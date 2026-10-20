class_name PlayerInput
extends RefCounted
## 玩家输入：键盘 WASD + J 轻 / K 重（按住蓄力）/ L 格挡（看准时机按下即拆招）/
## 空格 闪避（马上按住空格纵马冲锋）/ Shift 疾跑 / I 跳 / U 绝技

var enabled := true


func get_input(f, _dt: float) -> Dictionary:
	if not enabled:
		return {}
	var mv := Vector2(Input.get_axis("p1_left", "p1_right"), Input.get_axis("p1_up", "p1_down"))
	if mv.length() > 1.0:
		mv = mv.normalized()
	var run := Input.is_action_pressed("p1_run")
	if f.mounted and Input.is_action_pressed("p1_dodge"):
		run = true
	return {
		"move": mv,
		"run": run,
		"light": Input.is_action_just_pressed("p1_light"),
		"heavy": Input.is_action_just_pressed("p1_heavy"),
		"heavy_held": Input.is_action_pressed("p1_heavy"),
		"guard": Input.is_action_pressed("p1_guard"),
		"guard_pressed": Input.is_action_just_pressed("p1_guard"),
		"dodge": Input.is_action_just_pressed("p1_dodge"),
		"jump": Input.is_action_just_pressed("p1_jump"),
		"ult": Input.is_action_just_pressed("p1_ult"),
	}


## 拼刀时连打
func mash() -> bool:
	return Input.is_action_just_pressed("p1_light") or Input.is_action_just_pressed("p1_heavy")
