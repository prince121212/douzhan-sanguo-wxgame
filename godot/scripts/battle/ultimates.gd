class_name Ultimates
extends RefCounted
## 九位武将的绝技演出。每个都是一段脚本：切入立绘 → 运镜 → 连段 → 收尾一击。
## 对手在切入结束后有一瞬反应时间，闪得开就是"险避绝技"的名场面。

const WaveSlash := preload("res://scripts/battle/fx/wave_slash.gd")
const Reticle := preload("res://scripts/battle/fx/reticle.gd")
const GhostRider := preload("res://scripts/battle/fx/ghost_rider.gd")
const ArrowFx := preload("res://scripts/battle/fx/arrow.gd")
const SlashArc := preload("res://scripts/battle/fx/slash_arc.gd")
const ThrustStreak := preload("res://scripts/battle/fx/thrust_streak.gd")


static func run(b: Node, c: Fighter, t: Fighter) -> void:
	await _prologue(b, c, t)
	if not b.is_inside_tree():
		return
	var evaded := await _react(b, c, t)
	if evaded:
		b.ev("ult_whiff")
		await _whiff(b, c, t)
	else:
		match c.def["ult"]["id"]:
			"qijin":
				await _qijin(b, c, t)
			"tuodao":
				await _tuodao(b, c, t)
			"nuhou":
				await _nuhou(b, c, t)
			"tieqi":
				await _tieqi(b, c, t)
			"luoyi":
				await _luoyi(b, c, t)
			"eli":
				await _eli(b, c, t)
			"chuanyang":
				await _chuanyang(b, c, t)
			"wushuang":
				await _wushuang(b, c, t)
			"yicheng":
				await _yicheng(b, c, t)
			_:
				await _qijin(b, c, t)
	await _epilogue(b, c, t)


# ---------------------------------------------------------------- 通用

static func _prologue(b: Node, c: Fighter, t: Fighter) -> void:
	c.set_scripted(true)
	if t.state != Fighter.S.KO:
		t.set_scripted(true)
		t.set_pose("idle")
	c.set_pose("windup")
	c.glow = 1.0
	c.glow_col = c.theme_color
	c.flash = 0.8
	b.cine.set_letterbox(true)
	b.cam.track(c, 2.25, 1.4, Vector2(0, -90), 9.0)
	b.vfx.ring(c.center_global(), 320.0, c.theme_color, false, 22.0, 0.6)
	b.vfx.ring(c.global_position, 260.0, c.theme_color, true, 18.0, 0.6)
	b.post.flash(c.theme_color.lerp(Color.WHITE, 0.5), 0.3)
	b.post.blur(0.6, Vector2(0.5, 0.5))
	Sfx.play("ult_cutin", 0.0)
	Sfx.play("ult_whoosh", 0.0)
	Sfx.play("drum_big", 2.0)
	Sfx.music_duck(-14.0, 0.2)
	b.narrate("%s使出绝技「%s」！" % [c.def["name"], c.def["ult"]["name"]], 1)
	b.arena.cheer(c.side, 1.0)
	b.slowmo(0.02, 1.15)
	b.cine.show_cutin(c, 1.1)
	await b.wait_real(1.12)
	Sfx.music_duck(-4.0, 0.6)


## 切入后的反应窗口：对手能否闪开第一击
static func _react(b: Node, c: Fighter, t: Fighter) -> bool:
	if not t.is_alive() or t.mounted:
		return false
	var dodged := false
	if t.ctrl is PlayerInput:
		b.slowmo(0.35, 0.4)
		b.vfx.stamp(t.head_global() + Vector2(0, -40), "闪!", Color(0.7, 1.0, 0.8), 54)
		var end: float = b.real_time + 0.36
		b.prompt_dodge_until = end + 0.25   # 触屏「闪」按钮高亮
		while b.real_time < end:
			await b.get_tree().process_frame
			if Input.is_action_just_pressed("p1_dodge"):
				dodged = true
				break
	else:
		var skill: float = float(t.def["ai"]["dodge"]) * 0.28
		if b.player_side < 0:
			skill *= 0.9
		dodged = randf() < skill and t.stamina > Fighter.DODGE_COST
	return dodged


static func _whiff(b: Node, c: Fighter, t: Fighter) -> void:
	var dir := -1.0 if c.position.x < t.position.x else 1.0
	t.set_scripted(false)
	t.trail_on = true
	t.iframes = 0.6
	t.set_scripted(true)
	t.set_pose("jump")
	t.trail_on = true
	await _dash(b, t, t.position + Vector2(-dir * 220.0, 0), 0.18, 50.0)
	t.trail_on = false
	t.set_pose("idle")
	b.vfx.stamp(t.head_global() + Vector2(0, -30), "险避", Color(0.7, 1.0, 0.8), 80)
	b.narrate("%s险险避开了「%s」！" % [t.def["name"], c.def["ult"]["name"]], 1)
	b.arena.cheer(t.side, 1.0)
	Sfx.play("dodge_perfect", 0.0)
	# 绝技落空：扑个空
	c.set_pose("attack")
	c.trail_on = true
	await _dash(b, c, c.position + Vector2(-dir * 260.0, 0), 0.22)
	c.trail_on = false
	c.set_pose("hurt")
	c.glow = 0.0
	b.vfx.dust(c.global_position, 1.2)
	c.rage = 25.0
	await b.wait(0.45)


static func _epilogue(b: Node, c: Fighter, t: Fighter) -> void:
	c.trail_on = false
	c.spin = 0.0
	c.lift = 0.0
	c.glow = 0.0
	c.h = 0.0
	b.cam.set_roll(0.0)
	b.cine.set_letterbox(false)
	if c.is_alive() and c.state == Fighter.S.SCRIPTED:
		c.set_scripted(false)
	if t.is_alive() and t.state == Fighter.S.SCRIPTED:
		t.set_scripted(false)
	await b.wait(0.05)


## 平移（游戏时间），可带弧高
static func _dash(b: Node, f: Fighter, to: Vector2, dur: float, arc := 0.0) -> void:
	var bounds: Vector2 = b.arena_bounds(to.y)
	to.x = clamp(to.x, bounds.x + f.half_width(), bounds.y - f.half_width())
	to.y = clamp(to.y, b.Z_MIN, b.Z_MAX)
	var from := f.position
	var el := 0.0
	while el < dur and b.is_inside_tree():
		await b.get_tree().process_frame
		el += b.get_process_delta_time()
		var k: float = clamp(el / dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		f.position = from.lerp(to, e)
		if arc > 0.0:
			f.h = sin(k * PI) * arc
	f.position = to
	if arc > 0.0:
		f.h = 0.0


static func _face(f: Fighter, target: Fighter) -> void:
	f.facing = 1 if target.position.x >= f.position.x else -1


static func _impact(b: Node, pos: Vector2, col: Color, big: bool) -> void:
	b.vfx.hit_spark(pos, col, 2.0 if big else 1.1)
	b.vfx.ring(pos, 300.0 if big else 160.0, col.lerp(Color.WHITE, 0.4), false, 16.0, 0.4)
	if big:
		b.post.flash(Color(1, 1, 1), 0.45)
		b.post.aberrate(3.0)
		b.cam.punch(0.08)
		b.cam.shake(0.6)
		b.slowmo(0.2, 0.45)


static func _thrust_fx(b: Node, f: Fighter, length: float, width: float, angle := 0.0) -> void:
	var ds := f.depth_scale()
	b.vfx.spawn("thrust", {
		"position": f.global_position + Vector2(f.facing * 10.0, -(f.h + f.body_height() * 0.42) * ds),
		"rotation": angle * f.facing, "scale": Vector2(f.facing * ds, ds), "length": length, "width": width,
		"color": f.theme_color.lerp(Color.WHITE, 0.3), "life": 0.26})


static func _slash_fx(b: Node, f: Fighter, radius: float, thick: float, a0: float, a1: float, life := 0.32) -> void:
	var ds := f.depth_scale()
	b.vfx.spawn("slash", {
		"position": f.global_position + Vector2(f.facing * 30.0 * ds, -(f.h + f.body_height() * 0.45) * ds),
		"scale": Vector2(f.facing * ds, ds), "radius": radius, "thickness": thick,
		"a0": deg_to_rad(a0), "a1": deg_to_rad(a1), "squash_y": 0.7,
		"color": f.theme_color.lerp(Color.WHITE, 0.25), "life": life, "sweep_time": 0.08})


# ---------------------------------------------------------------- 赵云 · 七进七出

static func _qijin(b: Node, c: Fighter, t: Fighter) -> void:
	c.trail_on = true
	b.cam.track(t, 1.75, 3.0, Vector2(0, -80), 6.0)
	for i in 7:
		if not t.is_alive():
			break
		var side := 1.0 if i % 2 == 0 else -1.0
		var start_side := signf(c.position.x - t.position.x)
		if start_side == 0.0:
			start_side = -side
		var to := Vector2(t.position.x - start_side * 190.0, t.position.y + randf_range(-30.0, 30.0))
		c.facing = 1 if to.x > c.position.x else -1
		c.set_pose("attack")
		c.squash = Vector2(1.25, 0.85)
		_thrust_fx(b, c, 260.0, 18.0)
		Sfx.play("slash", -2.0, 1.1 + i * 0.03)
		await _dash(b, c, to, 0.075)
		b.ult_damage(c, t, 0.032, false, 60.0)
		t.facing = -c.facing
		b.cam.set_roll(3.0 * side)
		b.post.aberrate(1.0)
		await b.wait(0.07)
	b.cam.set_roll(0.0)
	c.trail_on = false
	# 末枪
	_face(c, t)
	c.set_pose("windup")
	c.glow = 1.0
	b.slowmo(0.3, 0.35)
	await b.wait(0.16)
	c.set_pose("attack")
	c.squash = Vector2(1.3, 0.85)
	_thrust_fx(b, c, 420.0, 40.0)
	Sfx.play("slash", 4.0, 0.8)
	_impact(b, t.center_global(), c.theme_color, true)
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "七进七出", Color(0.8, 0.92, 1.0), 76)
	b.ult_damage(c, t, 0.11, true, 700.0, 720.0)
	await b.wait(0.5)


# ---------------------------------------------------------------- 关羽 · 青龙拖刀斩

static func _tuodao(b: Node, c: Fighter, t: Fighter) -> void:
	var away := -1 if t.position.x > c.position.x else 1
	c.facing = away
	c.set_pose("windup")
	b.cam.track(c, 1.9, 2.0, Vector2(0, -80), 5.0)
	b.narrate("拖刀计！", 0)
	# 拖刀而走，刀尖在地上擦出火星
	var el := 0.0
	var from := c.position
	var to := c.position + Vector2(away * 230.0, 0)
	var bnd: Vector2 = b.arena_bounds(to.y)
	to.x = clamp(to.x, bnd.x + 60.0, bnd.y - 60.0)
	while el < 0.6 and b.is_inside_tree():
		await b.get_tree().process_frame
		el += b.get_process_delta_time()
		c.position = from.lerp(to, el / 0.6)
		c.bob = absf(sin(el * 18.0)) * 4.0
		if randf() < 0.5:
			var gp := c.global_position + Vector2(-away * 70.0, 0)
			b.vfx.hit_spark(gp, Color(1.0, 0.8, 0.4), 0.25)
			b.vfx.dust(gp, 0.3)
	Sfx.play("clang", -6.0, 1.4)
	# 回身
	_face(c, t)
	c.squash = Vector2(0.8, 1.15)
	c.glow = 1.2
	b.slowmo(0.25, 0.4)
	b.vfx.stamp(c.head_global() + Vector2(0, -40), "回身", Color(0.5, 1.0, 0.6), 64)
	await b.wait(0.18)
	c.set_pose("attack")
	_slash_fx(b, c, 220.0, 90.0, -120.0, 70.0, 0.4)
	Sfx.play("slash", 6.0, 0.7)
	b.cam.shake(0.4)
	var w: Node2D = b.vfx.spawn("wave", {"position": Vector2(c.position.x + c.facing * 80.0, c.position.y),
		"vx": c.facing * 1700.0, "color": Color(0.35, 1.0, 0.55), "height": 300.0})
	b.cam.track(w, 1.6, 1.0, Vector2(0, -120), 8.0)
	var hit := false
	el = 0.0
	while el < 1.0 and b.is_inside_tree():
		await b.get_tree().process_frame
		el += b.get_process_delta_time()
		if not is_instance_valid(w):
			break
		if (w.position.x - t.position.x) * c.facing >= -20.0:
			hit = true
			break
		if randf() < 0.6:
			b.vfx.dust(Vector2(w.position.x, w.position.y), 0.6, Color(0.6, 1.0, 0.7, 0.4))
	if hit:
		_impact(b, t.center_global(), Color(0.4, 1.0, 0.6), true)
		b.vfx.stamp(t.head_global() + Vector2(0, -60), "青龙偃月", Color(0.55, 1.0, 0.6), 76)
		b.ult_damage(c, t, 0.27, true, 760.0, 620.0)
	await b.wait(0.5)


# ---------------------------------------------------------------- 张飞 · 当阳怒吼

static func _nuhou(b: Node, c: Fighter, t: Fighter) -> void:
	c.set_pose("jump")
	c.jitter = 10.0
	b.cine.show_stamp("喝", Color(1.0, 0.35, 0.2), 1.2, 230, "燕人张飞在此——！", 0.26)
	Sfx.play("roar", 6.0)
	Sfx.play("drum", 4.0, 0.7)
	b.cam.track(c, 1.6, 1.4, Vector2(0, -80), 6.0)
	for i in 4:
		b.vfx.ring(c.center_global(), 500.0 + i * 120.0, Color(1.0, 0.5, 0.35), false, 26.0, 0.7)
		b.vfx.ring(c.global_position, 420.0 + i * 100.0, Color(1.0, 0.6, 0.4), true, 20.0, 0.7)
		b.post.blur(0.7, Vector2(0.5, 0.5))
		b.post.aberrate(2.5)
		b.cam.shake(0.45)
		c.jitter = 10.0
		await b.wait(0.16)
	# 对手被喝得发愣
	b.ult_damage(c, t, 0.04, false, 160.0)
	t.jitter = 9.0
	b.vfx.stamp(t.head_global() + Vector2(0, -50), "震慑", Color(1.0, 0.6, 0.4), 70)
	b.arena.gasp(t.side)
	await b.wait(0.35)
	_face(c, t)
	c.set_pose("attack")
	c.trail_on = true
	await _dash(b, c, Vector2(t.position.x - c.facing * 150.0, t.position.y), 0.14)
	c.trail_on = false
	b.cam.track(t, 2.0, 2.0, Vector2(0, -80), 8.0)
	var angles := [-0.12, 0.08, -0.05, 0.14, 0.0]
	for i in 5:
		c.set_pose("windup" if i % 2 == 0 else "attack")
		await b.wait(0.04)
		c.set_pose("attack")
		c.squash = Vector2(1.2, 0.88)
		_thrust_fx(b, c, 280.0, 20.0, angles[i])
		Sfx.play("slash", -2.0, 1.0 + i * 0.05)
		b.ult_damage(c, t, 0.036, false, 70.0)
		await b.wait(0.07)
	c.set_pose("windup")
	await b.wait(0.12)
	c.set_pose("attack")
	_thrust_fx(b, c, 460.0, 46.0)
	_impact(b, t.center_global(), c.theme_color, true)
	b.ult_damage(c, t, 0.1, true, 800.0, 700.0)
	await b.wait(0.5)


# ---------------------------------------------------------------- 马超 · 西凉铁骑

static func _tieqi(b: Node, c: Fighter, t: Fighter) -> void:
	var dir := 1 if t.position.x >= c.position.x else -1
	# 退到冲锋起点
	var bnd: Vector2 = b.arena_bounds(t.position.y)
	var start_x: float = bnd.x + 80.0 if dir > 0 else bnd.y - 80.0
	c.trail_on = true
	c.set_pose("jump")
	await _dash(b, c, Vector2(start_x, t.position.y), 0.2, 60.0)
	c.trail_on = false
	c.facing = dir
	b.cam.shot(Vector2((start_x + t.position.x) * 0.5, t.position.y - 160.0), 1.3, 2.6, 4.0)
	Sfx.play("horse_neigh", 2.0)
	Sfx.play("drum", 2.0, 0.9)
	b.narrate("西凉铁骑，万马奔腾！", 1)
	# 虚影骑兵
	var troop: Array = Bank.troop_frames("cavalry")
	var frames: Array = troop[0]["frames"] if not troop.is_empty() else []
	var anchor := Vector2.ZERO
	if not frames.is_empty():
		var entry: Dictionary = troop[0]["entry"]
		var tex0: Texture2D = frames[0]
		anchor = Vector2(tex0.get_width() * 0.5, tex0.get_height())
		if entry.has("anchor"):
			anchor = Vector2(entry["anchor"][0], entry["anchor"][1])
	var riders := 8
	var hits := 0
	for i in riders:
		var gp := {"frames": frames, "anchor": anchor}
		if frames.is_empty():
			gp["fallback"] = Bank.pose(c.id, true, "walk_l")["tex"] if Bank.has_stance(c.id, true) else c.sprite.texture
			gp["fallback_off"] = -Bank.pose(c.id, true, "walk_l")["anchor"] if Bank.has_stance(c.id, true) else c.sprite.offset
		var zz: float = t.position.y + randf_range(-110.0, 110.0)
		gp["position"] = Vector2(start_x - dir * randf_range(0.0, 260.0), zz)
		gp["vx"] = dir * randf_range(1500.0, 1900.0)
		gp["scale_k"] = 0.42 if not frames.is_empty() else c.base_scale * 1.1
		gp["tint"] = Color(0.55, 0.8, 1.6, 0.6)
		gp["life"] = 1.4
		b.vfx.spawn("ghost", gp, false)
		await b.wait(0.06)
	# 主将随虚影冲阵
	c.trail_on = true
	c.set_pose("attack")
	var el := 0.0
	var from := c.position
	var to := Vector2(t.position.x - dir * 120.0, t.position.y)
	while el < 0.55 and b.is_inside_tree():
		await b.get_tree().process_frame
		el += b.get_process_delta_time()
		c.position = from.lerp(to, clamp(el / 0.55, 0.0, 1.0))
		if hits < 6 and el > 0.08 * (hits + 1):
			hits += 1
			b.ult_damage(c, t, 0.03, false, 90.0)
			b.vfx.dust(t.global_position, 1.0)
		if randf() < 0.7:
			b.vfx.dust(c.global_position, 0.6)
	b.cam.track(t, 2.1, 1.5, Vector2(0, -80), 9.0)
	_thrust_fx(b, c, 480.0, 44.0)
	Sfx.play("slash", 4.0, 0.8)
	_impact(b, t.center_global(), c.theme_color, true)
	c.trail_on = false
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "西凉铁骑", Color(0.7, 0.85, 1.0), 76)
	b.ult_damage(c, t, 0.12, true, 820.0, 680.0)
	await b.wait(0.5)


# ---------------------------------------------------------------- 许褚 · 虎痴裸衣

static func _luoyi(b: Node, c: Fighter, t: Fighter) -> void:
	c.set_pose("windup")
	b.cam.track(c, 2.1, 1.2, Vector2(0, -90), 6.0)
	Sfx.play("roar", 4.0, 0.8)
	for i in 3:
		c.jitter = 9.0
		c.glow = 1.4
		c.glow_col = Color(1.0, 0.25, 0.1)
		b.vfx.ring(c.center_global(), 260.0 + i * 60.0, Color(1.0, 0.35, 0.15), false, 20.0, 0.5)
		b.post.aberrate(1.5)
		b.cam.shake(0.3)
		await b.wait(0.18)
	c.buffs["berserk"] = 8.0
	b.vfx.stamp(c.head_global() + Vector2(0, -50), "裸衣", Color(1.0, 0.45, 0.2), 80)
	b.narrate("许褚卸甲赤膊，杀气冲天——八息之内刀枪不入！", 1)
	# 跃起劈落
	_face(c, t)
	c.set_pose("jump")
	var land := Vector2(t.position.x - c.facing * 70.0, t.position.y)
	b.cam.shot((c.global_position + t.global_position) * 0.5 + Vector2(0, -150), 1.3, 1.0, 5.0)
	await _dash(b, c, land, 0.42, 210.0)
	c.set_pose("attack")
	c.squash = Vector2(1.35, 0.75)
	var gp := c.global_position + Vector2(c.facing * 60.0, 0)
	b.vfx.ring(gp, 420.0, Color(1.0, 0.7, 0.4), true, 26.0, 0.7)
	b.vfx.crack(gp, 2.2)
	for i in 4:
		b.vfx.dust(gp + Vector2(randf_range(-90, 90), randf_range(-20, 20)), 2.0)
	_slash_fx(b, c, 170.0, 80.0, -130.0, 60.0, 0.36)
	Sfx.play("thud", 6.0, 0.6)
	if absf(t.position.x - gp.x) < 240.0 and absf(t.position.y - gp.y) < 120.0:
		_impact(b, t.center_global(), Color(1.0, 0.5, 0.2), true)
		b.ult_damage(c, t, 0.2, true, 640.0, 600.0)
	else:
		b.cam.shake(0.6)
	await b.wait(0.45)


# ---------------------------------------------------------------- 典韦 · 古之恶来

static func _eli(b: Node, c: Fighter, t: Fighter) -> void:
	_face(c, t)
	c.set_pose("attack")
	b.cam.track(t, 1.8, 2.4, Vector2(0, -80), 6.0)
	Sfx.play("roar", 0.0, 1.1)
	var el := 0.0
	var hits := 0
	var start := c.position
	var goal := Vector2(t.position.x - c.facing * 90.0, t.position.y)
	var ring_t := 0.0
	while el < 1.25 and b.is_inside_tree():
		await b.get_tree().process_frame
		var dt: float = b.get_process_delta_time()
		el += dt
		if not c.mounted:
			c.spin += dt * 30.0 * c.facing
		c.position = start.lerp(goal, clamp(el / 0.35, 0.0, 1.0))
		ring_t -= dt
		if ring_t <= 0.0:
			ring_t = 0.09
			if c.mounted:
				# 马上不转身：左右开弓交替劈砍
				c.set_pose("attack" if c.pose != "attack" else "windup")
				c.squash = Vector2(1.15, 0.9)
			_slash_fx(b, c, 150.0, 34.0, 0.0, 400.0, 0.22)
			Sfx.play("slash", -6.0, randf_range(1.0, 1.3))
		if el > 0.3 and hits < 10 and el > 0.3 + hits * 0.09:
			hits += 1
			b.ult_damage(c, t, 0.022, false, 40.0)
			# 把对手卷着走
			t.position.x = lerp(t.position.x, c.position.x + c.facing * 80.0, 0.3)
	c.spin = 0.0
	c.set_pose("jump")
	await _dash(b, c, c.position, 0.2, 120.0)
	c.set_pose("attack")
	_slash_fx(b, c, 190.0, 80.0, -130.0, 60.0, 0.4)
	_impact(b, t.center_global(), c.theme_color, true)
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "恶来", Color(1.0, 0.4, 0.4), 80)
	b.ult_damage(c, t, 0.1, true, 760.0, 700.0)
	await b.wait(0.5)


# ---------------------------------------------------------------- 黄忠 · 百步穿杨

static func _chuanyang(b: Node, c: Fighter, t: Fighter) -> void:
	var away := -1 if t.position.x > c.position.x else 1
	if absf(t.position.x - c.position.x) < 420.0:
		c.set_pose("jump")
		c.trail_on = true
		await _dash(b, c, c.position + Vector2(away * 280.0, 0), 0.2, 70.0)
		c.trail_on = false
	_face(c, t)
	c.set_pose("windup")
	c.glow = 1.4
	c.glow_col = Color(1.0, 0.8, 0.3)
	b.vfx.spawn("reticle", {"target": t, "life": 1.1})
	b.cam.shot((c.global_position + t.global_position) * 0.5 + Vector2(0, -120), 1.4, 1.2, 4.0)
	Sfx.play("charge", 0.0, 0.8)
	b.slowmo(0.3, 0.9)
	await b.wait(0.32)
	c.set_pose("attack")
	Sfx.play("bow", 6.0, 0.8)
	var tip := c.tip_global()
	var a: Node2D = b.vfx.spawn("arrow", {"position": Vector2(tip.x, c.position.y), "h": c.position.y - tip.y,
		"vx": c.facing * 2600.0, "size": 2.2, "gold": true, "color": Color(1.0, 0.85, 0.35), "life": 1.5,
		"owner_f": c, "dead": true})
	b.cam.track(a, 2.0, 1.0, Vector2(0, -a.h), 10.0)
	var dist: float = absf(t.position.x - c.position.x)
	var el := 0.0
	while el < 1.2 and b.is_inside_tree() and is_instance_valid(a):
		await b.get_tree().process_frame
		el += b.get_process_delta_time()
		if (a.position.x - t.position.x) * c.facing >= 0.0:
			break
	if is_instance_valid(a):
		a.queue_free()
	_impact(b, t.center_global(), Color(1.0, 0.85, 0.35), true)
	var far_bonus: float = clamp(dist / 900.0, 0.0, 1.0) * 0.12
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "百步穿杨", Color(1.0, 0.85, 0.35), 76)
	b.ult_damage(c, t, 0.15 + far_bonus, false, 240.0)
	if far_bonus > 0.08:
		b.narrate("百步之外，一箭贯甲！", 1)
	await b.wait(0.25)
	# 箭雨
	b.cam.shot(t.global_position + Vector2(0, -160), 1.5, 1.6, 5.0)
	b.narrate("箭如雨下！", 0)
	for i in 9:
		b.vfx.spawn("arrow", {"position": Vector2(t.position.x + randf_range(-110.0, 110.0), t.position.y + randf_range(-40.0, 40.0)),
			"h": 520.0 + randf() * 120.0, "vx": c.facing * 120.0, "vh": -1900.0, "size": 1.1,
			"color": Color(1.0, 0.8, 0.4), "life": 0.35, "dead": true, "owner_f": c})
		Sfx.play("bow", -8.0, randf_range(1.1, 1.4))
		await b.wait(0.07)
		if i % 2 == 1 and i < 8:
			b.ult_damage(c, t, 0.016, false, 20.0)
	_impact(b, t.center_global(), Color(1.0, 0.8, 0.4), false)
	b.ult_damage(c, t, 0.03, true, 420.0, 480.0)
	await b.wait(0.45)


# ---------------------------------------------------------------- 吕布 · 天下无双

static func _wushuang(b: Node, c: Fighter, t: Fighter) -> void:
	b.post.set_grade(Color(1.06, 0.84, 0.8), Color(0.03, 0.0, 0.0), 0.56, 1.06, 1.08)
	b.cine.show_stamp("无双", Color(1.0, 0.2, 0.12), 1.0, 220, "人中吕布 · 马中赤兔", 0.26)
	Sfx.play("roar", 4.0, 0.7)
	_face(c, t)
	c.set_pose("jump")
	c.glow = 1.5
	c.glow_col = Color(1.0, 0.15, 0.08)
	var land := Vector2(t.position.x - c.facing * 110.0, t.position.y)
	b.cam.shot((c.global_position + t.global_position) * 0.5 + Vector2(0, -180), 1.25, 1.0, 4.0)
	await _dash(b, c, land, 0.5, 240.0)
	# 劈落
	c.set_pose("attack")
	c.squash = Vector2(1.35, 0.78)
	var gp := c.global_position + Vector2(c.facing * 80.0, 0)
	b.vfx.ring(gp, 460.0, Color(1.0, 0.35, 0.2), true, 26.0, 0.7)
	b.vfx.crack(gp, 2.4)
	for i in 5:
		b.vfx.dust(gp + Vector2(randf_range(-100, 100), randf_range(-20, 20)), 2.2)
	Sfx.play("thud", 8.0, 0.55)
	_impact(b, t.center_global(), Color(1.0, 0.3, 0.2), false)
	b.ult_damage(c, t, 0.08, false, 120.0)
	b.cam.track(t, 1.9, 2.4, Vector2(0, -80), 7.0)
	await b.wait(0.2)
	var arcs := [[-120.0, 70.0], [70.0, -110.0], [-130.0, 80.0]]
	for i in 3:
		c.set_pose("windup")
		await b.wait(0.07)
		c.set_pose("attack")
		c.squash = Vector2(1.2, 0.88)
		_slash_fx(b, c, 230.0, 76.0, arcs[i][0], arcs[i][1], 0.34)
		Sfx.play("slash", 2.0, 0.85 + i * 0.08)
		b.cam.set_roll(4.0 if i % 2 == 0 else -4.0)
		b.post.aberrate(2.0)
		b.ult_damage(c, t, 0.06, false, 110.0)
		await b.wait(0.16)
	b.cam.set_roll(0.0)
	c.set_pose("windup")
	b.slowmo(0.3, 0.3)
	await b.wait(0.14)
	c.set_pose("attack")
	_thrust_fx(b, c, 520.0, 52.0)
	_impact(b, t.center_global(), Color(1.0, 0.25, 0.15), true)
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "天下无双", Color(1.0, 0.3, 0.2), 80)
	b.ult_damage(c, t, 0.1, true, 950.0, 820.0)
	await b.wait(0.55)
	var pr: Dictionary = b.arena.preset
	b.post.set_grade(pr["grade"], pr["lift"], pr["vignette"], pr["sat"], pr["contrast"])


# ---------------------------------------------------------------- 徐盛 · 百里疑城

static func _yicheng(b: Node, c: Fighter, t: Fighter) -> void:
	var dir := 1 if t.position.x >= c.position.x else -1
	c.set_pose("windup")
	c.facing = dir
	b.cam.track(c, 2.0, 1.3, Vector2(0, -90), 7.0)
	Sfx.play("drum_big", 2.0)
	b.narrate("疑城连百里，草木皆兵！", 1)
	await b.wait(0.35)
	# 疑兵：虚影骑兵从后方缓步压上，只列阵不冲锋
	var troop: Array = Bank.troop_frames("cavalry")
	var frames: Array = troop[0]["frames"] if not troop.is_empty() else []
	var anchor := Vector2.ZERO
	if not frames.is_empty():
		var entry: Dictionary = troop[0]["entry"]
		var tex0: Texture2D = frames[0]
		anchor = Vector2(tex0.get_width() * 0.5, tex0.get_height())
		if entry.has("anchor"):
			anchor = Vector2(entry["anchor"][0], entry["anchor"][1])
	var bnd: Vector2 = b.arena_bounds(t.position.y)
	for i in 6:
		var gp := {"frames": frames, "anchor": anchor}
		if frames.is_empty():
			gp["fallback"] = Bank.pose(c.id, true, "walk_l")["tex"] if Bank.has_stance(c.id, true) else c.sprite.texture
			gp["fallback_off"] = -Bank.pose(c.id, true, "walk_l")["anchor"] if Bank.has_stance(c.id, true) else c.sprite.offset
		var zz: float = t.position.y + randf_range(-150.0, 150.0)
		var xx: float = t.position.x - dir * randf_range(320.0, 760.0)
		xx = clampf(xx, bnd.x + 40.0, bnd.y - 40.0)
		gp["position"] = Vector2(xx, zz)
		gp["vx"] = -dir * randf_range(20.0, 60.0)
		gp["scale_k"] = 0.42 if not frames.is_empty() else c.base_scale * 1.1
		gp["tint"] = Color(0.4, 1.5, 1.35, 0.55)
		gp["life"] = 1.8
		b.vfx.spawn("ghost", gp, false)
		Sfx.play("drum", -6.0, 0.9 + i * 0.05)
		await b.wait(0.05)
	# 敌将惊疑，一时不敢动
	b.cam.track(t, 2.2, 1.0, Vector2(0, -90), 9.0)
	t.set_scripted(true)
	t.set_pose("hurt")
	b.vfx.stamp(t.head_global() + Vector2(0, -70), "疑", Color(0.75, 1.0, 0.95), 64)
	b.slowmo(0.4, 0.5)
	await b.wait(0.3)
	t.set_pose("idle")
	# 伏兵万箭齐发
	b.cam.shot(t.global_position + Vector2(0, -180), 1.5, 1.5, 5.0)
	b.narrate("伏兵万箭齐发！", 0)
	for i in 10:
		b.vfx.spawn("arrow", {"position": Vector2(t.position.x + randf_range(-140.0, 140.0), t.position.y + randf_range(-50.0, 50.0)),
			"h": 520.0 + randf() * 120.0, "vx": -dir * 60.0, "vh": -1900.0, "size": 1.05,
			"color": Color(0.75, 1.0, 0.95), "life": 0.35, "dead": true, "owner_f": c})
		Sfx.play("bow", -8.0, randf_range(1.1, 1.4))
		await b.wait(0.06)
		if i % 3 == 2 and i < 9:
			b.ult_damage(c, t, 0.022, false, 20.0)
	# 收尾一枪
	_face(c, t)
	c.set_pose("attack")
	c.trail_on = true
	c.squash = Vector2(1.3, 0.85)
	_thrust_fx(b, c, 420.0, 40.0)
	Sfx.play("slash", 4.0, 0.85)
	_impact(b, t.center_global(), c.theme_color, true)
	b.vfx.stamp(t.head_global() + Vector2(0, -60), "百里疑城", Color(0.75, 1.0, 0.95), 76)
	b.ult_damage(c, t, 0.13, true, 700.0, 620.0)
	c.trail_on = false
	await b.wait(0.5)
