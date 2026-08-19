#!/usr/bin/env python3
"""Синтез звуков для «Вынеси мусор!» — физические модели вместо чистых синусов.

Каждый звук собирается из того, что реально происходит: транзиент удара,
резонансы материала, шум трения, форманты голоса. Плюс короткий отклик
подъезда, чтобы звуки не были «сухими» как в браузерной игре.

    python3 tools/gen_sfx.py            # всё
    python3 tools/gen_sfx.py --only sfx # sfx | music
"""
from __future__ import annotations

import argparse
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SFX = ROOT / "assets" / "sfx"
MUSIC = ROOT / "assets" / "music"
SR = 44100

rng = np.random.default_rng(20260814)


# --- основа -----------------------------------------------------------------

def write(path: Path, x: np.ndarray, peak: float = 0.9) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.nan_to_num(x)
    m = float(np.max(np.abs(x))) or 0.0
    if m < 1e-6:
        raise RuntimeError(f"тишина в {path.name}: пик={m}")
    x = x / m * peak
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"wrote {path.relative_to(ROOT)} ({len(x) / SR:.2f}s)")


def n_samples(dur: float) -> int:
    return int(SR * dur)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(n_samples(dur)) / SR


def noise(dur: float) -> np.ndarray:
    return rng.standard_normal(n_samples(dur))


def biquad(x: np.ndarray, b: tuple[float, float, float], a: tuple[float, float, float]) -> np.ndarray:
    """Прямая форма II — для фильтров хватает, а зависимостей не тянет."""
    y = np.zeros_like(x)
    z1 = z2 = 0.0
    b0, b1, b2 = b
    a1, a2 = a[1], a[2]
    for i, xi in enumerate(x):
        yi = b0 * xi + z1
        z1 = b1 * xi - a1 * yi + z2
        z2 = b2 * xi - a2 * yi
        y[i] = yi
    return y


def _rbj(kind: str, f0: float, q: float) -> tuple[tuple, tuple]:
    w0 = 2.0 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2.0 * q)
    cw = np.cos(w0)
    a0 = 1.0 + alpha
    if kind == "lp":
        b = ((1 - cw) / 2, 1 - cw, (1 - cw) / 2)
    elif kind == "hp":
        b = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2)
    else:  # bp с постоянным пиком
        b = (alpha, 0.0, -alpha)
    a = (1.0, -2.0 * cw, 1.0 - alpha)
    return tuple(v / a0 for v in b), tuple(v / a0 for v in a)


def lp(x: np.ndarray, f0: float, q: float = 0.707) -> np.ndarray:
    b, a = _rbj("lp", min(f0, SR * 0.45), q)
    return biquad(x, b, a)


def hp(x: np.ndarray, f0: float, q: float = 0.707) -> np.ndarray:
    b, a = _rbj("hp", max(f0, 20.0), q)
    return biquad(x, b, a)


def bp(x: np.ndarray, f0: float, q: float = 2.0) -> np.ndarray:
    b, a = _rbj("bp", min(max(f0, 30.0), SR * 0.45), q)
    return biquad(x, b, a)


def env_exp(dur: float, attack: float = 0.002, decay: float = 0.2) -> np.ndarray:
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return a * np.exp(-t / max(decay, 1e-5))


def modal(dur: float, freqs, decays, amps=None, jitter: float = 0.0) -> np.ndarray:
    """Резонансы материала: металл, дерево, стекло отличаются набором мод."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    if amps is None:
        amps = [1.0 / (i + 1) for i in range(len(freqs))]
    for f, d, a in zip(freqs, decays, amps):
        f_mod = f * (1.0 + jitter * rng.standard_normal())
        phase = rng.uniform(0, 2 * np.pi)
        out += a * np.sin(2 * np.pi * f_mod * t + phase) * np.exp(-t / d)
    return out


def sweep_noise(dur: float, f_start: float, f_end: float, q: float = 3.0, steps: int = 24) -> np.ndarray:
    """Шум с движущейся полосой — скольжение, свист, шорох."""
    x = noise(dur)
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), steps + 1).astype(int)
    fs = np.geomspace(f_start, f_end, steps)
    for i in range(steps):
        s, e = edges[i], edges[i + 1]
        if e <= s:
            continue
        chunk = bp(x[s:e], float(fs[i]), q)
        out[s:e] = chunk
    return out


def crackle(dur: float, rate: float, f_lo: float, f_hi: float, sharp: float = 0.004) -> np.ndarray:
    """Треск плёнки: серия микровсплесков — то, чем пакет отличается от шума."""
    out = np.zeros(n_samples(dur))
    count = int(dur * rate)
    for _ in range(count):
        pos = rng.integers(0, max(1, len(out) - 400))
        d = rng.uniform(sharp * 0.4, sharp * 2.0)
        seg = noise(d) * env_exp(d, 0.0004, d * 0.4)
        seg = bp(seg, float(rng.uniform(f_lo, f_hi)), 2.5)
        room = len(out) - pos
        if room <= 0:
            continue
        seg = seg[:room]
        out[pos:pos + len(seg)] += seg * rng.uniform(0.3, 1.0)
    return out


def voice(dur: float, f0: float, formants, vibrato: float = 4.5, vib_amt: float = 0.03,
          breath: float = 0.12, drift: float = 0.0) -> np.ndarray:
    """Голос: импульсный источник плюс формантные резонаторы."""
    t = t_axis(dur)
    f = f0 * (1.0 + vib_amt * np.sin(2 * np.pi * vibrato * t) + drift * t / max(dur, 1e-5))
    phase = np.cumsum(f) / SR
    # Пилообразный источник богат гармониками, как голосовые складки
    src = 2.0 * (phase % 1.0) - 1.0
    src += breath * rng.standard_normal(len(t))
    out = np.zeros_like(t)
    for fr, q, amp in formants:
        out += amp * bp(src, fr, q)
    return out


def impulse_response(dur: float = 0.55, decay: float = 0.16, taps=(0.011, 0.019, 0.031, 0.047)) -> np.ndarray:
    """Отклик лестничной клетки: ранние отражения от стен плюс хвост."""
    ir = np.zeros(n_samples(dur))
    ir[0] = 1.0
    for i, tap in enumerate(taps):
        idx = int(tap * SR)
        if idx < len(ir):
            ir[idx] += 0.55 / (i + 1)
    tail = noise(dur) * np.exp(-t_axis(dur) / decay)
    tail = bp(tail, 900.0, 0.7)
    ir += tail * 0.35
    return ir


_IR = None


def reverb(x: np.ndarray, wet: float = 0.25) -> np.ndarray:
    global _IR
    if _IR is None:
        _IR = impulse_response()
    wet_sig = np.convolve(x, _IR)[: len(x) + 2000]
    dry = np.pad(x, (0, len(wet_sig) - len(x)))
    wet_sig = wet_sig / (float(np.max(np.abs(wet_sig))) or 1.0)
    return dry * (1.0 - wet) + wet_sig * wet


def pad(x: np.ndarray, dur: float) -> np.ndarray:
    need = n_samples(dur)
    return np.pad(x, (0, max(0, need - len(x))))[:need]


def loopable(x: np.ndarray, fade: float = 0.25) -> np.ndarray:
    """Склейка конца с началом — иначе в цикле слышен щелчок."""
    f = n_samples(fade)
    if f * 2 >= len(x):
        return x
    head, tail = x[:f].copy(), x[-f:].copy()
    ramp = np.linspace(0.0, 1.0, f)
    x = x[:-f].copy()
    x[:f] = head * ramp + tail * (1.0 - ramp)
    return x


# --- удары и материалы ------------------------------------------------------

def make_step(seed_shift: int) -> np.ndarray:
    """Подошва по бетону: щелчок каблука, толчок в пол, шорох песка."""
    dur = 0.28
    heel = noise(0.02) * env_exp(0.02, 0.0004, 0.006)
    heel = bp(heel, 2400.0 + seed_shift * 120.0, 1.1)
    thud = modal(0.12, [58 + seed_shift * 3, 96, 143], [0.045, 0.03, 0.018], [1.0, 0.5, 0.25])
    thud *= env_exp(0.12, 0.001, 0.04)
    grit = crackle(0.09, 90, 1800, 7000, 0.0025) * 0.35
    body = pad(heel * 0.9, dur) + pad(thud * 0.8, dur) + pad(grit, dur)
    return reverb(body, 0.22)


def make_impact() -> np.ndarray:
    """Мешок с мусором о бетон: глухой удар и внутренний дребезг."""
    dur = 0.55
    thud = modal(0.22, [72, 118, 175], [0.06, 0.04, 0.025], [1.0, 0.45, 0.2])
    thud *= env_exp(0.22, 0.0015, 0.055)
    film = crackle(0.18, 190, 1200, 6500, 0.003) * 0.5
    inner = crackle(0.3, 40, 300, 2200, 0.01) * 0.4
    return reverb(pad(thud, dur) + pad(film, dur) + pad(inner, dur), 0.3)


def make_bag_drop() -> np.ndarray:
    dur = 0.7
    thud = modal(0.3, [55, 88, 132], [0.09, 0.05, 0.03], [1.0, 0.4, 0.2]) * env_exp(0.3, 0.002, 0.08)
    settle = crackle(0.45, 55, 400, 3000, 0.012) * 0.55
    glass = modal(0.35, [1180, 1760, 2340], [0.12, 0.08, 0.05], [0.25, 0.15, 0.1]) * env_exp(0.35, 0.004, 0.09)
    return reverb(pad(thud, dur) + pad(settle, dur) + pad(glass * 0.5, dur), 0.28)


def make_bag_grab() -> np.ndarray:
    dur = 0.3
    grab = crackle(0.22, 320, 900, 7000, 0.0035)
    tug = bp(noise(0.12), 500.0, 1.4) * env_exp(0.12, 0.004, 0.05) * 0.5
    return reverb(pad(grab, dur) + pad(tug, dur), 0.18)


def make_rustle() -> np.ndarray:
    """Шорох плёнки при ходьбе: цикл на три секунды."""
    dur = 3.0
    t = t_axis(dur)
    base = bp(noise(dur), 3400.0, 0.8)
    slow = 0.45 + 0.55 * np.abs(np.sin(2 * np.pi * 0.6 * t + 0.4 * np.sin(2 * np.pi * 0.17 * t)))
    body = base * slow * 0.55
    body += crackle(dur, 60, 1500, 9000, 0.0035) * 0.5
    body += bp(noise(dur), 700.0, 0.9) * slow * 0.18
    return loopable(body, 0.3)


def make_wall_rub() -> np.ndarray:
    dur = 0.42
    scrape = sweep_noise(dur, 700, 2600, q=1.6)
    rough = 0.5 + 0.5 * np.sin(2 * np.pi * 42 * t_axis(dur))
    body = scrape * rough * env_exp(dur, 0.01, 0.18)
    body += bp(noise(dur), 220.0, 3.0) * env_exp(dur, 0.02, 0.2) * 0.4
    return reverb(body, 0.25)


def make_burst() -> np.ndarray:
    """Разрыв пакета: рвущаяся плёнка и высыпающееся содержимое."""
    dur = 1.4
    tear = crackle(0.22, 900, 1200, 11000, 0.0035) * 1.2
    rip = sweep_noise(0.18, 5200, 900, q=1.2) * env_exp(0.18, 0.001, 0.07)
    spill = np.zeros(n_samples(dur))
    for _ in range(34):
        pos = int(rng.uniform(0.1, 1.0) * SR)
        kind = rng.integers(0, 3)
        if kind == 0:  # стекло
            seg = modal(0.25, [1450, 2170, 3050], [0.09, 0.06, 0.04], [1.0, 0.6, 0.35])
        elif kind == 1:  # жесть
            seg = modal(0.2, [640, 1120, 1870], [0.07, 0.05, 0.03], [1.0, 0.5, 0.3])
        else:  # бумага и органика
            seg = bp(noise(0.12), float(rng.uniform(700, 2600)), 1.5)
        seg = seg * env_exp(len(seg) / SR, 0.001, 0.05) * rng.uniform(0.25, 0.8)
        end = min(len(spill), pos + len(seg))
        spill[pos:end] += seg[: end - pos]
    return reverb(pad(tear, dur) + pad(rip, dur) + spill * 0.7, 0.32)


def make_dump() -> np.ndarray:
    """Мешок падает в металлический бак — главный звук игры."""
    dur = 1.8
    hit = noise(0.03) * env_exp(0.03, 0.0004, 0.008)
    hit = bp(hit, 2600.0, 1.0) * 0.7
    shell = modal(
        1.5,
        [96, 178, 261, 407, 588, 795, 1130, 1615, 2210],
        [0.85, 0.7, 0.55, 0.42, 0.3, 0.24, 0.17, 0.11, 0.07],
        [1.0, 0.8, 0.62, 0.5, 0.36, 0.3, 0.22, 0.15, 0.1],
        jitter=0.004,
    )
    shell *= env_exp(1.5, 0.0015, 0.45)
    wobble = 1.0 + 0.25 * np.exp(-t_axis(1.5) / 0.25) * np.sin(2 * np.pi * 47 * t_axis(1.5))
    shell *= wobble
    film = crackle(0.25, 260, 1200, 7000, 0.003) * 0.45
    return reverb(pad(hit, dur) + pad(shell, dur) + pad(film, dur), 0.35)


def make_slip() -> np.ndarray:
    dur = 0.8
    skid = sweep_noise(0.45, 500, 3200, q=2.2) * env_exp(0.45, 0.01, 0.2)
    squeal = modal(0.4, [820, 1240], [0.16, 0.1], [0.5, 0.3]) * env_exp(0.4, 0.03, 0.16)
    gasp = voice(0.3, 210.0, [(650, 6.0, 0.6), (1180, 7.0, 0.35)], vibrato=7.0, breath=0.5)
    gasp *= env_exp(0.3, 0.02, 0.12) * 0.5
    return reverb(pad(skid, dur) + pad(squeal * 0.6, dur) + pad(np.pad(gasp, (n_samples(0.2), 0)), dur), 0.3)


def make_elevator() -> np.ndarray:
    dur = 1.6
    t = t_axis(dur)
    relay = noise(0.02) * env_exp(0.02, 0.0003, 0.006)
    relay = bp(relay, 3200.0, 1.2)
    hum = (np.sin(2 * np.pi * 47 * t) * 0.6 + np.sin(2 * np.pi * 94 * t) * 0.3
           + np.sin(2 * np.pi * 141 * t) * 0.12)
    hum *= 0.4 + 0.15 * np.sin(2 * np.pi * 6.5 * t)
    ramp = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.35, 0, 1)
    motor = bp(noise(dur), 780.0, 2.5) * 0.25 * ramp
    creak = bp(noise(dur), 1600.0, 6.0) * 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * t))
    return reverb(pad(relay, dur) + (hum + motor + creak) * ramp, 0.3)


# --- голоса -----------------------------------------------------------------

def make_bark() -> np.ndarray:
    """Гав: питч падает, форманты как у собачьей пасти."""
    dur = 0.5
    body = voice(0.16, 240.0, [(480, 5.0, 1.0), (1350, 6.0, 0.55), (2600, 7.0, 0.25)],
                 vibrato=0.0, vib_amt=0.0, breath=0.28, drift=-0.55)
    body *= env_exp(0.16, 0.004, 0.055)
    growl = bp(noise(0.2), 320.0, 2.0) * env_exp(0.2, 0.01, 0.07) * 0.35
    tail = voice(0.12, 150.0, [(420, 5.0, 0.6), (1100, 6.0, 0.3)], vibrato=9.0, breath=0.3)
    tail *= env_exp(0.12, 0.01, 0.05) * 0.5
    out = pad(body, dur) + pad(growl, dur) + pad(np.pad(tail, (n_samples(0.16), 0)), dur)
    return reverb(out, 0.22)


def make_babushka() -> np.ndarray:
    """Ворчание: «А-а-а, куда пошёл» без слов — гласная с вибрато."""
    dur = 0.85
    v = voice(0.7, 178.0, [(680, 7.0, 1.0), (1150, 8.0, 0.5), (2550, 9.0, 0.22)],
              vibrato=5.2, vib_amt=0.045, breath=0.2, drift=-0.12)
    shape = np.clip(t_axis(0.7) / 0.06, 0, 1) * np.clip((0.7 - t_axis(0.7)) / 0.25, 0, 1)
    v *= shape
    return reverb(pad(v, dur), 0.3)


def make_mom(kind: int) -> np.ndarray:
    """Крик из-за двери: гласная, форсированная до хрипа."""
    presets = [
        (0.95, 250.0, [(720, 8.0, 1.0), (1220, 9.0, 0.55), (2700, 9.0, 0.25)], 6.0, -0.10),
        (0.75, 285.0, [(660, 8.0, 1.0), (1450, 9.0, 0.5), (2900, 9.0, 0.22)], 7.0, 0.16),
        (1.15, 232.0, [(760, 7.0, 1.0), (1150, 8.0, 0.6), (2500, 9.0, 0.28)], 5.0, -0.18),
    ]
    dur, f0, forms, vib, drift = presets[kind % 3]
    v = voice(dur * 0.85, f0, forms, vibrato=vib, vib_amt=0.05, breath=0.22, drift=drift)
    shape = np.clip(t_axis(dur * 0.85) / 0.05, 0, 1) * np.clip((dur * 0.85 - t_axis(dur * 0.85)) / 0.3, 0, 1)
    v *= shape
    v = np.tanh(v * 2.2) * 0.8  # форсаж связок
    # За дверью высокие срезаны
    v = lp(v, 3200.0, 0.8)
    return reverb(pad(v, dur), 0.34)


# --- итоги ------------------------------------------------------------------

def make_win() -> np.ndarray:
    dur = 1.8
    t = t_axis(dur)
    chord = np.zeros_like(t)
    for f, a in [(196.0, 0.5), (293.7, 0.35), (392.0, 0.28), (587.3, 0.16)]:
        chord += a * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9)
        chord += a * 0.3 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t / 0.35)
    bell = modal(1.4, [1568, 2350, 3130], [0.5, 0.3, 0.2], [0.3, 0.16, 0.08]) * env_exp(1.4, 0.004, 0.5)
    return reverb(chord * 0.8 + pad(bell, dur), 0.3)


def make_fail() -> np.ndarray:
    dur = 1.6
    t = t_axis(dur)
    drop = np.sin(2 * np.pi * np.cumsum(np.geomspace(150, 48, len(t))) / SR) * np.exp(-t / 0.6)
    thud = modal(0.5, [62, 97], [0.16, 0.1], [1.0, 0.4]) * env_exp(0.5, 0.003, 0.14)
    air = bp(noise(dur), 300.0, 0.8) * np.exp(-t / 0.35) * 0.25
    return reverb(drop * 0.7 + pad(thud, dur) + air, 0.32)


def make_pickup() -> np.ndarray:
    dur = 0.22
    click = noise(0.012) * env_exp(0.012, 0.0003, 0.004)
    click = bp(click, 1900.0, 1.4)
    cloth = crackle(0.16, 220, 1500, 6000, 0.003) * 0.5
    return reverb(pad(click, dur) + pad(cloth, dur), 0.16)


# --- музыка и амбиенс -------------------------------------------------------

def make_ambient_hall() -> np.ndarray:
    """Гул подъезда: далёкий город, лампа, воздух в шахте."""
    dur = 12.0
    t = t_axis(dur)
    air = lp(noise(dur), 380.0, 0.7) * 0.5
    city = bp(noise(dur), 140.0, 0.6) * 0.35 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t))
    lamp = np.sin(2 * np.pi * 100.0 * t) * 0.035 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * t))
    shaft = np.sin(2 * np.pi * 47.0 * t) * 0.05 + np.sin(2 * np.pi * 71.0 * t) * 0.03
    body = air + city + lamp + shaft
    return loopable(reverb(body, 0.4), 1.2)


def _drone(dur: float, root: float, partials, lfo: float, noise_amt: float, noise_f: float) -> np.ndarray:
    t = t_axis(dur)
    out = np.zeros_like(t)
    for mult, amp, detune in partials:
        f = root * mult
        out += amp * np.sin(2 * np.pi * f * t)
        out += amp * 0.6 * np.sin(2 * np.pi * (f * (1.0 + detune)) * t + 1.1)
    out *= 0.65 + 0.35 * np.sin(2 * np.pi * lfo * t)
    out += bp(noise(dur), noise_f, 0.8) * noise_amt
    return out


def make_menu_loop() -> np.ndarray:
    body = _drone(16.0, 55.0, [(1, 0.30, 0.004), (2, 0.16, 0.005), (3, 0.08, 0.003), (5, 0.04, 0.006)],
                  0.08, 0.06, 220.0)
    t = t_axis(16.0)
    # Редкие капли — как вода в стояке
    for k in range(6):
        pos = int((1.6 + k * 2.4) * SR)
        drip = modal(0.5, [880, 1320], [0.12, 0.07], [0.25, 0.12]) * env_exp(0.5, 0.002, 0.1)
        end = min(len(body), pos + len(drip))
        body[pos:end] += drip[: end - pos] * 0.5
    return loopable(reverb(body, 0.35), 1.5)


def make_game_loop() -> np.ndarray:
    body = _drone(20.0, 49.0, [(1, 0.28, 0.003), (1.5, 0.12, 0.004), (2, 0.14, 0.005), (4, 0.05, 0.004)],
                  0.05, 0.05, 180.0)
    t = t_axis(20.0)
    pulse = (np.sin(2 * np.pi * 0.5 * t) > 0.97).astype(float)
    body += lp(pulse * rng.standard_normal(len(t)), 120.0, 1.2) * 0.25
    return loopable(reverb(body, 0.3), 1.5)


def make_danger_loop() -> np.ndarray:
    dur = 12.0
    t = t_axis(dur)
    body = _drone(dur, 41.0, [(1, 0.34, 0.006), (2, 0.14, 0.008), (3, 0.07, 0.005)], 0.9, 0.07, 320.0)
    # Пульс на сердцебиение, ускоряется к концу петли
    beat = np.zeros_like(t)
    pos = 0.0
    bpm = 92.0
    while pos < dur:
        i = int(pos * SR)
        hit = modal(0.2, [52, 78], [0.07, 0.05], [1.0, 0.4]) * env_exp(0.2, 0.002, 0.06)
        end = min(len(beat), i + len(hit))
        beat[i:end] += hit[: end - i]
        pos += 60.0 / bpm
        bpm = min(132.0, bpm + 1.6)
    return loopable(reverb(body + beat * 0.5, 0.28), 1.0)


def do_sfx() -> None:
    write(SFX / "step.wav", make_step(0))
    for i in range(2, 5):
        write(SFX / f"step{i}.wav", make_step(i))
    write(SFX / "impact.wav", make_impact())
    write(SFX / "bag_drop.wav", make_bag_drop())
    write(SFX / "bag_grab.wav", make_bag_grab())
    write(SFX / "rustle.wav", make_rustle())
    write(SFX / "wall_rub.wav", make_wall_rub())
    write(SFX / "burst.wav", make_burst())
    write(SFX / "dump.wav", make_dump())
    write(SFX / "slip.wav", make_slip())
    write(SFX / "elevator.wav", make_elevator())
    write(SFX / "bark.wav", make_bark())
    write(SFX / "babushka.wav", make_babushka())
    for i in range(3):
        name = "mom.wav" if i == 0 else f"mom{i + 1}.wav"
        write(SFX / name, make_mom(i))
    write(SFX / "win.wav", make_win())
    write(SFX / "fail.wav", make_fail())
    write(SFX / "pickup.wav", make_pickup())


def do_music() -> None:
    write(MUSIC / "ambient_hall.wav", make_ambient_hall(), peak=0.55)
    write(MUSIC / "menu_loop.wav", make_menu_loop(), peak=0.7)
    write(MUSIC / "game_loop.wav", make_game_loop(), peak=0.65)
    write(MUSIC / "danger_loop.wav", make_danger_loop(), peak=0.7)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["sfx", "music"], default=None)
    args = ap.parse_args()
    if args.only in (None, "sfx"):
        do_sfx()
    if args.only in (None, "music"):
        do_music()
    print("SFX_OK")


if __name__ == "__main__":
    main()
