extends Node2D
## 天光：几道从左上斜照下来的柔和光束，缓慢明暗起伏（加色混合）。

var color := Color(1.0, 0.95, 0.85)
var strength := 0.06
var t := 0.0
var beams: Array = []


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	for i in 5:
		beams.append({"x": randf_range(-200.0, 1400.0), "w": randf_range(90.0, 260.0), "ph": randf() * TAU, "sp": randf_range(0.15, 0.35)})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if strength <= 0.0:
		return
	var slant := 520.0
	for b in beams:
		var a: float = strength * (0.55 + 0.45 * sin(t * float(b["sp"]) + float(b["ph"])))
		var x0: float = b["x"] + sin(t * 0.05 + float(b["ph"])) * 40.0
		var w: float = b["w"]
		var top := -40.0
		var bottom := 960.0
		var pts := PackedVector2Array([Vector2(x0, top), Vector2(x0 + w, top), Vector2(x0 + w * 1.8 + slant, bottom), Vector2(x0 + slant, bottom)])
		var c0 := Color(color.r, color.g, color.b, a)
		var c1 := Color(color.r, color.g, color.b, 0.0)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
