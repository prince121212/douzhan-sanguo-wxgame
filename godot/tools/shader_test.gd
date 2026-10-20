extends Node2D
## 开发：单独检查武将着色器（白闪/染色/描边）的显示效果

func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/bg/hulaoguan.png")
	bg.centered = false
	add_child(bg)
	var cases := [[0.85, Color.WHITE, 0.0], [1.0, Color.WHITE, 0.0], [0.4, Color.WHITE, 0.0], [0.85, Color(1, 0.72, 0.68), 0.0]]
	for i in cases.size():
		var s := Sprite2D.new()
		s.texture = load("res://assets/chars/mount/zhaoyun/hurt.png")
		s.position = Vector2(250 + i * 380, 600)
		s.scale = Vector2(0.8, 0.8)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fighter.gdshader")
		m.set_shader_parameter("flash", cases[i][0])
		m.set_shader_parameter("tint", cases[i][1])
		m.set_shader_parameter("glow_color", Color(1.5, 1.0, 0.4, cases[i][2]))
		if i == 2:
			m.set_shader_parameter("flash_color", Color(1, 1, 1, 1))
		s.material = m
		add_child(s)
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d:
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("/tmp/shader_test.png")
	get_tree().quit()
