#!/usr/bin/env python3
"""Генерация простых WAV для ВЫНЕСИ МУСОР! (без внешних зависимостей)."""
from __future__ import annotations
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SFX = ROOT / "assets" / "sfx"
MUSIC = ROOT / "assets" / "music"
SFX.mkdir(parents=True, exist_ok=True)
MUSIC.mkdir(parents=True, exist_ok=True)

SR = 22050


def write_wav(path: Path, samples: list[float], sr: int = SR) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), f"({len(samples)/sr:.2f}s)")


def tone(freq: float, dur: float, vol: float = 0.3, decay: bool = True) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = (1.0 - t / dur) if decay else 1.0
        out.append(math.sin(2 * math.pi * freq * t) * vol * env)
    return out


def noise(dur: float, vol: float = 0.2) -> list[float]:
    # LCG pseudo-noise
    n = int(SR * dur)
    out = []
    x = 1234567
    for i in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        v = (x / 0x7FFFFFFF) * 2 - 1
        env = 1.0 - (i / n)
        out.append(v * vol * env)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max(1e-6, max(abs(s) for s in out))
    return [s / peak * 0.85 for s in out]


def main() -> None:
    write_wav(SFX / "burst.wav", mix(noise(0.35, 0.5), tone(90, 0.25, 0.4)))
    write_wav(SFX / "pickup.wav", tone(520, 0.08, 0.25, True))
    write_wav(SFX / "dump.wav", mix(tone(140, 0.2, 0.35), noise(0.15, 0.2)))
    write_wav(SFX / "impact.wav", mix(noise(0.12, 0.45), tone(70, 0.1, 0.3)))
    write_wav(SFX / "slip.wav", mix(noise(0.4, 0.25), tone(200, 0.3, 0.15)))
    write_wav(SFX / "bark.wav", mix(tone(180, 0.12, 0.4), tone(120, 0.18, 0.35)))
    write_wav(SFX / "babushka.wav", mix(tone(280, 0.25, 0.3), tone(320, 0.2, 0.25)))
    # Мама орёт — пилообразный «крик»
    mom = []
    for i in range(int(SR * 0.9)):
        t = i / SR
        f = 380 + 80 * math.sin(t * 18)
        saw = (t * f) % 1.0 * 2 - 1
        env = min(1.0, t * 8) * max(0.0, 1.0 - (t - 0.5) * 2)
        mom.append(saw * 0.35 * env)
    write_wav(SFX / "mom.wav", mom)
    write_wav(SFX / "elevator.wav", mix(tone(440, 0.15, 0.2), tone(330, 0.2, 0.2)))
    write_wav(SFX / "win.wav", mix(tone(523, 0.15, 0.3), tone(659, 0.2, 0.28), tone(784, 0.35, 0.25)))

    # Короткий loop меню
    loop = []
    for i in range(SR * 4):
        t = i / SR
        s = (
            0.12 * math.sin(2 * math.pi * 110 * t)
            + 0.08 * math.sin(2 * math.pi * 164.8 * t)
            + 0.05 * math.sin(2 * math.pi * 220 * t)
        )
        # мягкий pulse
        s *= 0.7 + 0.3 * math.sin(2 * math.pi * 0.5 * t)
        loop.append(s)
    write_wav(MUSIC / "menu_loop.wav", loop)
    print("SFX_OK")


if __name__ == "__main__":
    main()
