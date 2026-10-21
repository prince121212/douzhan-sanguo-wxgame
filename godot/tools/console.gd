extends CanvasLayer
## 开发用「数值控制台」（只在桌面 Godot 里可用，不会进微信包）
## ---------------------------------------------------------------------------
## 三态锁，防止误改：
##   LOCKED    锁定：只能看，改不了
##   EDITING   解锁：可以调，但改动只存在内存里，游戏还没变
##   CONFIRMED 已确定：改动已确认，但还没生效
##   关锁 → 写回 config/*.json + Cfg.reload() → 真正生效
##
## 为什么绕这一圈：数值直接影响手感，误碰一个数字就可能毁掉整局体验。
## 「解锁 → 改 → 确定 → 关锁」四步保证每次改动都是有意为之。
##
## 开关：F8 或 F10（macOS 上 F10 默认是系统静音键，需按 Fn；F8 无冲突）
## 字段定义直接读 config/schema/*.schema.json —— schema 改了控制台自动跟着变。
## ---------------------------------------------------------------------------

enum St { LOCKED, EDITING, CONFIRMED }

const PANEL_W := 1180.0
const PANEL_H := 800.0

var st: int = St.LOCKED
var root: Control
var panel: PanelContainer
var lock_btn: Button
var apply_btn: Button
var revert_btn: Button
var status_lbl: Label
var tabs: TabContainer

var _pending: Dictionary = {}          # "文件|点路径" -> 新值
var _originals: Dictionary = {}        # 同样的键 -> 原值
var _rows: Array = []                  # [{kind, path, file, spin, slider, original}]
var _dirty := false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	_build_rows()


# ---------------------------------------------------------------- 界面骨架

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# ---- 顶栏 ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)

	var title := Label.new()
	title.text = "数值控制台"
	title.add_theme_font_override("font", Game.font_title)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	head.add_child(title)

	var hint := Label.new()
	hint.text = "F8 / F10 开关 · 数值改动需「解锁 → 确定 → 关锁」才生效"
	hint.add_theme_font_override("font", Game.font_ui)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hint)

	# 小锁按钮（自绘图标）
	lock_btn = Button.new()
	lock_btn.custom_minimum_size = Vector2(132, 48)
	lock_btn.focus_mode = Control.FOCUS_NONE
	lock_btn.add_theme_font_override("font", Game.font_ui)
	lock_btn.add_theme_font_size_override("font_size", 20)
	lock_btn.pressed.connect(_on_lock)
	head.add_child(lock_btn)

	# ---- 状态行 ----
	status_lbl = Label.new()
	status_lbl.add_theme_font_override("font", Game.font_ui)
	status_lbl.add_theme_font_size_override("font_size", 19)
	v.add_child(status_lbl)

	# ---- 分页 ----
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", Game.font_ui)
	tabs.add_theme_font_size_override("font_size", 20)
	v.add_child(tabs)

	# ---- 底栏 ----
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)

	revert_btn = Button.new()
	revert_btn.text = "还 原"
	revert_btn.custom_minimum_size = Vector2(140, 50)
	revert_btn.add_theme_font_override("font", Game.font_title)
	revert_btn.add_theme_font_size_override("font_size", 22)
	revert_btn.pressed.connect(_on_revert)
	foot.add_child(revert_btn)

	apply_btn = Button.new()
	apply_btn.text = "确 定"
	apply_btn.custom_minimum_size = Vector2(200, 50)
	apply_btn.add_theme_font_override("font", Game.font_title)
	apply_btn.add_theme_font_size_override("font_size", 24)
	apply_btn.pressed.connect(_on_confirm)
	foot.add_child(apply_btn)

	var close := Button.new()
	close.text = "关 闭"
	close.custom_minimum_size = Vector2(140, 50)
	close.add_theme_font_override("font", Game.font_title)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_on_close)
	foot.add_child(close)

	_refresh_state()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.04, 0.97)
	sb.border_color = Color(0.92, 0.72, 0.36, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb


# ---------------------------------------------------------------- 数据行

func _build_rows() -> void:
	_build_balance_tab()
	_build_characters_tab()


func _new_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	return v


func _section(v: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font_title)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	v.add_child(l)
	var line := HSeparator.new()
	v.add_child(line)


func _build_balance_tab() -> void:
	var schema := _read_json("res://config/schema/balance.schema.json")
	var props: Dictionary = schema.get("properties", {})
	var v := _new_tab("全局平衡")
	var section_names := {"round": "一局规则", "hp": "体力 / 耐力", "rage": "怒气（绝技槽）",
		"damage": "伤害计算", "ai_difficulty": "AI 难度曲线"}
	for sec in ["round", "hp", "rage", "damage", "ai_difficulty"]:
		if not props.has(sec):
			continue
		_section(v, section_names.get(sec, sec))
		var sub: Dictionary = props[sec].get("properties", {})
		for key in sub:
			var spec: Dictionary = sub[key]
			var path: String = sec + "." + key
			var desc: String = spec.get("description", "")
			if spec.get("type") == "array":
				# 难度曲线：4 个值并排
				var arr: Array = Cfg.bal(path, [])
				for i in arr.size():
					_add_row(v, "res://config/balance.json", path + "." + str(i),
						"%s [%d]" % [desc, i], float(arr[i]), spec.get("range", []))
			else:
				_add_row(v, "res://config/balance.json", path, desc,
					float(Cfg.bal(path, 0.0)), spec.get("range", []))


func _build_characters_tab() -> void:
	var v := _new_tab("武将")
	for id in Cfg.character_order:
		var c: Dictionary = Cfg.characters.get(id, {})
		if c.is_empty():
			continue
		_section(v, "%s · %s" % [c.get("name", id), c.get("epithet", "")])
		_add_row(v, "res://config/characters.json", "characters.%s.hp" % id, "体力上限",
			float(c.get("hp", 1000)), [800, 2200], true)
		_add_row(v, "res://config/characters.json", "characters.%s.size" % id, "立绘缩放",
			float(c.get("size", 1.0)), [0.8, 1.3])
		for sk in ["wu", "tong", "su", "dan"]:
			_add_row(v, "res://config/characters.json", "characters.%s.stats.%s" % [id, sk],
				"属性 · " + sk, float(c.get("stats", {}).get(sk, 90)), [60, 100], true)
		for ak in ["aggression", "patience", "parry", "dodge", "combo", "jump", "feint", "zone", "honor", "taunt"]:
			_add_row(v, "res://config/characters.json", "characters.%s.ai.%s" % [id, ak],
				"AI · " + ak, float(c.get("ai", {}).get(ak, 0.5)), [0, 1])


func _add_row(parent: VBoxContainer, file: String, path: String, label_text: String,
		value: float, rng: Array, is_int := false) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)

	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_override("font", Game.font_ui)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.92, 0.87, 0.78))
	l.tooltip_text = path
	h.add_child(l)

	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(140, 34)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spin.step = 1.0 if is_int else _step_for(value)
	spin.allow_greater = true
	spin.allow_lesser = true
	if rng.size() >= 2:
		spin.min_value = float(rng[0]) * 0.5
		spin.max_value = float(rng[1]) * 2.0
	else:
		spin.min_value = 0.0
		spin.max_value = 99999.0
	spin.value = value
	spin.custom_arrow_step = spin.step
	spin.add_theme_font_override("font", Game.font_ui)
	spin.add_theme_font_size_override("font_size", 19)
	spin.get_line_edit().add_theme_font_override("font", Game.font_ui)
	spin.get_line_edit().add_theme_font_size_override("font_size", 19)
	spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(spin)

	# 右侧统一留一块：有滑块的放滑块，没滑块的放弹性占位，保证每行等宽对齐
	var slider: HSlider = null
	if rng.size() >= 2 and float(rng[1]) <= 1.0:
		slider = HSlider.new()
		slider.min_value = float(rng[0])
		slider.max_value = float(rng[1])
		slider.step = 0.01
		slider.value = value
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(360, 0)
		h.add_child(slider)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.custom_minimum_size = Vector2(360, 0)
		h.add_child(spacer)

	var key := file + "|" + path
	_originals[key] = value
	_rows.append({"file": file, "path": path, "spin": spin, "slider": slider,
		"original": value, "is_int": is_int})

	spin.value_changed.connect(func(v2: float):
		if st != St.EDITING:
			return
		_pending[key] = v2
		if slider and absf(slider.value - v2) > 0.0001:
			slider.set_value_no_signal(v2)
		_mark_dirty())
	if slider:
		slider.value_changed.connect(func(v2: float):
			if st != St.EDITING:
				return
			_pending[key] = v2
			if absf(spin.value - v2) > 0.0001:
				spin.set_value_no_signal(v2)
			_mark_dirty())


func _step_for(v: float) -> float:
	if absf(v) >= 100.0:
		return 1.0
	if absf(v) >= 10.0:
		return 0.5
	return 0.01


# ---------------------------------------------------------------- 锁逻辑

func _on_lock() -> void:
	match st:
		St.LOCKED:
			st = St.EDITING
			_refresh_state()
		St.EDITING:
			if _dirty:
				# 有未确认的改动，关锁等于放弃
				status_lbl.text = "⚠ 有未确认的改动，已放弃。"
			st = St.LOCKED
			_pending.clear()
			_dirty = false
			_reset_widgets()
			_refresh_state()
		St.CONFIRMED:
			_commit()


func _on_confirm() -> void:
	if st != St.EDITING:
		return
	if not _dirty:
		status_lbl.text = "没有改动。"
		return
	st = St.CONFIRMED
	_refresh_state()


func _on_revert() -> void:
	if st != St.EDITING:
		return
	_pending.clear()
	_dirty = false
	_reset_widgets()
	status_lbl.text = "已还原到当前生效值（尚未写回文件）。"
	_refresh_state()


func _reset_widgets() -> void:
	for r in _rows:
		var v: float = float(r["original"])
		r["spin"].set_value_no_signal(v)
		if r["slider"]:
			r["slider"].set_value_no_signal(v)


func _mark_dirty() -> void:
	_dirty = true
	_refresh_state()


func _refresh_state() -> void:
	var editable := st == St.EDITING
	for r in _rows:
		r["spin"].editable = editable
		r["spin"].mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE
		if r["slider"]:
			r["slider"].editable = editable
			r["slider"].mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE

	apply_btn.modulate = Color(1, 1, 1) if not apply_btn.disabled else Color(0.45, 0.45, 0.45)
	revert_btn.disabled = not (_dirty and st == St.EDITING)
	revert_btn.modulate = Color(1, 1, 1) if not revert_btn.disabled else Color(0.4, 0.4, 0.4)
	lock_btn.add_theme_font_size_override("font_size", 20)

	match st:
		St.LOCKED:
			lock_btn.text = "🔒 已锁定"
			lock_btn.modulate = Color(0.75, 0.75, 0.75)
			apply_btn.disabled = true
			status_lbl.text = "已锁定 · 只能查看。点右上角小锁解锁后才能调整。"
			status_lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
		St.EDITING:
			lock_btn.text = "🔓 已解锁"
			lock_btn.modulate = Color(1.0, 0.86, 0.5)
			apply_btn.disabled = not _dirty
			status_lbl.text = "已解锁 · 可以调整。改完点「确定」，再点小锁关锁生效。" if not _dirty \
				else "已解锁 · 有 %d 处改动待确认。" % _pending.size()
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		St.CONFIRMED:
			lock_btn.text = "🔒 关锁生效"
			lock_btn.modulate = Color(0.5, 1.0, 0.6)
			apply_btn.disabled = true
			status_lbl.text = "已确定 %d 处改动 · 点小锁关锁后写入配置并生效。" % _pending.size()
			status_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	apply_btn.modulate = Color(1, 1, 1) if not apply_btn.disabled else Color(0.4, 0.4, 0.4)
	revert_btn.disabled = not (_dirty and st == St.EDITING)
	revert_btn.modulate = Color(1, 1, 1) if not revert_btn.disabled else Color(0.4, 0.4, 0.4)


# ---------------------------------------------------------------- 写回

func _commit() -> void:
	# 记录哪些路径是整数字段
	var int_paths := {}
	for r in _rows:
		if r.get("is_int", false):
			int_paths[r["file"] + "|" + r["path"]] = true

	var by_file := {}
	for key in _pending:
		var parts: PackedStringArray = key.split("|", true, 1)
		if parts.size() != 2:
			continue
		if not by_file.has(parts[0]):
			by_file[parts[0]] = {}
		var val = _pending[key]
		if int_paths.has(key):
			val = int(round(float(val)))
		by_file[parts[0]][parts[1]] = val

	var failed := []
	for file in by_file:
		if not _write_file(file, by_file[file]):
			failed.append(file)

	if failed.is_empty():
		Cfg.reload()
		_pending.clear()
		_dirty = false
		st = St.LOCKED
		# 重新读一遍真实值，保证界面与文件一致
		for r in _rows:
			var cur: Variant = _read_path(r["file"], r["path"])
			if cur != null:
				r["original"] = float(cur)
		_reset_widgets()
		status_lbl.text = "✅ 已写入配置并生效（%d 个文件）。" % by_file.size()
		status_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	else:
		st = St.EDITING
		status_lbl.text = "❌ 写入失败：%s（导出后的包 res:// 只读，请在 Godot 编辑器里运行）" % ", ".join(failed)
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_refresh_state()


func _write_file(path: String, changes: Dictionary) -> bool:
	var data := _read_json(path)
	if data.is_empty():
		return false
	for dotted in changes:
		var cur: Variant = data
		var parts: PackedStringArray = dotted.split(".")
		var ok := true
		for i in parts.size() - 1:
			var p := parts[i]
			if cur is Dictionary and cur.has(p):
				cur = cur[p]
			elif cur is Array and p.is_valid_int():
				cur = cur[int(p)]
			else:
				ok = false
				break
		if not ok:
			continue
		var last := parts[parts.size() - 1]
		var new_val = changes[dotted]
		if cur is Dictionary:
			var old = cur.get(last, null)
			# 保持整数类型（hp / stats / motes 等）
			if old is int and new_val is float:
				new_val = int(round(new_val))
			cur[last] = new_val
		elif cur is Array and last.is_valid_int():
			var idx := int(last)
			if idx >= 0 and idx < cur.size():
				var old2 = cur[idx]
				if old2 is int and new_val is float:
					new_val = int(round(new_val))
				cur[idx] = new_val
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _read_path(path: String, dotted: String):
	var data := _read_json(path)
	var cur: Variant = data
	for p in dotted.split("."):
		if cur is Dictionary and cur.has(p):
			cur = cur[p]
		elif cur is Array and p.is_valid_int() and int(p) < cur.size():
			cur = cur[int(p)]
		else:
			return null
	return cur


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if d is Dictionary else {}


# ---------------------------------------------------------------- 开关

func _on_close() -> void:
	if st == St.EDITING and _dirty:
		status_lbl.text = "⚠ 有未确认的改动，请先「确定」或「还原」。"
		return
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		st = St.LOCKED
		_pending.clear()
		_dirty = false
		_reset_widgets()
		_refresh_state()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_F8 or k.keycode == KEY_F10:
			toggle()
			get_viewport().set_input_as_handled()
