#!/usr/bin/env python3
"""Заглушки Steam-капсул и скриншотов (процедурные). Заменить геймплейными кадрами перед релизом."""
from __future__ import annotations
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAP = ROOT / "marketing" / "capsule"
SHOTS = ROOT / "marketing" / "shots"
CLIP = ROOT / "marketing" / "clip"
for d in (CAP, SHOTS, CLIP):
    d.mkdir(parents=True, exist_ok=True)


def capsule(path: Path, size: tuple[int, int], title: str) -> None:
    im = Image.new("RGB", size, (28, 36, 28))
    d = ImageDraw.Draw(im)
    # панелька
    d.rectangle([size[0] // 2, 0, size[0], size[1]], fill=(90, 88, 82))
    # пакет
    bx = size[0] // 4
    by = size[1] // 3
    d.rectangle([bx, by, bx + size[0] // 5, by + size[1] // 3], fill=(30, 120, 55))
    # «разрыв»
    d.polygon(
        [(bx + 20, by + 40), (bx + 60, by + 10), (bx + 80, by + 70)],
        fill=(180, 140, 60),
    )
    d.text((16, 16), title, fill=(240, 240, 220))
    im.save(path)
    print("capsule", path.name, size)


def shot(path: Path, label: str) -> None:
    im = Image.new("RGB", (1920, 1080), (40, 45, 42))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 200, 1920, 1080], fill=(70, 75, 70))
    d.rectangle([800, 400, 1000, 700], fill=(25, 110, 50))
    d.text((80, 80), f"TAKE OUT THE TRASH — {label}", fill=(255, 255, 230))
    im.save(path)


def main() -> None:
    capsule(CAP / "capsule_616x353.png", (616, 353), "ВЫНЕСИ МУСОР!")
    capsule(CAP / "capsule_460x215.png", (460, 215), "TAKE OUT THE TRASH!")
    capsule(CAP / "capsule_231x87.png", (231, 87), "TRASH!")
    capsule(CAP / "library_600x900.png", (600, 900), "ВЫНЕСИ МУСОР!")
    # Steam header / vertical
    capsule(CAP / "header_920x430.png", (920, 430), "ВЫНЕСИ МУСОР! / TAKE OUT THE TRASH!")
    capsule(CAP / "vertical_748x896.png", (748, 896), "ВЫНЕСИ МУСОР!")
    labels = [
        "01_stairwell",
        "02_bag_burst",
        "03_elevator",
        "04_ice_yard",
        "05_dogs",
        "06_babushka",
        "07_carpet",
        "08_fridge",
        "09_dumpster_win",
        "10_night",
    ]
    for lab in labels:
        shot(SHOTS / f"{lab}.png", lab)
    # Trailer placeholder note
    (CLIP / "TRAILER-README.txt").write_text(
        "Снять 45–60с трейлер из фейлов: разрыв пакета, лёд, собаки, холодильник.\n"
        "Экспорт: marketing/clip/takeoutthetrash_hook.mp4 (1080p).\n",
        encoding="utf-8",
    )
    print("STORE_ASSETS_OK")


if __name__ == "__main__":
    main()
