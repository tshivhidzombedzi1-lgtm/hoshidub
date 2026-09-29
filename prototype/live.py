"""Live anime interpreter: listens to what your PC is playing, speaks it back in English.

Nothing is downloaded or saved - it hears the sound like a person next to you would.

Two listening modes (picked automatically):
  * Cable mode    - if VB-Audio Virtual Cable is installed and the browser outputs to it. Clean: we hear
                    only the show, play it through to your speakers, and turn the Japanese down while
                    English is speaking.
  * Speaker mode  - listens to your speakers directly. Works with no setup; our own English is also
                    heard, so it is filtered out by language and by matching recently spoken lines.

Run:  .venv-live\\Scripts\\python live.py   [--model small|medium|large-v2]
"""
import argparse
import asyncio
import difflib
import os
import queue
import re
import subprocess
import sys
import threading
import time
import tkinter as tk
from collections import deque
from pathlib import Path

import numpy as np

ASR_SR = 16000   # whisper input rate
OUT_SR = 48000   # playback rate
BLOCK = 0.05     # capture block, seconds

# English voices picked by the speaker's pitch (Hz). Anime voices run high, so the bands are too.
VOICES = [
    (140, "en-US-ChristopherNeural"),  # deep male
    (190, "en-US-GuyNeural"),          # male
    (300, "en-US-AriaNeural"),         # female
    (9999, "en-US-AnaNeural"),         # young / high
]

# Whisper's stock hallucinations on music and silence
JUNK = re.compile(r"(thank(s| you) for watching|subscribe|please like|see you next time|"
                  r"subtitles by|amara\.org|\bmusic\b|^\W*$)", re.I)


def load_gpu_libs():
    """Use torch's bundled CUDA DLLs if torch is installed, so whisper can run on the GPU."""
    # borrow them from the dubber's venv rather than importing torch here (saves ~3 s startup)
    lib = Path(__file__).parent / ".venv" / "Lib" / "site-packages" / "torch" / "lib"
    if lib.exists():
        os.add_dll_directory(str(lib))
        os.environ["PATH"] = str(lib) + os.pathsep + os.environ["PATH"]


def resample(x, src, dst):
    if src == dst or len(x) == 0:
        return x.astype(np.float32)
    n = int(round(len(x) * dst / src))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def pitch_hz(x, sr=ASR_SR):
    """Median fundamental frequency of voiced frames, by autocorrelation."""
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


def voice_for(hz):
    return next(v for limit, v in VOICES if hz < limit)


class Interpreter:
    def __init__(self, model_name, ui_queue):
        self.model_name = model_name
        self.ui = ui_queue
        self.running = False
        self.utterances = queue.Queue()
        self.lines = queue.Queue()
        self.speech = deque()            # English audio chunks waiting to play (48k mono)
        self.speech_lock = threading.Lock()
        self.passthrough = deque()       # cable mode: show audio to forward (48k stereo)
        self.recent = deque(maxlen=12)   # (time, text) we spoke, for the echo filter
        self.voice_gain = 1.0
        self.duck = 0.3
        self.cable = None

    def status(self, msg):
        self.ui.put(("status", msg))

    # ------------------------------------------------------------ listening
    def pick_source(self):
        import soundcard as sc
        mics = sc.all_microphones(include_loopback=True)
        cable = next((m for m in mics if "cable output" in m.name.lower()), None)
        if cable:
            self.cable = cable
            return cable, "Cable mode (clean)"
        spk = sc.default_speaker()
        return sc.get_microphone(id=str(spk.name), include_loopback=True), "Speaker mode"

    def capture_loop(self):
        from faster_whisper.vad import VadOptions, get_speech_timestamps
        src, mode = self.pick_source()
        self.ui.put(("mode", mode))
        vad_opts = VadOptions(min_silence_duration_ms=300, speech_pad_ms=150)
        buf = np.zeros(0, dtype=np.float32)
        last_check = time.time()
        rec_sr = 48000
        with src.recorder(samplerate=rec_sr, channels=2, blocksize=int(rec_sr * BLOCK)) as rec:
            while self.running:
                data = rec.record(numframes=int(rec_sr * BLOCK))
                if self.cable:
                    self.passthrough.append(data.astype(np.float32))
                buf = np.concatenate([buf, resample(data.mean(1), rec_sr, ASR_SR)])
                if time.time() - last_check < 0.25:
                    continue
                last_check = time.time()
                buf = self.cut_utterances(buf, get_speech_timestamps, vad_opts)

    def cut_utterances(self, buf, vad, opts):
        """Emit a finished utterance once speech is followed by a pause (or runs past 9 s)."""
        ts = vad(buf, opts)
        if not ts:
            return buf[-ASR_SR:]  # keep only the last second of silence
        end_gap = (len(buf) - ts[-1]["end"]) / ASR_SR
        speech_len = (ts[-1]["end"] - ts[0]["start"]) / ASR_SR
        if end_gap > 0.45 or speech_len > 9:
            a, b = max(0, ts[0]["start"] - 1600), min(len(buf), ts[-1]["end"] + 1600)
            if speech_len > 0.4:
                self.utterances.put(buf[a:b].copy())
            return buf[b:]
        return buf

    # ------------------------------------------------------------ translating
    def translate_loop(self):
        from faster_whisper import WhisperModel
        model = None
        for dev, ct in (("cuda", "float16"), ("cpu", "int8")):
            name = self.pick_model(dev)
            self.status(f"loading {name} model...")
            try:
                model = WhisperModel(name, device=dev, compute_type=ct, cpu_threads=6)
                list(model.transcribe(np.zeros(ASR_SR, np.float32), language="ja")[0])
                self.status(f"listening ({name} on {dev.upper()})")
                break
            except Exception:
                model = None
        if model is None:
            self.status("could not load the speech model")
            return
        while self.running:
            try:
                audio = self.utterances.get(timeout=0.5)
            except queue.Empty:
                continue
            t0 = time.time()
            # speaker mode hears our own English too, so let whisper detect the language and skip English
            lang = "ja" if self.cable else None
            segs, info = model.transcribe(audio, language=lang, task="translate", beam_size=2,
                                          condition_on_previous_text=False, without_timestamps=True)
            segs = list(segs)
            if not self.cable and info.language != "ja":
                continue
            text = " ".join(s.text.strip() for s in segs
                            if s.no_speech_prob < 0.6 and s.avg_logprob > -1.0).strip()
            if not text or JUNK.search(text) or self.is_echo(text):
                continue
            hz = pitch_hz(audio)
            self.lines.put((text, voice_for(hz)))
            self.ui.put(("line", text, f"{hz:.0f} Hz, {time.time() - t0:.1f}s"))

    def pick_model(self, device):
        """'auto': the best model already downloaded that this device can run live."""
        if self.model_name != "auto":
            return self.model_name
        local = Path(__file__).parent / "models" / "whisper-large-v2"
        if device == "cuda" and (local / "model.bin").exists():
            return str(local)
        from faster_whisper.utils import download_model
        ranked = ["large-v2", "medium", "small"] if device == "cuda" else ["small"]
        for name in ranked:
            try:
                download_model(name, local_files_only=True)
                return name
            except Exception:
                continue
        return "small"

    def is_echo(self, text):
        now = time.time()
        t = text.lower()
        for when, said in self.recent:
            if now - when < 30 and (difflib.SequenceMatcher(None, t, said).ratio() > 0.55 or t in said):
                return True
        return False

    # ------------------------------------------------------------ speaking
    def tts_loop(self):
        import edge_tts
        loop = asyncio.new_event_loop()

        async def speak(text, voice, rate):
            mp3 = bytearray()
            async for chunk in edge_tts.Communicate(text, voice, rate=rate).stream():
                if chunk["type"] == "audio":
                    mp3 += chunk["data"]
            return bytes(mp3)

        while self.running:
            try:
                text, voice = self.lines.get(timeout=0.5)
            except queue.Empty:
                continue
            backlog = self.queued_seconds() + self.lines.qsize() * 2
            rate = "+0%" if backlog < 2 else "+15%" if backlog < 5 else "+30%"
            try:
                mp3 = loop.run_until_complete(speak(text, voice, rate))
            except Exception as e:
                self.status(f"voice service error: {e}")
                continue
            pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-f", "f32le", "-ac", "1",
                                  "-ar", str(OUT_SR), "pipe:1"], input=mp3, capture_output=True).stdout
            wav = np.frombuffer(pcm, dtype=np.float32)
            self.recent.append((time.time(), text.lower()))
            with self.speech_lock:
                self.speech.append(wav)

    def queued_seconds(self):
        with self.speech_lock:
            return sum(len(w) for w in self.speech) / OUT_SR

    def play_callback(self, out, frames, _time, _status):
        voice = np.zeros(frames, dtype=np.float32)
        filled = 0
        with self.speech_lock:
            while filled < frames and self.speech:
                w = self.speech[0]
                n = min(frames - filled, len(w))
                voice[filled:filled + n] = w[:n]
                filled += n
                if n == len(w):
                    self.speech.popleft()
                else:
                    self.speech[0] = w[n:]
        mix = np.repeat((voice * self.voice_gain)[:, None], out.shape[1], axis=1)
        if self.cable:
            show = self.take_passthrough(frames, out.shape[1])
            mix += show * (self.duck if filled else 1.0)
        out[:] = np.clip(mix, -1, 1)

    def take_passthrough(self, frames, ch):
        chunks, have = [], 0
        while have < frames and self.passthrough:
            c = self.passthrough.popleft()
            chunks.append(c)
            have += len(c)
        if len(self.passthrough) > 20:  # never drift more than ~1 s behind the show
            self.passthrough.clear()
        if not chunks:
            return np.zeros((frames, ch), dtype=np.float32)
        a = np.concatenate(chunks)
        if len(a) > frames:
            self.passthrough.appendleft(a[frames:])
            a = a[:frames]
        elif len(a) < frames:
            a = np.pad(a, ((0, frames - len(a)), (0, 0)))
        return a[:, :ch] if a.shape[1] >= ch else np.repeat(a[:, :1], ch, axis=1)

    # ------------------------------------------------------------ control
    def start(self):
        import sounddevice as sd
        self.running = True
        for fn in (self.translate_loop, self.tts_loop, self.capture_loop):
            threading.Thread(target=self.guard, args=(fn,), daemon=True).start()
        self.stream = sd.OutputStream(samplerate=OUT_SR, channels=2, dtype="float32",
                                      blocksize=int(OUT_SR * 0.02), callback=self.play_callback)
        self.stream.start()

    def guard(self, fn):
        try:
            fn()
        except Exception as e:
            self.status(f"error in {fn.__name__}: {e}")
            raise

    def stop(self):
        self.running = False
        if getattr(self, "stream", None):
            self.stream.stop()
            self.stream.close()
        with self.speech_lock:
            self.speech.clear()
        self.passthrough.clear()


# ---------------------------------------------------------------- UI
class App:
    def __init__(self, model):
        self.q = queue.Queue()
        self.interp = Interpreter(model, self.q)
        self.root = tk.Tk()
        self.root.title("Live Anime Interpreter")
        self.root.geometry("420x260")
        self.root.attributes("-topmost", True)

        self.btn = tk.Button(self.root, text="Start", width=14, font=("Segoe UI", 12, "bold"), command=self.toggle)
        self.btn.pack(pady=8)
        self.mode = tk.Label(self.root, text="", fg="#555")
        self.mode.pack()
        self.stat = tk.Label(self.root, text="Press Start, then play your show.", fg="#333")
        self.stat.pack(pady=2)

        vol = tk.Scale(self.root, from_=0, to=150, orient="horizontal", label="English voice volume %",
                       length=360, command=lambda v: setattr(self.interp, "voice_gain", int(v) / 100))
        vol.set(100)
        vol.pack()
        duck = tk.Scale(self.root, from_=0, to=100, orient="horizontal",
                        label="Japanese volume while English speaks % (cable mode)", length=360,
                        command=lambda v: setattr(self.interp, "duck", int(v) / 100))
        duck.set(30)
        duck.pack()

        # subtitle bar floating at the bottom of the screen
        self.subs = tk.Toplevel(self.root)
        self.subs.overrideredirect(True)
        self.subs.attributes("-topmost", True)
        self.subs.attributes("-alpha", 0.8)
        self.subs.configure(bg="black")
        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        self.subs.geometry(f"{int(sw * 0.7)}x70+{int(sw * 0.15)}+{sh - 170}")
        self.sub_label = tk.Label(self.subs, text="", fg="white", bg="black", font=("Segoe UI", 18),
                                  wraplength=int(sw * 0.68))
        self.sub_label.pack(expand=True, fill="both")
        self.subs.withdraw()

        self.root.protocol("WM_DELETE_WINDOW", self.quit)
        self.root.after(100, self.poll)

    def toggle(self):
        if self.interp.running:
            self.interp.stop()
            self.btn.config(text="Start")
            self.stat.config(text="Stopped.")
            self.subs.withdraw()
        else:
            self.interp.start()
            self.btn.config(text="Stop")
            self.subs.deiconify()

    def poll(self):
        while not self.q.empty():
            kind, *rest = self.q.get()
            if kind == "status":
                self.stat.config(text=rest[0])
            elif kind == "mode":
                self.mode.config(text=rest[0])
            elif kind == "line":
                self.sub_label.config(text=rest[0])
                print(f"[{rest[1]}] {rest[0]}", flush=True)
        self.root.after(100, self.poll)

    def quit(self):
        self.interp.stop()
        self.root.destroy()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="auto",
                    help="auto (best downloaded), small (fast), medium (better), large-v2 (best, needs GPU)")
    load_gpu_libs()
    App(ap.parse_args().model).root.mainloop()
