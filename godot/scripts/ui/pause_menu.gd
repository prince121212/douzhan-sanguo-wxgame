extends CanvasLayer
## 暂停菜单（Esc / P）。
## 观战模式下额外提供「倍速」「隐藏界面」两项 —— 战斗画面上不再挂这些按钮。

var battle: Node
var root: Control
var first_btn: Button
var speed_btn: Button
var hud_btn: Button
var watch_box: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.panel_style(0.92))
	box.position = Vector2(Game.view_size().x * 0.5 - 300, 150 + Game.ui_offset_y())
	box.custom_minimum_size = Vector2(600, 0)
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var title := UiKit.label("暂 停", 64, Color(1.0, 0.85, 0.45), true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	first_btn = UiKit.button("继续再战", resume, 38, 520)
	v.add_child(first_btn)

	# 观战专用：倍速 / 隐藏界面（单挑时不显示）
	watch_box = VBoxContainer.new()
	watch_box.add_theme_constant_override("separation", 10)
	watch_box.visible = false
	v.add_child(watch_box)
	speed_btn = UiKit.button("", _cycle_speed, 32, 520)
	watch_box.add_child(speed_btn)
	hud_btn = UiKit.button("", _toggle_hud, 32, 520)
	watch_box.add_child(hud_btn)

	v.add_child(UiKit.button("重新开始", func():
		resume()
		Game.goto("battle"), 38, 520))
	v.add_child(UiKit.button("返回选将", func():
		resume()
		Game.goto("select"), 38, 520))
	v.add_child(UiKit.button("回主菜单", func():
		resume()
		Game.goto("title"), 38, 520))
	# 帮助文案按「单挑 / 观战」分开：观战没有招式按钮，提示写操作键就行
	var watching: bool = battle != null and battle.player_side < 0
	var help_text := ""
	if watching:
		help_text = "观战：用上面两项调倍速 / 隐藏界面" if Game.touch_ui else "观战：F 调速　Tab 隐藏界面"
	else:
		help_text = "左摇杆移动（推到底疾跑）　轻 连招　重 按住蓄力　挡 看准时机拆招\n闪 闪避（马上按住纵马冲锋）　跳 跳跃　绝 怒气满放绝技"
		if not Game.touch_ui:
			help_text = "移动 WASD　轻击 J　重击 K（按住蓄力）　格挡 L（看准时机按下即拆招）\n闪避 空格（马上按住空格纵马冲锋）　疾跑 Shift　跳跃 I　绝技 U"
	var help := UiKit.label(help_text, 21, Color(0.9, 0.85, 0.75), false, 4)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if root.visible:
			resume()
		elif battle and battle.phase != "result":
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	root.visible = true
	get_tree().paused = true
	Sfx.play("ui_confirm", -6.0)
	first_btn.grab_focus()


func resume() -> void:
	root.visible = false
	get_tree().paused = false


## 只有观战（player_side < 0）才显示倍速 / 隐藏界面
func _refresh() -> void:
	var watching: bool = battle != null and battle.player_side < 0
	watch_box.visible = watching
	if not watching:
		return
	var speed: float = battle.user_speed
	speed_btn.text = "观战倍速　×%s" % _fmt_speed(speed)
	var hidden: bool = battle.hud != null and battle.hud.user_hidden
	hud_btn.text = "界面显示　%s" % ("已隐藏（点此显示）" if hidden else "显示中（点此隐藏）")


func _fmt_speed(v: float) -> String:
	return "1" if is_equal_approx(v, 1.0) else ("%.1f" % v).rstrip("0").rstrip(".")


func _cycle_speed() -> void:
	if battle == null:
		return
	battle.toggle_speed()
	_refresh()


func _toggle_hud() -> void:
	if battle == null:
		return
	battle.toggle_hud()
	_refresh()
