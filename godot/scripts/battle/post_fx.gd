extends CanvasLayer
## 全屏后期控制：闪白、色散、径向模糊、去色、残血红边、调色。都按真实时间衰减。

var rect: ColorRect
var mat: ShaderMaterial
var flash_a := 0.0
var flash_col := Color.WHITE
var aberr := 0.0
var radial := 0.0
var radial_center := Vector2(0.5, 0.5)
var desat := 0.0
var desat_goal := 0.0
var danger := [0.0, 0.0]
var danger_goal := [0.0, 0.0]
var ink := 0.0
var ink_goal := 0.0
var t := 0.0


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	# 小游戏版：Web/手机用不读屏幕纹理的轻量后期，省一次全屏拷贝
	if OS.has_feature("web") or OS.has_feature("mobile"):
		mat.shader = load("res://shaders/screen_fx_lite.gdshader")
	else:
		mat.shader = load("res://shaders/screen_fx.gdshader")
	rect.material = mat
	add_child(rect)


func set_grade(g: Color, lift_c: Color, vignette: float, sat: float, contrast: float) -> void:
	mat.set_shader_parameter("grade", Vector3(g.r, g.g, g.b))
	mat.set_shader_parameter("lift", Vector3(lift_c.r, lift_c.g, lift_c.b))
	mat.set_shader_parameter("vignette", vignette)
	mat.set_shader_parameter("saturation", sat)
	mat.set_shader_parameter("contrast", contrast)


func flash(col: Color, alpha: float) -> void:
	flash_col = col
	flash_a = max(flash_a, alpha)


func aberrate(amount: float) -> void:
	aberr = max(aberr, amount)


func blur(amount: float, center := Vector2(0.5, 0.5)) -> void:
	radial = max(radial, amount)
	radial_center = center


func set_desat(v: float) -> void:
	desat_goal = v


func set_danger(side: int, v: float) -> void:
	danger_goal[side] = v


func set_ink(v: float) -> void:
	ink_goal = v


func _process(delta: float) -> void:
	var dt: float = min(0.05, delta / max(0.0001, Engine.time_scale))
	t += dt
	flash_a = move_toward(flash_a, 0.0, dt * 3.2)
	aberr = move_toward(aberr, 0.0, dt * 5.0)
	radial = move_toward(radial, 0.0, dt * 2.6)
	desat = move_toward(desat, desat_goal, dt * 1.6)
	ink = move_toward(ink, ink_goal, dt * 1.8)
	for i in 2:
		var pulse := 0.65 + 0.35 * sin(t * 6.0)
		danger[i] = move_toward(danger[i], danger_goal[i] * pulse, dt * 2.0)
	mat.set_shader_parameter("flash_color", Color(flash_col.r, flash_col.g, flash_col.b, clamp(flash_a, 0.0, 1.0)))
	mat.set_shader_parameter("aberration", aberr)
	mat.set_shader_parameter("radial_blur", radial)
	mat.set_shader_parameter("blur_center", radial_center)
	mat.set_shader_parameter("desat", desat)
	mat.set_shader_parameter("danger_l", danger[0])
	mat.set_shader_parameter("danger_r", danger[1])
	mat.set_shader_parameter("ink", ink)
