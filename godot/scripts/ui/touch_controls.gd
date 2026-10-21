extends CanvasLayer
## 触屏操作（微信小游戏 / 手机）：左手浮动摇杆，右手按钮，顶部暂停。
## 只把触摸翻译成 p1_* 按键动作，战斗、AI 和键盘操作都不用改。
## 观战时没有摇杆和招式按钮，只有一个暂停（倍速 / 隐藏界面在暂停面板里）。

const STICK_R := 150.0          # 摇杆底盘半径（设计分辨率，高 1080）
const KNOB_R := 62.0
const DEAD := 0.18              # 中心死区
const RUN_AT := 0.9             # 推到这么远就疾跑（骑马就是纵马）
const HIT_GROW := 1.22          # 按钮判定圈比画出来的大一点，手指不用按得很准
const PILL := Vector2(150, 64)
const PAUSE_R := 50.0           # 暂停按钮半径（战斗右上角，角色头像下方）
const PAUSE_HIT := 64.0         # 暂停按钮判定半径

## 右手按钮：off 是相对屏幕右下角的位置。大按钮轻击在拇指下，其余沿弧线排开。
const FIGHT_BUTTONS := [
	{"id": "light", "action": "p1_light", "glyph": "轻", "sub": "连招", "off": Vector2(-215, -205), "r": 104.0},
	{"id": "heavy", "action": "p1_heavy", "glyph": "重", "sub": "按住蓄力", "off": Vector2(-432, -150), "r": 74.0},
	{"id": "guard", "action": "p1_guard", "glyph": "挡", "sub": "拆招", "off": Vector2(-405, -335), "r": 70.0},
	{"id": "dodge", "action": "p1_dodge", "glyph": "闪", "sub": "闪避", "off": Vector2(-262, -425), "r": 68.0},
	{"id": "jump", "action": "p1_jump", "glyph": "跳", "sub": "", "off": Vector2(-105, -400), "r": 56.0},
	{"id": "ult", "action": "p1_ult", "glyph": "绝", "sub": "绝技", "off": Vector2(-470, -505), "r": 72.0},
]

var battle: Node
var canvas: Control
var t := 0.0

var stick_touch := -1           # 按着摇杆的那根手指，-1 = 没有
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO   # -1..1
var held := {}                  # 触点编号 -> 按钮 id
var pop := {}                   # 按钮 id -> 按下的弹动 0..1
var _down := {}                 # 本层按下的动作 -> 次数（两指按同一个钮时不提前松开）


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_PAUSABLE
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_controls)
	add_child(canvas)
	if "--touch" in OS.get_cmdline_user_args() and not DisplayServer.is_touchscreen_available():
		Input.emulate_touch_from_mouse = true
	if "--touchtest" in OS.get_cmdline_user_args():
		_self_test()


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_release_all()
			visible = what != NOTIFICATION_PAUSED
		NOTIFICATION_UNPAUSED:
			visible = true


func _duel() -> bool:
	return battle != null and battle.player_side >= 0


## 招式按钮与摇杆：开打以后可用；演出中（拼刀角力、躲绝技）按钮仍可按，摇杆收起
func _fight_active() -> bool:
	return _duel() and battle.phase in ["fight", "cine"] and not battle.replaying


func _stick_active() -> bool:
	return _duel() and battle.phase == "fight" and not battle.replaying


func _pause_visible() -> bool:
	return battle != null and battle.phase in ["fight", "cine"] and not battle.replaying


func _skip_visible() -> bool:
	return battle != null and (battle.phase == "intro" or battle.replaying)


func _process(delta: float) -> void:
	t += delta / maxf(0.0001, Engine.time_scale)
	for k in pop.keys():
		pop[k] = move_toward(pop[k], 0.0, delta / maxf(0.0001, Engine.time_scale) * 6.0)
	if not _fight_active() and (stick_touch >= 0 or not held.is_empty()):
		_release_all()
	elif not _stick_active() and stick_touch >= 0:
		stick_touch = -1
		_apply_stick(Vector2.ZERO)
	canvas.queue_redraw()


# ---------------------------------------------------------------- 触摸

func _input(event: InputEvent) -> void:
	if battle == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_down(st.index, st.position):
				get_viewport().set_input_as_handled()
		elif _touch_up(st.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == stick_touch:
			_stick_move(sd.position)
			get_viewport().set_input_as_handled()


func _touch_down(index: int, pos: Vector2) -> bool:
	var vs := canvas.size
	if _skip_visible() and _skip_rect(vs).grow(12.0).has_point(pos):
		battle.request_skip()
		return true
	if _pause_visible() and _pause_hit(vs, pos):
		battle.pause_menu.open()
		return true
	if not _duel():
		# 观战只留一个「暂停」，倍速 / 隐藏界面都在暂停面板里设
		for p in _watch_pills(vs):
			if p["rect"].grow(10.0).has_point(pos):
				battle.pause_menu.open()
				return true
		return false
	if not _fight_active():
		return false
	var b := _button_at(vs, pos)
	if not b.is_empty():
		held[index] = b["id"]
		pop[b["id"]] = 1.0
		_press(b["action"])
		return true
	if _stick_active() and stick_touch < 0 and pos.x < vs.x * 0.5 and pos.y > 200.0:
		stick_touch = index
		# 底盘整个落在屏幕里，手指按在边上也能往外推
		stick_origin = Vector2(clampf(pos.x, STICK_R + 24.0, vs.x * 0.5), clampf(pos.y, 200.0 + STICK_R, vs.y - STICK_R - 24.0))
		_stick_move(pos)
		return true
	return false


func _touch_up(index: int) -> bool:
	if index == stick_touch:
		stick_touch = -1
		_apply_stick(Vector2.ZERO)
		return true
	if held.has(index):
		var id: String = held[index]
		held.erase(index)
		_release(_button(id)["action"])
		return true
	return false


func _stick_move(pos: Vector2) -> void:
	var d := pos - stick_origin
	# 手指拖出底盘时底盘跟着走，掉头不用把手指拉回原处
	if d.length() > STICK_R * 1.35:
		stick_origin = pos - d.normalized() * STICK_R * 1.35
		d = pos - stick_origin
	_apply_stick(d / STICK_R)


func _apply_stick(v: Vector2) -> void:
	var m := v.length()
	if m > 1.0:
		v /= m
		m = 1.0
	stick_vec = v
	var dir := Vector2.ZERO
	if m > DEAD:
		dir = v / m * ((m - DEAD) / (1.0 - DEAD))
	_axis("p1_left", "p1_right", dir.x)
	_axis("p1_up", "p1_down", dir.y)
	_set_held("p1_run", m >= RUN_AT)


func _axis(neg: String, pos: String, x: float) -> void:
	if x > 0.02:
		Input.action_release(neg)
		Input.action_press(pos, x)
	elif x < -0.02:
		Input.action_release(pos)
		Input.action_press(neg, -x)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _set_held(action: String, on: bool) -> void:
	if on and not _down.has(action):
		_press(action)
	elif not on and _down.has(action):
		_down.erase(action)
		Input.action_release(action)


func _press(action: String) -> void:
	_down[action] = _down.get(action, 0) + 1
	Input.action_press(action)


func _release(action: String) -> void:
	var n: int = _down.get(action, 0) - 1
	if n > 0:
		_down[action] = n
		return
	_down.erase(action)
	Input.action_release(action)


func _release_all() -> void:
	for a in _down.keys():
		Input.action_release(a)
	_down.clear()
	held.clear()
	if stick_touch >= 0 or stick_vec != Vector2.ZERO:
		stick_touch = -1
		stick_vec = Vector2.ZERO
		for a in ["p1_left", "p1_right", "p1_up", "p1_down"]:
			Input.action_release(a)


# ---------------------------------------------------------------- 布局

func _button(id: String) -> Dictionary:
	for b in FIGHT_BUTTONS:
		if b["id"] == id:
			return b
	return {}


func _button_pos(vs: Vector2, b: Dictionary) -> Vector2:
	return vs + Vector2(b["off"])


## 落在多个按钮的放大判定圈里时，取离圆心最近（按半径折算）的那个
func _button_at(vs: Vector2, pos: Vector2) -> Dictionary:
	var best := {}
	var best_k := INF
	for b in FIGHT_BUTTONS:
		var k := pos.distance_to(_button_pos(vs, b)) / float(b["r"])
		if k < HIT_GROW and k < best_k:
			best = b
			best_k = k
	return best


func _stick_home(vs: Vector2) -> Vector2:
	return Vector2(STICK_R + 110.0, vs.y - STICK_R - 110.0)


## 战斗暂停按钮：放在右上角角色头像正下方（HUD 头像圆心 x = vs.x - 108，底边约 y=166）
func _pause_center(vs: Vector2) -> Vector2:
	if _duel():
		return Vector2(vs.x - 108.0, 232.0)
	return Vector2.ZERO


func _pause_hit(vs: Vector2, pos: Vector2) -> bool:
	if _duel():
		return pos.distance_to(_pause_center(vs)) < PAUSE_HIT
	for p in _watch_pills(vs):
		if p["rect"].grow(10.0).has_point(pos):
			return true
	return false


## 观战：右下角只放一个「暂停」。倍速 / 隐藏界面都收进暂停面板里，
## 免得战斗画面上挂一堆按钮挡视线。
func _watch_pills(vs: Vector2) -> Array:
	var w := PILL.x
	return [{
		"id": "pause", "text": "暂 停",
		"rect": Rect2(vs.x - 40.0 - w, vs.y - 40.0 - PILL.y, w, PILL.y),
	}]


func _skip_rect(vs: Vector2) -> Rect2:
	var w := 180.0
	if _duel():
		return Rect2(vs.x - 40.0 - w, vs.y - 40.0 - PILL.y, w, PILL.y)
	return Rect2(vs.x - 40.0 - w, vs.y - 60.0 - PILL.y * 2.0, w, PILL.y)


# ---------------------------------------------------------------- 绘制

func _draw_controls() -> void:
	if battle == null:
		return
	var c := canvas
	var vs := c.size
	if _fight_active():
		var dim := 1.0 if battle.phase == "fight" else 0.55
		if _stick_active():
			_draw_stick(c, vs)
		for b in FIGHT_BUTTONS:
			_draw_button(c, vs, b, dim)
	if _pause_visible():
		if _duel():
			_draw_pause(c, _pause_center(vs))
	if not _duel() and battle.phase != "result":
		for p in _watch_pills(vs):
			_draw_pill(c, p["rect"], p["text"], false)
	if _skip_visible():
		_draw_pill(c, _skip_rect(vs), "跳 过 ›", true)


func _draw_stick(c: Control, vs: Vector2) -> void:
	var active := stick_touch >= 0
	var o := stick_origin if active else _stick_home(vs)
	var a := 1.0 if active else 0.55
	var running := active and stick_vec.length() >= RUN_AT
	c.draw_circle(o, STICK_R, Color(0.05, 0.03, 0.02, 0.36 * a))
	var rim := Color(1.0, 0.42, 0.2, 0.95) if running else Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.6 * a)
	c.draw_arc(o, STICK_R, 0.0, TAU, 64, rim, 5.0 if running else 3.0, true)
	c.draw_arc(o, STICK_R * RUN_AT, 0.0, TAU, 64, Color(1, 0.85, 0.5, 0.12 * a), 2.0, true)
	for i in 4:
		var ang := i * PI * 0.5
		var d := Vector2(cos(ang), sin(ang))
		var tip := o + d * (STICK_R - 16.0)
		var side := Vector2(-d.y, d.x) * 11.0
		c.draw_colored_polygon(PackedVector2Array([tip, tip - d * 16.0 + side, tip - d * 16.0 - side]), Color(1, 0.9, 0.7, 0.5 * a))
	var knob := o + stick_vec * STICK_R
	c.draw_circle(knob, KNOB_R, Color(0.16, 0.07, 0.04, 0.85 * a))
	c.draw_circle(knob, KNOB_R - 8.0, Color(0.85, 0.62, 0.3, 0.9 * a) if not running else Color(0.95, 0.4, 0.18, 0.95))
	c.draw_arc(knob, KNOB_R, 0.0, TAU, 48, Color(1, 0.88, 0.55, 0.9 * a), 3.0, true)
	if running:
		_glyph(c, "疾", knob, 54, Color(1, 0.95, 0.85))
	elif not active:
		_label(c, "移 动", o + Vector2(0, STICK_R + 34.0), 24, Color(1, 0.92, 0.78, 0.7))


func _draw_button(c: Control, vs: Vector2, b: Dictionary, dim: float) -> void:
	var id: String = b["id"]
	var p := _button_pos(vs, b)
	var r: float = b["r"]
	var f: Fighter = battle.f1
	var down := id in held.values()
	var a := dim
	var hot := false        # 需要玩家马上按的钮会闪
	var sub: String = b["sub"]
	if id == "ult":
		var full: bool = f.rage >= 100.0
		a *= 1.0 if full else 0.5
		hot = full and battle.phase == "fight"
	elif id == "dodge":
		if f.mounted:
			sub = "按住冲锋"
		if battle.real_time < battle.prompt_dodge_until:
			hot = true
			a = 1.0
	elif id in ["light", "heavy"] and not battle.cine.clash.is_empty():
		hot = true
		a = 1.0
	var s := 1.0 - float(pop.get(id, 0.0)) * 0.08
	var rr := r * s
	var pulse := 0.5 + 0.5 * sin(t * 9.0)
	if hot:
		c.draw_circle(p, rr + 10.0 + pulse * 8.0, Color(1.0, 0.75, 0.3, 0.22 * a))
	var fill := Color(0.62, 0.1, 0.06, 0.88) if down else Color(0.07, 0.04, 0.03, 0.58)
	c.draw_circle(p, rr, Color(fill.r, fill.g, fill.b, fill.a * a))
	var rim := Color(1.0, 0.85, 0.45) if (down or hot) else UiKit.GOLD
	c.draw_arc(p, rr, 0.0, TAU, 56, Color(rim.r, rim.g, rim.b, 0.85 * a), 4.0 if id == "light" else 3.0, true)
	# 怒气环 / 蓄力环
	if id == "ult":
		var ratio: float = clampf(f.rage / 100.0, 0.0, 1.0)
		if ratio > 0.0:
			c.draw_arc(p, rr + 7.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 56, Color(1.0, 0.7 + 0.25 * pulse * float(ratio >= 1.0), 0.25, 0.95), 7.0, true)
	elif id == "heavy" and down and f.charge_ratio > 0.01:
		var cr: float = clampf(f.charge_ratio, 0.0, 1.0)
		c.draw_arc(p, rr + 7.0, -PI * 0.5, -PI * 0.5 + TAU * cr, 56, Color(1.0, 0.55 + 0.4 * cr, 0.2, 0.95), 7.0, true)
	var glyph_size := int(rr * (0.86 if sub == "" else 0.78))
	var gy := p.y - (rr * 0.12 if sub != "" else 0.0)
	_glyph(c, b["glyph"], Vector2(p.x, gy), glyph_size, Color(1.0, 0.93, 0.78, a))
	if sub != "" and rr >= 60.0:
		_label(c, sub, Vector2(p.x, p.y + rr * 0.5), 19 if rr < 90.0 else 22, Color(1.0, 0.86, 0.6, 0.85 * a))


## 暂停按钮：木质圆牌 + 双层金环 + 呼吸光晕，中间两根圆角竖条
func _draw_pause(c: Control, p: Vector2) -> void:
	var r := PAUSE_R
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	# 外圈柔光（轻呼吸，提示可点）
	c.draw_circle(p, r + 7.0 + pulse * 3.0, Color(1.0, 0.78, 0.35, 0.10 + 0.05 * pulse))
	# 底盘：径向渐变感的同心圆
	c.draw_circle(p, r, Color(0.10, 0.05, 0.03, 0.88))
	c.draw_circle(p, r - 5.0, Color(0.20, 0.09, 0.05, 0.92))
	c.draw_circle(p, r - 12.0, Color(0.12, 0.05, 0.03, 0.95))
	# 双层金环
	c.draw_arc(p, r, 0.0, TAU, 64, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.95), 4.0, true)
	c.draw_arc(p, r - 8.0, 0.0, TAU, 64, Color(1.0, 0.86, 0.5, 0.45), 2.0, true)
	# 两根圆角竖条（暂停符号）：矩形 + 上下半圆帽 = 胶囊形
	var bar_w := 13.0
	var bar_h := 44.0
	var gap := 9.0
	var col := Color(1.0, 0.94, 0.78, 0.97)
	for sx in [-1.0, 1.0]:
		var cx: float = p.x + sx * (gap + bar_w * 0.5)
		var half := bar_w * 0.5
		c.draw_rect(Rect2(cx - half, p.y - bar_h * 0.5 + half, bar_w, bar_h - bar_w), col)
		c.draw_circle(Vector2(cx, p.y - bar_h * 0.5 + half), half, col)
		c.draw_circle(Vector2(cx, p.y + bar_h * 0.5 - half), half, col)
		# 高光：竖条左侧一条细亮线
		c.draw_rect(Rect2(cx - half + 2.0, p.y - bar_h * 0.5 + half, 2.0, bar_h - bar_w), Color(1, 1, 1, 0.32))


func _draw_pill(c: Control, r: Rect2, text: String, accent: bool) -> void:
	var bg := Color(0.45, 0.09, 0.05, 0.85) if accent else Color(0.07, 0.04, 0.03, 0.66)
	c.draw_rect(r, bg)
	c.draw_rect(r, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.8), false, 2.0)
	_label(c, text, r.get_center() + Vector2(0, 2), 26, Color(1, 0.93, 0.78))


func _glyph(c: Control, text: String, center: Vector2, size: int, col: Color) -> void:
	var font: Font = Game.font_brush
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w * 0.5, center.y + size * 0.36)
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.1, 0.02, 0.0, col.a))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _label(c: Control, text: String, center: Vector2, size: int, col: Color) -> void:
	var font: Font = Game.font_ui
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w * 0.5, center.y + size * 0.36)
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, col.a * 0.8))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ---------------------------------------------------------------- 开发：模拟触摸自检（--touchtest）

func _self_test() -> void:
	while battle == null or battle.phase != "fight":
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await _wait(0.6)
	var vs := canvas.size
	var f: Fighter = battle.f1
	# 自检期间让对手停手：否则 AI 正好打过来会把格挡/出招状态打断，测试结果随机飘
	var enemy: Fighter = battle.f2
	var enemy_ctrl = enemy.ctrl
	enemy.ctrl = null
	f.hp = f.max_hp
	enemy.hp = enemy.max_hp
	var results: Array = []
	var home := Vector2(320.0, vs.y - 300.0)
	var x0 := f.position.x
	_fake(0, home, true)
	_fake_drag(0, home + Vector2(STICK_R * 0.6 * -f.facing * -1.0, 0))
	await _wait(0.7)
	results.append(["摇杆推半程：武将移动", absf(f.position.x - x0) > 20.0 and not Input.is_action_pressed("p1_run")])
	_fake_drag(0, home + Vector2(STICK_R * 1.1 * float(f.facing), 0))
	await _wait(0.2)
	results.append(["摇杆推到底：疾跑", Input.is_action_pressed("p1_run")])
	_fake(0, home, false)
	await _wait(0.1)
	results.append(["松开摇杆：停止移动", not (Input.is_action_pressed("p1_right") or Input.is_action_pressed("p1_left") or Input.is_action_pressed("p1_run"))])
	await _wait(0.6)
	var light := _button_pos(vs, _button("light"))
	var serial: int = f.attack_serial
	_fake(1, light, true)
	await _wait(0.05)
	_fake(1, light, false)
	await _wait(0.1)
	results.append(["点轻击：出招", f.attack_serial > serial])
	await _wait(1.2)
	var guard := _button_pos(vs, _button("guard"))
	_fake(2, guard + Vector2(30, 20), true)
	await _wait(0.25)
	results.append(["按住格挡（按在钮边上）：进入格挡", f.state == Fighter.S.GUARD])
	_fake(2, guard, false)
	await _wait(0.5)
	# 两指同时：摇杆 + 重击
	_fake(0, home, true)
	_fake_drag(0, home + Vector2(0, STICK_R * 0.7))
	var heavy := _button_pos(vs, _button("heavy"))
	serial = f.attack_serial
	_fake(3, heavy, true)
	await _wait(0.35)
	results.append(["两指：边走边按住重击", f.attack_serial > serial and Input.is_action_pressed("p1_down")])
	_fake(3, heavy, false)
	_fake(0, home, false)
	await _wait(0.3)
	results.append(["全部松开后没有残留按键", _down.is_empty() and not Input.is_action_pressed("p1_heavy") and not Input.is_action_pressed("p1_down")])
	enemy.ctrl = enemy_ctrl
	var ok := true
	for r in results:
		print("TOUCHTEST %s %s" % ["PASS" if r[1] else "FAIL", r[0]])
		ok = ok and r[1]
	print("TOUCHTEST DONE %s" % ("OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## 走完整的输入管线：把设计坐标换成窗口坐标交给 Input，和真手指一样经过视口缩放
func _fake(index: int, design_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = get_viewport().get_final_transform() * design_pos
	Input.parse_input_event(ev)


func _fake_drag(index: int, design_pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = get_viewport().get_final_transform() * design_pos
	Input.parse_input_event(ev)
