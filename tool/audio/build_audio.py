"""Build the StatOz cyber-broadcast audio catalog.

The shipped files are deliberately generated rather than hand-edited:

* sport timing, crowds, engines and reward stingers are deterministic synthesis;
* selected transient layers come from Kenney's CC0 Interface/Impact packs;
* every output is mono 44.1 kHz PCM16 WAV with a controlled peak;
* the generated manifest records provenance, hashes and intended use.

Requirements (build-time only):
    python -m pip install numpy soundfile

Run from the repository root:
    python tool/audio/build_audio.py
"""

from __future__ import annotations

import hashlib
import math
import subprocess
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets" / "audio"
DOCS = ROOT / "docs" / "audio"
MASTERS = ROOT / "tool" / "audio" / "masters" / "kenney"
SAMPLE_RATE = 44_100

INTERFACE = MASTERS / "interface" / "Audio"
IMPACT = MASTERS / "impact" / "Audio"


@dataclass(frozen=True)
class Cue:
    kind: str
    duration: float
    category: str = "gameplay"
    master: Path | None = None
    label: str = ""
    loop: bool = False


def _cue(
    kind: str,
    duration: float,
    category: str = "gameplay",
    master: Path | None = None,
    label: str = "",
    loop: bool = False,
) -> Cue:
    return Cue(kind, duration, category, master, label, loop)


def _interface(name: str) -> Path:
    return INTERFACE / name


def _impact(name: str) -> Path:
    return IMPACT / name


CUES: dict[str, Cue] = {
    # Shared UI and gratification language.
    "ui_tap": _cue("ui", .075, "ui", _interface("click_003.ogg"), "navigation tap"),
    "ui_confirm": _cue(
        "confirm", .22, "ui", _interface("confirmation_003.ogg"), "decisive confirmation"
    ),
    "ui_invalid": _cue(
        "error", .24, "ui", _interface("error_004.ogg"), "invalid or locked action"
    ),
    "card_select": _cue(
        "select", .12, "ui", _interface("select_006.ogg"), "card or answer selection"
    ),
    "play_match": _cue("launch", .48, "reward", None, "primary play CTA"),
    "attack": _cue(
        "attack", .28, "gameplay", _impact("impactPunch_medium_001.ogg"), "attack role"
    ),
    "defense": _cue(
        "defense", .28, "gameplay", _impact("impactMetal_light_003.ogg"), "defence role"
    ),
    "special": _cue("special", .46, "gameplay", _interface("glitch_002.ogg"), "special action"),
    "commit": _cue(
        "confirm", .26, "gameplay", _interface("confirmation_004.ogg"), "lock an action"
    ),
    "card_slam": _cue(
        "slam", .3, "gameplay", _impact("impactSoft_heavy_002.ogg"), "card/result landing"
    ),
    "card_reveal": _cue(
        "reveal", .38, "gameplay", _interface("open_003.ogg"), "card or verdict flip"
    ),
    "pack_open": _cue(
        "burst", .72, "reward", _interface("open_004.ogg"), "pack burst"
    ),
    "whoosh": _cue("whoosh", .42, "gameplay", None, "phase transition"),
    "riser": _cue("riser", .75, "gameplay", None, "tension rise"),
    "goal": _cue("goal", 1.05, "reward", None, "football goal"),
    "save": _cue(
        "save", .42, "gameplay", _impact("impactSoft_heavy_003.ogg"), "keeper save"
    ),
    "block": _cue(
        "block", .34, "gameplay", _impact("impactGeneric_light_004.ogg"), "blocked play"
    ),
    "miss": _cue("miss", .44, "gameplay", None, "missed chance"),
    "foul": _cue("whistle", .52, "gameplay", None, "foul or caution"),
    "red_card": _cue("alarm", .68, "reward", None, "red-card event"),
    "coin_flip": _cue(
        "spin", .55, "gameplay", _impact("impactMetal_light_000.ogg"), "coin spinning"
    ),
    "coin_land": _cue(
        "coin", .18, "gameplay", _impact("impactMetal_light_004.ogg"), "coin landing"
    ),
    "countdown_tick": _cue(
        "tick", .1, "ui", _interface("tick_004.ogg"), "countdown tick"
    ),
    "banner_slam": _cue(
        "slam", .44, "reward", _impact("impactPunch_heavy_004.ogg"), "result banner"
    ),
    "coins": _cue("coins", .62, "reward", None, "currency earned"),
    "coin_spend": _cue("spend", .38, "ui", None, "currency spent"),
    "level_up": _cue("level", 1.18, "reward", None, "level gained"),
    "achievement": _cue("unlock", .92, "reward", None, "achievement unlocked"),
    "streak": _cue("line", .78, "reward", None, "streak advanced"),
    "rarity_bronze": _cue("rarity1", .42, "reward", None, "bronze reveal"),
    "rarity_silver": _cue("rarity2", .62, "reward", None, "silver reveal"),
    "rarity_gold": _cue("rarity3", .9, "reward", None, "gold reveal"),
    "rarity_platinum": _cue("rarity4", 1.3, "reward", None, "platinum reveal"),
    "match_win": _cue("victory", 1.25, "reward", None, "generic victory"),
    "match_draw": _cue("draw", .88, "reward", None, "draw result"),
    "match_lose": _cue("defeat", 1.0, "reward", None, "generic defeat"),
    "cheering": _cue("crowd", 1.6, "reward", None, "generic crowd payoff"),

    # Final Over host cues.
    "cricket_footstep": _cue(
        "footstep", .15, "gameplay", _impact("footstep_grass_002.ogg"), "bowler run-up"
    ),
    "cricket_release": _cue("release", .19, "gameplay", None, "ball release"),
    "cricket_bounce": _cue(
        "bounce", .13, "gameplay", _impact("impactSoft_medium_002.ogg"), "pitch bounce"
    ),
    "cricket_perfect": _cue(
        "bat", .3, "gameplay", _impact("impactWood_heavy_001.ogg"), "perfect bat contact"
    ),
    "cricket_great": _cue(
        "bat", .27, "gameplay", _impact("impactWood_medium_003.ogg"), "strong bat contact"
    ),
    "cricket_good": _cue(
        "bat", .23, "gameplay", _impact("impactWood_light_004.ogg"), "controlled bat contact"
    ),
    "cricket_edge": _cue(
        "edge", .2, "gameplay", _impact("impactWood_light_001.ogg"), "bat edge"
    ),
    "cricket_keeper": _cue(
        "glove", .25, "gameplay", _impact("impactSoft_medium_004.ogg"), "keeper collection"
    ),
    "cricket_catch": _cue(
        "glove", .3, "gameplay", _impact("impactSoft_heavy_001.ogg"), "catch taken"
    ),
    "cricket_drop": _cue(
        "drop", .28, "gameplay", _impact("impactSoft_medium_001.ogg"), "catch dropped"
    ),
    "cricket_stumps": _cue(
        "clatter", .58, "reward", _impact("impactWood_heavy_004.ogg"), "stumps and bails"
    ),
    "cricket_run_out": _cue(
        "runout", .78, "reward", _impact("impactWood_heavy_002.ogg"), "run-out"
    ),
    "cricket_run": _cue("run", .22, "gameplay", None, "running between wickets"),
    "cricket_throw": _cue("throw", .3, "gameplay", None, "fielder throw"),
    "cricket_roll": _cue("roll", .5, "gameplay", None, "ball rolling"),
    "cricket_extra": _cue("extra", .3, "gameplay", None, "wide or no-ball"),
    "cricket_power": _cue("power", .78, "reward", None, "power shot activation"),
    "cricket_boundary": _cue("boundary4", 1.05, "reward", None, "four"),
    "cricket_six": _cue("boundary6", 1.3, "reward", None, "six"),
    "cricket_crowd_pressure": _cue(
        "pressure", 2.2, "gameplay", None, "final-ball pressure"
    ),
    "cricket_victory": _cue("cricket_win", 1.4, "reward", None, "successful chase"),
    "cricket_defeat": _cue("cricket_loss", 1.15, "reward", None, "failed chase"),

    # Tennis Rally.
    "tennis_serve": _cue("serve", .3, "gameplay", None, "serve"),
    "tennis_contact": _cue(
        "racket", .18, "gameplay", _impact("impactGeneric_light_002.ogg"), "racket contact"
    ),
    "tennis_perfect": _cue("perfect", .3, "gameplay", None, "perfect contact"),
    "tennis_bounce": _cue(
        "tennis_bounce", .11, "gameplay", _impact("impactSoft_medium_000.ogg"), "court bounce"
    ),
    "tennis_net": _cue(
        "net", .25, "gameplay", _impact("impactMetal_light_002.ogg"), "net cord"
    ),
    "tennis_let": _cue("let", .36, "gameplay", None, "let"),
    "tennis_fault": _cue("fault", .38, "gameplay", None, "fault"),
    "tennis_double_fault": _cue("doublefault", .58, "reward", None, "double fault"),
    "tennis_out": _cue("out", .34, "gameplay", None, "ball out"),
    "tennis_ace": _cue("ace", .92, "reward", None, "ace"),
    "tennis_winner": _cue("winner", .82, "reward", None, "winner"),
    "tennis_point": _cue("point", .25, "ui", None, "point awarded"),
    "tennis_game": _cue("game", .48, "reward", None, "game won"),
    "tennis_tiebreak": _cue("tiebreak", .75, "reward", None, "tiebreak start"),
    "tennis_end_change": _cue("endchange", .42, "ui", None, "change ends"),
    "tennis_set": _cue("set", .95, "reward", None, "set won"),
    "tennis_lesson": _cue("lesson", .92, "reward", None, "lesson complete"),
    "tennis_victory": _cue("tennis_win", 1.22, "reward", None, "tennis victory"),
    "tennis_defeat": _cue("tennis_loss", 1.0, "reward", None, "tennis defeat"),

    # Hoop Duel.
    "bb_dribble": _cue(
        "bb_bounce", .16, "gameplay", _impact("impactSoft_heavy_000.ogg"), "dribble"
    ),
    "bb_rebound": _cue(
        "bb_rebound", .3, "gameplay", _impact("impactSoft_heavy_004.ogg"), "rebound"
    ),
    "bb_release": _cue("bb_release", .2, "gameplay", None, "shot release"),
    "bb_perfect_release": _cue("perfect", .32, "gameplay", None, "perfect release"),
    "bb_swish": _cue("swish", .38, "gameplay", None, "clean basket"),
    "bb_rim_rattle": _cue(
        "rim", .55, "gameplay", _impact("impactMetal_medium_004.ogg"), "rim miss"
    ),
    "bb_backboard": _cue(
        "glass", .32, "gameplay", _impact("impactGlass_medium_001.ogg"), "backboard"
    ),
    "bb_block": _cue(
        "block", .36, "gameplay", _impact("impactGeneric_light_001.ogg"), "block"
    ),
    "bb_steal": _cue("steal", .3, "gameplay", None, "steal"),
    "bb_dunk_slam": _cue(
        "dunk", .82, "reward", _impact("impactPunch_heavy_001.ogg"), "dunk"
    ),
    "bb_poster": _cue("poster", .9, "reward", None, "poster play"),
    "bb_buzzer": _cue("buzzer", .92, "reward", None, "period horn"),
    "bb_shot_clock": _cue("shotclock", .58, "gameplay", None, "shot-clock violation"),
    "bb_crowd_roar": _cue("arena_crowd", 1.45, "reward", None, "arena roar"),
    "bb_heat_end": _cue("heatend", .52, "gameplay", None, "heat ended"),
    "bb_sneaker_squeak": _cue("squeak", .13, "gameplay", None, "hard court cut"),
    "bb_substitution": _cue("sub", .34, "ui", None, "substitution"),
    "bb_victory": _cue("bb_win", 1.28, "reward", None, "basketball victory"),
    "bb_defeat": _cue("bb_loss", 1.05, "reward", None, "basketball defeat"),

    # Grand Prix Dash.
    "gp_light_on": _cue("light", .12, "ui", _interface("tick_002.ogg"), "start light"),
    "gp_lights_out": _cue("lightsout", .48, "reward", None, "lights out"),
    "gp_jump_start": _cue("alarm", .65, "reward", None, "jump start"),
    "gp_overtake": _cue("overtake", .52, "gameplay", None, "overtake"),
    "gp_tire_scrub": _cue("scrub", .4, "gameplay", None, "tire scrub"),
    "gp_wall_impact": _cue(
        "crash", .62, "gameplay", _impact("impactMetal_heavy_003.ogg"), "wall impact"
    ),
    "gp_car_impact": _cue(
        "carhit", .46, "gameplay", _impact("impactMetal_medium_001.ogg"), "car contact"
    ),
    "gp_lap": _cue("lap", .55, "reward", None, "lap complete"),
    "gp_finish": _cue("finish", .85, "reward", None, "finish line"),
    "gp_podium": _cue("podium", 1.3, "reward", None, "podium"),
    "gp_points": _cue("points", .92, "reward", None, "points finish"),
    "gp_dnf": _cue("dnf", 1.0, "reward", None, "did not finish"),

    # Football Chess, Shootout, Bingo, Quiz and daily mysteries.
    "chess_move": _cue("move", .2, "ui", None, "board move"),
    "chess_dribble": _cue("dribble", .28, "gameplay", None, "board dribble"),
    "chess_pass": _cue("kick", .28, "gameplay", None, "board pass"),
    "chess_shoot": _cue("shoot", .35, "gameplay", None, "board shot"),
    "chess_press": _cue("press", .3, "gameplay", None, "press"),
    "chess_tackle": _cue(
        "tackle", .4, "gameplay", _impact("impactPunch_medium_004.ogg"), "tackle"
    ),
    "chess_slide": _cue(
        "slide", .48, "gameplay", _impact("impactSoft_medium_003.ogg"), "slide tackle"
    ),
    "chess_turnover": _cue("turnover", .45, "reward", None, "turnover"),
    "chess_advanced": _cue("advanced", .3, "gameplay", None, "advanced play"),
    "chess_full_time": _cue("fulltime", .72, "reward", None, "full-time whistle"),
    "penalty_target": _cue("target", .16, "ui", None, "penalty target"),
    "penalty_kick": _cue(
        "kick", .32, "gameplay", _impact("impactSoft_heavy_003.ogg"), "penalty kick"
    ),
    "penalty_dive": _cue("dive", .42, "gameplay", None, "keeper dive"),
    "penalty_goal": _cue("penalty_goal", 1.0, "reward", None, "shootout goal"),
    "penalty_save": _cue(
        "penalty_save", .72, "reward", _impact("impactSoft_heavy_001.ogg"), "shootout save"
    ),
    "penalty_sudden_death": _cue("pressure", 1.25, "reward", None, "sudden death"),
    "bingo_correct": _cue("correct", .36, "gameplay", None, "correct placement"),
    "bingo_wrong": _cue("error", .34, "gameplay", _interface("error_003.ogg"), "wrong cell"),
    "bingo_line": _cue("line", .72, "reward", None, "completed line"),
    "bingo_complete": _cue("bingo", 1.18, "reward", None, "completed grid"),
    "lifeline": _cue("lifeline", .68, "reward", None, "lifeline restored"),
    "quiz_submit": _cue("suspense", .68, "gameplay", None, "quiz grading"),
    "quiz_correct": _cue("correct", .3, "gameplay", None, "correct answer"),
    "quiz_wrong": _cue("wrong", .34, "gameplay", None, "wrong answer"),
    "quiz_pass": _cue("quizpass", .98, "reward", None, "quiz passed"),
    "quiz_fail": _cue("quizfail", .82, "reward", None, "quiz failed"),
    "quiz_perfect": _cue("perfectwin", 1.28, "reward", None, "perfect quiz"),
    "quiz_unlock": _cue("unlock", .9, "reward", None, "mode unlocked"),
    "mystery_lock": _cue("lock", .3, "gameplay", None, "mystery guess locked"),
    "mystery_wrong": _cue("damage", .45, "gameplay", None, "wrong mystery guess"),
    "mystery_duplicate": _cue("error", .22, "ui", _interface("error_001.ogg"), "duplicate guess"),
    "mystery_hint": _cue("decrypt", .7, "reward", _interface("glitch_003.ogg"), "hint decrypted"),
    "mystery_correct": _cue("identity", 1.08, "reward", None, "identity confirmed"),
    "mystery_lost": _cue("declassified", .9, "reward", None, "identity declassified"),
    "driver_static": _cue("static", .42, "gameplay", _interface("glitch_004.ogg"), "pit-wall damage"),
    "football_dossier_wrong": _cue("foul", .38, "gameplay", None, "football mystery miss"),
    "cricket_dossier_wrong": _cue("edge", .38, "gameplay", None, "cricket mystery miss"),
    "basketball_dossier_wrong": _cue("rim", .4, "gameplay", None, "basketball mystery miss"),
    "tennis_dossier_wrong": _cue("net", .38, "gameplay", None, "tennis mystery miss"),

    # Looping beds and the dynamic engine channel.
    "football_stadium": _cue("football_ambience", 6.0, "ambient", None, "football stadium", True),
    "cricket_stadium": _cue("cricket_ambience", 6.0, "ambient", None, "cricket stadium", True),
    "basketball_arena": _cue("basketball_ambience", 6.0, "ambient", None, "basketball arena", True),
    "tennis_court": _cue("tennis_ambience", 6.0, "ambient", None, "tennis court", True),
    "race_grid": _cue("race_ambience", 6.0, "ambient", None, "race grid", True),
    "gp_engine": _cue("engine", 3.0, "ambient", None, "speed-controlled race engine", True),
}

FINAL_OVER_USES = {
    "ui_tap.wav": "navigation and selection",
    "footstep.wav": "bowler run-up",
    "release.wav": "ball release",
    "bounce.wav": "pitch bounce and dropped catch",
    "clean_hit.wav": "graded clean bat contact",
    "edge.wav": "edge or mistimed contact",
    "roll.wav": "ball rolling through the field",
    "catch.wav": "catch or keeper collection",
    "stumps.wav": "bowled dismissal",
    "throw.wav": "fielder throw",
    "four_crowd.wav": "four crowd payoff",
    "six_crowd.wav": "six crowd payoff",
    "wicket.wav": "non-bowled wicket payoff",
    "victory.wav": "successful chase",
    "defeat.wav": "failed chase",
    "ambience.wav": "looping cricket-stadium bed",
}


def _rng(name: str) -> np.random.Generator:
    seed = int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "little")
    return np.random.default_rng(seed)


def _time(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE


def _lowpass(noise: np.ndarray, factor: float) -> np.ndarray:
    result = np.empty_like(noise)
    value = 0.0
    for index, sample in enumerate(noise):
        value += factor * (sample - value)
        result[index] = value
    return result


def _tone(t: np.ndarray, frequency: float, decay: float = 8.0) -> np.ndarray:
    attack = np.minimum(1.0, t * 180)
    return (
        np.sin(2 * np.pi * frequency * t)
        + .23 * np.sin(2 * np.pi * frequency * 2.01 * t)
    ) * np.exp(-decay * t) * attack


def _sweep(t: np.ndarray, start: float, end: float) -> np.ndarray:
    duration = max(t[-1], 1 / SAMPLE_RATE)
    phase = 2 * np.pi * (start * t + (end - start) * t * t / (2 * duration))
    return np.sin(phase) * np.sin(np.pi * np.clip(t / duration, 0, 1))


def _chord(t: np.ndarray, notes: list[float], rising: bool = True) -> np.ndarray:
    result = np.zeros_like(t)
    for index, note in enumerate(notes):
        start = index * (.09 if rising else .06)
        local = np.maximum(0, t - start)
        active = t >= start
        result += active * np.sin(2 * np.pi * note * local) * np.exp(-2.4 * local)
    return result / max(1, len(notes))


def _crowd(t: np.ndarray, rng: np.random.Generator, bright: bool = False) -> np.ndarray:
    noise = _lowpass(rng.uniform(-1, 1, len(t)), .045 if bright else .025)
    swell = np.minimum(1, t * 5) * np.exp(-.6 * np.maximum(0, t - .45))
    chants = (
        np.sin(2 * np.pi * (235 if bright else 170) * t)
        + .5 * np.sin(2 * np.pi * (319 if bright else 247) * t)
    ) * .035
    return (noise * 2.8 + chants) * swell


def _load_master(path: Path, duration: float) -> np.ndarray:
    data, rate = sf.read(path, always_2d=True, dtype="float64")
    mono = data.mean(axis=1)
    if rate != SAMPLE_RATE:
        target_length = max(1, round(len(mono) * SAMPLE_RATE / rate))
        mono = np.interp(
            np.linspace(0, 1, target_length, endpoint=False),
            np.linspace(0, 1, len(mono), endpoint=False),
            mono,
        )
    peak = np.max(np.abs(mono)) if len(mono) else 1
    mono = mono / max(peak, 1e-9)
    count = round(duration * SAMPLE_RATE)
    if len(mono) >= count:
        return mono[:count]
    return np.pad(mono, (0, count - len(mono)))


def _synth(name: str, cue: Cue) -> np.ndarray:
    t = _time(cue.duration)
    rng = _rng(name)
    noise = rng.uniform(-1, 1, len(t))
    low = _lowpass(noise, .04)
    kind = cue.kind
    base_frequency = 160 + (int(hashlib.md5(name.encode()).hexdigest()[:4], 16) % 260)

    if kind in {"ui", "select", "target", "move", "light", "tick"}:
        result = _tone(t, base_frequency + 520, 28) * .65
    elif kind in {"confirm", "correct", "point", "sub", "coin"}:
        result = _tone(t, base_frequency + 260, 16) * .55 + _tone(t, base_frequency + 610, 23) * .35
    elif kind in {"error", "wrong", "fault", "out", "miss", "spend", "dnf"}:
        result = _tone(t, max(95, base_frequency - 80), 10) * .65 - _tone(t, base_frequency + 60, 13) * .28
    elif kind in {"whoosh", "release", "throw", "dive", "bb_release", "overtake"}:
        result = _sweep(t, 1200, 170) * .65 + low * np.sin(np.pi * t / cue.duration) * .35
    elif kind in {"riser", "pressure", "suspense", "power"}:
        result = _sweep(t, 95, 980) * .45 + _crowd(t, rng, True) * .55
    elif kind in {"slam", "attack", "defense", "block", "save", "tackle", "crash", "carhit"}:
        result = _tone(t, base_frequency * .55, 18) * .72 + low * np.exp(-24 * t) * 1.8
    elif kind in {"bat", "kick", "shoot", "racket", "edge"}:
        result = _tone(t, base_frequency + 40, 25) * .65 + noise * np.exp(-55 * t) * .42
    elif kind in {"bounce", "tennis_bounce", "bb_bounce", "bb_rebound", "glove", "drop", "footstep"}:
        result = _tone(t, base_frequency, 32) * .55 + low * np.exp(-30 * t) * .9
    elif kind in {"rim", "glass", "clatter", "runout"}:
        result = (
            _tone(t, base_frequency + 430, 9) * .48
            + _tone(t, base_frequency + 810, 14) * .28
            + noise * np.exp(-35 * t) * .22
        )
    elif kind in {"net", "squeak", "scrub", "slide", "static", "damage", "decrypt"}:
        carrier = _sweep(t, 1350, 3200 if kind == "squeak" else 420)
        result = carrier * .48 + noise * np.exp(-8 * t) * .28
    elif kind in {"whistle", "foul", "let", "doublefault", "shotclock", "fulltime", "alarm"}:
        result = np.sign(np.sin(2 * np.pi * (760 if kind != "alarm" else 430) * t))
        result *= np.minimum(1, t * 80) * np.exp(-1.5 * t) * .45
    elif kind in {"spin", "coins"}:
        result = np.zeros_like(t)
        for index, offset in enumerate(np.linspace(0, cue.duration * .72, 5)):
            local = np.maximum(0, t - offset)
            result += (t >= offset) * _tone(local, 760 + index * 170, 24) * .36
    elif kind in {"run", "dribble", "roll", "press", "steal"}:
        pulse = .35 + .65 * np.square(np.sin(2 * np.pi * (12 + base_frequency / 70) * t))
        result = low * pulse * np.exp(-2.5 * t) * 1.2
    elif kind == "swish":
        result = noise * np.exp(-15 * t) * (.25 + .75 * np.square(np.sin(2 * np.pi * 2100 * t)))
    elif kind == "buzzer":
        result = (
            np.sign(np.sin(2 * np.pi * 435 * t)) * .42
            + np.sin(2 * np.pi * 652 * t) * .22
        ) * np.minimum(1, t * 45)
    elif kind in {"burst", "reveal", "launch", "special", "unlock", "lifeline", "line"}:
        result = _sweep(t, 180, 1500) * .44 + _chord(t, [440, 554, 659]) * .55 + low * .4
    elif kind.startswith("rarity"):
        rank = int(kind[-1])
        notes = [330, 440, 554, 659, 880][: rank + 1]
        result = _chord(t, notes) * (.65 + rank * .06) + _sweep(t, 240, 650 + rank * 220) * .28
    elif kind in {
        "victory", "level", "goal", "cricket_win", "tennis_win", "bb_win",
        "podium", "quizpass", "perfectwin", "identity", "bingo", "finish",
        "penalty_goal", "winner", "ace", "game", "set", "lesson",
    }:
        result = _chord(t, [392, 494, 587, 784]) * .68 + _crowd(t, rng, True) * .7
    elif kind in {
        "defeat", "cricket_loss", "tennis_loss", "bb_loss", "quizfail",
        "declassified", "draw", "points", "heatend", "endchange",
    }:
        result = _chord(t, [330, 294, 220], False) * .72 + low * np.exp(-1.8 * t) * .5
    elif kind in {"crowd", "arena_crowd", "boundary4", "boundary6", "poster", "dunk"}:
        result = _crowd(t, rng, kind in {"boundary6", "poster", "dunk"}) * .95
        if kind in {"poster", "dunk"}:
            result += _tone(t, 78, 7) * .65
    elif kind in {"extra", "tiebreak", "lap", "lightsout"}:
        result = _chord(t, [523, 659]) * .5 + _sweep(t, 260, 960) * .38
    elif kind in {"football_ambience", "cricket_ambience", "basketball_ambience", "tennis_ambience", "race_ambience"}:
        # Integer-period tones plus low, crossfaded texture keep the seam calm.
        duration = cue.duration
        low_texture = _lowpass(noise, .006)
        profile = {
            "football_ambience": (72, 180, .42),
            "cricket_ambience": (55, 225, .3),
            "basketball_ambience": (90, 285, .48),
            "tennis_ambience": (62, 330, .2),
            "race_ambience": (48, 145, .38),
        }[kind]
        f1, f2, texture = profile
        result = (
            np.sin(2 * np.pi * round(f1 * duration) / duration * t) * .08
            + np.sin(2 * np.pi * round(f2 * duration) / duration * t) * .025
            + low_texture * texture
        )
    elif kind == "engine":
        duration = cue.duration
        fundamental = round(92 * duration) / duration
        result = sum(
            np.sin(2 * np.pi * fundamental * harmonic * t) / harmonic
            for harmonic in range(1, 7)
        )
        result += _lowpass(noise, .025) * .16
    else:
        result = _tone(t, base_frequency, 9) * .55 + low * .4

    if cue.master is not None:
        if not cue.master.exists():
            raise FileNotFoundError(
                f"Missing CC0 master {cue.master}. Download the Kenney packs first."
            )
        master = _load_master(cue.master, cue.duration)
        result = result * .7 + master * .3
    return result


def _master_audio(samples: np.ndarray, cue: Cue) -> np.ndarray:
    samples = np.nan_to_num(samples.astype(np.float64))
    samples -= samples.mean()
    if not cue.loop:
        fade = min(len(samples) // 4, round(.008 * SAMPLE_RATE))
        if fade:
            samples[:fade] *= np.linspace(0, 1, fade)
            samples[-fade:] *= np.linspace(1, 0, fade)
    else:
        seam = min(len(samples) // 6, round(.35 * SAMPLE_RATE))
        if seam:
            blend = np.linspace(0, 1, seam)
            seam_target = np.linspace(samples[-seam], samples[0], seam)
            samples[-seam:] = samples[-seam:] * (1 - blend) + seam_target * blend
    peak_targets = {"ui": .42, "gameplay": .72, "reward": .89, "ambient": .13}
    loudness_targets = {"ui": -22, "gameplay": -18, "reward": -16, "ambient": -30}
    rms = float(np.sqrt(np.mean(samples * samples))) if len(samples) else 0
    if rms < 1e-9:
        raise ValueError("Generated silence")
    samples *= 10 ** (loudness_targets[cue.category] / 20) / rms
    peak = float(np.max(np.abs(samples)))
    if peak > peak_targets[cue.category]:
        samples *= peak_targets[cue.category] / peak
    return samples


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _build_final_over() -> int:
    package = ROOT / "final_over"
    dart = ROOT / "flutter" / "bin" / (
        "dart.bat" if (ROOT / "flutter" / "bin" / "dart.bat").exists() else "dart"
    )
    subprocess.run(
        [str(dart), "run", "tool/generate_audio.dart"],
        cwd=package,
        check=True,
    )

    audio = package / "assets" / "audio"
    docs = package / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    rows = [
        "# Final Over Clean-Room Audio Manifest",
        "",
        "Generated by `python tool/audio/build_audio.py` via "
        "`final_over/tool/generate_audio.dart`.",
        "",
        "All 16 files are original deterministic synthesis created for Final Over. "
        "They contain no speech, commentary, music, chants, trademarks, or "
        "third-party recordings.",
        "",
        "| Asset | Intended use | Duration | Loop | SHA-256 |",
        "|---|---|---:|:---:|---|",
    ]
    for name, intended_use in FINAL_OVER_USES.items():
        path = audio / name
        info = sf.info(path)
        rows.append(
            f"| `assets/audio/{name}` | {intended_use} | "
            f"{info.duration:.3f}s | {'yes' if name == 'ambience.wav' else 'no'} | "
            f"`{_sha256(path)}` |"
        )
    rows.extend(
        [
            "",
            "License/provenance: project-owned original clean-room synthesis. "
            "No attribution is required.",
            "",
        ]
    )
    (docs / "AUDIO_ASSET_MANIFEST.md").write_text(
        "\n".join(rows), encoding="utf-8"
    )
    return sum(path.stat().st_size for path in audio.glob("*.wav"))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    expected = {f"{stem}.wav" for stem in CUES}
    for stale in OUTPUT.glob("*.wav"):
        if stale.name not in expected:
            stale.unlink()

    manifest_rows: list[str] = [
        "version: 1",
        "project: StatOz / Pitch Duel",
        "policy: cc0-plus-original-synthesis",
        "sample_rate_hz: 44100",
        "channels: 1",
        "encoding: PCM_16",
        "assets:",
    ]
    catalog_rows = [
        "# Audio Cue Catalog",
        "",
        "Generated by `python tool/audio/build_audio.py`.",
        "",
        "| Asset | Use | Category | Duration | Provenance |",
        "|---|---|---:|---:|---|",
    ]
    generator_hash = _sha256(Path(__file__))

    for stem, cue in sorted(CUES.items()):
        samples = _master_audio(_synth(stem, cue), cue)
        output = OUTPUT / f"{stem}.wav"
        sf.write(output, samples, SAMPLE_RATE, subtype="PCM_16")
        provenance = (
            f"Kenney CC0 `{cue.master.name}` + original deterministic synthesis"
            if cue.master is not None
            else "original deterministic synthesis"
        )
        duration = len(samples) / SAMPLE_RATE
        manifest_rows.extend(
            [
                f"  - path: assets/audio/{output.name}",
                f"    use: {cue.label or stem}",
                f"    category: {cue.category}",
                f"    duration_seconds: {duration:.3f}",
                f"    loop: {'true' if cue.loop else 'false'}",
                f"    provenance: {provenance}",
                "    creator: StatOz audio pipeline"
                + (" + Kenney" if cue.master is not None else ""),
                "    license: project-owned-original"
                + (" + CC0-1.0" if cue.master is not None else ""),
                "    source_url: "
                + (
                    "https://kenney.nl/assets/interface-sounds"
                    if cue.master is not None and cue.master.parent == INTERFACE
                    else "https://kenney.nl/assets/impact-sounds"
                    if cue.master is not None
                    else "local://tool/audio/build_audio.py"
                ),
                f"    generator_sha256: {generator_hash}",
                "    source_sha256: "
                + (_sha256(cue.master) if cue.master is not None else generator_hash),
                "    edits: mono mix, DC removal, trim/fade, category normalization, "
                "peak cap, PCM16 WAV conversion",
                f"    output_sha256: {_sha256(output)}",
            ]
        )
        catalog_rows.append(
            f"| `{output.name}` | {cue.label or stem} | {cue.category} | "
            f"{duration:.2f}s | {provenance} |"
        )

    manifest_rows.extend(
        [
            "sources:",
            "  - name: Kenney Interface Sounds 1.0",
            "    url: https://kenney.nl/assets/interface-sounds",
            "    license: CC0-1.0",
            "  - name: Kenney Impact Sounds 1.0",
            "    url: https://kenney.nl/assets/impact-sounds",
            "    license: CC0-1.0",
            "constraints:",
            "  - no speech, commentary, team chants, licensed music, or trademarks",
            "  - source masters under tool/audio are excluded from Flutter assets",
        ]
    )
    (DOCS / "audio_manifest.yaml").write_text(
        "\n".join(manifest_rows) + "\n", encoding="utf-8"
    )
    (DOCS / "CUE_CATALOG.md").write_text(
        "\n".join(catalog_rows) + "\n", encoding="utf-8"
    )

    final_over_total = _build_final_over()
    host_total = sum(path.stat().st_size for path in OUTPUT.glob("*.wav"))
    total = host_total + final_over_total
    if total > 15 * 1024 * 1024:
        raise ValueError(f"Shipped audio exceeds 15 MiB: {total} bytes")
    print(
        f"Generated {len(CUES)} host cues plus 16 Final Over cues "
        f"({total / 1024 / 1024:.2f} MiB shipped)."
    )


if __name__ == "__main__":
    main()
