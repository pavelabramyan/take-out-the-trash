#!/usr/bin/env python3
"""Загрузка CC0-ассетов: PBR-материалы ambientCG, GLTF-пропсы и HDRI Poly Haven.

Материалы пакуются в assets/pbr/<name>/{albedo,normal,orm}.webp:
ORM = R:AmbientOcclusion, G:Roughness, B:Metalness (формат ORMMaterial3D в Godot).

Использование:
    python3 tools/fetch_assets.py              # всё, что ещё не скачано
    python3 tools/fetch_assets.py --only pbr   # pbr | models | hdri
    python3 tools/fetch_assets.py --force      # перекачать
"""
from __future__ import annotations

import argparse
import io
import json
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PBR_DIR = ROOT / "assets" / "pbr"
MODEL_DIR = ROOT / "assets" / "models"
HDRI_DIR = ROOT / "assets" / "hdri"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) take-out-the-trash/1.0"
ACG_GET = "https://ambientcg.com/get?file={file}"
PH_FILES = "https://api.polyhaven.com/files/{name}"
TEX_SIZE = 1024

# Материал -> ассет ambientCG. Размер тайла в метрах нужен библиотеке материалов.
PBR: dict[str, dict] = {
    "concrete_wall": {"acg": "Concrete034", "tile_m": 2.0},
    "concrete_floor": {"acg": "Concrete031", "tile_m": 2.0},
    "plaster_white": {"acg": "Plaster001", "tile_m": 2.5},
    "plaster_paint": {"acg": "PaintedPlaster017", "tile_m": 2.0},
    "tiles_landing": {"acg": "Tiles141", "tile_m": 1.2},
    "metal_painted": {"acg": "Metal041B", "tile_m": 1.5},
    "steel_corrugated": {"acg": "CorrugatedSteel009", "tile_m": 1.5},
    "asphalt": {"acg": "Asphalt033", "tile_m": 3.0},
    "road": {"acg": "Road012A", "tile_m": 4.0},
    "bricks": {"acg": "Bricks104", "tile_m": 2.0},
    "wood_door": {"acg": "Wood095", "tile_m": 1.6},
    "carpet": {"acg": "Carpet016", "tile_m": 1.0},
    "grass": {"acg": "Grass005", "tile_m": 2.0},
    "ground_dirt": {"acg": "Ground108", "tile_m": 2.5},
    "gravel": {"acg": "Gravel043", "tile_m": 2.0},
    "ice": {"acg": "Ice003", "tile_m": 2.0},
    "snow": {"acg": "Snow013", "tile_m": 2.5},
}

# Пропсы Poly Haven: имя -> разрешение текстур
MODELS: dict[str, str] = {
    "trashbag": "2k",
    "metal_trash_can": "1k",
    "modular_chainlink_fence": "1k",
    "street_lamp_01": "1k",
    "caged_hanging_light": "1k",
    "industrial_caged_sconce": "1k",
    "security_light": "1k",
    "exterior_aircon_unit": "1k",
    "modular_electricity_poles": "1k",
    "water_manhole_cover": "1k",
    "covered_car": "1k",
    "old_tyre": "1k",
    "plastic_crate_01": "1k",
    "cardboard_box_01": "1k",
    "modular_pipes": "1k",
    "modular_street_seating": "1k",
    "plastic_monobloc_chair_01": "1k",
    "dandelion_01": "1k",
    "nettle_plant": "1k",
    "weed_plant_02": "1k",
    "grass_medium_01": "1k",
    # tree_small_02 не берём: 97 МБ геометрии листвы. Безлистное дерево
    # поздней осени дешевле собрать процедурно в prop_library.gd
    "street_rat": "1k",
}

HDRI: dict[str, str] = {
    "potsdamer_platz": "2k",   # пасмурный городской день
    "abandoned_parking": "1k",  # день с солнцем
    "preller_drive": "1k",      # ночь в городе
}


def fetch(url: str, timeout: int = 180) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def find_map(names: list[str], suffix: str) -> str | None:
    for n in names:
        if n.lower().endswith(suffix.lower()):
            return n
    return None


def load_gray(zf: zipfile.ZipFile, name: str | None, fallback: int) -> Image.Image:
    if name is None:
        return Image.new("L", (TEX_SIZE, TEX_SIZE), fallback)
    with zf.open(name) as f:
        im = Image.open(io.BytesIO(f.read())).convert("L")
    return im.resize((TEX_SIZE, TEX_SIZE), Image.LANCZOS)


def do_pbr(force: bool) -> list[str]:
    done = []
    PBR_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in PBR.items():
        out = PBR_DIR / name
        if out.exists() and (out / "albedo.webp").exists() and not force:
            print(f"skip pbr {name}")
            done.append(name)
            continue
        asset = spec["acg"]
        fname = f"{asset}_2K-JPG.zip"
        print(f"pbr {name} <- {asset}")
        try:
            blob = fetch(ACG_GET.format(file=fname))
        except urllib.error.HTTPError as e:
            print(f"  ОШИБКА {asset}: {e}")
            continue
        out.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(io.BytesIO(blob)) as zf:
            names = zf.namelist()
            color = find_map(names, "_Color.jpg")
            normal = find_map(names, "_NormalGL.jpg") or find_map(names, "_NormalDX.jpg")
            rough = find_map(names, "_Roughness.jpg")
            ao = find_map(names, "_AmbientOcclusion.jpg")
            metal = find_map(names, "_Metalness.jpg")
            if color is None or normal is None:
                print(f"  нет обязательных карт у {asset}: {names}")
                continue
            with zf.open(color) as f:
                alb = Image.open(io.BytesIO(f.read())).convert("RGB")
            alb.resize((TEX_SIZE, TEX_SIZE), Image.LANCZOS).save(out / "albedo.webp", quality=92, method=5)
            with zf.open(normal) as f:
                nrm = Image.open(io.BytesIO(f.read())).convert("RGB")
            nrm.resize((TEX_SIZE, TEX_SIZE), Image.LANCZOS).save(out / "normal.webp", quality=96, method=5)
            orm = Image.merge("RGB", (
                load_gray(zf, ao, 255),
                load_gray(zf, rough, 190),
                load_gray(zf, metal, 0),
            ))
            orm.save(out / "orm.webp", quality=92, method=5)
        (out / "source.txt").write_text(
            f"ambientCG {asset} (CC0)\nhttps://ambientcg.com/view?id={asset}\ntile_m={spec['tile_m']}\n",
            encoding="utf-8",
        )
        done.append(name)
    return done


def do_models(force: bool) -> list[str]:
    done = []
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    for name, res in MODELS.items():
        out = MODEL_DIR / name
        gltf_path = out / f"{name}.gltf"
        if gltf_path.exists() and not force:
            print(f"skip model {name}")
            done.append(name)
            continue
        print(f"model {name} ({res})")
        try:
            meta = json.loads(fetch(PH_FILES.format(name=name), timeout=60))
        except Exception as e:
            print(f"  ОШИБКА метаданных {name}: {e}")
            continue
        pack = meta.get("gltf", {}).get(res, {}).get("gltf")
        if pack is None:
            avail = list(meta.get("gltf", {}))
            print(f"  нет gltf {res} у {name}, есть {avail}")
            continue
        out.mkdir(parents=True, exist_ok=True)
        gltf_path.write_bytes(fetch(pack["url"], timeout=120))
        # include: относительный путь рядом с .gltf -> запись со своим url
        # (.bin у Poly Haven лежит в каталоге другого разрешения)
        for rel, info in (pack.get("include") or {}).items():
            dst = out / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists() and not force:
                continue
            src = info["url"] if isinstance(info, dict) else str(info)
            dst.write_bytes(fetch(src, timeout=240))
        (out / "source.txt").write_text(
            f"Poly Haven {name} (CC0)\nhttps://polyhaven.com/a/{name}\n", encoding="utf-8"
        )
        done.append(name)
    return done


def do_hdri(force: bool) -> list[str]:
    done = []
    HDRI_DIR.mkdir(parents=True, exist_ok=True)
    for name, res in HDRI.items():
        dst = HDRI_DIR / f"{name}_{res}.hdr"
        if dst.exists() and not force:
            print(f"skip hdri {name}")
            done.append(name)
            continue
        print(f"hdri {name} ({res})")
        try:
            meta = json.loads(fetch(PH_FILES.format(name=name), timeout=60))
            url = meta["hdri"][res]["hdr"]["url"]
        except Exception as e:
            print(f"  ОШИБКА {name}: {e}")
            continue
        dst.write_bytes(fetch(url, timeout=240))
        done.append(name)
    return done


def write_licenses(pbr: list[str], models: list[str], hdri: list[str]) -> None:
    lines = [
        "# Лицензии сторонних ассетов",
        "",
        "Все перечисленные ассеты распространяются под CC0 1.0 (public domain):",
        "их можно использовать в коммерческой игре без указания авторства.",
        "Атрибуция ниже оставлена из уважения к авторам.",
        "",
        "## PBR-материалы — ambientCG (CC0)",
        "",
        "Источник: https://ambientcg.com — скачано `2K-JPG`, упаковано в 1024 WebP,",
        "карты AO/Roughness/Metalness объединены в один ORM-файл.",
        "",
    ]
    for n in pbr:
        acg = PBR[n]["acg"]
        lines.append(f"- `assets/pbr/{n}` — {acg}, https://ambientcg.com/view?id={acg}")
    lines += ["", "## Модели — Poly Haven (CC0)", "", "Источник: https://polyhaven.com/models", ""]
    for n in models:
        lines.append(f"- `assets/models/{n}` — https://polyhaven.com/a/{n} ({MODELS[n]})")
    lines += ["", "## HDRI — Poly Haven (CC0)", "", "Источник: https://polyhaven.com/hdris", ""]
    for n in hdri:
        lines.append(f"- `assets/hdri/{n}_{HDRI[n]}.hdr` — https://polyhaven.com/a/{n}")
    lines += [
        "",
        "## Собственные ассеты",
        "",
        "Всё в `assets/textures`, `assets/sfx`, `assets/music` сгенерировано скриптами",
        "из `tools/` и принадлежит проекту.",
        "",
    ]
    (ROOT / "assets" / "LICENSES.md").write_text("\n".join(lines), encoding="utf-8")


def dir_size(p: Path) -> float:
    if not p.exists():
        return 0.0
    return sum(f.stat().st_size for f in p.rglob("*") if f.is_file()) / 1024 / 1024


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["pbr", "models", "hdri"], default=None)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    pbr = models = hdri = []
    if args.only in (None, "pbr"):
        pbr = do_pbr(args.force)
    if args.only in (None, "models"):
        models = do_models(args.force)
    if args.only in (None, "hdri"):
        hdri = do_hdri(args.force)
    if args.only is None:
        write_licenses(pbr, models, hdri)
    print(
        "ASSETS_OK pbr=%d models=%d hdri=%d | pbr=%.1fMB models=%.1fMB hdri=%.1fMB"
        % (len(pbr), len(models), len(hdri), dir_size(PBR_DIR), dir_size(MODEL_DIR), dir_size(HDRI_DIR))
    )


if __name__ == "__main__":
    if shutil.which("python3") is None:
        raise SystemExit("нужен python3")
    main()
