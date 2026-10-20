class_name UiKit
extends RefCounted
## 界面小工具：统一的按钮、面板、文字风格（暗木底 + 金边 + 书法字）。

const GOLD := Color(0.92, 0.72, 0.36)
const INK := Color(0.07, 0.04, 0.03)
const PAPER := Color(1.0, 0.93, 0.8)
const RED := Color(0.62, 0.1, 0.06)


static func panel_style(alpha := 0.86, border := GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb


static func button(text: String, cb: Callable, size := 40, min_w := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, size + 34)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", Game.font_title)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.6))
	b.add_theme_color_override("font_focus_color", Color(1, 0.95, 0.6))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.8, 0.4))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.07, 0.04, 0.88)
	normal.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.45, 0.09, 0.05, 0.95)
	hover.border_color = Color(1, 0.85, 0.45)
	hover.set_border_width_all(3)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.3, 0.05, 0.03, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func():
		Sfx.play("ui_confirm", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("ui_click", -12.0))
	b.focus_entered.connect(func(): Sfx.play("ui_click", -14.0))
	return b


static func label(text: String, size := 32, col := PAPER, title := true, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font_title if title else Game.font_ui)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	return l
