class_name BuildingBuilder
extends Node3D
## Подъезд для игры: всегда вперёд и вниз по зелёной дорожке. Без дыр, без змейки внахлёст.

const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 2.6
const RAMP_RUN := 5.0
const LAND_LEN := 3.2
const STAIR_W := 3.6
const SEG := RAMP_RUN + LAND_LEN  # длина одного этажа по Z

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
	_build_stairwell(_floors, has_basement)
	_build_apartment_door(start_floor)
	_build_yard(ice)
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

func _floor_z0(floor_1based: int) -> float:
	## Этаж 0 у z=0, каждый выше — дальше в −Z (старт сзади, спуск в +Z к выходу).
	return -float(floor_1based) * SEG

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
	_mats["rail"] = _mat(Color(0.5, 0.32, 0.2))
	_mats["door"] = _tex_mat("res://assets/textures/door.png", Color(0.42, 0.28, 0.2))
	_mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", Color(0.48, 0.48, 0.46))
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.25)
	_mats["dumpster"] = _tex_mat("res://assets/textures/dumpster.png", Color(0.2, 0.45, 0.25))
	_mats["mail"] = _mat(Color(0.55, 0.35, 0.2))
	_mats["mark"] = _mat(Color(0.12, 0.95, 0.35))
	(_mats["mark"] as StandardMaterial3D).emission_enabled = true
	(_mats["mark"] as StandardMaterial3D).emission = Color(0.12, 0.95, 0.35)
	(_mats["mark"] as StandardMaterial3D).emission_energy_multiplier = 3.2
	_mats["path"] = _mat(Color(0.15, 0.9, 0.4))
	(_mats["path"] as StandardMaterial3D).emission_enabled = true
	(_mats["path"] as StandardMaterial3D).emission = Color(0.1, 0.85, 0.3)
	(_mats["path"] as StandardMaterial3D).emission_energy_multiplier = 2.2
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
	env.ambient_light_color = Color(0.22, 0.24, 0.3) if night else Color(0.52, 0.54, 0.56)
	env.ambient_light_energy = 0.5 if night else 0.95
	env.fog_enabled = night
	if night:
		env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 0.22
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.25 if night else 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48, 30, 0)
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
	var z_min := _floor_z0(floors) - 1.0
	var z_max := LAND_LEN + 2.0
	var depth := z_max - z_min
	var mid_z := (z_min + z_max) * 0.5
	var top := float(floors) * FLOOR_H

	# Боковые стены на всю длину
	_box(Vector3(-4.3, top * 0.5 + 1.0, mid_z), Vector3(0.3, top + 4.0, depth + 2.0), "wall")
	_box(Vector3(4.3, top * 0.5 + 1.0, mid_z), Vector3(0.3, top + 4.0, depth + 2.0), "wall")
	# Задняя стена
	_box(Vector3(0, top * 0.5 + 1.0, z_min - 0.2), Vector3(8.8, top + 4.0, 0.3), "wall")
	# Крыша высоко
	_box(Vector3(0, top + 2.8, mid_z), Vector3(8.8, 0.3, depth + 1.0), "concrete")

	# Этаж 0 — выход
	_add_landing(0, 0.0)
	_box(Vector3(0, 1.25, LAND_LEN + 0.05), Vector3(1.6, 2.4, 0.1), "door", false)
	_box(Vector3(-2.2, 1.4, LAND_LEN + 0.15), Vector3(2.4, 2.8, 0.25), "wall")
	_box(Vector3(2.2, 1.4, LAND_LEN + 0.15), Vector3(2.4, 2.8, 0.25), "wall")
	_box(Vector3(0, 2.95, LAND_LEN + 0.15), Vector3(8.8, 0.4, 0.25), "wall")

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		_add_landing(f, y)
		_add_ramp_down(f, y, y - FLOOR_H)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.light_energy = 1.9
		lamp.omni_range = 11.0
		lamp.position = Vector3(0, y + 2.2, _floor_z0(f) + LAND_LEN * 0.5)
		add_child(lamp)
		lights.append(lamp)

	if basement:
		_box(Vector3(0, -FLOOR_H - 0.1, mid_z), Vector3(8.0, 0.2, depth), "concrete")
		_add_ramp_custom(0.0, -FLOOR_H, 0.0, RAMP_RUN)

func _add_landing(floor_i: int, y: float) -> void:
	var z0 := _floor_z0(floor_i)
	_box(Vector3(0, y - 0.1, z0 + LAND_LEN * 0.5), Vector3(8.0, 0.22, LAND_LEN), "tile")
	# Зелёная дорожка на всю площадку → к пандусу
	_box(Vector3(0, y + 0.04, z0 + LAND_LEN * 0.5), Vector3(1.4, 0.06, LAND_LEN - 0.4), "path", false)
	_box(Vector3(0, y + 0.06, z0 + LAND_LEN - 0.25), Vector3(1.8, 0.08, 0.55), "mark", false)
	# Низкие бортики по бокам
	_box(Vector3(-3.9, y + 0.35, z0 + LAND_LEN * 0.5), Vector3(0.12, 0.6, LAND_LEN), "rail")
	_box(Vector3(3.9, y + 0.35, z0 + LAND_LEN * 0.5), Vector3(0.12, 0.6, LAND_LEN), "rail")

func _add_ramp_down(from_floor: int, y_top: float, y_bot: float) -> void:
	## Пандус от края площадки этажа в +Z вниз на следующий.
	var z0 := _floor_z0(from_floor) + LAND_LEN
	var z1 := z0 + RAMP_RUN
	_add_ramp_custom(y_top, y_bot, z0, z1)

func _add_ramp_custom(y_top: float, y_bot: float, z0: float, z1: float) -> void:
	var run := z1 - z0
	var rise := y_top - y_bot
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(STAIR_W, 0.24, length)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(0.0, (y_top + y_bot) * 0.5, (z0 + z1) * 0.5)
	body.rotation.x = angle
	add_child(body)

	var steps := 14
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y_top, y_bot, t)
		var z := lerpf(z0, z1, t)
		_box(Vector3(0, y + 0.02, z), Vector3(STAIR_W - 0.2, 0.07, 0.3), "concrete", false)
		if i % 2 == 0:
			_box(Vector3(0, y + 0.07, z), Vector3(0.85, 0.04, 0.4), "path", false)

	_box(Vector3(0, y_top - 0.02, z0 + 0.2), Vector3(STAIR_W, 0.14, 0.5), "concrete", true)
	_box(Vector3(0, y_bot + 0.02, z1 - 0.2), Vector3(STAIR_W, 0.14, 0.5), "concrete", true)

	# Бортики пандуса
	for side_i in [-1, 1]:
		var sx: float = float(side_i) * (STAIR_W * 0.5 + 0.1)
		var rail := StaticBody3D.new()
		rail.collision_layer = 1
		var rcs := CollisionShape3D.new()
		var rsh := BoxShape3D.new()
		rsh.size = Vector3(0.14, 0.5, length)
		rcs.shape = rsh
		rail.add_child(rcs)
		var rmi := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		rbm.size = rsh.size
		rmi.mesh = rbm
		rmi.material_override = _mats["rail"]
		rail.add_child(rmi)
		rail.position = Vector3(sx, (y_top + y_bot) * 0.5 + 0.2, (z0 + z1) * 0.5)
		rail.rotation.x = angle
		add_child(rail)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	var z0 := _floor_z0(start_floor)
	_box(Vector3(-3.7, y + 1.1, z0 + 1.0), Vector3(0.08, 2.1, 0.9), "door", false)
	spawn_pos = Vector3(0.0, y + 0.4, z0 + 1.0)

func _build_yard(ice: bool) -> void:
	var mat_key := "ice" if ice else "concrete"
	_box(Vector3(0, -0.15, 12.0), Vector3(20.0, 0.3, 18.0), mat_key)
	_box(Vector3(-9.0, 0.6, 12.0), Vector3(1.0, 1.2, 16.0), "wall")
	_box(Vector3(9.0, 0.6, 12.0), Vector3(1.0, 1.2, 16.0), "wall")
	_box(Vector3(0, 0.8, 20.5), Vector3(18.0, 1.6, 1.0), "wall")
	_box(Vector3(0, -0.05, 6.5), Vector3(3.2, 0.15, 6.0), "concrete")
	_box(Vector3(0, 0.04, 6.5), Vector3(1.2, 0.06, 5.5), "path", false)
	_box(Vector3(-5.5, 0.55, 10.0), Vector3(2.2, 1.0, 1.1), "prop")
	_box(Vector3(6.0, 1.2, 13.0), Vector3(0.35, 2.4, 0.35), "prop")
	if ice:
		_box(Vector3(0, 0.02, 11.0), Vector3(4.0, 0.06, 1.2), "ice")
		yard_ice_zones.append(Rect2(Vector2(-8, 6), Vector2(16, 12)))

func _build_detour_path() -> void:
	_box(Vector3(-7.0, -0.05, 12.0), Vector3(2.5, 0.15, 12.0), "concrete")
	_box(Vector3(-7.0, 0.05, 16.0), Vector3(0.6, 0.08, 0.6), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(1.5, -FLOOR_H + 0.4, 2.0), Vector3(0.3, 0.3, 2.5), "prop")

func _build_dumpster() -> void:
	_box(Vector3(3.5, 0.7, 15.0), Vector3(2.2, 1.4, 1.4), "dumpster")
	dumpster = Area3D.new()
	dumpster.name = "Dumpster"
	dumpster.collision_layer = 0
	dumpster.collision_mask = 2 | 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.8, 2.0, 2.0)
	cs.shape = sh
	dumpster.add_child(cs)
	dumpster.position = Vector3(3.5, 1.0, 15.0)
	add_child(dumpster)
	_box(Vector3(3.5, 2.2, 15.0), Vector3(0.5, 0.5, 0.5), "mark", false)
	_box(Vector3(1.5, 0.04, 12.0), Vector3(1.0, 0.06, 5.0), "path", false)

func _build_elevator(floors: int) -> void:
	var start_f: int = int(_level.get("start_floor", floors))
	var y := float(start_f) * FLOOR_H
	var z := _floor_z0(start_f) + 0.8
	_box(Vector3(3.3, floors * FLOOR_H * 0.5, z), Vector3(1.0, floors * FLOOR_H, 1.0), "wall")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 2.4, 1.2)
	cs.shape = sh
	elevator_area.add_child(cs)
	elevator_area.position = Vector3(3.3, y + 1.0, z)
	add_child(elevator_area)

func _spawn_npcs(level: Dictionary) -> void:
	for i in range(int(level.get("babushkas", 0))):
		var npc = StairNpcScr.new()
		add_child(npc)
		npc.setup(0, Vector3(-3.0 + i, 0.2, 10.0 + i), Vector3(2.0, 0.2, 14.0 + i), null)
		npcs.append(npc)
	for i in range(int(level.get("dogs", 0))):
		var dog = StairNpcScr.new()
		add_child(dog)
		dog.setup(1, Vector3(2.0 + i, 0.2, 14.0), Vector3(5.0, 0.2, 16.5), null)
		npcs.append(dog)

func _spawn_player_and_bag(start_floor: int, level: Dictionary) -> void:
	var p = TrashPlayerScr.new()
	add_child(p)
	p.global_position = spawn_pos
	# Лицом к выходу / спуску (+Z)
	p.set_look_yaw(PI)
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = spawn_pos + Vector3(0.4, 0.7, 0.25)
	bag = trash

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", 0.3, period * 0.5)
			tw.tween_property(lamp, "light_energy", 1.9, period * 0.5)

func is_on_ice(pos: Vector3) -> bool:
	for r in yard_ice_zones:
		if (r as Rect2).has_point(Vector2(pos.x, pos.z)):
			return true
	return false

func guide_hint(player_pos: Vector3) -> String:
	var lang: String = Svc.loc().lang
	if player_pos.z > 10.0 and player_pos.y < 1.5:
		return "Зелёный куб — нажми E" if lang == "ru" else "Green cube — press E"
	if player_pos.y < 1.3 and player_pos.z > LAND_LEN - 0.5:
		return "Выходи во двор по зелёной дорожке" if lang == "ru" else "Exit to the yard on the green path"
	return "Иди вперёд по зелёной дорожке вниз" if lang == "ru" else "Walk forward on the green path down"
