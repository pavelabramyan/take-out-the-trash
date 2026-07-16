extends Node
## RU / EN локализация.

var lang: String = "ru"

const T := {
	"play": {"ru": "Играть", "en": "Play"},
	"continue": {"ru": "Продолжить", "en": "Continue"},
	"levels": {"ru": "Уровни", "en": "Levels"},
	"settings": {"ru": "Настройки", "en": "Settings"},
	"quit": {"ru": "Выход", "en": "Quit"},
	"back": {"ru": "Назад", "en": "Back"},
	"resume": {"ru": "Продолжить", "en": "Resume"},
	"restart": {"ru": "Заново (R)", "en": "Restart (R)"},
	"menu": {"ru": "В меню", "en": "Main menu"},
	"volume_music": {"ru": "Музыка", "en": "Music"},
	"volume_sfx": {"ru": "Звуки", "en": "SFX"},
	"language": {"ru": "Язык", "en": "Language"},
	"mouse_sens": {"ru": "Чувствительность мыши", "en": "Mouse sensitivity"},
	"invert_y": {"ru": "Инверсия Y", "en": "Invert Y"},
	"fov": {"ru": "FOV", "en": "FOV"},
	"fullscreen": {"ru": "Полный экран", "en": "Fullscreen"},
	"vsync": {"ru": "VSync", "en": "VSync"},
	"difficulty": {"ru": "Сложность", "en": "Difficulty"},
	"achievements": {"ru": "Ачивки", "en": "Achievements"},
	"stats": {"ru": "Статистика", "en": "Stats"},
	"notes": {"ru": "Записки", "en": "Notes"},
	"wishlist": {"ru": "Wishlist на Steam", "en": "Wishlist on Steam"},
	"win": {"ru": "ВЫНЕС!", "en": "TAKEN OUT!"},
	"fail_burst": {"ru": "Пакет порвался…", "en": "Bag burst…"},
	"fail_caught": {"ru": "Поймали на допросе", "en": "Caught for interrogation"},
	"fail_dog": {"ru": "Собаки!", "en": "Dogs!"},
	"fail_fall": {"ru": "Упал с пакетом", "en": "Fell with the bag"},
	"stars": {"ru": "Звёзды", "en": "Stars"},
	"star_time": {"ru": "Быстро", "en": "Fast"},
	"star_intact": {"ru": "Без разрывов", "en": "No tears"},
	"star_stealth": {"ru": "Стелс", "en": "Stealth"},
	"next": {"ru": "Дальше", "en": "Next"},
	"pick_trash": {"ru": "E — поднять мусор в охапку", "en": "E — pick trash into armful"},
	"pick_bag": {"ru": "E — поднять пакет", "en": "E — pick up bag"},
	"dumpster": {"ru": "E — выбросить", "en": "E — dump"},
	"elevator": {"ru": "E — лифт", "en": "E — elevator"},
	"mom_yell": {"ru": "ВЫНЕСИ МУСОР!!!", "en": "TAKE OUT THE TRASH!!!"},
	"paused": {"ru": "Пауза", "en": "Paused"},
	"level": {"ru": "Уровень", "en": "Level"},
	"bag_hp": {"ru": "Пакет", "en": "Bag"},
	"credits": {"ru": "Спасибо, что вынесли мусор.\nМама гордится (наверно).", "en": "Thanks for taking out the trash.\nMom is proud (probably)."},
	"fun_gate": {"ru": "Смешно?", "en": "Funny?"},
	"tagline": {"ru": "Мама сказала. Пакет рвётся. Соседи смотрят.", "en": "Mom said so. Bag tears. Neighbors stare. Chore physics comedy."},
	"babushka_listen": {"ru": "Бабушка допрашивает… постой 3 сек", "en": "Babushka interrogates… wait 3s"},
	"babushka_ok": {"ru": "Отпустила. Стелс ★ потеряна.", "en": "She let you go. Stealth ★ lost."},
	"replay_hint": {"ru": "(replay буфер записан — перескажи друзьям)", "en": "(fail replay buffer saved — tell your friends)"},
	"controls_hint": {"ru": "WASD · E поднять · ЛКМ бросок · ПКМ дроп · Alt аккуратно · F фонарь · R рестарт", "en": "WASD · E grab · LMB throw · RMB drop · Alt careful · F light · R restart"},
	"ng_plus": {"ru": "New Game+ (хрупкий пакет)", "en": "New Game+ (fragile bag)"},
}

func _ready() -> void:
	lang = Svc.meta().settings.get("lang", "ru")

func t(key: String) -> String:
	if not T.has(key):
		return key
	var entry: Dictionary = T[key]
	return str(entry.get(lang, entry.get("en", key)))

func set_lang(code: String) -> void:
	lang = code if code in ["ru", "en"] else "ru"
	Svc.meta().settings["lang"] = lang
	Svc.meta().save_all()
