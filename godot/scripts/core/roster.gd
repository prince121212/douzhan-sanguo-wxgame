extends Node
## 武将名册（薄壳）：数据全部来自 config/characters.json，由 Cfg 加载。
## 对外接口保持不变，所有调用点（battle/ui/arena）零改动。

const FALLBACK_ID := "zhaoyun"

## 属性换算系数。想整体调「武力→伤害」的曲线，改这里（不是平衡数值，是换算公式）。
const POWER_BASE := 0.62
const POWER_DIV := 260.0
const DEF_BASE := 1.0
const DEF_OFFSET := 60.0
const DEF_DIV := 420.0
const SPD_BASE := 0.86
const SPD_DIV := 700.0


func ids() -> Array:
	return Cfg.character_order.duplicate()


func get_def(id: String) -> Dictionary:
	if Cfg.characters.has(id):
		return Cfg.characters[id]
	if Cfg.characters.has(FALLBACK_ID):
		return Cfg.characters[FALLBACK_ID]
	return {}


func has(id: String) -> bool:
	return Cfg.characters.has(id)


func display_name(id: String) -> String:
	return get_def(id).get("name", id)


func line(id: String, key: String) -> String:
	var lines: Dictionary = get_def(id).get("lines", {})
	var l = lines.get(key, "")
	if l is Array:
		return l[randi() % l.size()] if l.size() > 0 else ""
	return l


func rivalry_line(a: String, b: String) -> String:
	return Cfg.rivalry.get(a + "|" + b, "")


## 属性换算
func power_mult(id: String) -> float:
	return POWER_BASE + float(get_def(id)["stats"]["wu"]) / POWER_DIV


func defense_mult(id: String) -> float:
	return DEF_BASE - (float(get_def(id)["stats"]["tong"]) - DEF_OFFSET) / DEF_DIV


func speed_mult(id: String) -> float:
	return SPD_BASE + float(get_def(id)["stats"]["su"]) / SPD_DIV
