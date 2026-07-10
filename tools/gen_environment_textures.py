#!/usr/bin/env python3
"""Процедурные PNG-текстуры панельки (кафель, бетон, двери)."""
from __future__ import annotations
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures"
OUT.mkdir(parents=True, exist_ok=True)


def tile_floor(path: Path, size: int = 256) -> None:
    im = Image.new("RGB", (size, size), (140, 145, 150))
    d = ImageDraw.Draw(im)
    step = 32
    for y in range(0, size, step):
        for x in range(0, size, step):
            c = (150, 155, 160) if (x // step + y // step) % 2 == 0 else (130, 135, 140)
            d.rectangle([x, y, x + step - 2, y + step - 2], fill=c)
    im.save(path)


def concrete(path: Path, size: int = 256) -> None:
    im = Image.new("RGB", (size, size), (120, 120, 118))
    d = ImageDraw.Draw(im)
    x = 1
    for i in range(400):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        px, py = x % size, (x // size) % size
        v = 100 + (x % 40)
        d.point((px, py), fill=(v, v, v - 2))
    im.save(path)


def wallpaper(path: Path, size: int = 256) -> None:
    im = Image.new("RGB", (size, size), (185, 178, 165))
    d = ImageDraw.Draw(im)
    for y in range(0, size, 16):
        d.line([(0, y), (size, y)], fill=(170, 163, 150), width=1)
    im.save(path)


def door_wood(path: Path, size: int = 256) -> None:
    im = Image.new("RGB", (size, size), (95, 60, 40))
    d = ImageDraw.Draw(im)
    for x in range(0, size, 18):
        d.line([(x, 0), (x, size)], fill=(80, 50, 32), width=2)
    d.ellipse([size - 60, size // 2 - 10, size - 40, size // 2 + 10], fill=(180, 160, 60))
    im.save(path)


def dumpster_green(path: Path, size: int = 128) -> None:
    im = Image.new("RGB", (size, size), (40, 110, 55))
    d = ImageDraw.Draw(im)
    d.rectangle([10, 20, size - 10, size - 10], outline=(20, 70, 30), width=4)
    im.save(path)


def main() -> None:
    tile_floor(OUT / "tile.png")
    concrete(OUT / "concrete.png")
    wallpaper(OUT / "wall.png")
    door_wood(OUT / "door.png")
    dumpster_green(OUT / "dumpster.png")
    print("TEX_OK", OUT)


if __name__ == "__main__":
    main()
