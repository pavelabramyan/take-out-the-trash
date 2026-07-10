extends Node
## SFX / музыка. Процедурные WAV из assets/sfx, fallback — тишина.

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var _streams: Dictionary = {}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	_apply_volumes()
	_try_load("burst", "res://assets/sfx/burst.wav")
	_try_load("pickup", "res://assets/sfx/pickup.wav")
	_try_load("dump", "res://assets/sfx/dump.wav")
	_try_load("impact", "res://assets/sfx/impact.wav")
	_try_load("slip", "res://assets/sfx/slip.wav")
	_try_load("bark", "res://assets/sfx/bark.wav")
	_try_load("babushka", "res://assets/sfx/babushka.wav")
	_try_load("mom", "res://assets/sfx/mom.wav")
	_try_load("elevator", "res://assets/sfx/elevator.wav")
	_try_load("win", "res://assets/sfx/win.wav")
	_try_load("music", "res://assets/music/menu_loop.wav")

func _try_load(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_streams[key] = load(path)

func _apply_volumes() -> void:
	music_player.volume_db = linear_to_db(clampf(float(Svc.meta().settings.get("music", 0.7)), 0.001, 1.0))
	sfx_player.volume_db = linear_to_db(clampf(float(Svc.meta().settings.get("sfx", 0.9)), 0.001, 1.0))

func refresh_volumes() -> void:
	_apply_volumes()

func play_sfx(key: String, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	sfx_player.pitch_scale = pitch
	sfx_player.stream = _streams[key]
	sfx_player.play()

func play_music(key: String = "music") -> void:
	if not _streams.has(key):
		return
	if music_player.playing and music_player.stream == _streams[key]:
		return
	music_player.stream = _streams[key]
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func yell_mom() -> void:
	play_sfx("mom", 0.95 + randf() * 0.1)
