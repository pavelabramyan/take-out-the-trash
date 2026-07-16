class_name LevelData
extends RefCounted
## 12 уровней: стили подъезда, thin/carpet/fridge, detour, daily seed hook.

const LEVELS := [
	{
		"id": 1, "style": "khrushchev",
		"title_ru": "Tutorial: вынеси мусор",
		"title_en": "Tutorial: take out the trash",
		"hint_ru": "Жёлтая метка → правый марш → площадка у окна → левый марш → дверь во двор → помойка (E).",
		"hint_en": "Yellow mark → right flight → window landing → left flight → yard door → dumpster (E).",
		"note_ru": "Записка: лестница как в панельке — разворот на промежуточной площадке.",
		"note_en": "Note: panelka U-stairs — turn on the mid landing.",
		"floors": 2, "start_floor": 2, "cargo": "bag", "bag_hp": 140.0, "time_star": 120.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 0, "babushkas": 0, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 2, "style": "khrushchev",
		"title_ru": "Тонкий пакет",
		"title_en": "Thin bag",
		"hint_ru": "Пакет рвётся от любого удара. Alt = аккуратно.",
		"hint_en": "Tears easily. Hold Alt to be careful.",
		"floors": 2, "start_floor": 2, "cargo": "thin", "bag_hp": 55.0, "time_star": 85.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 0, "babushkas": 0, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 3, "style": "brezhnev",
		"title_ru": "9-й этаж. Лифт?",
		"title_en": "9th floor. Elevator?",
		"hint_ru": "Лифт едет. Иногда застревает на полпути.",
		"hint_en": "Elevator moves. Sometimes jams mid-way.",
		"floors": 9, "start_floor": 9, "cargo": "bag", "bag_hp": 90.0, "time_star": 180.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": true,
		"dogs": 0, "babushkas": 1, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 4, "style": "brezhnev",
		"title_ru": "Лифт-лотерея",
		"title_en": "Elevator lottery",
		"hint_ru": "E у лифта. Удачи.",
		"hint_en": "E at elevator. Good luck.",
		"floors": 9, "start_floor": 9, "cargo": "bag", "bag_hp": 75.0, "time_star": 160.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": true,
		"dogs": 0, "babushkas": 2, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 5, "style": "khrushchev",
		"title_ru": "Ночь. Блэкаут",
		"title_en": "Night. Blackout",
		"hint_ru": "F — фонарик. Темно и страшно.",
		"hint_en": "F — flashlight. Dark and spooky.",
		"floors": 5, "start_floor": 5, "cargo": "bag", "bag_hp": 80.0, "time_star": 140.0,
		"night": true, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 0, "babushkas": 0, "basement": false, "light_timer": 5.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 6, "style": "courtyard",
		"title_ru": "Подвал",
		"title_en": "Basement",
		"hint_ru": "Через подвал короче. Лужи скользкие.",
		"hint_en": "Basement is shorter. Puddles are slick.",
		"floors": 4, "start_floor": 4, "cargo": "bag", "bag_hp": 85.0, "time_star": 150.0,
		"night": true, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 0, "babushkas": 1, "basement": true, "light_timer": 6.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 7, "style": "khrushchev",
		"title_ru": "Зима. Лёд",
		"title_en": "Winter. Ice",
		"hint_ru": "Видишь голубые полосы — не беги.",
		"hint_en": "Blue strips = ice. Don't sprint.",
		"floors": 3, "start_floor": 3, "cargo": "bag", "bag_hp": 70.0, "time_star": 120.0,
		"night": false, "ice": true, "wind": 0.0, "elevator": false,
		"dogs": 0, "babushkas": 1, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 8, "style": "courtyard",
		"title_ru": "Ветер",
		"title_en": "Wind",
		"hint_ru": "Ветер рвёт пакет. Держи Alt.",
		"hint_en": "Wind yanks the bag. Hold Alt.",
		"floors": 4, "start_floor": 4, "cargo": "bag", "bag_hp": 65.0, "time_star": 130.0,
		"night": false, "ice": true, "wind": 12.0, "elevator": false,
		"dogs": 0, "babushkas": 0, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 9, "style": "courtyard",
		"title_ru": "Собаки / обход",
		"title_en": "Dogs / detour",
		"hint_ru": "Короткий путь у помойки — собаки. Слева длинный обход.",
		"hint_en": "Short path = dogs. Left side = long detour.",
		"floors": 3, "start_floor": 3, "cargo": "bag", "bag_hp": 80.0, "time_star": 110.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 2, "babushkas": 0, "basement": false, "light_timer": 0.0,
		"detour": true, "babushka_talk": true,
	},
	{
		"id": 10, "style": "brezhnev",
		"title_ru": "Вёдра и бабушки",
		"title_en": "Buckets and babushkas",
		"hint_ru": "Присядь (Ctrl) — меньше видят. Или выслушай 3 сек.",
		"hint_en": "Crouch (Ctrl) = less vision. Or wait out 3s talk.",
		"floors": 5, "start_floor": 5, "cargo": "buckets", "bag_hp": 120.0, "time_star": 160.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": false,
		"dogs": 1, "babushkas": 3, "basement": false, "light_timer": 0.0,
		"detour": true, "babushka_talk": true,
	},
	{
		"id": 11, "style": "khrushchev",
		"title_ru": "Ковёр в проёме",
		"title_en": "Carpet in the doorway",
		"hint_ru": "Широкий груз. Не крутись в узких местах.",
		"hint_en": "Wide cargo. Don't spin in tight spots.",
		"floors": 6, "start_floor": 6, "cargo": "carpet", "bag_hp": 150.0, "time_star": 200.0,
		"night": false, "ice": false, "wind": 0.0, "elevator": true,
		"dogs": 0, "babushkas": 2, "basement": false, "light_timer": 0.0,
		"detour": false, "babushka_talk": true,
	},
	{
		"id": 12, "style": "brezhnev",
		"title_ru": "Холодильник",
		"title_en": "The fridge",
		"hint_ru": "Финал. Тяжёлый. Если порвётся — сыпется еда.",
		"hint_en": "Finale. Heavy. Burst = food avalanche.",
		"note_ru": "Записка: холодильник дошёл. Мама гордится (на минуту).",
		"note_en": "Note: fridge delivered. Mom is proud (for a minute).",
		"floors": 7, "start_floor": 7, "cargo": "fridge", "bag_hp": 200.0, "time_star": 240.0,
		"night": false, "ice": true, "wind": 4.0, "elevator": false,
		"dogs": 1, "babushkas": 2, "basement": false, "light_timer": 0.0,
		"detour": true, "babushka_talk": true,
	},
]

static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	var lv: Dictionary = LEVELS[index].duplicate(true)
	# Daily seed: лёгкий сдвиг HP/патрулей от дня года
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 17 + index * 31
	if int(lv.get("dogs", 0)) > 0:
		lv["dogs"] = clampi(int(lv["dogs"]) + (1 if rng.randf() < 0.15 else 0), 0, 4)
	# NG+
	return lv

static func count() -> int:
	if OS.has_feature("demo"):
		return mini(3, LEVELS.size())
	return LEVELS.size()

static func apply_ng_plus(lv: Dictionary) -> Dictionary:
	var out := lv.duplicate(true)
	out["bag_hp"] = float(out.get("bag_hp", 100)) * 0.55
	return out
