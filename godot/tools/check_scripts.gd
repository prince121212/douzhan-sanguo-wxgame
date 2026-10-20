extends Node
## 开发用：在完整环境（含自动加载）里逐个编译脚本，打印错误后退出。

func _ready() -> void:
	var files: Array = []
	_collect("res://scripts", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or (s is GDScript and not s.can_instantiate()):
			bad += 1
			print("BAD: ", f)
	print("CHECKED ", files.size(), " scripts, bad=", bad)
	get_tree().quit()


func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
