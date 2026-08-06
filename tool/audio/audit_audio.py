"""Fail-fast audit for every shipped StatOz and Final Over WAV asset."""

from __future__ import annotations

import hashlib
import importlib.util
import math
import struct
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HOST_AUDIO = ROOT / "assets" / "audio"
FINAL_AUDIO = ROOT / "final_over" / "assets" / "audio"
HOST_MANIFEST = ROOT / "docs" / "audio" / "audio_manifest.yaml"
FINAL_MANIFEST = ROOT / "final_over" / "docs" / "AUDIO_ASSET_MANIFEST.md"
SIZE_LIMIT = 15 * 1024 * 1024


def _load_catalog() -> dict[str, object]:
    source = ROOT / "tool" / "audio" / "build_audio.py"
    spec = importlib.util.spec_from_file_location("build_audio", source)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load audio catalog")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.CUES


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _read_pcm(path: Path) -> tuple[list[int], float]:
    with wave.open(str(path), "rb") as wav:
        if wav.getnchannels() != 1:
            raise AssertionError(f"{path}: expected mono")
        if wav.getframerate() != 44_100:
            raise AssertionError(f"{path}: expected 44.1 kHz")
        if wav.getsampwidth() != 2:
            raise AssertionError(f"{path}: expected PCM16")
        if wav.getcomptype() != "NONE":
            raise AssertionError(f"{path}: expected uncompressed PCM")
        frames = wav.readframes(wav.getnframes())
        samples = list(struct.unpack(f"<{len(frames) // 2}h", frames))
        return samples, wav.getnframes() / wav.getframerate()


def _audit_file(
    path: Path,
    *,
    category: str,
    loop: bool,
    expected_duration: float | None,
) -> None:
    samples, duration = _read_pcm(path)
    if not samples:
        raise AssertionError(f"{path}: no samples")
    peak = max(abs(sample) for sample in samples) / 32768
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32768
    if rms < 10 ** (-55 / 20):
        raise AssertionError(f"{path}: silent/near-silent ({20 * math.log10(rms):.1f} dBFS)")
    if peak > 10 ** (-1 / 20) + 1 / 32768:
        raise AssertionError(f"{path}: peak exceeds -1 dBFS ({peak:.5f})")
    if any(abs(sample) >= 32767 for sample in samples):
        raise AssertionError(f"{path}: clipped sample")

    if expected_duration is not None and abs(duration - expected_duration) > .015:
        raise AssertionError(
            f"{path}: duration {duration:.3f}s != catalog {expected_duration:.3f}s"
        )
    bounds = {
        "ui": (.05, .7),
        "gameplay": (.08, 2.6),
        "reward": (.2, 3.0),
        "ambient": (2.0, 8.0),
    }[category]
    if not bounds[0] <= duration <= bounds[1]:
        raise AssertionError(f"{path}: {category} duration {duration:.3f}s out of range")
    if loop:
        seam_delta = abs(samples[0] - samples[-1]) / 32768
        if seam_delta > .035:
            raise AssertionError(f"{path}: loop seam delta {seam_delta:.4f}")


def main() -> None:
    catalog = _load_catalog()
    expected_host = {f"{stem}.wav" for stem in catalog}
    actual_host = {path.name for path in HOST_AUDIO.glob("*.wav")}
    if actual_host != expected_host:
        raise AssertionError(
            f"Host orphan/missing assets: missing={expected_host - actual_host}, "
            f"orphaned={actual_host - expected_host}"
        )

    expected_final = {
        "ui_tap.wav",
        "footstep.wav",
        "release.wav",
        "bounce.wav",
        "clean_hit.wav",
        "edge.wav",
        "roll.wav",
        "catch.wav",
        "stumps.wav",
        "throw.wav",
        "four_crowd.wav",
        "six_crowd.wav",
        "wicket.wav",
        "victory.wav",
        "defeat.wav",
        "ambience.wav",
    }
    actual_final = {path.name for path in FINAL_AUDIO.glob("*.wav")}
    if actual_final != expected_final:
        raise AssertionError(
            f"Final Over orphan/missing assets: missing={expected_final - actual_final}, "
            f"orphaned={actual_final - expected_final}"
        )

    hashes: dict[str, Path] = {}
    for stem, cue in catalog.items():
        path = HOST_AUDIO / f"{stem}.wav"
        _audit_file(
            path,
            category=cue.category,
            loop=cue.loop,
            expected_duration=cue.duration,
        )
        digest = _sha256(path)
        if digest in hashes:
            raise AssertionError(f"Duplicate semantic audio: {path} == {hashes[digest]}")
        hashes[digest] = path

    final_reward = {
        "four_crowd.wav",
        "six_crowd.wav",
        "wicket.wav",
        "victory.wav",
        "defeat.wav",
    }
    final_ui = {"ui_tap.wav"}
    for name in expected_final:
        _audit_file(
            FINAL_AUDIO / name,
            category=(
                "ambient"
                if name == "ambience.wav"
                else "reward"
                if name in final_reward
                else "ui"
                if name in final_ui
                else "gameplay"
            ),
            loop=name == "ambience.wav",
            expected_duration=None,
        )

    host_manifest = HOST_MANIFEST.read_text(encoding="utf-8")
    final_manifest = FINAL_MANIFEST.read_text(encoding="utf-8")
    for name in expected_host:
        if f"assets/audio/{name}" not in host_manifest:
            raise AssertionError(f"Unmanifested host asset: {name}")
    for name in expected_final:
        if f"assets/audio/{name}" not in final_manifest:
            raise AssertionError(f"Unmanifested Final Over asset: {name}")

    total = sum(path.stat().st_size for path in HOST_AUDIO.glob("*.wav")) + sum(
        path.stat().st_size for path in FINAL_AUDIO.glob("*.wav")
    )
    if total > SIZE_LIMIT:
        raise AssertionError(f"Audio is {total} bytes; limit is {SIZE_LIMIT}")
    print(
        f"Audio audit passed: {len(expected_host)} host + {len(expected_final)} "
        f"Final Over files, {total / 1024 / 1024:.2f} MiB shipped."
    )


if __name__ == "__main__":
    main()
