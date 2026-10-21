extends Node
## 根节点：在标题、选将、战斗之间切换，切换时用水墨遮罩过渡。

const SCREENS := {
	"title": "res://scripts/ui/title_screen.gd",
	"select": "res://scripts/ui/select_screen.gd",
	"battle": "res://scripts/battle/battle.gd",
}

const CONSOLE_PATH := "res://tools/console.gd"

var current: Node = null
var console: Node = null
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var busy := false


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_window()
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.02, 0.02, 1.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	# 开发控制台：只在桌面版加载（tools/ 不进微信包，web/mobile 下也不加载）
	if not OS.has_feature("web") and not OS.has_feature("mobile") and ResourceLoader.exists(CONSOLE_PATH):
		var c := CanvasLayer.new()
		c.set_script(load(CONSOLE_PATH))
		c.name = "DevConsole"
		add_child(c)
		console = c

	var args := OS.get_cmdline_user_args()
	_fps_log = "--fps" in args
	for a in args:
		if a.begins_with("--shots="):
			_start_shots(a.substr(8))
		if a.begins_with("--evshots="):
			Game.event_shots = a.substr(10)
			DirAccess.make_dir_recursive_absolute(Game.event_shots)
		if a.begins_with("--rounds="):
			Game.rounds_to_win = int(a.substr(9))
		if a.begins_with("--arena="):
			Game.arena_id = a.substr(8)
		if a.begins_with("--pair="):
			var pr := a.substr(7).split(",")
			Game.p1_id = pr[0]
			Game.p2_id = pr[1]
	for a in args:
		if a.begins_with("--sim="):
			Game.sim = true
			Game.sim_left = int(a.substr(6))
			Game.mode = Game.Mode.WATCH
			Game.watch_rule = "random"
			Game.next_watch_pair("")
			show_screen("battle")
			return
	if "--watch" in args or "--autotest" in args:
		Game.mode = Game.Mode.WATCH
		if "--autotest" in args and not _has_pair(args):
			Game.p1_id = "zhaoyun"
			Game.p2_id = "lvbu"
		show_screen("battle")
	elif "--select" in args:
		Game.mode = Game.Mode.WATCH if "--watchmode" in args else Game.Mode.DUEL
		show_screen("select")
	elif "--duel" in args:
		Game.mode = Game.Mode.DUEL
		if "--botplayer" in args:
			_bot = true
		show_screen("battle")
	else:
		show_screen("title")


## 窗口按屏幕大小自适应：占可用区域约 85%，保持 16:9，居中
func _fit_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	# 调试：--winsize=2284x1080 可强制指定窗口尺寸（复现全面屏/微信的宽屏比例）
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--winsize="):
			var wh := a.substr(10).split("x")
			if wh.size() == 2:
				var sz := Vector2i(int(wh[0]), int(wh[1]))
				DisplayServer.window_set_size(sz)
				var scr2 := DisplayServer.window_get_current_screen()
				var usable2 := DisplayServer.screen_get_usable_rect(scr2)
				DisplayServer.window_set_position(usable2.position + (usable2.size - sz) / 2)
			return
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var w := int(usable.size.x * 0.86)
	var h := int(w * 9.0 / 16.0)
	if h > usable.size.y * 0.86:
		h = int(usable.size.y * 0.86)
		w = int(h * 16.0 / 9.0)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(usable.position + (usable.size - Vector2i(w, h)) / 2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		# 数值控制台：F8 / F10 都能开
		# （macOS 上 F10 默认是系统静音键，不按 Fn 会被系统吃掉，所以给 F8 做备用）
		if console and (k.keycode == KEY_F8 or k.keycode == KEY_F10):
			console.toggle()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed) or (k.keycode == KEY_F and k.meta_pressed and k.ctrl_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			if full:
				_fit_window()
			get_viewport().set_input_as_handled()


func show_screen(screen: String, _args := {}) -> void:
	if busy:
		return
	busy = true
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(fade_rect, "color:a", 1.0, 0.35 if current else 0.0)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current:
		current.queue_free()
		await get_tree().process_frame
	Sfx.muffle(0.0)
	var node: Node
	if screen == "battle":
		node = Node2D.new()
	else:
		node = Control.new()
	node.set_script(load(SCREENS[screen]))
	node.name = screen
	add_child(node)
	move_child(node, 0)
	current = node
	var tw2 := create_tween().set_ignore_time_scale(true)
	tw2.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await tw2.finished
	busy = false


func _has_pair(args: PackedStringArray) -> bool:
	for a in args:
		if a.begins_with("--rounds="):
			Game.rounds_to_win = int(a.substr(9))
		if a.begins_with("--arena="):
			Game.arena_id = a.substr(8)
		if a.begins_with("--pair="):
			return true
	return false


# ---------------------------------------------------------------- 开发：定时截图
# --shots=间隔秒,张数,目录   例：--shots=1.5,40,/tmp/shots
var _shot_cfg := []
var _shot_n := 0
var _shot_t := 0.0


func _start_shots(spec: String) -> void:
	var p := spec.split(",")
	_shot_cfg = [float(p[0]), int(p[1]), p[2] if p.size() > 2 else "/tmp/shots"]
	DirAccess.make_dir_recursive_absolute(_shot_cfg[2])


# ---------------------------------------------------------------- 开发：模拟玩家乱按键（测试玩家操作路径）
var _bot := false
var _bot_t := 0.0
var _bot_held := {}


func _bot_step(delta: float) -> void:
	_bot_t -= delta
	for a in _bot_held.keys():
		_bot_held[a] -= delta
		if _bot_held[a] <= 0.0:
			Input.action_release(a)
			_bot_held.erase(a)
	if _bot_t > 0.0:
		return
	_bot_t = randf_range(0.05, 0.25)
	var acts := ["p1_left", "p1_right", "p1_up", "p1_down", "p1_light", "p1_light", "p1_heavy", "p1_guard", "p1_dodge", "p1_jump", "p1_ult", "p1_light"]
	var a: String = acts[randi() % acts.size()]
	Input.action_press(a)
	_bot_held[a] = randf_range(0.05, 0.6)


var _fps_t := 0.0
var _fps_log := false


func _process(delta: float) -> void:
	if _fps_log:
		_fps_t += delta / maxf(0.0001, Engine.time_scale)
		if _fps_t > 2.0:
			_fps_t = 0.0
			print("FPS ", Engine.get_frames_per_second(), " draw_calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if _bot:
		_bot_step(delta / maxf(0.0001, Engine.time_scale))
	if _shot_cfg.is_empty():
		return
	_shot_t += delta / maxf(0.0001, Engine.time_scale)
	if _shot_t >= _shot_cfg[0]:
		_shot_t = 0.0
		var img := get_viewport().get_texture().get_image()
		if get_viewport().use_hdr_2d:
			img.convert(Image.FORMAT_RGBA8)
			img.linear_to_srgb()
		img.save_png("%s/shot_%03d.png" % [_shot_cfg[2], _shot_n])
		_shot_n += 1
		if _shot_n >= _shot_cfg[1]:
			get_tree().quit()
