"""Anime dubber: paste a URL, get the video back dubbed JP -> EN with a cloned voice per speaker.

Pipeline (every step caches its output in work/<id>/, so re-runs skip finished steps):
  1. download       yt-dlp -> video.mp4
  2. separate       demucs -> vocals.wav (speech) + background.wav (music/SFX)
  3. transcribe     faster-whisper, Japanese speech -> English text with timestamps
  4. speakers       voice embeddings + clustering -> speaker id per line, reference clip per speaker
  5. synthesize     Chatterbox TTS in each speaker's cloned voice
  6. mix            fit lines to their time slots, lay over background, mux back into the video
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

os.environ.setdefault("HF_HUB_DISABLE_XET", "1")  # the xet downloader stalls on this connection

import numpy as np
import soundfile as sf

ROOT = Path(__file__).parent
WORK = ROOT / "work"
OUT = ROOT / "output"
SR = 44100  # mixing sample rate


def log(msg):
    print(f"[dub] {msg}", flush=True)


def run(cmd):
    subprocess.run(cmd, check=True)


def load_torch():
    # torch ships the cuBLAS/cuDNN DLLs that faster-whisper's CTranslate2 needs on Windows
    import torch
    lib = Path(torch.__file__).parent / "lib"
    if lib.exists() and hasattr(os, "add_dll_directory"):
        os.add_dll_directory(str(lib))
        os.environ["PATH"] = str(lib) + os.pathsep + os.environ["PATH"]
    return torch


# ---------------------------------------------------------------- 1. download
def download(url, job):
    video = job / "video.mp4"
    if video.exists():
        return video
    if Path(url).is_file():  # a video already on this PC
        log("converting local video")
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", url, "-c:v", "copy", "-c:a", "aac", str(video)])
        (job / "title.txt").write_text(Path(url).stem, encoding="utf-8")
        return video
    log("downloading video")
    run([sys.executable, "-m", "yt_dlp", "-f", "bv*[height<=1080]+ba/b", "--merge-output-format", "mp4",
         "--no-playlist", "-o", str(video), "--print-to-file", "%(title)s", str(job / "title.txt"), url])
    return video


def job_dir(url):
    key = re.sub(r"[^A-Za-z0-9_-]", "_", url.split("//")[-1])[-60:]
    job = WORK / key
    job.mkdir(parents=True, exist_ok=True)
    return job


# ---------------------------------------------------------------- 2. separate
def separate(video, job, torch):
    vocals, background = job / "vocals.wav", job / "background.wav"
    if vocals.exists() and background.exists():
        return vocals, background
    mix = job / "original.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-vn", "-ac", "2", "-ar", str(SR), str(mix)])

    log("separating voices from music (demucs)")
    from demucs.apply import apply_model
    from demucs.pretrained import get_model
    model = get_model("htdemucs").cuda().eval()
    audio, _ = sf.read(mix, dtype="float32", always_2d=True)
    wav = torch.from_numpy(audio.T).cuda()
    ref = wav.mean(0)
    wav = (wav - ref.mean()) / (ref.std() + 1e-8)
    with torch.no_grad():
        stems = apply_model(model, wav[None], split=True, overlap=0.25, progress=True)[0]
    stems = stems * (ref.std() + 1e-8) + ref.mean()
    idx = model.sources.index("vocals")
    voc = stems[idx]
    bg = stems.sum(0) - voc
    sf.write(vocals, voc.cpu().numpy().T, SR)
    sf.write(background, bg.cpu().numpy().T, SR)
    del model
    torch.cuda.empty_cache()
    return vocals, background


# ---------------------------------------------------------------- 3. transcribe + translate
def transcribe(vocals, job, torch):
    out = job / "segments.json"
    if out.exists():
        return json.loads(out.read_text(encoding="utf-8"))
    log("transcribing Japanese and translating to English (whisper)")
    from faster_whisper import WhisperModel
    # large-v2 translates noticeably better than large-v3 for the ja->en task
    local = ROOT / "models" / "whisper-large-v2"
    model = WhisperModel(str(local) if (local / "model.bin").exists() else "large-v2",
                         device="cuda", compute_type="float16")
    segs, _ = model.transcribe(str(vocals), language="ja", task="translate", vad_filter=True,
                               vad_parameters={"min_silence_duration_ms": 400}, beam_size=5,
                               condition_on_previous_text=False)
    result = []
    for s in segs:
        text = s.text.strip()
        if not text or not re.search(r"[A-Za-z]", text):
            continue
        result.append({"start": round(s.start, 2), "end": round(s.end, 2), "text": text})
        log(f"  {s.start:7.1f}s  {text}")
    out.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    del model
    torch.cuda.empty_cache()
    return result


# ---------------------------------------------------------------- 4. speakers
def assign_speakers(segments, vocals, job, threshold):
    if segments and "speaker" in segments[0] and (job / "speakers").exists():
        return segments
    log("grouping lines by speaker")
    import librosa
    from chatterbox.models.voice_encoder import VoiceEncoder
    from sklearn.cluster import AgglomerativeClustering

    audio, sr = sf.read(vocals, dtype="float32", always_2d=True)
    mono = audio.mean(1)
    mono16 = librosa.resample(mono, orig_sr=sr, target_sr=16000)

    enc = VoiceEncoder().to("cuda").eval()
    enc.load_state_dict(_voice_encoder_weights())
    clips = [mono16[int(s["start"] * 16000):int(s["end"] * 16000)] for s in segments]
    usable = [i for i, c in enumerate(clips) if len(c) > 16000 * 0.8]
    embeds = enc.embeds_from_wavs([clips[i] for i in usable], sample_rate=16000)

    labels = np.zeros(len(segments), dtype=int)
    if len(usable) >= 2:
        cl = AgglomerativeClustering(n_clusters=None, metric="cosine", linkage="average",
                                     distance_threshold=threshold).fit(embeds)
        for i, lab in zip(usable, cl.labels_):
            labels[i] = lab
        # very short lines borrow the speaker of the nearest usable line
        for i in range(len(segments)):
            if i not in usable:
                nearest = min(usable, key=lambda j: abs(segments[j]["start"] - segments[i]["start"]))
                labels[i] = labels[nearest]

    # reference voice per speaker: their longest lines, up to ~12s of clean speech
    ref_dir = job / "speakers"
    ref_dir.mkdir(exist_ok=True)
    for spk in sorted(set(labels)):
        idx = sorted([i for i in range(len(segments)) if labels[i] == spk],
                     key=lambda i: segments[i]["end"] - segments[i]["start"], reverse=True)
        parts, total = [], 0.0
        for i in idx:
            s = segments[i]
            parts.append(mono[int(s["start"] * sr):int(s["end"] * sr)])
            parts.append(np.zeros(int(0.2 * sr), dtype=np.float32))
            total += s["end"] - s["start"]
            if total > 12:
                break
        sf.write(ref_dir / f"speaker_{spk}.wav", np.concatenate(parts), sr)

    for s, lab in zip(segments, labels):
        s["speaker"] = int(lab)
    (job / "segments.json").write_text(json.dumps(segments, ensure_ascii=False, indent=1), encoding="utf-8")
    log(f"  found {len(set(labels))} speaker(s)")
    return segments


def _voice_encoder_weights():
    from huggingface_hub import hf_hub_download
    from safetensors.torch import load_file
    return load_file(hf_hub_download("ResembleAI/chatterbox", "ve.safetensors"))


# ---------------------------------------------------------------- 5. synthesize
def synthesize(segments, job, torch, exaggeration):
    tts_dir = job / "tts"
    tts_dir.mkdir(exist_ok=True)
    todo = [i for i in range(len(segments)) if not (tts_dir / f"{i:04d}.wav").exists()]
    if not todo:
        return tts_dir
    log(f"speaking {len(todo)} lines in cloned voices (chatterbox)")
    from chatterbox.tts import ChatterboxTTS
    model = ChatterboxTTS.from_pretrained(device="cuda")
    for n, i in enumerate(todo, 1):
        s = segments[i]
        ref = job / "speakers" / f"speaker_{s['speaker']}.wav"
        wav = model.generate(s["text"], audio_prompt_path=str(ref), exaggeration=exaggeration, cfg_weight=0.4)
        sf.write(tts_dir / f"{i:04d}.wav", wav.squeeze(0).cpu().numpy(), model.sr)
        log(f"  [{n}/{len(todo)}] spk{s['speaker']}: {s['text']}")
    del model
    torch.cuda.empty_cache()
    return tts_dir


# ---------------------------------------------------------------- 6. mix
def fit_line(wav, sr, slot):
    """Trim silence, resample to SR, and speed up (max 1.4x) if the line overruns its slot."""
    import librosa
    wav, _ = librosa.effects.trim(wav, top_db=35)
    wav = librosa.resample(wav, orig_sr=sr, target_sr=SR)
    dur = len(wav) / SR
    if slot > 0 and dur > slot:
        rate = min(dur / slot, 1.4)
        wav = librosa.effects.time_stretch(wav, rate=rate)
    return wav


def mix(segments, tts_dir, background, video, job):
    log("mixing dubbed voices over the background track")
    bg, _ = sf.read(background, dtype="float32", always_2d=True)
    voice = np.zeros(len(bg), dtype=np.float32)
    for i, s in enumerate(segments):
        wav, sr = sf.read(tts_dir / f"{i:04d}.wav", dtype="float32")
        nxt = segments[i + 1]["start"] if i + 1 < len(segments) else s["end"] + 2
        slot = max(nxt - s["start"] - 0.05, s["end"] - s["start"])
        wav = fit_line(wav, sr, slot)
        a = int(s["start"] * SR)
        b = min(a + len(wav), len(voice))
        voice[a:b] += wav[:b - a]

    voice *= 0.9 / max(np.abs(voice).max(), 1e-6)
    out = bg * 0.8 + voice[:, None]
    out /= max(1.0, np.abs(out).max() / 0.98)
    dubbed = job / "dubbed.wav"
    sf.write(dubbed, out, SR)

    title_file = job / "title.txt"
    title = title_file.read_text(encoding="utf-8").strip().splitlines()[0] if title_file.exists() else job.name
    title = re.sub(r'[\\/:*?"<>|]', "_", title)[:80]
    OUT.mkdir(exist_ok=True)
    final = OUT / f"{title} [EN dub].mp4"
    write_srt(segments, final.with_suffix(".srt"))
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-i", str(dubbed),
         "-map", "0:v:0", "-map", "1:a:0", "-map", "0:a:0?", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
         "-metadata:s:a:0", "language=eng", "-metadata:s:a:0", "title=English dub",
         "-metadata:s:a:1", "language=jpn", "-metadata:s:a:1", "title=Japanese original",
         "-shortest", str(final)])
    return final


def write_srt(segments, path):
    def ts(t):
        h, m = int(t // 3600), int(t % 3600 // 60)
        return f"{h:02d}:{m:02d}:{t % 60:06.3f}".replace(".", ",")
    lines = [f"{i}\n{ts(s['start'])} --> {ts(s['end'])}\n{s['text']}\n" for i, s in enumerate(segments, 1)]
    path.write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------- main
def dub(url, threshold=0.35, exaggeration=0.6):
    torch = load_torch()
    job = job_dir(url)
    video = download(url, job)
    vocals, background = separate(video, job, torch)
    segments = transcribe(vocals, job, torch)
    if not segments:
        raise RuntimeError("No speech found in this video.")
    segments = assign_speakers(segments, vocals, job, threshold)
    tts_dir = synthesize(segments, job, torch, exaggeration)
    final = mix(segments, tts_dir, background, video, job)
    log(f"done -> {final}")
    return final


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Dub a Japanese anime video into English from a URL.")
    ap.add_argument("url")
    ap.add_argument("--speaker-threshold", type=float, default=0.35,
                    help="lower = more speakers split apart, higher = more lines merged into one voice")
    ap.add_argument("--exaggeration", type=float, default=0.6,
                    help="voice emotion intensity, 0.25 calm .. 1.0 very dramatic")
    a = ap.parse_args()
    dub(a.url, a.speaker_threshold, a.exaggeration)
