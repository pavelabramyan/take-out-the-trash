class_name BuildingBuilder
extends Node3D
## Подъезд русской панельки: вертикальная клетка, двери квартир, ящики, зелёнка.
## Ходьба: пологие пандусы под ступенями, марши слева/справа (не пересекаются).

const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 2.8
const STAIR_W := 1.85
const HOLE_Z0 := 0.45
const HOLE_Z1 := 3.05
const RAMP_RUN := HOLE_Z1 - HOLE_Z0  # ~2.6 → угол ~47°

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
	# Палитра подъезда панельки
	var wall_up := Color(0.82, 0.78, 0.70)      # выцветшая штукатурка
	var wall_low := Color(0.22, 0.42, 0.32)     # «зелёнка»
	var tile_c := Color(0.55, 0.52, 0.48)        # грязная плитка
	var panel_c := Color(0.72, 0.68, 0.62)       # наружная панель
	match style:
		"brezhnev":
			wall_up = Color(0.75, 0.78, 0.80)
			wall_low = Color(0.25, 0.35, 0.48)  # голубая полоса
			panel_c = Color(0.62, 0.66, 0.70)
		"courtyard":
			wall_up = Color(0.78, 0.70, 0.62)
			wall_low = Color(0.35, 0.28, 0.22)
			panel_c = Color(0.68, 0.58, 0.50)
		_:
			pass
	_mats["wall"] = _tex_mat("res://assets/textures/wall.png", wall_up)
	_mats["wainscot"] = _mat(wall_low)  # нижняя краска
	_mats["tile"] = _tex_mat("res://assets/textures/tile.png", tile_c)
	_mats["rail"] = _mat(Color(0.28, 0.22, 0.16), 0.35)
	_mats["door"] = _tex_mat("res://assets/textures/door.png", Color(0.35, 0.22, 0.14))
	_mats["door_apt"] = _mat(Color(0.55, 0.45, 0.32))
	_mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", Color(0.52, 0.50, 0.47))
	_mats["panel"] = _tex_mat("res://assets/textures/concrete.png", panel_c)
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.2)
	_mats["dumpster"] = _tex_mat("res://assets/textures/dumpster.png", Color(0.18, 0.40, 0.22))
	_mats["mail"] = _mat(Color(0.42, 0.38, 0.32), 0.4)
	_mats["metal"] = _mat(Color(0.35, 0.36, 0.38), 0.55)
	_mats["glass"] = _mat(Color(0.55, 0.7, 0.85), 0.1)
	(_mats["glass"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_mats["glass"] as StandardMaterial3D).albedo_color.a = 0.35
	_mats["mark"] = _mat(Color(0.85, 0.55, 0.12))  # потёртая жёлтая краска, не неон
	(_mats["mark"] as StandardMaterial3D).emission_enabled = true
	(_mats["mark"] as StandardMaterial3D).emission = Color(0.7, 0.4, 0.05)
	(_mats["mark"] as StandardMaterial3D).emission_energy_multiplier = 0.8
	_mats["prop"] = _mat(Color(0.35, 0.38, 0.4))
	_mats["number"] = _mat(Color(0.9, 0.9, 0.85))

func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92 - metallic * 0.4
	m.metallic = metallic
	return m

func _tex_mat(path: String, fallback: Color) -> StandardMaterial3D:
	var m := _mat(fallback)
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(2.2, 2.2, 2.2)
	return m

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12) if night else Color(0.58, 0.62, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.26, 0.28) if night else Color(0.48, 0.47, 0.44)
	env.ambient_light_energy = 0.4 if night else 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.16, 0.18) if night else Color(0.65, 0.66, 0.68)
	env.fog_density = 0.012 if night else 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.15 if night else 0.95
	sun.light_color = Color(0.55, 0.62, 0.85) if night else Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, 40, 0)
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

func _stair_x(left: bool) -> float:
	return -1.15 if left else 1.15

func _build_stairwell(floors: int, basement: bool) -> void:
	var top := float(floors) * FLOOR_H

	# === Коробка клетки ===
	_box(Vector3(-2.6, top * 0.5 + 0.8, 1.1), Vector3(0.22, top + 3.5, 5.0), "wall")
	_box(Vector3(2.6, top * 0.5 + 0.8, 1.1), Vector3(0.22, top + 3.5, 5.0), "wall")
	_box(Vector3(0, top * 0.5 + 0.8, -1.55), Vector3(5.4, top + 3.5, 0.22), "wall")
	# Зелёнка по стенам на всю высоту (низкая полоса на каждом этаже рисуем отдельно)
	_box(Vector3(-2.48, top * 0.5 + 0.5, 1.1), Vector3(0.06, top + 2.5, 4.8), "wainscot", false)
	_box(Vector3(2.48, top * 0.5 + 0.5, 1.1), Vector3(0.06, top + 2.5, 4.8), "wainscot", false)
	_box(Vector3(0, top * 0.5 + 0.5, -1.42), Vector3(5.0, top + 2.5, 0.06), "wainscot", false)

	# Фасад подъезда (на улицу) — панель + дверь только внизу
	_build_entrance_facade(floors, top)

	# Земля: если подвал — проём слева под марш; иначе сплошной пол
	if basement:
		_add_floor_landing(0.0, true, 0)
		_box(Vector3(0, -FLOOR_H - 0.1, 1.1), Vector3(5.0, 0.2, 4.8), "concrete")
		_add_flight(0, true, 0.0, -FLOOR_H)
		var bl := OmniLight3D.new()
		bl.light_color = Color(0.85, 0.65, 0.35)
		bl.light_energy = 0.7
		bl.omni_range = 6.0
		bl.position = Vector3(0, -FLOOR_H + 1.8, 1.0)
		add_child(bl)
	else:
		_box(Vector3(0, -0.1, 1.1), Vector3(5.0, 0.2, 4.8), "tile")
	_box(Vector3(0, 0.02, 2.9), Vector3(0.75, 0.04, 1.0), "mark", false)
	_add_entrance_door()

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		var left := (f % 2 == 1)  # 1 — левый марш вниз, 2 — правый…
		_add_floor_landing(y, left, f)
		_add_flight(f, left, y, y - FLOOR_H)
		_add_floor_props(y, f)
		_add_floor_light(y)

	_box(Vector3(0, top + 2.6, 1.1), Vector3(5.5, 0.28, 5.0), "concrete")

func _build_entrance_facade(floors: int, top: float) -> void:
	# Наружная стена-панель с швами
	_box(Vector3(-1.85, 1.45, 3.55), Vector3(1.5, 2.9, 0.2), "panel")
	_box(Vector3(1.85, 1.45, 3.55), Vector3(1.5, 2.9, 0.2), "panel")
	_box(Vector3(0, 2.95, 3.55), Vector3(5.4, 0.35, 0.2), "panel")
	# Швы панелей
	for i in range(3):
		var py := 3.5 + float(i) * 2.8
		if py < top + 1.0:
			_box(Vector3(0, py, 3.58), Vector3(5.2, 0.04, 0.04), "concrete", false)
	if floors >= 2:
		var uh := top - 2.9
		_box(Vector3(0, 3.0 + uh * 0.5, 3.55), Vector3(5.4, maxf(uh, 0.2), 0.2), "panel")
		# Окна клетки на фасаде
		for f in range(2, floors + 1):
			var wy := float(f) * FLOOR_H + 1.3
			_box(Vector3(0, wy, 3.62), Vector3(1.1, 1.0, 0.06), "glass", false)
			_box(Vector3(0, wy, 3.58), Vector3(1.2, 1.1, 0.04), "metal", false)

func _add_entrance_door() -> void:
	_box(Vector3(0, 1.15, 3.45), Vector3(1.15, 2.2, 0.08), "metal", false)
	_box(Vector3(0.35, 1.15, 3.42), Vector3(0.08, 0.35, 0.06), "metal", false)  # ручка
	_box(Vector3(-0.55, 1.5, 3.42), Vector3(0.25, 0.35, 0.05), "metal", false)  # домофон

func _add_floor_landing(y: float, left_stair: bool, floor_num: int) -> void:
	var sx := _stair_x(left_stair)
	var hole_l := sx - STAIR_W * 0.55
	var hole_r := sx + STAIR_W * 0.55
	# Задняя площадка (двери квартир)
	_box(Vector3(0, y - 0.1, -0.5), Vector3(5.0, 0.2, 1.9), "tile")
	# Передняя перемычка у окна/фасада
	_box(Vector3(0, y - 0.1, 3.25), Vector3(5.0, 0.2, 0.5), "tile")
	# Боковины проёма
	var mid_z := (HOLE_Z0 + HOLE_Z1) * 0.5
	var mid_d := HOLE_Z1 - HOLE_Z0
	var left_w := hole_l - (-2.45)
	if left_w > 0.12:
		_box(Vector3(-2.45 + left_w * 0.5, y - 0.1, mid_z), Vector3(left_w, 0.2, mid_d), "tile")
	var right_w := 2.45 - hole_r
	if right_w > 0.12:
		_box(Vector3(hole_r + right_w * 0.5, y - 0.1, mid_z), Vector3(right_w, 0.2, mid_d), "tile")
	# Зелёнка-бордюр на полу (визуал)
	_box(Vector3(0, y + 0.01, -0.5), Vector3(4.8, 0.02, 0.08), "wainscot", false)
	# Метка спуска — жёлтая потёртая краска у входа на марш
	_box(Vector3(sx, y + 0.03, HOLE_Z0 - 0.08), Vector3(0.9, 0.05, 0.35), "mark", false)

func _add_flight(from_floor: int, left: bool, y_top: float, y_bot: float) -> void:
	var x := _stair_x(left)
	var z0 := HOLE_Z0
	var z1 := HOLE_Z1
	var run := z1 - z0
	var rise := y_top - y_bot
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)

	# Пандус (коллизия)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(STAIR_W - 0.1, 0.2, length)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(x, (y_top + y_bot) * 0.5, (z0 + z1) * 0.5)
	body.rotation.x = angle
	add_child(body)

	# Бетонные ступени (вид)
	var steps := 12
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y_top, y_bot, t)
		var z := lerpf(z0 + 0.05, z1 - 0.05, t)
		_box(Vector3(x, y, z), Vector3(STAIR_W - 0.15, 0.11, 0.28), "concrete", false)

	# Стыки
	_box(Vector3(x, y_top - 0.03, z0 + 0.15), Vector3(STAIR_W - 0.1, 0.12, 0.4), "concrete", true)
	_box(Vector3(x, y_bot + 0.03, z1 - 0.15), Vector3(STAIR_W - 0.1, 0.12, 0.4), "concrete", true)

	# Перила марша (тонкие, как в панельке)
	var rail_x := x + (STAIR_W * 0.48 if not left else -STAIR_W * 0.48)
	var rail := StaticBody3D.new()
	rail.collision_layer = 1
	var rcs := CollisionShape3D.new()
	var rsh := BoxShape3D.new()
	rsh.size = Vector3(0.06, 0.85, length * 0.95)
	rcs.shape = rsh
	rail.add_child(rcs)
	var rmi := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = rsh.size
	rmi.mesh = rbm
	rmi.material_override = _mats["rail"]
	rail.add_child(rmi)
	rail.position = Vector3(rail_x, (y_top + y_bot) * 0.5 + 0.45, (z0 + z1) * 0.5)
	rail.rotation.x = angle
	add_child(rail)

	# Перила на площадке вокруг проёма (не на всю глубину — вход свободен)
	var hole_inner := x + (0.95 if left else -0.95)
	_box(Vector3(hole_inner, y_top + 0.5, (HOLE_Z0 + HOLE_Z1) * 0.5), Vector3(0.06, 0.9, RAMP_RUN * 0.85), "rail")
	_box(Vector3(x, y_top + 0.5, HOLE_Z1), Vector3(STAIR_W * 0.9, 0.9, 0.06), "rail")

func _add_floor_props(y: float, floor_num: int) -> void:
	# Двери квартир на площадке
	_box(Vector3(-2.15, y + 1.05, -1.2), Vector3(0.08, 2.05, 0.85), "door_apt", false)
	_box(Vector3(2.15, y + 1.05, -1.2), Vector3(0.08, 2.05, 0.85), "door_apt", false)
	# Номерок
	_box(Vector3(-2.05, y + 1.7, -0.85), Vector3(0.04, 0.18, 0.28), "number", false)
	_box(Vector3(2.05, y + 1.7, -0.85), Vector3(0.04, 0.18, 0.28), "number", false)
	# Почтовые ящики / щиток на площадке
	if floor_num == 1:
		for i in range(5):
			var bx := -2.15 + float(i) * 0.38
			_box(Vector3(bx, y + 1.15, -1.35), Vector3(0.32, 0.85, 0.12), "mail", false)
	else:
		_box(Vector3(-2.15, y + 1.25, -1.35), Vector3(0.55, 0.4, 0.1), "mail", false)
	# Проводка / труба
	_box(Vector3(2.35, y + 2.2, 0.8), Vector3(0.06, 0.06, 3.5), "metal", false)
	# Подоконник окна клетки
	_box(Vector3(0, y + 1.15, 3.35), Vector3(1.0, 0.08, 0.25), "concrete", false)

func _add_floor_light(y: float) -> void:
	# «Дневной» светильник
	_box(Vector3(0, y + 2.55, 0.2), Vector3(1.2, 0.08, 0.25), "metal", false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.95, 0.92, 0.75)
	lamp.light_energy = 1.35
	lamp.omni_range = 7.5
	lamp.omni_attenuation = 1.4
	lamp.position = Vector3(0, y + 2.45, 0.2)
	add_child(lamp)
	lights.append(lamp)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	spawn_pos = Vector3(0.0, y + 0.35, -0.55)
	# «Твоя» дверь чуть выделена
	_box(Vector3(-2.05, y + 1.05, -1.15), Vector3(0.1, 2.05, 0.9), "door", false)

func _build_yard(ice: bool, night: bool) -> void:
	var mat_key := "ice" if ice else "concrete"
	_box(Vector3(0, -0.15, 11.0), Vector3(22.0, 0.3, 16.0), mat_key)
	# Фасад дома с двора — сетка окон панельки
	_box(Vector3(0, 8.0, 3.9), Vector3(14.0, 16.0, 0.35), "panel")
	for row in range(5):
		for col in range(4):
			var wx := -4.5 + float(col) * 3.0
			var wy := 2.0 + float(row) * 2.8
			_box(Vector3(wx, wy, 4.15), Vector3(1.2, 1.3, 0.08), "glass", false)
			_box(Vector3(wx, wy, 4.05), Vector3(1.35, 1.45, 0.05), "metal", false)
	# Козырёк подъезда
	_box(Vector3(0, 2.6, 4.6), Vector3(3.2, 0.12, 1.8), "concrete")
	_box(Vector3(-1.4, 1.3, 4.6), Vector3(0.15, 2.5, 0.15), "metal")
	_box(Vector3(1.4, 1.3, 4.6), Vector3(0.15, 2.5, 0.15), "metal")
	# Двор
	_box(Vector3(-9.5, 0.7, 11.0), Vector3(1.0, 1.4, 14.0), "panel")
	_box(Vector3(9.5, 0.7, 11.0), Vector3(1.0, 1.4, 14.0), "panel")
	_box(Vector3(0, 0.9, 18.5), Vector3(19.0, 1.8, 1.0), "panel")
	# Лавочка, урна, машина
	_box(Vector3(-4.0, 0.35, 8.5), Vector3(1.6, 0.12, 0.45), "prop")
	_box(Vector3(-4.5, 0.45, 8.5), Vector3(0.12, 0.45, 0.4), "prop")
	_box(Vector3(-3.5, 0.45, 8.5), Vector3(0.12, 0.45, 0.4), "prop")
	_box(Vector3(5.5, 0.55, 10.0), Vector3(2.4, 1.0, 1.15), "prop")
	_box(Vector3(-6.0, 1.3, 13.0), Vector3(0.3, 2.5, 0.3), "prop")
	_box(Vector3(-6.0, 2.7, 13.0), Vector3(1.5, 0.5, 1.5), "wall")
	if ice:
		_box(Vector3(0, 0.02, 9.5), Vector3(3.5, 0.05, 1.0), "ice")
		yard_ice_zones.append(Rect2(Vector2(-8, 6), Vector2(16, 11)))
	if night:
		var yl := OmniLight3D.new()
		yl.light_color = Color(1.0, 0.85, 0.55)
		yl.light_energy = 2.2
		yl.omni_range = 12.0
		yl.position = Vector3(0, 4.5, 7.0)
		add_child(yl)

func _build_detour_path() -> void:
	_box(Vector3(-7.0, -0.05, 11.0), Vector3(2.2, 0.12, 10.0), "concrete")
	_box(Vector3(-7.0, 0.04, 15.0), Vector3(0.5, 0.06, 0.5), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(1.2, -FLOOR_H + 0.35, 1.2), Vector3(0.25, 0.25, 2.2), "metal")
	_box(Vector3(-1.0, -FLOOR_H + 0.12, 2.0), Vector3(1.0, 0.06, 1.0), "ice")

func _build_dumpster() -> void:
	_box(Vector3(4.0, 0.75, 14.5), Vector3(2.4, 1.5, 1.5), "dumpster")
	_box(Vector3(4.0, 1.55, 14.5), Vector3(2.5, 0.12, 1.55), "metal", false)  # крышка
	dumpster = Area3D.new()
	dumpster.name = "Dumpster"
	dumpster.collision_layer = 0
	dumpster.collision_mask = 2 | 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.8, 2.0, 2.2)
	cs.shape = sh
	dumpster.add_child(cs)
	dumpster.position = Vector3(4.0, 1.0, 14.5)
	add_child(dumpster)
	_box(Vector3(4.0, 2.3, 14.5), Vector3(0.4, 0.25, 0.4), "mark", false)

func _build_elevator(floors: int) -> void:
	var start_f: int = int(_level.get("start_floor", floors))
	var y := float(start_f) * FLOOR_H
	_box(Vector3(2.15, floors * FLOOR_H * 0.5, -0.9), Vector3(0.85, floors * FLOOR_H, 0.85), "metal")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.3, 1.0)
	cs.shape = sh
	elevator_area.add_child(cs)
	elevator_area.position = Vector3(2.15, y + 1.0, -0.9)
	add_child(elevator_area)
	_box(Vector3(2.15, y + 1.1, -0.4), Vector3(0.75, 2.0, 0.05), "metal", false)

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
	# Лицом к проёму лестницы (+Z), чуть к стороне марша
	var left := (start_floor % 2 == 1)
	p.set_look_yaw(PI + (0.35 if left else -0.35))
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = spawn_pos + Vector3(0.35, 0.65, 0.2)
	bag = trash

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", 0.35, period * 0.5)
			tw.tween_property(lamp, "light_energy", 1.35, period * 0.5)

func is_on_ice(pos: Vector3) -> bool:
	for r in yard_ice_zones:
		if (r as Rect2).has_point(Vector2(pos.x, pos.z)):
			return true
	return false

func guide_hint(player_pos: Vector3) -> String:
	var lang: String = Svc.loc().lang
	if player_pos.z > 8.0 and player_pos.y < 1.5:
		return "Помойка — подойди и нажми E" if lang == "ru" else "Dumpster — walk up and press E"
	if player_pos.y < 1.2 and player_pos.z > 2.5:
		return "Выход во двор — дверь подъезда" if lang == "ru" else "Exit to the yard — entrance door"
	var left := true
	# На чётном этаже марш справа
	var fl := int(round(player_pos.y / FLOOR_H))
	left = (fl % 2 == 1)
	if lang == "ru":
		return "Спуск: %s марш (жёлтая метка у проёма)" % ("левый" if left else "правый")
	return "Stairs: %s flight (yellow mark)" % ("left" if left else "right")
