import asyncio
import json
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import koe_engine as ke  # noqa: E402

CLIP = Path(__file__).resolve().parents[3] / "test" / "audio.wav"   # anime-dub/test/audio.wav


def tone(hz, seconds=1.5, sr=ke.ASR_SR):
    t = np.arange(int(seconds * sr)) / sr
    # a few harmonics so it looks like a voice to the autocorrelation
    return (0.3 * np.sin(2 * np.pi * hz * t) + 0.1 * np.sin(4 * np.pi * hz * t)).astype(np.float32)


# ---------------------------------------------------------------- pure helpers
@pytest.mark.parametrize("hz,voice", [(110, "en-US-ChristopherNeural"), (160, "en-US-GuyNeural"),
                                      (240, "en-US-AriaNeural"), (380, "en-US-AnaNeural")])
def test_pitch_picks_the_right_voice_band(hz, voice):
    measured = ke.pitch_hz(tone(hz))
    assert abs(measured - hz) / hz < 0.05
    assert ke.voice_for(measured) == voice


def test_silence_defaults_to_neutral_pitch():
    assert ke.pitch_hz(np.zeros(ke.ASR_SR, np.float32)) == 200.0


@pytest.mark.parametrize("junk", ["Thank you for watching!", "Please subscribe", "(Music)", "...", "Subtitles by Amara.org"])
def test_hallucinations_are_dropped(junk):
    assert ke.clean_text(junk) == ""


def test_repetition_loops_collapse():
    assert ke.clean_text("No no no no no! Stop!") == "No! Stop!"
    assert ke.clean_text("  We came to  protect the village. ") == "We came to protect the village."


def test_speech_speeds_up_with_backlog():
    assert [ke.speech_rate(s) for s in (0, 3, 8)] == ["+0%", "+15%", "+30%"]


# ---------------------------------------------------------------- segmenter (fake VAD)
class FakeVad:
    """Speech wherever the signal is loud."""

    def __call__(self, a):
        loud = np.abs(a) > 0.05
        out, start = [], None
        for i in range(0, len(a), 160):
            on = loud[i:i + 160].any()
            if on and start is None:
                start = i
            if not on and start is not None:
                out.append({"start": start, "end": i})
                start = None
        if start is not None:
            out.append({"start": start, "end": len(a)})
        return out


def stream(seg, audio, chunk=1600):
    got = []
    for i in range(0, len(audio), chunk):
        got += seg.feed(audio[i:i + chunk])
    return got


def test_segmenter_cuts_at_pauses():
    sr = ke.ASR_SR
    speech, gap = tone(200, 1.0), np.zeros(sr, np.float32)
    got = stream(ke.Segmenter(vad=FakeVad()), np.concatenate([gap, speech, gap, speech, gap]))
    assert len(got) == 2
    assert all(0.9 < len(u.audio) / sr < 1.5 for u in got)


def test_segmenter_forces_a_cut_on_long_speech():
    got = stream(ke.Segmenter(vad=FakeVad(), max_len=3.0), tone(200, 7.0))
    assert len(got) >= 2


def test_segmenter_ignores_clicks():
    click = np.zeros(ke.ASR_SR * 2, np.float32)
    click[ke.ASR_SR: ke.ASR_SR + 800] = 0.5
    assert stream(ke.Segmenter(vad=FakeVad()), click) == []


# ---------------------------------------------------------------- speaker tracking (fake voiceprints)
def fake_embed(audio):
    """Voiceprint = direction set by the first sample value, so tests control who is speaking."""
    who = int(round(audio[0] * 10))
    v = np.zeros(8, np.float32)
    v[who] = 1.0
    v += np.random.default_rng(len(audio)).normal(0, 0.05, 8).astype(np.float32)
    return v / np.linalg.norm(v)


def line(who, hz, seconds=2.0):
    a = tone(hz, seconds)
    a[0] = who / 10
    return a


def test_each_character_keeps_one_voice():
    t = ke.SpeakerTracker(fake_embed)
    a = [t.voice(line(1, 150)) for _ in range(3)]
    b = [t.voice(line(2, 260)) for _ in range(3)]
    a2 = t.voice(line(1, 230))            # same man, pitch jumps on a question
    assert len(set(a)) == 1 and len(set(b)) == 1
    assert a[0] in ke.MALE_VOICES and b[0] in ke.FEMALE_VOICES
    assert a2 == a[0]


def test_two_men_get_different_voices():
    t = ke.SpeakerTracker(fake_embed)
    assert t.voice(line(1, 130)) != t.voice(line(3, 140))


def test_short_interjection_does_not_create_a_character():
    t = ke.SpeakerTracker(fake_embed)
    first = t.voice(line(1, 150))
    assert t.voice(line(4, 300, seconds=0.8)) == first
    assert len(t.speakers) == 1


# ---------------------------------------------------------------- end to end through the socket
def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


@pytest.fixture(scope="module")
def engine():
    port = free_port()
    proc = subprocess.Popen([sys.executable, str(Path(ke.__file__)), "--port", str(port), "--token", "t0k"],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    deadline = time.time() + 180
    while time.time() < deadline:
        line = proc.stdout.readline()
        if '"state": "ready"' in line:
            break
        if '"state": "error"' in line:
            proc.kill()
            pytest.fail(line)
    yield port
    proc.kill()


def load_clip():
    import soundfile as sf
    audio, sr = sf.read(CLIP, dtype="float32", always_2d=True)
    mono = audio.mean(1)
    return np.interp(np.arange(0, len(mono), sr / ke.ASR_SR), np.arange(len(mono)), mono).astype(np.float32)


def test_rejects_a_wrong_token(engine):
    from websockets.asyncio.client import connect
    from websockets.exceptions import ConnectionClosed

    async def go():
        async with connect(f"ws://127.0.0.1:{engine}/?token=nope") as ws:
            with pytest.raises(ConnectionClosed):
                await ws.recv()
    asyncio.run(go())


@pytest.mark.skipif(not CLIP.exists(), reason="test clip missing")
def test_dubs_the_two_voice_clip_in_real_time(engine):
    """Stream the 35 s Japanese clip at real-time pace, like the app does, and check what comes back."""
    from websockets.asyncio.client import connect
    audio = load_clip()
    lines, audio_frames = [], 0

    async def go():
        nonlocal audio_frames
        async with connect(f"ws://127.0.0.1:{engine}/?token=t0k", max_size=2 ** 24) as ws:
            status = json.loads(await ws.recv())
            assert status["state"] == "ready"

            async def sender():
                step = ke.ASR_SR // 10
                for i in range(0, len(audio), step):
                    await ws.send(audio[i:i + step].tobytes())
                    await asyncio.sleep(0.1)
                for _ in range(40):                      # trailing silence flushes the last line
                    await ws.send(np.zeros(step, np.float32).tobytes())
                    await asyncio.sleep(0.1)

            async def receiver():
                nonlocal audio_frames
                while True:
                    msg = await ws.recv()
                    if isinstance(msg, bytes):
                        audio_frames += 1
                        continue
                    m = json.loads(msg)
                    if m["type"] == "line":
                        lines.append(m)

            recv = asyncio.create_task(receiver())
            await sender()
            await asyncio.sleep(3)
            recv.cancel()
    asyncio.run(go())

    text = " ".join(l["text"] for l in lines).lower()
    print("\n".join(f"{l['latency']:>5}s (tr {l['t_translate']}s) {l['voice']:<24} {l['text']}" for l in lines))
    assert len(lines) >= 5, lines
    assert audio_frames == len(lines)
    for word in ("who", "village", "hurry", "together"):
        assert word in text, f"missing '{word}' in: {text}"
    if "mountain" not in text:
        print("KNOWN QUALITY GAP: 'yama no mukou' not translated as 'mountain'")

    # the man (Keita) and the woman (Nanami) must each keep one voice, and not share it
    man = {l["voice"] for l in lines if re.search(r"who are you|doing here|on fire|survived|hurry", l["text"], re.I)}
    woman = {l["voice"] for l in lines if re.search(r"protect|lie|everyone|together", l["text"], re.I)}
    assert len(man) == 1 and len(woman) == 1, f"inconsistent voices: man={man} woman={woman}"
    assert man != woman, "both speakers got the same voice"

    median_latency = sorted(l["latency"] for l in lines)[len(lines) // 2]
    assert median_latency <= 2.0, f"too slow: median {median_latency}s after the speaker stops"


def test_subtitle_mode_learns_characters_from_whole_lines():
    t = ke.SpeakerTracker(fake_embed, same=0.7)
    man, woman = line(1, 150, 2.0), line(2, 260, 2.0)
    first = t.quick(man[:8000])                      # nobody known yet: a male voice, no character created
    assert first in ke.MALE_VOICES and t.speakers == []
    t.learn(man, first)
    assert t.quick(man[:8000]) == first               # now recognised from a short snippet
    w = t.quick(woman[:8000])                         # clearly someone else, other gender: fresh female voice
    assert w in ke.FEMALE_VOICES
    t.learn(woman, w)
    assert len(t.speakers) == 2
    assert t.quick(woman[:8000]) == w and t.quick(man[:8000]) == first


def test_fit_rate_speeds_up_long_lines_only():
    assert ke.fit_rate("Hi.", 2.0) == "+0%"
    assert ke.fit_rate("The survivors fled beyond the mountains before nightfall.", 2.5) == "+40%"


def test_cast_gives_each_named_character_one_voice():
    c = ke.Cast(ke.MALE_VOICES, ke.FEMALE_VOICES)
    lufas = c.assign("Lufas", 250)
    dina = c.assign("Dina", 240)
    gantz = c.assign("Gantz", 120)
    assert lufas in ke.FEMALE_VOICES and dina in ke.FEMALE_VOICES and lufas != dina
    assert gantz in ke.MALE_VOICES
    assert c.voice("Lufa") == lufas            # subtitle typo still maps to Lufas
    assert c.voice("LUFAS ") == lufas
    assert c.voice("Guard") is None            # not cast yet


def test_cast_fixes_a_wrong_first_guess():
    c = ke.Cast(ke.MALE_VOICES, ke.FEMALE_VOICES)
    first = c.assign("Chief", 230)             # short snippet sounded high
    c.confirm("Chief", 125)                    # whole line says: male
    assert first in ke.FEMALE_VOICES and c.voice("Chief") in ke.MALE_VOICES
    locked = c.voice("Chief")
    c.confirm("Chief", 260)                    # only the first line can change it
    assert c.voice("Chief") == locked


def test_pitch_ignores_the_soundtrack_under_a_voice():
    sr = ke.ASR_SR
    t = np.arange(int(2.0 * sr)) / sr
    music = (0.25 * (np.sin(2 * np.pi * 220 * t) + np.sin(2 * np.pi * 277 * t) + np.sin(2 * np.pi * 330 * t))).astype(np.float32)
    voice = tone(130, 1.0)                                   # a man speaking under loud music
    mixed = music[sr:2 * sr].copy()
    mixed[: len(voice)] += voice
    before = music[:sr]                                      # what was playing just before he spoke
    assert ke.voice_pitch(mixed, before) < ke.MALE_BELOW_HZ
    assert abs(ke.voice_pitch(mixed, before) - 130) / 130 < 0.1
