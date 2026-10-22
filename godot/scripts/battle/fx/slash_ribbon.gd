extends Node2D
## 刀光带：沿圆弧生成一条「月牙」带状网格（两层：外层柔光 + 内层亮芯），
## 由 shader 按「头部推进 + 拖尾衰减」画出挥砍过程。
##
## 为什么用带状网格而不是贴一张月牙图：
##   贴图形状固定，调粗细、弧度、收尖都得重画素材；
##   带状网格的每个参数（半径、张角、厚度）都能直接跟招式数值挂钩，
##   两端能精确收尖，刃口能单独加亮，内缘能按噪声破碎。
##
## 结构参考 REEBOO Stylized VFX (MIT) 的 slash shader：
##   头部先快后慢推进 / 头部后面留一段拖尾 / 外缘最亮。
##   https://github.com/reeboolabs/reeboo-stylized-vfx-free
##
## 性能：每刀 2 个 MeshInstance2D，段数固定（默认 26），无贴图依赖，
##       微信小游戏 GL Compatibility 下开销很小。

const SHADER := preload("res://scripts/battle/fx/slash_ribbon.gdshader")
const GLOW_SHADER := preload("res://scripts/battle/fx/slash_ribbon_glow.gdshader")
const NOISE := preload("res://assets/fx/noise_soft.png")

var color := Color(1.0, 0.62, 0.18)
var core_color := Color(1.0, 0.98, 0.88)
var radius := 150.0          ## 外缘弧半径（世界像素）
var width := 46.0            ## 月牙最厚处厚度
var a0 := -60.0              ## 起始角（度，0 = 正前，负 = 上方）
var a1 := 60.0               ## 结束角
var life := 0.2
var intensity := 1.0
var trail_length := 1.8
var sweep_power := 0.42
var taper := 0.5             ## 两端收尖的锐利度，越小越尖
var noise_strength := 0.55
var glow := 1.0              ## 外层柔光强度（0 关闭）
var glow_intensity := 0.42   ## 外层柔光亮度
var segs := 26
var head_taper := 0.12        ## 刀尖收尖长度（弧长比例）
var noise_scale_x := 3.2      ## 噪声沿弧的频率（越大越碎）
var tongue_freq := 1.7        ## 火舌沿弧的频率

var _t := 0.0
var _mat: ShaderMaterial
var _mat_glow: ShaderMaterial


func _ready() -> void:
	if glow > 0.0:
		_mat_glow = ShaderMaterial.new()
		_mat_glow.shader = GLOW_SHADER
		_mat_glow.set_shader_parameter("color", color)
		_mat_glow.set_shader_parameter("intensity", glow_intensity)
		_mat_glow.set_shader_parameter("trail_length", trail_length)
		_mat_glow.set_shader_parameter("sweep_power", sweep_power)
		_mat_glow.set_shader_parameter("inner_radius", radius)
		_mat_glow.set_shader_parameter("head_taper", head_taper)
		var g := MeshInstance2D.new()
		g.mesh = _build_halo(width * 2.4)
		g.material = _mat_glow
		add_child(g)

	_mat = _make_mat(intensity, noise_strength, 1.0)
	var m := MeshInstance2D.new()
	m.mesh = _build(width)
	m.material = _mat
	add_child(m)

	_apply(0.0)


func _make_mat(lum: float, nz: float, rim: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("core_color", core_color)
	mat.set_shader_parameter("intensity", lum)
	mat.set_shader_parameter("trail_length", trail_length)
	mat.set_shader_parameter("sweep_power", sweep_power)
	mat.set_shader_parameter("noise_strength", nz)
	mat.set_shader_parameter("rim_strength", rim)
	mat.set_shader_parameter("noise_tex", NOISE)
	mat.set_shader_parameter("inner_radius", radius)
	mat.set_shader_parameter("head_taper", head_taper)
	mat.set_shader_parameter("noise_scale_x", noise_scale_x)
	mat.set_shader_parameter("tongue_freq", tongue_freq)
	return mat


## 月牙剖面：中间厚、两端收尖。返回 0..1 的厚度系数。
func _profile(u: float) -> float:
	# sin 曲线做两端收尖，pow 控制尖角锐度；再轻微偏置，让刀尖那头更长
	var s := sin(PI * clampf(u, 0.0, 1.0))
	return pow(maxf(s, 0.0), taper) * (0.72 + 0.28 * u)


## 光晕网格：比主体向外扩 w，内缘略微内缩，宽度方向留出柔光余量。
func _build_halo(w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := maxi(4, segs)
	for i in n + 1:
		var u := float(i) / float(n)
		var ang := deg_to_rad(lerpf(a0, a1, u))
		var dir := Vector2(cos(ang), sin(ang))
		var pr := _profile(u)
		var r_in := radius - w * 0.22 * pr
		var r_out := radius + w * pr
		st.set_uv(Vector2(u, 0.0))
		st.add_vertex(Vector3(dir.x * r_in, dir.y * r_in, 0.0))
		st.set_uv(Vector2(u, 1.0))
		st.add_vertex(Vector3(dir.x * r_out, dir.y * r_out, 0.0))
	return st.commit()


## 生成月牙网格。UV.x 沿弧（0 刀尾 → 1 刀尖），UV.y 从内缘 0 到外缘 1。
func _build(w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := maxi(4, segs)
	for i in n + 1:
		var u := float(i) / float(n)
		var ang := deg_to_rad(lerpf(a0, a1, u))
		var dir := Vector2(cos(ang), sin(ang))
		var r_out := radius + w * _profile(u)
		st.set_uv(Vector2(u, 0.0))
		st.add_vertex(Vector3(dir.x * radius, dir.y * radius, 0.0))
		st.set_uv(Vector2(u, 1.0))
		st.add_vertex(Vector3(dir.x * r_out, dir.y * r_out, 0.0))
	return st.commit()


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / maxf(0.001, life), 0.0, 1.0)
	_apply(k)
	if _t >= life:
		queue_free()


func _apply(k: float) -> void:
	_mat.set_shader_parameter("age", k)
	if _mat_glow:
		_mat_glow.set_shader_parameter("age", k)
	# 收尾整体淡出，避免"啪"一下消失
	var fade := 1.0 if k < 0.72 else 1.0 - (k - 0.72) / 0.28
	_mat.set_shader_parameter("color", Color(color.r, color.g, color.b, color.a * fade))
	if _mat_glow:
		_mat_glow.set_shader_parameter("color", Color(color.r, color.g, color.b, color.a * fade))
