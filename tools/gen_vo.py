#!/usr/bin/env python3
"""Голос мамы — отдельный клип (дублирует gen_sfx mom для пайплайна)."""
from gen_sfx import write_wav, SFX, SR
import math


def main() -> None:
    mom = []
    phrase_len = int(SR * 1.1)
    for i in range(phrase_len):
        t = i / SR
        f = 360 + 100 * math.sin(t * 22) + 40 * math.sin(t * 7)
        saw = ((t * f) % 1.0) * 2 - 1
        env = min(1.0, t * 10) * max(0.0, 1.0 - max(0.0, t - 0.7) * 3)
        mom.append(saw * 0.4 * env)
    write_wav(SFX / "mom.wav", mom)
    print("VO_OK")


if __name__ == "__main__":
    main()
