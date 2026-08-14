extends Node
## Пул SFX + музыка меню/игры + VO мамы + ambient.

var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var _sfx_pool: Array = []
var _pool_i: int = 0
var _streams: Dictionary = {}
var _mom_lines: Array = ["mom", "mom2", "mom3"]
var _step_lines: Array = ["step", "step2", "step3", "step4"]
var _reverb: AudioEffectReverb = null
var _indoor: bool = false
var _last_step: int = -1

func _ready() -> void:
	_setup_buses()
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -8.0
	ambient_player.bus = "Music"
	add_child(ambient_player)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_apply_volumes()
	for k in ["burst", "pickup", "dump", "impact", "slip", "bark", "babushka", "mom", "mom2", "mom3", "elevator", "win", "fail", "step", "step2", "step3", "step4", "rustle", "bag_grab", "bag_drop", "wall_rub"]:
		_try_load(k, "res://assets/sfx/%s.wav" % k)
	_try_load("music", "res://assets/music/menu_loop.wav")
	_try_load("game_music", "res://assets/music/game_loop.wav")
	_try_load("danger_music", "res://assets/music/danger_loop.wav")
	_try_load("ambient", "res://assets/music/ambient_hall.wav")

## Шина SFX с ревербом: в подъезде эхо, во дворе почти сухо.
func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.62
		_reverb.damping = 0.42
		_reverb.spread = 0.9
		_reverb.dry = 1.0
		_reverb.wet = 0.16
		_reverb.predelay_msec = 14.0
		AudioServer.add_bus_effect(i, _reverb)
	else:
		var idx := AudioServer.get_bus_index("SFX")
		for e in range(AudioServer.get_bus_effect_count(idx)):
			var fx := AudioServer.get_bus_effect(idx, e)
			if fx is AudioEffectReverb:
				_reverb = fx
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "Music")
		AudioServer.set_bus_send(j, "Master")

## Переключение акустики: лестничная клетка гулкая, улица — нет.
func set_indoor(on: bool) -> void:
	if _reverb == null or _indoor == on:
		return
	_indoor = on
	_reverb.wet = 0.30 if on else 0.06
	_reverb.room_size = 0.72 if on else 0.3
	_reverb.damping = 0.32 if on else 0.7

func _try_load(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_streams[key] = load(path)

func _apply_volumes() -> void:
	var m := clampf(float(Svc.meta().settings.get("music", 0.7)), 0.001, 1.0)
	var s := clampf(float(Svc.meta().settings.get("sfx", 0.9)), 0.001, 1.0)
	music_player.volume_db = linear_to_db(m)
	ambient_player.volume_db = linear_to_db(m * 0.45) - 4.0
	for p in _sfx_pool:
		p.volume_db = linear_to_db(s)

func refresh_volumes() -> void:
	_apply_volumes()

func play_sfx(key: String, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	var p: AudioStreamPlayer = _sfx_pool[_pool_i]
	_pool_i = (_pool_i + 1) % _sfx_pool.size()
	p.pitch_scale = pitch
	p.stream = _streams[key]
	p.play()

func play_music(key: String = "music") -> void:
	if not _streams.has(key):
		return
	if music_player.playing and music_player.stream == _streams[key]:
		return
	music_player.stream = _streams[key]
	music_player.play()

func play_ambient() -> void:
	if not _streams.has("ambient"):
		return
	ambient_player.stream = _streams["ambient"]
	if not ambient_player.playing:
		ambient_player.play()

func stop_music() -> void:
	music_player.stop()

func yell_mom() -> void:
	var line: String = _mom_lines[randi() % _mom_lines.size()]
	if not _streams.has(line):
		line = "mom"
	play_sfx(line, 0.92 + randf() * 0.16)

func play_step() -> void:
	var pool: Array = []
	for k in _step_lines:
		if _streams.has(k):
			pool.append(k)
	if pool.is_empty():
		return
	var i := randi() % pool.size()
	if pool.size() > 1 and i == _last_step:
		i = (i + 1) % pool.size()
	_last_step = i
	play_sfx(pool[i], 0.94 + randf() * 0.12)

func set_danger(on: bool) -> void:
	if on and _streams.has("danger_music"):
		play_music("danger_music")
	elif _streams.has("game_music"):
		play_music("game_music")
