"""Hoshi, the watch buddy. The pipeline follows Project Riko (github.com/rayenfeng/riko_project, MIT):
listen -> understand -> reply in character -> speak. Rebuilt for Otodub to run free on the user's own GPU and to
know the show:

  * brain     a local 4-bit Qwen3-4B-Instruct (Apache-2.0) instead of a paid cloud API
  * grounding the episode's official subtitles up to *now*, speaker names and the show's description
  * shield    replies are checked against the episode's *future* lines and regenerated if they would spoil it
  * memory    a small profile (name, likes, shows) instead of an ever-growing chat log
  * moods     the scene's mood (from the dialogue and the audio's energy) steers her tone
"""
import json
import os
import re
import threading
import time
from pathlib import Path

import numpy as np

import packs

HERE = Path(__file__).resolve().parent
CHARACTER_FILE = HERE / "character" / "hoshi.yaml"
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")
WORD = re.compile(r"[A-Za-z][A-Za-z'-]{3,}")
COMMON = set("""that this with have from they what when your just will would there their about been were them then than
could should which while where these those into over after before again still really going gonna want know think like
yeah okay right come look make take give tell said says well even only also much very some more most other such here
because thing things something nothing anything everyone someone people time today tonight never always maybe
please thank thanks sorry hello does done doing being""".split())


def load_character(path=CHARACTER_FILE):
    import yaml
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


# ---------------------------------------------------------------- mood
def mood_of(lines, energy, words_by_mood):
    """Scene mood from the last few lines of dialogue and how loud the scene is (0..1)."""
    text = " ".join(l.get("text", "") for l in lines[-6:]).lower()
    scores = {m: sum(text.count(w) for w in ws) for m, ws in words_by_mood.items()}
    scores["hype"] = scores.get("hype", 0) + (1.5 if energy > 0.6 else 0)
    scores["tense"] = scores.get("tense", 0) + (0.5 if 0.35 < energy <= 0.6 else 0)
    best = max(scores, key=scores.get) if scores else "calm"
    return best if scores.get(best, 0) >= 1 else "calm"


# ---------------------------------------------------------------- memory
class Memory:
    """A compact profile of the viewer, plus the last few exchanges. Stays small forever."""

    def __init__(self, path):
        self.path = Path(path)
        self.data = {"name": "", "likes": [], "shows": [], "history": []}
        try:
            self.data.update(json.loads(self.path.read_text(encoding="utf-8")))
        except Exception:
            pass

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.data, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(self.path)

    def learn(self, said):
        """Pick up facts the viewer states about themselves."""
        m = re.search(r"\b(?:my name is|call me|i'm called)\s+([A-Z][a-z]+|[a-z]+)\b", said, re.I)
        if m:
            self.data["name"] = m.group(1).capitalize()
        for m in re.finditer(r"\bi (?:really )?(?:love|like|adore)\s+([^.,!?]{2,40})", said, re.I):
            thing = m.group(1).strip()
            if thing.lower() not in (x.lower() for x in self.data["likes"]):
                self.data["likes"] = (self.data["likes"] + [thing])[-20:]

    def watched(self, title):
        if title and title not in self.data["shows"]:
            self.data["shows"] = (self.data["shows"] + [title])[-30:]

    def remember_turn(self, user, reply):
        self.data["history"] = (self.data["history"] + [{"user": user, "hoshi": reply}])[-8:]

    def forget(self):
        self.data = {"name": "", "likes": [], "shows": [], "history": []}
        self.save()

    def facts(self):
        d = self.data
        out = []
        if d["name"]:
            out.append(f"The viewer's name is {d['name']}.")
        if d["likes"]:
            out.append("They like: " + "; ".join(d["likes"][-8:]) + ".")
        if d["shows"]:
            out.append("Shows you've watched together: " + ", ".join(d["shows"][-8:]) + ".")
        return " ".join(out)


# ---------------------------------------------------------------- spoiler shield
def spoiler_words(past, future, extra=""):
    """Distinctive words that only appear in lines that haven't happened yet."""
    known = {w.lower() for w in WORD.findall(" ".join(past) + " " + extra)}
    ahead = {}
    for line in future:
        for w in WORD.findall(line):
            lw = w.lower()
            if lw in known or lw in COMMON:
                continue
            ahead[lw] = ahead.get(lw, 0) + 1
    return set(ahead)


def spoils(reply, danger):
    return sorted({w.lower() for w in WORD.findall(reply)} & danger)


def clean_reply(text, limit=2):
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S)
    text = EMOJI.sub("", text)
    text = re.sub(r"[*_#`>\[\]]", "", text)
    text = re.sub(r"^(hoshi|assistant)\s*:\s*", "", text.strip(), flags=re.I)
    text = text.strip().strip('"').strip()
    sentences = re.split(r"(?<=[.!?])\s+", text)
    return " ".join(sentences[:limit]).strip()


# ---------------------------------------------------------------- brains
class LocalBrain:
    """Qwen3-4B-Instruct-2507 in 4-bit on the GPU. ~3 GB of VRAM; a reply takes about a second."""

    def __init__(self):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
        folder = packs.brain_dir()
        if not (folder / "model.safetensors").exists():
            raise FileNotFoundError("Hoshi's brain isn't downloaded")
        self.torch = torch
        self.tok = AutoTokenizer.from_pretrained(str(folder))
        self.model = AutoModelForCausalLM.from_pretrained(str(folder), device_map="cuda" if torch.cuda.is_available() else "cpu")
        self.model.eval()
        self.lock = threading.Lock()
        self.generate([{"role": "user", "content": "Say hi."}], 4)          # warm up

    def generate(self, messages, max_new_tokens=90, temperature=0.8):
        with self.lock, self.torch.inference_mode():
            prompt = self.tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
            ids = self.tok(prompt, return_tensors="pt").to(self.model.device)
            out = self.model.generate(**ids, max_new_tokens=max_new_tokens, do_sample=True, temperature=temperature,
                                      top_p=0.9, repetition_penalty=1.08, pad_token_id=self.tok.eos_token_id)
            return self.tok.decode(out[0][ids["input_ids"].shape[1]:], skip_special_tokens=True)


class FakeBrain:
    """Deterministic stand-in so tests exercise everything around the model quickly."""

    def __init__(self, script=None):
        self.script = list(script or [])
        self.calls = []

    def generate(self, messages, max_new_tokens=90, temperature=0.8):
        self.calls.append(messages)
        if self.script:
            return self.script.pop(0)
        q = messages[-1]["content"]
        return f"Reply to: {q[-60:]}"


# ---------------------------------------------------------------- Hoshi
class Buddy:
    def __init__(self, brain, memory, character=None):
        self.brain = brain
        self.memory = memory
        self.char = character or load_character()
        self.last_react = 0.0

    def context_block(self, ctx):
        past = ctx.get("past", [])[-30:]
        lines = "\n".join(f"{l.get('speaker') or 'Someone'}: {l.get('text', '')}" for l in past) or "(nothing yet)"
        show = ctx.get("title") or "an anime episode"
        about = (ctx.get("about") or "").strip()
        return (f"Show: {show}\n" + (f"About the show: {about[:400]}\n" if about else "")
                + f"What has happened so far (most recent last):\n{lines}")

    def messages(self, ctx, user_turn, mood):
        system = self.char["system_prompt"].replace("{mood}", mood)
        facts = self.memory.facts()
        if facts:
            system += "\nWhat you remember about the viewer: " + facts
        msgs = [{"role": "system", "content": system}]
        for h in self.memory.data["history"][-4:]:
            msgs += [{"role": "user", "content": h["user"]}, {"role": "assistant", "content": h["hoshi"]}]
        msgs.append({"role": "user", "content": f"{self.context_block(ctx)}\n\n{user_turn}"})
        return msgs

    def _answer(self, ctx, user_turn, mood, max_tokens, reacting=False):
        past = [l.get("text", "") for l in ctx.get("past", [])]
        danger = spoiler_words(past, ctx.get("future", []), extra=user_turn + " " + (ctx.get("about") or ""))
        for attempt in range(3):
            turn = user_turn if attempt == 0 else (
                user_turn + "\n(Answer again using only what has already happened. Do not mention anything else.)")
            raw = self.brain.generate(self.messages(ctx, turn, mood), max_tokens)
            reply = clean_reply(raw)
            if reacting and (not reply or reply.upper().startswith("SKIP")):
                return None
            if reply and not spoils(reply, danger):
                return reply
        return None

    def ask(self, question, ctx):
        """The viewer asked something (typed or spoken). Always returns something to say."""
        self.memory.learn(question)
        self.memory.watched(ctx.get("title"))
        mood = mood_of(ctx.get("past", []), ctx.get("energy", 0), self.char["moods"])
        reply = self._answer(ctx, question, mood, 90)
        if reply is None:
            reply = "I honestly don't know yet, and I'm dying to find out too."
        self.memory.remember_turn(question, reply)
        self.memory.save()
        return reply, mood

    def react(self, ctx, min_gap=120):
        """A short remark in a quiet moment, at most every `min_gap` seconds. None = stay quiet."""
        if time.time() - self.last_react < min_gap or len(ctx.get("past", [])) < 3:
            return None, "calm"
        mood = mood_of(ctx.get("past", []), ctx.get("energy", 0), self.char["moods"])
        turn = ("React to what just happened in ONE short sentence, like a friend watching with me. "
                "If nothing interesting just happened, reply with exactly SKIP.")
        reply = self._answer(ctx, turn, mood, 40, reacting=True)
        if reply:
            self.last_react = time.time()
        return reply, mood

    def greet(self):
        name = self.memory.data.get("name")
        return (f"Welcome back, {name}! Ready when you are." if name else self.char["intro"]), "calm"


def load_buddy(memory_dir):
    """Hoshi with the real brain if her pack is installed, else None (the app offers the download)."""
    if os.environ.get("KOE_BUDDY_FAKE"):
        return Buddy(FakeBrain(), Memory(Path(memory_dir) / "memory.json"))
    return Buddy(LocalBrain(), Memory(Path(memory_dir) / "memory.json"))
