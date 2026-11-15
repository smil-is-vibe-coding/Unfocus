"""
Procedural audio generator for the game.

Every sound here is synthesised from scratch (oscillators, noise, filters,
reverb), so the output is 100% original and free to use commercially - no
samples, no third-party licences.

Usage:
    pip install numpy scipy
    python tools/generate_audio.py            # writes audio/*.wav

Re-run after tweaking any recipe below. Deterministic (fixed seeds).
"""

import os
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- basics ----

def secs(d):
    return np.arange(int(SR * d)) / SR


def n_samples(d):
    return int(SR * d)


def noise(d):
    return rng.standard_normal(n_samples(d))


def osc(freq, d=None, shape="sine", phase0=0.0):
    """freq can be a scalar or an array (per-sample frequency)."""
    if np.isscalar(freq):
        freq = np.full(n_samples(d), float(freq))
    ph = 2 * np.pi * np.cumsum(freq) / SR + phase0
    if shape == "sine":
        return np.sin(ph)
    p = (ph / (2 * np.pi)) % 1.0
    if shape == "saw":
        return 2 * p - 1
    if shape == "square":
        return np.where(p < 0.5, 1.0, -1.0)
    if shape == "tri":
        return 4 * np.abs(p - 0.5) - 1
    raise ValueError(shape)


def sweep(f0, f1, d, curve="exp"):
    t = np.linspace(0, 1, n_samples(d))
    if curve == "exp":
        return f0 * (f1 / f0) ** t
    return f0 + (f1 - f0) * t


def decay(d, tau):
    return np.exp(-secs(d) / tau)


def adsr(d, a=0.005, dcy=0.1, s=0.6, r=0.2):
    n = n_samples(d)
    env = np.ones(n) * s
    na, nd, nr = n_samples(a), n_samples(dcy), n_samples(r)
    na = max(na, 1)
    env[:na] = np.linspace(0, 1, na)
    env[na:na + nd] = np.linspace(1, s, len(env[na:na + nd]))
    if nr > 0:
        env[-nr:] *= np.linspace(1, 0, nr)
    return env


def _sos(kind, fc, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = fc
        return signal.butter(order, [max(lo, 10) / nyq, min(hi, nyq * 0.95) / nyq], "bandpass", output="sos")
    return signal.butter(order, min(max(fc, 10), nyq * 0.95) / nyq, kind, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("low", fc, order), x)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("high", fc, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x)


def lp_sweep(x, f0, f1, block=256, order=2, curve="exp"):
    """Low-pass whose cutoff moves from f0 to f1 over the sound."""
    out = np.zeros_like(x)
    nb = int(np.ceil(len(x) / block))
    zi = None
    for b in range(nb):
        t = b / max(nb - 1, 1)
        fc = f0 * (f1 / f0) ** t if curve == "exp" else f0 + (f1 - f0) * t
        sos = _sos("low", fc, order)
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        seg = x[b * block:(b + 1) * block]
        out[b * block:(b + 1) * block], zi = signal.sosfilt(sos, seg, zi=zi)
    return out


def lp_lfo(x, fc_fn, block=256, order=2):
    """Low-pass with cutoff given by fc_fn(time_seconds)."""
    out = np.zeros_like(x)
    zi = None
    for s in range(0, len(x), block):
        fc = fc_fn(s / SR)
        sos = _sos("low", fc, order)
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        out[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return out


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def norm(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = n_samples(fin), n_samples(fout)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def pad_to(x, d):
    n = n_samples(d)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, t0, total):
    """Place x starting at time t0 inside a buffer of `total` seconds."""
    out = np.zeros(n_samples(total))
    s = n_samples(t0)
    e = min(len(out), s + len(x))
    out[s:e] = x[:e - s]
    return out


def crackle(d, density=300, decay_ms=3.0):
    n = n_samples(d)
    out = np.zeros(n)
    count = int(density * d)
    idx = rng.integers(0, n, count)
    out[idx] = rng.uniform(-1, 1, count)
    k = np.exp(-np.arange(n_samples(decay_ms / 1000)) / (SR * decay_ms / 4000))
    return np.convolve(out, k)[:n]


# -------------------------------------------------------------- effects ----

def comb(x, D, g):
    y = np.zeros(len(x))
    y[:D] = x[:D]
    for s in range(D, len(x), D):
        e = min(s + D, len(x))
        y[s:e] = x[s:e] + g * y[s - D:e - D]
    return y


def allpass(x, D, g):
    y = np.zeros(len(x))
    xd = np.concatenate([np.zeros(D), x[:-D]])
    y[:D] = -g * x[:D] + xd[:D]
    for s in range(D, len(x), D):
        e = min(s + D, len(x))
        y[s:e] = -g * x[s:e] + xd[s:e] + g * y[s - D:e - D]
    return y


def reverb(x, mix_amt=0.3, size=1.0, damp=5000, tail=1.5, seed_off=0):
    x = np.concatenate([x, np.zeros(n_samples(tail))])
    combs = [1557, 1617, 1491, 1422, 1277, 1356]
    wet = np.zeros(len(x))
    for i, D in enumerate(combs):
        wet += comb(x, int((D + seed_off * 23 * (i + 1)) * size), 0.82)
    wet = lp(wet / len(combs), damp)
    for D in (225, 556, 441):
        wet = allpass(wet, int(D * size), 0.5)
    return x * (1 - mix_amt) + wet * mix_amt


def stereo_reverb(l, r, mix_amt=0.3, size=1.0, damp=5000, tail=2.0):
    return (reverb(l, mix_amt, size, damp, tail, 0), reverb(r, mix_amt, size * 1.03, damp, tail, 3))


def feedback_delay(x, delay_s, fb=0.4, mix_amt=0.3, tail=1.0):
    D = n_samples(delay_s)
    x = np.concatenate([x, np.zeros(n_samples(tail))])
    y = comb(x, D, fb)
    wet = np.concatenate([np.zeros(D), y[:-D]])
    return x + wet * mix_amt


def make_loop(x, xfade):
    """Crossfade the extra tail of x into its head so it loops seamlessly."""
    n = n_samples(xfade)
    body = x[:-n].copy()
    tail = x[-n:]
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * ramp + tail * (1 - ramp)
    return body


# ---------------------------------------------------------------- output ----

def write(name, x, stereo=None):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    if stereo is not None:
        l, r = x, stereo
        n = min(len(l), len(r))
        data = np.empty(n * 2)
        data[0::2] = l[:n]
        data[1::2] = r[:n]
        ch = 2
    else:
        data = x
        ch = 1
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}.wav  {len(data) / SR / ch:5.2f}s")


# ======================================================== ENGINE LOOPS ====
# Loops are 2.0 s. All tonal frequencies are multiples of 0.5 Hz so they repeat
# exactly; noise layers are crossfaded. Godot raises pitch with speed.

LOOP = 2.0
XF = 0.25


def loopify(fn):
    """Render two-plus cycles, keep the settled second cycle and crossfade its
    tail into its head. Tonal parts (periodic in LOOP) join perfectly; noise
    parts get a smooth crossfade. Avoids filter start-up clicks at the seam."""
    x = fn(2 * LOOP + XF)
    return make_loop(x[n_samples(LOOP):], XF)


def _engine_viper(d):
    t = secs(d)
    core = 0.55 * lp(osc(110.0, d, "saw"), 1100)
    core += 0.25 * osc(220.0, d) + 0.12 * osc(330.0, d)
    whine = 0.22 * osc(880.0 + 6.0 * np.sin(2 * np.pi * 3.0 * t), None) + 0.08 * osc(1760.0, d)
    air = bp(noise(d), 500, 2600) * 0.35
    flutter = 1 + 0.12 * np.sin(2 * np.pi * 27.5 * t)
    return drive((core + whine) * flutter + air, 1.4)


def _engine_dart(d):
    t = secs(d)
    core = 0.45 * lp(osc(165.0, d, "saw"), 2200) + 0.2 * osc(330.0, d)
    whine = 0.35 * osc(1320.0 + 10 * np.sin(2 * np.pi * 5.0 * t), None)
    whine += 0.14 * osc(2640.0, d) + 0.05 * osc(3960.0, d)
    air = lp(hp(noise(d), 1500), 6000) * 0.12
    return drive(core + whine + air, 1.6)


def _engine_manta(d):
    t = secs(d)
    hum = 0.6 * osc(98.0, d) + 0.3 * osc(196.0, d) + 0.1 * lp(osc(98.0, d, "square"), 700)
    sing = 0.15 * osc(588.0, d) + 0.08 * osc(784.0, d)
    trem = 1 + 0.3 * np.sin(2 * np.pi * 8.0 * t)
    air = bp(noise(d), 300, 1200) * 0.22
    return hum * trem + sing + air


def _engine_titan(d):
    t = secs(d)
    core = 0.7 * lp(osc(55.0, d, "saw"), 600) + 0.5 * osc(27.5, d) + 0.3 * lp(osc(110.0, d, "square"), 500)
    chug = 1 + 0.45 * np.maximum(0, np.sin(2 * np.pi * 15.0 * t))
    rumble = lp(noise(d), 260, 4) * 0.9
    return drive(core * chug + rumble, 2.2)


def _engine_wraith(d):
    t = secs(d)
    a = lp(osc(130.5, d, "saw"), 1400)
    b = lp(osc(131.0, d, "saw"), 1400)  # 0.5 Hz beating = phasing
    ghost = 0.18 * osc(1046.5 + 14 * np.sin(2 * np.pi * 0.5 * t), None) + 0.1 * osc(1569.5, d)
    air = bp(noise(d), 1500, 4500) * 0.18
    return drive(0.45 * (a + b) + ghost + air, 1.3)


def engine_viper():
    return norm(loopify(_engine_viper), 0.8)


def engine_dart():
    return norm(loopify(_engine_dart), 0.8)


def engine_manta():
    return norm(loopify(_engine_manta), 0.8)


def engine_titan():
    return norm(loopify(_engine_titan), 0.82)


def engine_wraith():
    return norm(loopify(_engine_wraith), 0.8)


def engine_roar():
    """Shared thrust roar, volume follows the throttle."""
    def gen(d):
        x = noise(d)
        body = lp(x, 900, 4) * 1.4 + bp(x, 900, 3500) * 0.5
        return drive(body, 1.5)
    return norm(loopify(gen), 0.8)


def afterburner():
    def gen(d):
        x = noise(d)
        roar = lp(x, 700, 4) * 1.6 + bp(x, 700, 2500) * 0.7 + lp(hp(x, 2500), 7000) * 0.2
        cr = lp(crackle(d, 180, 5), 2500) * 1.5
        return drive(roar + cr, 1.8)
    return norm(loopify(gen), 0.8)


def airbrake():
    def gen(d):
        return bp(noise(d), 2500, 7000) * 0.6 + bp(noise(d), 600, 1500) * 0.4
    return norm(loopify(gen), 0.7)


def missile_loop():
    def gen(d):
        x = bp(noise(d), 1200, 5000)
        cr = lp(crackle(d, 250, 4), 4000)
        return drive(x + cr * 1.2, 1.5)
    return norm(loopify(gen), 0.7)


# ===================================================== ONE-SHOT SFX ======

def gun_shot():
    d = 0.22
    click = hp(noise(0.004), 3000) * 1.0
    crack = bp(noise(d), 900, 5000) * decay(d, 0.025) * 1.2
    thump = osc(sweep(140, 45, d), None) * decay(d, 0.05) * 1.3
    ring = osc(2350.0, d) * decay(d, 0.04) * 0.15
    x = mix(click, crack, thump, ring)
    return fade(norm(drive(x, 3.0), 0.92), 0.0005, 0.03)


def bullet_hit():
    d = 0.3
    parts = [osc(f, d) * decay(d, tau) * g for f, tau, g in
             [(2400, 0.06, 0.5), (3570, 0.04, 0.4), (5130, 0.03, 0.3), (1210, 0.08, 0.3)]]
    crack = hp(noise(d), 2000) * decay(d, 0.012)
    return fade(norm(mix(crack, *parts), 0.85))


def bullet_ricochet():
    d = 0.35
    zing = osc(sweep(3400, 1300, d), None) * decay(d, 0.12) * 0.6
    crack = hp(noise(d), 2500) * decay(d, 0.01)
    return fade(norm(mix(crack, zing), 0.7))


def missile_launch():
    d = 1.3
    ign = osc(sweep(90, 35, d), None) * decay(d, 0.18) * 1.2
    whoosh = lp_sweep(noise(d), 300, 7000) * adsr(d, 0.05, 0.3, 0.6, 0.6) * 0.9
    cr = lp(crackle(d, 300, 4), 5000) * decay(d, 0.5) * 1.2
    x = mix(ign, whoosh, cr)
    return fade(norm(reverb(drive(x, 2.0), 0.18, 0.8, 4000, 0.6)))


def explosion(d=2.6, big=False):
    boom = osc(sweep(75 if not big else 60, 25, d), None) * decay(d, 0.45 if not big else 0.7) * 1.6
    body = lp_sweep(noise(d), 6000, 150) * decay(d, 0.6 if not big else 0.9) * 1.3
    cr = crackle(d, 500, 6) * decay(d, 0.5) * 2.0
    x = mix(boom, body, lp(cr, 6000))
    if big:
        debris = bp(crackle(d, 120, 15), 800, 4000) * adsr(d, 0.2, 0.5, 0.5, 1.5) * 1.2
        x = mix(x, debris)
    x = drive(x, 2.5)
    return fade(norm(reverb(x, 0.25, 1.2, 3000, 1.2)), 0.0005, 0.3)


def boost():
    d = 1.6
    kick = osc(sweep(120, 40, 0.3), None) * decay(0.3, 0.09) * 1.4
    whoosh = lp_sweep(noise(d), 200, 9000) * adsr(d, 0.25, 0.2, 0.9, 0.9)
    rise = osc(sweep(180, 1500, d), None, "saw")
    rise = lp(rise, 3000) * adsr(d, 0.3, 0.3, 0.6, 0.8) * 0.35
    x = mix(kick, whoosh, rise)
    return fade(norm(reverb(drive(x, 1.6), 0.22, 1.0, 6000, 0.8)))


def hook_fire():
    d = 0.6
    zip_ = lp(osc(sweep(300, 2600, 0.25), None, "saw"), 5000) * decay(0.25, 0.12) * 0.6
    chain = np.zeros(n_samples(d))
    for i in range(10):
        t0 = 0.03 + i * 0.045
        k = bp(noise(0.02), 2500, 7000) * decay(0.02, 0.004) * (1 - i / 12)
        chain += at(k, t0, d)
    return fade(norm(mix(zip_, chain), 0.85))


def hook_attach():
    d = 0.6
    parts = [osc(f, d) * decay(d, tau) * g for f, tau, g in
             [(180, 0.2, 0.8), (473, 0.12, 0.5), (1131, 0.08, 0.35), (2207, 0.05, 0.3)]]
    hit = lp(noise(d), 2500) * decay(d, 0.02) * 1.2
    return fade(norm(drive(mix(hit, *parts), 1.8), 0.85))


def _shimmer(d, f0, f1, voices=5, trem=9.0):
    out = np.zeros(n_samples(d))
    t = secs(d)
    for i in range(voices):
        ratio = 1 + i * 0.5
        f = sweep(f0 * ratio, f1 * ratio, d)
        out += osc(f, None) * (1 + 0.6 * np.sin(2 * np.pi * (trem + i) * t)) / (i + 1)
    return out


def hook_snap():
    """Rubber-band twang + whip crack + energy thump."""
    d = 0.9
    t = secs(d)
    f = sweep(950, 110, d) * (1 + 0.04 * np.sin(2 * np.pi * 38 * t))
    twang = drive(osc(f, None, "saw"), 2.0)
    twang = lp_sweep(twang, 7000, 600) * decay(d, 0.22) * 0.7
    crack = hp(noise(d), 2500) * decay(d, 0.008) * 1.4
    thump = osc(sweep(130, 40, 0.35), None) * decay(0.35, 0.08) * 1.3
    zap = bp(noise(d), 1500, 6000) * decay(d, 0.05) * 0.5
    return fade(norm(reverb(mix(twang, crack, thump, zap), 0.2, 0.9, 7000, 0.5)))


def invis_on():
    d = 1.3
    x = _shimmer(d, 1800, 260) * adsr(d, 0.02, 0.3, 0.6, 0.6)
    x = mix(x, bp(noise(d), 2000, 8000) * decay(d, 0.3) * 0.4)
    return fade(norm(reverb(x, 0.4, 1.3, 7000, 1.0)))


def invis_off():
    d = 0.9
    x = _shimmer(d, 260, 1600) * adsr(d, 0.15, 0.2, 0.6, 0.4)
    return fade(norm(reverb(x, 0.35, 1.1, 7000, 0.8)))


def _bell(f, d, tau=0.4):
    return (osc(f, d) + 0.4 * osc(f * 2.0, d) * decay(d, tau * 0.5) + 0.15 * osc(f * 3.01, d) * decay(d, tau * 0.3)) * decay(d, tau)


def _arp(freqs, step, d, tau=0.3, gain=0.6):
    out = np.zeros(n_samples(d))
    for i, f in enumerate(freqs):
        out += at(_bell(f, d - i * step, tau) * gain, i * step, d)
    return out


def repair():
    d = 1.4
    x = _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.07, d, 0.35)
    sparkle = hp(crackle(d, 60, 8), 5000) * adsr(d, 0.1, 0.3, 0.5, 0.6) * 0.4
    return fade(norm(reverb(mix(x, sparkle), 0.35, 1.0, 8000, 1.0)))


def shield_hit():
    d = 0.9
    vwomm = osc(sweep(140, 55, d), None) * decay(d, 0.25) * 1.2
    buzz = lp(osc(120.0, d, "saw"), 1500) * decay(d, 0.12) * 0.5
    zap = bp(noise(d), 1500, 7000) * decay(d, 0.04) * 1.2
    ring = (osc(660, d) + osc(990, d) * 0.6 + osc(1485, d) * 0.3) * decay(d, 0.3) * 0.35
    cr = hp(crackle(d, 400, 2), 2000) * decay(d, 0.2) * 1.2
    x = drive(mix(vwomm, buzz, zap, ring, cr), 2.0)
    return fade(norm(reverb(x, 0.25, 0.9, 6000, 0.6)))


def shield_scrape():
    d = 0.3
    x = hp(crackle(d, 600, 2), 1500) * decay(d, 0.08) + bp(noise(d), 2000, 6000) * decay(d, 0.05) * 0.5
    x += osc(sweep(400, 300, d), None) * decay(d, 0.1) * 0.25
    return fade(norm(x, 0.7))


def shield_break():
    d = 2.0
    glass = np.zeros(n_samples(d))
    for _ in range(26):
        f = rng.uniform(2200, 9000)
        t0 = rng.uniform(0, 0.25)
        glass += at(osc(f, 0.6) * decay(0.6, rng.uniform(0.05, 0.25)) * rng.uniform(0.2, 0.6), t0, d)
    fall = osc(sweep(900, 60, d), None, "saw")
    fall = lp(fall, 2500) * adsr(d, 0.01, 0.3, 0.5, 1.0) * 0.5
    impact = lp(noise(d), 3000) * decay(d, 0.05) * 1.5
    x = drive(mix(glass, fall, impact), 1.6)
    return fade(norm(reverb(x, 0.35, 1.2, 7000, 1.2)))


def shield_refill():
    d = 1.5
    x = _arp([392.0, 523.25, 659.25, 783.99, 1046.5, 1568.0], 0.06, d, 0.5, 0.5)
    swell = _shimmer(d, 300, 1200, 4, 12) * adsr(d, 0.6, 0.2, 0.6, 0.6) * 0.3
    return fade(norm(reverb(mix(x, swell), 0.35, 1.2, 9000, 1.0)))


def fall():
    d = 2.2
    tone = osc(sweep(700, 50, d), None) * adsr(d, 0.02, 0.3, 0.7, 0.8) * 0.6
    wind = lp_sweep(noise(d), 5000, 200) * adsr(d, 0.05, 0.3, 0.8, 0.8)
    return fade(norm(reverb(mix(tone, wind), 0.4, 1.4, 4000, 1.2)))


def respawn():
    d = 1.0
    swell = lp_sweep(noise(0.6), 200, 9000) * np.linspace(0, 1, n_samples(0.6)) ** 2
    pop = at(_bell(1046.5, 0.4, 0.15) + osc(sweep(200, 60, 0.4), None) * decay(0.4, 0.06) * 1.2, 0.6, d)
    return fade(norm(reverb(mix(swell * 0.7, pop), 0.3, 1.0, 8000, 0.8)))


def hit_player():
    d = 0.35
    thump = osc(sweep(110, 40, d), None) * decay(d, 0.07) * 1.4
    crunch = drive(bp(noise(d), 300, 4000), 4.0) * decay(d, 0.04)
    return fade(norm(mix(thump, crunch), 0.85))


# -- pickups: each power-up gets its own short signature --

def pickup_boost():
    d = 0.5
    x = lp(osc(sweep(300, 2400, 0.25), None, "saw"), 5000) * decay(0.25, 0.15)
    x = mix(x, at(_bell(1568, 0.25, 0.1) * 0.5, 0.18, d))
    return fade(norm(reverb(x, 0.2, 0.8, 8000, 0.4)))


def pickup_machine_gun():
    d = 0.5
    c1 = bp(noise(0.05), 1500, 6000) * decay(0.05, 0.008) + osc(1800, 0.05) * decay(0.05, 0.015) * 0.4
    c2 = bp(noise(0.08), 800, 4000) * decay(0.08, 0.012) + osc(140, 0.08) * decay(0.08, 0.03)
    ring = osc(2600, 0.3) * decay(0.3, 0.06) * 0.2
    x = mix(at(c1, 0.0, d), at(c2, 0.12, d), at(ring, 0.12, d))
    return fade(norm(drive(x, 2.0), 0.85))


def pickup_invisibility():
    d = 0.9
    x = sum(_bell(f, d, 0.4) * g for f, g in [(1318.5, 0.5), (1760, 0.4), (2349.3, 0.3), (2793.8, 0.2)])
    x = x * (1 + 0.5 * np.sin(2 * np.pi * 11 * secs(d)))
    return fade(norm(reverb(x, 0.5, 1.3, 9000, 0.9)))


def pickup_hookshot():
    d = 0.5
    ting = _bell(2093, d, 0.15) * 0.7
    zip_ = lp(osc(sweep(800, 2000, 0.12), None, "saw"), 4000) * decay(0.12, 0.05) * 0.4
    return fade(norm(mix(at(zip_, 0, d), at(ting, 0.08, d)), 0.85))


def pickup_missile():
    d = 0.55
    beep = lp(osc(1250, 0.07, "square"), 4000) * adsr(0.07, 0.002, 0.01, 0.9, 0.01)
    beep_hi = lp(osc(1650, 0.14, "square"), 4000) * adsr(0.14, 0.002, 0.01, 0.9, 0.03)
    x = mix(at(beep, 0, d), at(beep, 0.11, d), at(beep_hi, 0.22, d))
    return fade(norm(x * 0.8, 0.75))


def pickup_repair():
    d = 0.7
    x = _arp([659.25, 987.77], 0.1, d, 0.3, 0.7)
    return fade(norm(reverb(x, 0.3, 1.0, 8000, 0.5)))


def pickup_forcefield():
    d = 0.9
    x = _arp([1046.5, 1318.5, 1568, 2093, 2637], 0.04, d, 0.25, 0.4)
    x = mix(x, _shimmer(d, 600, 1800, 3, 14) * adsr(d, 0.05, 0.2, 0.4, 0.4) * 0.3)
    return fade(norm(reverb(x, 0.4, 1.2, 10000, 0.8)))


def ui_move():
    d = 0.09
    return fade(norm(osc(sweep(900, 1300, d), None, "tri") * decay(d, 0.03), 0.6))


def ui_select():
    d = 0.6
    x = _arp([659.25, 987.77, 1318.5], 0.06, d, 0.25, 0.6)
    x = mix(x, osc(sweep(120, 50, 0.25), None) * decay(0.25, 0.06) * 0.8)
    return fade(norm(reverb(x, 0.3, 1.0, 8000, 0.5)))


# -- race flow --

def countdown_beep():
    d = 0.45
    tone = lp(osc(880.0, d, "square"), 3500) * 0.5 + osc(880.0, d) * 0.5
    x = tone * adsr(d, 0.003, 0.05, 0.6, 0.25)
    sub_ = osc(110.0, d) * decay(d, 0.08) * 0.8
    return fade(norm(reverb(mix(x, sub_), 0.25, 1.0, 7000, 0.4)))


def go_beep():
    d = 1.2
    chord = sum(lp(osc(f, d, "saw"), 5000) * g for f, g in [(1760, 0.5), (2217.5, 0.35), (2637, 0.3), (880, 0.4)])
    x = chord * adsr(d, 0.004, 0.15, 0.5, 0.7)
    kick = osc(sweep(160, 40, 0.3), None) * decay(0.3, 0.08) * 1.4
    return fade(norm(reverb(drive(mix(x, kick), 1.4), 0.3, 1.1, 8000, 0.8)))


def perfect_start():
    d = 1.4
    arp = _arp([523.25, 783.99, 1046.5, 1568.0, 2093.0], 0.045, d, 0.3, 0.5)
    whoosh = lp_sweep(noise(d), 400, 10000) * adsr(d, 0.05, 0.3, 0.6, 0.8) * 0.6
    return fade(norm(reverb(mix(arp, whoosh), 0.3, 1.0, 9000, 0.8)))


def stall():
    d = 1.5
    t = secs(d)
    chug = lp(osc(sweep(70, 30, d), None, "saw"), 600)
    gate = (np.sin(2 * np.pi * sweep(14, 5, d, "lin").cumsum() / SR) > 0.2).astype(float)
    gate = lp(gate, 60)
    pops = np.zeros(n_samples(d))
    for i in range(7):
        t0 = 0.08 + i * rng.uniform(0.12, 0.22)
        if t0 < d - 0.1:
            pops += at(drive(bp(noise(0.08), 300, 3000), 5.0) * decay(0.08, 0.02), t0, d)
    x = mix(chug * gate * adsr(d, 0.01, 0.3, 0.7, 0.4) * 1.2, pops * 0.8)
    return fade(norm(drive(x, 2.5), 0.85))


def lap():
    d = 0.9
    x = _arp([1046.5, 1568.0], 0.09, d, 0.3, 0.7)
    return fade(norm(reverb(x, 0.3, 1.0, 9000, 0.6)))


def finish():
    d = 3.2
    chord = np.zeros(n_samples(d))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        v = lp(osc(f, d - i * 0.08, "saw"), 4000) * adsr(d - i * 0.08, 0.01, 0.3, 0.6, 1.4) * 0.35
        chord += at(v, i * 0.08, d)
    crash = hp(noise(d), 4000) * decay(d, 0.6) * 0.5
    kick = osc(sweep(150, 40, 0.4), None) * decay(0.4, 0.1) * 1.4
    sparkle = hp(crackle(d, 80, 10), 6000) * adsr(d, 0.2, 0.5, 0.4, 1.2) * 0.4
    return fade(norm(reverb(mix(chord, crash, kick, sparkle), 0.35, 1.3, 9000, 1.2)))


# ================================================================ MUSIC ====

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def music_track(bpm, bars, chords, drums=True, arp_div=4, seed=0, energy=1.0):
    """Synthwave-ish loop. Returns (left, right), seamlessly loopable."""
    global rng
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars
    tail = bar * 2  # rendered past the loop end, then folded back to the start
    T = total + tail
    N = n_samples(T)
    L = np.zeros(N)
    R = np.zeros(N)
    side = np.ones(N)  # sidechain gain from the kick

    def add(buf, x, t0, gain=1.0):
        s = n_samples(t0)
        e = min(N, s + len(x))
        buf[s:e] += x[:e - s] * gain

    def section(b):
        b = b % bars
        if b < 4:
            return "intro"
        if b >= bars - 4:
            return "break"
        return "full"

    # --- pad: detuned saws, slow filter sweep, wide stereo ---
    pad_l = np.zeros(N)
    pad_r = np.zeros(N)
    for b in range(bars + 2):
        notes = chords[(b // 2) % len(chords)]
        if b % 2:
            continue
        d = bar * 2 + 0.8
        env = adsr(d, 0.6, 0.5, 0.8, 1.0)
        for n in notes:
            f = midi(n)
            for det, side_gain in ((-0.08, (1.0, 0.3)), (0.0, (0.6, 0.6)), (0.08, (0.3, 1.0))):
                v = osc(f * 2 ** (det / 12), d, "saw") * env * 0.12
                add(pad_l, v, b * bar, side_gain[0])
                add(pad_r, v, b * bar, side_gain[1])
    lfo = lambda t: 700 + 1600 * (0.5 + 0.5 * np.sin(2 * np.pi * t / (bar * 4)))
    pad_l = lp_lfo(pad_l, lfo)
    pad_r = lp_lfo(pad_r, lfo)

    # --- arp: plucky square through a ping-pong delay ---
    arp = np.zeros(N)
    step = beat / arp_div
    pattern = [0, 1, 2, 3, 2, 1, 3, 2]
    for b in range(bars + 2):
        notes = chords[(b // 2) % len(chords)]
        tones = sorted(notes)[:4]
        for s in range(int(4 * arp_div)):
            idx = pattern[s % len(pattern)]
            octave = 12 if (s // len(pattern)) % 2 else 24
            f = midi(tones[idx % len(tones)] + octave)
            d = step * 1.6
            v = lp(osc(f, d, "square"), 2400 + 1600 * energy) * decay(d, 0.09) * 0.16
            accent = 1.0 if s % 4 == 0 else 0.7
            add(arp, v * accent, b * bar + s * step)
    arp_l = feedback_delay(arp, step * 3, 0.45, 0.5, 0)[:N]
    arp_r = feedback_delay(arp, step * 2, 0.45, 0.5, 0)[:N]

    # --- bass: 8th-note saw, plucked filter ---
    bass = np.zeros(N)
    for b in range(bars + 2):
        root = sorted(chords[(b // 2) % len(chords)])[0]
        while root > 40:
            root -= 12
        sec = section(b)
        if not drums or sec == "intro":
            # Sustained drone in quiet sections.
            d = bar
            v = lp(osc(midi(root), d, "saw"), 300) * adsr(d, 0.05, 0.2, 0.7, 0.3) * 0.35
            add(bass, v, b * bar)
            continue
        for e in range(8):
            d = beat / 2
            v = lp_sweep(osc(midi(root + (12 if e % 4 == 3 else 0)), d, "saw"), 1800, 200) * adsr(d, 0.003, 0.1, 0.5, 0.05) * 0.5
            add(bass, v, b * bar + e * beat / 2)

    # --- drums ---
    kick = np.zeros(N)
    snare = np.zeros(N)
    hats = np.zeros(N)
    if drums:
        k_d = 0.45
        k = osc(sweep(150, 42, 0.12) if False else np.concatenate([sweep(150, 42, 0.12), np.full(n_samples(k_d - 0.12), 42.0)]), None)
        k = drive(k * decay(k_d, 0.16) * 1.2 + hp(noise(k_d), 4000) * decay(k_d, 0.003) * 0.4, 1.5)
        sn_d = 0.35
        sn = bp(noise(sn_d), 900, 6000) * decay(sn_d, 0.09) + osc(sweep(240, 160, sn_d), None) * decay(sn_d, 0.05) * 0.6
        hh = hp(noise(0.06), 7000) * decay(0.06, 0.012)
        oh = hp(noise(0.3), 6000) * decay(0.3, 0.08)
        duck_d = beat * 0.95
        duck = 1 - 0.65 * np.exp(-secs(duck_d) / 0.09)
        for b in range(bars + 2):
            sec = section(b)
            for q in range(4):
                t0 = b * bar + q * beat
                if sec == "full":
                    add(kick, k, t0, 0.9)
                    s = n_samples(t0)
                    e = min(N, s + len(duck))
                    side[s:e] = np.minimum(side[s:e], duck[:e - s])
                    if q in (1, 3):
                        add(snare, sn, t0, 0.45)
                if sec != "break":
                    add(hats, oh if sec == "full" else hh, t0 + beat / 2, 0.22 if sec == "full" else 0.15)
                    for sx in range(4):
                        if sec == "full" and sx in (1, 3):
                            add(hats, hh, t0 + sx * beat / 4, 0.12)
        # Riser into the loop point (last bar of the break).
        rise_d = bar * 2
        riser = lp_sweep(noise(rise_d), 200, 10000) * np.linspace(0, 1, n_samples(rise_d)) ** 3 * 0.35
        add(snare, riser, (bars - 2) * bar)

    # --- atmosphere swells every 8 bars ---
    atmos = np.zeros(N)
    for b in range(0, bars + 2, 8):
        d = bar * 4
        sw = lp_sweep(noise(d), 300, 4000) * np.sin(np.linspace(0, np.pi, n_samples(d))) * 0.06
        add(atmos, sw, b * bar)

    # --- mix ---
    L = (pad_l + bass) * side + arp_l * (0.6 + 0.4 * side) + kick + snare + hats * 0.9 + atmos
    R = (pad_r + bass) * side + arp_r * (0.6 + 0.4 * side) + kick + snare + hats * 1.1 + atmos
    wet_l, wet_r = stereo_reverb(pad_l * 0.5 + arp_l * 0.5 + snare * 0.4, pad_r * 0.5 + arp_r * 0.5 + snare * 0.4, 1.0, 1.4, 5000, 0.0)
    L = L + wet_l[:N] * 0.35
    R = R + wet_r[:N] * 0.35

    # Fold the rendered tail back onto the start for a seamless loop.
    n_total = n_samples(total)
    L[:N - n_total] += L[n_total:]
    R[:N - n_total] += R[n_total:]
    L, R = L[:n_total], R[:n_total]
    L = drive(L * 0.9, 1.2)
    R = drive(R * 0.9, 1.2)
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    return L * 0.89 / m, R * 0.89 / m


def main():
    print("Engines:")
    write("engine_viper", engine_viper())
    write("engine_dart", engine_dart())
    write("engine_manta", engine_manta())
    write("engine_titan", engine_titan())
    write("engine_wraith", engine_wraith())
    write("engine_roar", engine_roar())
    write("afterburner", afterburner())
    write("airbrake", airbrake())
    write("missile_loop", missile_loop())

    print("Weapons / items:")
    write("gun_shot", gun_shot())
    write("bullet_hit", bullet_hit())
    write("bullet_ricochet", bullet_ricochet())
    write("missile_launch", missile_launch())
    write("explosion", explosion())
    write("explosion_big", explosion(3.4, True))
    write("boost", boost())
    write("hook_fire", hook_fire())
    write("hook_attach", hook_attach())
    write("hook_snap", hook_snap())
    write("invis_on", invis_on())
    write("invis_off", invis_off())
    write("repair", repair())

    print("Shield / race events:")
    write("shield_hit", shield_hit())
    write("shield_scrape", shield_scrape())
    write("shield_break", shield_break())
    write("shield_refill", shield_refill())
    write("fall", fall())
    write("respawn", respawn())
    write("hit_player", hit_player())

    print("Pickups:")
    write("pickup_boost", pickup_boost())
    write("pickup_machine_gun", pickup_machine_gun())
    write("pickup_invisibility", pickup_invisibility())
    write("pickup_hookshot", pickup_hookshot())
    write("pickup_missile", pickup_missile())
    write("pickup_repair", pickup_repair())
    write("pickup_forcefield", pickup_forcefield())

    print("UI:")
    write("ui_move", ui_move())
    write("ui_select", ui_select())

    print("Race flow:")
    write("countdown_beep", countdown_beep())
    write("go_beep", go_beep())
    write("perfect_start", perfect_start())
    write("stall", stall())
    write("lap", lap())
    write("finish", finish())

    print("Music:")
    race_chords = [[57, 60, 64, 67, 71], [53, 57, 60, 64, 67], [48, 52, 55, 59, 64], [55, 59, 62, 66, 69]]
    l, r = music_track(118, 32, race_chords, drums=True, arp_div=4, seed=7, energy=1.0)
    write("music_race", l, r)
    menu_chords = [[50, 53, 57, 60, 64], [46, 50, 53, 57, 62], [53, 57, 60, 64, 67], [48, 52, 55, 57, 62]]
    l, r = music_track(84, 16, menu_chords, drums=False, arp_div=2, seed=11, energy=0.4)
    write("music_hangar", l, r)


if __name__ == "__main__":
    main()
