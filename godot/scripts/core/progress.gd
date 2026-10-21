extends Node
## 成长系统（autoload 名：Progress）
## ---------------------------------------------------------------------------
## 职责：
##   1. 单场评分（C/B/A/S/SS/SSS）—— 公式和权重全部来自 config/progression.json
##   2. 段位（青铜 → 最强王者）+ 小段（III/II/I），只增不减，输了不给分也不扣分
##   3. 奖章（永久累计的可消费货币）—— 解锁武将 / 购买称号
##   4. 掉段：只记录上次进游戏日期，下次进来做减法（不依赖服务端计时）
##   5. 存档：微信端走 wx.setStorageSync，桌面端走 user://progress.json
##
## 约定：本文件不写任何数值。要调分数线/段位门槛/奖章表，改 progression.json。
## ---------------------------------------------------------------------------

const STORAGE_KEY := "dzsg_progress_v1"
const LOCAL_PATH := "user://progress.json"
const SAVE_VERSION := 1

var state: Dictionary = {}
var last_decay: Dictionary = {}      # {dropped, from_text, to_text} 供 UI 提示
var loaded := false


func _ready() -> void:
	load_state()
	last_decay = apply_decay()
	_self_check()


## 启动自检：微信端存档是否真的可用（JavaScriptBridge 被平台限制时，存档会静默失效）。
func _self_check() -> void:
	if not _is_web():
		print("Progress: 桌面存档可用（user://progress.json）")
		return
	var b = _wx_bridge()
	if b == null:
		print("Progress: 微信存档自检 ❌ 拿不到 __dzsgStorage 桥（存档不会保留）")
		return
	b.dzsgSet("dzsg_probe", "1")
	var v = b.dzsgGet("dzsg_probe")
	print("Progress: 微信存档自检 " + ("✅ 可用" if str(v) == "1" else ("❌ 不可用（%s）" % str(v))))


# ---------------------------------------------------------------- 存档

func _is_web() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


## game.js 里挂的存档桥。方法名特意加了 dzsg 前缀：
## 叫 set/get 会撞上 JS 对象代理自身的 set/get，调用直接失败。
var _bridge_cache = null

func _wx_bridge():
	if _bridge_cache != null:
		return _bridge_cache
	if not _is_web():
		return null
	var b = JavaScriptBridge.get_interface("__dzsgStorage")
	if b == null:
		return null
	_bridge_cache = b
	return b


func _default_state() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"medals": 0,
		"medals_total": 0,
		"rank_points": 0.0,
		"wins": 0,
		"losses": 0,
		"streak": 0,
		"best_streak": 0,
		"best_grade": "",
		"matches": 0,
		"titles": [],
		"title": "",
		"chars": [],
		"last_seen": Time.get_date_string_from_system(),
		"decay_stacks": 0,
	}


func load_state() -> void:
	state = _default_state()
	var txt := _read_blob()
	if txt.strip_edges() != "":
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			for k in parsed:
				state[k] = parsed[k]
		else:
			push_warning("Progress: 存档解析失败，已重置")
	# 类型兜底（JSON 数字都是 float）
	state["rank_points"] = float(state.get("rank_points", 0.0))
	for k in ["medals", "medals_total", "wins", "losses", "streak", "best_streak", "matches", "decay_stacks"]:
		state[k] = int(state.get(k, 0))
	for k in ["titles", "chars"]:
		if not (state.get(k) is Array):
			state[k] = []
	loaded = true


func save_state() -> void:
	var txt := JSON.stringify(state)
	if _is_web():
		var b = _wx_bridge()
		if b == null:
			push_warning("Progress: 微信存档桥不可用，本局进度不会保留")
			return
		var r = b.dzsgSet(STORAGE_KEY, txt)
		if str(r) != "1":
			push_warning("Progress: 微信存档写入失败：" + str(r))
		return
	var f := FileAccess.open(LOCAL_PATH, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()


func _read_blob() -> String:
	if _is_web():
		var b = _wx_bridge()
		if b == null:
			return ""
		var r = b.dzsgGet(STORAGE_KEY)
		return "" if r == null else str(r)
	if FileAccess.file_exists(LOCAL_PATH):
		return FileAccess.get_file_as_string(LOCAL_PATH)
	return ""


# ---------------------------------------------------------------- 评分

## 输入：胜者统计、胜者剩余血量比例、用时（秒）、是否超时判胜
## 输出：{total, grade, grade_index, parts:{hp,time,skill,combo,finish}, capped_by_time}
func evaluate(stats: Dictionary, hp_ratio: float, duration: float, by_time: bool) -> Dictionary:
	var w: Dictionary = Cfg.prog("score.weights", {})
	var w_hp := float(w.get("hp", 30))
	var w_time := float(w.get("time", 25))
	var w_skill := float(w.get("skill", 25))
	var w_combo := float(w.get("combo", 10))
	var w_finish := float(w.get("finish", 10))

	# 1) 剩余血量
	var p_hp := clampf(hp_ratio, 0.0, 1.0) * w_hp

	# 2) 用时：满分线以内满分，零分线以外 0，中间线性
	var t_full := Cfg.prog_float("score.time_full_seconds", 40.0)
	var t_zero := Cfg.prog_float("score.time_zero_seconds", 150.0)
	var p_time := 0.0
	if t_zero > t_full:
		p_time = clampf((t_zero - duration) / (t_zero - t_full), 0.0, 1.0) * w_time
	else:
		p_time = w_time if duration <= t_full else 0.0

	# 3) 技术分：拆招 / 完美闪避 / 拼刀胜，各自有上限
	var sk: Dictionary = Cfg.prog("score.skill", {})
	var parry_pts := minf(float(stats.get("parries", 0)) * float(sk.get("parry", 3.0)), float(sk.get("parry_cap", 12.0)))
	var dodge_pts := minf(float(stats.get("dodges", 0)) * float(sk.get("dodge", 3.0)), float(sk.get("dodge_cap", 8.0)))
	var clash_pts := minf(float(stats.get("clash_win", 0)) * float(sk.get("clash", 5.0)), float(sk.get("clash_cap", 5.0)))
	var raw_skill := parry_pts + dodge_pts + clash_pts
	# 技术项总和不能超过权重（防止权重调小后总分破 100）
	var p_skill := minf(raw_skill, w_skill)

	# 4) 最高连击
	var combo_full := maxf(1.0, Cfg.prog_float("score.combo_full", 8.0))
	var p_combo := clampf(float(stats.get("max_combo", 0)) / combo_full, 0.0, 1.0) * w_combo

	# 5) 终结方式：KO 满分，超时判胜 0 分
	var p_finish := 0.0 if by_time else w_finish

	var total := p_hp + p_time + p_skill + p_combo + p_finish
	total = clampf(total, 0.0, 100.0)

	# 换算评价
	var grades: Array = Cfg.prog("score.grades", [])
	var gi := 0
	for i in grades.size():
		if total >= float(grades[i].get("min", 0)):
			gi = i
	var capped := false
	if by_time:
		var cap_id := str(Cfg.prog("score.timeout_max_grade", ""))
		if cap_id != "":
			for i in grades.size():
				if str(grades[i].get("id", "")) == cap_id and gi > i:
					gi = i
					capped = true
	return {
		"total": total,
		"grade": str(grades[gi].get("id", "C")) if gi < grades.size() else "C",
		"grade_index": gi,
		"parts": {
			"hp": p_hp, "time": p_time, "skill": p_skill,
			"combo": p_combo, "finish": p_finish,
			"parry": parry_pts, "dodge": dodge_pts, "clash": clash_pts,
		},
		"caps": {"hp": w_hp, "time": w_time, "skill": w_skill, "combo": w_combo, "finish": w_finish},
		"capped_by_time": capped,
	}


func grade_color(gid: String) -> Color:
	for g in Cfg.prog("score.grades", []):
		if str(g.get("id", "")) == gid:
			return g.get("color", Color.WHITE)
	return Color.WHITE


func grade_name(gid: String) -> String:
	for g in Cfg.prog("score.grades", []):
		if str(g.get("id", "")) == gid:
			return str(g.get("name", gid))
	return gid


func grade_desc(gid: String) -> String:
	for g in Cfg.prog("score.grades", []):
		if str(g.get("id", "")) == gid:
			return str(g.get("desc", ""))
	return ""


func grade_index(gid: String) -> int:
	var grades: Array = Cfg.prog("score.grades", [])
	for i in grades.size():
		if str(grades[i].get("id", "")) == gid:
			return i
	return -1


# ---------------------------------------------------------------- 段位

## 段位阶梯：把每个大段位拆成小段，得到 [{rank_id, rank_name, div_label, min, max, color, index}]
## 带缓存：战绩页每帧都会查，避免每帧重建 19 个字典。
var _ladder_cache: Array = []
var _ladder_key := ""

func ladder() -> Array:
	var ranks: Array = Cfg.prog("rank.ranks", [])
	var key := ""
	for r in ranks:
		key += "%s:%s:%s|" % [r.get("id", ""), r.get("min", 0), r.get("divisions", 1)]
	if key == _ladder_key and not _ladder_cache.is_empty():
		return _ladder_cache
	var out: Array = []
	for i in ranks.size():
		var r: Dictionary = ranks[i]
		var mn := float(r.get("min", 0))
		var mx: float
		if i + 1 < ranks.size():
			mx = float(ranks[i + 1].get("min", mn + 1000.0))
		else:
			mx = mn + 1000.0   # 最高段位留一条虚拟带
		var divs := maxi(1, int(r.get("divisions", 1)))
		for k in divs:
			var lo := mn + (mx - mn) * float(k) / float(divs)
			var hi := mn + (mx - mn) * float(k + 1) / float(divs)
			var label := ""
			if divs > 1:
				label = ["I", "II", "III", "IV", "V"][divs - 1 - k]
			out.append({
				"rank_id": str(r.get("id", "")),
				"rank_name": str(r.get("name", "")),
				"div_label": label,
				"min": lo,
				"max": hi,
				"color": r.get("color", Color.WHITE),
				"index": out.size(),
			})
	_ladder_cache = out
	_ladder_key = key
	return out


func rank_info(points := -1.0) -> Dictionary:
	if points < 0.0:
		points = float(state.get("rank_points", 0.0))
	var lad := ladder()
	if lad.is_empty():
		return {"rank_name": "青铜", "div_label": "III", "text": "青铜 III", "color": Color.GRAY, "progress": 0.0, "index": 0, "next_text": "", "points": points}
	var idx := 0
	for i in lad.size():
		if points >= float(lad[i]["min"]):
			idx = i
	var cur: Dictionary = lad[idx]
	var span := maxf(0.0001, float(cur["max"]) - float(cur["min"]))
	var prog := clampf((points - float(cur["min"])) / span, 0.0, 1.0)
	var text := str(cur["rank_name"])
	if str(cur["div_label"]) != "":
		text += " " + str(cur["div_label"])
	var next_text := ""
	if idx + 1 < lad.size():
		var nx: Dictionary = lad[idx + 1]
		next_text = str(nx["rank_name"]) + (" " + str(nx["div_label"]) if str(nx["div_label"]) != "" else "")
	return {
		"rank_id": str(cur["rank_id"]),
		"rank_name": str(cur["rank_name"]),
		"div_label": str(cur["div_label"]),
		"text": text,
		"color": cur["color"],
		"progress": prog,
		"index": idx,
		"next_text": next_text,
		"next_at": float(cur["max"]),
		"points": points,
		"ladder_size": lad.size(),
	}


func rank_index_of(rank_id: String) -> int:
	var ranks: Array = Cfg.prog("rank.ranks", [])
	for i in ranks.size():
		if str(ranks[i].get("id", "")) == rank_id:
			return i
	return -1


## 难度门槛：段位达到 from_rank 以上后，难度低于 min_difficulty 不给分
func difficulty_gate_ok(difficulty: int) -> bool:
	var from_rank := str(Cfg.prog("rank.difficulty_gate.from_rank", ""))
	if from_rank == "":
		return true
	var min_diff := Cfg.prog_int("rank.difficulty_gate.min_difficulty", 0)
	if difficulty >= min_diff:
		return true
	var need := rank_index_of(from_rank)
	if need < 0:
		return true
	# 当前大段位索引
	var ranks: Array = Cfg.prog("rank.ranks", [])
	var pts := float(state.get("rank_points", 0.0))
	var cur := 0
	for i in ranks.size():
		if pts >= float(ranks[i].get("min", 0)):
			cur = i
	return cur < need


# ---------------------------------------------------------------- 掉段

## 只按「上次进游戏日期」算：间隔 >= days 天 → 掉 min(floor(days/days), max_stacks) 个小段
func apply_decay() -> Dictionary:
	var days_need := maxi(1, Cfg.prog_int("rank.decay.days", 7))
	var max_stacks := maxi(1, Cfg.prog_int("rank.decay.max_stacks", 5))
	var last := str(state.get("last_seen", ""))
	var today := Time.get_date_string_from_system()
	state["last_seen"] = today
	if last == "" or last == today:
		save_state()
		return {}
	var t_last := Time.get_unix_time_from_datetime_string(last + "T00:00:00")
	var t_today := Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	var days := int(floor((t_today - t_last) / 86400.0))
	if days < days_need:
		save_state()
		return {}
	var drop := mini(int(floor(float(days) / float(days_need))), max_stacks)
	var before := rank_info()
	var lad := ladder()
	var idx := int(before.get("index", 0))
	var new_idx := maxi(0, idx - drop)
	if new_idx == idx:
		save_state()
		return {}
	state["rank_points"] = float(lad[new_idx]["min"])
	# 「连掉」计数：本次离线连掉了几段；下次再玩会清零（见 record_match）
	state["decay_stacks"] = idx - new_idx
	save_state()
	var after := rank_info()
	var info := {
		"dropped": idx - new_idx,
		"days": days,
		"from_text": str(before.get("text", "")),
		"to_text": str(after.get("text", "")),
	}
	return info


# ---------------------------------------------------------------- 结算

## 结算：记录一场。返回给结算页用的完整摘要。
## is_player_win=false 时只记败场，不给分、不扣分。
func record_match(eval_res: Dictionary, difficulty: int, is_player_win: bool) -> Dictionary:
	state["matches"] = int(state.get("matches", 0)) + 1
	var before := rank_info()
	var out := {
		"eval": eval_res,
		"medals": 0,
		"gate_ok": true,
		"gate_hint": "",
		"rank_before": before,
		"rank_after": before,
		"rank_up": false,
		"new_titles": [],
		"is_win": is_player_win,
	}
	if not is_player_win:
		state["decay_stacks"] = 0
		state["losses"] = int(state.get("losses", 0)) + 1
		state["streak"] = 0
		save_state()
		return out

	state["decay_stacks"] = 0   # 又出阵了，「连掉」中断
	state["wins"] = int(state.get("wins", 0)) + 1
	state["streak"] = int(state.get("streak", 0)) + 1
	state["best_streak"] = maxi(int(state.get("best_streak", 0)), int(state["streak"]))

	var gid := str(eval_res.get("grade", "C"))
	if grade_index(gid) > grade_index(str(state.get("best_grade", ""))):
		state["best_grade"] = gid

	# 奖章：行=评价，列=[易,中,难,极]
	var table: Dictionary = Cfg.prog("medals.by_grade_difficulty", {})
	var row = table.get(gid, [])
	var gained := 0
	if row is Array and row.size() > 0:
		gained = int(row[clampi(difficulty, 0, row.size() - 1)])
	out["gate_ok"] = difficulty_gate_ok(difficulty)
	if not out["gate_ok"]:
		gained = 0
		out["gate_hint"] = "当前段位需「%s」及以上难度才计分" % Game.difficulty_name(Cfg.prog_int("rank.difficulty_gate.min_difficulty", 1))
	out["medals"] = gained
	state["medals"] = int(state.get("medals", 0)) + gained
	state["medals_total"] = int(state.get("medals_total", 0)) + gained
	state["rank_points"] = float(state.get("rank_points", 0.0)) + float(gained) * Cfg.prog_float("rank.points_per_medal", 1.0)

	var after := rank_info()
	out["rank_after"] = after
	out["rank_up"] = int(after.get("index", 0)) > int(before.get("index", 0))

	# 称号：自动解锁
	var new_titles := _auto_unlock_titles()
	out["new_titles"] = new_titles
	save_state()
	return out


# ---------------------------------------------------------------- 称号 / 解锁

func titles() -> Array:
	var out: Array = []
	for t in Cfg.prog("titles", []):
		var id := str(t.get("id", ""))
		out.append({
			"id": id,
			"name": str(t.get("name", id)),
			"desc": str(t.get("desc", "")),
			"cost": float(t.get("cost", 0)),
			"unlocked": id in state.get("titles", []),
			"equipped": str(state.get("title", "")) == id,
		})
	return out


func _auto_unlock_titles() -> Array:
	var newly: Array = []
	for t in Cfg.prog("titles", []):
		var id := str(t.get("id", ""))
		if id in state.get("titles", []):
			continue
		# 需要花奖章买的称号不自动解锁（即使 require 是空的）
		if float(t.get("cost", 0)) > 0:
			continue
		var req: Dictionary = t.get("require", {})
		var ok := true
		if req.has("wins") and int(state.get("wins", 0)) < int(req["wins"]):
			ok = false
		if req.has("streak") and int(state.get("best_streak", 0)) < int(req["streak"]):
			ok = false
		if req.has("grade") and grade_index(str(state.get("best_grade", ""))) < grade_index(str(req["grade"])):
			ok = false
		if req.has("rank"):
			var need := rank_index_of(str(req["rank"]))
			var cur := rank_index_of(str(rank_info().get("rank_id", "")))
			if need >= 0 and cur >= 0 and cur < need:
				ok = false
		if ok:
			state["titles"].append(id)
			newly.append({"id": id, "name": str(t.get("name", id))})
			if str(state.get("title", "")) == "":
				state["title"] = id
	return newly


func equip_title(id: String) -> void:
	if id == "" or id in state.get("titles", []):
		state["title"] = id
		save_state()


func title_name() -> String:
	var id := str(state.get("title", ""))
	for t in titles():
		if t["id"] == id:
			return t["name"]
	return ""


func buy_title(id: String) -> Dictionary:
	for t in Cfg.prog("titles", []):
		if str(t.get("id", "")) != id:
			continue
		if id in state.get("titles", []):
			return {"ok": false, "error": "已拥有"}
		var cost := int(t.get("cost", 0))
		if cost <= 0:
			return {"ok": false, "error": "该称号需达成条件自动解锁"}
		if int(state.get("medals", 0)) < cost:
			return {"ok": false, "error": "奖章不足（需 %d）" % cost}
		state["medals"] = int(state["medals"]) - cost
		state["titles"].append(id)
		save_state()
		return {"ok": true, "cost": cost}
	return {"ok": false, "error": "称号不存在"}


func char_price(id: String) -> int:
	var tbl: Dictionary = Cfg.prog("unlocks.characters", {})
	if tbl.has(id):
		return int(tbl[id])
	return -1


func is_char_unlocked(id: String) -> bool:
	var price := char_price(id)
	if price < 0:
		return true
	return id in state.get("chars", [])


func buy_char(id: String) -> Dictionary:
	var price := char_price(id)
	if price < 0:
		return {"ok": false, "error": "该武将无需解锁"}
	if id in state.get("chars", []):
		return {"ok": false, "error": "已解锁"}
	if int(state.get("medals", 0)) < price:
		return {"ok": false, "error": "奖章不足（需 %d）" % price}
	state["medals"] = int(state["medals"]) - price
	state["chars"].append(id)
	save_state()
	return {"ok": true, "cost": price}


## 开发/测试用：重置存档
func reset() -> void:
	state = _default_state()
	save_state()
