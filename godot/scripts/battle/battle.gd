extends Node2D
## 一场斗将：搭建场景、开场演出、战斗循环、命中结算、拼刀、落马、绝技、终结与结算。

const Z_MIN := 470.0
const Z_MAX := 880.0
var map_rect := Rect2(0, 0, 1672, 941)   # 由 arena 配置决定，_build 里赋值
const ArrowFx := preload("res://scripts/battle/fx/arrow.gd")
const ResultPanel := preload("res://scripts/ui/result_panel.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

var world: Node2D
var arena: Node2D
var ground_layer: Node2D
var actors: Node2D
var vfx: Node2D
var cam: Camera2D
var hud: CanvasLayer
var cine: CanvasLayer
var post: CanvasLayer
var env: WorldEnvironment

var fighters: Array = []
var f1: Fighter
var f2: Fighter
var projectiles: Array = []

var phase := "intro"           # intro / fight / cine / ko / result
var game_time := 0.0
var real_time := 0.0
var time_left := 180.0   # 实际值在 _start_bout 里按 Cfg 设置
var round_count := 0
var last_round_t := -10.0
var wins := [0, 0]
var rounds_to_win := 1
var bout := 1
var player_side := 0           # -1 = 观战
var cine_busy := false
var preset_key := "wu"
var skip_intro := false
var user_speed := 1.0
var _slow: Array = []          # [{scale, until}]
var _time_scale := 1.0
var first_blood := false
var low_announced := [false, false]
var lead_rounds_announced := 0
var match_start_time := 0.0
var match_elapsed := 0.0       # 三局两胜时累计前几局的时长（评分用）
var unhorse_pending: Array = []
var result_panel: Node = null
var pause_menu: Node = null
var touch: Node = null          # 触屏：摇杆 + 招式按钮（微信小游戏 / 手机）
var prompt_dodge_until := -1.0  # 绝技反应窗口：让触屏的「闪」按钮高亮
var autoplay_next_t := -1.0
var mounted_pass_t := 0.0
var tele := {}                 # 统计：各类事件次数
var climax_music := false      # 残血决战时换成激昂的音乐

# 终结回放
const REC_SPAN := 4.5
var recording := false
var replaying := false
var replay_skip := false
var rec_frames: Array = []     # [{t, a, b}] 每帧两员武将的画面状态
var rec_events: Array = []     # [{t, kind, name, args}] 特效与音效调用
var bounds_on := false         # 开场入场时允许在场外


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = 1.0
	rounds_to_win = Game.rounds_to_win
	player_side = 0 if Game.mode == Game.Mode.DUEL else -1
	preset_key = ["chen", "wu", "you", "sha", "wu"][randi() % 5]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preset="):
			preset_key = a.substr(9)
	time_left = Cfg.bal_float("round.time_limit_duel", 180.0) if player_side >= 0 else Cfg.bal_float("round.time_limit_watch", 150.0)
	_build()
	_spawn_fighters()
	Sfx.recorder = _rec_sfx
	_start_bout(true)
	if "--pausetest" in OS.get_cmdline_user_args():
		get_tree().create_timer(5.0).timeout.connect(func(): pause_menu.open())
	if "--resulttest" in OS.get_cmdline_user_args():
		get_tree().create_timer(1.2).timeout.connect(_result_test)
	if "--resulttest-loss" in OS.get_cmdline_user_args():
		get_tree().create_timer(1.2).timeout.connect(_result_test_loss)


## 开发用：败北结算页（--resulttest-loss）
func _result_test_loss() -> void:
	phase = "result"
	cine_busy = false
	recording = false
	f1.stats = {"hits": 12, "max_combo": 3, "parries": 1, "dodges": 0, "ults": 0, "dmg": 480.0, "clash_win": 0}
	f1.hp = 0.0
	f2.hp = f2.max_hp * 0.4
	f1.set_pose("down")
	f2.enter_victory()
	match_start_time = game_time - 71.0
	round_count = 11
	wins[1] = 1
	_end_bout(f2, f1, false)


## 开发用：直接把战斗推到结算，检查战报页排版（--resulttest）
func _result_test() -> void:
	phase = "result"
	cine_busy = false
	recording = false
	f1.stats = {"hits": 26, "max_combo": 9, "parries": 5, "dodges": 3, "ults": 2, "dmg": 1420.0, "clash_win": 2}
	f2.stats = {"hits": 14, "max_combo": 4, "parries": 2, "dodges": 1, "ults": 1, "dmg": 610.0, "clash_win": 0}
	f1.hp = f1.max_hp * 0.72
	f2.hp = 0.0
	f1.enter_victory()
	f2.set_pose("down")
	match_start_time = game_time - 62.0
	round_count = 14
	wins[0] = 1
	_end_bout(f1, f2, false)


func _exit_tree() -> void:
	if Sfx.recorder == Callable(self, "_rec_sfx"):
		Sfx.recorder = Callable()


# ---------------------------------------------------------------- 搭建

func _build() -> void:
	world = Node2D.new()
	add_child(world)
	arena = Node2D.new()
	arena.set_script(preload("res://scripts/battle/arena.gd"))
	world.add_child(arena)
	ground_layer = Node2D.new()
	world.add_child(ground_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	vfx = Node2D.new()
	vfx.set_script(preload("res://scripts/battle/vfx.gd"))
	vfx.battle = self
	world.add_child(vfx)
	vfx.ground_layer = ground_layer
	arena.build(self, actors, preset_key)
	map_rect = Rect2(Vector2.ZERO, arena.map_size)
	cam = Camera2D.new()
	cam.set_script(preload("res://scripts/battle/camera_director.gd"))
	cam.battle = self
	cam.map_rect = map_rect
	cam.base_pos = Cfg.camera_focus(map_rect.size)
	world.add_child(cam)
	post = CanvasLayer.new()
	post.set_script(preload("res://scripts/battle/post_fx.gd"))
	add_child(post)
	var pr: Dictionary = arena.preset
	post.set_grade(pr.get("grade", Color.WHITE), pr.get("lift", Color.BLACK),
		float(pr.get("vignette", 0.25)), float(pr.get("sat", 1.0)), float(pr.get("contrast", 1.0)))
	if "--nopost" in OS.get_cmdline_user_args():
		post.visible = false
	hud = CanvasLayer.new()
	hud.set_script(preload("res://scripts/battle/hud.gd"))
	hud.battle = self
	add_child(hud)
	cine = CanvasLayer.new()
	cine.set_script(preload("res://scripts/battle/cinematic.gd"))
	add_child(cine)
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.15
	e.glow_hdr_scale = 1.6
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 0.9)
	e.set_glow_level(2, 0.6)
	e.set_glow_level(3, 0.3)
	e.set_glow_level(4, 0.0)
	e.set_glow_level(5, 0.0)
	e.set_glow_level(6, 0.0)
	env.environment = e
	# 小游戏版：Web/手机上不开辉光（Compatibility 渲染器下开销大）
	if not ("--noenv" in OS.get_cmdline_user_args()) and not OS.has_feature("web") and not OS.has_feature("mobile"):
		add_child(env)
	pause_menu = CanvasLayer.new()
	pause_menu.set_script(PauseMenu)
	pause_menu.battle = self
	add_child(pause_menu)
	# 微信小游戏 / 手机：加一层虚拟摇杆 + 招式按钮（桌面不显示）
	# 注意：web 导出在小游戏里 OS.has_feature("web") 为 true，但触摸能力仍要看
	# Game.touch_ui（它综合了 web/mobile/触摸屏/--touch 四种判定）。
	if Game.touch_ui:
		touch = CanvasLayer.new()
		touch.set_script(TouchControls)
		touch.battle = self
		add_child(touch)


func _spawn_fighters() -> void:
	f1 = Fighter.new()
	f2 = Fighter.new()
	f1.setup(Game.p1_id, 0, self, Game.start_mounted)
	f2.setup(Game.p2_id, 1, self, Game.start_mounted)
	f1.opponent = f2
	f2.opponent = f1
	actors.add_child(f1)
	actors.add_child(f2)
	fighters = [f1, f2]
	arena.build_flags(f1.id, f2.id)
	# 没有大招立绘的武将，开打前先把替代立绘做好，免得放绝技那一下卡顿
	for f in fighters:
		if Bank.cutin(f.id) == null:
			Bank.cutin_fallback(f.id)


func _make_controllers() -> void:
	if player_side == 0:
		f1.ctrl = PlayerInput.new()
	else:
		f1.ctrl = AiBrain.new(f1, 2.4, true)
	var lvl := float(Game.difficulty) if player_side == 0 else 2.4
	f2.ctrl = AiBrain.new(f2, lvl, player_side < 0)


# ---------------------------------------------------------------- 开场

func _start_bout(first: bool) -> void:
	# 多局制：把上一局的时间累计起来，评分用「整场总时长」而不是最后一局
	if first:
		match_elapsed = 0.0
	elif match_start_time > 0.0:
		match_elapsed += maxf(0.0, game_time - match_start_time)
	phase = "intro"
	cine_busy = false
	skip_intro = false
	projectiles.clear()
	for f in fighters:
		f.ctrl = null
		f.hp = f.max_hp
		f.stamina = Fighter.STAMINA_MAX
		f.rage = 0.0 if first else f.rage * 0.5
		f.combo = 0
		f.buffs.clear()
		f.juggle = 0
		f.h = 0.0
		f.vh = 0.0
		f.vel = Vector2.ZERO
		if Game.start_mounted and Bank.has_stance(f.id, true) and not f.mounted:
			f.mounted = true
			f.unhorsed = false
			f._apply_stance()
		f.state = Fighter.S.SCRIPTED
		f.set_pose("idle")
	low_announced = [false, false]
	time_left = Cfg.bal_float("round.time_limit_duel", 180.0) if player_side >= 0 else Cfg.bal_float("round.time_limit_watch", 150.0)
	round_count = 0
	first_blood = false
	lead_rounds_announced = 0
	post.set_desat(0.0)
	post.set_danger(0, 0.0)
	post.set_danger(1, 0.0)
	bounds_on = false
	f1.position = Vector2(-160, 690)
	f2.position = Vector2(map_rect.size.x + 160, 690)
	f1.facing = 1
	f2.facing = -1
	if Game.sim:
		f1.position = Vector2(590, 690)
		f2.position = Vector2(1082, 690)
		await wait_real(0.1)
	elif first and player_side < 0 and Game.champion_id != "":
		await _intro_arena()
	elif first:
		await _intro_full()
	else:
		await _intro_short()
	if not is_inside_tree():
		return
	_make_controllers()
	if "--ulttest" in OS.get_cmdline_user_args():
		f1.rage = 100.0
		f2.rage = 100.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cutintest="):
			_cutin_test(a.substr(12))
	bounds_on = true
	for f in fighters:
		f.set_scripted(false)
	phase = "fight"
	match_start_time = game_time
	climax_music = false
	rec_frames.clear()
	rec_events.clear()
	recording = true
	Sfx.play_music("bgm_drums", 1.2, -4.0)


func _intro_full() -> void:
	Sfx.stop_all_ambient()
	Sfx.ambient("crowd_amb", true, -16.0)
	Sfx.ambient("wind_amb", true, -20.0)
	Sfx.play_music("bgm_title", 1.0, -3.0)
	post.ink = 1.0
	post.set_ink(0.0)
	var mid := map_rect.get_center()
	cam.cut(Vector2(mid.x, map_rect.position.y + map_rect.size.y * 0.29), 2.0)
	cam.shot(Vector2(mid.x, map_rect.position.y + map_rect.size.y * 0.31), 2.05, 2.2, 1.0)
	var pr: Dictionary = arena.preset
	var place: String = arena.arena_def.get("name", "虎牢关")
	var sub := "%s · %s前" % [pr.get("name", ""), place]
	if f1.id == "lvbu" or f2.id == "lvbu":
		sub = "%s · %s前，飞将横戟" % [pr.get("name", ""), place]
	cine.show_title(place, sub, 2.6)
	Sfx.play("drum", -2.0, 0.8)
	if await _wait_skip(1.7):
		await _skip_to_fight()
		return
	# 镜头下摇到斗将台，两将纵马入场
	cam.shot(Vector2(mid.x, map_rect.position.y + map_rect.size.y * 0.64), 1.22, 3.4, 1.4)
	var drv1 := IntroDriver.new(Vector2(590, 690), true)
	var drv2 := IntroDriver.new(Vector2(1082, 690), true)
	for f in fighters:
		f.set_scripted(false)
	f1.ctrl = drv1
	f2.ctrl = drv2
	Sfx.play("horse_neigh", -6.0)
	if await _wait_skip(2.2):
		await _skip_to_fight()
		return
	cine.show_versus(f1, f2, 2.7)
	Sfx.play("drum", 0.0, 1.0)
	cam.shake(0.2)
	if await _wait_skip(2.6):
		await _skip_to_fight()
		return
	# 通名
	var asker := f2
	var answerer := f1
	if randf() < 0.5:
		asker = f1
		answerer = f2
	var line_a := Roster.rivalry_line(asker.id, answerer.id)
	if line_a == "":
		line_a = Roster.line(asker.id, "call")
	cam.shot(asker.head_global() + Vector2(0, 40), 1.9, 2.2, 3.0)
	say(asker, line_a, 2.0)
	if await _wait_skip(1.9):
		await _skip_to_fight()
		return
	var line_b := Roster.rivalry_line(answerer.id, asker.id)
	if line_b == "":
		line_b = Roster.line(answerer.id, "self")
	cam.shot(answerer.head_global() + Vector2(0, 40), 1.9, 2.2, 3.0)
	say(answerer, line_b, 2.0)
	if await _wait_skip(1.9):
		await _skip_to_fight()
		return
	if Roster.rivalry_line(asker.id, answerer.id) != "":
		cam.shot(asker.head_global() + Vector2(0, 40), 1.8, 1.8, 3.0)
		say(asker, Roster.line(asker.id, "self"), 1.6)
		if await _wait_skip(1.5):
			await _skip_to_fight()
		return
	cam.release(2.5)
	_fight_call()
	await wait_real(0.6)


## 擂台后续场次：不再重复大标题，直接挑战者登场
func _intro_arena() -> void:
	Sfx.ambient("crowd_amb", true, -16.0)
	Sfx.ambient("wind_amb", true, -20.0)
	Sfx.play_music("bgm_title", 1.0, -3.0)
	post.ink = 1.0
	post.set_ink(0.0)
	var champ := f1 if f1.id == Game.champion_id else f2
	var chall := f2 if champ == f1 else f1
	var mid2 := map_rect.get_center()
	cam.cut(Vector2(mid2.x, map_rect.position.y + map_rect.size.y * 0.64), 1.25)
	cam.shot(Vector2(mid2.x, map_rect.position.y + map_rect.size.y * 0.64), 1.25, 3.0, 1.4)
	for f in fighters:
		f.set_scripted(false)
	f1.ctrl = IntroDriver.new(Vector2(590, 690), true)
	f2.ctrl = IntroDriver.new(Vector2(1082, 690), true)
	cine.show_banner("第 %d 阵" % (Game.champion_streak + 1), "擂主 %s 已连胜 %d 阵　·　挑战者 %s 登场" % [champ.def["name"], Game.champion_streak, chall.def["name"]], Color(1, 0.75, 0.3), 2.2)
	Sfx.play("drum", -2.0, 0.9)
	Sfx.play("horse_neigh", -6.0)
	if await _wait_skip(2.2):
		await _skip_to_fight()
		return
	cine.show_versus(f1, f2, 2.4)
	Sfx.play("drum", 0.0, 1.0)
	if await _wait_skip(2.2):
		await _skip_to_fight()
		return
	var line_c := Roster.rivalry_line(chall.id, champ.id)
	if line_c == "":
		line_c = Roster.line(chall.id, "self")
	cam.shot(chall.head_global() + Vector2(0, 40), 1.8, 2.0, 3.0)
	say(chall, line_c, 1.9)
	if await _wait_skip(1.8):
		await _skip_to_fight()
		return
	var taunts := ["又来一个送死的。", "连胜%d阵，你也不过如此。" % Game.champion_streak, Roster.line(champ.id, "taunt")]
	cam.shot(champ.head_global() + Vector2(0, 40), 1.8, 2.0, 3.0)
	say(champ, taunts[randi() % taunts.size()], 1.9)
	if await _wait_skip(1.8):
		await _skip_to_fight()
		return
	cam.release(2.5)
	_fight_call()
	await wait_real(0.6)


func _intro_short() -> void:
	f1.position = Vector2(560, 690)
	f2.position = Vector2(1112, 690)
	for f in fighters:
		f.set_scripted(false)
		f.state = Fighter.S.SCRIPTED
		f.set_pose("idle")
	cam.release(3.0)
	post.ink = 1.0
	post.set_ink(0.0)
	var names := ["", "第一局", "第二局", "决胜局"]
	cine.show_banner(names[min(bout, 3)], "%s %d : %d %s" % [f1.def["name"], wins[0], wins[1], f2.def["name"]], Color(1, 0.75, 0.3), 1.8)
	await wait_real(1.9)
	_fight_call()
	await wait_real(0.5)


func _fight_call() -> void:
	cine.show_stamp("战", Color(1.0, 0.3, 0.18), 1.0, 260)
	Sfx.play("drum", 2.0, 1.1)
	Sfx.play("crowd_cheer", -6.0)
	cam.shake(0.35)
	cam.punch(0.06)
	post.flash(Color(1, 0.9, 0.8), 0.25)
	arena.cheer(0, 1.0)
	arena.cheer(1, 1.0)
	narrate("%s与%s两马相交，斗将开始！" % [f1.def["name"], f2.def["name"]], 0)


func _skip_to_fight() -> void:
	cine.title.clear()
	cine.versus.clear()
	for f in fighters:
		f.ctrl = null
	f1.position = Vector2(590, 690)
	f2.position = Vector2(1082, 690)
	f1.facing = 1
	f2.facing = -1
	cam.release(4.0)
	_fight_call()
	await wait_real(0.5)


## 等待，期间按键可跳过开场。返回 true 表示跳过。
func _wait_skip(t: float) -> bool:
	var end := real_time + t
	while real_time < end:
		if skip_intro:
			return true
		await get_tree().process_frame
		if not is_inside_tree():
			return true
	return skip_intro


func _unhandled_input(event: InputEvent) -> void:
	if replaying and event.is_pressed() and not event.is_echo() and (player_side >= 0 or event.is_action_pressed("ui_skip")):
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
			replay_skip = true
	if phase == "intro" and player_side >= 0 and event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
			skip_intro = true
	if phase == "intro" and player_side < 0 and event.is_action_pressed("ui_skip"):
		skip_intro = true
	if event.is_action_pressed("ui_speed") and player_side < 0:
		user_speed = {1.0: 1.5, 1.5: 2.0, 2.0: 1.0}.get(user_speed, 1.0)
		narrate("观战速度 ×%s" % str(user_speed), 0)
	if event.is_action_pressed("ui_hud"):
		hud.set_visible_hud(hud.user_hidden)


# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	var real := delta / maxf(0.0001, Engine.time_scale)
	real = min(real, 0.1)
	real_time += real
	_update_time_scale(real)
	var dt: float = min(delta, 0.034)
	if phase in ["fight", "cine", "ko", "intro", "result"] and not replaying:
		game_time += dt
		for f in fighters:
			f.step(dt)
		_update_projectiles(dt)
		_separate()
		_mounted_pass_check(dt)
		if recording:
			_record_frame()
	if phase == "fight":
		time_left -= dt
		if time_left <= 0.0:
			time_left = 0.0
			_timeout()
		for i in 2:
			var f: Fighter = fighters[i]
			var r := f.hp / f.max_hp
			var danger_r := Cfg.bal_float("round.danger_hp_ratio", 0.25)
			post.set_danger(i, 0.7 if r < danger_r and f.is_alive() else 0.0)
			if r < danger_r and not low_announced[i] and f.is_alive():
				low_announced[i] = true
				narrate("%s已是强弩之末！" % f.def["name"], 1)
				say(f, Roster.line(f.id, "low"), 1.6)
				slowmo(0.35, 0.45)
				cam.punch(0.05)
				post.flash(Color(0.8, 0.1, 0.05), 0.22)
				arena.gasp(f.side)
				Sfx.play("drum_big", -4.0, 0.85)
		_standoff_check(dt)
		for f in fighters:
			if f.id == "huangzhong" and f.is_alive() and f.hp / f.max_hp < 0.5 and not f.get_meta("laodang", false):
				f.set_meta("laodang", true)
				narrate("黄忠须发皆张——老当益壮，越战越勇！", 1)
				say(f, "谁说老夫老矣！", 1.6)
				vfx.ring(f.center_global(), 240.0, Color(1.0, 0.8, 0.3), false, 14.0, 0.5)
				f.glow = 0.9
				f.glow_col = Color(1.0, 0.75, 0.25)
				Sfx.play("rage", -4.0)
		if not climax_music and min(f1.hp / f1.max_hp, f2.hp / f2.max_hp) < Cfg.bal_float("round.climax_hp_ratio", 0.35):
			climax_music = true
			Sfx.play_music("bgm_climax", 2.5, -3.0)
	if autoplay_next_t > 0.0:
		autoplay_next_t -= real
		if autoplay_next_t <= 0.0:
			autoplay_next_t = -1.0
			_next_watch_match()


func _update_time_scale(real: float) -> void:
	if replaying:
		return
	var target := 1.0
	var keep: Array = []
	for s in _slow:
		if real_time < s["until"]:
			target = min(target, s["scale"])
			keep.append(s)
	_slow = keep
	# 进入慢动作要快，恢复要柔
	if target < _time_scale:
		_time_scale = target
	else:
		_time_scale = move_toward(_time_scale, target, real * 2.8)
	Engine.time_scale = max(0.02, _time_scale * user_speed)
	Sfx.muffle(clamp((0.8 - _time_scale) * 1.3, 0.0, 0.85))


## 慢动作：scale 倍速，持续 dur 秒（真实时间）
func slowmo(scale: float, dur: float) -> void:
	_slow.append({"scale": scale, "until": real_time + dur})


func wait(t: float) -> void:
	await get_tree().create_timer(t, false, false, false).timeout


func wait_real(t: float) -> void:
	await get_tree().create_timer(t, false, false, true).timeout


func arena_bounds(z: float) -> Vector2:
	# 场地略呈梯形：越靠近关门越窄
	var k: float = clamp((Z_MAX - z) / (Z_MAX - Z_MIN), 0.0, 1.0)
	return Vector2(300.0 + k * 60.0, 1372.0 - k * 60.0)


func _separate() -> void:
	if not (f1.is_alive() and f2.is_alive()):
		return
	for f in fighters:
		if f.state in [Fighter.S.SCRIPTED, Fighter.S.CLASH, Fighter.S.DODGE, Fighter.S.KO, Fighter.S.DOWN]:
			return
	if f1.is_airborne() or f2.is_airborne():
		return
	if absf(f1.position.y - f2.position.y) > 36.0:
		return
	# 马战对冲时允许交错而过
	if (f1.mounted and absf(f1.vel.x) > 280.0) or (f2.mounted and absf(f2.vel.x) > 280.0):
		return
	var dx := f2.position.x - f1.position.x
	var min_d := (f1.half_width() + f2.half_width()) * (0.95 if f1.mounted and f2.mounted else 0.8)
	if absf(dx) < min_d:
		var push := (min_d - absf(dx)) * 0.5
		var s := 1.0 if dx >= 0.0 else -1.0
		if absf(dx) < 0.5:
			s = 1.0 if f1.side == 0 else -1.0
		f1.push(-s * push)
		f2.push(s * push)


func _mounted_pass_check(dt: float) -> void:
	# 两马相交而过：记一合
	mounted_pass_t -= dt
	if phase != "fight" or mounted_pass_t > 0.0:
		return
	if not (f1.mounted or f2.mounted):
		return
	var dx := f2.position.x - f1.position.x
	var rel_v := f2.vel.x - f1.vel.x
	if absf(dx) < 60.0 and absf(rel_v) > 400.0 and absf(f1.position.y - f2.position.y) < 90.0:
		mounted_pass_t = 1.2
		_count_round()


func _count_round() -> void:
	if game_time - last_round_t < 1.1:
		return
	last_round_t = game_time
	round_count += 1
	if round_count % 10 == 0 and round_count > lead_rounds_announced:
		lead_rounds_announced = round_count
		var diff := absf(f1.hp / f1.max_hp - f2.hp / f2.max_hp)
		if diff < 0.15:
			narrate("二将大战%d合，不分胜负！" % round_count, 1)
		else:
			var lead := f1 if f1.hp / f1.max_hp > f2.hp / f2.max_hp else f2
			narrate("斗到%d合，%s渐占上风！" % [round_count, lead.def["name"]], 0)


# ---------------------------------------------------------------- 终结回放

func rec_event(kind: String, fn: String, args: Array) -> void:
	rec_events.append({"t": game_time, "kind": kind, "name": fn, "args": args})


func _rec_sfx(snd: String, vol: float, pitch: float) -> void:
	if recording:
		rec_event("sfx", snd, [vol, pitch])


func _record_frame() -> void:
	rec_frames.append({"t": game_time, "a": f1.snapshot(), "b": f2.snapshot()})
	var cutoff := game_time - REC_SPAN
	while rec_frames.size() > 0 and rec_frames[0]["t"] < cutoff:
		rec_frames.pop_front()
	while rec_events.size() > 0 and rec_events[0]["t"] < cutoff:
		rec_events.pop_front()


## 终结一击的慢镜头回放：重放最后两秒多的人物动作、特效和音效
func _replay(ko_t: float, winner: Fighter, loser: Fighter) -> void:
	recording = false
	if Game.sim or rec_frames.size() < 20:
		return
	var t0: float = max(float(rec_frames[0]["t"]), ko_t - 2.3)
	var t1: float = min(float(rec_frames[rec_frames.size() - 1]["t"]), ko_t + 0.6)
	if t1 - t0 < 0.8:
		return
	var save_a := f1.snapshot()
	var save_b := f2.snapshot()
	replaying = true
	replay_skip = false
	# 清掉场上残留的特效，回放更干净
	for c in vfx.get_children():
		if c != vfx.top_layer:
			c.queue_free()
	for c in vfx.top_layer.get_children():
		c.queue_free()
	cine.set_letterbox(true)
	cine.show_replay(true, winner)
	post.set_desat(0.32)
	post.flash(Color(1, 1, 1), 0.55)
	Sfx.play("ult_whoosh", -4.0, 1.25)
	Sfx.muffle(0.25)
	var rt := t0
	var fi := 0
	var ei := 0
	while ei < rec_events.size() and float(rec_events[ei]["t"]) < t0:
		ei += 1
	var zoom0 := 1.75
	var side := 1.0 if randf() < 0.5 else -1.0
	while rt < t1 and is_inside_tree() and not replay_skip:
		var near: bool = absf(rt - ko_t) < 0.28
		Engine.time_scale = 0.2 if near else 0.5
		await get_tree().process_frame
		if not is_inside_tree():
			return
		rt += get_process_delta_time()
		while fi < rec_frames.size() - 1 and float(rec_frames[fi + 1]["t"]) <= rt:
			fi += 1
		f1.apply_snapshot(rec_frames[fi]["a"])
		f2.apply_snapshot(rec_frames[fi]["b"])
		while ei < rec_events.size() and float(rec_events[ei]["t"]) <= rt:
			var e: Dictionary = rec_events[ei]
			ei += 1
			if e["kind"] == "vfx":
				vfx.callv(e["name"], e["args"])
			else:
				Sfx.play(e["name"], float(e["args"][0]) - 2.0, float(e["args"][1]) * 0.78, 0.0)
		var k: float = clamp((rt - t0) / (t1 - t0), 0.0, 1.0)
		var mid := (f1.center_global() + f2.center_global()) * 0.5
		cam.shot(mid + Vector2(side * (1.0 - k) * 60.0, -10.0), zoom0 + k * 0.4, 0.3, 7.0)
		cam.set_roll(side * (1.2 - k * 2.4))
	Engine.time_scale = 1.0
	Sfx.muffle(0.0)
	f1.apply_snapshot(save_a)
	f2.apply_snapshot(save_b)
	replaying = false
	cine.show_replay(false, winner)
	post.set_desat(0.0)
	cam.set_roll(0.0)
	post.flash(Color(1, 1, 1), 0.35)


# ---------------------------------------------------------------- 对峙

var standoff_t := 0.0
var last_standoff := -100.0
var standoff_count := 0


## 观战模式：两将拉开距离、对面而立片刻，便切入"对峙"演出，随后双双冲锋
func _standoff_check(dt: float) -> void:
	if player_side >= 0 or cine_busy or standoff_count >= 2:
		standoff_t = 0.0
		return
	if game_time - match_start_time < 7.0 or game_time - last_standoff < 18.0:
		return
	var ok := true
	for f in fighters:
		if not (f.state in [Fighter.S.IDLE, Fighter.S.GUARD]) or f.is_airborne() or f.vel.length() > 260.0:
			ok = false
	var dx := absf(f2.position.x - f1.position.x)
	if dx < 300.0 or dx > 760.0 or absf(f2.position.y - f1.position.y) > 140.0:
		ok = false
	if f1.facing == f2.facing or not projectiles.is_empty():
		ok = false
	standoff_t = standoff_t + dt if ok else max(0.0, standoff_t - dt * 2.0)
	if standoff_t > 0.45:
		standoff_t = 0.0
		_standoff()


func _standoff() -> void:
	ev("standoff")
	standoff_count += 1
	last_standoff = game_time
	cine_busy = true
	phase = "cine"
	for f in fighters:
		f.set_scripted(true)
		f.set_pose("idle")
		f.facing = 1 if f.opponent.position.x > f.position.x else -1
	var mid := (f1.center_global() + f2.center_global()) * 0.5
	cine.set_letterbox(true)
	cam.shot(mid + Vector2(0, -20), 1.45, 1.0, 2.2)
	arena.gust.position = Vector2(mid.x - 900.0, mid.y + 60.0)
	arena.gust.restart()
	arena.gust.emitting = true
	Sfx.play("wind", -2.0)
	Sfx.music_duck(-16.0, 0.6)
	var lines := ["风沙骤起，二将勒兵对峙……", "两军鸦雀无声，只听得战马喷鼻。", "四目相对，杀气弥漫。", "谁也不敢先动——"]
	narrate(lines[randi() % lines.size()], 1)
	await wait_real(1.0)
	if not is_inside_tree():
		return
	# 正反打：先给一方特写，再给另一方
	var order := [f1, f2] if randf() < 0.5 else [f2, f1]
	for f in order:
		cam.cut(f.head_global() + Vector2(f.facing * -30.0, 50.0), 2.5)
		cam.shot(f.head_global() + Vector2(f.facing * -30.0, 50.0), 2.65, 0.6, 1.2)
		cam.set_roll(-2.0 * f.facing)
		Sfx.play("blade_draw", -6.0)
		await wait_real(0.55)
		if not is_inside_tree():
			return
	cam.set_roll(0.0)
	cam.cut(mid + Vector2(0, -20), 1.7)
	# 双目一凛
	for f in fighters:
		vfx.block_spark(f.head_global() + Vector2(f.facing * 18.0, 30.0), f.theme_color.lerp(Color.WHITE, 0.4))
		f.glow = 0.9
		f.glow_col = f.theme_color
	cam.shot(mid + Vector2(0, -20), 1.85, 1.0, 6.0)
	Sfx.play("charge_full", -2.0)
	Sfx.play("drum", 2.0, 0.9)
	await wait_real(0.55)
	if not is_inside_tree():
		return
	Sfx.play("drum_big", 2.0)
	Sfx.music_duck(-2.0, 0.4)
	cine.set_letterbox(false)
	cam.release(3.5)
	narrate("杀——！二将同时发力冲出！", 1)
	arena.cheer(0, 1.0)
	arena.cheer(1, 1.0)
	cine_busy = false
	if phase == "cine":
		phase = "fight"
	for f in fighters:
		f.set_scripted(false)
		f.glow = 0.0
		if f.ctrl is AiBrain:
			f.ctrl.charge_now()


# ---------------------------------------------------------------- 招式事件

func on_move_start(_f: Fighter, _mv: Dictionary) -> void:
	pass


func on_move_active(a: Fighter, mv: Dictionary) -> void:
	var b: Fighter = a.opponent
	if b == null or not b.is_alive() or mv["kind"] != "melee" or phase != "fight":
		return
	if b.state != Fighter.S.ATTACK or b.move.is_empty() or b.move["kind"] != "melee":
		return
	var b_ready: bool = b.move_phase == 1 or (b.move_phase == 0 and b.startup_len - b.move_t < 0.07)
	if not b_ready:
		return
	if a.facing == b.facing:
		return
	var dx := absf(a.position.x - b.position.x)
	var dz := absf(a.position.y - b.position.y)
	var reach_a: float = mv["reach"] + b.half_width()
	var reach_b: float = b.move["reach"] + a.half_width()
	if dx > max(reach_a, reach_b) or dz > min(float(mv["depth"]), float(b.move["depth"])) + 12.0:
		return
	var ca: int = mv["clash"]
	var cb: int = b.move["clash"]
	if ca >= 2 and cb >= 2:
		ev("clash_lock")
		_lock_clash(a, b)
	elif ca >= 1 and cb >= 1:
		ev("clash_bounce")
		_bounce_clash(a, b)


func on_rage_full(f: Fighter) -> void:
	Sfx.play("rage", -4.0)
	vfx.ring(f.center_global(), 200.0, f.theme_color, false, 14.0, 0.5)
	if phase == "fight":
		narrate("%s怒气已满，绝技「%s」蓄势待发！" % [f.def["name"], f.def["ult"]["name"]], 0)


func on_fighter_down(f: Fighter) -> void:
	if f.is_alive():
		arena.cheer(1 - f.side, 0.7)
		arena.gasp(f.side)


func on_feint_turn(f: Fighter) -> void:
	ev("feint")
	slowmo(0.45, 0.35)
	cam.punch(0.05)
	narrate("回身一击！%s中计了！" % f.opponent.def["name"], 1)


func say(f: Fighter, text: String, life := 2.2) -> void:
	vfx.say(f, text, life)


var _last_narrate_t := -10.0
var _recent_lines := {}


func narrate(text: String, imp := 0) -> void:
	# 普通战报限频，同一句 8 秒内不重复，免得刷屏
	if _recent_lines.has(text) and real_time - _recent_lines[text] < 8.0:
		return
	if imp == 0 and real_time - _last_narrate_t < 1.8:
		return
	_last_narrate_t = real_time
	_recent_lines[text] = real_time
	hud.narrate(text, imp)


## 触屏：跳过开场 / 终结回放
func request_skip() -> void:
	if replaying:
		replay_skip = true
	elif phase == "intro":
		skip_intro = true


## 触屏：观战倍速（×1 → ×1.5 → ×2）
func toggle_speed() -> void:
	user_speed = {1.0: 1.5, 1.5: 2.0, 2.0: 1.0}.get(user_speed, 1.0)
	narrate("观战速度 ×%s" % str(user_speed), 0)


## 隐藏 / 显示血条（观战暂停面板里调用；键盘 Tab 也走这里）
func toggle_hud() -> void:
	if hud:
		hud.set_visible_hud(hud.user_hidden)   # 当前是隐藏 → 传 true 显示，反之亦然


func mode_label() -> String:
	if player_side >= 0:
		return "单挑 · 难度：%s" % Game.difficulty_name()
	if Game.watch_rule == "arena" and Game.champion_id != "":
		return "观战 · 擂台 · 擂主%s %d连胜" % [Roster.display_name(Game.champion_id), Game.champion_streak]
	return "观战 · 擂台"


# ---------------------------------------------------------------- 命中判定

func try_hit(a: Fighter, mv: Dictionary, idx: int) -> bool:
	var d: Fighter = a.opponent
	if d == null or not d.is_alive() or phase == "result":
		return false
	var reach: float = mv["reach"]
	if not mv["charge"].is_empty():
		reach += float(mv["charge"]["reach_add"]) * a.charge_ratio
	var rel := (d.position.x - a.position.x) * a.facing
	var hw := d.half_width()
	if rel < -float(mv["back"]) - hw * 0.5 or rel > reach + hw * 0.7:
		return false
	if absf(d.position.y - a.position.y) > float(mv["depth"]) + (12.0 if d.mounted else 4.0):
		return false
	if absf(d.h - a.h) > float(mv["height"]) + 30.0:
		return false
	var from_dir := 1 if a.position.x > d.position.x else -1
	var res := d.classify_incoming(a, mv, from_dir)
	match res:
		"none":
			return false
		"evade":
			if not a.perfect_dodge_used and d.state == Fighter.S.DODGE:
				a.perfect_dodge_used = true
				_perfect_dodge(d, a)
			return false
		"parry":
			_parry(a, d, mv)
			return true
		"block":
			_block(a, d, mv)
			return true
		"armor":
			_hit(a, d, mv, idx, true)
			return true
		_:
			_hit(a, d, mv, idx, false)
			return true


func _contact_point(a: Fighter, d: Fighter) -> Vector2:
	var dc := d.center_global()
	var ac := a.center_global()
	var p := dc.lerp(ac, 0.22)
	p.x = dc.x - a.facing * d.half_width() * 0.5 * d.depth_scale()
	return p


func _hit(a: Fighter, d: Fighter, mv: Dictionary, _idx: int, armored: bool, proj := {}) -> void:
	var ratio := a.charge_ratio if proj.is_empty() else float(proj.get("charge", 0.0))
	var v := Cfg.bal_float("damage.variance", 0.06)
	var mult: float = a.power * d.defense * randf_range(1.0 - v, 1.0 + v)
	var ch: Dictionary = mv["charge"]
	if not ch.is_empty():
		mult *= lerp(1.0, float(ch["dmg_mult"]), ratio)
	var tags: Array = []
	# 破招：对方已经起手一段时间、被抢先打中
	var counter: bool = d.state == Fighter.S.ATTACK and d.move_phase == 0 and not armored and d.move_t > 0.07
	if counter:
		mult *= 1.28
		tags.append("破招")
	if a.counter_ready > 0.0:
		mult *= 1.45
		a.counter_ready = 0.0
		tags.append("反击")
	var from_front: bool = (a.position.x - d.position.x) * d.facing > 0.0
	if not from_front and not d.mounted:
		mult *= 1.12
	if d.state == Fighter.S.GUARDBREAK:
		mult *= 1.2
	if a.buffs.has("berserk"):
		mult *= 1.25
	if a.mounted:
		mult *= float(a.def.get("mount_dmg", 1.0))
	# 黄忠·老当益壮：体力过半后越战越勇
	if a.id == "huangzhong" and a.hp / a.max_hp < 0.5:
		mult *= 1.15
	# 步战打骑将：专攻马腿，伤害略高；骑将打步卒略低（落马一方仍有翻盘机会）
	if d.mounted and not a.mounted:
		mult *= 1.12
	elif a.mounted and not d.mounted:
		mult *= 0.94
	if mv["run"] and a.mounted:
		mult *= 1.0 + clamp((absf(a.vel.x) - 300.0) / 600.0, 0.0, 0.5)
	var dmg: float = float(mv["dmg"]) * mult
	if armored:
		dmg *= 0.8
	var lethal := d.hp - dmg <= 0.0
	var dealt := d.take_damage(dmg, a)
	a.move_connected = true
	a.move_landed = true
	ev("hit")
	if armored:
		ev("armor_hit")
	if counter:
		ev("counter")
	a.stats["hits"] += 1
	a.combo += 1
	a.combo_t = 1.15
	a.stats["max_combo"] = max(a.stats["max_combo"], a.combo)
	if a.combo >= 2:
		hud.show_combo(a.side, a.combo)
	# 打击感：顿帧、震屏、推镜
	var big: bool = dmg > 70.0 or lethal or mv["launch"] > 0.0 or not ch.is_empty() and ratio > 0.5
	var stop: float = float(mv["hitstop"]) * (1.0 + ratio * 0.6) + (0.05 if counter else 0.0)
	a.freeze = stop
	d.freeze = stop
	cam.shake(float(mv["shake"]) * (1.0 + ratio * 0.5) + (0.1 if counter else 0.0))
	if float(mv["zoom_kick"]) > 0.0 or big:
		cam.punch(max(float(mv["zoom_kick"]), 0.03) * (1.0 + ratio))
	cam.heat(0.18 if big else 0.08)
	var cp: Vector2 = _contact_point(a, d) if proj.is_empty() else proj["pos"]
	vfx.hit_spark(cp, a.theme_color, 1.4 if big else 0.7)
	if big:
		post.aberrate(1.2 + ratio)
	Sfx.play(mv["sfx_hit"], 0.0 if big else -3.0, 0.92 if big else 1.0)
	if big:
		Sfx.play("clang", -10.0, 0.8)
	var kind := "crit" if (counter or tags.has("反击") or big) else "number"
	vfx.number(cp + Vector2(0, -30), dealt, kind)
	for tg in tags:
		if real_time - float(d.get_meta("stamp_t", -10.0)) > 0.9:
			d.set_meta("stamp_t", real_time)
			vfx.stamp(d.head_global() + Vector2(0, -20), tg, Color(1.0, 0.75, 0.25), 58)
	# 受击反应
	if not armored:
		var kb: float = float(proj.get("kb", mv["kb"]))
		var hitstun: float = float(proj.get("hitstun", mv["hitstun"]))
		var launch: float = float(mv["launch"])
		if not ch.is_empty() and ratio >= float(ch.get("launch_at", 2.0)):
			launch = max(launch, float(ch["launch"]))
		if counter:
			hitstun += 0.15
		d.apply_hit_reaction(a, mv, hitstun, kb * (1.0 + ratio * 0.4), launch)
	else:
		d.flash = 0.7
		d.glow = 1.0
		d.glow_col = Color(1.0, 0.8, 0.3)
		vfx.stamp(d.head_global(), "霸体", Color(1.0, 0.85, 0.35), 46)
	# 战报与士气
	_count_round()
	if not first_blood:
		first_blood = true
		narrate("%s先拔头筹！" % a.def["name"], 0)
	if a.combo == 4:
		narrate("%s连出四招，%s只有招架之功！" % [a.def["name"], d.def["name"]], 0)
	elif a.combo == 7:
		narrate("%s攻势如潮，已连击七下！" % a.def["name"], 1)
	if counter and randf() < Cfg.bal_float("damage.counter_chance", 0.35):
		narrate("%s抓住破绽，破招！" % a.def["name"], 0)
	if a.hp / a.max_hp < 0.3 and dealt > d.max_hp * 0.07:
		narrate("%s绝地反击！" % a.def["name"], 1)
	if mv["launch"] > 0.0 and not d.mounted and not lethal:
		ev("launch")
	if mv["launch"] > 0.0 and not d.mounted and not lethal and randf() < 0.4:
		narrate("%s一%s将%s挑飞！" % [a.def["name"], mv["label"], d.def["name"]], 0)
	arena.cheer(a.side, clamp(dealt / 90.0, 0.2, 1.0))
	if big:
		arena.gasp(d.side)
	if lethal:
		on_ko(d, a, mv)
		return
	# 落马
	var unhorse_r := Cfg.bal_float("round.unhorse_hp_ratio", 0.55)
	if d.mounted and d.can_unhorse and not d.unhorsed and d.hp / d.max_hp < unhorse_r and phase == "fight":
		_unhorse(d, a)
	elif d.mounted and not d.can_unhorse and not d.unhorsed and d.hp / d.max_hp < unhorse_r and phase == "fight":
		# 没有步战形象的武将：坐骑受惊嘶鸣，人马更凶
		d.unhorsed = true
		Sfx.play("horse_neigh", -2.0)
		say(d, "赤兔！随我杀！" if d.id == "lvbu" else "驾！", 1.6)
		d.gain_rage(Cfg.bal_float("rage.on_unhorse", 12.0))
		narrate("%s的坐骑一声长嘶，人马更凶！" % d.def["name"], 1)


func _block(a: Fighter, d: Fighter, mv: Dictionary) -> void:
	var ratio := a.charge_ratio
	var chip: float = float(mv["dmg"]) * a.power * d.defense * float(mv["chip"])
	d.take_damage(chip, a, false)
	var gd: float = float(mv["guard_dmg"]) * (1.0 + ratio * 0.7)
	d.stamina -= gd
	var cp := _contact_point(a, d)
	_count_round()
	if (mv["breaks_guard"] and (ratio >= 0.5 or d.stamina <= 0.0)) or d.stamina <= 0.0:
		ev("guard_break")
		d.apply_guard_break(a)
		a.freeze = 0.09
		d.freeze = 0.09
		cam.shake(0.32)
		cam.punch(0.05)
		vfx.clash_spark(cp, false)
		vfx.stamp(d.head_global(), "破防", Color(1.0, 0.45, 0.25), 66)
		Sfx.play("guard_break", 0.0)
		Sfx.play("clang", -2.0, 0.75)
		narrate("%s一招震开%s的守势——破防！" % [a.def["name"], d.def["name"]], 1)
		arena.cheer(a.side, 0.8)
		return
	ev("block")
	d.apply_block(a, mv, float(mv["kb"]) * 0.45 + 60.0)
	a.freeze = 0.05
	d.freeze = 0.05
	vfx.block_spark(cp, d.theme_color.lerp(Color(1, 0.85, 0.4), 0.6))
	cam.shake(0.08)
	d.gain_rage(Cfg.bal_float("rage.on_block", 2.5))
	Sfx.play("clang", -5.0, randf_range(0.95, 1.15))


func _parry(a: Fighter, d: Fighter, _mv: Dictionary) -> void:
	ev("parry")
	d.stats["parries"] += 1
	d.gain_rage(Cfg.bal_float("rage.on_parry", 16.0))
	d.counter_ready = 0.75
	a.apply_parried(d)
	d._to_idle()
	d.set_pose("attack")
	d.squash = Vector2(1.15, 0.9)
	var cp := _contact_point(a, d)
	vfx.clash_spark(cp, false)
	vfx.ring(cp, 180.0, Color(1, 0.95, 0.7), false, 10.0, 0.3)
	vfx.stamp(d.head_global() + Vector2(0, -20), "拆招", Color(0.6, 0.95, 1.0), 72)
	Sfx.play("parry", 0.0)
	Sfx.play("clang", 0.0, 1.25)
	slowmo(0.3, 0.32)
	cam.punch(0.06)
	cam.shake(0.18)
	post.flash(Color(0.85, 0.95, 1.0), 0.28)
	_count_round()
	var weapon: String = a.def["weapon_name"]
	narrate("%s拨开%s的%s——拆招！" % [d.def["name"], a.def["name"], weapon], 1)
	arena.cheer(d.side, 0.9)


func _perfect_dodge(d: Fighter, a: Fighter) -> void:
	ev("pdodge")
	d.stats["dodges"] += 1
	d.gain_rage(Cfg.bal_float("rage.on_pdodge", 9.0))
	slowmo(0.35, 0.3)
	vfx.stamp(d.head_global(), "闪", Color(0.7, 1.0, 0.8), 70)
	vfx.afterimage(d, Color(0.6, 1.0, 0.8), 0.45, 0.7)
	Sfx.play("dodge_perfect", -2.0)
	if randf() < 0.5:
		narrate("%s闪身躲过%s的%s！" % [d.def["name"], a.def["name"], a.move.get("label", "一击")], 0)


# ---------------------------------------------------------------- 拼刀

func _bounce_clash(a: Fighter, b: Fighter) -> void:
	# 弹刀：兵器相撞各自弹开
	var mid := (a.center_global() + b.center_global()) * 0.5
	vfx.clash_spark(mid, false)
	Sfx.play("clang", 0.0, randf_range(0.95, 1.1))
	cam.shake(0.2)
	cam.punch(0.04)
	slowmo(0.4, 0.16)
	for f in [a, b]:
		f.state = Fighter.S.HITSTUN
		f.state_t = 0.0
		f.hitstun_t = 0.26
		f.move = {}
		f.vel = Vector2((1.0 if f.position.x > (a.position.x + b.position.x) * 0.5 else -1.0) * 260.0, 0)
		f.set_pose("windup")
		f.tilt_goal = -12.0
	_count_round()
	if randf() < 0.5:
		narrate("铛！兵器相撞，二将各退半步。", 0)


func _lock_clash(a: Fighter, b: Fighter) -> void:
	if cine_busy:
		return
	cine_busy = true
	phase = "cine"
	var left := a if a.position.x < b.position.x else b
	var right := b if left == a else a
	var mid_x := (left.position.x + right.position.x) * 0.5
	var z := (left.position.y + right.position.y) * 0.5
	var gap := (left.half_width() + right.half_width()) * 0.55 + 46.0
	for f in [left, right]:
		f.state = Fighter.S.CLASH
		f.state_t = 0.0
		f.move = {}
		f.vel = Vector2.ZERO
		f.h = 0.0
		f.trail_on = false
		f.set_pose("attack")
		f.tilt_goal = 6.0
	left.facing = 1
	right.facing = -1
	left.position = Vector2(mid_x - gap, z)
	right.position = Vector2(mid_x + gap, z)
	var contact := Vector2(mid_x, z - Bank.STAND_HEIGHT * 0.55 * left.depth_scale())
	cine.set_letterbox(true)
	cam.shot(contact + Vector2(0, 30), 2.2, 6.0, 7.0)
	cam.set_roll(-2.5)
	vfx.clash_spark(contact, true)
	Sfx.play("clang", 4.0, 0.8)
	Sfx.play("clash_hold", -2.0)
	slowmo(0.25, 0.35)
	post.flash(Color(1, 0.95, 0.8), 0.35)
	post.aberrate(2.0)
	cam.shake(0.4)
	narrate("两将兵器绞在一处，各自较力！", 1)
	var player := player_side
	cine.start_clash(left, right, player)
	var bal := 0.0
	var t := 0.0
	var spark_t := 0.0
	var pl_ctrl = left.ctrl if player == 0 and left.side == 0 else (right.ctrl if player == 0 and right.side == 0 else null)
	var pl_is_left := pl_ctrl != null and left.side == 0
	while t < 2.4 and is_inside_tree():
		await get_tree().process_frame
		var dt: float = get_process_delta_time() / max(0.0001, Engine.time_scale)
		dt = min(dt, 0.05)
		t += dt
		var push_l := _clash_push(left) * dt
		var push_r := _clash_push(right) * dt
		if pl_ctrl != null and pl_ctrl.has_method("mash"):
			# 玩家连打代替 AI 的自动较力
			if pl_is_left:
				push_l = (0.13 if pl_ctrl.mash() else 0.0) + 0.1 * dt
			else:
				push_r = (0.13 if pl_ctrl.mash() else 0.0) + 0.1 * dt
		# bal > 0 表示右方占优，交锋点被推向左边
		bal += push_r - push_l
		bal = clamp(bal, -1.0, 1.0)
		cine.update_clash(bal)
		left.jitter = 3.0
		right.jitter = 3.0
		var shove := -bal * 22.0
		left.position.x = mid_x - gap + shove
		right.position.x = mid_x + gap + shove
		spark_t -= dt
		if spark_t <= 0.0:
			spark_t = randf_range(0.06, 0.14)
			vfx.block_spark(contact + Vector2(shove, randf_range(-10, 10)), Color(1, 0.85, 0.5))
			Sfx.play("clang", -14.0, randf_range(1.2, 1.5))
			cam.shake(0.08)
		if absf(bal) >= 1.0:
			break
	cine.end_clash()
	cine.set_letterbox(false)
	cam.set_roll(0.0)
	var winner: Fighter = null
	var loser: Fighter = null
	if bal >= 0.25:
		winner = right
		loser = left
	elif bal <= -0.25:
		winner = left
		loser = right
	if winner:
		winner.stats["clash_win"] += 1
		winner.gain_rage(Cfg.bal_float("rage.on_clash_win", 18.0))
		winner.state = Fighter.S.IDLE
		winner.set_pose("attack")
		loser.apply_guard_break(winner)
		loser.vel.x = (1.0 if loser.position.x > winner.position.x else -1.0) * 420.0
		vfx.clash_spark(contact, true)
		vfx.stamp(loser.head_global(), "震退", Color(1.0, 0.5, 0.3), 70)
		Sfx.play("guard_break", 0.0)
		Sfx.play("crowd_cheer", -6.0)
		cam.shake(0.45)
		cam.punch(0.07)
		slowmo(0.3, 0.3)
		narrate("%s力压%s，将其震退！" % [winner.def["name"], loser.def["name"]], 1)
		arena.cheer(winner.side, 1.0)
		arena.gasp(loser.side)
		winner._to_idle()
	else:
		for f in [left, right]:
			f.state = Fighter.S.HITSTUN
			f.state_t = 0.0
			f.hitstun_t = 0.35
			f.vel.x = (-1.0 if f == left else 1.0) * 380.0
			f.set_pose("hurt")
			f.gain_rage(Cfg.bal_float("rage.on_round_win", 8.0))
		vfx.clash_spark(contact, true)
		Sfx.play("clang", 2.0, 0.9)
		cam.shake(0.3)
		narrate("势均力敌！二将各自弹开。", 0)
	_count_round()
	cam.release(4.0)
	cine_busy = false
	if phase == "cine":
		phase = "fight"


func _clash_push(f: Fighter) -> float:
	var wu: float = f.def["stats"]["wu"]
	var base := 0.5 + (wu - 90.0) * 0.04
	base *= 1.0 + f.rage / 300.0
	if f.mounted:
		base *= 1.08
	return max(0.1, base * randf_range(0.4, 1.7))


# ---------------------------------------------------------------- 落马

func _unhorse(d: Fighter, a: Fighter) -> void:
	ev("unhorse")
	if cine_busy:
		unhorse_pending.append([d, a])
		return
	cine_busy = true
	phase = "cine"
	await wait(0.02)
	var dir := 1.0 if d.position.x > a.position.x else -1.0
	slowmo(0.22, 0.9)
	cam.track(d, 2.0, 1.7, Vector2(0, -90), 8.0)
	post.flash(Color(1, 0.95, 0.85), 0.3)
	Sfx.play("horse_neigh", 0.0)
	Sfx.play("hit_heavy", 0.0, 0.8)
	for i in 5:
		vfx.dust(d.global_position + Vector2(randf_range(-60, 60), randf_range(-10, 10)), 2.2)
	vfx.ring(d.global_position, 260.0, Color(1, 0.85, 0.6), true, 18.0, 0.6)
	d.unhorse()
	d.state = Fighter.S.KNOCKDOWN
	d.state_t = 0.0
	d.h = 40.0
	d.vh = 720.0
	d.vel = Vector2(dir * 300.0, 0)
	d.set_pose("hurt")
	d.bounced = false
	d.juggle = 2
	vfx.stamp(d.head_global() + Vector2(0, -60), "落马", Color(1.0, 0.6, 0.3), 84)
	narrate("%s被%s一招打落马下！" % [d.def["name"], a.def["name"]], 1)
	arena.cheer(a.side, 1.0)
	arena.gasp(d.side)
	await wait_real(1.0)
	cam.release(3.5)
	cine_busy = false
	if phase == "cine":
		phase = "fight"
	await wait_real(0.9)
	if not is_inside_tree() or not d.is_alive():
		return
	say(d, Roster.line(d.id, "unhorsed"), 1.8)
	# 义：对手若仍在马上，可能下马相陪
	if a.mounted and a.is_alive() and a.ctrl is AiBrain and randf() < float(a.def["ai"]["honor"]):
		await wait_real(1.4)
		if not is_inside_tree() or phase != "fight" or not a.mounted or cine_busy:
			return
		if not (a.state in [Fighter.S.IDLE, Fighter.S.GUARD]):
			await wait_real(0.6)
			if phase != "fight" or not (a.state in [Fighter.S.IDLE, Fighter.S.GUARD]) or cine_busy:
				return
		await _honor_dismount(a, d)


func _honor_dismount(a: Fighter, d: Fighter) -> void:
	ev("honor")
	cine_busy = true
	phase = "cine"
	a.set_scripted(true)
	d.set_scripted(true)
	cam.track(a, 1.9, 2.4, Vector2(0, -80), 5.0)
	say(a, Roster.line(a.id, "honor"), 2.0)
	await wait_real(1.2)
	vfx.dust(a.global_position, 1.8)
	Sfx.play("jump", -4.0)
	a.unhorse()
	a.set_pose("jump")
	a.squash = Vector2(0.8, 1.2)
	narrate("%s翻身下马，要与%s步战！" % [a.def["name"], d.def["name"]], 1)
	arena.cheer(a.side, 1.0)
	arena.cheer(d.side, 0.6)
	Sfx.play("crowd_cheer", -4.0)
	await wait_real(0.9)
	a.set_scripted(false)
	d.set_scripted(false)
	cam.release(3.0)
	cine_busy = false
	if phase == "cine":
		phase = "fight"


# ---------------------------------------------------------------- 绝技

func can_ult(f: Fighter) -> bool:
	if phase != "fight" or cine_busy or not f.is_alive() or not f.opponent.is_alive():
		return false
	if f.rage < 100.0:
		return false
	if f.state == Fighter.S.ATTACK and f.move_phase < 2:
		return false
	return f.state in [Fighter.S.IDLE, Fighter.S.ATTACK, Fighter.S.GUARD, Fighter.S.JUMP]


func start_ult(f: Fighter) -> void:
	if not can_ult(f):
		return
	f.rage = 0.0
	f.stats["ults"] += 1
	ev("ult")
	cine_busy = true
	phase = "cine"
	await Ultimates.run(self, f, f.opponent)
	if not is_inside_tree():
		return
	cine_busy = false
	if phase == "cine":
		phase = "fight"
	cam.release(3.0)
	cine.set_letterbox(false)
	for p in unhorse_pending:
		if p[0].is_alive() and p[0].mounted:
			_unhorse(p[0], p[1])
	unhorse_pending.clear()


## 绝技里的一下伤害（不经过格挡）。final=true 是收尾一击：可以致死，并放开对手让其飞出去。
func ult_damage(a: Fighter, d: Fighter, amount_ratio: float, final: bool, kb := 0.0, launch := 0.0, spark := true) -> void:
	if not d.is_alive():
		return
	var dmg: float = d.max_hp * amount_ratio * a.power * d.defense
	var dealt := d.take_damage(dmg, a, final)
	a.stats["hits"] += 1
	a.combo += 1
	a.combo_t = 1.6
	a.stats["max_combo"] = max(a.stats["max_combo"], a.combo)
	hud.show_combo(a.side, a.combo)
	var cp := d.center_global()
	if spark:
		vfx.hit_spark(cp, a.theme_color, 1.5 if final else 1.0)
	vfx.number(cp + Vector2(randf_range(-30, 30), -40), dealt, "crit")
	Sfx.play("hit_heavy" if final else "hit_light", 0.0 if final else -4.0, randf_range(0.9, 1.1))
	d.flash = 1.0
	d.jitter = 7.0
	d.tint = Color(1.0, 0.55, 0.55)
	d.set_pose("hurt")
	cam.shake(0.5 if final else 0.16)
	_count_round()
	arena.cheer(a.side, 1.0 if final else 0.5)
	if final:
		d.set_scripted(false)
		if d.hp <= 0.0:
			on_ko(d, a, {"launch": launch})
			return
		d.apply_hit_reaction(a, {}, 0.7, kb, launch)
		arena.gasp(d.side)
	elif kb != 0.0:
		var dir := 1.0 if d.position.x >= a.position.x else -1.0
		d.position.x += dir * kb * 0.04
		var b2 := arena_bounds(d.position.y)
		d.position.x = clamp(d.position.x, b2.x + d.half_width(), b2.y - d.half_width())


# ---------------------------------------------------------------- 箭矢

func spawn_projectile(f: Fighter, mv: Dictionary, ratio: float) -> void:
	var pj: Dictionary = mv["projectile"]
	var a := ArrowFx.new()
	var tip := f.tip_global()
	a.position = Vector2(tip.x, f.position.y)
	a.h = max(30.0, f.position.y - tip.y)
	a.vx = f.facing * float(pj["speed"]) * (1.0 + ratio * 0.25)
	a.owner_f = f
	a.mv = mv
	a.charge = ratio
	a.pierce = pj.get("pierce", false) and ratio > 0.3
	a.size = float(pj.get("size", 1.0)) * (1.0 + ratio * 0.3)
	a.gold = pj.get("gold", false) or ratio > 0.5
	a.color = f.theme_color
	a.life = float(pj.get("life", 1.0))
	if pj.has("dive"):
		a.vh = -float(pj["speed"]) * float(pj["dive"])
	vfx.add_child(a)
	projectiles.append(a)
	vfx._rec("spawn", ["arrow", {"position": a.position, "h": a.h, "vx": a.vx, "vh": a.vh, "size": a.size,
		"gold": a.gold, "color": a.color, "life": a.life, "owner_f": f, "dead": true}, false])
	if a.gold:
		vfx.ring(tip, 120.0, Color(1, 0.85, 0.4), false, 8.0, 0.25)
		cam.shake(0.1)


func _update_projectiles(_dt: float) -> void:
	var keep: Array = []
	for a in projectiles:
		if not is_instance_valid(a):
			continue
		if a.dead:
			keep.append(a)
			continue
		var owner: Fighter = a.owner_f
		var d: Fighter = owner.opponent
		var hit := false
		if d.is_alive() and absf(a.position.x - d.position.x) < d.half_width() + 22.0 and absf(a.position.y - d.position.y) < 34.0:
			var body_mid := d.h + d.body_height() * 0.5
			if absf(a.h - body_mid) < d.body_height() * 0.62:
				hit = true
		if hit:
			var from_dir := -int(signf(a.vx))
			var res := d.classify_incoming(owner, a.mv, from_dir)
			var pos := Vector2(a.position.x, a.position.y - a.h)
			match res:
				"evade":
					if not a.get_meta("evaded", false):
						a.set_meta("evaded", true)
						if d.state == Fighter.S.DODGE:
							_perfect_dodge(d, owner)
				"parry":
					a.deflected = true
					a.dead = true
					a.vx = -a.vx * 0.25
					a.vh = 700.0
					d.stats["parries"] += 1
					d.gain_rage(Cfg.bal_float("rage.on_unhorse", 12.0))
					d.counter_ready = 0.6
					vfx.block_spark(pos, Color(0.7, 0.95, 1.0))
					vfx.stamp(d.head_global(), "拨箭", Color(0.6, 0.95, 1.0), 60)
					Sfx.play("parry", -2.0)
					slowmo(0.4, 0.2)
					narrate("%s挥兵器拨开来箭！" % d.def["name"], 0)
				"block":
					d.take_damage(float(a.mv["dmg"]) * 0.06, owner, false)
					d.stamina -= float(a.mv.get("guard_dmg", 12.0))
					vfx.block_spark(pos)
					Sfx.play("clang", -8.0, 1.3)
					if d.stamina <= 0.0:
						d.apply_guard_break(owner)
					else:
						d.apply_block(owner, a.mv, 120.0)
					a.queue_free()
					continue
				"armor", "hit":
					var pj: Dictionary = a.mv["projectile"]
					var proj := {"charge": a.charge, "kb": pj.get("kb", 150.0), "hitstun": pj.get("hitstun", 0.3), "pos": pos}
					var saved := owner.charge_ratio
					_hit(owner, d, a.mv, 0, res == "armor", proj)
					owner.charge_ratio = saved
					if not a.pierce:
						a.queue_free()
						continue
					a.dead = true
		keep.append(a)
	projectiles = keep


# ---------------------------------------------------------------- 终局

func on_ko(d: Fighter, a: Fighter, mv: Dictionary) -> void:
	if phase in ["ko", "result"]:
		return
	phase = "ko"
	cine_busy = true
	var ko_t := game_time
	var launch: float = max(float(mv.get("launch", 0.0)), 520.0)
	d.enter_ko(a, launch)
	a.freeze = 0.0
	a.trail_on = false
	slowmo(0.12, 1.5)
	post.flash(Color(1, 1, 1), 0.65)
	post.blur(0.8, Vector2(0.5, 0.45))
	post.aberrate(3.0)
	post.set_danger(0, 0.0)
	post.set_danger(1, 0.0)
	cam.track(d, 2.25, 2.4, Vector2(0, -60), 9.0)
	cam.shake(0.6)
	cine.set_letterbox(true)
	Sfx.stop_music(0.4)
	Sfx.play("hit_heavy", 4.0, 0.7)
	Sfx.play("ko", 0.0)
	var a_ratio := a.hp / a.max_hp
	var stamp_sub := ""
	if a_ratio < 0.12:
		stamp_sub = "绝地逆转！"
	elif a_ratio > 0.8:
		stamp_sub = "势如破竹！"
	elif round_count >= 30:
		stamp_sub = "鏖战%d合！" % round_count
	elif a.counter_ready > 0.0 or mv.get("_counter", false):
		stamp_sub = "一击定乾坤！"
	cine.show_stamp("斩", Color(0.95, 0.15, 0.1), 1.6, 300, stamp_sub)
	var how := "斩%s于马下" % d.def["name"] if d.mounted else "将%s击倒" % d.def["name"]
	narrate("%s战%d合，%s！" % [a.def["name"], max(1, round_count), how], 1)
	if a_ratio < 0.12:
		narrate("%s仅剩一口气，竟绝地翻盘！" % a.def["name"], 1)
	arena.cheer(a.side, 1.0)
	arena.gasp(d.side)
	Sfx.play("crowd_cheer", 0.0)
	await wait_real(1.8)
	if not is_inside_tree():
		return
	await _replay(ko_t, a, d)
	if not is_inside_tree():
		return
	post.set_desat(0.0)
	a.enter_victory()
	cam.track(a, 1.95, 4.0, Vector2(0, -70), 3.0)
	say(a, Roster.line(a.id, "win"), 2.6)
	Sfx.play("victory_drums", -1.0)
	await wait_real(1.2)
	say(d, Roster.line(d.id, "lose"), 2.0)
	await wait_real(1.6)
	if not is_inside_tree():
		return
	wins[a.side] += 1
	_end_bout(a, d, false)


func _timeout() -> void:
	if phase != "fight":
		return
	phase = "ko"
	cine_busy = true
	var r1 := f1.hp / f1.max_hp
	var r2 := f2.hp / f2.max_hp
	var a := f1 if r1 >= r2 else f2
	var d := f2 if a == f1 else f1
	Sfx.play("gong", 0.0)
	cine.show_stamp("鸣金", Color(1.0, 0.8, 0.35), 1.6, 220, "时限已到")
	narrate("鸣金收兵！%s体力占优，判胜。" % a.def["name"], 1)
	for f in fighters:
		f.set_scripted(true)
	d.set_pose("hurt")
	await wait_real(1.6)
	a.enter_victory()
	cam.track(a, 1.9, 3.0, Vector2(0, -70), 3.0)
	say(a, Roster.line(a.id, "win"), 2.4)
	Sfx.stop_music(0.6)
	Sfx.play("victory_drums", -1.0)
	await wait_real(2.4)
	if not is_inside_tree():
		return
	wins[a.side] += 1
	_end_bout(a, d, true)


func _end_bout(a: Fighter, d: Fighter, by_time: bool) -> void:
	if wins[a.side] < rounds_to_win:
		bout += 1
		cine.set_letterbox(false)
		for f in fighters:
			f.set_scripted(true)
			f.tint = Color.WHITE
		post.set_ink(1.0)
		await wait_real(0.7)
		_start_bout(false)
		return
	phase = "result"
	cine.set_letterbox(false)
	if hud:
		hud.visible = false
	if touch:
		touch.visible = false
	if Game.sim:
		_sim_report(a, d, by_time)
		return
	var summary := {}
	if player_side >= 0:
		summary = _grade_and_record(a, by_time)
	result_panel = CanvasLayer.new()
	result_panel.set_script(ResultPanel)
	result_panel.setup(self, a, d, by_time, summary)
	add_child(result_panel)
	if player_side < 0:
		autoplay_next_t = 7.5


## 结算评分 + 成长记录。只有玩家亲自打的单挑才计分（观战不计）。
func _grade_and_record(a: Fighter, by_time: bool) -> Dictionary:
	var duration := match_elapsed + maxf(0.0, game_time - match_start_time)
	var ev := Progress.evaluate(a.stats, a.hp / maxf(1.0, a.max_hp), duration, by_time)
	var is_win := a.id == Game.p1_id
	if is_win:
		return Progress.record_match(ev, Game.difficulty, true)
	# 输了：不给分、不扣分，但仍记录败场（用于称号条件/统计）
	Progress.record_match(ev, Game.difficulty, false)
	return {"eval": ev, "is_win": false, "medals": 0, "gate_ok": true,
		"rank_before": Progress.rank_info(), "rank_after": Progress.rank_info(),
		"rank_up": false, "new_titles": []}


func _sim_report(a: Fighter, d: Fighter, by_time: bool) -> void:
	var dur := game_time - match_start_time
	var line := "SIM %s>%s t=%.0f hp=%.2f rounds=%d time=%s hits=%d/%d dmg=%d/%d ult=%d/%d par=%d/%d cw=%d/%d %s" % [
		a.id, d.id, dur, a.hp / a.max_hp, round_count, str(by_time),
		f1.stats["hits"], f2.stats["hits"], int(f1.stats["dmg"]), int(f2.stats["dmg"]),
		f1.stats["ults"], f2.stats["ults"], f1.stats["parries"], f2.stats["parries"],
		f1.stats["clash_win"], f2.stats["clash_win"], str(tele)]
	print(line)
	Game.sim_log.append({"w": a.id, "l": d.id, "t": dur, "hp": a.hp / a.max_hp, "time": by_time, "tele": tele.duplicate()})
	Game.sim_left -= 1
	if Game.sim_left <= 0:
		_sim_summary()
		get_tree().quit()
		return
	Game.next_watch_pair("")
	Game.goto("battle")


func _sim_summary() -> void:
	var wins_by := {}
	var games_by := {}
	var total_t := 0.0
	var timeouts := 0
	var agg := {}
	for r in Game.sim_log:
		wins_by[r["w"]] = wins_by.get(r["w"], 0) + 1
		games_by[r["w"]] = games_by.get(r["w"], 0) + 1
		games_by[r["l"]] = games_by.get(r["l"], 0) + 1
		total_t += r["t"]
		if r["time"]:
			timeouts += 1
		for k in r["tele"]:
			agg[k] = agg.get(k, 0) + r["tele"][k]
	var n: int = Game.sim_log.size()
	print("SUMMARY n=%d avg_t=%.1f timeouts=%d" % [n, total_t / max(1, n), timeouts])
	for id in games_by:
		print("  %s %d/%d" % [id, wins_by.get(id, 0), games_by[id]])
	for k in agg:
		print("  ev %s avg=%.2f" % [k, float(agg[k]) / max(1, n)])


var _evshot_n := 0


func ev(key: String) -> void:
	tele[key] = tele.get(key, 0) + 1
	if Game.event_shots != "" and key in ["parry", "clash_lock", "unhorse", "ult", "guard_break", "honor", "feint", "launch", "pdodge", "ult_whiff", "clash_bounce", "counter", "standoff"]:
		var delays := [0.12, 0.7, 1.4]
		if key == "ult":
			delays = [0.45, 0.85, 1.3, 1.8, 2.3, 2.9, 3.6]
		for delay in delays:
			_evshot(key, delay)


## 开发用：八员武将的绝技切入左右各放一遍，逐张截图后退出
func _cutin_test(dir: String) -> void:
	await wait_real(1.0)
	var n := 0
	for id in Roster.ids():
		for side in 2:
			if not is_inside_tree():
				return
			cine.set_letterbox(true)
			cine.show_cutin_for(id, side, Color(Roster.get_def(id)["color"]), 1.1)
			await wait_real(0.5)
			var img := get_viewport().get_texture().get_image()
			if get_viewport().use_hdr_2d:
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png("%s/cutin_%02d_%s_%d.png" % [dir, n, id, side])
			n += 1
			await wait_real(0.75)
	get_tree().quit()


func _evshot(key: String, delay: float) -> void:
	await wait_real(delay)
	if not is_inside_tree():
		return
	var img := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d:
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("%s/%03d_%s_%.1f.png" % [Game.event_shots, _evshot_n, key, delay])
	_evshot_n += 1


func _next_watch_match() -> void:
	Game.next_watch_pair(_winner_id())
	Game.goto("battle")


func _winner_id() -> String:
	if wins[0] > wins[1]:
		return f1.id
	if wins[1] > wins[0]:
		return f2.id
	return f1.id


# ---------------------------------------------------------------- 开场入场驱动

class IntroDriver:
	extends RefCounted
	var goal := Vector2.ZERO
	var gallop := false

	func _init(g: Vector2, run: bool) -> void:
		goal = g
		gallop = run

	func get_input(f, _dt: float) -> Dictionary:
		var to: Vector2 = goal - f.position
		var mv := Vector2.ZERO
		if absf(to.x) > (40.0 if f.mounted else 12.0):
			mv.x = signf(to.x)
		if absf(to.y) > 10.0:
			mv.y = signf(to.y) * 0.5
		var run: bool = gallop and absf(to.x) > 260.0
		return {"move": mv, "run": run}
