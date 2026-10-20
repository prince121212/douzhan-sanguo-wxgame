extends Camera2D
## 战场运镜：双人自动取景 + 震屏 + 推镜冲击 + 荷兰角 + 演出镜头。
## 全部用真实时间推进，慢动作时镜头依然流畅。

const VIEW := Vector2(1920, 1080)
const ZOOM_WIDE := 1.18
const ZOOM_TIGHT := 1.78

var battle: Node
var map_rect := Rect2(0, 0, 1672, 941)
var base_pos := Vector2(836, 560)
var base_zoom := 1.3
var trauma := 0.0
var kick := 0.0
var kick_v := 0.0
var roll := 0.0
var roll_goal := 0.0
var noise := FastNoiseLite.new()
var t := 0.0
var intensity := 0.0     # 最近打得越激烈，镜头越近

# 演出镜头
var shot_on := false
var shot_pos := Vector2.ZERO
var shot_zoom := 1.5
var shot_until := 0.0
var shot_rate := 5.0
var shot_track: Node2D = null
var shot_track_off := Vector2.ZERO
var shot_free := false
var follow_rate := 3.2


func _ready() -> void:
	ignore_rotation = false
	noise.seed = randi()
	noise.frequency = 2.2
	zoom = Vector2(base_zoom, base_zoom)
	position = base_pos
	make_current()


func real_dt(delta: float) -> float:
	return delta / max(0.0001, Engine.time_scale)


func _process(delta: float) -> void:
	var dt := real_dt(delta)
	dt = min(dt, 0.05)
	t += dt
	intensity = move_toward(intensity, 0.0, dt * 0.25)
	var goal_pos := base_pos
	var goal_zoom := base_zoom
	var rate := follow_rate
	if shot_on and t >= shot_until:
		shot_on = false
		shot_track = null
	if shot_on:
		goal_pos = shot_pos
		if shot_track and is_instance_valid(shot_track):
			goal_pos = shot_track.global_position + shot_track_off
		goal_zoom = shot_zoom
		rate = shot_rate
	else:
		var fr := _follow_frame()
		goal_pos = fr[0]
		goal_zoom = fr[1]
	var k := 1.0 - exp(-rate * dt)
	base_pos = base_pos.lerp(goal_pos, k)
	base_zoom = lerp(base_zoom, goal_zoom, 1.0 - exp(-rate * 0.8 * dt))
	# 推镜冲击：弹簧
	kick_v += (-kick) * 180.0 * dt - kick_v * 16.0 * dt
	kick += kick_v * dt
	roll = lerp(roll, roll_goal, 1.0 - exp(-4.0 * dt))
	trauma = max(0.0, trauma - dt * 1.7)
	var shake_amt := trauma * trauma * Game.screen_shake
	var off := Vector2(noise.get_noise_2d(t * 60.0, 0.0), noise.get_noise_2d(0.0, t * 60.0)) * 34.0 * shake_amt
	var rot_shake := noise.get_noise_2d(t * 40.0, 99.0) * 0.035 * shake_amt
	var z: float = base_zoom * (1.0 + kick + sin(t * 0.7) * 0.006)
	zoom = Vector2(z, z)
	var p := base_pos + off / z
	if not (shot_on and shot_free):
		p = _clamp_to_map(p, z)
	position = p
	rotation = roll + rot_shake


func _follow_frame() -> Array:
	var fs: Array = battle.fighters if battle else []
	if fs.size() < 2:
		return [base_pos, base_zoom]
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for f in fs:
		var ds: float = f.depth_scale()
		var top: float = f.position.y - (f.h + f.lift + f.body_height() * 1.08) * ds
		minx = min(minx, f.position.x - f.half_width() * ds - 230.0)
		maxx = max(maxx, f.position.x + f.half_width() * ds + 230.0)
		miny = min(miny, top - 90.0)
		maxy = max(maxy, f.position.y + 110.0)
	var w := maxx - minx
	var hgt := maxy - miny
	# 用真实视口宽高取景，宽屏下才不会把两人拍得过近/过远
	var vp := Game.view_size()
	var view := Vector2(maxf(vp.x, VIEW.x), maxf(vp.y, VIEW.y))
	var zx := view.x / w
	var zy := view.y / hgt
	var z: float = clamp(min(zx, zy), ZOOM_WIDE, ZOOM_TIGHT)
	z *= 1.0 + intensity * 0.06
	z = min(z, ZOOM_TIGHT)
	var c := Vector2((minx + maxx) * 0.5, (miny + maxy) * 0.5 - 10.0)
	return [c, z]


func _clamp_to_map(p: Vector2, z: float) -> Vector2:
	# 用真实视口算可见半宽，否则宽屏（全面屏/微信）下会算出偏小的边界，
	# 镜头会把地图外的区域拉进画面。
	var vp := Game.view_size()
	var view := Vector2(maxf(vp.x, VIEW.x), maxf(vp.y, VIEW.y))
	var half := view / (2.0 * z)
	var out := p
	if map_rect.size.x > half.x * 2.0:
		out.x = clamp(p.x, map_rect.position.x + half.x, map_rect.end.x - half.x)
	else:
		out.x = map_rect.get_center().x
	if map_rect.size.y > half.y * 2.0:
		out.y = clamp(p.y, map_rect.position.y + half.y, map_rect.end.y - half.y)
	else:
		out.y = map_rect.get_center().y
	return out


# ---------------------------------------------------------------- 外部接口

func shake(amount: float) -> void:
	trauma = min(1.0, trauma + amount)


func punch(amount: float) -> void:
	kick_v += amount * 22.0


func heat(amount: float) -> void:
	intensity = min(1.0, intensity + amount)


func set_roll(deg: float) -> void:
	roll_goal = deg_to_rad(deg)


## 演出镜头：看向某点
func shot(pos: Vector2, z: float, hold: float, rate := 5.0, free := false) -> void:
	shot_on = true
	shot_pos = pos
	shot_zoom = z
	shot_until = t + hold
	shot_rate = rate
	shot_track = null
	shot_free = free


## 演出镜头：跟拍某个节点
func track(node: Node2D, z: float, hold: float, off := Vector2.ZERO, rate := 6.0) -> void:
	shot_on = true
	shot_track = node
	shot_track_off = off
	shot_zoom = z
	shot_until = t + hold
	shot_rate = rate
	shot_free = false


## 硬切
func cut(pos: Vector2, z: float) -> void:
	base_pos = pos
	base_zoom = z
	shot_pos = pos
	shot_zoom = z


func release(rate := 3.2) -> void:
	shot_on = false
	shot_track = null
	follow_rate = rate
	roll_goal = 0.0
