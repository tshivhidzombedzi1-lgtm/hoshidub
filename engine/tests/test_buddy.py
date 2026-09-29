import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import buddy as bd  # noqa: E402

PAST = [
    {"speaker": "Lufas", "text": "So this is Svel. It changed a lot in two hundred years."},
    {"speaker": "Dina", "text": "Mistress Lufas, the villagers say orcs have been raiding the farms."},
    {"speaker": "Lufas", "text": "Then we deal with the orcs first."},
]
FUTURE = ["Aries has attacked the capital!", "The devilfolk were manipulating Aries all along."]
CTX = {"title": "A Wild Last Boss Appeared!", "past": PAST, "future": FUTURE, "energy": 0.2}


def make(script=None, tmp=None):
    return bd.Buddy(bd.FakeBrain(script), bd.Memory(tmp / "memory.json"))


def test_character_file_loads_and_credits_the_creator():
    c = bd.load_character()
    assert c["name"] == "Hoshi"
    assert "MCP Labs" in c["intro"] and "Moss" in c["intro"]
    assert "{mood}" in c["system_prompt"]


def test_prompt_contains_the_past_but_never_the_future(tmp_path):
    b = make(tmp=tmp_path)
    b.ask("Who is Dina?", CTX)
    prompt = str(b.brain.calls[-1])
    assert "orcs have been raiding" in prompt and "Svel" in prompt
    assert "Aries" not in prompt and "devilfolk" not in prompt


def test_spoiler_shield_regenerates_a_reply_that_leaks_the_future(tmp_path):
    b = make(["I bet Aries shows up soon!", "The orcs are the real problem right now."], tmp_path)
    reply, _ = b.ask("What happens next?", CTX)
    assert reply == "The orcs are the real problem right now."
    assert len(b.brain.calls) == 2                       # first draft was rejected


def test_when_every_draft_spoils_she_says_she_doesnt_know(tmp_path):
    b = make(["Aries!", "The devilfolk did it.", "Aries again."], tmp_path)
    reply, _ = b.ask("Tell me the twist", CTX)
    assert "don't know yet" in reply


def test_words_the_viewer_used_are_not_spoilers(tmp_path):
    b = make(["Aries? No idea who that is yet."], tmp_path)
    reply, _ = b.ask("Who is Aries?", CTX)             # the viewer said it first: fine to repeat
    assert reply.startswith("Aries?")


def test_memory_learns_name_and_likes_and_stays_small(tmp_path):
    b = make(tmp=tmp_path)
    b.ask("My name is Moss and I really love fight scenes", CTX)
    for i in range(20):
        b.ask(f"question {i}", CTX)
    m = bd.Memory(tmp_path / "memory.json")             # persisted
    assert m.data["name"] == "Moss"
    assert any("fight scenes" in x for x in m.data["likes"])
    assert len(m.data["history"]) <= 8
    assert "Moss" in str(b.brain.calls[-1][0])          # the system prompt knows the viewer
    assert b.greet()[0].startswith("Welcome back, Moss")


def test_replies_are_cleaned_for_speaking():
    assert bd.clean_reply('Hoshi: "*grins* That was AMAZING! 🔥 Did you see it? Wow. Again."') == \
        "grins That was AMAZING! Did you see it?"
    assert bd.clean_reply("<think>hmm</think>Sure thing.") == "Sure thing."


def test_mood_follows_dialogue_and_audio_energy():
    moods = bd.load_character()["moods"]
    assert bd.mood_of([{"text": "Get ready to fight! This is the final battle!"}], 0.3, moods) == "hype"
    assert bd.mood_of([{"text": "I'm sorry... she died protecting us."}], 0.1, moods) == "sad"
    assert bd.mood_of([{"text": "Nice weather today."}], 0.1, moods) == "calm"
    assert bd.mood_of([{"text": "Nice weather today."}], 0.8, moods) == "hype"          # loud scene


def test_reactions_can_stay_quiet_and_are_rate_limited(tmp_path):
    b = make(["SKIP", "Dina is so protective, I love it."], tmp_path)
    assert b.react(CTX, min_gap=0)[0] is None
    first = b.react(CTX, min_gap=0)[0]
    assert first == "Dina is so protective, I love it."
    assert b.react(CTX, min_gap=120)[0] is None          # too soon after the last remark
