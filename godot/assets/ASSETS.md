# 斗战三国 · 素材清单（ASSETS）

所有路径以 `res://assets/` 开头。素材由 `tools/` 下的脚本生成/拷贝，可重复执行：
`slice_sheets.py`（武将，已有）、`slice_troops.py`（小兵）、`build_audio.py`（音频）、`build_bg.py`（背景）、`build_ui.py`（UI + 字体）。
音频来源与许可见 `audio/CREDITS.md`，字体来源与许可见 `fonts/CREDITS.md`。

## 1. 音效与音乐 `assets/audio/`

| 类别 | 文件 | 最终路径 | 时长 | 格式 | 用途 |
|---|---|---|---|---|---|
| 挥砍 / 破风 | `slash_1.wav` | `res://assets/audio/slash_1.wav` | 0.20s | PCM16 32k 单声道 | 轻挥砍破风，最短，普攻第 1、2 段 |
|  | `slash_2.wav` | `res://assets/audio/slash_2.wav` | 0.23s | PCM16 32k 单声道 | 锐利挥砍，高频偏亮，快刀/连段 |
|  | `slash_3.wav` | `res://assets/audio/slash_3.wav` | 0.32s | PCM16 32k 单声道 | 中挥，蓄力后出手 |
|  | `slash_4.wav` | `res://assets/audio/slash_4.wav` | 0.60s | PCM16 32k 单声道 | 长挥/横扫，重击、大招挥舞 |
| 兵器 / 金属 | `clang_1.wav` | `res://assets/audio/clang_1.wav` | 0.20s | PCM16 32k 单声道 | 兵器相交，短促金属撞击（拼刀首选） |
|  | `clang_2.wav` | `res://assets/audio/clang_2.wav` | 0.29s | PCM16 32k 单声道 | 格挡金属声，中等余音 |
|  | `clang_3.wav` | `res://assets/audio/clang_3.wav` | 0.40s | PCM16 32k 单声道 | 重格挡/弹刀，长余音 |
|  | `clang_4.ogg` | `res://assets/audio/clang_4.ogg` | 0.28s | Vorbis 48k 立体声 | 轻金属磕碰（真实拟音），甲片声/轻格挡 |
|  | `blade_draw_1.ogg` | `res://assets/audio/blade_draw_1.ogg` | 0.40s | Vorbis 48k 立体声 | 拔刀/亮兵器，音量偏小，可做蓄力起手 |
|  | `blade_draw_2.ogg` | `res://assets/audio/blade_draw_2.ogg` | 0.45s | Vorbis 48k 立体声 | 拔刀/亮兵器 |
|  | `blade_draw_3.ogg` | `res://assets/audio/blade_draw_3.ogg` | 0.48s | Vorbis 48k 立体声 | 刀刃刮擦+一下撞击，可做擦刀/格挡收尾 |
| 命中 / 倒地 | `hit_light.wav` | `res://assets/audio/hit_light.wav` | 0.13s | PCM16 22.05k 单声道 | 轻命中 |
|  | `hit_heavy.wav` | `res://assets/audio/hit_heavy.wav` | 0.22s | PCM16 32k 单声道 | 重命中（噪声冲击更厚） |
|  | `hit_thud.wav` | `res://assets/audio/hit_thud.wav` | 0.12s | PCM16 32k 单声道 | 低沉闷击，可叠在重击/盾挡下层 |
|  | `body_fall.wav` | `res://assets/audio/body_fall.wav` | 0.40s | PCM16 32k 单声道 | 倒地/重物落地震地闷响 |
| 移动 | `step_1.ogg` | `res://assets/audio/step_1.ogg` | 0.25s | Vorbis 48k 立体声 | 脚步（每个文件含两下踏步，随机轮换 1..4） |
|  | `step_2.ogg` | `res://assets/audio/step_2.ogg` | 0.28s | Vorbis 48k 立体声 | 脚步 |
|  | `step_3.ogg` | `res://assets/audio/step_3.ogg` | 0.24s | Vorbis 48k 立体声 | 脚步 |
|  | `step_4.ogg` | `res://assets/audio/step_4.ogg` | 0.24s | Vorbis 48k 立体声 | 脚步 |
|  | `jump.wav` | `res://assets/audio/jump.wav` | 0.16s | PCM16 22.05k 单声道 | 起跳（8-bit 上扬音） |
|  | `land.wav` | `res://assets/audio/land.wav` | 0.12s | PCM16 32k 单声道 | 落地（低沉轻落地） |
|  | `land_slide.wav` | `res://assets/audio/land_slide.wav` | 0.17s | PCM16 32k 单声道 | 滑步落地/急停 |
|  | `dash.wav` | `res://assets/audio/dash.wav` | 0.17s | PCM16 22.05k 单声道 | 冲刺 |
| 马 | `horse_step_1.ogg` | `res://assets/audio/horse_step_1.ogg` | 0.30s | Vorbis 48k 单声道 | 马蹄（脚步降调+低频增强派生，源库无马蹄/马嘶） |
|  | `horse_step_2.ogg` | `res://assets/audio/horse_step_2.ogg` | 0.38s | Vorbis 48k 单声道 | 马蹄 |
|  | `horse_step_3.ogg` | `res://assets/audio/horse_step_3.ogg` | 0.26s | Vorbis 48k 单声道 | 马蹄 |
| 观众 / 环境 | `crowd_cheer_1.ogg` | `res://assets/audio/crowd_cheer_1.ogg` | 3.80s | Vorbis 44.1k 立体声 | 观众欢呼（单次触发，随机轮换 1..6） |
|  | `crowd_cheer_2.ogg` | `res://assets/audio/crowd_cheer_2.ogg` | 4.40s | Vorbis 44.1k 立体声 | 观众欢呼 |
|  | `crowd_cheer_3.ogg` | `res://assets/audio/crowd_cheer_3.ogg` | 4.00s | Vorbis 44.1k 立体声 | 观众欢呼 |
|  | `crowd_cheer_4.ogg` | `res://assets/audio/crowd_cheer_4.ogg` | 4.30s | Vorbis 44.1k 立体声 | 观众欢呼 |
|  | `crowd_cheer_5.ogg` | `res://assets/audio/crowd_cheer_5.ogg` | 3.60s | Vorbis 44.1k 立体声 | 观众欢呼 |
|  | `crowd_cheer_6.ogg` | `res://assets/audio/crowd_cheer_6.ogg` | 5.80s | Vorbis 44.1k 立体声 | 观众欢呼（最长） |
|  | `crowd_ooh_1.ogg` | `res://assets/audio/crowd_ooh_1.ogg` | 1.04s | Vorbis 24k 立体声 | 观众惊呼“哦——”单发，重击/大招命中时用 |
|  | `crowd_ooh_2.ogg` | `res://assets/audio/crowd_ooh_2.ogg` | 0.76s | Vorbis 24k 立体声 | 观众惊呼单发 |
|  | `crowd_ooh_3.ogg` | `res://assets/audio/crowd_ooh_3.ogg` | 0.72s | Vorbis 24k 立体声 | 观众惊呼单发 |
|  | `crowd_amb.ogg` | `res://assets/audio/crowd_amb.ogg` | 16.00s | Vorbis 44.1k 立体声 | **循环**：远处观众杂音底噪，首尾已做无缝 |
|  | `wind_amb.wav` | `res://assets/audio/wind_amb.wav` | 4.00s | PCM16 24k 单声道 | **循环**：风声底噪（导入时 Loop Mode 设 Forward） |
| 胜负 / UI / 大招 | `victory.wav` | `res://assets/audio/victory.wav` | 8.64s | PCM16 44.1k 立体声 | 胜利 |
|  | `defeat.wav` | `res://assets/audio/defeat.wav` | 11.14s | PCM16 44.1k 立体声 | 失败 |
|  | `ui_click.wav` | `res://assets/audio/ui_click.wav` | 0.09s | PCM16 22.05k 单声道 | UI 点击 |
|  | `ui_confirm.wav` | `res://assets/audio/ui_confirm.wav` | 1.40s | PCM16 22.05k 单声道 | UI 确认/开战（上行琶音） |
|  | `ui_select.wav` | `res://assets/audio/ui_select.wav` | 0.28s | PCM16 22.05k 单声道 | UI 切换/选择武将 |
|  | `ult_charge.wav` | `res://assets/audio/ult_charge.wav` | 0.42s | PCM16 48k 单声道 | 大招蓄力 |
|  | `ult_cutin.wav` | `res://assets/audio/ult_cutin.wav` | 0.85s | PCM16 48k 单声道 | 大招立绘切入 |
| BGM | `bgm_battle.mp3` | `res://assets/audio/bgm_battle.mp3` | 37.89s | MP3 44.1k 立体声 | **循环**：战斗 BGM（Champion Lance 高潮段，152BPM，整段循环，loop_offset=0） |
|  | `bgm_intro.mp3` | `res://assets/audio/bgm_intro.mp3` | 70.24s | MP3 44.1k 立体声 | **循环**：开场/选将 BGM（Champion Blue 前奏+主循环，164BPM，loop_offset=11.707） |

循环设置（Godot 导入面板）：`crowd_amb.ogg`、`bgm_battle.mp3` 勾选 Loop；`bgm_intro.mp3` 勾选 Loop 且 Loop Offset = 11.707；`wind_amb.wav` 的 Loop Mode 选 Forward。其余都是单次触发。
MP3 编码自带约 25ms 的起始静音，若循环点能听出细微停顿，可把对应源 WAV（见 CREDITS）用 ffmpeg 转成 .ogg 替换。
缺失项：**马嘶**（源库没有任何马叫声）。

## 2. 战场背景 `assets/bg/`

| 文件 | 尺寸 | 用途 |
|---|---|---|
| `hulaoguan.png` | 1672×941 | 虎牢关原图整幅（含两侧营寨道具），不做视差时等比放大 1.1483 倍铺满 1920×1080 |
| `hulaoguan_sky.png` | 1920×540 | 远景层：天空/云/远山 + 原图上部（悬崖、城墙、关楼）原像素 1:1；悬崖向上用纹理拼接加高，左右各 124px 镜像渐进模糊填充；可水平无缝平铺 |
| `hulaoguan_ground.png` | 2600×1200 | 近景地面层：原图空地纹理拼接（无镜像轴、无重复块）；可水平无缝平铺；顶部 48px alpha 羽化 |
| `hulaoguan_parallax.json` | — | 每层尺寸、建议 scroll_scale、摆放位置、z_index |

建议视差（Godot 4 `Parallax2D`，视口 1920×1080）：

| 层 | scroll_scale | position | z_index | repeat_size | 备注 |
|---|---|---|---|---|---|
| sky | (0.3, 0.15) | (0, 0) | -30 | (1920, 0) | 地平线 y≈495 |
| ground | (1.0, 1.0) | (-340, 492) | -10 | (2600, 0) | 角色脚底线建议 y=900 |
| full_scene | (0.85, 0.85) | (0, 0) | -20 | — | 可选，scale=1.1483 |

## 3. 武将 `assets/chars/`（已有，未改动）

路径 `res://assets/chars/<组>/<动作>.png`。每张都是紧裁剪透明 PNG，尺寸各不相同；摆放时以 `chars/manifest.json` 里该动作的 `anchor`（脚底点）为原点，`tip` 为兵器尖，`stand_height` 为待机身高（用于统一比例）。

| 组 | 身高 | idle | walk_l | walk_r | windup | attack | hurt | jump | down |
|---|---|---|---|---|---|---|---|---|---|
| `stand/dianwei` | 353 | 425×377 | 378×383 | 376×377 | 443×359 | 507×361 | 418×352 | 413×386 | 487×280 |
| `stand/guanyu` | 405 | 405×429 | 391×422 | 387×422 | 365×417 | 550×366 | 357×419 | 407×428 | 442×302 |
| `stand/huangzhong` | 368 | 343×392 | 343×395 | 342×392 | 419×378 | 505×376 | 371×380 | 369×384 | 430×291 |
| `stand/machao` | 389 | 368×413 | 365×413 | 364×410 | 388×385 | 524×374 | 337×382 | 391×428 | 429×308 |
| `stand/xuchu` | 377 | 388×402 | 390×399 | 390×399 | 371×379 | 522×379 | 383×363 | 395×388 | 429×281 |
| `stand/zhangfei` | 401 | 382×425 | 366×428 | 371×427 | 418×376 | 548×369 | 357×387 | 417×425 | 460×309 |
| `stand/zhaoyun` | 381 | 370×405 | 360×405 | 364×399 | 379×386 | 497×378 | 351×383 | 396×427 | 426×292 |
| `mount/dianwei` | 387 | 381×412 | 380×411 | 388×410 | 374×443 | 484×389 | 351×397 | 388×377 | 416×307 |
| `mount/guanyu` | 394 | 342×418 | 351×418 | 360×417 | 381×431 | 484×373 | 386×398 | 356×386 | 414×303 |
| `mount/huangzhong` | 401 | 364×425 | 367×425 | 370×426 | 371×422 | 394×409 | 508×416 | 383×376 | 405×338 |
| `mount/lvbu` | 409 | 365×433 | 372×414 | 370×416 | 419×454 | 497×405 | 380×405 | 452×393 | 427×349 |
| `mount/machao` | 394 | 348×418 | 351×418 | 347×417 | 377×418 | 475×409 | 382×406 | 407×390 | 396×344 |
| `mount/xuchu` | 387 | 355×411 | 382×406 | 379×402 | 375×419 | 400×382 | 393×367 | 380×357 | 403×303 |
| `mount/zhangfei` | 394 | 349×418 | 352×418 | 357×415 | 406×395 | 504×375 | 345×397 | 429×369 | 396×334 |
| `mount/zhaoyun` | 383 | 333×407 | 353×407 | 359×405 | 385×408 | 524×366 | 340×379 | 423×369 | 366×355 |

共 15 组 × 8 动作 = 120 张。stand 组 7 个（无吕布步战），mount 组 8 个。

## 4. 小兵助威 `assets/troops/`

路径 `res://assets/troops/<兵种>/cheer_1..8.png`，8 帧是一个连续助威循环。**同一兵种 8 帧共用同一画布尺寸和同一锚点（脚底/马蹄对齐）**，直接做 SpriteFrames 循环播放即可；`AnimatedSprite2D` 设 `centered = false`、`offset = -anchor`，脚底就落在节点原点。

| 兵种 | key | 帧 | 画布 | 锚点（脚底） | 身高 | 建议 FPS |
|---|---|---|---|---|---|---|
| 刀盾兵 | `sword_shield` | cheer_1..8 | 331×400 | (195, 394) | 346 | 8（6–8） |
| 枪兵 | `spear` | cheer_1..8 | 315×419 | (170, 412) | 389 | 8（6–8） |
| 弓兵 | `archer` | cheer_1..8 | 362×384 | (210, 376) | 363 | 8（6–8） |
| 骑兵 | `cavalry` | cheer_1..8 | 391×428 | (171, 422) | 403 | 8（6–8） |

全部朝右；放在左侧观众席朝向场中时保持原样，右侧观众席 `flip_h`（翻转后锚点 x = 画布宽 − anchor.x）。

## 5. UI `assets/ui/`（程序生成，暗金/朱红/水墨像素风）

| 文件 | 尺寸 | 用途 |
|---|---|---|
| `icon.png` | 512×512 | 应用图标：深色底 + 金色楷书“斗” + 朱红圆相 + 方天画戟剪影（project.godot 的 application/config/icon 可直接用） |
| `bar_bg.png` | 512×28 | 血条底槽：墨色外框 + 金框 + 两端朱红铆钉；**填充有效区 x=16..496, y=6..22** |
| `bar_fill_p1.png` | 512×28 | 我方血条填充：朱红→橙分级渐变，只在有效区内有像素，与 bar_bg 同尺寸直接叠放 |
| `bar_fill_p2.png` | 512×28 | 敌方血条填充：暗紫→蓝分级渐变（敌方在右侧时水平翻转使用，fill_mode 右到左） |
| `bar_stamina.png` | 512×12 | 体力条：淡金，整条即填充（底槽可用同图 modulate 压暗） |
| `bar_ult.png` | 512×12 | 大招条：青白，上下两行半透明光晕 + 闪点 |
| `banner.png` | 1200×300 | 大招立绘横幅底版：斜切平行四边形深色半透明板（α≈0.8）+ 金线 + 底部朱红饰带 |
| `vignette.png` | 1920×1080 | 全屏晕影：四角压暗（中心透明，四角 α≈0.72），盖在最上层 |
| `dust.png` | 128×128 | 柔和径向白点（尘土/烟粒子，GPUParticles2D 纹理，用 color 调色） |
| `spark.png` | 64×64 | 四角星形高光（像素风，命中火花/刀光闪点） |
| `ring.png` | 256×256 | 空心圆环（冲击波，scale 放大 + 透明度衰减） |

血条用法：`TextureProgressBar.texture_under = bar_bg.png`，`texture_progress = bar_fill_p1.png`（或 p2）。填充图两端各 16px 是透明的，若要 value=0/100 正好对齐槽的两端，可把进度条值映射到 16/512 ~ 496/512。
像素风素材导入时 Filter 选 Nearest（项目默认纹理过滤设成 Nearest 最省事）；`dust/ring/vignette` 是平滑渐变，用 Linear 也可。

## 6. 字体 `assets/fonts/`

| 文件 | 字体 | 用途 / 注意 |
|---|---|---|
| `NotoSansSC.ttf` | Noto Sans SC 可变字体（wght 100–900，16.95 MB） | 正文/数字/按钮。**默认字重是 Thin(100)**，直接用会非常细；请建 `FontVariation`，Variation › OpenType 里把 Weight 设 400（正文）或 700（标题）。OFL，可随游戏分发 |
| `title.ttf` | 楷体 Kaiti SC Black（从 macOS 系统 Kaiti.ttc 第 6 个字形面用 fontTools 转出，36.61 MB） | 标题/“单挑”/武将名等书法大字。**Apple 系统字体，只能本机开发预览，不能随游戏分发**；文件很大，发布前建议换成下面两个 OFL 字体之一 |
| `brush.ttf` | 马善政毛笔楷书 Ma Shan Zheng（5.59 MB，GB2312 范围） | 外部新增（非本次生成），OFL，见 `brush-OFL.txt`；可作为 title.ttf 的可商用替代 |
| `serif.ttf` | 站酷小薇 ZCOOL XiaoWei（6.02 MB，GB2312 范围） | 外部新增（非本次生成），OFL，见 `serif-OFL.txt`；偏宋体的说明文字/台词 |

## 7. 尚未接入的源素材

- 大招立绘：`斗战三国Q版/大招立绘/guanyu_cutin.png`、`zhaoyun_cutin.png`（1672×941，洋红底未抠），可配合 `ui/banner.png` 使用，本次未处理。

## 战斗特效 `assets/fx/`

| 文件 | 用途 | 来源 |
|---|---|---|
| `slash/arc_wide.png` | 斩击月牙（横斩/斜劈/回旋） | CC0 · Cethiel《Slash Effect Collection》 |
| `slash/arc_thin.png` | 突刺光刃 | 同上 |

素材为纯白 + 亮度在 alpha，靠 shader `scripts/battle/fx/slash_reveal.gdshader`
的 tint 跟随武将主题色。许可见 `fx/CREDITS.md`，重新生成用 `_tools/build_fx_assets.py`。
