extends Control
## 选将：八员大将卡片 + 左右两侧大立像与属性。单挑选我方/敌方与难度；观战选擂台规则与首阵。

var slot := 0                  # 0 我方/左阵  1 敌方/右阵
var picks := ["zhaoyun", "lvbu"]
var cards := {}
var previews: Array = []       # 两侧预览 {root, sprite, name, info, stats}
var t := 0.0
var slot_label: Label
var diff_btns: Array = []
var round_btns: Array = []
var rule_btns: Array = []
var mount_btn: Button
var start_btn: Button
var bg_rect: TextureRect
var head_lbl: Label
var grid: GridContainer
var opt_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	picks = [Game.p1_id, Game.p2_id]
	if not Progress.is_char_unlocked(picks[0]) or not Progress.is_char_unlocked(picks[1]):
		var pool0: Array = []
		for id in Roster.ids():
			if Progress.is_char_unlocked(id):
				pool0.append(id)
		if pool0.size() >= 2:
			picks = [pool0[0], pool0[1]]
	if picks[0] == picks[1]:
		picks[1] = "lvbu" if picks[0] != "lvbu" else "zhaoyun"
	bg_rect = TextureRect.new()
	var bg_path: String = Cfg.arena().get("map", "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		bg_rect.texture = load(bg_path)
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# 铺满视口（宽屏下比 1920 更宽），否则右侧会露出清屏底色
	if bg_rect.texture:
		var r := Game.cover_rect(bg_rect.texture.get_size())
		bg_rect.size = r.size
		bg_rect.position = r.position
	bg_rect.modulate = Color(0.42, 0.36, 0.32)
	add_child(bg_rect)
	var watch := Game.mode == Game.Mode.WATCH
	head_lbl = UiKit.label(Cfg.ui_text("select_watch", "观战 · 擂台") if watch else Cfg.ui_text("select_duel", "单挑 · 点将"), 64, Color(1.0, 0.85, 0.45), true, 10)
	head_lbl.position = Vector2(Game.view_size().x * 0.5 - 260, 26 + Game.ui_offset_y())
	head_lbl.size = Vector2(520, 80)
	head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head_lbl)
	slot_label = UiKit.label("", 34, UiKit.PAPER, true, 6)
	slot_label.position = Vector2(Game.view_size().x * 0.5 - 400, 112 + Game.ui_offset_y())
	slot_label.size = Vector2(800, 50)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(slot_label)
	_build_previews()
	_build_grid()
	_build_options(watch)
	_refresh()
	Sfx.play_music("bgm_title", 1.2, -3.0)


func _build_grid() -> void:
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(Game.view_size().x * 0.5 - (5 * 140 + 4 * 14) * 0.5, 190 + Game.ui_offset_y())
	add_child(grid)
	var first: Button = null
	for id in Roster.ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 176)
		b.focus_mode = Control.FOCUS_ALL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.05, 0.03, 0.9)
		sb.border_color = Color(0.5, 0.35, 0.2)
		sb.set_border_width_all(2)
		var hov := sb.duplicate()
		hov.border_color = Color(1, 0.85, 0.45)
		hov.bg_color = Color(0.3, 0.08, 0.04, 0.95)
		hov.set_border_width_all(4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("focus", hov)
		b.add_theme_stylebox_override("pressed", hov)
		var gid: String = id
		if not Progress.is_char_unlocked(gid):
			b.disabled = true
			b.modulate = Color(0.55, 0.55, 0.55)
		b.pressed.connect(func(): _pick(gid))
		b.focus_entered.connect(func(): Sfx.play("ui_click", -14.0))
		var face := TextureRect.new()
		face.texture = Bank.portrait(id)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2(6, 6)
		face.size = Vector2(128, 120)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		var nm := UiKit.label(Roster.display_name(id), 34, UiKit.PAPER, true, 6)
		nm.position = Vector2(0, 124)
		nm.size = Vector2(140, 46)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		var tag := Control.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size = Vector2(140, 176)
		tag.draw.connect(func(): _draw_card_tag(tag, gid))
		b.add_child(tag)
		grid.add_child(b)
		cards[id] = {"btn": b, "tag": tag}
		if first == null:
			first = b
	first.call_deferred("grab_focus")


func _draw_card_tag(c: Control, id: String) -> void:
	if not Progress.is_char_unlocked(id):
		var f0: Font = Game.font_title
		c.draw_rect(Rect2(0, 0, 140, 176), Color(0, 0, 0, 0.55))
		var lk := "未解锁"
		var w0 := f0.get_string_size(lk, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		c.draw_string(f0, Vector2(70 - w0 * 0.5, 78), lk, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.8, 0.4))
		var pr := "%d 奖章" % Progress.char_price(id)
		var w1 := f0.get_string_size(pr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_string(f0, Vector2(70 - w1 * 0.5, 106), pr, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.85, 0.75))
		return
	for s in 2:
		if picks[s] == id:
			var col := Color(0.85, 0.2, 0.12) if s == 0 else Color(0.2, 0.4, 0.85)
			var lbl := "我" if s == 0 else "敌"
			if Game.mode == Game.Mode.WATCH:
				lbl = "左" if s == 0 else "右"
			var p := Vector2(22 if s == 0 else 118, 22)
			c.draw_circle(p, 18.0, col)
			c.draw_arc(p, 18.0, 0.0, TAU, 24, Color(1, 0.85, 0.45), 2.5)
			var f: Font = Game.font_title
			var w := f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			c.draw_string(f, p + Vector2(-w * 0.5, 9), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1))
			c.draw_rect(Rect2(2, 2, 136, 172), col, false, 4.0)


func _build_previews() -> void:
	for s in 2:
		var root := Control.new()
		root.position = Vector2(40 if s == 0 else Game.view_size().x - 40 - 520, 150 + Game.ui_offset_y())
		root.size = Vector2(520, 900)
		add_child(root)
		var panel := Panel.new()
		panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.72, Color(0.85, 0.2, 0.12) if s == 0 else Color(0.25, 0.45, 0.9)))
		panel.size = Vector2(520, 880)
		root.add_child(panel)
		var spr := Sprite2D.new()
		spr.position = Vector2(260, 470)
		root.add_child(spr)
		var nm := UiKit.label("", 64, UiKit.PAPER, true, 10)
		nm.position = Vector2(20, 490)
		nm.size = Vector2(480, 80)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(nm)
		var info := UiKit.label("", 26, Color(0.95, 0.85, 0.7), false, 4)
		info.position = Vector2(30, 576)
		info.size = Vector2(460, 120)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(info)
		var stats := Control.new()
		stats.position = Vector2(30, 720)
		stats.size = Vector2(460, 150)
		root.add_child(stats)
		var side := s
		stats.draw.connect(func(): _draw_stats(stats, side))
		var tag := UiKit.label(("我方" if s == 0 else "敌方") if Game.mode == Game.Mode.DUEL else ("左阵" if s == 0 else "右阵"), 36, Color(1, 0.85, 0.45), true, 8)
		tag.position = Vector2(20, 14)
		root.add_child(tag)
		var sl := s
		var sel := Button.new()
		sel.flat = true
		sel.position = Vector2(0, 0)
		sel.size = Vector2(520, 480)
		sel.focus_mode = Control.FOCUS_NONE
		sel.pressed.connect(func():
			slot = sl
			_refresh())
		root.add_child(sel)
		previews.append({"root": root, "sprite": spr, "name": nm, "info": info, "stats": stats, "panel": panel})


func _draw_stats(c: Control, s: int) -> void:
	var d := Roster.get_def(picks[s])
	var st: Dictionary = d["stats"]
	var names := [["武力", "wu"], ["统率", "tong"], ["速度", "su"], ["胆识", "dan"]]
	var f: Font = Game.font_title
	for i in names.size():
		var y := i * 36.0
		var v: float = st[names[i][1]]
		c.draw_string(f, Vector2(0, y + 26), names[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.85, 0.7))
		c.draw_rect(Rect2(90, y + 8, 300, 20), Color(0.1, 0.05, 0.03))
		var w: float = 300.0 * clamp((v - 60.0) / 40.0, 0.05, 1.0)
		c.draw_rect(Rect2(90, y + 8, w, 20), Color(d["color"]).lerp(Color(1, 0.8, 0.4), 0.3))
		c.draw_rect(Rect2(90, y + 8, 300, 20), Color(0.7, 0.5, 0.25), false, 2.0)
		c.draw_string(f, Vector2(404, y + 27), str(int(v)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.95, 0.85))


func _build_options(watch: bool) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(Game.view_size().x * 0.5 - 330, 600 + Game.ui_offset_y())
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	opt_box = box
	if watch:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.add_child(UiKit.label("规则", 32, UiKit.PAPER, true, 4))
		for r in [["arena", "擂台车轮战"], ["random", "随机对决"]]:
			var key: String = r[0]
			var b := UiKit.button(r[1], func():
				Game.watch_rule = key
				_refresh(), 28, 240)
			h.add_child(b)
			rule_btns.append([key, b])
		box.add_child(h)
	else:
		var h2 := HBoxContainer.new()
		h2.add_theme_constant_override("separation", 10)
		h2.add_child(UiKit.label("难度", 32, UiKit.PAPER, true, 4))
		for d in 4:
			var lvl := d
			var b2 := UiKit.button(Game.difficulty_name(d), func():
				Game.difficulty = lvl
				_refresh(), 28, 110)
			h2.add_child(b2)
			diff_btns.append(b2)
		box.add_child(h2)
	var h3 := HBoxContainer.new()
	h3.add_theme_constant_override("separation", 10)
	h3.add_child(UiKit.label("局制", 32, UiKit.PAPER, true, 4))
	for r in [[1, "一局定胜负"], [2, "三局两胜"]]:
		var n: int = r[0]
		var b3 := UiKit.button(r[1], func():
			Game.rounds_to_win = n
			_refresh(), 28, 210)
		h3.add_child(b3)
		round_btns.append([n, b3])
	box.add_child(h3)
	mount_btn = UiKit.button("", func():
		Game.start_mounted = not Game.start_mounted
		_refresh(), 28, 300)
	box.add_child(mount_btn)
	var h4 := HBoxContainer.new()
	h4.add_theme_constant_override("separation", 16)
	h4.add_child(UiKit.button("随　机", _random, 34, 200))
	start_btn = UiKit.button("出　阵", _start, 40, 240)
	h4.add_child(start_btn)
	h4.add_child(UiKit.button("返　回", func(): Game.goto("title"), 34, 200))
	box.add_child(h4)


func _pick(id: String) -> void:
	if not Progress.is_char_unlocked(id):
		Sfx.play("ui_click", -6.0)
		slot_label.text = "「%s」尚未解锁 · 在「战绩」页用奖章解锁" % Roster.display_name(id)
		return
	if picks[1 - slot] == id:
		# 不能选同一人：交换
		picks[1 - slot] = picks[slot]
	picks[slot] = id
	Sfx.play("ui_confirm", -6.0)
	Sfx.play("drum", -10.0, 1.2)
	slot = 1 - slot
	_refresh()


func _random() -> void:
	var pool: Array = []
	for id in Roster.ids():
		if Progress.is_char_unlocked(id):
			pool.append(id)
	if pool.size() < 2:
		pool = Roster.ids()
	pool.shuffle()
	picks = [pool[0], pool[1] if pool.size() > 1 else pool[0]]
	_refresh()


func _start() -> void:
	Game.p1_id = picks[0]
	Game.p2_id = picks[1]
	Game.champion_id = ""
	Game.champion_streak = 0
	Game.recent_ids.clear()
	Game.recent_ids.append(picks[0])
	Game.recent_ids.append(picks[1])
	Game.save_settings()
	Game.goto("battle")


func _refresh() -> void:
	var watch := Game.mode == Game.Mode.WATCH
	if watch:
		slot_label.text = "点选左阵武将" if slot == 0 else "点选右阵武将"
	else:
		slot_label.text = "点选我方武将" if slot == 0 else "点选对手"
	for s in 2:
		var pv: Dictionary = previews[s]
		var id: String = picks[s]
		var d := Roster.get_def(id)
		var mounted := Game.start_mounted and Bank.has_stance(id, true)
		if not Bank.has_stance(id, false):
			mounted = true
		var p := Bank.pose(id, mounted, "idle")
		var spr: Sprite2D = pv["sprite"]
		spr.texture = p["tex"]
		spr.centered = false
		spr.offset = -p["anchor"]
		var sc := Bank.base_scale(id, mounted) * (2.4 if not mounted else 1.9)
		spr.scale = Vector2(sc * (1 if s == 0 else -1), sc)
		pv["name"].text = d["call"]
		pv["info"].text = "%s · %s · %s\n绝技「%s」：%s" % [d["epithet"], d["weapon_name"], d["horse"], d["ult"]["name"], d["ult"]["desc"]]
		pv["stats"].queue_redraw()
		var panel: Panel = pv["panel"]
		panel.modulate = Color(1, 1, 1) if slot == s else Color(0.75, 0.75, 0.75)
	for id in cards:
		cards[id]["tag"].queue_redraw()
	for i in diff_btns.size():
		diff_btns[i].modulate = Color(1, 1, 1) if Game.difficulty == i else Color(0.6, 0.6, 0.6)
	for r in round_btns:
		r[1].modulate = Color(1, 1, 1) if Game.rounds_to_win == r[0] else Color(0.6, 0.6, 0.6)
	for r in rule_btns:
		r[1].modulate = Color(1, 1, 1) if Game.watch_rule == r[0] else Color(0.6, 0.6, 0.6)
	mount_btn.text = "开局：骑马出阵" if Game.start_mounted else "开局：步战"
	if not watch and not Progress.difficulty_gate_ok(Game.difficulty):
		slot_label.text += "　｜　「%s」难度当前不计分（需「%s」及以上）" % [
			Game.difficulty_name(Game.difficulty),
			Game.difficulty_name(Cfg.prog_int("rank.difficulty_gate.min_difficulty", 1))]


## 视口尺寸变化（微信 canvas 异步 resize）时重排
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout()


func _layout() -> void:
	var vs := Game.view_size()
	var oy := Game.ui_offset_y()
	if bg_rect and bg_rect.texture:
		var r := Game.cover_rect(bg_rect.texture.get_size())
		bg_rect.size = r.size
		bg_rect.position = r.position
	if head_lbl:
		head_lbl.position = Vector2(vs.x * 0.5 - 260, 26 + oy)
	if slot_label:
		slot_label.position = Vector2(vs.x * 0.5 - 400, 112 + oy)
	if grid:
		grid.position = Vector2(vs.x * 0.5 - (5 * 140 + 4 * 14) * 0.5, 190 + oy)
	if opt_box:
		opt_box.position = Vector2(vs.x * 0.5 - 330, 600 + oy)
	for s in previews.size():
		var root: Control = previews[s]["root"]
		root.position = Vector2(40 if s == 0 else vs.x - 40 - 520, 150 + oy)


func _process(delta: float) -> void:
	t += delta
	for s in previews.size():
		var spr: Sprite2D = previews[s]["sprite"]
		spr.position.y = 470.0 + sin(t * 2.4 + s) * 3.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.goto("title")
	elif event.is_action_pressed("ui_skip"):
		_start()
