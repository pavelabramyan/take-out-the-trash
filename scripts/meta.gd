extends Node
## Прогресс, настройки, звёзды. user://meta.json

const SAVE_PATH := "user://meta.json"

var settings: Dictionary = {
	"lang": "ru",
	"music": 0.7,
	"sfx": 0.9,
	"mouse_sens": 1.0,
}
var progress: Dictionary = {
	"unlocked": 1,
	"stars": {},  # "1": 0..3
	"achievements": {},
	"best_times": {},
}
var current_level: int = 0  # 0-based

func _ready() -> void:
	load_all()

func load_all() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("settings"):
		settings.merge(data["settings"], true)
	if data.has("progress"):
		progress.merge(data["progress"], true)

func save_all() -> void:
	var payload := {"settings": settings, "progress": progress}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()

func unlock_level(level_1based: int) -> void:
	progress["unlocked"] = maxi(int(progress.get("unlocked", 1)), level_1based)
	save_all()

func set_stars(level_1based: int, stars: int) -> void:
	var key := str(level_1based)
	var prev := int(progress["stars"].get(key, 0))
	progress["stars"][key] = maxi(prev, clampi(stars, 0, 3))
	save_all()

func get_stars(level_1based: int) -> int:
	return int(progress["stars"].get(str(level_1based), 0))

func set_best_time(level_1based: int, t: float) -> void:
	var key := str(level_1based)
	var prev = progress["best_times"].get(key, null)
	if prev == null or float(prev) > t:
		progress["best_times"][key] = t
		save_all()

func mark_achievement(id: String) -> void:
	if progress["achievements"].get(id, false):
		return
	progress["achievements"][id] = true
	save_all()
	Svc.steam().unlock(id)
