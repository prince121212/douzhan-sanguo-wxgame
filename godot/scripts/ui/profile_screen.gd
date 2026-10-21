extends Control
## 成就 / 段位页：段位进度、累计战绩、称号、武将解锁。
## 数据全部来自 Progress（存档）与 config/progression.json（规则）。

var bg: TextureRect
var t := 0.0
var rank_card: Control
var medal_lbl: Label
var title_box: VBoxContainer
var char_box: VBoxContainer
var hint_lbl: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = TextureRect.new()
	var bg_path: String = Cfg.arena().get("map", "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	if bg.texture:
		var r := Game.cover_rect(bg.texture.get_size())
		bg.size = r.size
		bg.position = r.position
	bg.modulate = Color(0.22, 0.19, 0.17)
	add_child(bg)
	var vs := Game.view_size()
	var oy := Game.ui_offset_y()
	var head := UiKit.label("战 绩 · 成 就", 64, Color(1.0, 0.85, 0.45), true, 10)
	head.position = Vector2(vs.x * 0.5 - 300, 26 + oy)
	head.size = Vector2(600, 80)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)
	medal_lbl = UiKit.label("", 30, Color(1.0, 0.86, 0.5), true, 6)
	medal_lbl.position = Vector2(vs.x * 0.5 - 300, 104 + oy)
	medal_lbl.size = Vector2(600, 44)
	medal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(medal_lbl)
	rank_card = Control.new()
	rank_card.position = Vector2(vs.x * 0.5 - 470, 160 + oy)
	rank_card.size = Vector2(940, 170)
	rank_card.draw.connect(_draw_rank_card)
	add_child(rank_card)
	# 两栏列表
	title_box = _make_column("称 号", vs.x * 0.5 - 940, 356 + oy, 620)
	char_box = _make_column("武 将 解 锁", vs.x * 0.5 + 60, 356 + oy, 620)
	hint_lbl = UiKit.label("", 20, Color(0.8, 0.74, 0.66, 0.85), false, 3)
	hint_lbl.position = Vector2(vs.x * 0.5 - 700, vs.y - 58)
	add_child(hint_lbl)
	var back := UiKit.button("返 回 主 菜 单", func(): Game.goto("title"), 34, 340)
	back.position = Vector2(vs.x * 0.5 - 170, vs.y - 96)
	add_child(back)
	back.call_deferred("grab_focus")
	_refresh()
	Sfx.play_music("bgm_title", 1.0, -4.0)


func _make_column(title: String, x: float, y: float, w: float) -> VBoxContainer:
	var lbl := UiKit.label(title, 32, Color(1, 0.86, 0.5), true, 6)
	lbl.position = Vector2(x, y - 46)
	add_child(lbl)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.78))
	panel.position = Vector2(x, y)
	panel.custom_minimum_size = Vector2(w, 470)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(w - 20, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(w - 40, 0)
	scroll.add_child(vb)
	return vb


func _draw_rank_card() -> void:
	var c := rank_card
	var info := Progress.rank_info()
	var col: Color = info.get("color", Color.GRAY)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.04, 0.03, 0.72))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(col.r, col.g, col.b, 0.55), false, 3.0)
	var f: Font = Game.font_title
	var fu: Font = Game.font_ui
	# 段位大字
	c.draw_string_outline(f, Vector2(34, 86), str(info.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 62, 8, Color(0, 0, 0))
	c.draw_string(f, Vector2(34, 86), str(info.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 62, col)
	# 进度条
	var bx := 380.0
	var bw := 520.0
	var by := 46.0
	c.draw_rect(Rect2(bx, by, bw, 30), Color(0.12, 0.09, 0.07))
	var p: float = float(info.get("progress", 0.0))
	c.draw_rect(Rect2(bx, by, bw * clampf(p, 0.0, 1.0), 30), col)
	c.draw_rect(Rect2(bx, by, bw, 30), Color(0.8, 0.65, 0.38), false, 2.0)
	var pts := float(info.get("points", 0.0))
	var nx := str(info.get("next_text", ""))
	var line := "段位分 %d" % int(pts)
	if nx != "":
		line += "　·　距 %s 还差 %d" % [nx, maxi(0, int(ceil(float(info.get("next_at", pts)) - pts)))]
	c.draw_string(fu, Vector2(bx, by + 66), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.88, 0.8, 0.7))
	# 战绩
	var st: Dictionary = Progress.state
	var stat := "胜 %d　败 %d　最高连胜 %d　最佳评价 %s" % [
		int(st.get("wins", 0)), int(st.get("losses", 0)), int(st.get("best_streak", 0)),
		(str(st.get("best_grade", "")) if str(st.get("best_grade", "")) != "" else "—")]
	c.draw_string(fu, Vector2(34, 136), stat, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.82, 0.76, 0.68))


func _refresh() -> void:
	medal_lbl.text = "奖章 %d　（累计获得 %d）" % [int(Progress.state.get("medals", 0)), int(Progress.state.get("medals_total", 0))]
	rank_card.queue_redraw()
	for b in title_box.get_children():
		b.queue_free()
	for b in char_box.get_children():
		b.queue_free()
	# 称号
	var equipped := str(Progress.state.get("title", ""))
	for tt in Progress.titles():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var unlocked: bool = tt["unlocked"]
		var col := Color(1, 0.9, 0.6) if unlocked else Color(0.62, 0.58, 0.52)
		var nm := UiKit.label(str(tt["name"]), 26, col, true, 4)
		nm.custom_minimum_size = Vector2(150, 0)
		h.add_child(nm)
		var d := UiKit.label(str(tt["desc"]), 17, Color(0.68, 0.62, 0.55), false, 2)
		d.custom_minimum_size = Vector2(250, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(d)
		var tid := str(tt["id"])
		if unlocked:
			if equipped == tid:
				var tag := UiKit.label("佩戴中", 20, Color(0.6, 0.95, 0.6), true, 3)
				tag.custom_minimum_size = Vector2(110, 0)
				h.add_child(tag)
			else:
				var b := UiKit.button("佩 戴", func(): Progress.equip_title(tid); _refresh(), 20, 110)
				h.add_child(b)
		else:
			if float(tt["cost"]) > 0:
				var b2 := UiKit.button("%d 奖章" % int(tt["cost"]), func():
					var r := Progress.buy_title(tid)
					if r.get("ok", false):
						Sfx.play("ui_confirm", -4.0)
						_refresh()
					else:
						hint_lbl.text = str(r.get("error", ""))
						Sfx.play("ui_click", -6.0), 20, 130)
				h.add_child(b2)
			else:
				var lk := UiKit.label("未达成", 20, Color(0.55, 0.5, 0.45), false, 2)
				lk.custom_minimum_size = Vector2(110, 0)
				h.add_child(lk)
		title_box.add_child(h)
	# 武将解锁
	for cid in Roster.ids():
		var id: String = cid
		var d := Roster.get_def(id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var unlocked := Progress.is_char_unlocked(id)
		var nm := UiKit.label(str(d.get("name", id)), 26, Color(1, 0.9, 0.6) if unlocked else Color(0.62, 0.58, 0.52), true, 4)
		nm.custom_minimum_size = Vector2(120, 0)
		h.add_child(nm)
		var ep := UiKit.label(str(d.get("epithet", "")), 17, Color(0.68, 0.62, 0.55), false, 2)
		ep.custom_minimum_size = Vector2(250, 0)
		h.add_child(ep)
		if unlocked:
			var tag := UiKit.label("已解锁", 20, Color(0.6, 0.95, 0.6), true, 3)
			tag.custom_minimum_size = Vector2(110, 0)
			h.add_child(tag)
		else:
			var price := Progress.char_price(id)
			var b := UiKit.button("%d 奖章" % price, func():
				var r := Progress.buy_char(id)
				if r.get("ok", false):
					Sfx.play("ui_confirm", -4.0)
					_refresh()
				else:
					hint_lbl.text = str(r.get("error", ""))
					Sfx.play("ui_click", -6.0), 20, 130)
			h.add_child(b)
		char_box.add_child(h)


func _process(delta: float) -> void:
	t += delta
	rank_card.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.goto("title")
