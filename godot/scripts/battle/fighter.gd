class_name Fighter
extends Node2D
## 武将：状态机 + 物理 + 程序化动画。
## 玩家与 AI 用同一套输入接口（controller.get_input），所以 AI 能用的招式玩家都能用。

enum S { IDLE, ATTACK, GUARD, DODGE, JUMP, HITSTUN, BLOCKSTUN, GUARDBREAK, KNOCKDOWN, DOWN, GETUP, CLASH, SCRIPTED, KO, VICTORY }

const GRAVITY := 2100.0
const PARRY_WINDOW := 0.16
const STAND_HW := 30.0
const MOUNT_HW := 78.0
const DODGE_COST := 22.0
const STAMINA_MAX := 100.0
const SHADER := preload("res://shaders/fighter.gdshader")

signal changed

# ---------------------------------------------------------------- 身份
var id := ""
var def: Dictionary
var side := 0                 # 0 左方，1 右方
var battle: Node
var opponent: Fighter
var ctrl                      # 控制器：PlayerInput / AiBrain
var theme_color := Color.WHITE

# ---------------------------------------------------------------- 姿态
var mounted := false
var can_unhorse := true
var unhorsed := false
var moves: Dictionary = {}

# ---------------------------------------------------------------- 数值
var max_hp := 1000.0
var hp := 1000.0
var stamina := STAMINA_MAX
var rage := 0.0
var power := 1.0
var defense := 1.0
var spd := 1.0

# ---------------------------------------------------------------- 物理（x 横向，z 纵深=屏幕 y，h 离地高度）
var vel := Vector2.ZERO
var h := 0.0
var vh := 0.0
var facing := 1
var run_held := false

# ---------------------------------------------------------------- 状态
var state: int = S.IDLE
var state_t := 0.0
var move: Dictionary = {}
var move_phase := 0           # 0 起手 1 出招 2 收招
var move_t := 0.0
var move_hits := 0            # 本招已判定命中次数
var move_landed := false      # 本招打中过（命中或被格挡）
var move_connected := false   # 本招打中肉身
var charge_t := 0.0
var charge_ratio := 0.0
var startup_len := 0.0
var active_len := 0.0
var recovery_len := 0.0
var buffered := ""
var buffer_t := 0.0
var air_move := false
var attack_serial := 0         # 每出一招 +1，AI 用来区分同一招的不同次出手

var guard_press_t := -10.0
var iframes := 0.0
var hitstun_t := 0.0
var freeze := 0.0
var juggle := 0
var last_hit_time := -10.0
var down_t := 0.0
var bounced := false
var dodge_dir := Vector2.ZERO
var land_lag := 0.0
var turn_t := 0.0
var perfect_dodge_used := false
var buffs := {}               # 名称 -> 剩余秒数
var counter_ready := 0.0      # 拆招后的反击窗口
var scripted_pose := ""
var victory_t := 0.0
var gallop_dust_t := 0.0
var step_snd_t := 0.0

# 连击（由对方被打中时累计）
var combo := 0
var combo_t := 0.0

var stats := {"hits": 0, "max_combo": 0, "parries": 0, "dodges": 0, "ults": 0, "dmg": 0.0, "clash_win": 0}

# ---------------------------------------------------------------- 画面
var vis: Node2D               # 纵深缩放
var body: Node2D              # 朝向翻转 + 挤压 + 倾斜 + 高度
var sprite: Sprite2D
var shadow: Node2D
var mat: ShaderMaterial
var base_scale := 0.4
var pose := ""
var anchor := Vector2.ZERO
var tip := Vector2.ZERO
var top_y := 0.0
var squash := Vector2.ONE
var squash_v := Vector2.ZERO
var squash_goal := Vector2.ONE
var tilt := 0.0
var tilt_v := 0.0
var tilt_goal := 0.0
var spin := 0.0
var jitter := 0.0
var flash := 0.0
var tint := Color.WHITE
var glow := 0.0
var glow_col := Color(1, 0.6, 0.2)
var walk_phase := 0.0
var anim_t := 0.0
var afterimage_t := 0.0
var trail_on := false
var bob := 0.0
var lift := 0.0               # 额外视觉抬升（马跳等）


func setup(p_id: String, p_side: int, p_battle: Node, p_mounted: bool) -> void:
	id = p_id
	def = Roster.get_def(id)
	side = p_side
	battle = p_battle
	theme_color = def["color"]
	max_hp = float(def["hp"])
	hp = max_hp
	power = Roster.power_mult(id)
	defense = Roster.defense_mult(id)
	spd = Roster.speed_mult(id)
	can_unhorse = Bank.has_stance(id, false)
	mounted = p_mounted and Bank.has_stance(id, true)
	if not Bank.has_stance(id, false):
		mounted = true
	facing = 1 if side == 0 else -1
	_build_visual()
	_apply_stance()


func _build_visual() -> void:
	shadow = Node2D.new()
	shadow.set_script(preload("res://scripts/battle/fx/shadow_blob.gd"))
	add_child(shadow)
	vis = Node2D.new()
	add_child(vis)
	body = Node2D.new()
	vis.add_child(body)
	sprite = Sprite2D.new()
	sprite.centered = false
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	sprite.material = mat
	body.add_child(sprite)


func _apply_stance() -> void:
	moves = Moves.moveset(def["weapon"], mounted)
	base_scale = Bank.base_scale(id, mounted)
	pose = ""
	set_pose("idle")
	shadow.set("radius", (MOUNT_HW + 18.0) if mounted else (STAND_HW + 10.0))


func half_width() -> float:
	return MOUNT_HW if mounted else STAND_HW


func body_height() -> float:
	return Bank.MOUNT_HEIGHT if mounted else Bank.STAND_HEIGHT


func is_alive() -> bool:
	return hp > 0.0 and state != S.KO


func is_airborne() -> bool:
	return h > 1.0


func center_global() -> Vector2:
	return global_position + Vector2(0, -h - body_height() * 0.5 * depth_scale())


func head_global() -> Vector2:
	return global_position + Vector2(0, -h - body_height() * 1.0 * depth_scale())


func depth_scale() -> float:
	var t := inverse_lerp(battle.Z_MIN, battle.Z_MAX, position.y)
	return lerp(0.86, 1.04, clamp(t, 0.0, 1.0))


# ---------------------------------------------------------------- 贴图与动画

func set_pose(p: String) -> void:
	if p == pose:
		return
	var info := Bank.pose(id, mounted, p)
	if info["tex"] == null:
		return
	var had := pose != ""
	pose = p
	sprite.texture = info["tex"]
	anchor = info["anchor"]
	tip = info["tip"]
	top_y = info["top"]
	sprite.offset = -anchor
	if had:
		# 换姿势时轻轻一弹，掩盖单帧切换的生硬
		squash_v += Vector2(2.2, -2.2)


## 兵器尖的世界坐标（按当前姿势）
func tip_global() -> Vector2:
	var local := (tip - anchor) * base_scale
	local.x *= facing * squash.x
	local.y *= squash.y
	local = local.rotated(body.rotation)
	return global_position + (Vector2(local.x, local.y - h - lift) * depth_scale())


func _spring(dt: float) -> void:
	# 挤压与倾斜都用弹簧，动作有回弹感
	var k := 260.0
	var c := 22.0
	squash_v += (squash_goal - squash) * k * dt - squash_v * c * dt
	squash += squash_v * dt
	tilt_v += (tilt_goal - tilt) * 220.0 * dt - tilt_v * 20.0 * dt
	tilt += tilt_v * dt


func _update_visual(dt: float, real_dt := -1.0) -> void:
	anim_t += dt
	_spring(dt)
	flash = move_toward(flash, 0.0, (real_dt if real_dt >= 0.0 else dt) * 9.0)
	jitter = move_toward(jitter, 0.0, dt * 30.0)
	var ds := depth_scale()
	vis.scale = Vector2(ds, ds)
	var jx := 0.0
	if jitter > 0.0:
		jx = sin(anim_t * 95.0) * jitter
	var breathe := 0.0
	if state == S.IDLE and vel.length() < 20.0 and not mounted:
		breathe = sin(anim_t * 3.4) * 0.016
	elif state == S.IDLE and mounted and vel.length() < 20.0:
		breathe = sin(anim_t * 2.6) * 0.012
	body.position = Vector2(jx, -h - lift - bob)
	body.scale = Vector2(facing * squash.x * (1.0 - breathe * 0.5), squash.y * (1.0 + breathe))
	body.rotation = deg_to_rad(tilt * facing) + spin
	sprite.scale = Vector2(base_scale, base_scale)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("light_dir", Vector2(-0.7 * float(facing), -0.7))
	var g := glow
	if rage >= 100.0 and state != S.KO:
		g = max(g, 0.55 + 0.25 * sin(anim_t * 6.0))
	mat.set_shader_parameter("glow_color", Color(glow_col.r * 1.6, glow_col.g * 1.6, glow_col.b * 1.6, g))
	mat.set_shader_parameter("glow_px", 5.0 / max(0.2, base_scale) * 0.35)
	shadow.set("height", h + lift)
	shadow.scale = Vector2(ds, ds)
	tint = tint.lerp(Color.WHITE, min(1.0, dt * 5.0))
	# 残影
	if trail_on:
		afterimage_t -= dt
		if afterimage_t <= 0.0:
			afterimage_t = 0.032
			battle.vfx.afterimage(self, theme_color)


# ---------------------------------------------------------------- 回放：记录 / 还原画面状态

func snapshot() -> Dictionary:
	return {
		"p": position, "h": h, "f": facing, "m": mounted, "pose": pose,
		"bp": body.position, "bs": body.scale, "br": body.rotation, "vs": vis.scale.x, "ss": base_scale,
		"fl": flash, "ti": tint, "gl": glow, "gc": glow_col, "rg": rage >= 100.0, "tr": trail_on,
		"lift": lift,
	}


func apply_snapshot(sn: Dictionary) -> void:
	position = sn["p"]
	h = sn["h"]
	facing = sn["f"]
	lift = sn["lift"]
	if sn["m"] != mounted:
		mounted = sn["m"]
		pose = ""
	if sn["pose"] != pose:
		var info := Bank.pose(id, mounted, sn["pose"])
		if info["tex"]:
			pose = sn["pose"]
			sprite.texture = info["tex"]
			anchor = info["anchor"]
			tip = info["tip"]
			sprite.offset = -anchor
	base_scale = sn["ss"]
	vis.scale = Vector2(sn["vs"], sn["vs"])
	body.position = sn["bp"]
	body.scale = sn["bs"]
	body.rotation = sn["br"]
	sprite.scale = Vector2(base_scale, base_scale)
	mat.set_shader_parameter("flash", sn["fl"])
	mat.set_shader_parameter("tint", sn["ti"])
	mat.set_shader_parameter("light_dir", Vector2(-0.7 * float(facing), -0.7))
	var g: float = sn["gl"]
	if sn["rg"]:
		g = max(g, 0.6)
	var gc: Color = sn["gc"]
	mat.set_shader_parameter("glow_color", Color(gc.r * 1.6, gc.g * 1.6, gc.b * 1.6, g))
	shadow.set("height", h + lift)
	shadow.scale = vis.scale
	if sn["tr"]:
		afterimage_t -= get_process_delta_time()
		if afterimage_t <= 0.0:
			afterimage_t = 0.032
			battle.vfx.afterimage(self, theme_color)


# ---------------------------------------------------------------- 主循环

func step(dt: float) -> void:
	if freeze > 0.0:
		freeze -= dt
		_update_visual(dt * 0.25, dt)
		return
	state_t += dt
	_tick_timers(dt)
	var inp: Dictionary = {}
	if ctrl != null and controllable():
		inp = ctrl.get_input(self, dt)
		if inp.get("guard_pressed", false):
			_press_guard()
	match state:
		S.IDLE:
			_st_idle(dt, inp)
		S.ATTACK:
			_st_attack(dt, inp)
		S.GUARD:
			_st_guard(dt, inp)
		S.DODGE:
			_st_dodge(dt, inp)
		S.JUMP:
			_st_jump(dt, inp)
		S.HITSTUN, S.BLOCKSTUN, S.GUARDBREAK:
			_st_stun(dt, inp)
		S.KNOCKDOWN:
			_st_knockdown(dt)
		S.DOWN:
			_st_down(dt)
		S.GETUP:
			_st_getup(dt)
		S.CLASH, S.SCRIPTED:
			pass
		S.KO:
			_st_ko(dt)
		S.VICTORY:
			_st_victory(dt)
	if state != S.SCRIPTED and state != S.CLASH:
		_integrate(dt)
	_update_visual(dt)


func controllable() -> bool:
	return state in [S.IDLE, S.ATTACK, S.GUARD, S.DODGE, S.JUMP, S.HITSTUN, S.BLOCKSTUN, S.GUARDBREAK]


func _tick_timers(dt: float) -> void:
	iframes = max(0.0, iframes - dt)
	counter_ready = max(0.0, counter_ready - dt)
	buffer_t = max(0.0, buffer_t - dt)
	if buffer_t <= 0.0:
		buffered = ""
	combo_t -= dt
	if combo_t <= 0.0 and combo > 0:
		combo = 0
	var regen := 18.0 if state in [S.IDLE, S.JUMP] else (4.0 if state == S.GUARD else 8.0)
	if run_held and vel.length() > 200.0:
		regen = 2.0 if not mounted else 10.0
	stamina = min(STAMINA_MAX, stamina + regen * dt)
	for b in buffs.keys():
		buffs[b] -= dt
		if buffs[b] <= 0.0:
			buffs.erase(b)
			_on_buff_end(b)
	if buffs.has("berserk"):
		glow = max(glow, 0.8)
		glow_col = Color(1.0, 0.25, 0.1)
	elif glow > 0.0 and rage < 100.0:
		glow = move_toward(glow, 0.0, dt * 2.0)
	if rage >= 100.0:
		glow_col = theme_color


func _on_buff_end(b: String) -> void:
	if b == "berserk":
		glow = 0.0
		battle.narrate("%s的狂气渐渐平息。" % def["name"], 0)


# ---------------------------------------------------------------- 中立：走位 / 出招

func _st_idle(dt: float, inp: Dictionary) -> void:
	if land_lag > 0.0:
		land_lag -= dt
		_move_physics(dt, Vector2.ZERO, false)
		return
	if _try_actions(inp):
		return
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	run_held = inp.get("run", false)
	_move_physics(dt, mv, run_held)
	_auto_face(mv)
	_animate_locomotion(dt)
	if inp.get("guard", false):
		_enter_guard(inp.get("guard_pressed", false))


func _try_actions(inp: Dictionary) -> bool:
	if inp.is_empty():
		return false
	if inp.get("ult", false) and rage >= 100.0 and battle.can_ult(self):
		battle.start_ult(self)
		return true
	if inp.get("dodge", false) and not mounted and stamina >= DODGE_COST * 0.5:
		_start_dodge(inp.get("move", Vector2.ZERO))
		return true
	if inp.get("jump", false):
		_start_jump(inp.get("move", Vector2.ZERO))
		return true
	if inp.get("heavy", false):
		_start_attack(_pick_heavy())
		return true
	if inp.get("light", false):
		_start_attack(_pick_light())
		return true
	return false


func _pick_light() -> String:
	if mounted:
		if abs(vel.x) > 300.0 and sign(vel.x) == facing and moves.has("charge"):
			return "charge"
		if def["weapon"] == "bow" and _dist_to_opp() < 170.0:
			return "bash"
		return "l1"
	if run_held and vel.length() > 300.0 and moves.has("run"):
		return "run"
	if def["weapon"] == "bow" and _dist_to_opp() < 200.0 and abs(_dz_to_opp()) < 70.0:
		return "bash"
	return "l1"


func _pick_heavy() -> String:
	if mounted and abs(vel.x) > 300.0 and sign(vel.x) == facing and moves.has("charge"):
		return "charge"
	return "heavy"


func _dist_to_opp() -> float:
	if opponent == null:
		return 9999.0
	return abs(opponent.position.x - position.x)


func _dz_to_opp() -> float:
	if opponent == null:
		return 0.0
	return opponent.position.y - position.y


func _move_physics(dt: float, mv: Vector2, run: bool) -> void:
	if mounted:
		_mount_physics(dt, mv, run)
		return
	var guard_slow := 0.38 if state == S.GUARD else 1.0
	var speed := 230.0 * spd * guard_slow
	if run and state == S.IDLE:
		speed *= 1.75
		if stamina < 5.0:
			speed *= 0.7
	if buffs.has("berserk"):
		speed *= 1.12
	var target := Vector2(mv.x * speed, mv.y * speed * 0.62)
	vel = vel.move_toward(target, 2600.0 * dt)


func _mount_physics(dt: float, mv: Vector2, run: bool) -> void:
	# 马有惯性：加速慢、刹车慢，掉头要先减速
	var max_spd := 250.0 * spd
	if run:
		max_spd = 560.0 * spd
	var want_x := mv.x * max_spd
	var accel := 640.0 if run else 760.0
	if sign(want_x) != sign(vel.x) and abs(vel.x) > 40.0:
		accel = 1100.0  # 勒马
	if abs(mv.x) < 0.1:
		accel = 820.0
	vel.x = move_toward(vel.x, want_x, accel * dt)
	vel.y = move_toward(vel.y, mv.y * 150.0, 600.0 * dt)
	if run and abs(vel.x) > 260.0:
		gallop_dust_t -= dt
		if gallop_dust_t <= 0.0:
			gallop_dust_t = 0.06
			battle.vfx.dust(global_position + Vector2(-facing * 50.0, 0), 0.5, Color(0.72, 0.58, 0.4, 0.55))


func _auto_face(mv: Vector2) -> void:
	if opponent == null:
		return
	var to_opp: int = 1 if opponent.position.x >= position.x else -1
	if mounted:
		if abs(vel.x) > 110.0:
			_set_facing(int(sign(vel.x)))
		elif abs(opponent.position.x - position.x) > 20.0:
			_set_facing(to_opp)
		return
	if run_held and abs(mv.x) > 0.3:
		_set_facing(int(sign(mv.x)))
	elif abs(opponent.position.x - position.x) > 8.0:
		_set_facing(to_opp)


func _set_facing(f: int) -> void:
	if f == 0 or f == facing:
		return
	facing = f
	squash = Vector2(0.82, 1.06)
	turn_t = 0.12


func _animate_locomotion(dt: float) -> void:
	var sp := vel.length()
	tilt_goal = 0.0
	squash_goal = Vector2.ONE
	if mounted:
		if sp > 30.0:
			var rate := 0.55 + sp / 260.0
			walk_phase += dt * rate * 6.5
			var gallop := absf(vel.x) > 330.0
			var cyc := int(walk_phase) % (3 if gallop else 2)
			var seq := ["walk_l", "walk_r", "jump"] if gallop else ["walk_l", "walk_r"]
			set_pose(seq[cyc])
			bob = abs(sin(walk_phase * PI)) * (9.0 if gallop else 4.0)
			tilt_goal = clamp(vel.x * facing / 90.0, -3.0, 6.0) * (1.0 if gallop else 0.4)
			step_snd_t -= dt
			if step_snd_t <= 0.0:
				step_snd_t = 0.42 / rate
				Sfx.play("horse_step", -10.0 if gallop else -15.0, 1.0, 0.1)
		else:
			set_pose("idle")
			bob = move_toward(bob, 0.0, dt * 30.0)
		return
	if sp > 25.0:
		var rate := 0.7 + sp / 300.0
		walk_phase += dt * rate * 7.0
		set_pose("walk_l" if int(walk_phase) % 2 == 0 else "walk_r")
		bob = abs(sin(walk_phase * PI)) * 4.5
		var lean := vel.x * facing / 240.0
		tilt_goal = clamp(lean * 4.0, -5.0, 6.0)
		step_snd_t -= dt
		if step_snd_t <= 0.0:
			step_snd_t = 0.34 / rate
			Sfx.play("step", -16.0, 1.0, 0.12)
	else:
		set_pose("idle")
		bob = move_toward(bob, 0.0, dt * 25.0)


# ---------------------------------------------------------------- 攻击

func _start_attack(mid: String) -> void:
	if not moves.has(mid):
		mid = "l1"
	move = moves[mid]
	attack_serial += 1
	state = S.ATTACK
	state_t = 0.0
	move_phase = 0
	move_t = 0.0
	move_hits = 0
	move_landed = false
	move_connected = false
	charge_t = 0.0
	charge_ratio = 0.0
	buffered = ""
	air_move = move["air"] and is_airborne()
	perfect_dodge_used = false
	var sm := spd * (1.12 if buffs.has("berserk") else 1.0)
	startup_len = move["startup"] / sm
	active_len = move["active"]
	recovery_len = move["recovery"] / sm
	if counter_ready > 0.0:
		startup_len *= 0.6
	_face_target_for_attack()
	set_pose(move["pose_startup"])
	tilt_goal = move["tilt_startup"]
	squash_goal = Vector2(0.96, 1.04)
	if mounted and not move["run"]:
		vel.x *= 0.6
	elif not move["run"]:
		vel *= 0.3
	if move["armor"]:
		glow = max(glow, 0.6)
		glow_col = Color(1.0, 0.8, 0.3)
	if not move["charge"].is_empty():
		Sfx.play("blade_draw", -6.0)
	battle.on_move_start(self, move)


func _face_target_for_attack() -> void:
	if opponent == null or (mounted and abs(vel.x) > 200.0):
		return
	var dx := opponent.position.x - position.x
	if abs(dx) > 4.0:
		var f: int = 1 if dx > 0 else -1
		if f != facing:
			facing = f


func _st_attack(dt: float, inp: Dictionary) -> void:
	move_t += dt
	# 输入缓冲：收招期间按键可以接下一招
	if not inp.is_empty():
		if inp.get("light", false):
			buffered = "light"
			buffer_t = 0.22
		elif inp.get("heavy", false):
			buffered = "heavy"
			buffer_t = 0.22
		if inp.get("ult", false) and rage >= 100.0 and battle.can_ult(self) and move_phase == 2 and move_connected:
			battle.start_ult(self)
			return
	match move_phase:
		0:
			_attack_startup(dt, inp)
		1:
			_attack_active(dt)
		2:
			_attack_recovery(dt, inp)
	# 出招过程中可能被拆招/拼刀/打断，状态已经变了
	if state != S.ATTACK or move.is_empty():
		return
	if air_move:
		vh -= GRAVITY * dt
		h += vh * dt
		if h <= 0.0:
			h = 0.0
			vh = 0.0
			air_move = false
			_on_land(false)
			if move_phase < 2:
				move_phase = 2
				move_t = 0.0
	elif mounted:
		vel.x = move_toward(vel.x, 0.0, (240.0 if move["run"] else 500.0) * dt)
		vel.y = move_toward(vel.y, 0.0, 600.0 * dt)
	else:
		vel = vel.move_toward(Vector2.ZERO, 1500.0 * dt)


func _attack_startup(dt: float, inp: Dictionary) -> void:
	var ch: Dictionary = move["charge"]
	var holding: bool = inp.get("heavy_held", false)
	if not ch.is_empty() and holding and move_t >= startup_len * 0.6 and charge_t < ch["max"]:
		# 蓄力：停在起手，抖动、发光
		charge_t += dt
		charge_ratio = clamp(charge_t / ch["max"], 0.0, 1.0)
		jitter = 1.5 + charge_ratio * 2.5
		glow = max(glow, 0.3 + charge_ratio * 0.7)
		glow_col = theme_color
		squash_goal = Vector2(0.94 - charge_ratio * 0.04, 1.06 + charge_ratio * 0.04)
		tilt_goal = move["tilt_startup"] * (1.0 + charge_ratio * 0.5)
		if int(charge_t * 12.0) != int((charge_t - dt) * 12.0):
			battle.vfx.charge_spark(self, charge_ratio)
		move_t = startup_len * 0.6
		if charge_ratio >= 1.0 and not move.get("_full_announced", false):
			move["_full_announced"] = true
			flash = 0.6
			Sfx.play("charge_full", -4.0)
		return
	if move["lunge_startup"] > 0.0:
		position.x += facing * move["lunge_startup"] * dt / startup_len
	if move_t >= startup_len:
		move.erase("_full_announced")
		_enter_active()


func _enter_active() -> void:
	move_phase = 1
	move_t = 0.0
	# 重招出手时留下起手姿势的残影，单帧动作也有挥动感
	if move["kind"] == "melee" and (float(move["dmg"]) >= 60.0 or move["run"] or charge_ratio > 0.3):
		battle.vfx.afterimage(self, theme_color, 0.18, 0.45)
	set_pose(move["pose_active"])
	tilt_goal = move["tilt_active"]
	squash = Vector2(1.14, 0.9)
	squash_goal = Vector2.ONE
	var lunge: float = move["lunge"]
	if lunge > 0.0:
		var spd_x: float = lunge / max(0.05, active_len) * 1.6
		if mounted:
			vel.x = facing * max(abs(vel.x), spd_x * 0.5) if move["run"] else facing * spd_x * 0.4
		else:
			vel.x = facing * spd_x
			if move["run"]:
				vel.x = facing * max(abs(vel.x), spd_x)
	if air_move:
		vh = min(vh, -300.0)
		vel.x = facing * max(abs(vel.x), 240.0)
	if move["kind"] == "projectile":
		battle.spawn_projectile(self, move, charge_ratio)
	else:
		battle.vfx.swing(self, move, charge_ratio)
	Sfx.play(move["sfx_swing"], -3.0 + charge_ratio * 3.0, 1.05 - charge_ratio * 0.15)
	battle.on_move_active(self, move)


func _attack_active(dt: float) -> void:
	if state != S.ATTACK:
		return
	var hits_total: int = move["hits"]
	if move["kind"] == "melee" and move_hits < hits_total:
		var slot := active_len * float(move_hits) / float(hits_total)
		if move_t >= slot:
			var landed: bool = battle.try_hit(self, move, move_hits)
			if state != S.ATTACK or move.is_empty():
				return
			if landed:
				move_landed = true
			if landed or hits_total > 1:
				move_hits += 1
	if move["vfx"] == "spin":
		spin += dt * 34.0 * facing
	if move_t >= active_len:
		move_phase = 2
		move_t = 0.0
		spin = 0.0
		# 落空且对手正在闪身：算一次漂亮的闪避
		if not move_landed and move["kind"] == "melee" and opponent and opponent.state == S.DODGE and not perfect_dodge_used:
			var reach_k: float = float(move["reach"]) + 160.0
			if absf(opponent.position.x - position.x) < reach_k:
				perfect_dodge_used = true
				battle._perfect_dodge(opponent, self)


func _attack_recovery(dt: float, inp: Dictionary) -> void:
	if move_t >= recovery_len * 0.45:
		if pose != "idle" and not mounted:
			set_pose("idle")
		elif mounted and pose != "idle":
			set_pose("idle")
		tilt_goal = 0.0
	var cancel_ok: bool = move_t <= move["cancel"] + recovery_len * 0.35
	if buffered != "" and cancel_ok:
		var nxt := ""
		if buffered == "light" and move["next"] != "" and (move_landed or move["kind"] == "projectile"):
			nxt = move["next"]
		elif buffered == "heavy" and move["heavy_next"] != "" and move_landed:
			nxt = move["heavy_next"]
		elif buffered == "light" and move["next"] != "" and move_t > recovery_len * 0.55:
			nxt = move["next"]
		if nxt != "":
			buffered = ""
			_start_attack(nxt)
			return
	if move_t >= recovery_len:
		_to_idle()


func _to_idle() -> void:
	state = S.IDLE
	state_t = 0.0
	spin = 0.0
	tilt_goal = 0.0
	squash_goal = Vector2.ONE
	if glow > 0.0 and not buffs.has("berserk") and rage < 100.0:
		glow = 0.0
	set_pose("idle")


# ---------------------------------------------------------------- 格挡 / 闪避 / 跳跃

var _last_guard_tap := -10.0


## 拆招判定窗口从按下格挡开始；连续乱按不会刷新窗口（防止狂按必拆）
func _press_guard() -> void:
	var now: float = battle.game_time
	if now - _last_guard_tap >= 0.38:
		guard_press_t = now
	_last_guard_tap = now


func _enter_guard(pressed: bool) -> void:
	state = S.GUARD
	state_t = 0.0
	if pressed:
		_press_guard()
	set_pose("windup")
	tilt_goal = -6.0
	squash_goal = Vector2(0.97, 1.0)


func _st_guard(dt: float, inp: Dictionary) -> void:
	if not inp.get("guard", false) and state_t > 0.06:
		_to_idle()
		return
	if inp.get("light", false) or inp.get("heavy", false):
		if counter_ready > 0.0 or state_t > 0.1:
			_to_idle()
			_try_actions(inp)
			return
	if inp.get("dodge", false) and not mounted and stamina >= DODGE_COST:
		_start_dodge(inp.get("move", Vector2.ZERO))
		return
	_move_physics(dt, inp.get("move", Vector2.ZERO) * 0.5, false)
	_auto_face(Vector2.ZERO)
	battle.vfx.guard_glint(self)


func _start_dodge(mv: Vector2) -> void:
	var dir := mv
	if dir.length() < 0.2:
		dir = Vector2(-facing, 0)
	dir = dir.normalized()
	dodge_dir = dir
	stamina = max(0.0, stamina - DODGE_COST)
	state = S.DODGE
	state_t = 0.0
	iframes = 0.24
	perfect_dodge_used = false
	vel = Vector2(dir.x * 720.0, dir.y * 430.0) * spd
	vh = 260.0
	set_pose("jump")
	tilt_goal = -12.0 if sign(dir.x) == -facing else 10.0
	squash = Vector2(1.15, 0.86)
	trail_on = true
	Sfx.play("dash", -5.0)
	battle.vfx.dust(global_position, 0.7)


func _st_dodge(dt: float, _inp: Dictionary) -> void:
	vh -= GRAVITY * 1.2 * dt
	h = max(0.0, h + vh * dt)
	vel = vel.move_toward(Vector2.ZERO, 2200.0 * dt)
	if state_t >= 0.3:
		trail_on = false
		h = 0.0
		vh = 0.0
		_to_idle()
		land_lag = 0.06
		_on_land(false)


func _start_jump(mv: Vector2) -> void:
	state = S.JUMP
	state_t = 0.0
	vh = 700.0 if not mounted else 560.0
	vel = Vector2(mv.x * 260.0 * spd, mv.y * 120.0)
	if mounted:
		vel.x = vel.x + (sign(vel.x) * 120.0 if abs(vel.x) > 10 else facing * 140.0)
	set_pose("jump")
	squash = Vector2(0.84, 1.18)
	tilt_goal = 6.0
	Sfx.play("jump", -6.0)
	battle.vfx.dust(global_position, 0.6)


func _st_jump(dt: float, inp: Dictionary) -> void:
	if not inp.is_empty() and not mounted:
		if inp.get("light", false) or inp.get("heavy", false):
			if moves.has("air") and h > 30.0:
				_start_attack("air")
				return
		var mv: Vector2 = inp.get("move", Vector2.ZERO)
		vel.x = move_toward(vel.x, mv.x * 260.0 * spd, 900.0 * dt)
	vh -= GRAVITY * dt
	h += vh * dt
	tilt_goal = clamp(-vh / 120.0, -8.0, 8.0)
	if h <= 0.0:
		h = 0.0
		vh = 0.0
		_to_idle()
		land_lag = 0.08
		_on_land(true)


func _on_land(heavy: bool) -> void:
	squash = Vector2(1.2, 0.82)
	battle.vfx.dust(global_position, 0.9 if heavy else 0.6)
	Sfx.play("land", -8.0 if heavy else -12.0)


# ---------------------------------------------------------------- 受击

## 由 battle 计算几何命中后调用。返回 "hit" "block" "parry" "armor" "evade"
func classify_incoming(attacker: Fighter, mv: Dictionary, from_dir: int) -> String:
	if not is_alive() or state in [S.SCRIPTED, S.DOWN, S.GETUP, S.KO]:
		return "none"
	if iframes > 0.0:
		return "evade"
	var front := from_dir == facing  # 攻击来自我面对的方向
	if (state == S.GUARD or state == S.BLOCKSTUN) and front:
		if battle.game_time - guard_press_t <= PARRY_WINDOW:
			return "parry"
		return "block"
	if state == S.ATTACK and move.get("armor", false) and move_phase <= 1:
		return "armor"
	if buffs.has("berserk") and state != S.GUARDBREAK:
		return "armor"
	if state == S.CLASH:
		return "none"
	return "hit"


func take_damage(amount: float, attacker: Fighter, allow_ko: bool = true) -> float:
	var dmg := amount
	if not allow_ko:
		dmg = min(dmg, hp - 1.0)
	dmg = max(0.0, dmg)
	hp = max(0.0, hp - dmg)
	last_hit_time = battle.game_time
	gain_rage(dmg / max_hp * 92.0)
	if attacker:
		attacker.gain_rage(dmg / max_hp * 66.0)
		attacker.stats["dmg"] += dmg
	changed.emit()
	return dmg


func gain_rage(v: float) -> void:
	if buffs.has("berserk"):
		v *= 0.3
	var before := rage
	rage = clamp(rage + v, 0.0, 100.0)
	if before < 100.0 and rage >= 100.0:
		battle.on_rage_full(self)
	changed.emit()


## 被打中：硬直、击退、浮空
func apply_hit_reaction(attacker: Fighter, mv: Dictionary, hitstun: float, kb: float, launch: float) -> void:
	var dir: int = 1 if position.x >= attacker.position.x else -1
	if attacker.state == S.SCRIPTED:
		dir = attacker.facing
	if mounted:
		kb *= 0.55
		launch = 0.0
		hitstun *= 0.85
	flash = 0.62
	jitter = 6.0
	tint = Color(1.0, 0.8, 0.76)
	trail_on = false
	spin = 0.0
	if state == S.ATTACK and move_phase == 0:
		move = {}
	if launch > 0.0 and juggle < 3:
		state = S.KNOCKDOWN
		state_t = 0.0
		vh = launch * (1.0 - juggle * 0.22)
		h = max(h, 2.0)
		vel = Vector2(dir * kb * 0.6, 0)
		bounced = false
		juggle += 1
		set_pose("hurt")
		tilt_goal = -25.0
	elif is_airborne() and state == S.KNOCKDOWN:
		# 空中追击：再弹一下
		vh = max(vh, 260.0)
		vel.x = dir * kb * 0.5
		juggle += 1
	else:
		state = S.HITSTUN
		state_t = 0.0
		hitstun_t = hitstun
		vel = Vector2(dir * kb, 0)
		set_pose("hurt")
		tilt_goal = -12.0
		squash = Vector2(0.86, 1.1)
		if is_airborne() and state != S.KNOCKDOWN:
			state = S.KNOCKDOWN
			vh = 120.0
	if facing == dir and not mounted:
		# 从背后挨打，转过身来
		facing = -dir


func apply_block(attacker: Fighter, mv: Dictionary, push: float) -> void:
	state = S.BLOCKSTUN
	state_t = 0.0
	hitstun_t = 0.16 + float(mv.get("guard_dmg", 10.0)) / 260.0
	var dir: int = 1 if position.x >= attacker.position.x else -1
	vel = Vector2(dir * push, 0)
	jitter = 3.0
	set_pose("windup")
	tilt_goal = -10.0
	squash = Vector2(0.92, 1.05)


func apply_guard_break(attacker: Fighter) -> void:
	state = S.GUARDBREAK
	state_t = 0.0
	hitstun_t = 0.95
	stamina = 0.0
	var dir: int = 1 if position.x >= attacker.position.x else -1
	vel = Vector2(dir * 280.0, 0)
	set_pose("hurt")
	jitter = 8.0
	tilt_goal = -18.0
	flash = 0.8


func apply_parried(defender: Fighter) -> void:
	# 被拆招：兵器被荡开，大硬直
	state = S.HITSTUN
	state_t = 0.0
	hitstun_t = 0.62
	var dir: int = 1 if position.x >= defender.position.x else -1
	vel = Vector2(dir * 240.0, 0)
	set_pose("hurt")
	tilt_goal = -20.0
	jitter = 5.0
	move = {}
	trail_on = false
	spin = 0.0


func _st_stun(dt: float, inp: Dictionary) -> void:
	if state == S.GUARDBREAK:
		tilt_goal = -14.0 + sin(state_t * 14.0) * 8.0
	if mounted:
		vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
	else:
		vel = vel.move_toward(Vector2.ZERO, 1500.0 * dt)
	if state_t >= hitstun_t:
		if state == S.BLOCKSTUN and inp.get("guard", false):
			state = S.GUARD
			state_t = 0.1
			return
		_to_idle()


func _st_knockdown(dt: float) -> void:
	vh -= GRAVITY * dt
	h += vh * dt
	tilt_goal = -40.0 - min(60.0, state_t * 140.0)
	vel.x = move_toward(vel.x, 0.0, 200.0 * dt)
	if h <= 0.0:
		h = 0.0
		if not bounced and vh < -420.0:
			bounced = true
			vh = -vh * 0.32
			h = 1.0
			battle.vfx.dust(global_position, 1.1)
			battle.cam.shake(0.18)
			Sfx.play("land", -2.0, 0.8)
			return
		vh = 0.0
		_go_down(0.7)


func _go_down(t: float) -> void:
	state = S.DOWN
	state_t = 0.0
	down_t = t
	h = 0.0
	vh = 0.0
	tilt = 0.0
	tilt_goal = 0.0
	tilt_v = 0.0
	set_pose("down")
	squash = Vector2(1.15, 0.85)
	vel.x *= 0.3
	juggle = 0
	iframes = t + 0.5
	battle.vfx.dust(global_position, 1.2)
	Sfx.play("thud", -2.0)
	battle.on_fighter_down(self)


func _st_down(dt: float) -> void:
	vel = vel.move_toward(Vector2.ZERO, 900.0 * dt)
	if not is_alive():
		return
	if state_t >= down_t:
		state = S.GETUP
		state_t = 0.0
		iframes = 0.45
		set_pose("jump")
		squash = Vector2(0.85, 1.15)
		vh = 0.0


func _st_getup(_dt: float) -> void:
	if state_t >= 0.28:
		_to_idle()


func _st_ko(dt: float) -> void:
	if h > 0.0 or vh != 0.0:
		vh -= GRAVITY * dt
		h += vh * dt
		tilt_goal = -60.0
		if h <= 0.0:
			h = 0.0
			vh = 0.0
			tilt = 0.0
			tilt_goal = 0.0
			tilt_v = 0.0
			set_pose("down")
			squash = Vector2(1.2, 0.8)
			battle.vfx.dust(global_position, 1.4)
			Sfx.play("thud", 0.0, 0.7)
	vel = vel.move_toward(Vector2.ZERO, 500.0 * dt)
	position += Vector2(vel.x, vel.y) * dt


func _st_victory(dt: float) -> void:
	victory_t += dt
	vel = vel.move_toward(Vector2.ZERO, 800.0 * dt)
	if not mounted:
		var cyc := fmod(victory_t, 1.1)
		if cyc < 0.42:
			h = sin(cyc / 0.42 * PI) * 46.0
			set_pose("jump")
		else:
			h = 0.0
			set_pose("idle")
	else:
		var cyc := fmod(victory_t, 1.4)
		set_pose("jump" if cyc < 0.5 else "idle")
		lift = sin(clamp(cyc / 0.5, 0.0, 1.0) * PI) * 24.0


func enter_ko(attacker: Fighter, launch: float) -> void:
	state = S.KO
	state_t = 0.0
	trail_on = false
	spin = 0.0
	glow = 0.0
	set_pose("hurt")
	var dir: int = 1 if position.x >= attacker.position.x else -1
	vel = Vector2(dir * 360.0, 0)
	vh = max(launch, 420.0) if not mounted else 0.0
	h = max(h, 1.0) if not mounted else 0.0
	if mounted:
		set_pose("down")


func enter_victory() -> void:
	state = S.VICTORY
	state_t = 0.0
	victory_t = 0.0
	trail_on = false
	spin = 0.0
	tilt_goal = 0.0
	h = 0.0
	if opponent:
		_set_facing(1 if opponent.position.x > position.x else -1)


func set_scripted(on: bool) -> void:
	if on:
		state = S.SCRIPTED
		state_t = 0.0
		move = {}
		trail_on = false
		vel = Vector2.ZERO
	else:
		spin = 0.0
		lift = 0.0
		tilt_goal = 0.0
		if hp > 0.0:
			_to_idle()


# ---------------------------------------------------------------- 落马

func unhorse() -> void:
	mounted = false
	unhorsed = true
	_apply_stance()


func remount_none() -> void:
	pass


# ---------------------------------------------------------------- 物理积分与边界

func _integrate(dt: float) -> void:
	if state == S.KO:
		return
	position.x += vel.x * dt
	position.y += vel.y * dt
	if not battle.bounds_on:
		return
	var b: Vector2 = battle.arena_bounds(position.y)
	var hw := half_width()
	if position.x < b.x + hw:
		position.x = b.x + hw
		if vel.x < -260.0 and state in [S.HITSTUN, S.KNOCKDOWN]:
			vel.x = -vel.x * 0.35
			battle.vfx.dust(global_position, 0.9)
			battle.cam.shake(0.12)
		else:
			vel.x = max(vel.x, 0.0)
	elif position.x > b.y - hw:
		position.x = b.y - hw
		if vel.x > 260.0 and state in [S.HITSTUN, S.KNOCKDOWN]:
			vel.x = -vel.x * 0.35
			battle.vfx.dust(global_position, 0.9)
			battle.cam.shake(0.12)
		else:
			vel.x = min(vel.x, 0.0)
	position.y = clamp(position.y, battle.Z_MIN, battle.Z_MAX)


## 被对手推挤（battle 调用）
func push(dx: float) -> void:
	position.x += dx
