class_name BuildingBuilder
extends Node3D
## Подъезд: читаемые площадки + широкий марш в проёме + двор.

const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 3.0
const SHAFT_W := 5.0
const STAIR_W := 1.9
## Проём лестницы в площадке (z: от квартир к фасаду)
const HOLE_Z0 := 0.45
const HOLE_Z1 := 2.75
const HOLE_W := 2.05

var player: CharacterBody3D
var bag: RigidBody3D
var dumpster: Area3D
var elevator_area: Area3D
var spawn_pos: Vector3 = Vector3.ZERO
var yard_ice_zones: Array = []
var npcs: Array = []
var lights: Array = []

var _mats: Dictionary = {}
var _level: Dictionary = {}

func build(level: Dictionary) -> void:
	_level = level
	_make_materials()
	var floors: int = int(level.get("floors", 2))
	var start_floor: int = int(level.get("start_floor", floors))
	var night: bool = bool(level.get("night", false))
	var has_basement: bool = bool(level.get("basement", false))
	var has_elevator: bool = bool(level.get("elevator", false))
	var ice: bool = bool(level.get("ice", false))

	_add_world_env(night)
	_build_stairwell(floors, has_basement)
	_build_apartment_door(start_floor)
	_build_yard(ice)
	if bool(level.get("detour", false)):
		_build_detour_path()
	_build_dumpster()
	if has_elevator:
		_build_elevator(floors)
	if has_basement:
		_build_basement_props()
	_spawn_npcs(level)
	_spawn_player_and_bag(start_floor, level)
	Svc.audio().play_ambient()
	Svc.audio().play_music("game_music")

func _make_materials() -> void:
	var style: String = str(_level.get("style", "khrushchev"))
	var wall_c := Color(0.78, 0.74, 0.68)
	var tile_c := Color(0.58, 0.6, 0.62)
	match style:
		"brezhnev":
			wall_c = Color(0.62, 0.66, 0.7)
			tile_c = Color(0.45, 0.48, 0.5)
		"courtyard":
			wall_c = Color(0.72, 0.62, 0.55)
			tile_c = Color(0.5, 0.48, 0.42)
		_:
			pass
	_mats["wall"] = _tex_mat("res://assets/textures/wall.png", wall_c)
	_mats["tile"] = _tex_mat("res://assets/textures/tile.png", tile_c)
	_mats["rail"] = _mat(Color(0.45, 0.28, 0.18))
	_mats["door"] = _tex_mat("res://assets/textures/door.png", Color(0.42, 0.28, 0.2))
	_mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", Color(0.48, 0.48, 0.46))
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.25)
	_mats["dumpster"] = _tex_mat("res://assets/textures/dumpster.png", Color(0.2, 0.45, 0.25))
	_mats["mail"] = _mat(Color(0.55, 0.35, 0.2))
	_mats["mark"] = _mat(Color(0.15, 0.95, 0.35))
	(_mats["mark"] as StandardMaterial3D).emission_enabled = true
	(_mats["mark"] as StandardMaterial3D).emission = Color(0.15, 0.95, 0.35)
	(_mats["mark"] as StandardMaterial3D).emission_energy_multiplier = 2.5
	_mats["prop"] = _mat(Color(0.35, 0.38, 0.4))

func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9 - metallic * 0.5
	m.metallic = metallic
	return m

func _tex_mat(path: String, fallback: Color) -> StandardMaterial3D:
	var m := _mat(fallback)
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(2, 2, 2)
	return m

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1) if night else Color(0.55, 0.65, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.22, 0.28) if night else Color(0.5, 0.52, 0.55)
	env.ambient_light_energy = 0.45 if night else 0.85
	env.fog_enabled = night
	if night:
		env.fog_light_color = Color(0.08, 0.1, 0.15)
		env.fog_density = 0.02
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	# Лёгкий виньет через glow
	env.glow_enabled = true
	env.glow_intensity = 0.15
	env.glow_strength = 0.6
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.2 if night else 1.15
	sun.light_color = Color(0.6, 0.7, 1.0) if night else Color(1, 0.98, 0.92)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)

func _box(pos: Vector3, size: Vector3, mat_key: String, with_collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if with_collision else 0
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat_key]
	body.add_child(mi)
	if with_collision:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
	body.position = pos
	add_child(body)
	return body

func _build_stairwell(floors: int, basement: bool) -> void:
	var top := float(floors) * FLOOR_H

	# Наружные стены шахты
	_box(Vector3(-2.55, top * 0.5 + 0.5, 1.2), Vector3(0.2, top + 3.0, 5.6), "wall")
	_box(Vector3(2.55, top * 0.5 + 0.5, 1.2), Vector3(0.2, top + 3.0, 5.6), "wall")
	_box(Vector3(0, top * 0.5 + 0.5, -1.5), Vector3(5.3, top + 3.0, 0.2), "wall")

	# Фасад: дверной проём только на 1 этаже
	_box(Vector3(-1.75, 1.5, 3.85), Vector3(1.7, 3.0, 0.2), "wall")
	_box(Vector3(1.75, 1.5, 3.85), Vector3(1.7, 3.0, 0.2), "wall")
	_box(Vector3(0, 2.9, 3.85), Vector3(5.3, 0.4, 0.2), "wall")
	if floors >= 2:
		var uh := top - 3.0
		_box(Vector3(0, 3.0 + uh * 0.5, 3.85), Vector3(5.3, maxf(uh, 0.2), 0.2), "wall")

	# Пол 1 этажа — весь, выход во двор через проём
	_box(Vector3(0, -0.1, 1.2), Vector3(5.0, 0.2, 5.2), "tile")
	_box(Vector3(0, 1.1, 3.7), Vector3(1.05, 2.2, 0.05), "door", false)
	# Стрелка к выходу на 1 этаже
	_box(Vector3(0, 0.05, 3.2), Vector3(0.5, 0.06, 0.8), "mark", false)

	if basement:
		_box(Vector3(0, -FLOOR_H - 0.1, 1.2), Vector3(5.0, 0.2, 5.2), "concrete")
		_add_flight(1, true)  # с 1 на подвал (y=0 → y=-FLOOR_H через from=1)
		var bl := OmniLight3D.new()
		bl.light_color = Color(0.9, 0.7, 0.4)
		bl.light_energy = 1.0
		bl.omni_range = 7.0
		bl.position = Vector3(0, -FLOOR_H + 2.0, 1.0)
		add_child(bl)
		lights.append(bl)

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		var left := (f % 2 == 1)
		_add_floor_landing(y, left)
		# При подвале марш 1→0 уже добавлен выше — не дублируем
		if not (basement and f == 1):
			_add_flight(f, left)
		_add_simple_rail(y, left)
		_add_stair_marker(y, left)

		if f == 1:
			_box(Vector3(-2.15, 1.15, -0.85), Vector3(0.35, 1.3, 0.12), "mail")

		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.93, 0.8)
		lamp.light_energy = 1.6
		lamp.omni_range = 8.0
		lamp.position = Vector3(0, y + 2.5, 0.3)
		add_child(lamp)
		lights.append(lamp)

	_box(Vector3(0, top + 0.2, 1.2), Vector3(5.3, 0.3, 5.4), "concrete")

func _add_floor_landing(y: float, left_stair: bool) -> void:
	## Площадка с ЯВНЫМ прямоугольным проёмом под марш — без перекрытия ступеней.
	var hx := -1.0 if left_stair else 1.0
	var hole_l := hx - HOLE_W * 0.5
	var hole_r := hx + HOLE_W * 0.5
	# Задняя площадка (квартиры) — до края проёма
	var back_z0 := -1.35
	var back_depth := HOLE_Z0 - back_z0
	_box(Vector3(0, y - 0.1, back_z0 + back_depth * 0.5), Vector3(5.0, 0.2, back_depth), "tile")
	# Передняя перемычка
	var front_z1 := 3.2
	var front_depth := front_z1 - HOLE_Z1
	_box(Vector3(0, y - 0.1, HOLE_Z1 + front_depth * 0.5), Vector3(5.0, 0.2, front_depth), "tile")
	# Боковые плиты слева/справа от проёма (на всю глубину проёма)
	var mid_z := (HOLE_Z0 + HOLE_Z1) * 0.5
	var mid_depth := HOLE_Z1 - HOLE_Z0
	var left_w := hole_l - (-2.5)
	if left_w > 0.15:
		_box(Vector3(-2.5 + left_w * 0.5, y - 0.1, mid_z), Vector3(left_w, 0.2, mid_depth), "tile")
	var right_w := 2.5 - hole_r
	if right_w > 0.15:
		_box(Vector3(hole_r + right_w * 0.5, y - 0.1, mid_z), Vector3(right_w, 0.2, mid_depth), "tile")

func _add_flight(from_floor: int, left_side: bool) -> void:
	## Ступени С коллизией + корректный пандус (раньше угол был перевёрнут — спуск = стена).
	var y0 := float(from_floor) * FLOOR_H
	var y1 := float(from_floor - 1) * FLOOR_H
	var x := -1.0 if left_side else 1.0
	var steps := 12
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y0, y1, t) - 0.02
		var z := lerpf(HOLE_Z0 + 0.08, HOLE_Z1 - 0.08, t)
		# Коллизия на каждой ступени — CharacterBody спокойно шагает вниз
		_box(Vector3(x, y, z), Vector3(STAIR_W, 0.14, 0.36), "concrete", true)
	_add_ramp(x, y0, y1)

func _add_ramp(x: float, y_top: float, y_bot: float) -> void:
	## Страховка под ступенями. rotation.x > 0: верх у квартир (малый z), низ у фасада.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var run := HOLE_Z1 - HOLE_Z0
	var rise := y_top - y_bot
	var length := sqrt(run * run + rise * rise)
	sh.size = Vector3(STAIR_W - 0.2, 0.1, length)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(x, (y_top + y_bot) * 0.5 - 0.08, (HOLE_Z0 + HOLE_Z1) * 0.5)
	# ВАЖНО: плюс atan2 — раньше минус переворачивал пандус и блокировал спуск
	body.rotation.x = atan2(rise, run)
	add_child(body)

func _add_simple_rail(y: float, left_stair: bool) -> void:
	## Перила вокруг ПРОЁМА: нельзя упасть в дыру, вход только с зелёной метки.
	var hx := -1.0 if left_stair else 1.0
	var hole_l := hx - HOLE_W * 0.5
	var hole_r := hx + HOLE_W * 0.5
	var mid_z := (HOLE_Z0 + HOLE_Z1) * 0.5
	var mid_depth := HOLE_Z1 - HOLE_Z0
	# Бока проёма — высокие, чтобы не перепрыгнуть в шахту
	_box(Vector3(hole_l, y + 0.7, mid_z), Vector3(0.08, 1.3, mid_depth), "rail")
	_box(Vector3(hole_r, y + 0.7, mid_z), Vector3(0.08, 1.3, mid_depth), "rail")
	# Дальний край проёма (у фасада) — закрыт
	_box(Vector3(hx, y + 0.7, HOLE_Z1), Vector3(HOLE_W, 1.3, 0.08), "rail")
	# У входа (зелёная метка) перил НЕТ — сюда заходишь на ступени

func _add_stair_marker(y: float, left_stair: bool) -> void:
	## Зелёная метка = вход на лестницу (задний край проёма).
	var x := -1.0 if left_stair else 1.0
	_box(Vector3(x, y + 0.03, HOLE_Z0 - 0.12), Vector3(0.85, 0.06, 0.4), "mark", false)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	_box(Vector3(-2.4, y + 1.1, -0.55), Vector3(0.08, 2.1, 0.85), "door", false)
	spawn_pos = Vector3(0.0, y + 0.3, -0.4)

func _build_yard(ice: bool) -> void:
	var mat_key := "ice" if ice else "concrete"
	_box(Vector3(0, -0.15, 10.0), Vector3(18.0, 0.3, 14.0), mat_key)
	_box(Vector3(-8.0, 0.6, 10.0), Vector3(1.0, 1.2, 12.0), "wall")
	_box(Vector3(8.0, 0.6, 10.0), Vector3(1.0, 1.2, 12.0), "wall")
	_box(Vector3(0, 0.8, 16.5), Vector3(16.0, 1.6, 1.0), "wall")
	_box(Vector3(0, 6.0, -2.6), Vector3(14.0, 14.0, 1.0), "wall")
	# Декор двора: машины/деревья-примитивы
	_box(Vector3(-5.5, 0.55, 8.0), Vector3(2.2, 1.0, 1.1), "prop")
	_box(Vector3(6.0, 1.2, 11.0), Vector3(0.35, 2.4, 0.35), "prop")
	_box(Vector3(6.0, 2.5, 11.0), Vector3(1.6, 0.5, 1.6), "wall")
	# Объявления / щит
	_box(Vector3(-2.3, 1.6, 3.5), Vector3(0.05, 0.7, 0.5), "mail", false)
	if ice:
		# Видимые ледяные полосы
		_box(Vector3(0, 0.02, 9.0), Vector3(4.0, 0.06, 1.2), "ice")
		_box(Vector3(2.5, 0.02, 12.0), Vector3(3.0, 0.06, 1.0), "ice")
		yard_ice_zones.append(Rect2(Vector2(-7, 4), Vector2(14, 12)))

func _build_detour_path() -> void:
	## Длинный обход вокруг двора — безопаснее собак.
	_box(Vector3(-6.5, -0.05, 10.0), Vector3(2.5, 0.15, 10.0), "concrete")
	_box(Vector3(-6.5, 0.05, 14.5), Vector3(0.6, 0.08, 0.6), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(1.5, -FLOOR_H + 0.4, 1.0), Vector3(0.3, 0.3, 2.5), "prop")
	_box(Vector3(-1.2, -FLOOR_H + 0.15, 2.0), Vector3(1.2, 0.08, 1.2), "ice")
	var bl := OmniLight3D.new()
	bl.light_color = Color(0.7, 0.5, 0.3)
	bl.light_energy = 0.8
	bl.omni_range = 5.0
	bl.position = Vector3(0, -FLOOR_H + 2.0, 0.5)
	add_child(bl)

func _build_dumpster() -> void:
	_box(Vector3(3.5, 0.7, 13.5), Vector3(2.2, 1.4, 1.4), "dumpster")
	dumpster = Area3D.new()
	dumpster.name = "Dumpster"
	dumpster.collision_layer = 0
	dumpster.collision_mask = 2 | 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.8, 2.0, 2.0)
	cs.shape = sh
	dumpster.add_child(cs)
	dumpster.position = Vector3(3.5, 1.0, 13.5)
	add_child(dumpster)
	_box(Vector3(3.5, 2.15, 13.5), Vector3(0.35, 0.35, 0.35), "mark", false)

func _build_elevator(floors: int) -> void:
	_box(Vector3(2.2, floors * FLOOR_H * 0.5, -0.75), Vector3(0.9, floors * FLOOR_H, 0.9), "wall")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.1, 2.4, 1.1)
	cs.shape = sh
	elevator_area.add_child(cs)
	elevator_area.position = Vector3(2.2, float(_level.get("start_floor", 1)) * FLOOR_H + 1.0, -0.75)
	add_child(elevator_area)
	_box(Vector3(2.2, float(_level.get("start_floor", 1)) * FLOOR_H + 1.1, -0.25), Vector3(0.85, 2.1, 0.06), "door", false)

func _spawn_npcs(level: Dictionary) -> void:
	var dogs: int = int(level.get("dogs", 0))
	var babushkas: int = int(level.get("babushkas", 0))
	for i in range(babushkas):
		var npc = StairNpcScr.new()
		add_child(npc)
		npc.setup(0, Vector3(-3.5 + i * 0.8, 0.2, 9.0 + i * 1.2), Vector3(1.5 + i * 0.5, 0.2, 12.0 + i * 0.8), null)
		npcs.append(npc)
	for i in range(dogs):
		var dog = StairNpcScr.new()
		add_child(dog)
		dog.setup(1, Vector3(2.0 + i, 0.2, 12.5), Vector3(5.5 + i * 0.3, 0.2, 14.5), null)
		npcs.append(dog)

func _spawn_player_and_bag(_start_floor: int, level: Dictionary) -> void:
	var p = TrashPlayerScr.new()
	add_child(p)
	p.global_position = spawn_pos
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = spawn_pos + Vector3(0.35, 0.7, 0.15)
	bag = trash

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", 0.25, period * 0.5)
			tw.tween_property(lamp, "light_energy", 1.6, period * 0.5)

func is_on_ice(pos: Vector3) -> bool:
	for r in yard_ice_zones:
		if (r as Rect2).has_point(Vector2(pos.x, pos.z)):
			return true
	return false
