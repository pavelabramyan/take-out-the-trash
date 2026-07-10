class_name BuildingBuilder
extends Node3D
## Процедурный подъезд панельки + двор + помойка.

const LevelData = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")
const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 3.0
const STAIR_W := 1.6
const LANDING := 2.4

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
	_build_stairwell(floors, has_basement, has_elevator)
	_build_apartment_door(start_floor)
	_build_yard(ice)
	_build_dumpster()
	if has_elevator:
		_build_elevator(floors)
	_spawn_npcs(level)
	_spawn_player_and_bag(start_floor, level)

func _make_materials() -> void:
	_mats["wall"] = _mat(Color(0.72, 0.7, 0.65))
	_mats["floor"] = _mat(Color(0.55, 0.52, 0.48))
	_mats["tile"] = _mat(Color(0.62, 0.68, 0.7))
	_mats["rail"] = _mat(Color(0.35, 0.2, 0.15))
	_mats["door"] = _mat(Color(0.4, 0.25, 0.18))
	_mats["concrete"] = _mat(Color(0.5, 0.5, 0.48))
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.15)
	_mats["dumpster"] = _mat(Color(0.2, 0.45, 0.25))
	_mats["mail"] = _mat(Color(0.55, 0.35, 0.2))

func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9 - metallic * 0.5
	m.metallic = metallic
	return m

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1) if night else Color(0.55, 0.65, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.18, 0.25) if night else Color(0.45, 0.48, 0.5)
	env.ambient_light_energy = 0.35 if night else 0.7
	env.fog_enabled = night
	if night:
		env.fog_light_color = Color(0.08, 0.1, 0.15)
		env.fog_density = 0.02
	we.environment = env
	add_child(we)

	if not night:
		var sun := DirectionalLight3D.new()
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		sun.rotation_degrees = Vector3(-45, 30, 0)
		add_child(sun)
	else:
		var moon := DirectionalLight3D.new()
		moon.light_energy = 0.15
		moon.light_color = Color(0.6, 0.7, 1.0)
		moon.rotation_degrees = Vector3(-30, -20, 0)
		add_child(moon)

func _box(pos: Vector3, size: Vector3, mat_key: String, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat_key]
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	(parent if parent else self).add_child(body)
	return body

func _build_stairwell(floors: int, basement: bool, elevator: bool) -> void:
	# Шахта подъезда: X от -2.5 до 2.5, Z от -1.2 до 3.5
	var bottom := -FLOOR_H if basement else 0.0
	var top := floors * FLOOR_H
	# Пол 1 этажа / вход
	_box(Vector3(0, -0.1, 1.2), Vector3(5.2, 0.2, 5.0), "tile")
	# Стены шахты
	_box(Vector3(-2.6, top * 0.5, 1.2), Vector3(0.2, top + 2.0, 5.2), "wall")
	_box(Vector3(2.6, top * 0.5, 1.2), Vector3(0.2, top + 2.0, 5.2), "wall")
	_box(Vector3(0, top * 0.5, -1.3), Vector3(5.4, top + 2.0, 0.2), "wall")
	# Задняя стена с проёмом на двор (1 этаж)
	_box(Vector3(-1.6, 1.5, 3.7), Vector3(2.0, 3.0, 0.2), "wall")
	_box(Vector3(1.6, 1.5, 3.7), Vector3(2.0, 3.0, 0.2), "wall")
	_box(Vector3(0, 2.7, 3.7), Vector3(5.4, 0.6, 0.2), "wall")

	if basement:
		_box(Vector3(0, -FLOOR_H - 0.1, 1.2), Vector3(5.2, 0.2, 5.0), "concrete")
		_box(Vector3(0, -FLOOR_H * 0.5, 1.2), Vector3(4.8, FLOOR_H - 0.2, 4.6), "concrete")
		# Тёмный свет подвала
		var bl := OmniLight3D.new()
		bl.light_color = Color(0.9, 0.7, 0.4)
		bl.light_energy = 1.2
		bl.omni_range = 8.0
		bl.position = Vector3(0, -FLOOR_H + 2.2, 1.0)
		add_child(bl)
		lights.append(bl)

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		# Площадка этажа
		_box(Vector3(0, y - 0.1, 0.2), Vector3(5.0, 0.2, 2.8), "tile")
		# Лестничный марш (упрощённо — наклонная плита + ступени-боксы)
		_add_stairs(f)
		# Почтовые ящики на 1 этаже
		if f == 1:
			_box(Vector3(-2.2, 1.2, -0.9), Vector3(0.4, 1.4, 0.15), "mail")
		# Свет этажа
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.92, 0.75)
		lamp.light_energy = 1.4
		lamp.omni_range = 7.0
		lamp.position = Vector3(0, y + 2.4, 0.5)
		lamp.set_meta("floor", f)
		add_child(lamp)
		lights.append(lamp)
		# Перила
		_box(Vector3(1.9, y + 0.5, 1.5), Vector3(0.08, 0.9, 2.0), "rail")

	# Крыша
	_box(Vector3(0, top + 0.1, 1.0), Vector3(5.4, 0.2, 5.0), "concrete")

	# Входная дверь наружу (проём уже есть)
	_box(Vector3(0, 1.1, 3.55), Vector3(1.1, 2.2, 0.08), "door")

func _add_stairs(floor_num: int) -> void:
	var y0 := float(floor_num - 1) * FLOOR_H
	var steps := 10
	for i in range(steps):
		var t := float(i) / float(steps)
		var y := y0 + t * FLOOR_H + 0.12
		var z := 2.2 - t * 2.0
		var x := -0.9 if floor_num % 2 == 1 else 0.9
		_box(Vector3(x, y, z), Vector3(1.5, 0.18, 0.35), "concrete")

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	_box(Vector3(-2.35, y + 1.1, -0.5), Vector3(0.1, 2.1, 0.9), "door")
	spawn_pos = Vector3(0.0, y + 0.2, 0.3)

func _build_yard(ice: bool) -> void:
	# Двор за подъездом
	var mat_key := "ice" if ice else "concrete"
	_box(Vector3(0, -0.15, 10.0), Vector3(18.0, 0.3, 14.0), mat_key)
	# Бордюры / гаражи
	_box(Vector3(-8.0, 0.6, 10.0), Vector3(1.0, 1.2, 12.0), "wall")
	_box(Vector3(8.0, 0.6, 10.0), Vector3(1.0, 1.2, 12.0), "wall")
	_box(Vector3(0, 0.8, 16.5), Vector3(16.0, 1.6, 1.0), "wall")
	# Панелька-фасад сзади подъезда (декор)
	_box(Vector3(0, 6.0, -2.5), Vector3(14.0, 14.0, 1.0), "wall")
	if ice:
		yard_ice_zones.append(Rect2(Vector2(-7, 4), Vector2(14, 12)))

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
	# Маркер
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	marker.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.3)
	mat.emission_energy_multiplier = 2.0
	marker.material_override = mat
	marker.position = Vector3(3.5, 2.2, 13.5)
	add_child(marker)

func _build_elevator(floors: int) -> void:
	# Кабина у стены
	_box(Vector3(2.1, floors * FLOOR_H * 0.5, -0.6), Vector3(1.2, floors * FLOOR_H, 1.2), "wall")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 2.4, 1.4)
	cs.shape = sh
	elevator_area.add_child(cs)
	# Кнопка на стартовом этаже — позиция обновится из game
	elevator_area.position = Vector3(2.1, float(_level.get("start_floor", 1)) * FLOOR_H + 1.0, -0.6)
	add_child(elevator_area)
	# Дверь лифта
	_box(Vector3(2.1, float(_level.get("start_floor", 1)) * FLOOR_H + 1.1, 0.05), Vector3(1.0, 2.1, 0.08), "door")

func _spawn_npcs(level: Dictionary) -> void:
	var dogs: int = int(level.get("dogs", 0))
	var babushkas: int = int(level.get("babushkas", 0))
	for i in range(babushkas):
		var npc = StairNpcScr.new()
		add_child(npc)
		var a := Vector3(-2.0 + i * 0.5, 0.2, 5.0 + i * 1.5)
		var b := Vector3(2.0 - i * 0.3, 0.2, 8.0 + i * 1.2)
		npc.setup(0, a, b, null)  # BABUSHKA
		npcs.append(npc)
	for i in range(dogs):
		var dog = StairNpcScr.new()
		add_child(dog)
		var a2 := Vector3(1.0 + i, 0.2, 12.0)
		var b2 := Vector3(5.0 + i, 0.2, 14.5)
		dog.setup(1, a2, b2, null)  # DOG
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
	trash.global_position = spawn_pos + Vector3(0.4, 0.8, -0.3)
	bag = trash

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", 0.2, period * 0.5)
			tw.tween_property(lamp, "light_energy", 1.4, period * 0.5)

func is_on_ice(pos: Vector3) -> bool:
	for r in yard_ice_zones:
		var rect: Rect2 = r
		if rect.has_point(Vector2(pos.x, pos.z)):
			return true
	return false
