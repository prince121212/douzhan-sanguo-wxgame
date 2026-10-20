#!/usr/bin/env python3
"""程序合成源库里没有的音效：战鼓、铜锣、马嘶、弓弦、拆招、破防、怒吼、蓄力等。

纯 numpy 生成，输出 44.1kHz 16bit 单声道 WAV。可重复执行。
用法：python3 synth_sfx.py <输出目录> [源音频目录]
"""
import os
import sys
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(dur, decay, attack=0.002):
    t = t_axis(dur)
    e = np.exp(-t / decay)
    a = np.clip(t / attack, 0, 1) if attack > 0 else 1
    return e * a


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def lowpass(x, cutoff):
    # 一阶低通，多次叠加近似更陡
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lowpass_fast(x, cutoff, passes=2):
    from scipy.signal import butter, lfilter
    b, a = butter(passes, cutoff / (SR / 2), "low")
    return lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    from scipy.signal import butter, lfilter
    b, a = butter(order, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    from scipy.signal import butter, lfilter
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return lfilter(b, a, x)


def reverb(x, length=1.2, mix=0.25, damp=3000):
    n = int(length * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * length / 5))
    ir = lowpass_fast(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    from scipy.signal import fftconvolve
    wet = fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry * (1 - mix) + wet * mix


def norm(x, peak_db=-2.0):
    p = np.max(np.abs(x)) + 1e-9
    return x / p * (10 ** (peak_db / 20))


def fade_out(x, ms=30):
    n = min(len(x), int(SR * ms / 1000))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(path, x, peak_db=-2.0):
    x = fade_out(norm(np.asarray(x, dtype=np.float64), peak_db))
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {os.path.basename(path)}  {len(x) / SR:.2f}s")


# ---------------------------------------------------------------- 各音效

def drum(pitch=1.0, big=False):
    """战鼓：低频下滑的鼓腔 + 鼓皮击打噪声 + 混响"""
    dur = 1.6 if big else 1.1
    t = t_axis(dur)
    f = (95 * pitch) * (1 + 0.9 * np.exp(-t / 0.03))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / (0.32 if big else 0.22))
    body += 0.35 * np.sin(ph * 1.6) * np.exp(-t / 0.12)
    skin = lowpass_fast(noise(dur), 1800) * np.exp(-t / 0.035) * 0.9
    thump = np.sin(2 * np.pi * 48 * pitch * t) * np.exp(-t / 0.4) * (0.7 if big else 0.4)
    x = body + skin + thump
    x = np.tanh(x * 1.6)
    return reverb(x, 1.4 if big else 1.0, 0.22, 2500)


def gong():
    """铜锣：一组不谐和泛音，缓慢衰减，带拍频"""
    dur = 3.6
    t = t_axis(dur)
    partials = [(176, 1.0, 1.8), (233, 0.5, 1.4), (391, 0.7, 1.2), (523, 0.45, 0.9),
                (647, 0.35, 0.8), (893, 0.3, 0.6), (1187, 0.2, 0.45), (1530, 0.14, 0.35)]
    x = np.zeros_like(t)
    for f, a, d in partials:
        beat = 1 + 0.004 * np.sin(2 * np.pi * 1.3 * t)
        swell = np.clip(t / 0.06, 0, 1)
        x += a * np.sin(2 * np.pi * f * beat * t + rng.random() * 6) * np.exp(-t / d) * swell
    hit = bandpass(noise(dur), 300, 4000) * np.exp(-t / 0.05) * 0.5
    x = x + hit
    return reverb(x, 2.0, 0.3, 4000)


def neigh():
    """马嘶：带快速颤音的高音锯齿，先升后降，再加呼气声"""
    dur = 1.35
    t = t_axis(dur)
    u = t / dur
    f0 = 620 + 900 * np.sin(np.clip(u * 1.25, 0, 1) * np.pi) ** 0.8 - 260 * u
    trill = 1 + 0.07 * np.sin(2 * np.pi * (22 + 8 * u) * t)
    f = f0 * trill
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    voice = bandpass(saw, 700, 3800, 2)
    amp = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.35, 0, 1)
    amp *= 0.75 + 0.25 * np.sin(2 * np.pi * 11 * t)
    breath = bandpass(noise(dur), 1500, 6000) * 0.25 * amp
    snort = bandpass(noise(0.18), 300, 1500)
    snort = np.concatenate([snort * np.exp(-t_axis(0.18) / 0.05), np.zeros(len(t) - len(snort))])
    x = voice * amp + breath + snort * 0.6
    return reverb(x, 0.7, 0.18, 5000)


def bow():
    """弓弦：Karplus-Strong 拨弦 + 箭离弦的'嗖'"""
    dur = 0.7
    n = int(dur * SR)
    period = int(SR / 98)
    buf = rng.standard_normal(period) * 0.8
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        nxt = 0.497 * (buf[i % period] + buf[(i + 1) % period])
        buf[i % period] = nxt
    t = t_axis(dur)
    out *= np.exp(-t / 0.18)
    whoosh = bandpass(noise(dur), 2500, 9000) * np.exp(-((t - 0.05) / 0.04) ** 2) * 0.6
    snap = highpass(noise(dur), 3000) * np.exp(-t / 0.006) * 0.8
    return out + whoosh + snap


def parry():
    """拆招：清脆的金属'叮——'，高频不谐和泛音"""
    dur = 1.2
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f, a, d in [(2093, 1.0, 0.35), (3311, 0.6, 0.25), (4567, 0.4, 0.18), (5987, 0.25, 0.12), (1320, 0.5, 0.5)]:
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
    x += highpass(noise(dur), 2000) * np.exp(-t / 0.01) * 1.2
    return reverb(x, 0.9, 0.25, 7000)


def guard_break():
    """破防：沉闷的撞击 + 金属崩裂 + 碎响"""
    dur = 0.9
    t = t_axis(dur)
    low = np.sin(2 * np.pi * 70 * t * (1 + 0.6 * np.exp(-t / 0.04))) * np.exp(-t / 0.2)
    crack = bandpass(noise(dur), 1200, 6000) * np.exp(-t / 0.06)
    ring_ = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
                for f, a, d in [(830, 0.5, 0.25), (1390, 0.35, 0.18), (2210, 0.25, 0.12)])
    rattle = bandpass(noise(dur), 3000, 8000) * (np.exp(-((t - 0.12) / 0.05) ** 2) * 0.5)
    x = np.tanh((low * 1.2 + crack * 0.8 + ring_ + rattle) * 1.4)
    return reverb(x, 0.8, 0.2, 4000)


def rage():
    """怒气满：上扬的光芒音 + 呼啸"""
    dur = 1.1
    t = t_axis(dur)
    f = 220 * (2 ** (t / dur * 1.6))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = (np.sin(ph) + 0.4 * np.sin(ph * 2.01) + 0.25 * np.sin(ph * 3.02)) * np.sin(np.pi * t / dur)
    swish = bandpass(noise(dur), 800, 5000) * np.sin(np.pi * t / dur) ** 2 * 0.5
    return reverb(tone * 0.6 + swish, 1.0, 0.25, 6000)


def charge():
    """蓄力：逐渐升高、颤动的嗡鸣"""
    dur = 0.8
    t = t_axis(dur)
    f = 140 + 520 * (t / dur) ** 1.4
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t))
    x += 0.3 * bandpass(noise(dur), 400, 2500) * (t / dur)
    return x * np.clip(t / 0.05, 0, 1)


def charge_full():
    """蓄满：短促的'铮'"""
    dur = 0.6
    t = t_axis(dur)
    x = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, a, d in [(1760, 1, 0.2), (2640, 0.5, 0.15), (3520, 0.3, 0.1)])
    return reverb(x, 0.6, 0.2, 8000)


def dodge_perfect():
    """完美闪避：空气撕裂 + 风铃"""
    dur = 0.8
    t = t_axis(dur)
    sweep = bandpass(noise(dur), 900, 7000) * np.exp(-((t - 0.08) / 0.07) ** 2)
    chime = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-(t - 0.05).clip(0) / 0.25) * (t > 0.05)
                for f, a in [(1568, 0.5), (2349, 0.35), (3136, 0.2)])
    return reverb(sweep + chime, 0.8, 0.3, 8000)


def clash_hold():
    """拼刀角力：持续的刀刃摩擦与震颤"""
    dur = 2.2
    t = t_axis(dur)
    grind = bandpass(noise(dur), 1800, 7000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * t)))
    hum = sum(a * np.sin(2 * np.pi * f * t + 2 * np.sin(2 * np.pi * 6 * t))
              for f, a in [(620, 0.3), (1240, 0.2), (1890, 0.12)])
    amp = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    return (grind * 0.6 + hum) * amp


def roar():
    """怒吼：低沉的喉音嘶吼（锯齿+共振峰+粗糙噪声）"""
    dur = 1.5
    t = t_axis(dur)
    f = 115 + 40 * np.sin(np.pi * t / dur) - 30 * (t / dur)
    f = f * (1 + 0.04 * np.sin(2 * np.pi * 31 * t) + 0.03 * rng.standard_normal(len(t)).cumsum() / 400)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    v = bandpass(saw, 300, 900) * 1.0 + bandpass(saw, 1100, 2600) * 0.6
    grit = bandpass(noise(dur), 400, 3000) * 0.5
    amp = np.clip(t / 0.08, 0, 1) * np.clip((dur - t) / 0.4, 0, 1)
    x = np.tanh((v + grit) * amp * 2.2)
    return reverb(x, 1.2, 0.3, 3500)


def ko():
    """终结：巨大低频轰鸣 + 尾音"""
    dur = 2.4
    t = t_axis(dur)
    boom = np.sin(2 * np.pi * 42 * t * (1 + 1.2 * np.exp(-t / 0.05))) * np.exp(-t / 0.7)
    crack = lowpass_fast(noise(dur), 2500) * np.exp(-t / 0.08) * 0.9
    sub = np.sin(2 * np.pi * 30 * t) * np.exp(-t / 1.0) * 0.5
    x = np.tanh((boom + crack + sub) * 1.5)
    return reverb(x, 2.0, 0.35, 2000)


def wind_gust():
    """一阵风沙：带通噪声，起伏"""
    dur = 2.8
    t = t_axis(dur)
    amp = np.sin(np.pi * t / dur) ** 1.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 1.7 * t))
    x = bandpass(noise(dur), 300, 2200) * amp
    x += bandpass(noise(dur), 2500, 6000) * amp * 0.25
    return x


def ult_whoosh():
    """绝技切入：重低音冲击 + 长呼啸"""
    dur = 1.4
    t = t_axis(dur)
    hit = np.sin(2 * np.pi * 55 * t * (1 + 1.5 * np.exp(-t / 0.03))) * np.exp(-t / 0.35)
    sw = bandpass(noise(dur), 500, 6000) * np.exp(-((t - 0.25) / 0.2) ** 2) * 0.7
    ring_ = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.6) for f, a in [(440, 0.2), (660, 0.15), (880, 0.1)])
    return reverb(np.tanh((hit + sw + ring_) * 1.4), 1.3, 0.3, 4000)


def victory_drums():
    """得胜鼓：咚——咚咚 咚！ + 铜锣收尾"""
    dur = 4.2
    out = np.zeros(int(dur * SR))
    for at, pitch, big, vol in [(0.0, 0.85, True, 1.0), (0.42, 1.0, False, 0.7), (0.62, 1.0, False, 0.75), (0.95, 0.8, True, 1.0), (1.3, 1.1, False, 0.5), (1.45, 1.05, False, 0.55), (1.6, 0.78, True, 1.0)]:
        d = drum(pitch, big) * vol
        i = int(at * SR)
        n = min(len(d), len(out) - i)
        out[i:i + n] += d[:n]
    g = gong() * 0.75
    i = int(1.6 * SR)
    n = min(len(g), len(out) - i)
    out[i:i + n] += g[:n]
    return np.tanh(out * 0.9)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    print("合成音效 ->", out_dir)
    save(os.path.join(out_dir, "drum_1.wav"), drum(1.0))
    save(os.path.join(out_dir, "drum_2.wav"), drum(0.9))
    save(os.path.join(out_dir, "drum_3.wav"), drum(1.1))
    save(os.path.join(out_dir, "drum_big.wav"), drum(0.8, True))
    save(os.path.join(out_dir, "gong.wav"), gong())
    save(os.path.join(out_dir, "horse_neigh.wav"), neigh(), -5.0)
    save(os.path.join(out_dir, "bow_1.wav"), bow())
    save(os.path.join(out_dir, "bow_2.wav"), bow())
    save(os.path.join(out_dir, "parry.wav"), parry(), -3.0)
    save(os.path.join(out_dir, "guard_break.wav"), guard_break())
    save(os.path.join(out_dir, "rage.wav"), rage(), -4.0)
    save(os.path.join(out_dir, "charge.wav"), charge(), -6.0)
    save(os.path.join(out_dir, "charge_full.wav"), charge_full(), -5.0)
    save(os.path.join(out_dir, "dodge_perfect.wav"), dodge_perfect(), -4.0)
    save(os.path.join(out_dir, "clash_hold.wav"), clash_hold(), -6.0)
    save(os.path.join(out_dir, "roar.wav"), roar(), -3.0)
    save(os.path.join(out_dir, "ko.wav"), ko())
    save(os.path.join(out_dir, "wind.wav"), wind_gust(), -6.0)
    save(os.path.join(out_dir, "ult_whoosh.wav"), ult_whoosh())
    save(os.path.join(out_dir, "victory_drums.wav"), victory_drums(), -1.5)


if __name__ == "__main__":
    main(sys.argv[1])
