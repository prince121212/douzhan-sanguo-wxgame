extends CanvasLayer
## 暂停菜单（Esc / P）。

var battle: Node
var root: Control
var first_btn: Button


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
	box.position = Vector2(660, 200)
	box.custom_minimum_size = Vector2(600, 0)
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	box.add_child(v)
	var title := UiKit.label("暂 停", 64, Color(1.0, 0.85, 0.45), true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	first_btn = UiKit.button("继续再战", resume, 38, 520)
	v.add_child(first_btn)
	v.add_child(UiKit.button("重新开始", func():
		resume()
		Game.goto("battle"), 38, 520))
	v.add_child(UiKit.button("返回选将", func():
		resume()
		Game.goto("select"), 38, 520))
	v.add_child(UiKit.button("回主菜单", func():
		resume()
		Game.goto("title"), 38, 520))
	var help := UiKit.label("移动 WASD　轻击 J　重击 K（按住蓄力）　格挡 L（看准时机按下即拆招）\n闪避 空格（马上按住空格纵马冲锋）　疾跑 Shift　跳跃 I　绝技 U\n观战：F 调速　Tab 隐藏界面", 22, Color(0.9, 0.85, 0.75), false, 4)
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
	root.visible = true
	get_tree().paused = true
	Sfx.play("ui_confirm", -6.0)
	first_btn.grab_focus()


func resume() -> void:
	root.visible = false
	get_tree().paused = false
