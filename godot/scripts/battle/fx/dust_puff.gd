extends Node2D
## 尘土：几团柔和的圆向外膨胀、上飘、淡出。

var size := 1.0
var color := Color(0.78, 0.64, 0.46, 0.7)
var life := 0.7
var t := 0.0
var puffs: Array = []
static var tex: Texture2D


func _ready() -> void:
	if tex == null and ResourceLoader.exists("res://assets/ui/dust.png"):
		tex = load("res://assets/ui/dust.png")
	var n := int(4 + size * 5)
	for i in n:
		var a := randf_range(PI * 0.9, PI * 2.1)
		var sp := randf_range(40.0, 160.0) * size
		puffs.append({"p": Vector2(randf_range(-10, 10) * size, 0), "v": Vector2(cos(a) * sp * 1.4, sin(a) * sp * 0.35 - 20.0),
			"r": randf_range(14.0, 26.0) * size, "g": randf_range(1.6, 2.6)})
	life *= (0.8 + size * 0.3)


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for p in puffs:
		p["v"] *= pow(0.08, delta)
		p["p"] += p["v"] * delta
		p["p"].y -= 14.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := t / life
	for p in puffs:
		var r: float = p["r"] * (1.0 + k * p["g"])
		var c := Color(color.r, color.g, color.b, color.a * (1.0 - k) * (1.0 - k * 0.3))
		if tex:
			draw_texture_rect(tex, Rect2(p["p"] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
		else:
			draw_circle(p["p"], r, c)
