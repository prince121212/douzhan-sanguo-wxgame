extends CanvasLayer
## 战后结算：胜者大印、战况一句话、双方数据、按钮（单挑）或倒计时（观战）。

var battle: Node
var winner: Fighter
var loser: Fighter
var by_time := false
var root: Control
var t := 0.0
var countdown_lbl: Label


func setup(b: Node, w: Fighter, l: Fighter, timeout: bool) -> void:
	battle = b
	winner = w
	loser = l
	by_time = timeout


func _ready() -> void:
	layer = 25
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	create_tween().set_ignore_time_scale(true).tween_property(shade, "color:a", 0.5, 0.6)
	# 胜者大印
	var seal := Control.new()
	var ox := Game.ui_offset_x()
	var oy := Game.ui_offset_y()
	seal.position = Vector2(560 + ox, 300 + oy)
	seal.draw.connect(func():
		seal.draw_circle(Vector2.ZERO, 150.0, Color(0.6, 0.06, 0.04, 0.95))
		seal.draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 64, UiKit.GOLD, 8.0)
		seal.draw_arc(Vector2.ZERO, 128.0, 0.0, TAU, 64, Color(1, 0.8, 0.4, 0.6), 3.0)
		var f: Font = Game.font_brush
		var w := f.get_string_size("胜", HORIZONTAL_ALIGNMENT_LEFT, -1, 200).x
		seal.draw_string_outline(f, Vector2(-w * 0.5, 70), "胜", HORIZONTAL_ALIGNMENT_LEFT, -1, 200, 14, Color(0.2, 0.02, 0.0))
		seal.draw_string(f, Vector2(-w * 0.5, 70), "胜", HORIZONTAL_ALIGNMENT_LEFT, -1, 200, Color(1.0, 0.92, 0.72)))
	root.add_child(seal)
	seal.scale = Vector2(2.4, 2.4)
	seal.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(seal, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(seal, "modulate:a", 1.0, 0.2)
	tw.chain().tween_callback(func():
		Sfx.play("drum", 0.0, 1.0)
		battle.cam.shake(0.3))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.panel_style(0.88))
	box.position = Vector2(760 + ox, 170 + oy)
	box.custom_minimum_size = Vector2(1000, 0)
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	v.add_child(UiKit.label("%s %s" % [winner.def["call"], "胜"], 66, Color(1.0, 0.88, 0.5), true, 10))
	var how := ""
	if by_time:
		how = "鸣金收兵，%s以体力占优取胜。" % winner.def["name"]
	elif loser.mounted:
		how = "%s与%s大战%d合，斩%s于马下！" % [winner.def["name"], loser.def["name"], max(1, battle.round_count), loser.def["name"]]
	else:
		how = "%s与%s大战%d合，终将%s击倒！" % [winner.def["name"], loser.def["name"], max(1, battle.round_count), loser.def["name"]]
	v.add_child(UiKit.label(how, 34, UiKit.PAPER, true, 6))
	if battle.rounds_to_win > 1:
		v.add_child(UiKit.label("局分  %s %d : %d %s" % [battle.f1.def["name"], battle.wins[0], battle.wins[1], battle.f2.def["name"]], 28, Color(1, 0.85, 0.6), false, 4))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var a: Fighter = battle.f1
	var b2: Fighter = battle.f2
	grid.add_child(UiKit.label("", 26))
	grid.add_child(UiKit.label(a.def["name"], 34, a.theme_color.lerp(Color.WHITE, 0.4)))
	grid.add_child(UiKit.label(b2.def["name"], 34, b2.theme_color.lerp(Color.WHITE, 0.4)))
	var rows := [["命中", "hits"], ["最大连击", "max_combo"], ["拆招", "parries"], ["闪避", "dodges"], ["拼刀胜", "clash_win"], ["绝技", "ults"], ["伤害", "dmg"]]
	for r in rows:
		grid.add_child(UiKit.label(r[0], 28, Color(0.85, 0.75, 0.6), false, 4))
		grid.add_child(UiKit.label(str(int(a.stats[r[1]])), 30, UiKit.PAPER, false, 4))
		grid.add_child(UiKit.label(str(int(b2.stats[r[1]])), 30, UiKit.PAPER, false, 4))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	v.add_child(hb)
	if battle.player_side >= 0:
		var b_again := UiKit.button("再 战", func(): Game.goto("battle"), 36, 220)
		hb.add_child(b_again)
		hb.add_child(UiKit.button("换 将", func(): Game.goto("select"), 36, 220))
		hb.add_child(UiKit.button("主菜单", func(): Game.goto("title"), 36, 220))
		b_again.call_deferred("grab_focus")
	else:
		countdown_lbl = UiKit.label("", 30, Color(1, 0.85, 0.5), true, 6)
		v.add_child(countdown_lbl)
		var b_next := UiKit.button("下一阵", func(): battle._next_watch_match(), 36, 240)
		hb.add_child(b_next)
		hb.add_child(UiKit.button("返回选单", func(): Game.goto("title"), 36, 240))
	box.modulate.a = 0.0
	create_tween().set_ignore_time_scale(true).tween_property(box, "modulate:a", 1.0, 0.5).set_delay(0.3)
	if battle.player_side >= 0:
		get_tree().create_timer(2.5, true, false, true).timeout.connect(func(): Sfx.play_music("bgm_title", 3.0, -8.0))


func _process(delta: float) -> void:
	t += delta / max(0.0001, Engine.time_scale)
	if countdown_lbl:
		var left: float = max(0.0, battle.autoplay_next_t)
		if Game.watch_rule == "arena":
			var streak: int = Game.champion_streak + 1 if Game.champion_id == winner.id else 1
			countdown_lbl.text = "擂主 %s 已连胜 %d 阵　·　%d 秒后下一位挑战者登场" % [winner.def["name"], streak, int(ceil(left))]
		else:
			countdown_lbl.text = "%d 秒后开始下一阵" % int(ceil(left))
