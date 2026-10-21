extends Control
## 标题：虎牢关缓慢推镜，两员大将对峙，书法大字，菜单。

var bg: TextureRect
var t := 0.0
var left_id := "zhaoyun"
var right_id := "lvbu"
var left_spr: Sprite2D
var right_spr: Sprite2D
var menu: VBoxContainer
var settings_box: PanelContainer
var title_node: Control
var motes: CPUParticles2D
var base_scale := {}
var _bg_base_pos := Vector2.ZERO
var hint_lbl: Label
var credit_lbl: Label
var rank_lbl: Label


## 底图铺满视口：等比放大到完全覆盖，多出的部分居中裁掉。
## 留 1.06 的余量给推镜位移，避免移动时露边。
func _cover_bg() -> void:
	if bg == null or bg.texture == null:
		return
	var r := Game.cover_rect(bg.texture.get_size(), 1.06)
	bg.size = r.size
	bg.position = r.position
	_bg_base_pos = r.position


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var pool: Array = []
	for id in Roster.ids():
		if Progress.is_char_unlocked(id):
			pool.append(id)
	if pool.size() < 2:
		pool = Roster.ids()
	pool.shuffle()
	left_id = pool[0]
	right_id = pool[1]
	if randf() < 0.4 and Progress.is_char_unlocked("lvbu") and left_id != "lvbu":
		right_id = "lvbu"
	bg = TextureRect.new()
	var bg_path: String = Cfg.arena().get("map", "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	# 铺满视口（宽屏下比 1920 更宽），多出的部分居中裁掉，避免右侧露黑
	_cover_bg()
	bg.modulate = Color(0.75, 0.68, 0.62)
	add_child(bg)
	# 上下压暗：用渐变贴图，避免一条条色带
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.0, 0.35))
	grad.add_point(0.45, Color(0.02, 0.01, 0.0, 0.05))
	grad.set_color(grad.get_point_count() - 1, Color(0.02, 0.01, 0.0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	motes = CPUParticles2D.new()
	motes.amount = 70
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(1000, 560)
	motes.position = Game.view_size() * 0.5
	motes.direction = Vector2(1, -0.2)
	motes.spread = 30.0
	motes.gravity = Vector2(0, -6)
	motes.initial_velocity_min = 15.0
	motes.initial_velocity_max = 45.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 4.0
	motes.color = Color(1.0, 0.85, 0.6, 0.45)
	add_child(motes)
	# 两侧立像贴着视口边缘站（宽屏下视口比 1920 更宽，不能写死 1590）
	var vs := Game.view_size()
	left_spr = _hero(left_id, false, Vector2(330, vs.y - 70), 1)
	right_spr = _hero(right_id, true, Vector2(vs.x - 330, vs.y - 70), -1)
	title_node = Control.new()
	title_node.position = Vector2(Game.view_size().x * 0.5, 300 + Game.ui_offset_y())
	title_node.draw.connect(_draw_title)
	add_child(title_node)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu.position = Vector2(Game.view_size().x * 0.5 - 190, 536 + Game.ui_offset_y())
	add_child(menu)
	var b1 := UiKit.button("单挑斗将", func():
		Game.mode = Game.Mode.DUEL
		Game.goto("select"), 44, 380)
	menu.add_child(b1)
	menu.add_child(UiKit.button("观战擂台", func():
		Game.mode = Game.Mode.WATCH
		Game.goto("select"), 44, 380))
	menu.add_child(UiKit.button("战　绩", func(): Game.goto("profile"), 44, 380))
	menu.add_child(UiKit.button("设　置", _toggle_settings, 44, 380))
	# 微信小游戏没有"退出游戏"这个概念（退出由平台胶囊按钮负责），
	# 桌面上才给这个按钮。
	if not Game.touch_ui:
		menu.add_child(UiKit.button("退　出", func(): get_tree().quit(), 44, 380))
	b1.call_deferred("grab_focus")
	var hint_text := "左摇杆移动 · 推到底疾跑 · 轻 连招 · 重 按住蓄力 · 挡 看准拆招 · 闪 闪避/纵马 · 绝 绝技"
	if not Game.touch_ui:
		hint_text = "WASD 移动 · J 轻击 · K 重击(按住蓄力) · L 格挡/拆招 · 空格 闪避/纵马 · Shift 疾跑 · I 跳 · U 绝技"
	hint_lbl = UiKit.label(hint_text, 24, Color(0.9, 0.82, 0.7, 0.8), false, 4)
	hint_lbl.position = Vector2(Game.view_size().x * 0.5 - 560, Game.view_size().y - 80)
	add_child(hint_lbl)
	rank_lbl = UiKit.label("", 28, Color(1.0, 0.86, 0.5), true, 6)
	rank_lbl.position = Vector2(Game.view_size().x * 0.5 - 300, 500 + Game.ui_offset_y())
	rank_lbl.size = Vector2(600, 44)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(rank_lbl)
	_refresh_rank()
	if not Progress.last_decay.is_empty():
		var d: Dictionary = Progress.last_decay
		var decay_lbl := UiKit.label("久未出阵，段位由 %s 降至 %s" % [d.get("from_text", ""), d.get("to_text", "")], 24, Color(1.0, 0.7, 0.5), false, 4)
		decay_lbl.position = Vector2(Game.view_size().x * 0.5 - 500, 548 + Game.ui_offset_y())
		decay_lbl.size = Vector2(1000, 40)
		decay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(decay_lbl)
		Progress.last_decay = {}
	credit_lbl = UiKit.label("音乐：Imperial China Cinematic / The Fall Of Heroes — Shane Ivers (silvermansound.com, CC BY 4.0) · Horde War Drums — William Hector (CC0)", 16, Color(0.85, 0.78, 0.66, 0.6), false, 0)
	credit_lbl.position = Vector2(20, Game.view_size().y - 30)
	add_child(credit_lbl)
	_build_settings()
	Sfx.stop_all_ambient()
	Sfx.ambient("wind_amb", true, -22.0)
	Sfx.play_music("bgm_title", 1.2, -3.0)


## 视口尺寸变化（微信 canvas 会异步 resize）时重排，避免仍按旧尺寸排版留下空白
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout()


func _layout() -> void:
	var vs := Game.view_size()
	var oy := Game.ui_offset_y()   # 视口比 16:9 更高时（4:3 横屏）整体下移
	_cover_bg()
	if bg:
		bg.position = _bg_base_pos
	if motes:
		motes.position = vs * 0.5
	if left_spr:
		left_spr.position = Vector2(330, vs.y - 70)
	if right_spr:
		right_spr.position = Vector2(vs.x - 330, vs.y - 70)
	if title_node:
		title_node.position = Vector2(vs.x * 0.5, 300 + oy)
	if menu:
		menu.position = Vector2(vs.x * 0.5 - 190, 536 + oy)
	if settings_box:
		settings_box.position = Vector2(vs.x * 0.5 - 400, 300 + oy)
	if rank_lbl:
		rank_lbl.position = Vector2(vs.x * 0.5 - 300, 500 + oy)
	if hint_lbl:
		hint_lbl.position = Vector2(vs.x * 0.5 - 560, vs.y - 80)
	if credit_lbl:
		credit_lbl.position = Vector2(20, vs.y - 30)


func _hero(id: String, prefer_mount: bool, pos: Vector2, facing: int) -> Sprite2D:
	var mounted := prefer_mount and Bank.has_stance(id, true)
	if not Bank.has_stance(id, false):
		mounted = true
	var p := Bank.pose(id, mounted, "idle")
	var s := Sprite2D.new()
	s.texture = p["tex"]
	s.centered = false
	s.offset = -p["anchor"]
	var sc := Bank.base_scale(id, mounted) * (3.0 if not mounted else 2.4)
	s.scale = Vector2(sc * facing, sc)
	s.position = pos
	base_scale[s] = sc
	add_child(s)
	# 影子
	var sh := Node2D.new()
	sh.set_script(preload("res://scripts/battle/fx/shadow_blob.gd"))
	sh.set("radius", 120.0)
	sh.position = pos
	add_child(sh)
	move_child(sh, s.get_index())
	return s


func _draw_title() -> void:
	var c := title_node
	var f: Font = Game.font_brush
	var k: float = clamp(t / 0.8, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	# 墨迹
	var brush := PackedVector2Array()
	for i in 32:
		var u := float(i) / 31.0
		brush.append(Vector2(lerp(-640.0, 640.0, u) * e, -120.0 + sin(u * 37.0 + 1.0) * 14.0))
	for i in 32:
		var u := 1.0 - float(i) / 31.0
		brush.append(Vector2(lerp(-640.0, 640.0, u) * e, 110.0 + cos(u * 29.0) * 16.0))
	c.draw_colored_polygon(brush, Color(0.06, 0.03, 0.02, 0.82))
	var text := Cfg.ui_text("title", "斗战三国")
	var size := 190
	var spacing := 26.0
	var total := 0.0
	var ws: Array = []
	for i in text.length():
		var w := f.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ws.append(w)
		total += w
	total += spacing * (text.length() - 1)
	var x := -total * 0.5
	for i in text.length():
		var ck: float = clamp((t - 0.15 * i) / 0.35, 0.0, 1.0)
		var s := lerpf(1.8, 1.0, 1.0 - pow(1.0 - ck, 3.0))
		var y := sin(t * 1.4 + i) * 4.0
		c.draw_set_transform(Vector2(x + ws[i] * 0.5, y), 0.0, Vector2(s, s))
		var pos := Vector2(-ws[i] * 0.5, size * 0.34)
		c.draw_string_outline(f, pos, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 18, Color(0.25, 0.03, 0.01, ck))
		c.draw_string(f, pos, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.86, 0.45, ck))
		x += ws[i] + spacing
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sub := Cfg.ui_text("subtitle", "虎牢关 · 斗将")
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	var sa: float = clamp((t - 0.8) / 0.5, 0.0, 1.0)
	c.draw_string_outline(f, Vector2(-sw * 0.5, 175), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 10, Color(0, 0, 0, sa))
	c.draw_string(f, Vector2(-sw * 0.5, 175), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(1.0, 0.93, 0.8, sa))
	# 印章
	var seal_a: float = clamp((t - 1.1) / 0.3, 0.0, 1.0)
	c.draw_rect(Rect2(560, -100, 92, 92), Color(0.65, 0.08, 0.05, 0.9 * seal_a))
	var s1 := "斗将"
	var s1w := f.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	c.draw_string(f, Vector2(606 - s1w * 0.5, -40), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 0.9, 0.75, seal_a))


func _process(delta: float) -> void:
	t += delta
	var k := sin(t * 0.08)
	if bg:
		var base := _bg_base_pos
		bg.position = base + Vector2(k * 60.0, cos(t * 0.06) * 25.0)
	for s in [left_spr, right_spr]:
		if s:
			var br := sin(t * 2.6 + (0.0 if s == left_spr else 1.5)) * 0.015
			var base: float = base_scale.get(s, absf(s.scale.y))
			s.scale.y = base * (1.0 + br)
	title_node.queue_redraw()


func _build_settings() -> void:
	settings_box = PanelContainer.new()
	settings_box.add_theme_stylebox_override("panel", UiKit.panel_style(0.94))
	settings_box.position = Vector2(Game.view_size().x * 0.5 - 400, 300 + Game.ui_offset_y())
	settings_box.custom_minimum_size = Vector2(800, 0)
	settings_box.visible = false
	add_child(settings_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	settings_box.add_child(v)
	v.add_child(UiKit.label("设 置", 56, Color(1.0, 0.85, 0.45), true, 8))
	v.add_child(_slider("音乐音量", Game.music_volume, func(x):
		Game.music_volume = x
		Game.save_settings()))
	v.add_child(_slider("音效音量", Game.sfx_volume, func(x):
		Game.sfx_volume = x
		Game.save_settings()))
	v.add_child(_slider("震屏强度", Game.screen_shake, func(x):
		Game.screen_shake = x
		Game.save_settings()))
	var dn := CheckBox.new()
	dn.text = "显示伤害数字"
	dn.button_pressed = Game.show_damage_numbers
	dn.add_theme_font_override("font", Game.font_title)
	dn.add_theme_font_size_override("font_size", 32)
	dn.toggled.connect(func(on):
		Game.show_damage_numbers = on
		Game.save_settings())
	v.add_child(dn)
	v.add_child(UiKit.button("返　回", _toggle_settings, 36, 300))


func _slider(text: String, val: float, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := UiKit.label(text, 32, UiKit.PAPER, true, 4)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(460, 40)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h


func _refresh_rank() -> void:
	var info := Progress.rank_info()
	var tt := Progress.title_name()
	var txt := "段位 %s　·　奖章 %d" % [str(info.get("text", "")), int(Progress.state.get("medals", 0))]
	if tt != "":
		txt += "　·　「%s」" % tt
	rank_lbl.text = txt
	rank_lbl.add_theme_color_override("font_color", info.get("color", Color(1.0, 0.86, 0.5)))


func _toggle_settings() -> void:
	settings_box.visible = not settings_box.visible
	menu.visible = not settings_box.visible
	if menu.visible:
		for c in menu.get_children():
			if c is Button and c.text == "设　置":
				c.grab_focus()
				break
