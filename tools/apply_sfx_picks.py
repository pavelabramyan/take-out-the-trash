#!/usr/bin/env python3
"""Копирует выбранные варианты из launch/sfx_picks/ в assets/sfx и assets/music.

    python3 tools/apply_sfx_picks.py dump=3 step=1 mom=4
    python3 tools/apply_sfx_picks.py --from launch/sfx_picks/picks.json
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PICKS = ROOT / "launch" / "sfx_picks"
MUSIC = {"menu_loop", "game_loop", "danger_loop", "ambient_hall"}
MUSIC_KIND = {"menu_loop": "menu", "game_loop": "game", "danger_loop": "danger", "ambient_hall": "ambient"}
MUSIC_DUR = {"menu": 16.0, "game": 20.0, "danger": 12.0, "ambient": 12.0}
MUSIC_PEAK = {"menu": 0.7, "game": 0.65, "danger": 0.7, "ambient": 0.55}


def apply(choices: dict[str, int]) -> None:
    sys.path.insert(0, str(Path(__file__).parent))
    import gen_sfx as g
    import gen_sfx_variants as v

    for key, n in choices.items():
        src = PICKS / key / f"{int(n)}.wav"
        if not src.exists():
            raise SystemExit(f"нет файла: {src}")
        dest_dir = ROOT / "assets" / ("music" if key in MUSIC else "sfx")
        dest = dest_dir / f"{key}.wav"
        shutil.copy2(src, dest)
        print(f"{key} ← вариант {n}")

    if int(choices.get("step", 0)) == 1:
        for i, name in enumerate(("footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003"), start=2):
            audio = v.fade(v.room(v.impact(name), 0.2))
            g.write(ROOT / "assets" / "sfx" / f"step{i}.wav", audio, peak=0.88)
            print(f"step{i} ← бетон {name}")

    if "mom" in choices:
        others = [i for i in (1, 5, 2) if i != int(choices["mom"])]
        shutil.copy2(PICKS / "mom" / f"{others[0]}.wav", ROOT / "assets" / "sfx" / "mom2.wav")
        shutil.copy2(PICKS / "mom" / f"{others[1]}.wav", ROOT / "assets" / "sfx" / "mom3.wav")
        print(f"mom2 ← вариант {others[0]}; mom3 ← вариант {others[1]}")

    for key, kind in MUSIC_KIND.items():
        if key not in choices:
            continue
        idx = int(choices[key]) - 1
        audio = v._music_preview(kind, idx, MUSIC_DUR[kind])
        g.write(ROOT / "assets" / "music" / f"{key}.wav", audio, peak=MUSIC_PEAK[kind])
        print(f"{key} ← полная петля варианта {choices[key]}")

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
