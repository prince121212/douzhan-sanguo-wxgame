# 音频素材来源（CREDITS）

## 音乐（2026-10-15 更新，替换了原先借用的宝可梦同人 BGM）

| 文件 | 曲目 | 作者 / 来源 | 许可 | 用途 |
|---|---|---|---|---|
| `bgm_title.ogg` | Imperial China Cinematic | Shane Ivers，https://www.silvermansound.com | CC BY 4.0（须署名：Music: Imperial China Cinematic by Shane Ivers - https://www.silvermansound.com） | 标题、选将、开场 |
| `bgm_drums.ogg` | Horde War Drums loop | William Hector，https://opengameart.org/content/horde-war-drums-loop | CC0 | 斗将主战鼓（130 BPM 无缝循环） |
| `bgm_climax.ogg` | The Fall Of Heroes | Shane Ivers，https://www.silvermansound.com | CC BY 4.0（须署名：Music: The Fall Of Heroes by Shane Ivers - https://www.silvermansound.com） | 有一方体力低于 35% 时切换的决战曲 |

## 程序合成音效（tools/synth_sfx.py，可重复生成，无版权问题）

drum_1..3 / drum_big（战鼓）、gong（铜锣）、horse_neigh（马嘶）、bow_1..2（弓弦）、parry（拆招）、guard_break（破防）、rage（怒气满）、charge / charge_full（蓄力）、dodge_perfect（闪身）、clash_hold（角力）、roar（怒吼）、ko（终结）、wind（风沙）、ult_whoosh（绝技切入）、victory_drums（得胜鼓）。

## 以下为第一批从源工程拷贝的音效


由 `tools/build_audio.py` 生成，可重复执行。路径相对于工作区 `羁绊之旅/`。

- 主源库：`打包-斗将三国/assets/audio`。该打包版里大量文件是 **1 秒静音占位**（全部 BGM、`battle-victory.wav`、`battle-defeat.wav`、`voice/` 整个目录等，md5 相同），遇到占位时自动回退到同一相对路径的 `还原工程-windows/assets/audio`（同一工程的完整版）。
- 只拷贝音频本体，未拷贝任何 `.import`；Godot 打开工程时会自动重新导入。
- `audio/voice/m15/sword.ogg` 实际是 6.9 秒的角色对白（同目录还有 boast/fear/lesson 等台词），不是挥砍音效，未采用。
- 源库中没有任何马嘶/马蹄音频，马蹄用脚步派生代替；**马嘶缺失**。
- 许可提醒：Kenney 与 tournament-crowd 为 CC0，可放心使用；其余来自源工程（宝可梦同人作品）或 PokeTravel 音乐包，许可未声明，商业发布前请确认或替换。

| 目标文件 | 源文件 | 处理 | 来源 / 许可 | 用途 |
|---|---|---|---|---|
| `assets/audio/slash_1.wav` | `打包-斗将三国/assets/audio/move_quick.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 轻挥砍破风（0.20s，最短，普攻连段） |
| `assets/audio/slash_2.wav` | `打包-斗将三国/assets/audio/move_razor.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 锐利挥砍（0.23s，高频偏亮，快刀） |
| `assets/audio/slash_3.wav` | `打包-斗将三国/assets/audio/move_gust.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 中挥（0.32s，蓄力后出手） |
| `assets/audio/slash_4.wav` | `打包-斗将三国/assets/audio/move_tailwind.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 长挥/横扫（0.60s，重击、大招挥舞） |
| `assets/audio/clang_1.wav` | `打包-斗将三国/assets/audio/impact_steel.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 兵器相交（0.20s，短促金属撞击） |
| `assets/audio/clang_2.wav` | `打包-斗将三国/assets/audio/move_iron.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 格挡金属声（0.29s，中等余音） |
| `assets/audio/clang_3.wav` | `打包-斗将三国/assets/audio/element_steel.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 重格挡/弹刀（0.40s，长余音） |
| `assets/audio/clang_4.ogg` | `打包-斗将三国/assets/audio/beltHandle1.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 轻金属磕碰（0.28s，甲片/轻格挡，真实拟音） |
| `assets/audio/blade_draw_1.ogg` | `打包-斗将三国/assets/audio/drawKnife1.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 拔刀/亮兵器（0.40s，偏弱，可做蓄力起手） |
| `assets/audio/blade_draw_2.ogg` | `打包-斗将三国/assets/audio/drawKnife2.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 拔刀/亮兵器（0.45s） |
| `assets/audio/blade_draw_3.ogg` | `打包-斗将三国/assets/audio/drawKnife3.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 刀刃刮擦（0.48s，带一下撞击，可做擦刀/格挡收尾） |
| `assets/audio/hit_light.wav` | `打包-斗将三国/assets/audio/hit.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 轻命中（0.13s） |
| `assets/audio/hit_heavy.wav` | `打包-斗将三国/assets/audio/impact_fire.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 重命中（0.22s，噪声冲击更厚） |
| `assets/audio/hit_thud.wav` | `打包-斗将三国/assets/audio/impact_normal.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 低沉闷击（0.12s，可叠在重击/盾挡下层） |
| `assets/audio/body_fall.wav` | `打包-斗将三国/assets/audio/element_rock.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 倒地/重物落地震地闷响（0.40s） |
| `assets/audio/step_1.ogg` | `打包-斗将三国/assets/audio/footstep00.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 脚步（每个文件含两下踏步） |
| `assets/audio/step_2.ogg` | `打包-斗将三国/assets/audio/footstep01.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 脚步 |
| `assets/audio/step_3.ogg` | `打包-斗将三国/assets/audio/footstep02.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 脚步 |
| `assets/audio/step_4.ogg` | `打包-斗将三国/assets/audio/footstep06.ogg` | 原样拷贝 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 脚步 |
| `assets/audio/jump.wav` | `打包-斗将三国/assets/audio/jump.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 起跳（0.16s，8-bit 风格上扬音） |
| `assets/audio/land.wav` | `打包-斗将三国/assets/audio/land_light.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 落地（0.12s，低沉轻落地） |
| `assets/audio/land_slide.wav` | `打包-斗将三国/assets/audio/land_slide.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 滑步落地/急停（0.17s） |
| `assets/audio/dash.wav` | `打包-斗将三国/assets/audio/dash.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 冲刺（0.17s） |
| `assets/audio/crowd_cheer_1.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-1.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（3.8s） |
| `assets/audio/crowd_cheer_2.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-2.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（4.4s） |
| `assets/audio/crowd_cheer_3.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-3.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（4.0s） |
| `assets/audio/crowd_cheer_4.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-4.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（4.3s） |
| `assets/audio/crowd_cheer_5.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-5.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（3.6s） |
| `assets/audio/crowd_cheer_6.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-6.ogg` | 原样拷贝 | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众欢呼（5.8s，最长） |
| `assets/audio/crowd_ooh_1.ogg` | `打包-斗将三国/assets/audio/referee-japanese-current/crowd-1.ogg` | 原样拷贝 | 源工程素材（来源/许可未声明） | 观众惊呼“哦——”（1.0s 单发，适合重击/大招命中） |
| `assets/audio/crowd_ooh_2.ogg` | `打包-斗将三国/assets/audio/referee-japanese-current/crowd-2.ogg` | 原样拷贝 | 源工程素材（来源/许可未声明） | 观众惊呼（0.75s 单发） |
| `assets/audio/crowd_ooh_3.ogg` | `打包-斗将三国/assets/audio/referee-japanese-current/crowd-3.ogg` | 原样拷贝 | 源工程素材（来源/许可未声明） | 观众惊呼（0.71s 单发） |
| `assets/audio/wind_amb.wav` | `打包-斗将三国/assets/audio/story-ep126/wind.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | 风声底噪（4.0s，可循环，24kHz 单声道） |
| `assets/audio/ui_click.wav` | `打包-斗将三国/assets/audio/ui.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | UI 点击（0.09s） |
| `assets/audio/ui_confirm.wav` | `打包-斗将三国/assets/audio/success.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | UI 确认/成功（1.4s 上行琶音） |
| `assets/audio/ui_select.wav` | `打包-斗将三国/assets/audio/switch.wav` | 原样拷贝 | 源工程《宝可梦羁绊之旅》自制音效（许可未单独声明，沿用源工程） | UI 切换/选择武将（0.28s） |
| `assets/audio/ult_charge.wav` | `打包-斗将三国/assets/audio/bond-feedback/charge.wav` | 原样拷贝 | 源工程 bond-feedback 原创合成音（见 bond-feedback/source.json） | 大招蓄力（0.42s） |
| `assets/audio/ult_cutin.wav` | `打包-斗将三国/assets/audio/bond-feedback/awaken.wav` | 原样拷贝 | 源工程 bond-feedback 原创合成音（见 bond-feedback/source.json） | 大招立绘切入（0.85s） |
| `assets/audio/horse_step_1.ogg` | `打包-斗将三国/assets/audio/footstep08.ogg` | 派生：降 3 个半音（慢放）+ 低频 +4dB / 高频 -4dB，峰值归一 -1.5dBFS，模拟土地上的马蹄闷响 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 马蹄（源库无任何马嘶/马蹄音频，用最重的脚步代替） |
| `assets/audio/horse_step_2.ogg` | `打包-斗将三国/assets/audio/footstep04.ogg` | 派生：降 3 个半音（慢放）+ 低频 +4dB / 高频 -4dB，峰值归一 -1.5dBFS，模拟土地上的马蹄闷响 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 马蹄（源库无任何马嘶/马蹄音频，用最重的脚步代替） |
| `assets/audio/horse_step_3.ogg` | `打包-斗将三国/assets/audio/footstep09.ogg` | 派生：降 3 个半音（慢放）+ 低频 +4dB / 高频 -4dB，峰值归一 -1.5dBFS，模拟土地上的马蹄闷响 | Kenney RPG Audio（CC0，见 还原工程-windows/licenses/Kenney-RPG-Audio-License.txt） | 马蹄（源库无任何马嘶/马蹄音频，用最重的脚步代替） |
| `assets/audio/crowd_amb.ogg` | `打包-斗将三国/assets/audio/tournament-crowd/cheer-1..6.ogg` | 派生：3 声部随机串接+轻微变调+低通 1.8kHz+慢速自动增益，16s 首尾交叉淡化无缝循环，RMS≈-27dBFS | freesound Ev-Dawg #360620（CC0 1.0，见 tournament-crowd/source.json） | 观众杂音底噪（循环）。指定的 referee-japanese-current/crowd-1.ogg 只有 1s 单发惊呼，不适合做底噪，已改为 crowd_ooh_1.ogg |
