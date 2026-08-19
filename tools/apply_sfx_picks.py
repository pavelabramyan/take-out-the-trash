#!/usr/bin/env python3
"""Копирует выбранные варианты из launch/sfx_picks/ в assets/sfx и assets/music.

    python3 tools/apply_sfx_picks.py dump=3 step=1 mom=4
    python3 tools/apply_sfx_picks.py --from launch/sfx_picks/picks.json
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PICKS = ROOT / "launch" / "sfx_picks"
MUSIC = {"menu_loop", "game_loop", "danger_loop", "ambient_hall"}


def apply(choices: dict[str, int]) -> None:
    for key, n in choices.items():
        src = PICKS / key / f"{int(n)}.wav"
        if not src.exists():
            raise SystemExit(f"нет файла: {src}")
        dest_dir = ROOT / "assets" / ("music" if key in MUSIC else "sfx")
        dest = dest_dir / f"{key}.wav"
        shutil.copy2(src, dest)
        print(f"{key} ← вариант {n}")
    print("APPLY_OK — перезапусти игру, чтобы услышать.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", default=None)
    ap.add_argument("pairs", nargs="*")
    args = ap.parse_args()
    choices: dict[str, int] = {}
    if args.src:
        choices.update({k: int(v) for k, v in json.loads(Path(args.src).read_text()).items()})
    for pair in args.pairs:
        k, v = pair.split("=", 1)
        choices[k] = int(v)
    if not choices:
        raise SystemExit("укажи dump=3 step=1 … или --from picks.json")
    apply(choices)


if __name__ == "__main__":
    main()
