extends Node2D
## 特效工厂：刀光、突刺、火花、尘土、冲击波、残影、飘字、对白。

const SlashArc := preload("res://scripts/battle/fx/slash_arc.gd")
const SlashTex := preload("res://scripts/battle/fx/slash_tex.gd")
const ImpactRing := preload("res://scripts/battle/fx/impact_ring.gd")
const ThrustStreak := preload("res://scripts/battle/fx/thrust_streak.gd")
const SparkBurst := preload("res://scripts/battle/fx/spark_burst.gd")
const RingWave := preload("res://scripts/battle/fx/ring_wave.gd")
const DustPuff := preload("res://scripts/battle/fx/dust_puff.gd")
const Afterimage := preload("res://scripts/battle/fx/afterimage.gd")
const FloatText := preload("res://scripts/battle/fx/float_text.gd")
const SpeechBubble := preload("res://scripts/battle/fx/speech_bubble.gd")
const GroundCrack := preload("res://scripts/battle/fx/ground_crack.gd")
const GuardFlare := preload("res://scripts/battle/fx/guard_flare.gd")
const ChargeMote := preload("res://scripts/battle/fx/charge_mote.gd")
const WaveSlash := preload("res://scripts/battle/fx/wave_slash.gd")
const Reticle := preload("res://scripts/battle/fx/reticle.gd")
const GhostRider := preload("res://scripts/battle/fx/ghost_rider.gd")
const ArrowFx := preload("res://scripts/battle/fx/arrow.gd")

const SPAWN_KINDS := {
	"thrust": ThrustStreak, "slash": SlashArc, "wave": WaveSlash, "reticle": Reticle,
	"ghost": GhostRider, "arrow": ArrowFx, "ring": RingWave, "spark": SparkBurst,
	"impact": ImpactRing, "slashspr": SlashTex,
}

var add_mat: CanvasItemMaterial
var battle: Node
var ground_layer: Node2D       # 地面层（裂纹、地面冲击波），在人物下面
var top_layer: Node2D          # 文字层，最上面
var _glint_t := {}
## 每个武将当前那一刀。连招时新刀直接顶掉旧刀，
## 否则 0.2 秒内存活的三四刀会并排叠成一串月牙。
var _slash_of := {}


func _ready() -> void:
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	top_layer = Node2D.new()
	top_layer.z_index = 50
	add_child(top_layer)


func _add(n: Node2D, additive := true, layer: Node2D = null) -> Node2D:
	if additive:
		n.material = add_mat
	(layer if layer else self).add_child(n)
	return n


## 回放：把这次特效调用记下来，回放时按时间重新调用一遍
var _rec_depth := 0


func _rec(fn: String, args: Array) -> void:
	if battle and battle.recording and _rec_depth == 0:
		battle.rec_event("vfx", fn, args)


## 通用特效生成（绝技里的定制特效走这里，方便回放）。props 是属性表。
func spawn(kind: String, props: Dictionary, additive := true) -> Node2D:
	_rec("spawn", [kind, props.duplicate(), additive])
	var n: Node2D = SPAWN_KINDS[kind].new()
	for k in props:
		n.set(k, props[k])
	return _add(n, additive)


# ---------------------------------------------------------------- 挥击

func swing(f: Fighter, mv: Dictionary, ratio: float) -> void:
	_rec("swing", [f, mv, ratio])
	var kind: String = mv["vfx"]
	var ds := f.depth_scale()
	var col: Color = f.theme_color
	var center := f.global_position + Vector2(0, -(f.h + f.body_height() * 0.46) * ds)
	var reach: float = mv["reach"] * (1.0 + ratio * 0.3)
	match kind:
		"thrust":
			# 突刺：细长光刃沿判定方向推出，和斩击共用同一套揭示逻辑
			var s := SlashTex.new()
			s.kind = "thin"
			s.radius = reach * 0.95 * ds
			s.position = Vector2(f.global_position.x + f.facing * reach * 0.22 * ds,
				center.y + f.body_height() * 0.06 * ds)
			s.flip = f.facing < 0
			var tarc: Array = mv["arc"]
			s.set_arc_deg(float(tarc[0]), float(tarc[1]))
			s.color = col.lerp(Color.WHITE, 0.45)
			s.life = clampf(float(mv["active"]) * 1.6, 0.13, 0.24)
			s.grow = 1.10
			_add(s)
		"slash", "slash_up", "slash_down":
			# 贴图月牙 + 旋转扫出。贴图纯白，modulate 成武将主题色。
			# 为什么不用程序化弧线：几何弧缺笔触、缺粗细变化，一眼假。
			var sp := SlashTex.new()
			# 骑战时角色更高、镜头更远，刀光按同一比例会显得过大，收一点
			sp.radius = reach * (0.52 if f.mounted else 0.62) * ds
			# 弧心放在身前：月牙贴着兵刃扫过的位置，而不是套在角色身上
			sp.position = center + Vector2(f.facing * reach * 0.30 * ds,
				f.body_height() * 0.12 * ds)
			# 素材的弧默认朝右前。面向左时整体转 180°，刀光才会跟着甩到左边。
			sp.flip = f.facing < 0
			# 刀光的弧和招式的判定弧对齐：横斩横着扫，下劈从上往下扫。
			# mv["arc"] 就是判定用的 [起角, 终角]，这样"看得见的"和"打得到的"一致。
			var arc: Array = mv["arc"]
			sp.set_arc_deg(float(arc[0]), float(arc[1]))
			# 普通混合而不是加法：黄沙很亮，加法会把主题色冲成一片白
			# 主题色占比高一点：纯白在浅色骑装上会和角色糊在一起
			sp.color = col.lerp(Color.WHITE, 0.42)
			sp.life = clampf(float(mv["active"]) * 1.6, 0.14, 0.28)
			sp.grow = 1.06 + ratio * 0.10
			# 顶掉同一武将上一刀的残留
			var prev = _slash_of.get(f)
			if prev != null and is_instance_valid(prev):
				prev.queue_free()
			_add(sp, false)
			_slash_of[f] = sp
		"spin":
			# 回旋斩：两圈反向的月牙，程序化画（贴图素材里没有整圈的那种）
			for i in 2:
				var sp := SlashArc.new()
				sp.position = center
				sp.scale = Vector2(f.facing * ds, ds)
				sp.radius = reach * (0.5 + i * 0.12)
				sp.thickness = 44.0
				sp.a0 = 0.0 + i * PI
				sp.a1 = TAU * 1.2 + i * PI
				sp.squash_y = 0.45
				# 回旋：两圈反向月牙，颜色略淡，别盖住角色
				sp.color = col.lerp(Color.WHITE, 0.25)
				sp.life = float(mv["active"]) + 0.12
				sp.sweep_time = float(mv["active"])
				_add(sp)
	if mv.get("ground_ring", false):
		var gp := Vector2(f.global_position.x + f.facing * reach * 0.6 * ds, f.global_position.y)
		get_tree().create_timer(max(0.04, float(mv["active"]) * 0.6), false).timeout.connect(func():
			_rec_depth += 1
			ring(gp, 160.0 + ratio * 80.0, Color(1.0, 0.8, 0.5), true, 16.0, 0.5)
			crack(gp, 0.9 + ratio * 0.6)
			dust(gp, 1.4 + ratio)
			_rec_depth -= 1
			battle.cam.shake(0.22 + ratio * 0.15))


# ---------------------------------------------------------------- 命中类

func hit_spark(pos: Vector2, col: Color, power: float) -> void:
	_rec("hit_spark", [pos, col, power])
	var s := SparkBurst.new()
	s.position = pos
	s.color = col.lerp(Color(1, 0.95, 0.8), 0.5)
	s.power = power
	s.life = 0.26 + power * 0.12
	_add(s)
	if power > 0.78:
		# 冲击环：只在重击时出现，小而碎。轻击每次都弹环会让画面变成打靶。
		var ir := ImpactRing.new()
		ir.position = pos
		ir.r0 = 10.0 + power * 6.0
		ir.r1 = 38.0 + power * 52.0
		ir.color = col.lerp(Color.WHITE, 0.3)
		ir.life = 0.18 + power * 0.08
		_add(ir)
	if power > 0.9:
		_rec_depth += 1
		ring(pos, 90.0 + power * 70.0, col.lerp(Color.WHITE, 0.5), false, 10.0, 0.3)
		_rec_depth -= 1


func clash_spark(pos: Vector2, big := true) -> void:
	_rec("clash_spark", [pos, big])
	var s := SparkBurst.new()
	s.position = pos
	s.color = Color(1.0, 0.9, 0.55)
	s.power = 2.2 if big else 1.0
	s.life = 0.45
	_add(s)
	_rec_depth += 1
	ring(pos, 150.0 if big else 78.0, Color(1.0, 0.95, 0.75), false, 11.0 if big else 7.0, 0.32)
	_rec_depth -= 1


func block_spark(pos: Vector2, col := Color(1.0, 0.85, 0.4)) -> void:
	_rec("block_spark", [pos, col])
	var s := SparkBurst.new()
	s.position = pos
	s.color = col
	s.power = 0.6
	s.big_flash = false
	s.life = 0.25
	_add(s)


func ring(pos: Vector2, r1: float, col: Color, ground := false, width := 12.0, life := 0.4) -> void:
	_rec("ring", [pos, r1, col, ground, width, life])
	var r := RingWave.new()
	r.position = pos
	r.r1 = r1
	r.color = col
	r.ground = ground
	r.width = width
	r.life = life
	_add(r, true, ground_layer if ground and ground_layer else null)


func dust(pos: Vector2, size := 1.0, col := Color(0.78, 0.64, 0.46, 0.65)) -> void:
	_rec("dust", [pos, size, col])
	var d := DustPuff.new()
	d.position = pos
	d.size = size
	d.color = col
	_add(d, false)


func crack(pos: Vector2, size := 1.0) -> void:
	_rec("crack", [pos, size])
	var c := GroundCrack.new()
	c.position = pos
	c.size = size
	if ground_layer:
		ground_layer.add_child(c)
	else:
		add_child(c)


func afterimage(f: Fighter, col: Color, life := 0.26, alpha := 0.5) -> void:
	if f.sprite.texture == null:
		return
	var a := Afterimage.new()
	a.texture = f.sprite.texture
	a.centered = false
	a.offset = f.sprite.offset
	a.modulate = Color(col.r * 1.2, col.g * 1.2, col.b * 1.4, alpha)
	a.base_alpha = alpha
	a.life = life
	_add(a)
	a.global_transform = f.sprite.global_transform


func guard_glint(f: Fighter) -> void:
	var now := Time.get_ticks_msec()
	if _glint_t.get(f, 0) > now:
		return
	_glint_t[f] = now + 380
	var g := GuardFlare.new()
	var ds := f.depth_scale()
	g.position = f.global_position + Vector2(f.facing * 26.0 * ds, -(f.h + f.body_height() * 0.5) * ds)
	g.scale = Vector2(ds, ds)
	g.facing = f.facing
	g.color = f.theme_color.lerp(Color(1, 0.9, 0.5), 0.5)
	_add(g)


func charge_spark(f: Fighter, ratio: float) -> void:
	_rec("charge_spark", [f, ratio])
	var ds := f.depth_scale()
	var c := f.global_position + Vector2(0, -(f.h + f.body_height() * 0.5) * ds)
	for i in 3:
		var m := ChargeMote.new()
		var ang := randf() * TAU
		m.position = c
		m.start = Vector2(cos(ang), sin(ang)) * randf_range(80.0, 140.0) * ds
		m.target_off = Vector2.ZERO
		m.color = f.theme_color.lerp(Color.WHITE, 0.3 + ratio * 0.4)
		m.life = 0.26
		_add(m)


# ---------------------------------------------------------------- 文字

## 世界空间里的文字随镜头缩放，乘上这个系数让它在屏幕上大小稳定
func _screen_k(base: float) -> float:
	if battle and battle.cam:
		return base / maxf(0.8, battle.cam.zoom.x)
	return 1.0


func number(pos: Vector2, value: float, kind := "number") -> void:
	_rec("number", [pos, value, kind])
	if not Game.show_damage_numbers:
		return
	var t := FloatText.new()
	t.position = pos + Vector2(randf_range(-20, 20), 0)
	t.scale = Vector2.ONE * _screen_k(1.25)
	t.text = str(int(round(value)))
	t.kind = kind
	t.font = Game.font_title
	match kind:
		"crit":
			t.size = 64
			t.color = Color(1.0, 0.82, 0.25)
		"chip":
			t.size = 34
			t.color = Color(0.85, 0.85, 0.85)
		_:
			t.size = 46
			t.color = Color(1.0, 0.95, 0.9)
	top_layer.add_child(t)


func stamp(pos: Vector2, text: String, col: Color, size := 72) -> void:
	_rec("stamp", [pos, text, col, size])
	var t := FloatText.new()
	t.position = pos
	t.scale = Vector2.ONE * _screen_k(1.35)
	t.text = text
	t.kind = "stamp"
	t.font = Game.font_title
	t.size = size
	t.color = col
	top_layer.add_child(t)


func say(f: Fighter, text: String, life := 2.2) -> void:
	if text == "":
		return
	# 同一人的旧气泡先撤掉
	for c in top_layer.get_children():
		if c.get_script() == SpeechBubble and c.target == f:
			c.queue_free()
	var b := SpeechBubble.new()
	b.scale = Vector2.ONE * _screen_k(1.3)
	# 对手的气泡还在：错开高度，免得两句话叠在一起
	for c in top_layer.get_children():
		if c.get_script() == SpeechBubble and c.target != f and is_instance_valid(c.target) and not c.is_queued_for_deletion():
			if absf(c.target.global_position.x - f.global_position.x) < 520.0:
				b.y_offset = c.y_offset + 78.0
	b.target = f
	b.text = text
	b.font = Game.font_title
	b.life = life
	b.accent = f.theme_color
	top_layer.add_child(b)
	b.global_position = f.head_global()
