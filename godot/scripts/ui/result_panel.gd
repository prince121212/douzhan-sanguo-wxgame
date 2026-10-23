extends CanvasLayer
## 战后结算。
## 版式（单挑 / 观战统一）：中间留出空档给胜者欢呼镜头，
##   左栏 评价大字印（分数 / 评价名 / 奖章），右栏 五项评分明细，
##   底栏 单挑=段位进度（+晋升），观战=擂台连胜 + 下一阵倒计时。
## 单挑的分数/段位/奖章由 Progress 算好传进来；观战没有存档，
## 现场用 Progress.evaluate 按胜者数据算一份只读的评价（不计奖章、不改段位）。

var battle: Node
var winner: Fighter
var loser: Fighter
var by_time := false
var summary: Dictionary = {}     # Progress.record_match 的返回值（观战时为空）

var root: Control
var canvas: Control
var t := 0.0
var is_watch := false           # 观战结算：没有 Progress 存档，但同样走「评分」版式
var eval_res: Dictionary = {}   # 单挑取 summary.eval；观战现场按胜者数据算一份
var streak := 1                 # 擂台连胜（观战）

# 动画量
var g_anim := 0.0            # 评价印出现 0→1
var ring_rot := 0.0
var pulse := 0.0
var score_shown := 0.0       # 总分滚动
var b0 := 0.0
var b1 := 0.0
var b2 := 0.0
var b3 := 0.0
var b4 := 0.0
var rank_anim := 0.0
var medal_anim := 0.0
var title_anim := 0.0
var flash_a := 0.0

const ROW_LABELS := ["剩余血量", "用时", "技术", "最高连击", "终结方式"]
const ROW_KEYS := ["hp", "time", "skill", "combo", "finish"]
const ROW_HINTS := ["保住的体力", "打得越快越高", "拆招 / 闪避 / 拼刀", "最高连段", "击倒才算满分"]


func setup(b: Node, w: Fighter, l: Fighter, timeout: bool, s: Dictionary = {}) -> void:
	battle = b
	winner = w
	loser = l
	by_time = timeout
	summary = s


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
	create_tween().set_ignore_time_scale(true).tween_property(shade, "color:a", 0.18, 0.55)
	# 顶部 / 底部渐变：只有放字的地方压暗，中间整条留给胜者欢呼
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.82))
	grad.set_color(1, Color(0, 0, 0, 0.82))
	grad.add_point(0.17, Color(0, 0, 0, 0.50))
	grad.add_point(0.30, Color(0, 0, 0, 0.0))
	grad.add_point(0.60, Color(0, 0, 0, 0.0))
	grad.add_point(0.72, Color(0, 0, 0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.modulate.a = 0.0
	root.add_child(band)
	create_tween().set_ignore_time_scale(true).tween_property(band, "modulate:a", 1.0, 0.55)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_all)
	root.add_child(canvas)

	is_watch = summary.is_empty()
	if is_watch:
		var dur: float = battle.match_elapsed + maxf(0.0, battle.game_time - battle.match_start_time)
		eval_res = Progress.evaluate(winner.stats, winner.hp / maxf(1.0, winner.max_hp), dur, by_time)
		streak = Game.champion_streak + 1 if Game.champion_id == winner.id else 1
	else:
		eval_res = summary.get("eval", {})
	_build_top()
	_animate()


# ---------------------------------------------------------------- 顶部标题 + 按钮

func _build_top() -> void:
	var vs := Game.view_size()
	var win := _is_win()
	# 顶部：谁赢了 + 一句话（单挑 / 观战共用）
	var head := "%s 胜" % winner.def["call"] if win else "%s 败" % loser.def["call"]
	var who := UiKit.label(head, 64,
		Color(1.0, 0.88, 0.5) if win else Color(0.75, 0.82, 0.95), true, 10)
	who.position = Vector2(vs.x * 0.5 - 600, vs.y * 0.045)
	who.size = Vector2(1200, 90)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(who)
	var sub := UiKit.label(_how_text(win), 30, Color(0.92, 0.85, 0.74), false, 5)
	sub.position = Vector2(vs.x * 0.5 - 700, vs.y * 0.045 + 88)
	sub.size = Vector2(1400, 46)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	# 按钮：观战只有「下一阵 / 返回选单」，单挑是四个
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	root.add_child(hb)
	var b_again: Button = null
	if is_watch:
		var bw := 240.0
		hb.position = Vector2(vs.x * 0.5 - bw - 12, vs.y * 0.875)
		b_again = UiKit.button("下一阵", func(): battle._next_watch_match(), 36, bw)
		hb.add_child(b_again)
		hb.add_child(UiKit.button("返回选单", func(): Game.goto("title"), 36, bw))
	else:
		hb.position = Vector2(vs.x * 0.5 - 436, vs.y * 0.875)
		b_again = UiKit.button("再 战", func(): Game.goto("battle"), 36, 200)
		hb.add_child(b_again)
		hb.add_child(UiKit.button("换 将", func(): Game.goto("select"), 36, 200))
		hb.add_child(UiKit.button("主菜单", func(): Game.goto("title"), 36, 200))
		hb.add_child(UiKit.button("成 就", func(): Game.goto("profile"), 36, 200))
	b_again.call_deferred("grab_focus")
	if win:
		get_tree().create_timer(0.6, true, false, true).timeout.connect(func(): Sfx.play("drum_big", 0.0))
	else:
		get_tree().create_timer(0.4, true, false, true).timeout.connect(func(): Sfx.play("ko", -2.0))
	get_tree().create_timer(2.6, true, false, true).timeout.connect(func(): Sfx.play_music("bgm_title", 3.0, -8.0))


func _how_text(win: bool) -> String:
	if not win:
		return "胜败乃兵家常事，整军再战便是。"
	if by_time:
		if is_watch:
			return "鸣金收兵，%s以体力占优取胜。" % winner.def["name"]
		return "鸣金收兵，以体力占优取胜（超时判胜，评价受限）。"
	if is_watch:
		if loser.mounted:
			return "%s与%s大战%d合，斩%s于马下！" % [winner.def["name"], loser.def["name"], max(1, battle.round_count), loser.def["name"]]
		return "%s与%s大战%d合，终将%s击倒！" % [winner.def["name"], loser.def["name"], max(1, battle.round_count), loser.def["name"]]
	if loser.mounted:
		return "大战 %d 合，斩 %s 于马下！" % [max(1, battle.round_count), loser.def["name"]]
	return "大战 %d 合，终将 %s 击倒！" % [max(1, battle.round_count), loser.def["name"]]


func _is_win() -> bool:
	return is_watch or bool(summary.get("is_win", true))


# ---------------------------------------------------------------- 动画驱动

func _animate() -> void:
	var win := _is_win()
	# 每个属性各起一条 tween（用 delay 错开），避免 chain 与 parallel 混用出错
	if win:
		_tw(self, "g_anim", 1.0, 0.5, 0.15, Tween.TRANS_BACK, Tween.EASE_OUT)
		_tw(self, "flash_a", 1.0, 0.08, 0.15)
		_tw(self, "flash_a", 0.0, 0.5, 0.26)
		var total: float = float(eval_res.get("total", 0.0))
		_tw(self, "score_shown", total, 1.1, 0.35, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		var names := ["b0", "b1", "b2", "b3", "b4"]
		for i in 5:
			_tw(self, names[i], 1.0, 0.75, 0.55 + i * 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		_tw(self, "rank_anim", 1.0, 0.9, 0.9, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		_tw(self, "medal_anim", 1.0, 0.6, 1.15, Tween.TRANS_BACK, Tween.EASE_OUT)
		_tw(self, "title_anim", 1.0, 0.5, 1.5, Tween.TRANS_BACK, Tween.EASE_OUT)
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Sfx.play("victory_drums", -3.0))
	else:
		_tw(self, "g_anim", 1.0, 0.55, 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		_tw(self, "rank_anim", 1.0, 0.6, 0.4)


func _tw(obj: Object, prop: String, to: Variant, dur: float, delay := 0.0, trans := Tween.TRANS_LINEAR, ease := Tween.EASE_IN_OUT) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(obj, prop, to, dur).set_trans(trans).set_ease(ease).set_delay(delay)


func _process(delta: float) -> void:
	t += delta / maxf(0.0001, Engine.time_scale)
	ring_rot += delta * 0.35
	pulse = 0.5 + 0.5 * sin(t * 2.2)
	canvas.queue_redraw()


# ---------------------------------------------------------------- 绘制

func _draw_all() -> void:
	var win := _is_win()
	var vs := Game.view_size()
	var vw := vs.x
	var vh := vs.y
	# 左右两栏各自贴着屏幕边缘，中间空档宽度随屏幕变化（宽屏更宽，正好给欢呼镜头）
	var cx := vw * 0.02 + 280.0
	var cy := vh * 0.365
	# 左栏底板：只压住左栏，中间整条留给胜者（跟着入场动画一起淡入）
	var pa := clampf(g_anim, 0.0, 1.0)
	canvas.draw_rect(Rect2(cx - 232, cy - 200, 464, 492), Color(0.04, 0.03, 0.02, 0.80 * pa))
	canvas.draw_rect(Rect2(cx - 232, cy - 200, 464, 492), Color(0.85, 0.7, 0.4, 0.22 * pa), false, 2.0)
	if win:
		_draw_grade(cx, cy)
		_draw_breakdown(vw, vh, win)
	else:
		_draw_defeat(cx, cy)
		_draw_loss_stats(vw, vh)
	if is_watch:
		_draw_watch_bar(vw, vh)
	else:
		_draw_rank(vw, vh)
	_draw_medals(cx, cy, win)
	if flash_a > 0.001:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.95, 0.8, flash_a * 0.55))


func _draw_grade(cx: float, cy: float) -> void:
	var ev: Dictionary = eval_res
	var gid := str(ev.get("grade", "C"))
	var col: Color = Progress.grade_color(gid)
	var r := 128.0
	var s := lerpf(2.2, 1.0, g_anim)
	var a := clampf(g_anim, 0.0, 1.0)
	canvas.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(s, s))
	# 外发光
	for i in 4:
		var rr := r + 10.0 + i * 14.0
		canvas.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 72, Color(col.r, col.g, col.b, 0.10 * a * (1.0 - i / 4.0)), 3.0)
	# 主盘
	canvas.draw_circle(Vector2.ZERO, r, Color(0.06, 0.04, 0.03, 0.92 * a))
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(col.r, col.g, col.b, a), 7.0)
	canvas.draw_arc(Vector2.ZERO, r - 14.0, 0.0, TAU, 96, Color(col.r, col.g, col.b, 0.35 * a), 2.0)
	# 旋转刻度环
	for i in 36:
		var ang := ring_rot + TAU * float(i) / 36.0
		var l := 10.0 if i % 3 == 0 else 5.0
		var p1 := Vector2(cos(ang), sin(ang)) * (r + 6.0)
		var p2 := Vector2(cos(ang), sin(ang)) * (r + 6.0 + l)
		canvas.draw_line(p1, p2, Color(col.r, col.g, col.b, 0.5 * a), 2.0)
	# 评价字
	var f: Font = Game.font_brush
	var size := 210 if gid.length() <= 1 else (150 if gid.length() == 2 else 120)
	var tw := f.get_string_size(gid, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string_outline(f, Vector2(-tw * 0.5, size * 0.34), gid, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0, 0, 0, a))
	canvas.draw_string(f, Vector2(-tw * 0.5, size * 0.34), gid, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, a))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 评价名 + 说明
	var gn: String = Progress.grade_name(gid)
	var gd: String = Progress.grade_desc(gid)
	var fn: Font = Game.font_title
	var gy := cy + r + 44
	if gn != gid:
		var w1 := fn.get_string_size(gn, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		canvas.draw_string(fn, Vector2(cx - w1 * 0.5, gy), gn, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 0.93, 0.8, a))
		gy += 34
	var w2 := fn.get_string_size(gd, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	canvas.draw_string(fn, Vector2(cx - w2 * 0.5, gy), gd, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.82, 0.7, 0.85 * a))
	# 总分
	var total_txt := "%.1f" % score_shown
	var fbig: Font = Game.font_title
	var ws := fbig.get_string_size(total_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x
	var suffix := " 分"
	var wsf := fbig.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var bx := cx - (ws + wsf) * 0.5
	var ty := cy - r - 30
	canvas.draw_string_outline(fbig, Vector2(bx, ty), total_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, 8, Color(0, 0, 0, a))
	canvas.draw_string(fbig, Vector2(bx, ty), total_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(1.0, 0.9, 0.6, a))
	canvas.draw_string(fbig, Vector2(bx + ws, ty), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.82, 0.7, 0.9 * a))
	if bool(ev.get("capped_by_time", false)):
		var cap := "超时判胜 · 评价封顶"
		var wc := fn.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		canvas.draw_string(fn, Vector2(cx - wc * 0.5, cy + r + 114), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1, 0.7, 0.45, 0.9 * a))


func _draw_defeat(cx: float, cy: float) -> void:
	var r := 168.0
	var s := lerpf(1.8, 1.0, g_anim)
	var a := clampf(g_anim, 0.0, 1.0)
	var col := Color(0.55, 0.65, 0.8)
	canvas.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(s, s))
	canvas.draw_circle(Vector2.ZERO, r, Color(0.05, 0.05, 0.07, 0.92 * a))
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(col.r, col.g, col.b, 0.85 * a), 6.0)
	var f: Font = Game.font_brush
	var tw := f.get_string_size("败", HORIZONTAL_ALIGNMENT_LEFT, -1, 200).x
	canvas.draw_string_outline(f, Vector2(-tw * 0.5, 68), "败", HORIZONTAL_ALIGNMENT_LEFT, -1, 200, 12, Color(0, 0, 0, a))
	canvas.draw_string(f, Vector2(-tw * 0.5, 68), "败", HORIZONTAL_ALIGNMENT_LEFT, -1, 200, Color(col.r, col.g, col.b, a))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fn: Font = Game.font_title
	var txt := "未获积分 · 段位不变"
	var w := fn.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	canvas.draw_string(fn, Vector2(cx - w * 0.5, cy + r + 60), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.88, 0.85, 0.8, a))


func _draw_breakdown(vw: float, vh: float, win: bool) -> void:
	var ev: Dictionary = eval_res
	if not win or ev.is_empty():
		return
	var parts: Dictionary = ev.get("parts", {})
	var caps: Dictionary = ev.get("caps", {})
	var x := vw * 0.98 - 630.0
	var y := vh * 0.175
	var w := 600.0
	var f: Font = Game.font_title
	var fu: Font = Game.font_ui
	var a := clampf(g_anim, 0.0, 1.0)
	canvas.draw_rect(Rect2(x - 30, y - 56, w + 60, 404), Color(0.05, 0.04, 0.03, 0.80 * a))
	canvas.draw_rect(Rect2(x - 30, y - 56, w + 60, 404), Color(0.85, 0.7, 0.4, 0.35 * a), false, 2.0)
	canvas.draw_string(f, Vector2(x, y - 16), "战 报 明 细", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.86, 0.5, a))
	for i in 5:
		var ry := y + 14 + i * 68.0
		var key: String = ROW_KEYS[i]
		var got: float = float(parts.get(key, 0.0))
		var cap: float = maxf(0.001, float(caps.get(key, 1.0)))
		var anim: float = [b0, b1, b2, b3, b4][i]
		var frac: float = clampf(got / cap, 0.0, 1.0) * anim
		canvas.draw_string(f, Vector2(x, ry + 24), ROW_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.88, 0.76, a))
		canvas.draw_string(fu, Vector2(x, ry + 46), ROW_HINTS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.54, 0.46, 0.85 * a))
		var bx := x + 170.0
		var bw := 290.0
		canvas.draw_rect(Rect2(bx, ry + 4, bw, 24), Color(0.12, 0.09, 0.07, 0.9 * a))
		var col := Color(0.95, 0.75, 0.35)
		if key == "hp":
			col = Color(0.9, 0.35, 0.3)
		elif key == "time":
			col = Color(0.55, 0.8, 0.95)
		elif key == "skill":
			col = Color(0.65, 0.85, 0.6)
		elif key == "combo":
			col = Color(0.8, 0.6, 0.95)
		canvas.draw_rect(Rect2(bx, ry + 4, bw * frac, 24), Color(col.r, col.g, col.b, a))
		canvas.draw_rect(Rect2(bx, ry + 4, bw, 24), Color(0.75, 0.6, 0.35, 0.5 * a), false, 1.5)
		var vtxt := "%.1f / %d" % [got * anim, int(round(cap))]
		canvas.draw_string(f, Vector2(bx + bw + 14, ry + 26), vtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.9, 0.82, a))


func _draw_loss_stats(vw: float, vh: float) -> void:
	var me: Fighter = battle.f1
	var him: Fighter = battle.f2
	var x := vw * 0.98 - 630.0
	var y := vh * 0.175
	var w := 600.0
	var f: Font = Game.font_title
	var fu: Font = Game.font_ui
	var a := clampf(g_anim, 0.0, 1.0)
	canvas.draw_rect(Rect2(x - 30, y - 56, w + 60, 448), Color(0.05, 0.04, 0.03, 0.80 * a))
	canvas.draw_rect(Rect2(x - 30, y - 56, w + 60, 448), Color(0.85, 0.7, 0.4, 0.35 * a), false, 2.0)
	canvas.draw_string(f, Vector2(x, y - 16), "本 场 数 据", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.86, 0.5, a))
	var rows := [
		["命中次数", int(me.stats["hits"]), int(him.stats["hits"])],
		["最高连击", int(me.stats["max_combo"]), int(him.stats["max_combo"])],
		["成功拆招", int(me.stats["parries"]), int(him.stats["parries"])],
		["完美闪避", int(me.stats["dodges"]), int(him.stats["dodges"])],
		["拼刀获胜", int(me.stats["clash_win"]), int(him.stats["clash_win"])],
		["造成伤害", int(me.stats["dmg"]), int(him.stats["dmg"])],
	]
	canvas.draw_string(fu, Vector2(x + 300, y + 24), me.def["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.75, 0.7, a))
	canvas.draw_string(fu, Vector2(x + 450, y + 24), him.def["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.8, 0.95, a))
	for i in rows.size():
		var ry := y + 60 + i * 52.0
		canvas.draw_string(fu, Vector2(x, ry), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.84, 0.75, a))
		canvas.draw_string(f, Vector2(x + 300, ry), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.75, 0.7, a))
		canvas.draw_string(f, Vector2(x + 450, ry), str(rows[i][2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.7, 0.8, 0.95, a))
	var tip := "下次试试：多拆招、多闪避，血量和用时都会更好看"
	canvas.draw_string(fu, Vector2(x, y + 372), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.62, 0.56, 0.48, a))


func _draw_rank(vw: float, vh: float) -> void:
	var before: Dictionary = summary.get("rank_before", {})
	var after: Dictionary = summary.get("rank_after", before)
	var x := vw * 0.02
	var y := vh * 0.72
	var w := vw * 0.96
	var f: Font = Game.font_title
	var fu: Font = Game.font_ui
	var a := clampf(rank_anim, 0.0, 1.0)
	canvas.draw_rect(Rect2(x - 26, y - 34, w + 52, 132), Color(0.05, 0.04, 0.03, 0.80 * a))
	canvas.draw_rect(Rect2(x - 26, y - 34, w + 52, 132), Color(0.85, 0.7, 0.4, 0.3 * a), false, 2.0)
	canvas.draw_string(fu, Vector2(x, y + 4), "段 位", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.68, 0.58, a))
	var btext := str(before.get("text", "青铜 III"))
	var atext := str(after.get("text", btext))
	var bcol: Color = before.get("color", Color.GRAY)
	var acol: Color = after.get("color", bcol)
	canvas.draw_string(f, Vector2(x, y + 44), btext, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(bcol.r, bcol.g, bcol.b, a))
	# 进度条
	var bx := x + 300.0
	var bw := 560.0
	canvas.draw_rect(Rect2(bx, y + 14, bw, 26), Color(0.12, 0.09, 0.07, 0.9 * a))
	var p0: float = float(before.get("progress", 0.0))
	var p1: float = float(after.get("progress", p0))
	var same_seg: bool = int(before.get("index", 0)) == int(after.get("index", 0))
	var cur := p1
	if same_seg:
		cur = lerpf(p0, p1, clampf(rank_anim, 0.0, 1.0))
	else:
		cur = 1.0 if rank_anim < 0.5 else lerpf(0.0, p1, (rank_anim - 0.5) * 2.0)
	canvas.draw_rect(Rect2(bx, y + 14, bw * clampf(cur, 0.0, 1.0), 26), Color(acol.r, acol.g, acol.b, 0.95 * a))
	canvas.draw_rect(Rect2(bx, y + 14, bw, 26), Color(0.75, 0.6, 0.35, 0.5 * a), false, 1.5)
	var pts := float(after.get("points", 0.0))
	var nx := str(after.get("next_text", ""))
	var line := "段位分 %d" % int(pts)
	if nx != "":
		line += "　·　距 %s 还差 %d" % [nx, maxi(0, int(ceil(float(after.get("next_at", pts)) - pts)))]
	canvas.draw_string(fu, Vector2(bx, y + 70), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.85, 0.78, 0.68, a))
	if bool(summary.get("rank_up", false)) and rank_anim > 0.6:
		var up := "晋 升"
		var uw := f.get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		var alpha := clampf((rank_anim - 0.6) / 0.4, 0.0, 1.0)
		canvas.draw_string_outline(f, Vector2(x + w - uw - 10, y + 52), up, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(0.2, 0.1, 0, alpha))
		canvas.draw_string(f, Vector2(x + w - uw - 10, y + 52), up, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1.0, 0.85, 0.4, alpha))
		canvas.draw_string(f, Vector2(x + w - uw - 120, y + 90), atext, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(acol.r, acol.g, acol.b, alpha))


## 观战结算的底栏：擂主连胜 + 下一阵倒计时（单挑这里是段位条）
func _draw_watch_bar(vw: float, vh: float) -> void:
	var x := vw * 0.02
	var y := vh * 0.72
	var w := vw * 0.96
	var f: Font = Game.font_title
	var fu: Font = Game.font_ui
	var a := clampf(rank_anim, 0.0, 1.0)
	canvas.draw_rect(Rect2(x - 26, y - 34, w + 52, 132), Color(0.05, 0.04, 0.03, 0.80 * a))
	canvas.draw_rect(Rect2(x - 26, y - 34, w + 52, 132), Color(0.85, 0.7, 0.4, 0.3 * a), false, 2.0)
	var bar_title := "擂 台" if Game.watch_rule == "arena" else "对 决"
	canvas.draw_string(fu, Vector2(x, y + 4), bar_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.68, 0.58, a))
	canvas.draw_string(f, Vector2(x, y + 48), winner.def["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.86, 0.5, a))
	# 擂台：连胜数用一排小印表示（最多 6 枚，再多只写数字）；随机对决不显示连胜
	if Game.watch_rule == "arena":
		var streak_x := x + 260.0
		var chip := 34.0
		for i in mini(streak, 6):
			var r := Rect2(streak_x + i * (chip + 8.0), y + 16, chip, chip)
			canvas.draw_rect(r, Color(0.55, 0.08, 0.05, 0.9 * a))
			canvas.draw_rect(r, Color(1, 0.82, 0.4, 0.7 * a), false, 1.5)
			var tw := fu.get_string_size("胜", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			canvas.draw_string(fu, Vector2(r.position.x + (chip - tw) * 0.5, y + 42), "胜", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.7, a))
		canvas.draw_string(fu, Vector2(streak_x, y + 74), "连胜 %d 阵" % streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.85, 0.78, 0.68, a))
	# 下一阵倒计时
	var left: float = max(0.0, battle.autoplay_next_t)
	var tip := ""
	if Game.watch_rule == "arena":
		tip = "%d 秒后下一位挑战者登场" % int(ceil(left))
	else:
		tip = "%d 秒后开始下一阵" % int(ceil(left))
	var tw2 := f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	canvas.draw_string(f, Vector2(x + w - tw2, y + 46), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.85, 0.5, a))


func _draw_medals(cx: float, cy: float, win: bool) -> void:
	# 观战不计奖章：底栏已经写了连胜，这里什么都不画
	if not win or is_watch:
		return
	var gained := int(summary.get("medals", 0))
	var a := clampf(medal_anim, 0.0, 1.0)
	var f: Font = Game.font_title
	var txt := "+%d 奖章" % int(round(gained * a))
	if not bool(summary.get("gate_ok", true)):
		txt = "本场不计分"
	var col := Color(1.0, 0.84, 0.42)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var px := cx - w * 0.5
	var py := cy + 236.0 - (1.0 - a) * 26.0
	canvas.draw_string_outline(f, Vector2(px, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.15, 0.08, 0.02, a))
	canvas.draw_string(f, Vector2(px, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(col.r, col.g, col.b, a))
	if not bool(summary.get("gate_ok", true)):
		var hint := str(summary.get("gate_hint", ""))
		var fh := Game.font_ui
		var hw := fh.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		canvas.draw_string(fh, Vector2(cx - hw * 0.5, py + 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.65, 0.5, a))
	# 新称号
	var nt: Array = summary.get("new_titles", [])
	if nt.size() > 0 and title_anim > 0.01:
		var ta := clampf(title_anim, 0.0, 1.0)
		var names: Array = []
		for x in nt:
			names.append(str(x.get("name", "")))
		var line := "解锁称号：" + "、".join(names)
		var fh2: Font = Game.font_ui
		var tw := fh2.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		canvas.draw_string(fh2, Vector2(cx - tw * 0.5, py + 38), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.75, 0.95, 0.7, ta))
