extends Node
## Прогресс, настройки, статистика, cloud-ready save.

const SAVE_PATH := "user://meta.json"
const CLOUD_FLAG := "user://steam_cloud_ok.txt"

var settings: Dictionary = {
	"lang": "ru",
	"music": 0.7,
	"sfx": 0.9,
	"mouse_sens": 1.0,
	"invert_y": false,
	"fov": 75.0,
	"fullscreen": false,
	"vsync": true,
	"difficulty": "normal",
	"ng_plus": false,
	"bag_skin": "default",
}
var progress: Dictionary = {
	"unlocked": 1,
	"stars": {},
	"achievements": {},
	"best_times": {},
	"stats": {"dumps": 0, "bursts": 0, "fails": 0},
	"notes": [],
	"skins": ["default"],
}
var current_level: int = 0

func _ready() -> void:
	load_all()
	_apply_display()

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
		if not progress.has("stats"):
			progress["stats"] = {"dumps": 0, "bursts": 0, "fails": 0}

func save_all() -> void:
	var payload := {"settings": settings, "progress": progress}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	# Хук под Steam Cloud: файл в user:// подхватывается Steamworks при настройке Autocloud
	if FileAccess.file_exists(CLOUD_FLAG) or int(ProjectSettings.get_setting("steam/initialization/app_id", 0)) > 0:
		pass

func _apply_display() -> void:
	# На Mac AMD + MoltenVK fullscreen/Retina 3–4K swapchain часто роняет процесс без лога.
	# Держим окно 1280×720, пока не будет стабильного рендера.
	var want_fs := bool(settings.get("fullscreen", false))
	if OS.get_name() == "macOS":
		want_fs = false
		settings["fullscreen"] = false
	if want_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var scr := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(Vector2i(maxi(40, (scr.x - 1280) / 2), maxi(40, (scr.y - 720) / 2)))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
	)

func unlock_level(level_1based: int) -> void:
	progress["unlocked"] = maxi(int(progress.get("unlocked", 1)), level_1based)
	save_all()

func set_stars(level_1based: int, stars: int) -> void:
	var key := str(level_1based)
	var prev := int(progress["stars"].get(key, 0))
	progress["stars"][key] = maxi(prev, clampi(stars, 0, 3))
	var total := 0
	for k in progress["stars"].keys():
		total += int(progress["stars"][k])
	if total >= 12 and not ("green" in progress.get("skins", [])):
		progress["skins"].append("green")
	save_all()

func get_stars(level_1based: int) -> int:
	return int(progress["stars"].get(str(level_1based), 0))

func set_best_time(level_1based: int, t: float) -> void:
	var key := str(level_1based)
	var prev = progress["best_times"].get(key, null)
	if prev == null or float(prev) > t:
		progress["best_times"][key] = t
		save_all()

func add_stat(key: String, amount: int = 1) -> void:
	if not progress.has("stats"):
		progress["stats"] = {}
	progress["stats"][key] = int(progress["stats"].get(key, 0)) + amount
	save_all()

func mark_achievement(id: String) -> void:
	if progress["achievements"].get(id, false):
		return
	progress["achievements"][id] = true
	save_all()
	Svc.steam().unlock(id)

func unlock_note(text: String) -> void:
	if not progress.has("notes"):
		progress["notes"] = []
	var notes: Array = progress["notes"]
	if text in notes:
		return
	notes.append(text)
	progress["notes"] = notes
	save_all()

func get_notes() -> Array:
	return progress.get("notes", [])
