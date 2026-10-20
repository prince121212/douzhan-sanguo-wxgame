extends Node
## 角色贴图库：读 manifest，按（武将, 步/骑, 动作）给出贴图与锚点。

const CHAR_DIR := "res://assets/chars/"
const CUTIN_DIR := "res://assets/cutin/"
const TROOP_DIR := "res://assets/troops/"
const POSES := ["idle", "walk_l", "walk_r", "windup", "attack", "hurt", "jump", "down"]

# 统一显示身高（世界单位），步战与骑马分开
const STAND_HEIGHT := 150.0
const MOUNT_HEIGHT := 196.0

var manifest := {}
var troop_manifest := {}
var _cache := {}


func _ready() -> void:
	manifest = _load_json(CHAR_DIR + "manifest.json")
	troop_manifest = _load_json(TROOP_DIR + "manifest.json")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func has_stance(id: String, mounted: bool) -> bool:
	return manifest.has(("mount/" if mounted else "stand/") + id)


## 返回 {tex: Texture2D, anchor: Vector2, tip: Vector2, top: float}
func pose(id: String, mounted: bool, pose_name: String) -> Dictionary:
	var group := ("mount/" if mounted else "stand/") + id
	var key := group + "/" + pose_name
	if _cache.has(key):
		return _cache[key]
	var entry: Dictionary = manifest.get(group, {})
	var poses: Dictionary = entry.get("poses", {})
	if not poses.has(pose_name):
		pose_name = "idle"
	var info: Dictionary = poses.get(pose_name, {})
	var tex: Texture2D = null
	var path := CHAR_DIR + group + "/" + pose_name + ".png"
	if ResourceLoader.exists(path):
		tex = load(path)
	var anchor := Vector2.ZERO
	var tip := Vector2.ZERO
	var top := 0.0
	if info.has("anchor"):
		anchor = Vector2(info["anchor"][0], info["anchor"][1])
		tip = Vector2(info["tip"][0], info["tip"][1])
		top = info.get("top", 0)
	var out := {"tex": tex, "anchor": anchor, "tip": tip, "top": top}
	_cache[key] = out
	return out


## 让不同原图的武将显示成统一身高（再乘武将体型系数）
func base_scale(id: String, mounted: bool) -> float:
	var group := ("mount/" if mounted else "stand/") + id
	var entry: Dictionary = manifest.get(group, {})
	var h: float = max(1.0, float(entry.get("stand_height", 380)))
	var target := MOUNT_HEIGHT if mounted else STAND_HEIGHT
	return target / h * float(Roster.get_def(id).get("size", 1.0))


## 头像：取待机图上半部分
func portrait(id: String) -> Texture2D:
	var key := "portrait/" + id
	if _cache.has(key):
		return _cache[key]
	var p := pose(id, false, "idle") if has_stance(id, false) else pose(id, true, "idle")
	var tex: Texture2D = p["tex"]
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := float(tex.get_width())
	var top := float(p["top"])
	var head_h: float = (p["anchor"].y - top) * (0.62 if has_stance(id, false) else 0.42)
	var cx: float = p["anchor"].x
	var side: float = min(w, head_h * 1.08)
	at.region = Rect2(clamp(cx - side * 0.5, 0.0, w - side), top, side, head_h)
	_cache[key] = at
	return at


## 大招立绘（若已生成）
func cutin(id: String) -> Texture2D:
	var path := CUTIN_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## 没有大招立绘时：从攻击动作里截出头肩连兵器，当作立绘用。
## 返回 {tex, face, face_w, n, mounted}：face 是脸心、face_w 是脸宽，都按贴图像素计；
## n 是放大倍数。像素图先按整数倍最近邻放大，再交给线性过滤，颗粒清楚，移动时也不闪。
func cutin_fallback(id: String) -> Dictionary:
	var key := "cutin_fb/" + id
	if _cache.has(key):
		return _cache[key]
	var standing := has_stance(id, false)
	var p := pose(id, not standing, "attack")
	var tex: Texture2D = p["tex"]
	if tex == null:
		return {}
	var img := tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var top := int(p["top"])
	var body_h := float(p["anchor"].y) - float(top)
	# 找脸：头部那几行里的肤色像素，中位数作脸心，5%~95% 的横向跨度作脸宽
	var data := img.get_data()
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var fy0 := top + int(body_h * (0.14 if standing else 0.1))
	var fy1 := mini(h, top + int(body_h * (0.58 if standing else 0.42)))
	for y in range(fy0, fy1, 2):
		for x in range(0, w, 2):
			var i := (y * w + x) * 4
			var r := data[i]
			var g := data[i + 1]
			var b := data[i + 2]
			if data[i + 3] > 127 and r > 180 and g > 110 and b > 80 and r > g + 25 and g > b - 5 and r - b > 40:
				xs.append(x)
				ys.append(y)
	var face := Vector2(float(p["anchor"].x), top + body_h * (0.45 if standing else 0.3))
	var face_w := body_h * (0.45 if standing else 0.15)
	if xs.size() > 20:
		xs.sort()
		ys.sort()
		face = Vector2(xs[xs.size() / 2], ys[ys.size() / 2])
		face_w = maxf(8.0, xs[int(xs.size() * 0.95)] - xs[int(xs.size() * 0.05)])
	# 往下截到色带下沿以外（骑将的兵器在胸口，要多留一些）
	var y0 := maxi(0, top - 6)
	var y1 := mini(h, int(face.y + face_w * (1.0 if standing else 1.8)))
	var region := img.get_region(Rect2i(0, y0, w, y1 - y0))
	# 四周留一圈透明（贴图边缘不会被拉成条），下缘渐隐
	var pad := 2
	var out_img := Image.create_empty(region.get_width() + pad * 2, region.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
	out_img.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), Vector2i(pad, pad))
	var fade_h := int(region.get_height() * 0.12)
	for k in fade_h:
		var yy := pad + region.get_height() - 1 - k
		var a := smoothstep(0.0, 1.0, float(k) / float(fade_h))
		for x in out_img.get_width():
			var c := out_img.get_pixel(x, yy)
			if c.a > 0.0:
				c.a *= a
				out_img.set_pixel(x, yy, c)
	var n := 3 if standing else 4
	out_img.resize(out_img.get_width() * n, out_img.get_height() * n, Image.INTERPOLATE_NEAREST)
	var out := {"tex": ImageTexture.create_from_image(out_img), "n": n, "mounted": not standing,
		"face": (face - Vector2(0, y0) + Vector2(pad, pad)) * n, "face_w": face_w * n}
	_cache[key] = out
	return out


func troop_frames(kind: String) -> Array:
	var key := "troop/" + kind
	if _cache.has(key):
		return _cache[key]
	var frames: Array = []
	var entry: Dictionary = troop_manifest.get(kind, {})
	for i in range(1, 9):
		var path := TROOP_DIR + kind + "/cheer_%d.png" % i
		if ResourceLoader.exists(path):
			frames.append(load(path))
	var out := {"frames": frames, "entry": entry}
	_cache[key] = [out]
	return [out]
