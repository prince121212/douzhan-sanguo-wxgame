#!/usr/bin/env python3
"""从源素材库挑选 / 派生《斗战三国》音效与 BGM，输出到 assets/audio/ 并写 CREDITS.md。

源库优先用 打包-斗将三国/assets/audio；那边很多文件是 1 秒静音占位
（WAV 8078B / OGG 3520B / MP3 4510B，md5 固定），遇到占位就回退到
同一相对路径的 还原工程-windows/assets/audio（同一工程的完整版）。

只拷贝音频本体，不拷 .import。派生处理（马蹄、观众底噪、BGM 转码）全部用
ffmpeg + numpy 完成，参数写死，可重复生成。

用法：python3 tools/build_audio.py
"""
import hashlib
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))          # 斗战三国/
WS = os.path.dirname(ROOT)                                                    # 羁绊之旅/
SRC_PACKED = os.path.join(WS, "打包-斗将三国", "assets", "audio")
SRC_FULL = os.path.join(WS, "还原工程-windows", "assets", "audio")
DST = os.path.join(ROOT, "assets", "audio")
FFMPEG = "/usr/local/bin/ffmpeg"

PLACEHOLDER_MD5 = {
    "13fdc8fdcba5a74835dd0dbc5b33ada1",  # 1s 静音 WAV 8kHz 8bit
    "d4a625ed3d53127ea13a9456db0fa9e7",  # 1s 静音 OGG
    "f1c570d733eb780efadb4abe3ad99f94",  # 1s 静音 MP3
}

KENNEY = "Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt）"
CROWD_CC0 = "freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json）"
SRCPROJ = "源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程）"
SYNTH = "源工程 bond-feedback 原创合成音（见 bond-feedback/source.json）"
POKETRAVEL = "PokeTravel 音乐包（源工程 poketravel/source_manifest.json，许可未声明，发布前需确认）"
UNKNOWN = "源工程素材（来源/许可未声明）"

# (目标文件, 源相对路径, 用途, 来源许可)
COPIES = [
    # 挥砍 / 破风（短 -> 长）
    ("slash_1.wav", "move_quick.wav", "轻挥砍破风（0.20s，最短，普攻连段）", SRCPROJ),
    ("slash_2.wav", "move_razor.wav", "锐利挥砍（0.23s，高频偏亮，快刀）", SRCPROJ),
    ("slash_3.wav", "move_gust.wav", "中挥（0.32s，蓄力后出手）", SRCPROJ),
    ("slash_4.wav", "move_tailwind.wav", "长挥/横扫（0.60s，重击、大招挥舞）", SRCPROJ),
    # 金属撞击 / 格挡
    ("clang_1.wav", "impact_steel.wav", "兵器相交（0.20s，短促金属撞击）", SRCPROJ),
    ("clang_2.wav", "move_iron.wav", "格挡金属声（0.29s，中等余音）", SRCPROJ),
    ("clang_3.wav", "element_steel.wav", "重格挡/弹刀（0.40s，长余音）", SRCPROJ),
    ("clang_4.ogg", "beltHandle1.ogg", "轻金属磕碰（0.28s，甲片/轻格挡，真实拟音）", KENNEY),
    ("blade_draw_1.ogg", "drawKnife1.ogg", "拔刀/亮兵器（0.40s，偏弱，可做蓄力起手）", KENNEY),
    ("blade_draw_2.ogg", "drawKnife2.ogg", "拔刀/亮兵器（0.45s）", KENNEY),
    ("blade_draw_3.ogg", "drawKnife3.ogg", "刀刃刮擦（0.48s，带一下撞击，可做擦刀/格挡收尾）", KENNEY),
    # 命中
    ("hit_light.wav", "hit.wav", "轻命中（0.13s）", SRCPROJ),
    ("hit_heavy.wav", "impact_fire.wav", "重命中（0.22s，噪声冲击更厚）", SRCPROJ),
    ("hit_thud.wav", "impact_normal.wav", "低沉闷击（0.12s，可叠在重击/盾挡下层）", SRCPROJ),
    ("body_fall.wav", "element_rock.wav", "倒地/重物落地震地闷响（0.40s）", SRCPROJ),
    # 脚步
    ("step_1.ogg", "footstep00.ogg", "脚步（每个文件含两下踏步）", KENNEY),
    ("step_2.ogg", "footstep01.ogg", "脚步", KENNEY),
    ("step_3.ogg", "footstep02.ogg", "脚步", KENNEY),
    ("step_4.ogg", "footstep06.ogg", "脚步", KENNEY),
    # 跳跃 / 落地 / 冲刺
    ("jump.wav", "jump.wav", "起跳（0.16s，8-bit 风格上扬音）", SRCPROJ),
    ("land.wav", "land_light.wav", "落地（0.12s，低沉轻落地）", SRCPROJ),
    ("land_slide.wav", "land_slide.wav", "滑步落地/急停（0.17s）", SRCPROJ),
    ("dash.wav", "dash.wav", "冲刺（0.17s）", SRCPROJ),
    # 观众
    ("crowd_cheer_1.ogg", "tournament-crowd/cheer-1.ogg", "观众欢呼（3.8s）", CROWD_CC0),
    ("crowd_cheer_2.ogg", "tournament-crowd/cheer-2.ogg", "观众欢呼（4.4s）", CROWD_CC0),
    ("crowd_cheer_3.ogg", "tournament-crowd/cheer-3.ogg", "观众欢呼（4.0s）", CROWD_CC0),
    ("crowd_cheer_4.ogg", "tournament-crowd/cheer-4.ogg", "观众欢呼（4.3s）", CROWD_CC0),
    ("crowd_cheer_5.ogg", "tournament-crowd/cheer-5.ogg", "观众欢呼（3.6s）", CROWD_CC0),
    ("crowd_cheer_6.ogg", "tournament-crowd/cheer-6.ogg", "观众欢呼（5.8s，最长）", CROWD_CC0),
    ("crowd_ooh_1.ogg", "referee-japanese-current/crowd-1.ogg", "观众惊呼“哦——”（1.0s 单发，适合重击/大招命中）", UNKNOWN),
    ("crowd_ooh_2.ogg", "referee-japanese-current/crowd-2.ogg", "观众惊呼（0.75s 单发）", UNKNOWN),
    ("crowd_ooh_3.ogg", "referee-japanese-current/crowd-3.ogg", "观众惊呼（0.71s 单发）", UNKNOWN),
    # 环境
    ("wind_amb.wav", "story-ep126/wind.wav", "风声底噪（4.0s，可循环，24kHz 单声道）", SRCPROJ),
    # 胜负
    ("victory.wav", "battle-victory.wav", "胜利（8.6s）", SRCPROJ),
    ("defeat.wav", "battle-defeat.wav", "失败（11.1s）", SRCPROJ),
    # UI
    ("ui_click.wav", "ui.wav", "UI 点击（0.09s）", SRCPROJ),
    ("ui_confirm.wav", "success.wav", "UI 确认/成功（1.4s 上行琶音）", SRCPROJ),
    ("ui_select.wav", "switch.wav", "UI 切换/选择武将（0.28s）", SRCPROJ),
    # 大招
    ("ult_charge.wav", "bond-feedback/charge.wav", "大招蓄力（0.42s）", SYNTH),
    ("ult_cutin.wav", "bond-feedback/awaken.wav", "大招立绘切入（0.85s）", SYNTH),
]

# 马蹄：库里没有任何马相关音频，用最“重”的三个脚步降 3 个半音 + 低频增强代替
HORSE = [
    ("horse_step_1.ogg", "footstep08.ogg"),
    ("horse_step_2.ogg", "footstep04.ogg"),
    ("horse_step_3.ogg", "footstep09.ogg"),
]

BGM = [
    # (目标, [按顺序拼接的源], 用途, loop_offset 秒)
    ("bgm_battle.mp3", ["poketravel/BGM_Champion_Lance/Climax.wav"],
     "战斗 BGM（Champion Lance 的 Climax 段，152BPM，本身就是循环段）", 0.0),
    ("bgm_intro.mp3", ["poketravel/BGM_Champion_Blue/Intro.wav", "poketravel/BGM_Champion_Blue/LoopA.wav"],
     "开场/选将 BGM（Champion Blue：Intro 前奏 + LoopA 主循环，164BPM）", None),
]
MAX_BYTES = 8 * 1024 * 1024


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve(rel):
    """返回 (真实源路径, 说明)。打包库是占位符就回退到完整工程。"""
    packed = os.path.join(SRC_PACKED, rel)
    full = os.path.join(SRC_FULL, rel)
    if os.path.exists(packed) and md5(packed) not in PLACEHOLDER_MD5:
        return packed, ""
    if os.path.exists(full) and md5(full) not in PLACEHOLDER_MD5:
        why = "打包库同名文件是 1s 静音占位，改用还原工程完整版" if os.path.exists(packed) else "打包库缺文件，改用还原工程"
        return full, why
    raise FileNotFoundError(f"{rel}: 两个库都没有可用的真实文件")


def probe_duration(path):
    out = subprocess.run(["/opt/homebrew/bin/ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip()
    return float(out)


def load_f32(path, sr=44100, ch=2):
    p = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", str(ch), "-ar", str(sr), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, ch).copy()


def save_ogg(x, path, sr=44100, quality=5):
    raw = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(sr), "-ac", str(x.shape[1]), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), path], input=raw, check=True)


def rel_ws(path):
    return os.path.relpath(path, WS)


def make_horse(src, dst):
    sr = int(subprocess.run(["/opt/homebrew/bin/ffprobe", "-v", "error", "-select_streams", "a:0",
                             "-show_entries", "stream=sample_rate", "-of", "csv=p=0", src],
                            capture_output=True, text=True).stdout.strip())
    factor = 2 ** (-3 / 12)  # 降 3 个半音（等于慢放 1.19 倍）
    af = f"asetrate={sr * factor:.0f},aresample={sr},lowshelf=g=4:f=180,highshelf=g=-4:f=3500"
    p = subprocess.run([FFMPEG, "-v", "error", "-i", src, "-af", af, "-ac", "1", "-f", "f32le", "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, 1).copy()
    x *= 10 ** (-1.5 / 20) / max(1e-6, float(np.abs(x).max()))   # 峰值归一到 -1.5dBFS（Kenney 原件本身有过载）
    save_ogg(x, dst, sr, quality=5)


def make_crowd_bed(sources, dst, seconds=16.0, sr=44100, seed=7):
    """把 6 段 CC0 观众录音做成 16s 无缝循环的远处人群底噪：
    3 条声部各自随机串接（0.6s 交叉淡化）、轻微变调、左右分开，
    再低通 1.8kHz（压掉口哨/掌声的尖峰，听感变远）+ 高通 90Hz + 慢速压缩，
    最后首尾 1.5s 等功率交叉淡化成无缝循环。"""
    rng = np.random.default_rng(seed)
    clips = [load_f32(s, sr) for s in sources]
    xf = int(0.6 * sr)
    L, X = int(seconds * sr), int(1.5 * sr)
    voices = []
    # (变速比 up/down, 声像)：100/97 略慢略低，100/103 略快略高
    for v, (up, down, pan) in enumerate([(1, 1, 0.0), (100, 97, -0.35), (100, 103, 0.35)]):
        skip = int(v * 2.3 * sr)          # 各声部错开起点（多生成一段再切掉，不用 roll，避免硬接缝）
        need = L + X + skip
        out = np.zeros((0, 2), np.float32)
        while len(out) < need:
            c = clips[rng.integers(len(clips))]
            seg = c[int(rng.uniform(0, 0.25) * len(c)):]
            if up != down:
                seg = signal.resample_poly(seg, up, down, axis=0).astype(np.float32)
            if len(out) == 0:
                out = seg
            else:
                fade = np.linspace(0, 1, xf, dtype=np.float32)[:, None]
                out = np.concatenate([out[:-xf], out[-xf:] * np.sqrt(1 - fade) + seg[:xf] * np.sqrt(fade), seg[xf:]])
        out = out[skip:need]
        # 一半保留原立体声，一半做等功率声像，拉开三个声部
        gl, gr = np.cos((pan + 1) * np.pi / 4) * 1.414, np.sin((pan + 1) * np.pi / 4) * 1.414
        mono = out.mean(axis=1)
        out = np.stack([0.5 * out[:, 0] + 0.5 * gl * mono, 0.5 * out[:, 1] + 0.5 * gr * mono], 1)
        voices.append(out)
    bed = sum(voices) / len(voices)
    sos_lp = signal.butter(4, 1800, "low", fs=sr, output="sos")
    sos_hp = signal.butter(2, 90, "high", fs=sr, output="sos")
    bed = signal.sosfiltfilt(sos_hp, signal.sosfiltfilt(sos_lp, bed, axis=0), axis=0)
    # 慢速自动增益（平滑 0.8s），让底噪电平稳定
    power = signal.sosfiltfilt(signal.butter(1, 1.2, "low", fs=sr, output="sos"), (bed ** 2).mean(1))
    env = np.sqrt(np.maximum(power, 0.0) + 1e-9)   # filtfilt 可能出现极小负值
    target = np.median(env)
    gain = np.clip(target / env, 0.5, 2.0) ** 0.7
    bed = bed * gain[:, None]
    # 无缝循环：取 seconds + 1.5s，把尾巴 1.5s 交叉淡化进开头
    seg = bed[: L + X]
    fade = np.linspace(0, 1, X)[:, None]
    head = seg[:X] * np.sqrt(fade) + seg[L:L + X] * np.sqrt(1 - fade)
    loop = np.concatenate([head, seg[X:L]])
    # 电平：RMS -27 dBFS，峰值不超过 -6 dBFS
    rms = np.sqrt(np.mean(loop ** 2))
    loop *= 10 ** (-27 / 20) / rms
    pk = np.max(np.abs(loop))
    if pk > 10 ** (-6 / 20):
        loop *= 10 ** (-6 / 20) / pk
    save_ogg(loop.astype(np.float32), dst, sr, quality=4)


def make_bgm(srcs, dst):
    total_wav = sum(os.path.getsize(s) for s in srcs)
    # 规则：源超过 8MB 就用 128kbps；否则 192kbps（必须转成 mp3）
    kbps = 128 if total_wav > MAX_BYTES else 192
    base = [FFMPEG, "-v", "error", "-y"]
    for s in srcs:
        base += ["-i", s]
    # 源母带峰值贴 0dBFS，MP3 解码会过冲，整体 -1dB 留余量
    ins = "".join(f"[{i}:a]" for i in range(len(srcs)))
    graph = (f"{ins}concat=n={len(srcs)}:v=0:a=1,volume=-1dB[a]" if len(srcs) > 1 else "[0:a]volume=-1dB[a]")
    base += ["-filter_complex", graph, "-map", "[a]"]

    def encode(rate):
        subprocess.run(base + ["-c:a", "libmp3lame", "-b:a", f"{rate}k", "-ar", "44100", dst], check=True)

    encode(kbps)
    if os.path.getsize(dst) > MAX_BYTES:  # 理论上不会发生，兜底再压
        kbps = 96
        encode(kbps)
    return kbps, total_wav


def main():
    os.makedirs(DST, exist_ok=True)
    rows = []   # (目标, 源, 处理, 许可, 用途)
    fails = []
    for dst_name, rel, use, lic in COPIES:
        try:
            src, why = resolve(rel)
        except FileNotFoundError as e:
            fails.append(str(e))
            continue
        shutil.copyfile(src, os.path.join(DST, dst_name))
        rows.append((dst_name, rel_ws(src), "原样拷贝" + (f"；{why}" if why else ""), lic, use))
        print(f"[copy] {dst_name:22s} <- {rel_ws(src)}")

    for dst_name, rel in HORSE:
        src, why = resolve(rel)
        make_horse(src, os.path.join(DST, dst_name))
        rows.append((dst_name, rel_ws(src),
                     "派生：降 3 个半音（慢放）+ 低频 +4dB / 高频 -4dB，峰值归一 -1.5dBFS，模拟土地上的马蹄闷响", KENNEY,
                     "马蹄（源库无任何马嘶/马蹄音频，用最重的脚步代替）"))
        print(f"[horse] {dst_name:21s} <- {rel_ws(src)}")

    crowd_src = [resolve(f"tournament-crowd/cheer-{i}.ogg")[0] for i in range(1, 7)]
    make_crowd_bed(crowd_src, os.path.join(DST, "crowd_amb.ogg"))
    rows.append(("crowd_amb.ogg", rel_ws(os.path.dirname(crowd_src[0])) + "/cheer-1..6.ogg",
                 "派生：3 声部随机串接+轻微变调+低通 1.8kHz+慢速自动增益，16s 首尾交叉淡化无缝循环，RMS≈-27dBFS",
                 CROWD_CC0,
                 "观众杂音底噪（循环）。指定的 referee-japanese-current/crowd-1.ogg 只有 1s 单发惊呼，"
                 "不适合做底噪，已改为 crowd_ooh_1.ogg"))
    print("[crowd] crowd_amb.ogg <- tournament-crowd/cheer-1..6.ogg")

    bgm_rows = []
    for dst_name, rels, use, loop_offset in BGM:
        srcs, whys = zip(*[resolve(r) for r in rels])
        out = os.path.join(DST, dst_name)
        kbps, wav_bytes = make_bgm(list(srcs), out)
        if loop_offset is None:
            loop_offset = probe_duration(srcs[0])
        note = (f"转码 MP3 {kbps}kbps/44.1kHz（源 WAV 共 {wav_bytes / 1048576:.1f}MB），整体 -1dB 防解码过载"
                + ("；按顺序拼接" if len(srcs) > 1 else "")
                + (f"；{whys[0]}" if whys[0] else ""))
        src_desc = " + ".join(rel_ws(s) for s in srcs)
        rows.append((dst_name, src_desc, note, POKETRAVEL, use + (f"；循环点 loop_offset={loop_offset:.3f}s" if loop_offset else "")))
        bgm_rows.append((dst_name, loop_offset, os.path.getsize(out)))
        print(f"[bgm] {dst_name} {kbps}kbps {os.path.getsize(out) / 1048576:.2f}MB loop_offset={loop_offset:.3f}")

    write_credits(rows, fails)
    if fails:
        print("失败：", *fails, sep="\n  ")
        sys.exit(1)


def write_credits(rows, fails):
    lines = [
        "# 音频素材来源（CREDITS）",
        "",
        "由 `tools/build_audio.py` 生成，可重复执行。路径相对于工作区 `羁绊之旅/`。",
        "",
        "- 主源库：`打包-斗将三国/assets/audio`。该打包版里大量文件是 **1 秒静音占位**"
        "（全部 BGM、`battle-victory.wav`、`battle-defeat.wav`、`voice/` 整个目录等，md5 相同），"
        "遇到占位时自动回退到同一相对路径的 `还原工程-windows/assets/audio`（同一工程的完整版）。",
        "- 只拷贝音频本体，未拷贝任何 `.import`；Godot 打开工程时会自动重新导入。",
        "- `audio/voice/m15/sword.ogg` 实际是 6.9 秒的角色对白（同目录还有 boast/fear/lesson 等台词），不是挥砍音效，未采用。",
        "- 源库中没有任何马嘶/马蹄音频，马蹄用脚步派生代替；**马嘶缺失**。",
        "- 许可提醒：Kenney 与 tournament-crowd 为 CC0，可放心使用；其余来自源工程（宝可梦同人作品）或 PokeTravel 音乐包，"
        "许可未声明，商业发布前请确认或替换。",
        "",
        "| 目标文件 | 源文件 | 处理 | 来源 / 许可 | 用途 |",
        "|---|---|---|---|---|",
    ]
    for dst_name, src, how, lic, use in rows:
        lines.append(f"| `assets/audio/{dst_name}` | `{src}` | {how} | {lic} | {use} |")
    if fails:
        lines += ["", "## 失败项", ""] + [f"- {f}" for f in fails]
    with open(os.path.join(DST, "CREDITS.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"CREDITS.md: {len(rows)} 条")


if __name__ == "__main__":
    main()
