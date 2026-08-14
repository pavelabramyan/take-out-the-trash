#!/usr/bin/env python3
"""Правит .import у 3D-текстур: мипмапы, VRAM-сжатие, режим нормалей.

Godot включает мипмапы только когда редактор сам замечает текстуру в 3D
(detect_3d), а мы собираем материалы из кода — поэтому флаги ставим руками,
иначе дальние поверхности рябят, а VRAM забивается несжатыми картами.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET_DIRS = [ROOT / "assets" / "pbr", ROOT / "assets" / "models"]
NORMAL_HINT = ("normal", "_nor_gl", "_nor_dx")
# ORM/AO/roughness — данные, не цвет: сжатие и мипмапы те же, но без srgb-хинтов
DATA_HINT = ("orm", "_arm", "rough", "_ao")


def patch(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    name = path.name.lower()
    is_normal = any(h in name for h in NORMAL_HINT)
    wanted = {
        "compress/mode": "2",
        "compress/high_quality": "true" if is_normal else "false",
        "mipmaps/generate": "true",
        "compress/normal_map": "1" if is_normal else "0",
        "detect_3d/compress_to": "0",
    }
    out = text
    for key, val in wanted.items():
        pattern = rf"^{re.escape(key)}=.*$"
        if re.search(pattern, out, flags=re.M):
            out = re.sub(pattern, f"{key}={val}", out, flags=re.M)
        else:
            out = out.rstrip("\n") + f"\n{key}={val}\n"
    if out == text:
        return False
    path.write_text(out, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    total = 0
    for base in TARGET_DIRS:
        if not base.exists():
            continue
        for imp in sorted(base.rglob("*.import")):
            src = imp.with_suffix("")
            if src.suffix.lower() not in (".webp", ".jpg", ".jpeg", ".png"):
                continue
            total += 1
            if patch(imp):
                changed += 1
    print(f"IMPORT_FLAGS_OK изменено={changed} из={total}")
    if changed:
        # .godot/imported кэш надо сбросить, иначе Godot не пересоберёт .ctex
        print("нужен повторный запуск Godot --import")


if __name__ == "__main__":
    main()
