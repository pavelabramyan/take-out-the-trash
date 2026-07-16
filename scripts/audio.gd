extends Node
## Пул SFX + музыка меню/игры + VO мамы + ambient.

var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var _sfx_pool: Array = []
var _pool_i: int = 0
var _streams: Dictionary = {}
var _mom_lines: Array = ["mom", "mom2", "mom3"]

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -8.0
	add_child(ambient_player)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	_apply_volumes()
	for k in ["burst", "pickup", "dump", "impact", "slip", "bark", "babushka", "mom", "mom2", "mom3", "elevator", "win", "fail", "step"]:
		_try_load(k, "res://assets/sfx/%s.wav" % k)
	_try_load("music", "res://assets/music/menu_loop.wav")
	_try_load("game_music", "res://assets/music/game_loop.wav")
	_try_load("danger_music", "res://assets/music/danger_loop.wav")
	_try_load("ambient", "res://assets/music/ambient_hall.wav")

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
	play_sfx("step", 0.9 + randf() * 0.2)

func set_danger(on: bool) -> void:
	if on and _streams.has("danger_music"):
		play_music("danger_music")
	elif _streams.has("game_music"):
		play_music("game_music")
