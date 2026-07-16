class_name BuildingBuilder
extends Node3D
## Клетка 9-этажной панельки: U-лестница с промежуточными площадками,
## зелёнка, двери с глазками, ящики, фасад со швами. Пандусы под ступенями.

const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 2.8
const HALF_H := 1.4
const STAIR_W := 1.15
## Квартирная площадка (зад)
const LAND_Z0 := -1.35
const LAND_Z1 := 0.55
## Промежуточная площадка (не над тамбуром у двери — иначе потолок 1.2 м)
const MID_Z0 := 2.30
const MID_Z1 := 2.95
## Марш: площадка → mid (run 1.75 м, подъём 1.4 → ~39°)
const FLIGHT_Z_A0 := 0.55
const FLIGHT_Z_A1 := 2.30
const DOOR_Z := 3.85
## Тамбур у двери: полный потолок, mid заканчивается раньше
const LOBBY_Z0 := 3.05

var player: CharacterBody3D
var bag: RigidBody3D
var dumpster: Area3D
var elevator_area: Area3D
var spawn_pos: Vector3 = Vector3.ZERO
var yard_ice_zones: Array = []
var npcs: Array = []
var lights: Array = []
var _floors: int = 2

var _mats: Dictionary = {}
var _level: Dictionary = {}

func build(level: Dictionary) -> void:
	_level = level
	_make_materials()
	_floors = int(level.get("floors", 2))
	var start_floor: int = int(level.get("start_floor", _floors))
	var night: bool = bool(level.get("night", false))
	var has_basement: bool = bool(level.get("basement", false))
	var has_elevator: bool = bool(level.get("elevator", false))
	var ice: bool = bool(level.get("ice", false))

	_add_world_env(night)
	_build_stairwell(_floors, has_basement, has_elevator)
	_build_apartment_door(start_floor)
	_build_yard(ice, night)
	if bool(level.get("detour", false)):
		_build_detour_path()
	_build_dumpster()
	if has_elevator:
		_build_elevator(_floors)
	if has_basement:
		_build_basement_props()
	_spawn_npcs(level)
	_spawn_player_and_bag(start_floor, level)
	Svc.audio().play_ambient()
	Svc.audio().play_music("game_music")

func _make_materials() -> void:
	var style: String = str(_level.get("style", "khrushchev"))
	var wall_up := Color(0.86, 0.82, 0.74)
	var wall_low := Color(0.22, 0.42, 0.30)
	var tile_c := Color(0.58, 0.54, 0.48)
	var panel_c := Color(0.70, 0.66, 0.58)
	match style:
		"brezhnev":
			wall_up = Color(0.78, 0.80, 0.82)
			wall_low = Color(0.28, 0.40, 0.52)
			panel_c = Color(0.60, 0.64, 0.68)
		"courtyard":
			wall_up = Color(0.80, 0.72, 0.64)
			wall_low = Color(0.38, 0.30, 0.24)
			panel_c = Color(0.66, 0.56, 0.48)
		_:
			pass
	_mats["wall"] = _tex_mat("res://assets/textures/wall.png", wall_up, Vector3(1.6, 1.6, 1.6))
	_mats["wainscot"] = _tex_mat("res://assets/textures/zelenka.png", wall_low, Vector3(1.4, 1.4, 1.4))
	_mats["tile"] = _tex_mat("res://assets/textures/tile.png", tile_c, Vector3(2.8, 2.8, 2.8))
	_mats["rail"] = _mat(Color(0.22, 0.18, 0.14), 0.45)
	_mats["door"] = _tex_mat("res://assets/textures/door.png", Color(0.40, 0.26, 0.16), Vector3(1, 1, 1))
	_mats["door_apt"] = _tex_mat("res://assets/textures/door.png", Color(0.52, 0.40, 0.28), Vector3(1, 1, 1))
	_mats["door_metal"] = _tex_mat("res://assets/textures/metal_door.png", Color(0.35, 0.36, 0.38), Vector3(1, 1, 1))
	_mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", Color(0.55, 0.52, 0.48), Vector3(2.0, 2.0, 2.0))
	_mats["panel"] = _tex_mat("res://assets/textures/panel.png", panel_c, Vector3(1.2, 1.2, 1.2))
	_mats["asphalt"] = _tex_mat("res://assets/textures/asphalt.png", Color(0.28, 0.28, 0.30), Vector3(4.0, 4.0, 4.0))
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.2)
	_mats["dumpster"] = _tex_mat("res://assets/textures/dumpster.png", Color(0.18, 0.40, 0.22), Vector3(1.5, 1.5, 1.5))
	_mats["mail"] = _mat(Color(0.38, 0.34, 0.28), 0.35)
	_mats["metal"] = _mat(Color(0.32, 0.33, 0.35), 0.62)
	_mats["glass"] = _mat(Color(0.45, 0.55, 0.62), 0.05)
	(_mats["glass"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_mats["glass"] as StandardMaterial3D).albedo_color.a = 0.42
	(_mats["glass"] as StandardMaterial3D).roughness = 0.35
	_mats["mark"] = _mat(Color(0.72, 0.48, 0.10))
	(_mats["mark"] as StandardMaterial3D).emission_enabled = true
	(_mats["mark"] as StandardMaterial3D).emission = Color(0.55, 0.32, 0.04)
	(_mats["mark"] as StandardMaterial3D).emission_energy_multiplier = 0.45
	_mats["prop"] = _mat(Color(0.32, 0.34, 0.36))
	_mats["number"] = _mat(Color(0.92, 0.90, 0.82))
	_mats["wood"] = _mat(Color(0.42, 0.28, 0.16))
	_mats["paper"] = _mat(Color(0.85, 0.82, 0.72))

func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92 - metallic * 0.45
	m.metallic = metallic
	return m

func _tex_mat(path: String, fallback: Color, uv_scale: Vector3 = Vector3(2, 2, 2)) -> StandardMaterial3D:
	var m := _mat(fallback)
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = uv_scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10) if night else Color(0.52, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.23, 0.26) if night else Color(0.42, 0.40, 0.36)
	env.ambient_light_energy = 0.35 if night else 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.13, 0.15) if night else Color(0.62, 0.63, 0.65)
	env.fog_density = 0.014 if night else 0.0035
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.08
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.88
	env.adjustment_contrast = 1.06
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.12 if night else 0.85
	sun.light_color = Color(0.55, 0.62, 0.85) if night else Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.rotation_degrees = Vector3(-38, 35, 0)
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

func _label3d(text: String, pos: Vector3, size: float = 0.12) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 48
	lab.pixel_size = size * 0.01
	lab.modulate = Color(0.15, 0.15, 0.12)
	lab.outline_modulate = Color(0.9, 0.9, 0.85)
	lab.outline_size = 4
	lab.position = pos
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(lab)

func _stair_x(left: bool) -> float:
	return -1.20 if left else 1.20

## Всегда один и тот же U-паттерн: верхний марш справа → mid → нижний слева.
## Иначе марши соседних этажей пересекаются в одном проёме.
func _upper_left(_floor_num: int) -> bool:
	return false

func _build_stairwell(floors: int, basement: bool, has_elevator: bool) -> void:
	var top := float(floors) * FLOOR_H
	# Коробка клетки
	_box(Vector3(-2.65, top * 0.5 + 0.6, 1.05), Vector3(0.18, top + 3.2, 5.2), "wall")
	_box(Vector3(2.65, top * 0.5 + 0.6, 1.05), Vector3(0.18, top + 3.2, 5.2), "wall")
	_box(Vector3(0, top * 0.5 + 0.6, -1.55), Vector3(5.5, top + 3.2, 0.18), "wall")
	_build_entrance_facade(floors, top)

	# Пол 1 этажа / земля
	if basement:
		_add_main_landing(0.0, 0)
		_box(Vector3(0, -FLOOR_H - 0.1, 1.05), Vector3(5.1, 0.2, 5.0), "concrete")
		_add_u_flights(0, 0.0, -FLOOR_H)
		var bl := OmniLight3D.new()
		bl.light_color = Color(0.85, 0.62, 0.32)
		bl.light_energy = 0.65
		bl.omni_range = 5.5
		bl.position = Vector3(0, -FLOOR_H + 1.7, 1.0)
		add_child(bl)
	else:
		_add_main_landing(0.0, 0)
		# Пол шахты + тамбур к двери (mid висит только до MID_Z1, тамбур с полным потолком)
		_box(Vector3(0, -0.1, 1.55), Vector3(5.1, 0.2, 2.0), "tile")
		_box(Vector3(0, -0.1, (LOBBY_Z0 + DOOR_Z) * 0.5 + 0.15), Vector3(5.1, 0.2, 1.4), "tile")
		_box(Vector3(0, 0.06, 3.35), Vector3(0.7, 0.04, 0.7), "mark", false)

	_add_entrance_props()
	_add_ground_mailboxes()

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		_add_main_landing(y, f)
		_add_mid_landing(y - HALF_H)
		_add_u_flights(f, y, y - FLOOR_H)
		_add_floor_props(y, f, has_elevator)
		_add_floor_wainscot(y)
		_add_floor_light(y)

	# Зелёнка у входа (1 этаж)
	_add_floor_wainscot(0.0)
	_box(Vector3(0, top + 2.5, 1.05), Vector3(5.6, 0.26, 5.3), "concrete")

func _build_entrance_facade(floors: int, top: float) -> void:
	# Внутренняя сторона фасада с проёмом двери ~1.55 м
	_box(Vector3(-2.05, 1.35, DOOR_Z - 0.12), Vector3(1.85, 2.7, 0.16), "panel")
	_box(Vector3(2.05, 1.35, DOOR_Z - 0.12), Vector3(1.85, 2.7, 0.16), "panel")
	_box(Vector3(0, 2.85, DOOR_Z - 0.12), Vector3(5.5, 0.35, 0.16), "panel")
	var uh := top - 2.85
	if uh > 0.15:
		_box(Vector3(0, 2.9 + uh * 0.5, DOOR_Z - 0.12), Vector3(5.5, uh, 0.16), "panel")
	# Окна на промежуточных площадках
	for f in range(1, floors + 1):
		var mid_y := float(f) * FLOOR_H - HALF_H
		_box(Vector3(0, mid_y + 1.15, DOOR_Z - 0.02), Vector3(1.05, 1.05, 0.05), "glass", false)
		_box(Vector3(0, mid_y + 1.15, DOOR_Z - 0.08), Vector3(1.15, 1.15, 0.04), "metal", false)
		_box(Vector3(0, mid_y + 0.55, DOOR_Z - 0.15), Vector3(1.2, 0.08, 0.22), "concrete", false)
		# грязные «шторы» намёк
		_box(Vector3(-0.35, mid_y + 1.2, DOOR_Z - 0.01), Vector3(0.25, 0.7, 0.02), "paper", false)

func _add_entrance_props() -> void:
	# Металлическая дверь ОТКРЫТА (створка у стены)
	_box(Vector3(-0.95, 1.1, DOOR_Z - 0.35), Vector3(0.07, 2.15, 0.85), "door_metal", false)
	_box(Vector3(-0.75, 1.45, DOOR_Z - 0.18), Vector3(0.18, 0.28, 0.06), "metal", false)
	# Рама
	_box(Vector3(-0.82, 1.1, DOOR_Z - 0.14), Vector3(0.08, 2.2, 0.1), "metal", false)
	_box(Vector3(0.82, 1.1, DOOR_Z - 0.14), Vector3(0.08, 2.2, 0.1), "metal", false)
	_box(Vector3(0, 2.25, DOOR_Z - 0.14), Vector3(1.72, 0.1, 0.1), "metal", false)
	# Коврик
	_box(Vector3(0, 0.02, 3.35), Vector3(1.1, 0.03, 0.55), "prop", false)
	# Доска объявлений
	_box(Vector3(2.25, 1.55, 3.55), Vector3(0.55, 0.7, 0.04), "wood", false)
	_box(Vector3(2.25, 1.6, 3.52), Vector3(0.45, 0.55, 0.02), "paper", false)
	# Щиток / автоматы
	_box(Vector3(-2.25, 1.6, 3.5), Vector3(0.45, 0.7, 0.12), "metal", false)
	# Свет над входом
	var el := OmniLight3D.new()
	el.light_color = Color(1.0, 0.88, 0.55)
	el.light_energy = 1.6
	el.omni_range = 4.5
	el.position = Vector3(0, 2.4, DOOR_Z + 0.15)
	add_child(el)
	lights.append(el)

func _add_ground_mailboxes() -> void:
	for i in range(6):
		var bx := -2.05 + float(i) * 0.42
		_box(Vector3(bx, 1.05, -1.38), Vector3(0.38, 0.95, 0.14), "mail", false)
		_box(Vector3(bx, 1.35, -1.30), Vector3(0.28, 0.08, 0.02), "number", false)

func _add_main_landing(y: float, floor_num: int) -> void:
	var depth := LAND_Z1 - LAND_Z0
	var zc := (LAND_Z0 + LAND_Z1) * 0.5
	_box(Vector3(0, y - 0.1, zc), Vector3(5.1, 0.2, depth), "tile")
	# Боковые полосы у лестничной шахты (не закрывают mid)
	_box(Vector3(-2.05, y - 0.1, 1.55), Vector3(1.0, 0.2, 1.9), "tile")
	_box(Vector3(2.05, y - 0.1, 1.55), Vector3(1.0, 0.2, 1.9), "tile")
	# Плинтус
	_box(Vector3(0, y + 0.01, LAND_Z0 + 0.08), Vector3(4.9, 0.03, 0.06), "wainscot", false)
	if floor_num > 0:
		var left := _upper_left(floor_num)
		var sx := _stair_x(left)
		_box(Vector3(sx, y + 0.03, LAND_Z1 - 0.05), Vector3(0.75, 0.04, 0.28), "mark", false)

func _add_mid_landing(y: float) -> void:
	var depth := MID_Z1 - MID_Z0
	var zc := (MID_Z0 + MID_Z1) * 0.5
	_box(Vector3(0, y - 0.1, zc), Vector3(4.6, 0.2, depth), "tile")
	# Перила в шахту (со стороны маршей)
	_box(Vector3(0, y + 0.55, MID_Z0 - 0.08), Vector3(0.9, 0.7, 0.05), "rail", false)
	_box(Vector3(0, y + 0.05, MID_Z0 - 0.08), Vector3(0.9, 0.12, 0.05), "rail")
	# Нельзя шагнуть с mid в пустоту тамбура
	_box(Vector3(0, y + 0.5, MID_Z1), Vector3(4.5, 0.95, 0.1), "rail")
	_box(Vector3(-1.8, y + 0.5, zc), Vector3(0.06, 0.9, depth * 0.9), "rail")
	_box(Vector3(1.8, y + 0.5, zc), Vector3(0.06, 0.9, depth * 0.9), "rail")

func _add_u_flights(from_floor: int, y_top: float, y_bot: float) -> void:
	var mid_y := y_top - HALF_H
	var upper_left := _upper_left(from_floor if from_floor > 0 else 1)
	# Верхний марш: площадка → mid (+Z)
	_add_flight_segment(_stair_x(upper_left), y_top, mid_y, FLIGHT_Z_A0, FLIGHT_Z_A1, upper_left)
	# Нижний марш: mid → нижняя площадка (−Z)
	_add_flight_segment(_stair_x(not upper_left), mid_y, y_bot, FLIGHT_Z_A1, FLIGHT_Z_A0, not upper_left)

func _add_flight_segment(x: float, y_top: float, y_bot: float, z0: float, z1: float, left: bool) -> void:
	var run := absf(z1 - z0)
	var rise := y_top - y_bot
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	# Знак угла: если идём в −Z, наклон обратный по Z
	if z1 < z0:
		angle = -angle

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(STAIR_W - 0.08, 0.18, length)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(x, (y_top + y_bot) * 0.5, (z0 + z1) * 0.5)
	body.rotation.x = angle
	add_child(body)

	var steps := 8
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y_top, y_bot, t)
		var z := lerpf(z0, z1, t)
		_box(Vector3(x, y, z), Vector3(STAIR_W - 0.12, 0.10, 0.24), "concrete", false)

	_box(Vector3(x, y_top - 0.02, z0 + (0.12 if z1 > z0 else -0.12)), Vector3(STAIR_W - 0.08, 0.1, 0.32), "concrete", true)
	_box(Vector3(x, y_bot + 0.02, z1 + (-0.12 if z1 > z0 else 0.12)), Vector3(STAIR_W - 0.08, 0.1, 0.32), "concrete", true)

	# Перила с внешней стороны марша
	var rail_x := x + (STAIR_W * 0.48 if not left else -STAIR_W * 0.48)
	var rail := StaticBody3D.new()
	rail.collision_layer = 1
	var rcs := CollisionShape3D.new()
	var rsh := BoxShape3D.new()
	rsh.size = Vector3(0.05, 0.8, length * 0.92)
	rcs.shape = rsh
	rail.add_child(rcs)
	var rmi := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = rsh.size
	rmi.mesh = rbm
	rmi.material_override = _mats["rail"]
	rail.add_child(rmi)
	rail.position = Vector3(rail_x, (y_top + y_bot) * 0.5 + 0.42, (z0 + z1) * 0.5)
	rail.rotation.x = angle
	add_child(rail)

	# Стойки перил (визуал)
	for i in range(4):
		var t := (float(i) + 0.5) / 4.0
		_box(Vector3(rail_x, lerpf(y_top, y_bot, t) + 0.4, lerpf(z0, z1, t)), Vector3(0.04, 0.75, 0.04), "rail", false)

func _add_floor_wainscot(y: float) -> void:
	# Полоса зелёнки ~1.35 м на этаже
	var h := 1.35
	var cy := y + h * 0.5
	_box(Vector3(-2.52, cy, 1.05), Vector3(0.05, h, 5.0), "wainscot", false)
	_box(Vector3(2.52, cy, 1.05), Vector3(0.05, h, 5.0), "wainscot", false)
	_box(Vector3(0, cy, -1.42), Vector3(5.2, h, 0.05), "wainscot", false)

func _add_floor_props(y: float, floor_num: int, has_elevator: bool) -> void:
	# Двери квартир
	_apt_door(Vector3(-2.35, y + 1.05, -1.25), floor_num * 2 - 1)
	_apt_door(Vector3(2.35, y + 1.05, -1.25), floor_num * 2)
	# Батарея
	_box(Vector3(-2.35, y + 0.55, 0.9), Vector3(0.12, 0.55, 0.7), "metal", false)
	for i in range(5):
		_box(Vector3(-2.35, y + 0.55, 0.6 + float(i) * 0.14), Vector3(0.14, 0.5, 0.06), "metal", false)
	# Проводка
	_box(Vector3(2.45, y + 2.35, 0.9), Vector3(0.05, 0.05, 3.8), "metal", false)
	_box(Vector3(2.45, y + 1.8, -0.6), Vector3(0.08, 0.9, 0.08), "metal", false)
	# Пожарный шкаф
	if floor_num % 2 == 0:
		_box(Vector3(2.35, y + 1.2, 0.2), Vector3(0.35, 0.9, 0.18), "metal", false)
		_box(Vector3(2.35, y + 1.25, 0.12), Vector3(0.28, 0.55, 0.02), "mark", false)
	# Лифтовые двери на площадке
	if has_elevator:
		_box(Vector3(0.0, y + 1.1, -1.42), Vector3(1.1, 2.1, 0.08), "metal", false)
		_box(Vector3(-0.28, y + 1.1, -1.38), Vector3(0.5, 2.0, 0.04), "door_metal", false)
		_box(Vector3(0.28, y + 1.1, -1.38), Vector3(0.5, 2.0, 0.04), "door_metal", false)
		_label3d("%d" % floor_num, Vector3(0.7, y + 1.85, -1.30), 0.1)

func _apt_door(pos: Vector3, num: int) -> void:
	_box(pos, Vector3(0.08, 2.05, 0.88), "door_apt", false)
	# глазок / ручка / номерок
	_box(pos + Vector3(0.06 if pos.x < 0 else -0.06, 0.55, 0.0), Vector3(0.04, 0.08, 0.08), "metal", false)
	_box(pos + Vector3(0.06 if pos.x < 0 else -0.06, 0.0, 0.28), Vector3(0.05, 0.12, 0.18), "metal", false)
	_box(pos + Vector3(0.07 if pos.x < 0 else -0.07, 0.65, -0.25), Vector3(0.03, 0.16, 0.28), "number", false)
	var lx := pos.x + (0.12 if pos.x < 0 else -0.12)
	_label3d(str(num), Vector3(lx, pos.y + 0.65, pos.z - 0.25), 0.09)

func _add_floor_light(y: float) -> void:
	_box(Vector3(0, y + 2.52, 0.15), Vector3(1.35, 0.07, 0.22), "metal", false)
	_box(Vector3(0, y + 2.48, 0.15), Vector3(1.2, 0.03, 0.12), "number", false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.96, 0.90, 0.68)
	lamp.light_energy = 1.15
	lamp.omni_range = 6.5
	lamp.omni_attenuation = 1.55
	lamp.position = Vector3(0, y + 2.4, 0.15)
	add_child(lamp)
	lights.append(lamp)
	# Свет на mid
	var ml := OmniLight3D.new()
	ml.light_color = Color(0.95, 0.92, 0.75)
	ml.light_energy = 0.7
	ml.omni_range = 4.0
	ml.position = Vector3(0, y - HALF_H + 2.2, 3.0)
	add_child(ml)
	lights.append(ml)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	spawn_pos = Vector3(0.15, y + 0.35, -0.4)
	_box(Vector3(-2.25, y + 1.05, -1.18), Vector3(0.1, 2.05, 0.92), "door", false)
	_label3d("%d" % (start_floor * 2 - 1), Vector3(-2.10, y + 1.7, -1.0), 0.1)

func _build_yard(ice: bool, night: bool) -> void:
	var ground := "ice" if ice else "asphalt"
	_box(Vector3(0, -0.1, 12.0), Vector3(24.0, 0.3, 18.0), ground)
	# Наружный фасад с дырой под дверь
	_box(Vector3(-4.4, 8.5, DOOR_Z + 0.28), Vector3(6.9, 17.0, 0.3), "panel")
	_box(Vector3(4.4, 8.5, DOOR_Z + 0.28), Vector3(6.9, 17.0, 0.3), "panel")
	_box(Vector3(0, 10.0, DOOR_Z + 0.28), Vector3(1.9, 14.0, 0.3), "panel")
	# Швы панелей
	for row in range(6):
		var sy := 1.4 + float(row) * FLOOR_H
		_box(Vector3(0, sy, DOOR_Z + 0.45), Vector3(14.0, 0.04, 0.04), "concrete", false)
	for col in range(5):
		var sx := -7.0 + float(col) * 3.5
		if absf(sx) < 1.0:
			continue
		_box(Vector3(sx, 8.0, DOOR_Z + 0.45), Vector3(0.04, 16.0, 0.04), "concrete", false)
	# Окна фасада
	for row in range(6):
		for col in range(4):
			var wx := -5.5 + float(col) * 3.6
			if absf(wx) < 1.3:
				continue
			var wy := 1.6 + float(row) * FLOOR_H
			_box(Vector3(wx, wy, DOOR_Z + 0.48), Vector3(1.2, 1.35, 0.06), "glass", false)
			_box(Vector3(wx, wy, DOOR_Z + 0.40), Vector3(1.35, 1.5, 0.05), "metal", false)
	# Козырёк
	_box(Vector3(0, 2.55, 4.9), Vector3(3.6, 0.12, 2.4), "concrete")
	_box(Vector3(-1.4, 1.2, 4.85), Vector3(0.12, 2.5, 0.12), "metal")
	_box(Vector3(1.4, 1.2, 4.85), Vector3(0.12, 2.5, 0.12), "metal")
	_box(Vector3(0, -0.05, 4.7), Vector3(2.8, 0.2, 2.6), "concrete")
	# Дорожка (потёртая краска, не неон)
	_box(Vector3(0, 0.05, 6.8), Vector3(0.85, 0.04, 3.2), "mark", false)
	_box(Vector3(1.4, 0.05, 10.8), Vector3(0.85, 0.04, 4.2), "mark", false)
	_box(Vector3(3.4, 0.05, 14.0), Vector3(2.4, 0.04, 2.8), "mark", false)
	# Ограда / газон намёк
	_box(Vector3(-10.0, 0.55, 12.0), Vector3(0.8, 1.1, 16.0), "panel")
	_box(Vector3(10.0, 0.55, 12.0), Vector3(0.8, 1.1, 16.0), "panel")
	_box(Vector3(0, 0.7, 19.5), Vector3(20.0, 1.4, 0.8), "panel")
	# Скамейка
	_box(Vector3(-4.8, 0.32, 8.2), Vector3(1.8, 0.1, 0.42), "wood")
	_box(Vector3(-5.4, 0.4, 8.2), Vector3(0.1, 0.4, 0.38), "wood")
	_box(Vector3(-4.2, 0.4, 8.2), Vector3(0.1, 0.4, 0.38), "wood")
	# Урна
	_box(Vector3(-3.2, 0.45, 7.5), Vector3(0.35, 0.7, 0.35), "metal", false)
	# Двор-колодец намёк: сушилка / турник
	_box(Vector3(6.8, 1.2, 11.5), Vector3(0.12, 2.3, 0.12), "metal")
	_box(Vector3(7.6, 1.2, 11.5), Vector3(0.12, 2.3, 0.12), "metal")
	_box(Vector3(7.2, 2.35, 11.5), Vector3(1.0, 0.08, 0.08), "metal", false)
	# Контейнерная площадка
	_box(Vector3(3.5, 0.7, 16.2), Vector3(4.5, 1.3, 0.12), "metal")
	_box(Vector3(1.4, 0.7, 14.5), Vector3(0.12, 1.3, 3.5), "metal")
	_box(Vector3(5.6, 0.7, 14.5), Vector3(0.12, 1.3, 3.5), "metal")
	if ice:
		_box(Vector3(0, 0.02, 9.0), Vector3(3.0, 0.05, 1.0), "ice")
		yard_ice_zones.append(Rect2(Vector2(-7, 7), Vector2(14, 10)))
	if night:
		var yl := OmniLight3D.new()
		yl.light_color = Color(1.0, 0.82, 0.5)
		yl.light_energy = 2.2
		yl.omni_range = 13.0
		yl.position = Vector3(0, 4.0, 7.2)
		add_child(yl)

func _build_detour_path() -> void:
	_box(Vector3(-7.0, -0.05, 11.0), Vector3(2.2, 0.12, 10.0), "asphalt")
	_box(Vector3(-7.0, 0.04, 15.0), Vector3(0.5, 0.06, 0.5), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(1.2, -FLOOR_H + 0.35, 1.2), Vector3(0.25, 0.25, 2.2), "metal")
	_box(Vector3(-1.0, -FLOOR_H + 0.12, 2.0), Vector3(1.0, 0.06, 1.0), "ice")

func _build_dumpster() -> void:
	_box(Vector3(3.5, 0.75, 14.6), Vector3(2.3, 1.45, 1.45), "dumpster")
	_box(Vector3(3.5, 1.55, 14.6), Vector3(2.4, 0.1, 1.5), "metal", false)
	_box(Vector3(5.2, 0.7, 14.6), Vector3(1.1, 1.3, 1.1), "dumpster")
	dumpster = Area3D.new()
	dumpster.name = "Dumpster"
	dumpster.collision_layer = 0
	dumpster.collision_mask = 2 | 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.6, 2.4, 3.2)
	cs.shape = sh
	dumpster.add_child(cs)
	dumpster.position = Vector3(3.5, 1.0, 14.6)
	add_child(dumpster)
	_box(Vector3(3.5, 2.3, 14.6), Vector3(0.5, 0.3, 0.5), "mark", false)

func _build_elevator(floors: int) -> void:
	var start_f: int = int(_level.get("start_floor", floors))
	var y := float(start_f) * FLOOR_H
	_box(Vector3(0.0, floors * FLOOR_H * 0.5, -1.85), Vector3(1.2, floors * FLOOR_H + 0.5, 0.7), "metal")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.15, 2.2, 1.0)
	cs.shape = sh
	elevator_area.add_child(cs)
	elevator_area.position = Vector3(0.0, y + 1.0, -1.35)
	add_child(elevator_area)

func _spawn_npcs(level: Dictionary) -> void:
	for i in range(int(level.get("babushkas", 0))):
		var npc = StairNpcScr.new()
		add_child(npc)
		npc.setup(0, Vector3(-3.0 + i * 0.7, 0.2, 8.5 + i), Vector3(1.5, 0.2, 12.0 + i), null)
		npcs.append(npc)
	for i in range(int(level.get("dogs", 0))):
		var dog = StairNpcScr.new()
		add_child(dog)
		dog.setup(1, Vector3(2.0 + i, 0.2, 13.0), Vector3(5.5, 0.2, 15.5), null)
		npcs.append(dog)

func _spawn_player_and_bag(start_floor: int, level: Dictionary) -> void:
	var p = TrashPlayerScr.new()
	add_child(p)
	p.global_position = spawn_pos
	var left := _upper_left(start_floor)
	p.set_look_yaw(PI + (0.4 if left else -0.4))
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = spawn_pos + Vector3(0.35, 0.65, 0.15)
	bag = trash

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", 0.3, period * 0.5)
			tw.tween_property(lamp, "light_energy", 1.1, period * 0.5)

func is_on_ice(pos: Vector3) -> bool:
	for r in yard_ice_zones:
		if (r as Rect2).has_point(Vector2(pos.x, pos.z)):
			return true
	return false

func guide_hint(player_pos: Vector3) -> String:
	var lang: String = Svc.loc().lang
	if dumpster and player_pos.distance_to(dumpster.global_position) < 4.5:
		return "E — выбросить мусор" if lang == "ru" else "E — dump the trash"
	if player_pos.y < 1.3 and player_pos.z > 5.5:
		return "По жёлтой дорожке к помойке" if lang == "ru" else "Follow yellow path to dumpster"
	if player_pos.y < 1.3 and player_pos.z > 2.4:
		return "Выходи в открытую дверь во двор" if lang == "ru" else "Go through the open door to the yard"
	# Промежуточная площадка у окна
	var near_mid := player_pos.z > 2.1 and player_pos.z < 3.1 and fmod(player_pos.y + 0.35, FLOOR_H) > HALF_H - 0.55 and fmod(player_pos.y + 0.35, FLOOR_H) < HALF_H + 0.55
	if near_mid:
		return "Разворот: левый марш вниз" if lang == "ru" else "Turn: left flight down"
	if lang == "ru":
		return "Вниз: правый марш (жёлтая метка) → площадка у окна"
	return "Down: right flight (yellow mark) → window landing"
