class_name AiBrain
extends RefCounted
## 武将 AI。和玩家用同一套输入；靠性格参数打出不同风格：
## 游斗、压制、诈败拖刀、远射、马上对冲、拆招反击、蓄力等起身……
## showman=true（观战）时更爱拼刀、留绝技等名场面、杜绝僵持。

var f: Fighter
var p: Dictionary
var level := 2.0
var showman := false

var now := 0.0
var think_t := 0.0
var tactic := "approach"
var tactic_t := 0.0
var tactic_len := 2.0
var lane_z := 660.0

var queued: Array = []          # [{at, key}]
var guard_until := -1.0
var heavy_until := -1.0
var run_on := false
var move_goal := Vector2.ZERO
var has_goal := false
var seen_serial := -1           # 已经反应过的对手出招序号
var pending_dodge := Vector2.ZERO
var seen_arrows := {}
var reaction := 0.22
var parry_skill := 0.6
var mistake := 0.1
var aggression := 0.6
var stall := 0.0
var last_opp_hp := 1.0
var last_my_hp := 1.0
var ult_hold := 0.0
var combo_goal := 3
var feint_phase := 0
var joust_dir := 0
var joust_t := 0.0
var taunt_cd := 6.0
var punish_cd := 0.0
var wakeup_charge := false


func _init(fighter: Fighter, lvl: float, show := false) -> void:
	f = fighter
	p = f.def["ai"]
	level = lvl
	showman = show
	var li := clampi(int(round(lvl)), 0, 3)
	reaction = [0.40, 0.29, 0.21, 0.15][li] + randf_range(-0.02, 0.02)
	parry_skill = p["parry"] * [0.25, 0.55, 0.85, 1.05][li]
	mistake = [0.28, 0.16, 0.08, 0.03][li]
	aggression = p["aggression"] * [0.75, 0.9, 1.0, 1.1][li]
	if showman:
		reaction = 0.2
		parry_skill = p["parry"] * 0.8
		mistake = 0.08
	lane_z = randf_range(600.0, 760.0)


# ---------------------------------------------------------------- 入口

func get_input(_fighter, dt: float) -> Dictionary:
	now += dt
	var opp: Fighter = f.opponent
	if opp == null or not opp.is_alive():
		return {"move": Vector2.ZERO}
	var out := {"move": Vector2.ZERO, "run": false, "light": false, "heavy": false, "heavy_held": false,
		"guard": false, "guard_pressed": false, "dodge": false, "jump": false, "ult": false}
	_track_hp(opp, dt)
	_defend(opp, out)
	think_t -= dt
	if think_t <= 0.0:
		think_t = randf_range(0.08, 0.2) + (0.08 if level < 1.0 else 0.0)
		_think(opp)
	_offense(opp, out, dt)
	_fire_queue(out)
	if now < guard_until:
		out["guard"] = true
		if out["light"] or out["heavy"]:
			# 格挡期间不出招
			out["light"] = false
			out["heavy"] = false
	if now < heavy_until:
		out["heavy_held"] = true
	_movement(opp, out, dt)
	return out


func _track_hp(opp: Fighter, dt: float) -> void:
	var o := opp.hp / opp.max_hp
	var m := f.hp / f.max_hp
	if o < last_opp_hp - 0.001 or m < last_my_hp - 0.001:
		stall = 0.0
	else:
		stall += dt
	last_opp_hp = o
	last_my_hp = m
	taunt_cd -= dt
	punish_cd -= dt


func _press(key: String, delay := 0.0) -> void:
	queued.append({"at": now + delay, "key": key})


func _fire_queue(out: Dictionary) -> void:
	var keep: Array = []
	for q in queued:
		if q["at"] <= now:
			out[q["key"]] = true
			if q["key"] == "guard_pressed":
				out["guard"] = true
			if q.has("dir"):
				pending_dodge = q["dir"]
		else:
			keep.append(q)
	queued = keep


# ---------------------------------------------------------------- 防守反应

func _defend(opp: Fighter, out: Dictionary) -> void:
	# 箭矢：侧移、格挡、跳
	for a in f.battle.projectiles:
		if not is_instance_valid(a) or a.owner_f == f or a.dead or seen_arrows.has(a):
			continue
		var toward: bool = signf(a.vx) == signf(f.position.x - a.position.x)
		var dist: float = absf(a.position.x - f.position.x)
		if toward and dist < 900.0 and absf(a.position.y - f.position.y) < 50.0:
			seen_arrows[a] = true
			var eta: float = dist / max(1.0, absf(a.vx))
			# 箭太快来不及看清，或者一时疏忽
			if eta < reaction + 0.04 or randf() > 0.5 + float(p["patience"]) * 0.25 - mistake:
				continue
			var r := randf()
			if not f.mounted and r < float(p["dodge"]) * 0.5 and f.stamina > 30.0:
				# 侧闪出箭道
				var side_dir := 1.0 if f.position.y < 700.0 else -1.0
				_press_dodge_dir(Vector2(0, side_dir), max(reaction, eta - 0.18))
			elif r < 0.8:
				if randf() < parry_skill * 0.55:
					_press("guard_pressed", max(reaction, eta - randf_range(0.05, 0.12)))
					guard_until = max(guard_until, now + eta + 0.15)
				else:
					_press("guard_pressed", reaction)
					guard_until = max(guard_until, now + eta + 0.2)
			elif not f.mounted:
				_press("jump", max(reaction, eta - 0.25))
	if opp.state != Fighter.S.ATTACK or opp.move.is_empty():
		return
	if seen_serial == opp.attack_serial or opp.move_phase > 0:
		return
	seen_serial = opp.attack_serial
	var mv: Dictionary = opp.move
	if mv["kind"] == "projectile":
		return
	var adx: float = absf(opp.position.x - f.position.x)
	var adz: float = absf(opp.position.y - f.position.y)
	var reach: float = mv["reach"] + f.half_width() + 40.0 + (80.0 if mv["run"] else 0.0) + float(mv["lunge"]) * 0.7
	if opp.mounted and mv["run"]:
		reach += absf(opp.vel.x) * 0.25
	var threat: bool = adx < reach and adz < float(mv["depth"]) + 30.0 and opp.facing == signi(int(signf(f.position.x - opp.position.x)))
	if not threat:
		return
	if f.state in [Fighter.S.HITSTUN, Fighter.S.GUARDBREAK, Fighter.S.KNOCKDOWN, Fighter.S.DOWN, Fighter.S.GETUP]:
		return
	if f.state == Fighter.S.ATTACK and f.move_phase >= 1:
		return
	if randf() < mistake:
		return  # 失误：没看出来
	var time_left: float = max(0.02, opp.startup_len - opp.move_t)
	if not mv["charge"].is_empty():
		time_left += 0.15
	var guarding: bool = f.state in [Fighter.S.GUARD, Fighter.S.BLOCKSTUN] or now < guard_until
	if guarding:
		# 已在守势、全神贯注：有机会看准时机拆招
		if time_left > reaction * 0.45 and randf() < parry_skill * 0.75:
			var err := randf_range(-0.07, 0.07) * (1.1 - clampf(parry_skill, 0.0, 1.0))
			_press("guard_pressed", max(0.0, time_left - 0.07 + err))
		guard_until = max(guard_until, now + time_left + float(mv["active"]) + 0.2)
		return
	if time_left <= reaction:
		# 来不及反应：凭经验预判，或者硬吃
		if f.state == Fighter.S.IDLE and randf() < 0.12 + float(p["patience"]) * 0.3:
			_press("guard_pressed", 0.0)
			guard_until = max(guard_until, now + time_left + float(mv["active"]) + 0.15)
		return
	var choice := _pick_defense(opp, mv, time_left - reaction, adx)
	match choice:
		"parry":
			var err2 := randf_range(-0.08, 0.08) * (1.1 - clampf(parry_skill, 0.0, 1.0))
			_press("guard_pressed", max(reaction, time_left - 0.07 + err2))
			guard_until = max(guard_until, now + time_left + 0.2)
		"guard":
			_press("guard_pressed", reaction)
			guard_until = max(guard_until, now + time_left + float(mv["active"]) + 0.25)
		"dodge":
			var back := Vector2(-signf(opp.position.x - f.position.x), 0)
			if randf() < 0.5:
				back = Vector2(0, 1.0 if f.position.y < lane_z else -1.0)
			_press_dodge_dir(back, max(reaction, time_left - 0.12))
		"counter":
			_press("light", reaction)
		"clash":
			_press("heavy", reaction)
		"jump":
			_press("jump", max(reaction, time_left - 0.15))


func _pick_defense(opp: Fighter, mv: Dictionary, remaining: float, adx: float) -> String:
	var w := {}
	w["parry"] = parry_skill * 1.2
	w["guard"] = 0.7 + float(p["patience"]) * 0.4
	if not f.mounted and f.stamina > Fighter.DODGE_COST:
		w["dodge"] = float(p["dodge"]) * 1.0
		w["jump"] = float(p["jump"]) * 0.35 if mv["vfx"] == "thrust" else 0.0
	var my_l1: Dictionary = f.moves.get("l1", {})
	if not my_l1.is_empty() and my_l1["kind"] == "melee":
		var my_start: float = float(my_l1["startup"]) / f.spd
		if my_start < remaining - 0.04 and adx < float(my_l1["reach"]) + opp.half_width():
			w["counter"] = aggression * 0.9
	if int(mv["clash"]) >= 2 and f.moves.has("heavy") and int(f.moves["heavy"]["clash"]) >= 2:
		w["clash"] = aggression * (0.9 if showman else 0.4)
	if f.state == Fighter.S.HITSTUN or f.state == Fighter.S.GUARDBREAK:
		return "none"
	if f.state == Fighter.S.ATTACK and f.move_phase >= 1:
		# 自己正出招，只能硬吃或者靠格挡（来不及）
		return "none"
	if mv["breaks_guard"] and f.stamina < float(mv["guard_dmg"]):
		w["guard"] = 0.1
		w["dodge"] = w.get("dodge", 0.0) * 1.8
	return _weighted(w)


func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += max(0.0, float(w[k]))
	if total <= 0.0:
		return "none"
	var r := randf() * total
	for k in w:
		r -= max(0.0, float(w[k]))
		if r <= 0.0:
			return k
	return w.keys()[0]


func _press_dodge_dir(dir: Vector2, delay: float) -> void:
	queued.append({"at": now + delay, "key": "dodge", "dir": dir})
	has_goal = true
	move_goal = f.position + dir * 200.0


## 对峙之后：两将同时冲锋
func charge_now() -> void:
	tactic = "joust" if f.mounted else "approach"
	tactic_t = 0.0
	tactic_len = 2.5
	joust_dir = 0
	run_on = true
	guard_until = -1.0
	stall = 6.0
	if not f.mounted:
		_press("light", randf_range(0.35, 0.6))


# ---------------------------------------------------------------- 战术选择

func _think(opp: Fighter) -> void:
	tactic_t += think_t
	var adx: float = absf(opp.position.x - f.position.x)
	var my_ratio := f.hp / f.max_hp
	var opp_ratio := opp.hp / opp.max_hp
	var agg := aggression + (stall - 3.0) * 0.12 if stall > 3.0 else aggression
	if showman and stall > 5.0:
		agg += 0.3
	if opp_ratio < 0.3:
		agg += 0.15
	if my_ratio < 0.25 and p["patience"] > 0.5:
		agg -= 0.1
	# 绝技
	if f.rage >= 100.0:
		ult_hold += 0.15
		if _want_ult(opp, adx, my_ratio, opp_ratio):
			_press("ult", 0.0)
			ult_hold = 0.0
			return
	# 主动守势：对手进入攻击范围时，稳重的武将会先架起兵器
	var opp_reach: float = float(opp.moves.get("l1", {}).get("reach", 150.0)) + f.half_width() + 50.0
	if adx < opp_reach and f.state == Fighter.S.IDLE and opp.state in [Fighter.S.IDLE, Fighter.S.ATTACK] and now >= guard_until:
		var g_rate := (0.35 + float(p["patience"]) * 1.1 - aggression * 0.35) * think_t
		if tactic == "space" or tactic == "circle":
			g_rate *= 1.6
		if randf() < g_rate:
			_press("guard_pressed", 0.0)
			guard_until = now + randf_range(0.3, 0.75)
	if tactic_t < tactic_len and tactic != "approach":
		return
	tactic_t = 0.0
	tactic_len = randf_range(1.2, 3.0)
	if opp.state in [Fighter.S.DOWN, Fighter.S.GETUP]:
		tactic = "wakeup"
		return
	if f.mounted:
		var w := {"joust": 0.6 + agg * 0.6, "melee": 0.4 + agg * 0.4, "circle": float(p["patience"]) * 0.4}
		if f.def["weapon"] == "bow":
			w = {"zone": 1.2, "joust": 0.3, "circle": 0.3}
		tactic = _weighted(w)
		if tactic == "joust":
			joust_dir = 0
		return
	var w2 := {"approach": 0.4 + agg, "pressure": agg * 0.8, "space": float(p["patience"]) * 0.8,
		"circle": float(p["patience"]) * 0.5, "feint": float(p["feint"]) * 0.6}
	if float(p["zone"]) > 0.0:
		w2["zone"] = float(p["zone"]) * 1.6
		w2["approach"] *= 0.3
		w2["pressure"] *= 0.2
	if f.stamina < 25.0:
		w2["space"] = w2.get("space", 0.0) + 0.8
	if showman and randf() < 0.12 and adx > 300.0 and adx < 600.0:
		w2 = {"standoff": 1.0}
	tactic = _weighted(w2)
	feint_phase = 0
	if tactic == "standoff":
		tactic_len = randf_range(1.0, 1.8)


func _want_ult(opp: Fighter, adx: float, my_ratio: float, opp_ratio: float) -> bool:
	if not f.battle.can_ult(f):
		return false
	if not (opp.state in [Fighter.S.IDLE, Fighter.S.ATTACK, Fighter.S.GUARD, Fighter.S.HITSTUN, Fighter.S.BLOCKSTUN, Fighter.S.GUARDBREAK, Fighter.S.DODGE]):
		return false
	var range_ok := adx < 700.0
	if not range_ok:
		return false
	match p["ult_style"]:
		"eager":
			return ult_hold > 0.4
		"finisher":
			return opp_ratio < 0.4 or my_ratio < 0.3 or ult_hold > 9.0
		_:
			return opp_ratio < 0.55 or my_ratio < 0.45 or ult_hold > 6.0 or opp.state == Fighter.S.GUARDBREAK
	return false


# ---------------------------------------------------------------- 进攻

var _dt_since_offense := 0.0


func _offense(opp: Fighter, out: Dictionary, dt: float) -> void:
	_dt_since_offense = dt
	if f.state == Fighter.S.ATTACK:
		_continue_combo(opp)
		return
	if not (f.state in [Fighter.S.IDLE, Fighter.S.GUARD]):
		return
	if now < guard_until:
		return
	var dx: float = opp.position.x - f.position.x
	var adx := absf(dx)
	var adz := absf(opp.position.y - f.position.y)
	var l1: Dictionary = f.moves.get("l1", {})
	var reach: float = float(l1.get("reach", 150.0)) + opp.half_width() * 0.8
	var depth: float = float(l1.get("depth", 40.0))
	var facing_ok := signf(dx) == float(f.facing) or f.mounted == false
	if f.mounted:
		_offense_mounted(opp, out, adx, adz, dx)
		return
	if f.def["weapon"] == "bow" and tactic == "zone":
		if adx > 260.0 and adz < 40.0 and randf() < (0.9 + aggression * 0.8) * _dt_since_offense:
			if randf() < 0.35 and opp.state != Fighter.S.GUARD:
				_press("heavy")
				heavy_until = now + randf_range(0.2, 0.9)
			else:
				_press("light")
				combo_goal = 1 + randi() % 3
			return
	# 对手收招露破绽：惩罚
	var opp_whiff: bool = opp.state == Fighter.S.ATTACK and opp.move_phase == 2 and not opp.move_landed
	var opp_open: bool = opp.state in [Fighter.S.GUARDBREAK, Fighter.S.HITSTUN] or opp_whiff
	if opp_open and adx < reach + 40.0 and adz < depth + 10.0 and punish_cd <= 0.0:
		punish_cd = 0.4
		if opp.state == Fighter.S.GUARDBREAK and randf() < 0.6:
			_press("heavy")
			heavy_until = now + randf_range(0.3, 0.75)
		else:
			_press("light")
			combo_goal = 3
		return
	if tactic == "wakeup":
		if adx < reach + 30.0 and opp.state == Fighter.S.GETUP and randf() < 0.5:
			_press("light")
		return
	if adx < reach and adz < depth * 0.8 and facing_ok:
		var r := randf()
		var per_sec := 0.55 + aggression * 1.5
		if tactic == "pressure":
			per_sec += 0.8
		if tactic == "space" or tactic == "circle":
			per_sec *= 0.45
		if stall > 4.0:
			per_sec += 0.6
		var rate := per_sec * _dt_since_offense
		if r < rate:
			if opp.state == Fighter.S.GUARD and randf() < 0.55:
				_press("heavy")
				heavy_until = now + randf_range(0.15, 0.7)
			elif randf() < 0.22 + (0.15 if showman else 0.0):
				_press("heavy")
				heavy_until = now + randf_range(0.0, 0.8) * (1.0 if randf() < 0.5 else 0.2)
			elif randf() < float(p["jump"]) * 0.25:
				_press("jump")
				_press("light", 0.18)
			else:
				_press("light")
				combo_goal = 2 + (1 if randf() < float(p["combo"]) else 0)
				if randf() < 0.3:
					combo_goal = 1
	# 冲刺突进
	elif tactic in ["approach", "pressure"] and adx > reach + 60.0 and adx < reach + 260.0 and adz < depth and randf() < (0.25 + aggression * 0.5) * _dt_since_offense:
		run_on = true
		_press("light", randf_range(0.18, 0.32))


func _offense_mounted(opp: Fighter, _out: Dictionary, adx: float, adz: float, dx: float) -> void:
	var l1: Dictionary = f.moves.get("l1", {})
	var reach: float = float(l1.get("reach", 190.0)) + opp.half_width() * 0.6
	var approaching: bool = signf(f.vel.x) == signf(dx) and absf(f.vel.x) > 300.0
	if f.def["weapon"] == "bow":
		if adx > 240.0 and adz < 45.0 and signf(dx) == float(f.facing) and randf() < 1.1 * _dt_since_offense:
			if randf() < 0.3:
				_press("heavy")
				heavy_until = now + randf_range(0.2, 0.8)
			else:
				_press("light")
				combo_goal = 2
		elif adx < 170.0 and randf() < 1.5 * _dt_since_offense:
			_press("light")
		return
	if approaching and adz < 44.0:
		# 冲锋出手时机：按马速预判
		var lead := absf(f.vel.x) * 0.14
		if adx < reach + lead and adx > reach * 0.4:
			_press("light")
			return
	if adx < reach and adz < 44.0 and signf(dx) == float(f.facing) and absf(f.vel.x) < 300.0:
		if randf() < (0.6 + aggression * 1.4) * _dt_since_offense:
			if opp.state == Fighter.S.GUARD and randf() < 0.6:
				_press("heavy")
				heavy_until = now + randf_range(0.2, 0.7)
			elif randf() < 0.25:
				_press("heavy")
				heavy_until = now + randf_range(0.0, 0.6)
			else:
				_press("light")
				combo_goal = 2


var combo_decided := -1


func _continue_combo(opp: Fighter) -> void:
	var mv: Dictionary = f.move
	if mv.is_empty() or f.move_phase != 2:
		return
	if f.buffered != "" or combo_decided == f.attack_serial:
		return
	combo_decided = f.attack_serial
	# 打中才连（命中确认），观众看得出"连招"
	var hits_so_far := f.combo
	if mv["kind"] == "projectile":
		if mv["next"] != "" and combo_goal > 1 and randf() < 0.5:
			combo_goal -= 1
			_press("light", randf_range(0.0, 0.08))
		return
	if not f.move_connected:
		return
	var launched: bool = opp.state == Fighter.S.KNOCKDOWN
	if launched and not f.mounted:
		# 浮空追击
		if randf() < float(p["combo"]) * 0.7 and absf(opp.position.x - f.position.x) < 200.0:
			if randf() < 0.5:
				_press("jump", 0.02)
				_press("light", 0.2)
			else:
				_press("light", 0.04)
		return
	if mv["next"] != "" and hits_so_far < combo_goal + 1:
		if randf() < float(p["combo"]) + 0.1:
			_press("light", randf_range(0.0, 0.06))
			if mv["heavy_next"] != "" and randf() < 0.28:
				queued.pop_back()
				_press("heavy", randf_range(0.0, 0.05))
	elif mv["heavy_next"] != "" and randf() < 0.3:
		_press("heavy", 0.02)


# ---------------------------------------------------------------- 走位

func _movement(opp: Fighter, out: Dictionary, dt: float) -> void:
	var dx: float = opp.position.x - f.position.x
	var adx := absf(dx)
	var dz: float = opp.position.y - f.position.y
	var dirx := signf(dx)
	var l1: Dictionary = f.moves.get("l1", {})
	var reach: float = float(l1.get("reach", 150.0)) + opp.half_width() * 0.7
	var mv := Vector2.ZERO
	var run := false
	if f.mounted:
		_movement_mounted(opp, out, dt)
		return
	if has_goal:
		var to := move_goal - f.position
		if to.length() < 24.0:
			has_goal = false
		else:
			mv = to.normalized()
	else:
		match tactic:
			"approach", "pressure":
				var want := reach * (0.7 if tactic == "pressure" else 0.85)
				if adx > want:
					mv.x = dirx
				elif adx < want * 0.45:
					mv.x = -dirx * 0.5
				mv.y = clampf(dz / 60.0, -1.0, 1.0)
				run = adx > 420.0 and f.stamina > 40.0
			"space":
				var opp_reach: float = float(opp.moves.get("l1", {}).get("reach", 150.0)) + f.half_width() + 40.0
				if adx < opp_reach:
					mv.x = -dirx
				elif adx > opp_reach + 90.0:
					mv.x = dirx * 0.6
				mv.y = clampf(dz / 80.0, -1.0, 1.0) * 0.6
			"circle", "standoff":
				var want2 := reach + (120.0 if tactic == "circle" else 220.0)
				mv.x = clampf((adx - want2) / 80.0, -1.0, 1.0) * dirx * 0.7
				var strafe := sin(now * (1.3 if tactic == "circle" else 0.9) + float(f.side) * 2.0)
				mv.y = strafe * 0.8
				if tactic == "standoff":
					mv *= 0.5
			"zone":
				var want3 := 520.0
				if adx < 380.0:
					mv.x = -dirx
					run = adx < 260.0 and f.stamina > 30.0
					if adx < 200.0 and f.stamina > Fighter.DODGE_COST and randf() < 0.9 * dt:
						_press_dodge_dir(Vector2(-dirx, randf_range(-0.5, 0.5)), 0.0)
				elif adx > want3 + 150.0:
					mv.x = dirx * 0.7
				mv.y = clampf(dz / 50.0, -1.0, 1.0)
			"feint":
				_feint(opp, out, adx, dirx, dz, reach)
				return
			"wakeup":
				var want4 := reach * 0.9
				mv.x = clampf((adx - want4) / 60.0, -1.0, 1.0) * dirx
				mv.y = clampf(dz / 60.0, -1.0, 1.0)
				if opp.state == Fighter.S.DOWN and opp.down_t - opp.state_t < 0.6 and not wakeup_charge and randf() < 0.35 and f.state == Fighter.S.IDLE:
					wakeup_charge = true
					_press("heavy")
					heavy_until = now + 0.9
				if opp.state == Fighter.S.IDLE:
					wakeup_charge = false
	# 墙边：别被逼进角落
	var b: Vector2 = f.battle.arena_bounds(f.position.y)
	if f.position.x - b.x < 120.0 and mv.x < 0.0:
		mv.x = 0.3
		mv.y = signf(lane_z - f.position.y) if absf(lane_z - f.position.y) > 40.0 else 0.6
	if b.y - f.position.x < 120.0 and mv.x > 0.0:
		mv.x = -0.3
		mv.y = signf(lane_z - f.position.y) if absf(lane_z - f.position.y) > 40.0 else -0.6
	if run_on:
		run = true
		if adx < reach:
			run_on = false
	out["move"] = mv.limit_length(1.0)
	out["run"] = run or out.get("run", false)
	if pending_dodge != Vector2.ZERO:
		out["move"] = pending_dodge
		pending_dodge = Vector2.ZERO
	# 嘲讽：对手倒地、距离远
	if taunt_cd <= 0.0 and opp.state == Fighter.S.DOWN:
		taunt_cd = 9.0
		if randf() < float(p["taunt"]) * 0.8:
			f.battle.say(f, Roster.line(f.id, "taunt"))


func _feint(opp: Fighter, out: Dictionary, adx: float, dirx: float, dz: float, reach: float) -> void:
	# 诈败：拖刀背走，引对手追来，回身一击
	match feint_phase:
		0:
			if adx < reach + 200.0:
				feint_phase = 1
				tactic_len = 3.0
				if f.def["weapon"] == "glaive":
					f.battle.narrate("%s拖刀而走——莫非是诈败？" % f.def["name"], 1)
				else:
					f.battle.narrate("%s佯装不敌，拨马便走！" % f.def["name"], 0)
			out["move"] = Vector2(dirx, clampf(dz / 60.0, -1.0, 1.0))
		1:
			out["move"] = Vector2(-dirx, 0)
			out["run"] = true
			if f.def["weapon"] == "glaive" and randf() < 0.3:
				f.battle.vfx.dust(f.global_position + Vector2(f.facing * 60.0, 0), 0.3, Color(1.0, 0.8, 0.5, 0.6))
			var chasing: bool = signf(opp.vel.x) == -dirx and absf(opp.vel.x) > 120.0
			if (chasing and adx < reach + 140.0) or tactic_t > 1.4:
				feint_phase = 2
				out["run"] = false
				out["move"] = Vector2(dirx, 0)
				_press("heavy", 0.05)
				heavy_until = now + randf_range(0.0, 0.25)
				if chasing:
					f.battle.on_feint_turn(f)
		2:
			tactic = "approach"
			feint_phase = 0


func _movement_mounted(opp: Fighter, out: Dictionary, _dt: float) -> void:
	var dx: float = opp.position.x - f.position.x
	var adx := absf(dx)
	var dz: float = opp.position.y - f.position.y
	var dirx := signf(dx)
	var mv := Vector2.ZERO
	var run := false
	var b: Vector2 = f.battle.arena_bounds(f.position.y)
	match tactic:
		"joust", "zone":
			if joust_dir == 0:
				# 先拉开距离：朝离对手远的一侧奔去
				var space_left: float = f.position.x - b.x
				var space_right: float = b.y - f.position.x
				joust_dir = -1 if space_left > space_right else 1
				if adx > 520.0:
					joust_dir = int(dirx)
				joust_t = 0.0
			joust_t += 0.016
			var target_dir := float(joust_dir)
			if tactic == "zone":
				target_dir = -dirx if adx < 480.0 else dirx * 0.3
			mv.x = target_dir
			run = true
			# 冲向对手时对准对方所在的纵深
			if signf(target_dir) == dirx:
				mv.y = clampf(dz / 40.0, -1.0, 1.0)
			else:
				mv.y = clampf((lane_z - f.position.y) / 120.0, -1.0, 1.0) * 0.4
			# 冲过头或到场边，掉头再冲
			var near_wall: bool = (joust_dir < 0 and f.position.x - b.x < 160.0) or (joust_dir > 0 and b.y - f.position.x < 160.0)
			var passed: bool = signf(dx) != float(joust_dir) and adx > 260.0
			if near_wall or (passed and joust_t > 0.5):
				joust_dir = int(dirx)
				joust_t = 0.0
		"melee":
			var want := float(f.moves.get("l1", {}).get("reach", 190.0)) * 0.8
			mv.x = clampf((adx - want) / 80.0, -1.0, 1.0) * dirx
			mv.y = clampf(dz / 40.0, -1.0, 1.0)
			if adx > 520.0:
				run = true
		"circle":
			mv.x = clampf((adx - 360.0) / 120.0, -1.0, 1.0) * dirx * 0.6
			mv.y = sin(now * 1.1 + float(f.side)) * 0.8
		_:
			mv.x = dirx
			mv.y = clampf(dz / 40.0, -1.0, 1.0)
	out["move"] = mv.limit_length(1.0)
	out["run"] = run
