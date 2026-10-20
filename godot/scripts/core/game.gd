extends Node
## 全局：设置、按键、对局配置、场景切换。

signal settings_changed

enum Mode { DUEL, WATCH }

const SAVE_PATH := "user://settings.cfg"

# 对局配置（选将界面写入，战斗场景读取）
var mode: int = Mode.DUEL
var p1_id := "zhaoyun"
var p2_id := "lvbu"
var difficulty := 1            # 0 易 1 中 2 难 3 极
var rounds_to_win := 1         # 1 = 一局定胜负，2 = 三局两胜
var watch_rule := "arena"      # arena 擂台车轮战 / random 随机对决
var start_mounted := true

# 擂台战绩（观战模式里擂主连胜）
var champion_id := ""
var champion_streak := 0
var recent_ids: Array[String] = []

# 设置
var music_volume := 0.7
var sfx_volume := 0.85
var show_damage_numbers := true
var screen_shake := 1.0

var main: Node = null   # main.gd 注册自己

# 触屏操作（微信小游戏 / 手机）：左手摇杆、右手按钮。电脑上用 --touch 可以拿鼠标模拟单指
var touch_ui := false

# 开发：无头批量模拟（--sim=N），用于调平衡
var sim := false
var sim_left := 0
var sim_log: Array = []
var event_shots := ""     # 开发：关键事件自动截图目录（--evshots=目录）

var font_title: Font    # 标题/名号（典雅衬线）
var font_brush: Font    # 书法大字（印章、技名）
var font_ui: Font       # 正文字


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()
	load_settings()
	_load_fonts()
	touch_ui = OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() \
		or "--touch" in OS.get_cmdline_user_args()


## 当前画面的设计尺寸。高度固定 1080，全面屏手机上宽度会大于 1920
func view_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp else Vector2(1920, 1080)


## 按 1920 宽排版的界面居中时要右移的距离
func ui_offset_x() -> float:
	return maxf(0.0, (view_size().x - 1920.0) * 0.5)


func _load_fonts() -> void:
	# 全部使用 SIL OFL 字体，可随游戏分发
	var noto := _try_font(["res://assets/fonts/NotoSansSC.ttf"])
	if noto:
		var fv := FontVariation.new()
		fv.base_font = noto
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}
		font_ui = fv
	font_title = _try_font(["res://assets/fonts/serif.ttf"])
	font_brush = _try_font(["res://assets/fonts/brush.ttf"])
	if font_ui == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["PingFang SC", "Heiti SC", "Noto Sans CJK SC", "Microsoft YaHei"])
		font_ui = sf
	if font_title == null:
		font_title = font_ui
	if font_brush == null:
		font_brush = font_title
	# 缺字时回退到思源黑体
	if font_title is FontFile and font_ui:
		font_title.fallbacks = [font_ui]
	if font_brush is FontFile and font_title:
		font_brush.fallbacks = [font_title, font_ui]


func _try_font(paths: Array) -> Font:
	for p in paths:
		if ResourceLoader.exists(p):
			var f = load(p)
			if f is Font:
				return f
	return null


func _setup_input() -> void:
	var keys := {
		"p1_left": [KEY_A, KEY_LEFT],
		"p1_right": [KEY_D, KEY_RIGHT],
		"p1_up": [KEY_W, KEY_UP],
		"p1_down": [KEY_S, KEY_DOWN],
		"p1_light": [KEY_J],
		"p1_heavy": [KEY_K],
		"p1_guard": [KEY_L],
		"p1_dodge": [KEY_SPACE],
		"p1_run": [KEY_SHIFT],
		"p1_jump": [KEY_I],
		"p1_ult": [KEY_U],
		"pause": [KEY_ESCAPE, KEY_P],
		"ui_speed": [KEY_F],
		"ui_hud": [KEY_TAB],
		"ui_skip": [KEY_ENTER, KEY_KP_ENTER],
	}
	var pads := {
		"p1_light": [JOY_BUTTON_X],
		"p1_heavy": [JOY_BUTTON_Y],
		"p1_dodge": [JOY_BUTTON_B],
		"p1_run": [JOY_BUTTON_LEFT_STICK],
		"p1_jump": [JOY_BUTTON_A],
		"p1_guard": [JOY_BUTTON_RIGHT_SHOULDER],
		"p1_ult": [JOY_BUTTON_LEFT_SHOULDER],
		"pause": [JOY_BUTTON_START],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in pads:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		for b in pads[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)
	var axes := {
		"p1_left": [JOY_AXIS_LEFT_X, -1.0],
		"p1_right": [JOY_AXIS_LEFT_X, 1.0],
		"p1_up": [JOY_AXIS_LEFT_Y, -1.0],
		"p1_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axes[action][0]
		ev.axis_value = axes[action][1]
		InputMap.action_add_event(action, ev)
	# 右扳机也能放绝技
	var trig := InputEventJoypadMotion.new()
	trig.axis = JOY_AXIS_TRIGGER_RIGHT
	trig.axis_value = 1.0
	InputMap.action_add_event("p1_ult", trig)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	difficulty = cfg.get_value("game", "difficulty", difficulty)
	rounds_to_win = cfg.get_value("game", "rounds_to_win", rounds_to_win)
	watch_rule = cfg.get_value("game", "watch_rule", watch_rule)
	show_damage_numbers = cfg.get_value("game", "damage_numbers", show_damage_numbers)
	screen_shake = cfg.get_value("game", "screen_shake", screen_shake)
	p1_id = cfg.get_value("last", "p1", p1_id)
	p2_id = cfg.get_value("last", "p2", p2_id)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "rounds_to_win", rounds_to_win)
	cfg.set_value("game", "watch_rule", watch_rule)
	cfg.set_value("game", "damage_numbers", show_damage_numbers)
	cfg.set_value("game", "screen_shake", screen_shake)
	cfg.set_value("last", "p1", p1_id)
	cfg.set_value("last", "p2", p2_id)
	cfg.save(SAVE_PATH)
	settings_changed.emit()


func goto(screen: String, args: Dictionary = {}) -> void:
	if main and main.has_method("show_screen"):
		main.show_screen(screen, args)


## 观战模式：挑出下一位挑战者（擂台）或一对随机武将
func next_watch_pair(last_winner: String) -> void:
	var ids: Array = Roster.ids()
	if watch_rule == "arena" and last_winner != "":
		if champion_id == last_winner:
			champion_streak += 1
		else:
			champion_id = last_winner
			champion_streak = 1
		p1_id = champion_id
		p2_id = _pick_fresh(ids, [p1_id])
	else:
		champion_id = ""
		champion_streak = 0
		p1_id = _pick_fresh(ids, [])
		p2_id = _pick_fresh(ids, [p1_id])


func _pick_fresh(ids: Array, exclude: Array) -> String:
	var pool: Array = []
	for id in ids:
		if id in exclude:
			continue
		if id in recent_ids:
			continue
		pool.append(id)
	if pool.is_empty():
		for id in ids:
			if not (id in exclude):
				pool.append(id)
	var pick: String = pool[randi() % pool.size()]
	recent_ids.append(pick)
	while recent_ids.size() > 4:
		recent_ids.pop_front()
	return pick


func difficulty_name(d: int = -1) -> String:
	if d < 0:
		d = difficulty
	return ["易", "中", "难", "极"][clampi(d, 0, 3)]
