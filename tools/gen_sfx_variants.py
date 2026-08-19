#!/usr/bin/env python3
"""5 разных характеров каждого звука → launch/sfx_picks/ + catalog.json.

Источники: Kenney CC0 (фоли), macOS say (мама/бабушка), физический синтез
(лифт, собака, петли, музыка). Это банк для выбора, не финальные ассеты.

    python3 tools/gen_sfx_variants.py
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).parent))
import gen_sfx as g  # noqa: E402

OUT = ROOT / "launch" / "sfx_picks"
SR = g.SR
KENNEY = Path("/tmp/kenney_sfx")

try:
    from scipy.signal import lfilter

    def _biquad(x, b, a):
        return lfilter(b, a, x)

    g.biquad = _biquad
except ImportError:
    pass

_cache: dict[str, np.ndarray] = {}


def load(path: Path) -> np.ndarray:
    key = str(path)
    if key in _cache:
        return _cache[key].copy()
    if not path.exists():
        raise FileNotFoundError(path)
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "pipe:1"]
    )
    x = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    _cache[key] = x
    return x.copy()


def k(pack: str, *parts: str) -> np.ndarray:
    return load(KENNEY / pack / Path(*parts))


def impact(name: str) -> np.ndarray:
    return k("impact", "Audio", f"{name}.ogg")


def rpg(name: str) -> np.ndarray:
    return k("rpg", "Audio", f"{name}.ogg")


def iface(name: str) -> np.ndarray:
    return k("iface", "Audio", f"{name}.ogg")


def jingle(folder: str, name: str) -> np.ndarray:
    return k("jingles", "Audio", folder, f"{name}.ogg")


def fade(x: np.ndarray, inn: float = 0.002, out: float = 0.03) -> np.ndarray:
    x = x.copy()
    a, b = g.n_samples(inn), g.n_samples(out)
    if a and a < len(x):
        x[:a] *= np.linspace(0, 1, a)
    if b and b < len(x):
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim(x: np.ndarray, thr: float = 0.012) -> np.ndarray:
    idx = np.where(np.abs(x) > thr)[0]
    if idx.size == 0:
        return x
    lo = max(0, int(idx[0]) - 48)
    hi = min(len(x), int(idx[-1]) + g.n_samples(0.05))
    return x[lo:hi]


def pitch(x: np.ndarray, st: float) -> np.ndarray:
    factor = 2.0 ** (st / 12.0)
    n = max(16, int(round(len(x) / factor)))
    t_old = np.linspace(0.0, 1.0, len(x), endpoint=False)
    t_new = np.linspace(0.0, 1.0, n, endpoint=False)
    return np.interp(t_new, t_old, x)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def add_same(*xs: np.ndarray) -> np.ndarray:
    n = max(len(x) for x in xs)
    acc = np.zeros(n)
    for x in xs:
        acc[: len(x)] += x
    return acc


def layer(*parts: tuple) -> np.ndarray:
    """Каждый элемент: массив или (массив, delay_sec, gain)."""
    parsed = []
    for p in parts:
        if isinstance(p, tuple):
            arr, delay, gain = p
        else:
            arr, delay, gain = p, 0.0, 1.0
        parsed.append((np.asarray(arr, dtype=np.float64), float(delay), float(gain)))
    n = max(len(a) + int(d * SR) for a, d, _ in parsed)
    out = np.zeros(n)
    for a, d, gn in parsed:
        i = int(d * SR)
        out[i : i + len(a)] += a * gn
    return out


def room(x: np.ndarray, wet: float) -> np.ndarray:
    g._IR = None
    return g.reverb(x, wet)


def say_ru(text: str, rate: int = 185, voice: str = "Milena") -> np.ndarray:
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.check_call(
            ["say", "-v", voice, "-r", str(rate), "-o", path, "--data-format=LEI16@44100", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return trim(load(Path(path)))
    finally:
        Path(path).unlink(missing_ok=True)


def scatter_loop(clips: list[np.ndarray], dur: float, hits: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros(g.n_samples(dur))
    for _ in range(hits):
        clip = clips[int(rng.integers(0, len(clips)))]
        pos = int(rng.integers(0, max(1, len(out) - 200)))
        end = min(len(out), pos + len(clip))
        out[pos:end] += clip[: end - pos] * float(rng.uniform(0.35, 1.0))
    return g.loopable(out, 0.28)


# --- характеры -------------------------------------------------------------

def variants_dump() -> list[tuple[str, np.ndarray]]:
    return [
        (
            "Тяжёлый железный бак",
            fade(room(layer(
                (impact("impactMetal_heavy_000"), 0.00, 1.0),
                (impact("impactSoft_heavy_000"), 0.02, 0.85),
                (rpg("cloth1"), 0.01, 0.7),
                (impact("impactMetal_light_001"), 0.08, 0.45),
            ), 0.32)),
        ),
        (
            "Тонкая жесть, дребезг",
            fade(room(layer(
                (impact("impactTin_medium_000"), 0.00, 1.0),
                (impact("impactMetal_light_002"), 0.03, 0.8),
                (rpg("metalPot1"), 0.05, 0.55),
                (rpg("cloth2"), 0.00, 0.5),
            ), 0.22)),
        ),
        (
            "Пластиковый контейнер",
            fade(room(layer(
                (impact("impactSoft_heavy_002"), 0.00, 1.0),
                (impact("impactPunch_medium_000"), 0.01, 0.65),
                (rpg("dropLeather"), 0.02, 0.5),
                (rpg("cloth3"), 0.00, 0.7),
            ), 0.18)),
        ),
        (
            "Далёкий двор, эхо",
            fade(room(layer(
                (pitch(impact("impactMetal_heavy_001"), -3), 0.00, 0.75),
                (impact("impactSoft_medium_001"), 0.04, 0.5),
                (rpg("cloth4"), 0.02, 0.4),
            ), 0.48)),
        ),
        (
            "Мокрый мешок + бутылки",
            fade(room(layer(
                (impact("impactSoft_heavy_003"), 0.00, 1.0),
                (impact("impactGlass_medium_000"), 0.06, 0.55),
                (impact("impactGlass_light_002"), 0.14, 0.35),
                (rpg("cloth1"), 0.00, 0.65),
            ), 0.28)),
        ),
    ]


def variants_burst() -> list[tuple[str, np.ndarray]]:
    tear = g.crackle(0.2, 900, 1400, 11000, 0.003)
    return [
        (
            "Резкий разрыв и стекло",
            fade(room(layer(
                (rpg("knifeSlice"), 0.00, 1.0),
                (tear, 0.00, 0.7),
                (impact("impactGlass_heavy_000"), 0.08, 0.7),
                (rpg("cloth2"), 0.04, 0.5),
            ), 0.26)),
        ),
        (
            "Мокрый хлопок",
            fade(room(layer(
                (impact("impactSoft_heavy_001"), 0.00, 1.0),
                (impact("impactGlass_medium_002"), 0.07, 0.45),
                (g.crackle(0.35, 120, 400, 2400, 0.01), 0.05, 0.7),
            ), 0.3)),
        ),
        (
            "Медленный надрыв",
            fade(room(layer(
                (pitch(rpg("knifeSlice2"), -4), 0.00, 1.0),
                (rpg("drawKnife1"), 0.12, 0.55),
                (rpg("cloth4"), 0.05, 0.7),
                (g.crackle(0.5, 80, 800, 6000, 0.006), 0.00, 0.45),
            ), 0.2)),
        ),
        (
            "Жесть и банки",
            fade(room(layer(
                (rpg("metalPot2"), 0.00, 0.9),
                (impact("impactTin_medium_002"), 0.03, 0.85),
                (impact("impactGlass_light_001"), 0.1, 0.5),
                (rpg("knifeSlice"), 0.00, 0.45),
            ), 0.24)),
        ),
        (
            "Тихий хлопок",
            fade(room(layer(
                (rpg("cloth1"), 0.00, 1.0),
                (impact("impactGeneric_light_000"), 0.02, 0.7),
                (g.crackle(0.18, 200, 1500, 7000, 0.004), 0.00, 0.4),
            ), 0.16)),
        ),
    ]


def variants_step() -> list[tuple[str, np.ndarray]]:
    return [
        ("Бетон подъезда", fade(room(impact("footstep_concrete_000"), 0.2))),
        ("Кафель / дерево", fade(room(impact("footstep_wood_001"), 0.16))),
        ("Наледь во дворе", fade(room(impact("footstep_snow_000"), 0.14))),
        ("Трава / грунт", fade(room(impact("footstep_grass_002"), 0.12))),
        ("Ковёр / тихо", fade(room(impact("footstep_carpet_001"), 0.1))),
    ]


def variants_rustle() -> list[tuple[str, np.ndarray]]:
    cloths = [rpg(n) for n in ("cloth1", "cloth2", "cloth3", "cloth4")]
    paper = [rpg(n) for n in ("bookFlip1", "bookFlip2", "bookFlip3")]
    leather = [rpg("handleSmallLeather"), rpg("handleSmallLeather2"), rpg("dropLeather")]
    return [
        (
            "Тонкий магазинный пакет",
            fade(g.loopable(g.hp(add_same(scatter_loop(cloths, 3.0, 28, 11), g.crackle(3.0, 70, 2500, 10000, 0.0025) * 0.45), 900), 0.3), 0.02, 0.02),
        ),
        (
            "Толстый мусорный мешок",
            fade(g.loopable(g.lp(add_same(scatter_loop(cloths + leather, 3.0, 16, 22), g.bp(g.noise(3.0), 700, 0.8) * 0.12), 2800), 0.3), 0.02, 0.02),
        ),
        (
            "Бумага и картон",
            fade(scatter_loop(paper + cloths[:2], 3.0, 18, 33), 0.02, 0.02),
        ),
        (
            "Мокрый пакет",
            fade(g.loopable(g.lp(add_same(scatter_loop(cloths, 3.0, 12, 44), g.bp(g.noise(3.0), 280, 0.7) * 0.2), 1600), 0.3), 0.02, 0.02),
        ),
        (
            "Почти тихий шорох",
            fade(g.loopable(add_same(scatter_loop(cloths, 3.0, 7, 55) * 0.55, g.crackle(3.0, 18, 1800, 7000, 0.003) * 0.25), 0.3), 0.02, 0.02),
        ),
    ]


def variants_bag_grab() -> list[tuple[str, np.ndarray]]:
    return [
        ("Хруст плёнки", fade(room(layer((rpg("cloth1"), 0, 1.0), (rpg("handleSmallLeather"), 0.02, 0.7)), 0.12))),
        ("Ручка пакета", fade(room(layer((rpg("beltHandle1"), 0, 1.0), (rpg("cloth2"), 0.01, 0.6)), 0.12))),
        ("Тканевая сумка", fade(room(layer((rpg("clothBelt"), 0, 1.0), (rpg("cloth3"), 0.03, 0.5)), 0.1))),
        ("Тяжёлый рывок", fade(room(layer((rpg("dropLeather"), 0, 0.9), (rpg("beltHandle2"), 0.04, 0.7), (rpg("cloth4"), 0, 0.5)), 0.16))),
        ("Короткий щипок", fade(room(layer((rpg("metalClick"), 0, 0.7), (rpg("cloth1"), 0.01, 0.8)), 0.1))),
    ]


def variants_bag_drop() -> list[tuple[str, np.ndarray]]:
    return [
        ("Мягко на пол", fade(room(layer((impact("impactSoft_heavy_000"), 0, 1.0), (rpg("cloth2"), 0.02, 0.65)), 0.2))),
        ("Тяжёлый удар", fade(room(layer((impact("impactPunch_heavy_000"), 0, 1.0), (rpg("cloth1"), 0.01, 0.55)), 0.22))),
        ("Бутылки внутри", fade(room(layer((impact("impactSoft_medium_002"), 0, 0.85), (impact("impactGlass_medium_001"), 0.05, 0.7)), 0.24))),
        ("Картонная коробка", fade(room(layer((rpg("bookPlace1"), 0, 1.0), (impact("impactSoft_medium_000"), 0.03, 0.55)), 0.16))),
        ("Пластик с отскоком", fade(room(layer((impact("impactGeneric_light_002"), 0, 1.0), (impact("impactTin_medium_001"), 0.07, 0.4), (rpg("cloth3"), 0, 0.4)), 0.14))),
    ]


def variants_impact() -> list[tuple[str, np.ndarray]]:
    return [
        ("Глухой мешок", fade(room(impact("impactSoft_heavy_001"), 0.2))),
        ("Стекло внутри", fade(room(layer((impact("impactSoft_medium_003"), 0, 0.7), (impact("impactGlass_medium_003"), 0.02, 0.85)), 0.2))),
        ("Жесть о перила", fade(room(impact("impactTin_medium_003"), 0.18))),
        ("Косяк / дерево", fade(room(impact("impactWood_medium_001"), 0.18))),
        ("Лёгкий шлёп", fade(room(impact("impactGeneric_light_003"), 0.12))),
    ]


def variants_wall_rub() -> list[tuple[str, np.ndarray]]:
    scrape = g.sweep_noise(0.4, 600, 2400, q=1.5)
    return [
        ("Плёнка о краску", fade(room(layer((iface("scratch_001"), 0, 0.7), (rpg("cloth2"), 0, 0.8)), 0.16))),
        ("Ткань по стене", fade(room(layer((rpg("clothBelt2"), 0, 1.0), (rpg("cloth3"), 0.05, 0.5)), 0.14))),
        ("Мешок о бетон", fade(room(layer((scrape, 0, 0.8), (rpg("cloth1"), 0, 0.5), (g.bp(g.noise(0.4), 180, 2.5) * g.env_exp(0.4, 0.02, 0.15), 0, 0.45)), 0.22))),
        ("Резина / писк", fade(room(layer((iface("scratch_003"), 0, 0.55), (g.modal(0.35, [740, 1180], [0.12, 0.08], [0.5, 0.25]) * g.env_exp(0.35, 0.02, 0.12), 0.04, 0.45)), 0.18))),
        ("Короткое шарканье", fade(room(iface("scratch_002"), 0.12))),
    ]


def variants_pickup() -> list[tuple[str, np.ndarray]]:
    return [
        ("Мягкий клик", fade(room(layer((iface("click_002"), 0, 0.7), (rpg("cloth1"), 0.01, 0.7)), 0.1))),
        ("Бумага", fade(room(rpg("bookFlip2"), 0.08))),
        ("Пластиковая крышка", fade(room(iface("switch_002"), 0.08))),
        ("Мелочь / жесть", fade(room(rpg("handleCoins"), 0.1))),
        ("Ткань в охапку", fade(room(rpg("cloth4"), 0.1))),
    ]


def variants_slip() -> list[tuple[str, np.ndarray]]:
    skid = g.sweep_noise(0.4, 480, 3000, q=2.0) * g.env_exp(0.4, 0.01, 0.16)
    return [
        ("Резина по плитке", fade(room(layer((iface("scratch_004"), 0, 0.8), (skid, 0, 0.55)), 0.2))),
        ("Лёд", fade(room(layer((impact("footstep_snow_002"), 0, 0.7), (skid, 0.02, 0.8)), 0.16))),
        ("Мокрый след", fade(room(layer((impact("impactSoft_medium_004"), 0, 0.7), (g.lp(skid, 1400), 0, 0.7)), 0.2))),
        ("Визг и срыв", fade(room(layer((skid, 0, 0.7), (g.modal(0.35, [880, 1320], [0.14, 0.08], [0.45, 0.25]) * g.env_exp(0.35, 0.02, 0.12), 0.05, 0.55), (impact("impactPunch_medium_002"), 0.18, 0.45)), 0.22))),
        ("Короткий подскок", fade(room(layer((iface("scratch_005"), 0, 0.65), (impact("impactGeneric_light_001"), 0.08, 0.7)), 0.14))),
    ]


def variants_elevator() -> list[tuple[str, np.ndarray]]:
    return [
        (
            "Советское реле и мотор",
            fade(room(layer(
                (g.make_elevator(), 0, 1.0),
                (rpg("metalLatch"), 0.02, 0.35),
            ), 0.22)),
        ),
        (
            "Двери лифта",
            fade(room(layer(
                (rpg("doorOpen_1"), 0, 0.85),
                (rpg("metalLatch"), 0.15, 0.6),
                (rpg("doorClose_2"), 0.55, 0.8),
                (rpg("creak1"), 0.2, 0.35),
            ), 0.2)),
        ),
        (
            "Скрипучая шахта",
            fade(room(layer(
                (rpg("creak2"), 0, 0.9),
                (rpg("creak3"), 0.25, 0.7),
                (rpg("metalPot3"), 0.1, 0.25),
                (g.lp(g.noise(1.2), 120) * g.env_exp(1.2, 0.1, 0.5) * 0.35, 0, 1.0),
            ), 0.28)),
        ),
        (
            "Короткий хлопок дверей",
            fade(room(layer((rpg("doorClose_1"), 0, 1.0), (rpg("metalClick"), 0.08, 0.4)), 0.16)),
        ),
        (
            "Гул шахты",
            fade(room(layer(
                (g.lp(g.noise(1.4), 90) * (0.4 + 0.2 * np.sin(2 * np.pi * 6 * g.t_axis(1.4))), 0, 1.0),
                (rpg("creak1"), 0.3, 0.35),
                (rpg("doorClose_4"), 0.9, 0.25),
            ), 0.35)),
        ),
    ]


def variants_bark() -> list[tuple[str, np.ndarray]]:
    return [
        ("Близкий тявк", fade(room(g.make_bark(), 0.12))),
        (
            "Крупный пёс",
            fade(room(layer(
                (g.voice(0.22, 140, [(380, 5, 1.0), (980, 6, 0.45), (1900, 6, 0.2)], vibrato=0, vib_amt=0, breath=0.35, drift=-0.4) * g.env_exp(0.22, 0.006, 0.07), 0, 1.0),
                (g.bp(g.noise(0.25), 220, 1.8) * g.env_exp(0.25, 0.01, 0.08), 0, 0.4),
            ), 0.18)),
        ),
        (
            "Двойной гав",
            fade(room(layer(
                (g.make_bark(), 0, 1.0),
                (pitch(g.make_bark(), -1), 0.22, 0.85),
            ), 0.2)),
        ),
        (
            "Двор, далеко",
            fade(room(pitch(g.make_bark(), -2) * 0.7, 0.45)),
        ),
        (
            "Предупреждающий рык",
            fade(room(layer(
                (g.voice(0.35, 110, [(320, 4, 1.0), (780, 5, 0.4)], vibrato=8, vib_amt=0.04, breath=0.45, drift=-0.15) * g.env_exp(0.35, 0.03, 0.14), 0, 1.0),
                (g.make_bark() * 0.35, 0.18, 0.7),
            ), 0.2)),
        ),
    ]


def variants_babushka() -> list[tuple[str, np.ndarray]]:
    lines = [
        ("А куда пошёл?", 155, -2, 0.28, "Ворчание: «куда пошёл»"),
        ("Молодой человек!", 165, -1, 0.22, "Оклик с площадки"),
        ("Что это несёшь?", 150, -3, 0.3, "Подозрительный вопрос"),
        ("Опять мусор таскаешь.", 140, -4, 0.34, "Нудящая жалоба"),
        ("Стой-ка тут.", 148, -2, 0.26, "Короткое «стой»"),
    ]
    out = []
    for text, rate, st, wet, label in lines:
        v = pitch(say_ru(text, rate=rate), st)
        v = g.lp(v, 2800)
        out.append((label, fade(room(v, wet))))
    return out


def variants_mom() -> list[tuple[str, np.ndarray]]:
    specs = [
        ("Вынеси мусор!", 200, 1, 0.18, False, "Резкий крик"),
        ("Ну сколько можно, вынеси мусор!", 170, 0, 0.32, True, "Из-за двери, длинный"),
        ("Сынок! Мусор!", 190, 2, 0.4, True, "Далёкий, из квартиры"),
        ("Я сказала, вынеси мусор!", 205, 1, 0.2, False, "Злая, быстрее"),
        ("Мусор!!!", 210, 3, 0.16, False, "Короткий ор"),
    ]
    out = []
    for text, rate, st, wet, door, label in specs:
        v = pitch(say_ru(text, rate=rate), st)
        v = np.tanh(v * (2.4 if not door else 1.6))
        v = g.lp(v, 1800 if door else 3400)
        if door:
            v = g.hp(v, 180) * 0.9
        out.append((label, fade(room(v, wet))))
    return out


def variants_win() -> list[tuple[str, np.ndarray]]:
    return [
        ("Тёплый аккорд", fade(room(g.make_win(), 0.22))),
        ("Сталь / бокал", fade(jingle("Steel jingles", "jingles_STEEL00"))),
        ("Пиццикато", fade(jingle("Pizzicato jingles", "jingles_PIZZI01"))),
        ("Ударный джингл", fade(jingle("Hit jingles", "jingles_HIT00"))),
        ("Короткое подтверждение", fade(iface("confirmation_002"))),
    ]


def variants_fail() -> list[tuple[str, np.ndarray]]:
    return [
        ("Нисходящий гул", fade(room(g.make_fail(), 0.22))),
        ("Ошибка UI", fade(iface("error_003"))),
        ("Тупой удар", fade(room(layer((impact("impactSoft_heavy_004"), 0, 0.8), (iface("error_006"), 0.05, 0.7)), 0.2))),
        ("Грустный хит", fade(jingle("Hit jingles", "jingles_HIT16"))),
        ("Сакс, не вышло", fade(jingle("Sax jingles", "jingles_SAX08"))),
    ]


def _music_preview(kind: str, idx: int) -> np.ndarray:
    g.rng = np.random.default_rng(7000 + idx * 97 + (sum(ord(c) for c in kind) % 1000))
    g._IR = None
    roots = {
        "menu": [55.0, 49.0, 36.0, 62.0, 41.0],
        "game": [49.0, 44.0, 55.0, 38.0, 52.0],
        "danger": [41.0, 31.0, 46.0, 36.0, 55.0],
        "ambient": [0.0, 0.0, 0.0, 0.0, 0.0],
    }
    if kind == "ambient":
        styles = [
            lambda: g.make_ambient_hall()[: g.n_samples(6.0)],
            lambda: g.loopable(g.lp(g.noise(6.0), 240) * 0.45 + np.sin(2 * np.pi * 100 * g.t_axis(6.0)) * 0.04, 0.8),
            lambda: g.loopable(g.bp(g.noise(6.0), 90, 0.6) * 0.5 + g.lp(g.noise(6.0), 500) * 0.15, 0.8),
            lambda: g.loopable(g.lp(g.noise(6.0), 180) * 0.35 + np.sin(2 * np.pi * 47 * g.t_axis(6.0)) * 0.06, 0.8),
            lambda: g.loopable(g.hp(g.lp(g.noise(6.0), 800), 200) * (0.25 + 0.1 * np.sin(2 * np.pi * 0.15 * g.t_axis(6.0))), 0.8),
        ]
        return fade(g.loopable(room(styles[idx](), 0.35), 0.7), 0.05, 0.05)
    root = roots[kind][idx]
    if kind == "menu":
        body = g._drone(6.0, root, [(1, 0.30, 0.004), (2, 0.16, 0.005), (3, 0.08, 0.003), (5, 0.04, 0.006)], 0.08, 0.05, 200 + idx * 40)
    elif kind == "game":
        body = g._drone(6.0, root, [(1, 0.28, 0.003), (1.5, 0.12, 0.004), (2, 0.14, 0.005), (4, 0.05, 0.004)], 0.05, 0.04, 160 + idx * 30)
        t = g.t_axis(6.0)
        pulse = (np.sin(2 * np.pi * (0.4 + idx * 0.12) * t) > 0.96).astype(float)
        body += g.lp(pulse * g.rng.standard_normal(len(t)), 110, 1.1) * (0.18 + idx * 0.03)
    else:
        body = g._drone(6.0, root, [(1, 0.34, 0.006), (2, 0.14, 0.008), (3, 0.07, 0.005)], 0.7 + idx * 0.15, 0.07, 280 + idx * 40)
        beat = np.zeros_like(g.t_axis(6.0))
        pos, bpm = 0.0, 88.0 + idx * 10
        while pos < 6.0:
            i = int(pos * SR)
            hit = g.modal(0.16, [50, 76], [0.06, 0.04], [1.0, 0.4]) * g.env_exp(0.16, 0.002, 0.05)
            beat[i : i + len(hit)] += hit[: max(0, min(len(hit), len(beat) - i))]
            pos += 60.0 / bpm
        body = body + beat * (0.35 + idx * 0.05)
    return fade(g.loopable(room(body, 0.28), 0.7), 0.05, 0.05)


def variants_menu() -> list[tuple[str, np.ndarray]]:
    labels = ["Тёмный дрон", "Ниже и теплее", "Почти тишина", "Выше, ночь", "Холодный гул"]
    return [(labels[i], _music_preview("menu", i)) for i in range(5)]


def variants_game() -> list[tuple[str, np.ndarray]]:
    labels = ["Низкий шаг", "Чуть быстрее пульс", "Светлее", "Глухой", "Нервный тик"]
    return [(labels[i], _music_preview("game", i)) for i in range(5)]


def variants_danger() -> list[tuple[str, np.ndarray]]:
    labels = ["Сердце", "Ниже и злее", "Быстрее", "Диссонанс", "Тревожный стук"]
    return [(labels[i], _music_preview("danger", i)) for i in range(5)]


def variants_ambient() -> list[tuple[str, np.ndarray]]:
    labels = ["Подъезд как сейчас", "Лампа и гул", "Двор за окном", "Пустая шахта", "Воздух в лестнице"]
    return [(labels[i], _music_preview("ambient", i)) for i in range(5)]


CATALOG = [
    {"id": "dump", "title": "Мешок в бак", "hint": "Главный звук игры", "group": "sfx", "now": "assets/sfx/dump.wav", "loop": False, "fn": variants_dump},
    {"id": "burst", "title": "Пакет порвался", "hint": "Проигрыш / дыра в пакете", "group": "sfx", "now": "assets/sfx/burst.wav", "loop": False, "fn": variants_burst},
    {"id": "step", "title": "Шаги", "hint": "Бетон, плитка, двор", "group": "sfx", "now": "assets/sfx/step.wav", "loop": False, "fn": variants_step},
    {"id": "rustle", "title": "Шорох пакета", "hint": "Петля, пока несёшь", "group": "sfx", "now": "assets/sfx/rustle.wav", "loop": True, "fn": variants_rustle},
    {"id": "bag_grab", "title": "Хват пакета", "hint": "Поднял мешок", "group": "sfx", "now": "assets/sfx/bag_grab.wav", "loop": False, "fn": variants_bag_grab},
    {"id": "bag_drop", "title": "Пакет на пол", "hint": "Поставил / бросил", "group": "sfx", "now": "assets/sfx/bag_drop.wav", "loop": False, "fn": variants_bag_drop},
    {"id": "impact", "title": "Удар пакета", "hint": "Стена, перила, ступеньки", "group": "sfx", "now": "assets/sfx/impact.wav", "loop": False, "fn": variants_impact},
    {"id": "wall_rub", "title": "Трение о стену", "hint": "Пакет трётся в подъезде", "group": "sfx", "now": "assets/sfx/wall_rub.wav", "loop": False, "fn": variants_wall_rub},
    {"id": "pickup", "title": "Подбор мусора", "hint": "Кусок в охапку", "group": "sfx", "now": "assets/sfx/pickup.wav", "loop": False, "fn": variants_pickup},
    {"id": "slip", "title": "Поскользнулся", "hint": "Лёд и мокрый пол", "group": "sfx", "now": "assets/sfx/slip.wav", "loop": False, "fn": variants_slip},
    {"id": "elevator", "title": "Лифт", "hint": "Двери и шахта", "group": "sfx", "now": "assets/sfx/elevator.wav", "loop": False, "fn": variants_elevator},
    {"id": "bark", "title": "Собака", "hint": "Двор, если поймали", "group": "sfx", "now": "assets/sfx/bark.wav", "loop": False, "fn": variants_bark},
    {"id": "babushka", "title": "Бабушка", "hint": "Допрос на площадке", "group": "sfx", "now": "assets/sfx/babushka.wav", "loop": False, "fn": variants_babushka},
    {"id": "mom", "title": "Крик мамы", "hint": "Старт уровня", "group": "sfx", "now": "assets/sfx/mom.wav", "loop": False, "fn": variants_mom},
    {"id": "win", "title": "Победа", "hint": "Вынес — джингл", "group": "sfx", "now": "assets/sfx/win.wav", "loop": False, "fn": variants_win},
    {"id": "fail", "title": "Поражение", "hint": "Пакет / поймали", "group": "sfx", "now": "assets/sfx/fail.wav", "loop": False, "fn": variants_fail},
    {"id": "menu_loop", "title": "Музыка меню", "hint": "Превью 6 сек", "group": "music", "now": "assets/music/menu_loop.wav", "loop": True, "fn": variants_menu},
    {"id": "game_loop", "title": "Музыка игры", "hint": "Превью 6 сек", "group": "music", "now": "assets/music/game_loop.wav", "loop": True, "fn": variants_game},
    {"id": "danger_loop", "title": "Музыка опасности", "hint": "Превью 6 сек", "group": "music", "now": "assets/music/danger_loop.wav", "loop": True, "fn": variants_danger},
    {"id": "ambient_hall", "title": "Гудение подъезда", "hint": "Превью 6 сек", "group": "music", "now": "assets/music/ambient_hall.wav", "loop": True, "fn": variants_ambient},
]


def main() -> None:
    missing = [p for p in (KENNEY / "impact" / "Audio", KENNEY / "rpg" / "Audio", KENNEY / "iface" / "Audio", KENNEY / "jingles" / "Audio") if not p.exists()]
    if missing:
        sys.exit("Нет распакованных Kenney-паков в /tmp/kenney_sfx — сначала скачай zip'ы.")
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = {"sounds": []}
    for spec in CATALOG:
        sid = spec["id"]
        dest = OUT / sid
        dest.mkdir(parents=True, exist_ok=True)
        print(f"== {sid}")
        items = spec["fn"]()
        if len(items) != 5:
            raise RuntimeError(f"{sid}: ожидалось 5 вариантов, получили {len(items)}")
        variants_meta = []
        for i, (label, audio) in enumerate(items, start=1):
            g.write(dest / f"{i}.wav", np.asarray(audio, dtype=np.float64), peak=0.88)
            variants_meta.append({"n": i, "label": label, "file": f"{sid}/{i}.wav"})
        catalog["sounds"].append({
            "id": sid,
            "title": spec["title"],
            "hint": spec["hint"],
            "group": spec["group"],
            "now": f"../../{spec['now']}",
            "loop": spec["loop"],
            "variants": variants_meta,
        })
    (OUT / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"CATALOG {len(catalog['sounds'])} sounds × 5 → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
