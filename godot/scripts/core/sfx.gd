extends Node
## 音效与音乐。按文件名前缀分组：slash_1.ogg / slash_2.ogg → play("slash") 随机取一个。

const AUDIO_DIR := "res://assets/audio/"
const POOL_SIZE := 28
const LOOP_OFFSETS := {}

var groups := {}          # 名称 -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _amb: Dictionary = {}  # 环境声循环
var _lowpass: AudioEffectLowPassFilter
var _muffle := 0.0
var _muffle_target := 0.0
var _last_play := {}
var recorder: Callable          # 战斗回放用：记录每次播放


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_scan()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_music_cur = _music_a
	apply_volumes()
	Game.settings_changed.connect(apply_volumes)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Amb"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _lowpass)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -10.0
	comp.ratio = 3.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), comp)


func _scan() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return
	var seen := {}
	for f in dir.get_files():
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := file.get_extension().to_lower()
		if not (ext in ["wav", "ogg", "mp3"]):
			continue
		if seen.has(file):
			continue
		seen[file] = true
		var base := file.get_basename()
		var parts := base.rsplit("_", true, 1)
		var group := base
		if parts.size() == 2 and parts[1].is_valid_int():
			group = parts[0]
		var path := AUDIO_DIR + file
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		if not groups.has(group):
			groups[group] = []
		groups[group].append(stream)
		# 全名也可以直接用
		if group != base:
			groups[base] = [stream]


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(0.0001, Game.music_volume * 0.8)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(0.0001, Game.sfx_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), linear_to_db(max(0.0001, Game.sfx_volume * 0.7)))


func has_sound(snd: String) -> bool:
	return groups.has(snd)


## 播放音效。vol_db 相对音量，pitch_var 随机变调幅度。
func play(snd: String, vol_db := 0.0, pitch := 1.0, pitch_var := 0.06) -> void:
	if not groups.has(snd):
		return
	if recorder.is_valid():
		recorder.call(snd, vol_db, pitch)
	# 同一音效 30ms 内不叠播，防止爆音
	var now := Time.get_ticks_msec()
	if _last_play.get(snd, -1000) > now - 30:
		return
	_last_play[snd] = now
	var list: Array = groups[snd]
	var stream: AudioStream = list[randi() % list.size()]
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = max(0.2, pitch + randf_range(-pitch_var, pitch_var))
	p.play()


func play_music(track: String, fade := 1.2, vol_db := 0.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var other := _music_b if _music_cur == _music_a else _music_a
	if groups.has(track):
		var s: AudioStream = groups[track][0]
		if s is AudioStreamMP3:
			s.loop = true
			s.loop_offset = LOOP_OFFSETS.get(track, 0.0)
		elif s is AudioStreamOggVorbis:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		other.stream = s
		other.volume_db = -40.0
		other.play()
		var tw := create_tween().set_parallel(true)
		tw.tween_property(other, "volume_db", vol_db, fade)
		tw.tween_property(_music_cur, "volume_db", -40.0, fade)
		tw.chain().tween_callback(_music_cur.stop)
	else:
		var tw := create_tween()
		tw.tween_property(_music_cur, "volume_db", -40.0, fade)
		tw.tween_callback(_music_cur.stop)
	_music_cur = other


func stop_music(fade := 1.0) -> void:
	_music_name = ""
	var cur := _music_cur
	var tw := create_tween()
	tw.tween_property(cur, "volume_db", -40.0, fade)
	tw.tween_callback(cur.stop)


func music_duck(db := -10.0, time := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(_music_cur, "volume_db", db, time)


func ambient(snd: String, on: bool, vol_db := -6.0) -> void:
	if on:
		if _amb.has(snd) or not groups.has(snd):
			return
		var p := AudioStreamPlayer.new()
		p.bus = "Amb"
		var s: AudioStream = groups[snd][0]
		if s is AudioStreamOggVorbis or s is AudioStreamMP3:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
		p.volume_db = -40.0
		add_child(p)
		p.play()
		create_tween().tween_property(p, "volume_db", vol_db, 1.5)
		_amb[snd] = p
	elif _amb.has(snd):
		var p: AudioStreamPlayer = _amb[snd]
		_amb.erase(snd)
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -40.0, 0.8)
		tw.tween_callback(p.queue_free)


func stop_all_ambient() -> void:
	for n in _amb.keys():
		ambient(n, false)


## 慢动作/大招时让声音发闷（0 = 正常，1 = 很闷）
func muffle(amount: float) -> void:
	_muffle_target = clamp(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	var real := delta / maxf(0.001, Engine.time_scale)
	_muffle = move_toward(_muffle, _muffle_target, real * 4.0)
	_lowpass.cutoff_hz = lerp(20000.0, 900.0, _muffle * _muffle)
