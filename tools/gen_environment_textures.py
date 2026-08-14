#!/usr/bin/env python3
"""Процедурные PNG — грязная панелька: зелёнка, плитка, фасад, асфальт."""
from __future__ import annotations

import math
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures"
OUT.mkdir(parents=True, exist_ok=True)


def _noise(im: Image.Image, amp: int = 18, seed: int = 1) -> None:
    px = im.load()
    w, h = im.size
    x = seed
    for y in range(h):
        for i in range(w):
            x = (1103515245 * x + 12345) & 0x7FFFFFFF
            r, g, b = px[i, y]
            d = (x % (amp * 2 + 1)) - amp
            px[i, y] = (
                max(0, min(255, r + d)),
                max(0, min(255, g + d)),
                max(0, min(255, b + d // 2)),
            )


def _stain(d: ImageDraw.ImageDraw, size: int, n: int = 40, seed: int = 7) -> None:
    x = seed
    for _ in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        cx, cy = x % size, (x // size) % size
        rad = 4 + (x % 28)
        a = 18 + (x % 40)
        col = (40 + x % 30, 35 + x % 25, 30 + x % 20, a)
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=col)


def tile_floor(path: Path, size: int = 512) -> None:
    im = Image.new("RGBA", (size, size), (118, 112, 105, 255))
    d = ImageDraw.Draw(im, "RGBA")
    step = 48
    for y in range(0, size, step):
        for x in range(0, size, step):
            odd = ((x // step) + (y // step)) % 2
            base = (132, 126, 118) if odd else (108, 102, 96)
            d.rectangle([x + 1, y + 1, x + step - 3, y + step - 3], fill=base + (255,))
            # грязь в швах
            d.rectangle([x, y, x + step, y + 2], fill=(70, 65, 58, 180))
            d.rectangle([x, y, x + 2, y + step], fill=(70, 65, 58, 160))
    _stain(d, size, 55, 11)
    # потёртости у «прохода»
    for i in range(80):
        xx = (i * 37) % size
        yy = size // 2 + (i * 13) % 40 - 20
        d.ellipse([xx, yy, xx + 6, yy + 3], fill=(90, 85, 78, 90))
    im = im.convert("RGB")
    _noise(im, 12, 3)
    im.save(path)


def concrete(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (128, 124, 118))
    d = ImageDraw.Draw(im, "RGBA")
    _noise(im, 22, 5)
    # трещины
    x = 99
    for _ in range(12):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        pts = []
        cx, cy = x % size, (x // 7) % size
        for k in range(8):
            x = (1103515245 * x + 12345) & 0x7FFFFFFF
            cx = (cx + (x % 17) - 8) % size
            cy = (cy + ((x // 17) % 17) - 8) % size
            pts.append((cx, cy))
        if len(pts) >= 2:
            d.line(pts, fill=(90, 88, 84, 160), width=1)
    _stain(ImageDraw.Draw(im.convert("RGBA"), "RGBA"), size, 30, 2)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    im.save(path)


def wallpaper(path: Path, size: int = 512) -> None:
    """Верх стены: выцветшая эмульсия с подтёками."""
    im = Image.new("RGBA", (size, size), (198, 188, 172, 255))
    d = ImageDraw.Draw(im, "RGBA")
    for y in range(0, size, 3):
        shade = 188 + (y % 7)
        d.line([(0, y), (size, y)], fill=(shade, shade - 8, shade - 20, 40))
    # подтёки
    x = 21
    for _ in range(25):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        sx = x % size
        for dy in range(40 + x % 80):
            a = max(0, 50 - dy // 2)
            d.point((sx, (x // size + dy) % size), fill=(150, 140, 120, a))
            d.point(((sx + 1) % size, (x // size + dy) % size), fill=(150, 140, 120, a // 2))
    _stain(d, size, 35, 9)
    im = im.convert("RGB")
    _noise(im, 10, 8)
    im.save(path)


def zelenka(path: Path, size: int = 512) -> None:
    """Масляная зелёнка/бирюза как на Нижегородской: грязь, сколы, потёки."""
    # Реф: читаемый teal (не почти-чёрный — иначе в сцене пропадает)
    im = Image.new("RGBA", (size, size), (42, 98, 90, 255))
    d = ImageDraw.Draw(im, "RGBA")
    for x in range(0, size, 3):
        c = 22 + (x * 2) % 18
        d.line([(x, 0), (x, size)], fill=(c, c + 38, c + 32, 40), width=2)
    # горизонтальные следы тряпки
    for y in range(0, size, 28):
        d.line([(0, y), (size, y + (y % 5) - 2)], fill=(20, 55, 50, 28), width=3)
    x = 44
    for _ in range(90):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        cx, cy = x % size, (x // size) % size
        w, h = 4 + x % 18, 3 + x % 10
        # скол до жёлтого бетона
        d.ellipse([cx, cy, cx + w, cy + h], fill=(155, 140, 110, 210))
    for _ in range(55):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        x0, y0 = x % size, (x // 3) % size
        d.line([(x0, y0), (x0 + 25 + x % 50, y0 + (x % 7) - 3)], fill=(18, 40, 36, 140), width=1)
    # тёмные потёки
    for i in range(18):
        x = (1103515245 * (i + 9) + 12345) & 0x7FFFFFFF
        sx = x % size
        for dy in range(50 + x % 70):
            a = max(0, 55 - dy // 2)
            d.point((sx, (x // size + dy) % size), fill=(15, 35, 30, a))
    d.rectangle([0, size - 22, size, size], fill=(22, 40, 36, 200))
    im = im.convert("RGB")
    _noise(im, 16, 12)
    im.save(path)


def panel_facade(path: Path, size: int = 512) -> None:
    """Наружная панель: швы, гравийная фактура."""
    im = Image.new("RGB", (size, size), (168, 158, 145))
    d = ImageDraw.Draw(im)
    _noise(im, 16, 15)
    # горизонтальный шов панели
    d.rectangle([0, size // 2 - 4, size, size // 2 + 4], fill=(120, 112, 100))
    d.line([(0, size // 2 - 5), (size, size // 2 - 5)], fill=(95, 90, 82), width=1)
    # вертикальный шов
    d.rectangle([size // 2 - 3, 0, size // 2 + 3, size], fill=(125, 118, 105))
    # ржавые потёки от крепежа
    for ox in (size // 4, 3 * size // 4):
        for dy in range(60):
            a = 40 - dy // 2
            if a > 0:
                d.point((ox, size // 2 + 8 + dy), fill=(110, 70, 50))
    im.save(path)


def door_wood(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (78, 52, 36))
    d = ImageDraw.Draw(im)
    for x in range(0, size, 14):
        d.line([(x, 0), (x, size)], fill=(62, 40, 28), width=2)
    # филёнка
    m = 40
    d.rectangle([m, m, size - m, size - m], outline=(55, 35, 25), width=6)
    d.rectangle([m + 20, m + 20, size - m - 20, size // 2 - 10], outline=(50, 32, 22), width=3)
    d.rectangle([m + 20, size // 2 + 10, size - m - 20, size - m - 20], outline=(50, 32, 22), width=3)
    # глазок
    d.ellipse([size // 2 - 14, size // 3 - 14, size // 2 + 14, size // 3 + 14], fill=(40, 40, 42))
    d.ellipse([size // 2 - 8, size // 3 - 8, size // 2 + 8, size // 3 + 8], fill=(20, 20, 22))
    # ручка
    d.ellipse([size - 90, size // 2 - 12, size - 55, size // 2 + 12], fill=(170, 150, 70))
    _noise(im, 10, 20)
    im.save(path)


def dumpster_green(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (36, 95, 48))
    d = ImageDraw.Draw(im)
    d.rectangle([8, 16, size - 8, size - 8], outline=(20, 60, 28), width=8)
    for y in range(30, size - 20, 22):
        d.line([(16, y), (size - 16, y)], fill=(28, 75, 38), width=3)
    _noise(im, 18, 22)
    # ржавчина / вмятины
    for _ in range(8):
        x = (1103515245 * (_ + 9) + 12345) & 0x7FFFFFFF
        cx, cy = x % size, (x // 7) % size
        d.ellipse([cx, cy, cx + 40, cy + 28], fill=(90, 55, 30))
    im.save(path)


def _rough_from_albedo(albedo: Path, out: Path) -> None:
    im = Image.open(albedo).convert("L")
    # Инверсия яркости → шероховатость (светлое = глаже)
    inv = Image.eval(im, lambda p: 220 - p // 3)
    inv.save(out)


def _normal_from_albedo(albedo: Path, out: Path, strength: float = 2.2) -> None:
    im = Image.open(albedo).convert("L")
    w, h = im.size
    src = im.load()
    nrm = Image.new("RGB", (w, h))
    dst = nrm.load()
    for y in range(h):
        for x in range(w):
            x0 = src[(x - 1) % w, y]
            x1 = src[(x + 1) % w, y]
            y0 = src[x, (y - 1) % h]
            y1 = src[x, (y + 1) % h]
            dx = (x0 - x1) * strength
            dy = (y0 - y1) * strength
            dz = 255.0
            length = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
            dst[x, y] = (
                int(128 + 127 * dx / length),
                int(128 + 127 * dy / length),
                int(128 + 127 * dz / length),
            )
    nrm.save(out)


def asphalt(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (55, 55, 58))
    _noise(im, 20, 30)
    d = ImageDraw.Draw(im)
    x = 77
    for _ in range(8):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        pts = []
        cx, cy = x % size, (x // 5) % size
        for k in range(10):
            x = (1103515245 * x + 12345) & 0x7FFFFFFF
            cx = (cx + (x % 25) - 12) % size
            cy = (cy + ((x // 11) % 20) - 10) % size
            pts.append((cx, cy))
        d.line(pts, fill=(40, 40, 42), width=2)
    im.save(path)


def stair_paint(path: Path, size: int = 512) -> None:
    """Охра в проходе, зелёнка по краям — как на Нижегородской."""
    im = Image.new("RGB", (size, size), (168, 148, 110))
    d = ImageDraw.Draw(im, "RGBA")
    _noise(im, 18, 41)
    edge = int(size * 0.22)
    for x in range(edge):
        for y in range(size):
            t = 1.0 - x / float(edge)
            teal = (38, 92, 82)
            och = im.getpixel((x, y))
            im.putpixel((x, y), tuple(int(och[i] * (1 - t) + teal[i] * t) for i in range(3)))
            im.putpixel((size - 1 - x, y), tuple(int(im.getpixel((size - 1 - x, y))[i] * (1 - t) + teal[i] * t) for i in range(3)))
    d = ImageDraw.Draw(im, "RGBA")
    for i in range(90):
        x = 80 + (i * 17) % (size - 160)
        y = (i * 29) % size
        d.ellipse([x, y, x + 8, y + 4], fill=(190, 168, 120, 140))
    for i in range(40):
        x = (i * 41) % size
        y = (i * 23) % size
        if x < edge or x > size - edge:
            d.ellipse([x, y, x + 10, y + 6], fill=(155, 140, 110, 200))
    d.rectangle([0, size - 40, size, size], fill=(70, 62, 52, 180))
    im = im.convert("RGB")
    _noise(im, 8, 42)
    im.save(path)


def dumpster_rust(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (92, 48, 28))
    d = ImageDraw.Draw(im)
    for i in range(30):
        sx = (i * 47) % size
        for dy in range(40 + i * 3):
            d.point((sx, (20 + dy) % size), fill=(60, 30, 16))
    for y in range(0, size, 18):
        d.line([(0, y), (size, y)], fill=(70, 38, 22), width=1)
    for y in range(24, size, 48):
        for x in range(24, size, 48):
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(40, 40, 42))
    for i in range(20):
        x = (i * 53) % size
        y = (i * 37) % size
        d.ellipse([x, y, x + 28, y + 16], fill=(36, 95, 48))
    _noise(im, 14, 55)
    im.save(path)


def tile_dirty(path: Path, size: int = 512) -> None:
    im = Image.new("RGBA", (size, size), (110, 104, 96, 255))
    d = ImageDraw.Draw(im, "RGBA")
    step = 48
    for y in range(0, size, step):
        for x in range(0, size, step):
            odd = ((x // step) + (y // step)) % 2
            base = (124, 116, 106) if odd else (98, 92, 84)
            d.rectangle([x + 2, y + 2, x + step - 3, y + step - 3], fill=base + (255,))
            d.rectangle([x, y, x + step, y + 3], fill=(48, 44, 38, 200))
            d.rectangle([x, y, x + 3, y + step], fill=(48, 44, 38, 180))
    for i in range(70):
        xx = (i * 31) % size
        yy = size // 2 + (i * 11) % 50 - 25
        d.ellipse([xx, yy, xx + 14, yy + 8], fill=(70, 64, 56, 90))
    im = im.convert("RGB")
    _noise(im, 10, 61)
    im.save(path)


def wool(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (110, 42, 48))
    d = ImageDraw.Draw(im)
    for y in range(0, size, 10):
        d.line([(0, y), (size, y)], fill=(95, 36, 42), width=2)
    for y in range(0, size, 8):
        for x in range(0, size, 8):
            if ((x // 8) + (y // 8)) % 2 == 0:
                d.rectangle([x, y, x + 7, y + 7], fill=(125, 50, 55))
    _noise(im, 12, 71)
    im.save(path)


def grass(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (90, 82, 48))
    d = ImageDraw.Draw(im)
    x = 13
    for _ in range(400):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        sx, sy = x % size, (x // 9) % size
        d.line([(sx, sy), (sx + (x % 3) - 1, sy - 6 - x % 8)], fill=(70, 78, 36), width=1)
    for i in range(18):
        x = (1103515245 * (i + 3) + 12345) & 0x7FFFFFFF
        cx, cy = x % size, (x // 5) % size
        d.ellipse([cx, cy, cx + 30, cy + 18], fill=(78, 62, 40))
    _noise(im, 14, 81)
    im.save(path)


def ice_tex(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (180, 190, 200))
    d = ImageDraw.Draw(im)
    _noise(im, 16, 91)
    x = 19
    for _ in range(10):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        pts = []
        cx, cy = x % size, (x // 6) % size
        for _k in range(8):
            x = (1103515245 * x + 12345) & 0x7FFFFFFF
            cx = (cx + (x % 20) - 10) % size
            cy = (cy + ((x // 9) % 16) - 8) % size
            pts.append((cx, cy))
        d.line(pts, fill=(140, 150, 160), width=1)
    im.save(path)


def graffiti(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (200, 190, 175))
    d = ImageDraw.Draw(im)
    _noise(im, 10, 101)
    d.line([(40, 180), (80, 80), (120, 180)], fill=(20, 20, 22), width=6)
    d.line([(80, 80), (80, 200)], fill=(20, 20, 22), width=5)
    d.ellipse([200, 90, 280, 170], outline=(18, 18, 20), width=5)
    d.line([(320, 200), (360, 70), (400, 200)], fill=(22, 22, 24), width=5)
    d.line([(430, 80), (430, 200)], fill=(22, 22, 24), width=5)
    d.line([(430, 80), (480, 80)], fill=(22, 22, 24), width=4)
    im.save(path)


def mail(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (78, 72, 58))
    d = ImageDraw.Draw(im)
    d.rectangle([40, 80, size - 40, size - 80], outline=(50, 46, 38), width=8)
    d.rectangle([80, 140, size - 80, 170], fill=(30, 28, 24))
    d.ellipse([size // 2 - 12, 220, size // 2 + 12, 244], fill=(40, 40, 42))
    _noise(im, 10, 111)
    im.save(path)


def paper_notice(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (200, 188, 150))
    d = ImageDraw.Draw(im)
    for i, y in enumerate((80, 130, 180, 230, 280)):
        d.rectangle([50, y, size - 50 - (i % 3) * 30, y + 14], fill=(90, 80, 60))
    d.rectangle([8, 8, 40, 28], fill=(160, 140, 90))
    d.rectangle([size - 40, 8, size - 8, 28], fill=(160, 140, 90))
    _noise(im, 8, 121)
    im.save(path)


def metal_door(path: Path, size: int = 512) -> None:
    im = Image.new("RGB", (size, size), (72, 74, 78))
    d = ImageDraw.Draw(im)
    for y in range(0, size, 8):
        d.line([(0, y), (size, y)], fill=(65, 67, 70), width=1)
    d.rectangle([30, 30, size - 30, size - 30], outline=(50, 52, 55), width=8)
    d.rectangle([size - 100, size // 2 - 18, size - 40, size // 2 + 18], fill=(40, 42, 45))
    d.ellipse([size - 85, size // 2 - 8, size - 55, size // 2 + 8], fill=(160, 140, 60))
    _noise(im, 12, 33)
    im.save(path)


def main() -> None:
    names = [
        "tile.png",
        "concrete.png",
        "wall.png",
        "zelenka.png",
        "panel.png",
        "door.png",
        "dumpster.png",
        "asphalt.png",
        "metal_door.png",
        "stair_paint.png",
        "dumpster_rust.png",
        "tile_dirty.png",
        "wool.png",
        "grass.png",
        "ice.png",
        "graffiti.png",
        "mail.png",
        "paper_notice.png",
    ]
    tile_floor(OUT / "tile.png")
    concrete(OUT / "concrete.png")
    wallpaper(OUT / "wall.png")
    zelenka(OUT / "zelenka.png")
    panel_facade(OUT / "panel.png")
    door_wood(OUT / "door.png")
    dumpster_green(OUT / "dumpster.png")
    asphalt(OUT / "asphalt.png")
    metal_door(OUT / "metal_door.png")
    stair_paint(OUT / "stair_paint.png")
    dumpster_rust(OUT / "dumpster_rust.png")
    tile_dirty(OUT / "tile_dirty.png")
    wool(OUT / "wool.png")
    grass(OUT / "grass.png")
    ice_tex(OUT / "ice.png")
    graffiti(OUT / "graffiti.png")
    mail(OUT / "mail.png")
    paper_notice(OUT / "paper_notice.png")
    for name in names:
        base = OUT / name
        stem = base.stem
        _rough_from_albedo(base, OUT / f"{stem}_rough.png")
        _normal_from_albedo(base, OUT / f"{stem}_normal.png")
    print("TEX_OK", OUT)


if __name__ == "__main__":
    main()
