"""Koe dubbing engine: Japanese speech in, English speech out, over a local WebSocket.

Started by the Koe app:  python koe_engine.py --port 43123 --token <secret>

Protocol (ws://127.0.0.1:<port>/?token=<secret>):
  app -> engine   binary  float32 mono PCM at 16 kHz (the player's audio, streamed continuously)
                  text    {"type": "config", "voice_style": "auto"|..., "speed": 1.0}
                          {"type": "backlog", "seconds": 1.2}   (English still queued to play)
                          {"type": "reset"}                      (seeked / new episode)
  engine -> app   text    {"type": "status", "state": "loading"|"ready"|"error", "detail": "..."}
                          {"type": "line", "id": 7, "text": "...", "voice": "...", "latency": 0.9}
                          {"type": "audio", "id": 7, "sr": 24000, "samples": N}  then one binary frame
                                                                                 of N float32 samples
Every stdout line is JSON too, so the app can follow startup before the socket is up.
"""
import argparse
import asyncio
import json
import os
import re
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

import numpy as np

ASR_SR = 16000
TTS_SR = 24000
import packs                                        # model files, locations, downloads

ROOT = Path(__file__).resolve().parents[2]          # anime-dub/

# English voices by the speaker's pitch (Hz). Anime voices run high, so the bands do too.
VOICE_BANDS = [
    (140, "en-US-ChristopherNeural"),  # deep male
    (190, "en-US-GuyNeural"),          # male
    (300, "en-US-AriaNeural"),         # female
    (9999, "en-US-AnaNeural"),         # young / high
]
# Each new character takes the next free voice in their pool, so two characters never share one.
# Local Kokoro voices (fast, offline) ...
MALE_VOICES = packs.VOICES["en"]["male"]
FEMALE_VOICES = packs.VOICES["en"]["female"]
# ... and the online edge-tts fallback if Kokoro can't load.
EDGE_MALE = ["en-US-GuyNeural", "en-US-ChristopherNeural", "en-US-EricNeural", "en-US-AndrewNeural",
             "en-US-BrianNeural", "en-US-RogerNeural"]
EDGE_FEMALE = ["en-US-AriaNeural", "en-US-AnaNeural", "en-US-JennyNeural", "en-US-MichelleNeural",
               "en-US-EmmaNeural", "en-US-AvaNeural"]
MALE_BELOW_HZ = 175

# Whisper's stock hallucinations on music, silence and credits
JUNK = re.compile(r"(thank(s| you) for watching|subscribe|please like|see you (next time|in the next)|"
                  r"subtitles? by|amara\.org|translated by|\bmusic\b|^\W*$)", re.I)


def emit(**msg):
    """Startup/status line for the parent process."""
    print(json.dumps(msg), flush=True)


def load_gpu_libs():
    """torch ships the cuBLAS/cuDNN DLLs CTranslate2 needs on Windows; import it just for the path."""
    try:
        import torch
        lib = Path(torch.__file__).parent / "lib"
        os.add_dll_directory(str(lib))
        os.environ["PATH"] = str(lib) + os.pathsep + os.environ["PATH"]
        return torch.cuda.is_available()
    except Exception:
        return False


# ---------------------------------------------------------------- pure helpers (unit tested)
def pitch_hz(x, sr=ASR_SR):
    """Median fundamental frequency of voiced frames, by autocorrelation. 200 Hz if unvoiced."""
    frame, hop = int(0.04 * sr), int(0.02 * sr)
    lo, hi = sr // 500, sr // 70
    f0 = []
    for i in range(0, len(x) - frame, hop):
        w = x[i:i + frame]
        if np.sqrt(np.mean(w ** 2)) < 0.01:
            continue
        w = w - w.mean()
        ac = np.correlate(w, w, "full")[frame - 1:]
        if ac[0] <= 0:
            continue
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] / ac[0] > 0.35:
            f0.append(sr / lag)
    return float(np.median(f0)) if len(f0) >= 5 else 200.0


def remove_background(x, background, n=512, hop=256, strength=1.6):
    """Spectral subtraction: take out what was already playing before the line (music, ambience), so the
    pitch we measure is the voice's and not the soundtrack's."""
    if len(background) < n * 2 or len(x) < n:
        return x
    win = np.hanning(n).astype(np.float32)
    frames = lambda a: np.stack([a[i:i + n] * win for i in range(0, len(a) - n, hop)])
    noise = np.abs(np.fft.rfft(frames(background), axis=1)).mean(axis=0)
    spec = np.fft.rfft(frames(x), axis=1)
    mag = np.abs(spec)
    clean = np.maximum(mag - strength * noise, 0.05 * mag) * np.exp(1j * np.angle(spec))
    out = np.zeros(len(x), np.float32)
    for k, f in enumerate(np.fft.irfft(clean, n=n, axis=1)):
        out[k * hop:k * hop + n] += f.astype(np.float32) * win
    return out


def voice_pitch(x, background=None):
    """Pitch of the voice in x, with the soundtrack that was playing just before removed first."""
    return pitch_hz(remove_background(x, background) if background is not None else x)


def voice_for(hz):
    return next(v for limit, v in VOICE_BANDS if hz < limit)


def clean_text(text):
    """Collapse whisper's repetition loops and whitespace; return '' for junk."""
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\b(\w+(?:\W+\w+){0,3}?)(?:\W+\1\b){2,}", r"\1", text, flags=re.I)
    return "" if JUNK.search(text) else text


class Cast:
    """Character name (from the subtitle file) -> one fixed English voice for the whole episode."""

    def __init__(self, male, female):
        self.male, self.female = male, female
        self.voices = {}          # key -> voice
        self.firsts = {}          # key -> True until the gender is confirmed from a whole line

    @staticmethod
    def key(name):
        return re.sub(r"[^a-z]", "", str(name or "").lower())

    def resolve(self, name):
        """Match spelling variants (Lufa/Lufas, Village/Villager) to a character we already know."""
        k = self.key(name)
        if not k:
            return ""
        if k in self.voices:
            return k
        for known in self.voices:
            short, long_ = sorted((k, known), key=len)
            if len(short) >= 4 and long_.startswith(short) and len(long_) - len(short) <= 2:
                return known
        return k

    def voice(self, name):
        return self.voices.get(self.resolve(name))

    def assign(self, name, hz):
        k = self.resolve(name)
        pool = self.male if hz < MALE_BELOW_HZ else self.female
        taken = set(self.voices.values())
        v = next((x for x in pool if x not in taken), pool[len(self.voices) % len(pool)])
        self.voices[k], self.firsts[k] = v, True
        return v

    def confirm(self, name, hz):
        """After a character's first whole line: fix the voice if the short snippet got the gender wrong."""
        k = self.resolve(name)
        if not self.firsts.pop(k, False):
            return
        if (self.voices[k] in self.male) != (hz < MALE_BELOW_HZ):
            del self.voices[k]
            self.assign(k, hz)
            self.firsts.pop(k, None)


def fit_rate(text, seconds, chars_per_second=14.5, fastest=1.4):
    """Speed needed for an English line to fit the time its subtitle is on screen, as an edge-style rate."""
    natural = len(text) / chars_per_second
    speed = min(max(natural / max(seconds, 0.3), 1.0), fastest)
    return f"+{int(round((speed - 1) * 100))}%"


def speech_rate(backlog_seconds):
    """Talk faster when English is piling up behind the show."""
    if backlog_seconds < 2:
        return "+0%"
    if backlog_seconds < 5:
        return "+15%"
    return "+30%"


class SpeakerTracker:
    """Recognises characters by voiceprint so each keeps one English voice for the whole episode.

    `embed` maps 16 kHz audio -> unit-length speaker vector. Short lines (unreliable prints) stick with
    the closest known speaker, or the previous one.
    """

    def __init__(self, embed, same=0.72, short=1.2, male=MALE_VOICES, female=FEMALE_VOICES, min_seconds=0.6):
        self.embed = embed
        self.same, self.short, self.min_seconds = same, short, min_seconds
        self.male, self.female = male, female
        self.speakers = []   # dicts: centroid, n, voice, hz
        self.last = None

    def reset(self):
        self.speakers, self.last = [], None

    def voice(self, audio):
        hz = pitch_hz(audio)
        seconds = len(audio) / ASR_SR
        if seconds < self.min_seconds and self.last is not None:
            return self.last["voice"]
        v = self.embed(audio)
        best, sim = None, -1.0
        for s in self.speakers:
            c = float(np.dot(s["centroid"], v))
            if c > sim:
                best, sim = s, c
        threshold = self.same - (0.1 if seconds < self.short else 0.0)
        if best is None or sim < threshold:
            if seconds < self.short and self.last is not None:
                return self.last["voice"]          # too short to found a new character on
            best = {"centroid": v, "n": 0, "hz": hz, "voice": self.pick_voice(hz)}
            self.speakers.append(best)
        best["n"] += 1
        w = 1.0 / min(best["n"], 20)
        c = (1 - w) * best["centroid"] + w * v
        best["centroid"] = c / (np.linalg.norm(c) + 1e-9)
        self.last = best
        return best["voice"]

    # ---- subtitle mode: guess from a short snippet, learn from the whole line afterwards
    def _best(self, v):
        best, sim = None, -1.0
        for s in self.speakers:
            c = float(np.dot(s["centroid"], v))
            if c > sim:
                best, sim = s, c
        return best, sim

    def quick(self, audio, quick_same=0.75):
        """Voice for a line from its first half-second. Never creates a character (prints this short are
        unreliable); if it clearly isn't anyone we know, returns a fresh voice for the right gender."""
        hz = pitch_hz(audio)
        if not self.speakers:
            return self.pick_voice(hz)
        best, sim = self._best(self.embed(audio))
        # short prints all look fairly alike, so only a very close match overrides what the pitch says
        same_gender = (best["hz"] < MALE_BELOW_HZ) == (hz < MALE_BELOW_HZ)
        if sim >= quick_same or same_gender:
            self.last = best
            return best["voice"]
        return self.pick_voice(hz)

    def learn(self, audio, voice_used):
        """After a line ends: fold the whole line into its character, or found a new one."""
        if len(audio) < ASR_SR * 1.0:
            return
        hz, v = pitch_hz(audio), self.embed(audio)
        best, sim = self._best(v)
        if best is not None and sim >= self.same:
            best["n"] += 1
            w = 1.0 / min(best["n"], 20)
            c = (1 - w) * best["centroid"] + w * v
            best["centroid"] = c / (np.linalg.norm(c) + 1e-9)
            return
        taken = {s["voice"] for s in self.speakers}
        voice = voice_used if voice_used not in taken else self.pick_voice(hz)
        self.speakers.append({"centroid": v, "n": 1, "hz": hz, "voice": voice})

    def pick_voice(self, hz):
        pool = self.male if hz < MALE_BELOW_HZ else self.female
        taken = {s["voice"] for s in self.speakers}
        return next((v for v in pool if v not in taken), pool[len(self.speakers) % len(pool)])


def load_voiceprint():
    """Chatterbox's speaker encoder (already downloaded with the voice model). None if unavailable."""
    try:
        import torch
        from safetensors.torch import load_file
        from chatterbox.models.voice_encoder import VoiceEncoder
        weights = packs.local_path("ResembleAI/chatterbox", "ve.safetensors")
        if not weights.exists():
            raise FileNotFoundError("voiceprint weights not downloaded")
        dev = "cuda" if torch.cuda.is_available() else "cpu"
        enc = VoiceEncoder()
        enc.load_state_dict(load_file(str(weights)))
        enc = enc.to(dev).eval()

        def embed(audio):
            e = enc.embeds_from_wavs([audio], sample_rate=ASR_SR, trim_top_db=None)[0]
            return e / (np.linalg.norm(e) + 1e-9)
        embed(np.random.randn(ASR_SR).astype(np.float32) * 0.1)   # warm up
        return embed
    except Exception as e:
        emit(type="log", msg=f"voiceprints unavailable, using pitch only: {e}")
        return None


@dataclass
class Utterance:
    audio: np.ndarray
    ended_at: float       # wall-clock time the speaker stopped


class Segmenter:
    """Accumulates streamed audio and cuts it into utterances at pauses (silero VAD)."""

    def __init__(self, vad=None, min_gap=0.45, max_len=9.0, min_len=0.4):
        if vad is None:
            from faster_whisper.vad import VadOptions, get_speech_timestamps
            opts = VadOptions(min_silence_duration_ms=300, speech_pad_ms=150)
            vad = lambda a: get_speech_timestamps(a, opts)
        self.vad = vad
        self.min_gap, self.max_len, self.min_len = min_gap, max_len, min_len
        self.buf = np.zeros(0, dtype=np.float32)
        self.pending = 0

    def reset(self):
        self.buf = np.zeros(0, dtype=np.float32)
        self.pending = 0

    def feed(self, pcm):
        """Add audio; returns a list of finished utterances (usually empty)."""
        self.buf = np.concatenate([self.buf, pcm.astype(np.float32)])
        self.pending += len(pcm)
        if self.pending < ASR_SR // 4:          # run VAD at most every 250 ms
            return []
        self.pending = 0
        out = []
        ts = self.vad(self.buf)
        if not ts:
            self.buf = self.buf[-ASR_SR:]      # keep a second of lead-in
            return out
        end_gap = (len(self.buf) - ts[-1]["end"]) / ASR_SR
        length = (ts[-1]["end"] - ts[0]["start"]) / ASR_SR
        if end_gap > self.min_gap or length > self.max_len:
            a = max(0, ts[0]["start"] - 1600)
            b = min(len(self.buf), ts[-1]["end"] + 1600)
            if length >= self.min_len:
                out.append(Utterance(self.buf[a:b].copy(), time.time() - end_gap))
            self.buf = self.buf[b:]
        return out


# ---------------------------------------------------------------- models
class Translator:
    def __init__(self):
        from faster_whisper import WhisperModel
        gpu = load_gpu_libs()
        folder = packs.whisper_dir()
        if folder is None:
            raise FileNotFoundError("the translate-by-ear pack is not installed")
        attempts = ([(str(folder), "cuda", "float16")] if gpu else []) + [(str(folder), "cpu", "int8")]
        last = None
        for name, dev, ct in attempts:
            try:
                self.model = WhisperModel(name, device=dev, compute_type=ct, cpu_threads=6)
                list(self.model.transcribe(np.zeros(ASR_SR, np.float32), language="ja")[0])
                self.desc = f"{Path(name).name} on {dev.upper()}"
                return
            except Exception as e:
                last = e
        raise RuntimeError(f"could not load a speech model: {last}")

    def translate(self, audio):
        segs, _ = self.model.transcribe(audio, language="ja", task="translate", beam_size=3,
                                        condition_on_previous_text=False, without_timestamps=True,
                                        vad_filter=False)
        parts = [s.text.strip() for s in segs if s.no_speech_prob < 0.6 and s.avg_logprob > -1.0]
        return clean_text(" ".join(parts))


class LocalVoice:
    """Kokoro-82M on the GPU: ~0.15 s per line once warm. Apache-2.0, fine for commercial use."""

    male, female = MALE_VOICES, FEMALE_VOICES
    desc = "local voices"

    def __init__(self):
        import torch
        from kokoro import KModel, KPipeline
        dev = "cuda" if torch.cuda.is_available() else "cpu"
        model = KModel(repo_id=packs.KOKORO, config=str(packs.local_path(packs.KOKORO, "config.json")),
                       model=str(packs.local_path(packs.KOKORO, "kokoro-v1_0.pth"))).to(dev).eval()
        self.pipe = KPipeline(lang_code="a", repo_id=packs.KOKORO, model=model)
        self.pool = ThreadPoolExecutor(max_workers=1)
        for v in self.male + self.female:        # first use of a voice is slow: pay it at startup
            self.render("Ready.", v, 1.0)

    def render(self, text, voice, speed):
        # voices load from our own pack folder, never from a network cache
        path = str(packs.voice_path(voice))
        parts = [r.audio.numpy() for r in self.pipe(text, voice=path, speed=speed) if r.audio is not None]
        return np.concatenate(parts).astype(np.float32) if parts else np.zeros(0, np.float32)

    async def speak(self, text, voice, rate):
        speed = 1.0 + int(rate.strip("+%")) / 100
        return await asyncio.get_running_loop().run_in_executor(self.pool, self.render, text, voice, speed)


class Voice:
    """edge-tts neural voices (online fallback), decoded to float32 PCM with ffmpeg."""

    male, female = EDGE_MALE, EDGE_FEMALE
    desc = "online voices"

    def __init__(self):
        import edge_tts
        self.edge_tts = edge_tts

    async def speak(self, text, voice, rate):
        mp3 = bytearray()
        async for chunk in self.edge_tts.Communicate(text, voice, rate=rate).stream():
            if chunk["type"] == "audio":
                mp3 += chunk["data"]
        proc = await asyncio.create_subprocess_exec(
            "ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-f", "f32le", "-ac", "1", "-ar", str(TTS_SR), "pipe:1",
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        pcm, _ = await proc.communicate(bytes(mp3))
        return np.frombuffer(pcm, dtype=np.float32)


# ---------------------------------------------------------------- server
class Engine:
    def __init__(self, token):
        self.token = token
        self.state, self.detail = "loading", "starting"
        self.translator = None
        self.embed = None
        self.voice = None
        self.pool = ThreadPoolExecutor(max_workers=1)   # GPU work is serialised
        self.clients = set()

    def load(self):
        try:
            self.set_status("loading", "loading speech model")
            try:
                self.translator = Translator()
            except Exception as e:                  # subtitle mode still works without it
                self.translator = None
                emit(type="log", msg=f"translate-by-ear unavailable: {e}")
            self.set_status("loading", "loading voiceprints")
            self.embed = load_voiceprint()
            self.set_status("loading", "warming up voices")
            try:
                self.voice = LocalVoice()
            except Exception as e:
                emit(type="log", msg=f"local voices unavailable, using online voices: {e}")
                self.voice = Voice()
            ear = self.translator.desc if self.translator else "subtitles only (translate-by-ear pack not installed)"
            self.set_status("ready", f"{ear}, {self.voice.desc}")
        except Exception as e:
            self.set_status("error", str(e))

    def set_status(self, state, detail):
        self.state, self.detail = state, detail
        emit(type="status", state=state, detail=detail)
        loop = getattr(self, "loop", None)
        if loop:
            for ws in list(self.clients):
                asyncio.run_coroutine_threadsafe(self.send(ws, type="status", state=state, detail=detail), loop)

    async def send(self, ws, **msg):
        try:
            await ws.send(json.dumps(msg))
        except Exception:
            pass

    async def handle(self, ws):
        from urllib.parse import parse_qs, urlparse
        q = parse_qs(urlparse(ws.request.path).query)
        if q.get("token", [""])[0] != self.token:
            await ws.close(4001, "bad token")
            return
        self.clients.add(ws)
        await self.send(ws, type="status", state=self.state, detail=self.detail)
        session = Session(self, ws)
        try:
            async for msg in ws:
                if isinstance(msg, bytes):
                    session.feed(np.frombuffer(msg, dtype=np.float32))
                else:
                    session.control(json.loads(msg))
        finally:
            self.clients.discard(ws)
            session.close()

    async def serve(self, port):
        from websockets.asyncio.server import serve
        self.loop = asyncio.get_running_loop()
        threading.Thread(target=self.load, daemon=True).start()
        async with serve(self.handle, "127.0.0.1", port, max_size=2 ** 22):
            emit(type="listening", port=port)
            await asyncio.Future()


class Session:
    """One connected app window. Two modes:

    listen  segment the audio -> translate by ear -> speak. Translation runs one line at a time on the GPU;
            speech for a line is generated while the next is translated.
    subs    the app sends the site's own subtitle lines as they come up ("say"); we listen just long enough
            to recognise who is talking, then speak the official line in that character's voice.
    Either way, lines are delivered in the order they were spoken.
    """

    RING_SECONDS = 12

    def __init__(self, engine, ws):
        self.engine, self.ws = engine, ws
        self.segmenter = Segmenter()
        self.mode = "listen"
        self.ring = []                 # (arrival time, pcm) of recent audio, for subtitle-mode voiceprints
        self.queue = asyncio.Queue()
        self.backlog = 0.0
        self.next_id = 0
        self.epoch = 0                 # bumps on reset so stale lines are dropped
        self.delivered = None          # future of the previous line's delivery, for ordering
        self.prepared = {}             # subtitle id -> {voice: task rendering that line in that voice}
        self.cast = Cast(engine.voice.male, engine.voice.female)
        self.new_speakers()
        self.worker = asyncio.create_task(self.run())

    def new_speakers(self):
        eng, v = self.engine, self.engine.voice
        if not eng.embed:
            self.speakers = None
        elif self.mode == "subs":      # short listening windows: accept shorter voiceprints
            self.speakers = SpeakerTracker(eng.embed, male=v.male, female=v.female, same=0.7)
        else:
            self.speakers = SpeakerTracker(eng.embed, male=v.male, female=v.female)

    def feed(self, pcm):
        now = time.time()
        self.ring.append((now, pcm))
        while self.ring and now - self.ring[0][0] > self.RING_SECONDS:
            self.ring.pop(0)
        if self.mode == "listen":
            for utt in self.segmenter.feed(pcm):
                self.queue.put_nowait((self.epoch, utt))

    def recent_audio(self, since, until=None):
        parts = [p for t, p in self.ring if t >= since and (until is None or t <= until)]
        return np.concatenate(parts) if parts else np.zeros(0, np.float32)

    def control(self, msg):
        kind = msg.get("type")
        if kind == "backlog":
            self.backlog = float(msg.get("seconds", 0))
        elif kind == "reset":
            self.epoch += 1
            self.segmenter.reset()
            self.new_speakers()
            self.cast = Cast(self.engine.voice.male, self.engine.voice.female)
        elif kind == "config" and msg.get("mode") in ("listen", "subs") and msg["mode"] != self.mode:
            self.mode = msg["mode"]
            self.epoch += 1
            self.segmenter.reset()
            self.new_speakers()
        elif kind == "prepare" and self.mode == "subs" and self.engine.state == "ready":
            self.prepare(int(msg.get("id", 0)), clean_text(str(msg.get("text", ""))), float(msg.get("dur", 2)),
                         str(msg.get("speaker", "")))
        elif kind == "say" and self.mode == "subs" and self.engine.state == "ready":
            text = clean_text(str(msg.get("text", "")))
            if text:
                line_id = int(msg.get("id", 0))
                speech = asyncio.create_task(self.speak_subtitle(line_id, text, float(msg.get("dur", 2)), self.epoch,
                                                                 str(msg.get("speaker", ""))))
                self.delivered = asyncio.create_task(
                    self.deliver_subtitle(self.delivered, speech, line_id, text, self.epoch))

    def identify(self, audio):
        if len(audio) < ASR_SR * 0.25 or np.sqrt(np.mean(audio ** 2)) < 0.005:
            return self.speakers.last["voice"] if self.speakers and self.speakers.last else self.engine.voice.male[0]
        return self.speakers.quick(audio) if self.speakers else voice_for(pitch_hz(audio))

    async def confirm_later(self, said, dur, speaker, epoch):
        await asyncio.sleep(max(0.0, said + dur + 0.2 - time.time()))
        if epoch == self.epoch:
            line = self.recent_audio(said - 0.1, said + dur + 0.2)
            self.cast.confirm(speaker, voice_pitch(line, self.recent_audio(said - 1.6, said - 0.2)))

    async def learn_later(self, said, dur, voice, epoch):
        await asyncio.sleep(max(0.0, said + dur + 0.2 - time.time()))
        if epoch != self.epoch or not self.speakers:
            return
        audio = self.recent_audio(said - 0.1, said + dur + 0.2)
        await asyncio.get_running_loop().run_in_executor(self.engine.pool, self.speakers.learn, audio, voice)

    LISTEN = 0.4        # seconds of a line we hear before choosing its voice (audio is pre-rendered)

    def candidate_voices(self):
        v = self.engine.voice
        known = [s["voice"] for s in sorted(self.speakers.speakers, key=lambda s: -s["n"])] if self.speakers else []
        out = []
        for voice in known + [v.male[0], v.female[0]]:
            if voice not in out:
                out.append(voice)
        return out[:4]

    def prepare(self, line_id, text, dur, speaker=""):
        """Render an upcoming subtitle line ahead of time: in its character's voice if we know it,
        otherwise in each likely voice."""
        if not text:
            return
        for old in [k for k in self.prepared if k < line_id - 8 or k > line_id + 40]:
            self.prepared.pop(old)                # seeked away: drop stale renders
        slot = self.prepared.setdefault(line_id, {})
        known = self.cast.voice(speaker)
        rate = fit_rate(text, dur if known else dur - self.LISTEN * 0.5)
        for voice in ([known] if known else self.candidate_voices()):
            if voice not in slot:
                slot[voice] = asyncio.create_task(self.engine.voice.speak(text, voice, rate))

    async def speak_subtitle(self, line_id, text, dur, epoch, speaker=""):
        said = time.time()
        eng = self.engine
        voice = self.cast.voice(speaker)
        if voice:                                   # a named character we already cast: play instantly
            ready = self.prepared.pop(line_id, {}).get(voice)
            pcm = await ready if ready else await eng.voice.speak(text, voice, fit_rate(text, dur))
            return pcm, voice, time.time() - said
        await asyncio.sleep(self.LISTEN)
        if epoch != self.epoch:
            return None
        audio = self.recent_audio(said - 0.15)
        if self.cast.key(speaker):                  # first line of a named character: cast them by pitch
            voice = self.cast.assign(speaker, voice_pitch(audio, self.recent_audio(said - 1.6, said - 0.2)))
            asyncio.create_task(self.confirm_later(said, dur, speaker, epoch))
        else:
            voice = await asyncio.get_running_loop().run_in_executor(eng.pool, self.identify, audio)
            asyncio.create_task(self.learn_later(said, dur, voice, epoch))
        ready = self.prepared.pop(line_id, {}).get(voice)
        pcm = await ready if ready else await eng.voice.speak(text, voice, fit_rate(text, dur - self.LISTEN * 0.5))
        return pcm, voice, time.time() - said

    async def deliver_subtitle(self, previous, speech, line_id, text, epoch):
        eng = self.engine
        try:
            result = await speech
        except Exception as e:
            result = None
            await eng.send(self.ws, type="status", state="ready", detail=f"voice service problem: {e}")
        if previous is not None:
            await asyncio.shield(previous)
        if not result or epoch != self.epoch or len(result[0]) == 0:
            return
        pcm, voice, latency = result
        await eng.send(self.ws, type="line", id=line_id, text=text, voice=voice, latency=round(latency, 2),
                       source="subtitles")
        await eng.send(self.ws, type="audio", id=line_id, sr=TTS_SR, samples=len(pcm))
        await self.ws.send(pcm.tobytes())

    def close(self):
        self.worker.cancel()

    def translate_and_identify(self, audio):
        text = self.engine.translator.translate(audio)
        if not text:
            return "", None
        voice = self.speakers.voice(audio) if self.speakers else voice_for(pitch_hz(audio))
        return text, voice

    async def run(self):
        loop = asyncio.get_running_loop()
        while True:
            epoch, utt = await self.queue.get()
            eng = self.engine
            if eng.state != "ready" or epoch != self.epoch or eng.translator is None:
                continue
            if self.queue.qsize() > 3:           # hopelessly behind: skip to recent speech
                continue
            t0 = time.time()
            text, voice = await loop.run_in_executor(eng.pool, self.translate_and_identify, utt.audio)
            if not text or epoch != self.epoch:
                continue
            speech = asyncio.create_task(eng.voice.speak(text, voice, speech_rate(self.backlog)))
            self.delivered = asyncio.create_task(
                self.deliver(self.delivered, speech, text, voice, utt, epoch, time.time() - t0))

    async def deliver(self, previous, speech, text, voice, utt, epoch, t_translate):
        eng = self.engine
        try:
            pcm = await speech
        except Exception as e:
            pcm = None
            await eng.send(self.ws, type="status", state="ready", detail=f"voice service problem: {e}")
        if previous is not None:
            await asyncio.shield(previous)       # keep spoken order
        if pcm is None or len(pcm) == 0 or epoch != self.epoch:
            return
        self.next_id += 1
        latency = round(time.time() - utt.ended_at, 2)
        await eng.send(self.ws, type="line", id=self.next_id, text=text, voice=voice, latency=latency,
                       t_translate=round(t_translate, 2))
        await eng.send(self.ws, type="audio", id=self.next_id, sr=TTS_SR, samples=len(pcm))
        await self.ws.send(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--token", required=True)
    a = ap.parse_args()
    try:
        asyncio.run(Engine(a.token).serve(a.port))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
