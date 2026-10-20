extends Sprite2D
## 残影：复制当前姿势的贴图，染色后淡出。

var life := 0.28
var t := 0.0
var base_alpha := 0.55


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	modulate.a = base_alpha * (1.0 - t / life)
