extends Node
## Steam-ачивки через GodotSteam (если AppID задан). Иначе — только локальный прогресс.

const ACHIEVEMENTS := {
	"first_dump": {"ru": "Первый вынос", "en": "First dump"},
	"burst_once": {"ru": "Пакет порвался", "en": "Bag burst"},
	"no_tear_star": {"ru": "Целый пакет", "en": "Intact bag"},
	"stealth_star": {"ru": "Невидимка подъезда", "en": "Stairwell ghost"},
	"speed_star": {"ru": "Спринтер помойки", "en": "Dumpster sprinter"},
	"elevator_luck": {"ru": "Лифт повезло", "en": "Elevator luck"},
	"elevator_fail": {"ru": "Лифт застрял", "en": "Elevator jam"},
	"ice_slip": {"ru": "На льду", "en": "On ice"},
	"dog_escape": {"ru": "Мимо собак", "en": "Past the dogs"},
	"babushka_escape": {"ru": "Мимо бабушек", "en": "Past babushkas"},
	"carpet_done": {"ru": "Ковёр вынесен", "en": "Carpet out"},
	"fridge_done": {"ru": "Холодильник!", "en": "Fridge!"},
	"all_stars": {"ru": "36 звёзд", "en": "36 stars"},
	"all_levels": {"ru": "Все 12", "en": "All 12"},
	"mom_proud": {"ru": "Мама гордится", "en": "Mom is proud"},
	"wind_hold": {"ru": "Удержал в ветре", "en": "Held in the wind"},
	"basement_run": {"ru": "Через подвал", "en": "Through basement"},
	"night_dump": {"ru": "Ночной вынос", "en": "Night dump"},
	"triple_star": {"ru": "Три звезды на уровне", "en": "Triple star"},
	"restart_king": {"ru": "10 рестартов подряд", "en": "10 restarts"},
}

var _steam_ok: bool = false
var _restart_streak: int = 0

func _ready() -> void:
	_init_steam()

func _init_steam() -> void:
	if not ClassDB.class_exists("Steam"):
		return
	# AppID 0 = offline / ещё не зарегистрирован
	var app_id := int(ProjectSettings.get_setting("steam/initialization/app_id", 0))
	if app_id <= 0:
		return
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null:
		return
	var res = steam.steamInitEx(true, app_id)
	_steam_ok = typeof(res) == TYPE_DICTIONARY and int(res.get("status", 1)) == 0

func unlock(id: String) -> void:
	if not ACHIEVEMENTS.has(id):
		return
	Svc.meta().progress["achievements"][id] = true
	Svc.meta().save_all()
	if not _steam_ok:
		return
	var steam = Engine.get_singleton("Steam")
	if steam:
		steam.setAchievement(id)
		steam.storeStats()

func note_restart() -> void:
	_restart_streak += 1
	if _restart_streak >= 10:
		unlock("restart_king")

func note_win_reset_restarts() -> void:
	_restart_streak = 0

func list_ids() -> Array:
	return ACHIEVEMENTS.keys()
