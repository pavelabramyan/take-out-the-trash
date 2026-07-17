#!/usr/bin/env python3
"""Текстуры полиэтиленового пакета: albedo, roughness, normal-ish, seam mask."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "bag"
OUT.mkdir(parents=True, exist_ok=True)


def _noise(im: Image.Image, amp: int = 14, seed: int = 3) -> None:
    px = im.load()
    w, h = im.size
    x = seed
    for y in range(h):
        for i in range(w):
            x = (1103515245 * x + 12345) & 0x7FFFFFFF
            r, g, b = px[i, y][:3]
            d = (x % (amp * 2 + 1)) - amp
            px[i, y] = (
                max(0, min(255, r + d)),
                max(0, min(255, g + d)),
                max(0, min(255, b + d // 2)),
            ) + ((px[i, y][3],) if len(px[i, y]) > 3 else ())


def albedo(path: Path, size: int = 512, thin: bool = False) -> None:
    base = (36, 110, 58) if not thin else (48, 130, 72)
    im = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(im, "RGBA")
    # вертикальный шов
    cx = size // 2
    d.rectangle([cx - 3, 0, cx + 3, size], fill=(28, 80, 42, 180))
    d.line([(cx, 0), (cx, size)], fill=(20, 60, 30, 220), width=1)
    # складки
    x = 11
    for _ in range(40):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        x0 = x % size
        y0 = (x // 7) % size
        d.line([(x0, y0), (x0 + 8 + x % 20, y0 + 40 + x % 60)], fill=(30, 90, 48, 90), width=2)
    # жирные пятна
    for _ in range(25):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        cx2, cy = x % size, (x // size) % size
        rad = 6 + x % 22
        d.ellipse([cx2 - rad, cy - rad, cx2 + rad, cy + rad], fill=(24, 70, 40, 70))
    # потёртости у «углов»
    for ox in (40, size - 60):
        for oy in (size - 80, 30):
            d.ellipse([ox, oy, ox + 50, oy + 35], fill=(55, 95, 60, 100))
    im = im.convert("RGB")
    _noise(im, 10 if thin else 14, 5)
    if thin:
        im = ImageEnhance.Brightness(im).enhance(1.08)
    im.save(path)


def roughness(path: Path, size: int = 512) -> None:
    im = Image.new("L", (size, size), 200)
    d = ImageDraw.Draw(im)
    x = 77
    for _ in range(80):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        cx, cy = x % size, (x // 3) % size
        rad = 4 + x % 18
        # жир = ниже roughness (темнее в карте = ниже? в Godot roughness texture: white=rough)
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=140)
    # шов чуть глянцевее
    d.rectangle([size // 2 - 4, 0, size // 2 + 4, size], fill=170)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im.save(path)


def normal_proxy(path: Path, size: int = 512) -> None:
    """Псевдо-normal: складки как сине-фиолетовый bump."""
    im = Image.new("RGB", (size, size), (128, 128, 255))
    d = ImageDraw.Draw(im)
    x = 33
    for _ in range(50):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        x0, y0 = x % size, (x // 5) % size
        d.line([(x0, y0), (x0 + 12, y0 + 50)], fill=(110, 140, 255), width=3)
        d.line([(x0 + 2, y0), (x0 + 14, y0 + 50)], fill=(150, 120, 255), width=2)
    # шов
    d.line([(size // 2, 0), (size // 2, size)], fill=(100, 100, 255), width=4)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(path)


def tear_mask(path: Path, size: int = 512) -> None:
    """Белые точки на шве — будущие дыры (используем как albedo darken)."""
    im = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(im)
    cx = size // 2
    for i in range(12):
        y = 40 + i * 36
        d.ellipse([cx - 4, y - 3, cx + 4, y + 3], fill=255)
    im.save(path)


def main() -> None:
    albedo(OUT / "bag_albedo.png", thin=False)
    albedo(OUT / "bag_thin_albedo.png", thin=True)
    roughness(OUT / "bag_rough.png")
    normal_proxy(OUT / "bag_normal.png")
    tear_mask(OUT / "bag_tear.png")
    print("BAG_TEX_OK", OUT)


if __name__ == "__main__":
    main()
