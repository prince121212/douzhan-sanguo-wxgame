extends Node2D
## 帅旗：旗杆 + 写着主将姓氏的飘动旗面（SubViewport 渲染文字，着色器飘动）。

var text := "赵"
var cloth := Color(0.5, 0.1, 0.08)
var trim := Color(1, 0.8, 0.35)
var facing := 1
var wave_shader: Shader
var pole_h := 300.0
var vp: SubViewport
var sprite: Sprite2D
var t := 0.0


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(220, 300)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(220, 300)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.position = Vector2(10, 20)
	bg.size = Vector2(200, 250)
	bg.color = cloth
	root.add_child(bg)
	var border := ReferenceRect.new()
	border.position = Vector2(18, 28)
	border.size = Vector2(184, 234)
	border.border_color = trim
	border.border_width = 6.0
	border.editor_only = false
	root.add_child(border)
	# 旗边锯齿（火焰边）
	var teeth := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 11:
		pts.append(Vector2(10 + i * 20, 270))
		pts.append(Vector2(20 + i * 20, 292))
	pts.append(Vector2(210, 270))
	pts.append(Vector2(10, 270))
	teeth.polygon = pts
	teeth.color = trim
	root.add_child(teeth)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(10, 30)
	lbl.size = Vector2(200, 230)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Game.font_brush)
	lbl.add_theme_font_size_override("font_size", 168)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.01))
	lbl.add_theme_constant_override("outline_size", 14)
	root.add_child(lbl)
	sprite = Sprite2D.new()
	sprite.texture = vp.get_texture()
	sprite.centered = false
	var sc := 0.62
	sprite.scale = Vector2(sc, sc)
	sprite.position = Vector2(4 if facing > 0 else -4 - 220 * sc, -pole_h + 6)
	var m := ShaderMaterial.new()
	m.shader = wave_shader
	m.set_shader_parameter("pole_left", 1.0 if facing > 0 else -1.0)
	m.set_shader_parameter("phase", randf() * 6.0)
	sprite.material = m
	add_child(sprite)


func _draw() -> void:
	# 旗杆
	draw_rect(Rect2(-5, -pole_h, 10, pole_h), Color(0.28, 0.16, 0.08))
	draw_rect(Rect2(-5, -pole_h, 3, pole_h), Color(0.45, 0.28, 0.14))
	# 杆头枪尖与红缨
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -pole_h), Vector2(0, -pole_h - 34), Vector2(9, -pole_h)]), Color(0.85, 0.85, 0.9))
	draw_circle(Vector2(0, -pole_h + 4), 11.0, Color(0.8, 0.12, 0.08))
	# 底座阴影
	for i in 3:
		draw_circle(Vector2(0, 0), 26.0 - i * 6.0, Color(0.08, 0.05, 0.03, 0.12))
