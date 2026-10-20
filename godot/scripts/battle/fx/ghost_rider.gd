extends Node2D
## 西凉铁骑虚影：半透明骑兵疾驰而过。

var frames: Array = []
var vx := 1400.0
var life := 1.6
var t := 0.0
var sprite: Sprite2D
var fallback: Texture2D
var fallback_off := Vector2.ZERO
var tint := Color(0.6, 0.85, 1.5, 0.55)
var scale_k := 1.0
var anchor := Vector2.ZERO


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = m
	sprite.modulate = tint
	add_child(sprite)
	if frames.is_empty() and fallback:
		sprite.texture = fallback
		sprite.offset = fallback_off
	elif not frames.is_empty():
		sprite.texture = frames[0]
		sprite.offset = -anchor
	sprite.scale = Vector2(scale_k * signf(vx), scale_k)


func _process(delta: float) -> void:
	t += delta
	position.x += vx * delta
	if not frames.is_empty():
		sprite.texture = frames[int(t * 14.0) % frames.size()]
	sprite.position.y = -absf(sin(t * 18.0)) * 8.0
	var fade: float = clamp(t / 0.15, 0.0, 1.0) * (1.0 - clamp((t - life + 0.3) / 0.3, 0.0, 1.0))
	sprite.modulate = Color(tint.r, tint.g, tint.b, tint.a * fade)
	if t >= life:
		queue_free()
