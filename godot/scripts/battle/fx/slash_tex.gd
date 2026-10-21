extends Node2D
## 刀光：一张月牙贴图 + 按角度逐步揭示，演出一记挥砍。
##
## 为什么不是「旋转 + 淡出」：
##   素材本身就是一段约 180° 的月牙。整段一起转、一起淡，屏幕上永远是一整条弧，
##   看不出"挥"的过程，像贴纸。真正的读法是把光刃「扫」出来 ——
##   从刀尾沿弧推进到刀尖。所以用 shader 按角度 discard，把 sweep 从 0 推到 1。
##
## 素材：Slash Effect Collection by Cethiel (CC0)
##       https://opengameart.org/content/slash-effect-collection
## 贴图由 _tools/build_fx_assets.py 生成为「白 + 亮度进 alpha」。
## 染色走 shader 的 tint uniform（不能用 Sprite2D.modulate，会被 shader 覆盖）。

const ARC := preload("res://assets/fx/slash/arc_wide.png")
const ARC_THIN := preload("res://assets/fx/slash/arc_thin.png")
const REVEAL := preload("res://scripts/battle/fx/slash_reveal.gdshader")

## 实测（arc_wide.png）：圆心 (0.5434, 0.7037)，弧从 -145° 到 +35.6°，半径 0.283×宽
const PIVOT := Vector2(0.5434, 0.7037)
const ANGLE_START := -2.5311
const ANGLE_SPAN := 3.1534
const R_RATIO := 0.283
const ASPECT := 1.975
## 细刃（arc_thin.png）的实测值：圆心 (0.605, 0.495)，半径 0.252×宽
const PIVOT_THIN := Vector2(0.605, 0.495)
const R_RATIO_THIN := 0.252
const ASPECT_THIN := 1.407
## 素材的弧覆盖 [-145°, +35.6°]。整体转 +45° 后覆盖 [-100°, +80.6°]，
## 大致是「上方 → 前方 → 下方」，正好够覆盖各种挥砍角度。
const BASE_ROT := 45.0
const TEX_A0 := -145.0
const TEX_SPAN := 180.6

## wide = 大月牙（斩击）；thin = 细长光刃（突刺）
var kind := "wide"
var color := Color.WHITE
var radius := 150.0          ## 月牙半径（世界像素）
var life := 0.18
var grow := 1.06
var flip := false
var alpha := 1.0
var reverse := false         ## 反向扫（反手斩）
## 整体再转一点，用来区分上撩/下劈/横扫
var tilt_deg := 0.0
## 只揭示弧的一段（0..1）。素材是 180° 大弧，全揭示会盖住头顶和脚下；
## 取 0.15~0.95 就是「身前上方 → 身前」这一段。
var reveal_from := 0.0
var reveal_to := 1.0


## 让刀光只覆盖判定弧 [a0, a1]（度，0=正前，负=上方）。
## 这样横斩就是横着扫、下劈就是从上往下扫，和实际能打到的范围一致。
func set_arc_deg(a0: float, a1: float) -> void:
	var base := TEX_A0 + BASE_ROT
	reveal_from = clampf((a0 - base) / TEX_SPAN, 0.0, 1.0)
	reveal_to = clampf((a1 - base) / TEX_SPAN, 0.0, 1.0)
	if absf(reveal_to - reveal_from) < 0.06:
		# 判定弧太窄（比如小突刺），给一个最小可见宽度
		var c := (reveal_from + reveal_to) * 0.5
		reveal_from = clampf(c - 0.03, 0.0, 1.0)
		reveal_to = clampf(c + 0.03, 0.0, 1.0)
## 扫完之后停留多久再消失（占 life 的比例）
var hold := 0.42

var _t := 0.0
var _spr: Sprite2D
var _mat: ShaderMaterial
var _sc := 1.0


func _ready() -> void:
	var tex: Texture2D = ARC if kind == "wide" else ARC_THIN
	var pivot := PIVOT if kind == "wide" else PIVOT_THIN
	var r_ratio := R_RATIO if kind == "wide" else R_RATIO_THIN
	var aspect := ASPECT if kind == "wide" else ASPECT_THIN

	_mat = ShaderMaterial.new()
	_mat.shader = REVEAL
	_mat.set_shader_parameter("angle_start", ANGLE_START)
	_mat.set_shader_parameter("angle_span", ANGLE_SPAN)
	_mat.set_shader_parameter("pivot", pivot)
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("reverse", 1.0 if reverse else 0.0)
	_mat.set_shader_parameter("reveal_from", reveal_from)
	_mat.set_shader_parameter("reveal_to", reveal_to)

	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.centered = false
	_spr.material = _mat
	# centered=false 时 offset 就是左上角相对原点的位移。
	# 让「弧心」落在节点原点：之后旋转/缩放都绕圆心，月牙才是扫不是平移。
	_spr.offset = Vector2(-pivot.x * tex.get_width(), -pivot.y * tex.get_height())
	_sc = radius / (tex.get_width() * r_ratio)
	_spr.scale = Vector2(_sc, _sc)
	add_child(_spr)
	rotation = deg_to_rad(_rot_for_facing())
	_apply(0.0)


## 朝向只用「整体旋转 180°」处理，不要用负 scale。
## 负 scale 会同时把 shader 里按 UV 算的角度镜像掉，揭示顺序和位置都会错。
func _rot_for_facing() -> float:
	var base := BASE_ROT + tilt_deg
	if flip:
		return base + 180.0
	return base


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / maxf(0.001, life), 0.0, 1.0)
	_apply(k)
	if _t >= life:
		queue_free()


func _apply(k: float) -> void:
	# 前 60% 的时间把光刃扫出来，先快后慢
	var reveal_k := clampf(k / 0.6, 0.0, 1.0)
	_mat.set_shader_parameter("sweep", 1.0 - pow(1.0 - reveal_k, 2.2))
	# 扫的同时微微放大
	var s := _sc * lerpf(1.0, grow, k)
	_spr.scale = Vector2(s, s)
	# 收尾淡出（改 tint 的 alpha，不动 modulate）
	var fade := 1.0 if k < (1.0 - hold) else 1.0 - (k - (1.0 - hold)) / maxf(0.001, hold)
	_mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, color.a * alpha * fade))
