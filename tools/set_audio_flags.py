#!/usr/bin/env python3
"""Флаги импорта звука: петли для шороха и музыки, чтобы цикл не щёлкал."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOOPED = {"rustle", "ambient_hall", "menu_loop", "game_loop", "danger_loop"}


def patch(imp: Path, loop: bool) -> bool:
    text = imp.read_text(encoding="utf-8")
    lines = text.splitlines()
    out: list[str] = []
    seen: set[str] = set()
    want = {
        "edit/loop_mode": "1" if loop else "0",
        "force/max_rate": "false",
        "compress/mode": "0",
    }
    in_params = False
    for line in lines:
        if line.startswith("[params]"):
            in_params = True
            out.append(line)
            continue
        key = line.split("=")[0].strip() if "=" in line else ""
        if in_params and key in want:
            out.append(f"{key}={want[key]}")
            seen.add(key)
            continue
        out.append(line)
    for key, val in want.items():
        if key not in seen:
            out.append(f"{key}={val}")
    new = "\n".join(out) + "\n"
    if new != text:
        imp.write_text(new, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = 0
    for folder in ["assets/sfx", "assets/music"]:
        for wav in sorted((ROOT / folder).glob("*.wav")):
            imp = wav.with_suffix(".wav.import")
            if not imp.exists():
                print(f"нет .import (нужен запуск Godot --import): {wav.name}")
                continue
            if patch(imp, wav.stem in LOOPED):
                changed += 1
                print(f"{wav.name}: loop={'да' if wav.stem in LOOPED else 'нет'}")
    print(f"AUDIO_FLAGS_OK changed={changed}")


if __name__ == "__main__":
    main()
