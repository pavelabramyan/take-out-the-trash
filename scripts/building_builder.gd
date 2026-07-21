class_name BuildingBuilder
extends Node3D
## Реалистичная клетка панельки (серия ~90 / брежневка):
## ширина ~3.1 м, марш 1.05 м, зазор 0.15 м, U-лестница, потолки, тусклый свет.

const TrashPlayerScr = preload("res://scripts/player.gd")
const TrashBagScr = preload("res://scripts/trash_bag.gd")
const StairNpcScr = preload("res://scripts/npc.gd")

const FLOOR_H := 2.8
const HALF_H := 1.4
const STAIR_W := 1.05
const CELL_HALF := 1.55          # чистота ~3.1 м
const CELL_W := CELL_HALF * 2.0
const STAIR_X := 0.60            # ±, зазор между маршами ~0.15 м
## Этажная площадка (глубина ~1.65 м — как типовая)
const LAND_Z0 := -1.25
const LAND_Z1 := 0.40
## Промежуточная — не над тамбуром
const MID_Z0 := 2.15
const MID_Z1 := 2.75
const FLIGHT_Z_A0 := 0.40
const FLIGHT_Z_A1 := 2.15
const DOOR_Z := 3.70
const LOBBY_Z0 := 2.90

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
	_build_level_flavor()
	# Только гул подъезда — музыка позже из game.gd
	Svc.audio().play_ambient()

func _make_materials() -> void:
	## Цвета по рефу Нижегородской / типовой клетки: грязная бирюза + грязный верх.
	## Важно: albedo_color умножается на текстуру — при готовой albedo держим ~1.0.
	var style: String = str(_level.get("style", "khrushchev"))
	var wall_up := Color(1.05, 1.0, 0.92)       # грязно-белый верх (tint на wall.png)
	var wall_low := Color(1.15, 1.2, 1.1)        # зелёнка уже в zelenka.png
	var tile_c := Color(0.95, 0.92, 0.88)
	var panel_c := Color(1.0, 0.96, 0.9)         # облезлая панель
	match style:
		"brezhnev":
			wall_up = Color(1.0, 1.0, 1.0)
			wall_low = Color(0.95, 1.05, 1.2)
			panel_c = Color(0.95, 0.98, 1.0)
		"courtyard":
			wall_up = Color(1.0, 0.95, 0.85)
			wall_low = Color(1.1, 0.95, 0.85)
			panel_c = Color(1.0, 0.9, 0.8)
		_:
			pass
	_mats["wall"] = _tex_mat("res://assets/textures/wall.png", wall_up, Vector3(0.7, 0.7, 0.7))
	(_mats["wall"] as StandardMaterial3D).roughness = 0.92
	_mats["wainscot"] = _tex_mat("res://assets/textures/zelenka.png", wall_low, Vector3(0.95, 0.95, 0.95))
	(_mats["wainscot"] as StandardMaterial3D).roughness = 0.55  # масляная краска чуть блестит
	_mats["tile"] = _tex_mat("res://assets/textures/tile.png", tile_c, Vector3(5.5, 5.5, 5.5))
	(_mats["tile"] as StandardMaterial3D).roughness = 0.9
	_mats["rail"] = _mat(Color(0.18, 0.18, 0.19), 0.65)
	(_mats["rail"] as StandardMaterial3D).roughness = 0.55
	_mats["handrail"] = _mat(Color(0.38, 0.14, 0.12), 0.05)  # тёмно-бордовый поручень
	(_mats["handrail"] as StandardMaterial3D).roughness = 0.62
	_mats["door"] = _tex_mat("res://assets/textures/door.png", Color(1.0, 1.0, 1.0), Vector3(1, 1, 1))
	_mats["door_apt"] = _tex_mat("res://assets/textures/door.png", Color(1.1, 1.05, 0.95), Vector3(1, 1, 1))
	_mats["door_metal"] = _tex_mat("res://assets/textures/metal_door.png", Color(1.0, 1.0, 1.0), Vector3(1, 1, 1))
	_mats["concrete"] = _tex_mat("res://assets/textures/concrete.png", Color(1.0, 0.96, 0.88), Vector3(2.2, 2.2, 2.2))
	# Ступени: жёлтый бетон в центре прохода + зелёная краска по краям
	_mats["step"] = _tex_mat("res://assets/textures/concrete.png", Color(1.15, 1.05, 0.85), Vector3(3.5, 3.5, 3.5))
	_mats["step_paint"] = _tex_mat("res://assets/textures/zelenka.png", Color(1.25, 1.35, 1.15), Vector3(2.0, 2.0, 2.0))
	(_mats["step_paint"] as StandardMaterial3D).roughness = 0.7
	_mats["panel"] = _tex_mat("res://assets/textures/panel.png", panel_c, Vector3(0.85, 0.85, 0.85))
	_mats["asphalt"] = _tex_mat("res://assets/textures/asphalt.png", Color(1.05, 1.05, 1.05), Vector3(4.5, 4.5, 4.5))
	_mats["ice"] = _mat(Color(0.75, 0.85, 0.95), 0.2)
	_mats["dumpster"] = _tex_mat("res://assets/textures/dumpster.png", Color(1.15, 1.25, 1.1), Vector3(1.2, 1.2, 1.2))
	_mats["mail"] = _mat(Color(0.30, 0.28, 0.22), 0.45)
	(_mats["mail"] as StandardMaterial3D).roughness = 0.55
	_mats["metal"] = _mat(Color(0.22, 0.23, 0.24), 0.75)
	(_mats["metal"] as StandardMaterial3D).roughness = 0.48
	_mats["glass"] = _mat(Color(0.28, 0.34, 0.38), 0.05)
	(_mats["glass"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_mats["glass"] as StandardMaterial3D).albedo_color.a = 0.45
	(_mats["glass"] as StandardMaterial3D).roughness = 0.3
	_mats["mark"] = _mat(Color(0.28, 0.22, 0.12))
	(_mats["mark"] as StandardMaterial3D).roughness = 0.96
	_mats["prop"] = _mat(Color(0.26, 0.24, 0.22))
	_mats["number"] = _mat(Color(0.72, 0.70, 0.58))
	_mats["wood"] = _mat(Color(0.34, 0.22, 0.12))
	_mats["paper"] = _mat(Color(0.72, 0.68, 0.55))
	_mats["dirt"] = _mat(Color(0.18, 0.16, 0.12))
	(_mats["dirt"] as StandardMaterial3D).albedo_color.a = 0.62
	(_mats["dirt"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["graffiti"] = _mat(Color(0.12, 0.12, 0.12))
	(_mats["graffiti"] as StandardMaterial3D).roughness = 0.95
	_mats["grass"] = _mat(Color(0.32, 0.30, 0.18))  # сухая дворовая трава
	(_mats["grass"] as StandardMaterial3D).roughness = 0.95
	_mats["rust"] = _mat(Color(0.42, 0.22, 0.10), 0.35)
	(_mats["rust"] as StandardMaterial3D).roughness = 0.78
	_mats["lamp"] = _mat(Color(1.0, 0.88, 0.55))
	(_mats["lamp"] as StandardMaterial3D).emission_enabled = true
	(_mats["lamp"] as StandardMaterial3D).emission = Color(1.0, 0.78, 0.35)
	(_mats["lamp"] as StandardMaterial3D).emission_energy_multiplier = 3.2
	_mats["window_lit"] = _mat(Color(0.95, 0.85, 0.55))
	(_mats["window_lit"] as StandardMaterial3D).emission_enabled = true
	(_mats["window_lit"] as StandardMaterial3D).emission = Color(1.0, 0.82, 0.45)
	(_mats["window_lit"] as StandardMaterial3D).emission_energy_multiplier = 1.6
	_mats["curtain"] = _mat(Color(0.45, 0.30, 0.24))
	(_mats["curtain"] as StandardMaterial3D).roughness = 0.9
	_mats["balcony"] = _mat(Color(0.72, 0.72, 0.70))
	(_mats["balcony"] as StandardMaterial3D).roughness = 0.75
	_mats["puddle"] = _mat(Color(0.22, 0.24, 0.26), 0.25)
	(_mats["puddle"] as StandardMaterial3D).roughness = 0.28
	(_mats["puddle"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_mats["puddle"] as StandardMaterial3D).albedo_color.a = 0.45

func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.94 - metallic * 0.5
	m.metallic = metallic
	return m

func _tex_mat(path: String, fallback: Color, uv_scale: Vector3 = Vector3(2, 2, 2)) -> StandardMaterial3D:
	var m := _mat(fallback)
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = uv_scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rough_path := path.get_basename() + "_rough.png"
	if ResourceLoader.exists(rough_path):
		m.roughness_texture = load(rough_path)
	var nrm_path := path.get_basename() + "_normal.png"
	if ResourceLoader.exists(nrm_path):
		m.normal_enabled = true
		m.normal_texture = load(nrm_path)
		m.normal_scale = 0.65
	return m

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Небо с горизонтом — не плоская заливка
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	if night:
		sky_mat.sky_top_color = Color(0.04, 0.05, 0.09)
		sky_mat.sky_horizon_color = Color(0.12, 0.11, 0.14)
		sky_mat.ground_horizon_color = Color(0.08, 0.07, 0.07)
		sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.05)
		sky_mat.sun_angle_max = 2.0
		sky_mat.sky_energy_multiplier = 0.55
	else:
		sky_mat.sky_top_color = Color(0.42, 0.55, 0.72)
		sky_mat.sky_horizon_color = Color(0.72, 0.68, 0.58)
		sky_mat.ground_horizon_color = Color(0.45, 0.42, 0.38)
		sky_mat.ground_bottom_color = Color(0.28, 0.26, 0.24)
		sky_mat.sun_angle_max = 28.0
		sky_mat.sky_energy_multiplier = 1.05
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Ambient: мрачно, но зелёнка должна читаться (не «чёрная студия»)
	env.ambient_light_color = Color(0.32, 0.30, 0.26) if night else Color(0.55, 0.52, 0.46)
	env.ambient_light_energy = 0.45 if night else 0.58
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.12, 0.14) if night else Color(0.55, 0.52, 0.48)
	env.fog_density = 0.01 if night else 0.003
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.65
	env.glow_bloom = 0.06
	# SDFGI на MoltenVK/AMD нестабилен — fill светом + ReflectionProbe
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.04
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12 if night else 1.22
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.4 if night else 1.05
	sun.light_color = Color(0.55, 0.62, 0.85) if night else Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.rotation_degrees = Vector3(-32, 42, 0) if night else Vector3(-38, 55, 0)
	add_child(sun)

	# Bounce в клетке + у входа
	var rp_cell := ReflectionProbe.new()
	rp_cell.size = Vector3(4.2, 12.0, 6.5)
	rp_cell.position = Vector3(0, 4.0, 1.2)
	rp_cell.update_mode = ReflectionProbe.UPDATE_ONCE
	rp_cell.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	add_child(rp_cell)
	var rp_yard := ReflectionProbe.new()
	rp_yard.size = Vector3(18.0, 8.0, 16.0)
	rp_yard.position = Vector3(0, 2.5, 10.0)
	rp_yard.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(rp_yard)

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
	return -STAIR_X if left else STAIR_X

func _upper_left(_floor_num: int) -> bool:
	return false

func _build_stairwell(floors: int, basement: bool, has_elevator: bool) -> void:
	var top := float(floors) * FLOOR_H
	# Коробка клетки ~3.1 × ~5 м
	_box(Vector3(-CELL_HALF - 0.08, top * 0.5 + 0.5, 1.15), Vector3(0.16, top + 3.0, 5.0), "wall")
	_box(Vector3(CELL_HALF + 0.08, top * 0.5 + 0.5, 1.15), Vector3(0.16, top + 3.0, 5.0), "wall")
	_box(Vector3(0, top * 0.5 + 0.5, LAND_Z0 - 0.12), Vector3(CELL_W + 0.2, top + 3.0, 0.16), "wall")
	_build_entrance_facade(floors, top)

	if basement:
		_add_main_landing(0.0, 0)
		_box(Vector3(0, -FLOOR_H - 0.1, 1.15), Vector3(CELL_W, 0.2, 5.0), "concrete")
		_add_u_flights(0, 0.0, -FLOOR_H)
		var bl := OmniLight3D.new()
		bl.light_color = Color(1.0, 0.72, 0.35)
		bl.light_energy = 0.45
		bl.omni_range = 4.5
		bl.omni_attenuation = 2.0
		bl.position = Vector3(0, -FLOOR_H + 1.6, 1.0)
		add_child(bl)
	else:
		_add_main_landing(0.0, 0)
		_box(Vector3(0, -0.1, 1.4), Vector3(CELL_W - 0.1, 0.2, 1.9), "tile")
		_box(Vector3(0, -0.1, (LOBBY_Z0 + DOOR_Z) * 0.5), Vector3(CELL_W - 0.1, 0.2, 1.2), "tile")
		# потёртость у входа — не неон
		_box(Vector3(0, 0.02, 3.2), Vector3(0.55, 0.03, 0.5), "mark", false)

	_add_entrance_props()
	_add_ground_mailboxes()
	# Потолок тамбура (полный рост)
	_box(Vector3(0, FLOOR_H - 0.14, 3.25), Vector3(CELL_W - 0.1, 0.12, 1.3), "concrete")

	for f in range(1, floors + 1):
		var y := float(f) * FLOOR_H
		_add_main_landing(y, f)
		_add_mid_landing(y - HALF_H)
		_add_u_flights(f, y, y - FLOOR_H)
		_add_floor_props(y, f, has_elevator)
		_add_floor_wainscot(y)
		_add_floor_light(y)
		_add_floor_ceiling(y)
		_add_dirt_stains(y)

	_add_floor_wainscot(0.0)
	_add_dirt_stains(0.0)
	_box(Vector3(0, top + 2.45, 1.15), Vector3(CELL_W + 0.3, 0.22, 5.1), "concrete")

func _add_floor_ceiling(y: float) -> void:
	## Перекрытие над этажной площадкой — без него клетка «без потолка»
	var cy := y + FLOOR_H - 0.14
	var depth := LAND_Z1 - LAND_Z0
	var zc := (LAND_Z0 + LAND_Z1) * 0.5
	_box(Vector3(0, cy, zc), Vector3(CELL_W - 0.1, 0.12, depth), "concrete")
	# Боковые полосы над шахтой (отверстие под марши)
	_box(Vector3(-CELL_HALF + 0.22, cy, 1.35), Vector3(0.4, 0.12, 1.8), "concrete")
	_box(Vector3(CELL_HALF - 0.22, cy, 1.35), Vector3(0.4, 0.12, 1.8), "concrete")

func _add_dirt_stains(y: float) -> void:
	_box(Vector3(-CELL_HALF + 0.02, y + 0.4, 0.3), Vector3(0.02, 0.5, 0.7), "dirt", false)
	_box(Vector3(CELL_HALF - 0.02, y + 1.1, -0.4), Vector3(0.02, 0.8, 0.4), "dirt", false)
	_box(Vector3(0.4, y + 0.02, -0.6), Vector3(0.6, 0.01, 0.35), "dirt", false)

func _build_entrance_facade(floors: int, top: float) -> void:
	var hw := CELL_W * 0.5
	_box(Vector3(-hw * 0.55 - 0.35, 1.3, DOOR_Z - 0.1), Vector3(hw * 0.7, 2.6, 0.14), "panel")
	_box(Vector3(hw * 0.55 + 0.35, 1.3, DOOR_Z - 0.1), Vector3(hw * 0.7, 2.6, 0.14), "panel")
	_box(Vector3(0, 2.75, DOOR_Z - 0.1), Vector3(CELL_W + 0.15, 0.35, 0.14), "panel")
	var uh := top - 2.75
	if uh > 0.15:
		_box(Vector3(0, 2.8 + uh * 0.5, DOOR_Z - 0.1), Vector3(CELL_W + 0.15, uh, 0.14), "panel")
	for f in range(1, floors + 1):
		var mid_y := float(f) * FLOOR_H - HALF_H
		_box(Vector3(0, mid_y + 1.1, DOOR_Z - 0.02), Vector3(0.95, 1.15, 0.04), "glass", false)
		_box(Vector3(0, mid_y + 1.1, DOOR_Z - 0.08), Vector3(1.05, 1.25, 0.04), "metal", false)
		_box(Vector3(0, mid_y + 0.48, DOOR_Z - 0.14), Vector3(1.1, 0.07, 0.2), "concrete", false)
		_box(Vector3(-0.3, mid_y + 1.15, DOOR_Z), Vector3(0.22, 0.85, 0.02), "paper", false)

func _add_entrance_props() -> void:
	# Открытая дверь + рама / ручка / доводчик
	_box(Vector3(-0.78, 1.05, DOOR_Z - 0.32), Vector3(0.06, 2.05, 0.8), "door_metal", false)
	_box(Vector3(-0.62, 1.4, DOOR_Z - 0.16), Vector3(0.16, 0.26, 0.05), "metal", false)
	_box(Vector3(-0.72, 1.05, DOOR_Z - 0.12), Vector3(0.07, 2.1, 0.08), "metal", false)
	_box(Vector3(0.72, 1.05, DOOR_Z - 0.12), Vector3(0.07, 2.1, 0.08), "metal", false)
	_box(Vector3(0, 2.15, DOOR_Z - 0.12), Vector3(1.5, 0.09, 0.08), "metal", false)
	_box(Vector3(0.55, 1.85, DOOR_Z - 0.2), Vector3(0.08, 0.06, 0.22), "metal", false)  # доводчик
	_box(Vector3(0, 0.015, 3.15), Vector3(0.9, 0.025, 0.45), "prop", false)
	_box(Vector3(CELL_HALF - 0.25, 1.45, 3.35), Vector3(0.4, 0.65, 0.04), "wood", false)
	_box(Vector3(CELL_HALF - 0.25, 1.5, 3.32), Vector3(0.32, 0.5, 0.02), "paper", false)
	_box(Vector3(-CELL_HALF + 0.25, 1.5, 3.35), Vector3(0.35, 0.65, 0.1), "metal", false)
	# Наружный пол у козырька — не смотреть в void под ногами
	_box(Vector3(0, -0.05, DOOR_Z + 0.9), Vector3(2.4, 0.12, 2.0), "concrete")
	_box(Vector3(0, 0.02, DOOR_Z + 0.35), Vector3(1.6, 0.04, 0.5), "concrete", false)
	# Свет с улицы в тамбур
	var slit := OmniLight3D.new()
	slit.light_color = Color(0.85, 0.9, 1.0)
	slit.light_energy = 1.35
	slit.omni_range = 3.2
	slit.omni_attenuation = 1.5
	slit.position = Vector3(0.15, 1.1, DOOR_Z + 0.35)
	add_child(slit)
	# Плафон под козырьком
	_box(Vector3(0, 2.35, DOOR_Z + 0.55), Vector3(0.35, 0.08, 0.35), "metal", false)
	_box(Vector3(0, 2.30, DOOR_Z + 0.55), Vector3(0.22, 0.04, 0.22), "lamp", false)
	var el := OmniLight3D.new()
	el.light_color = Color(1.0, 0.82, 0.48)
	el.light_energy = 1.35
	el.omni_range = 4.5
	el.omni_attenuation = 1.8
	el.shadow_enabled = true
	el.position = Vector3(0, 2.25, DOOR_Z + 0.55)
	add_child(el)
	lights.append(el)

func _add_ground_mailboxes() -> void:
	for i in range(4):
		var bx := -1.05 + float(i) * 0.52
		_box(Vector3(bx, 1.0, LAND_Z0 + 0.08), Vector3(0.46, 0.9, 0.12), "mail", false)
		_box(Vector3(bx, 1.25, LAND_Z0 + 0.15), Vector3(0.32, 0.07, 0.02), "number", false)

func _add_main_landing(y: float, floor_num: int) -> void:
	var depth := LAND_Z1 - LAND_Z0
	var zc := (LAND_Z0 + LAND_Z1) * 0.5
	_box(Vector3(0, y - 0.1, zc), Vector3(CELL_W - 0.12, 0.2, depth), "tile")
	# Узкие боковины шахты
	_box(Vector3(-CELL_HALF + 0.28, y - 0.1, 1.25), Vector3(0.5, 0.2, 1.6), "tile")
	_box(Vector3(CELL_HALF - 0.28, y - 0.1, 1.25), Vector3(0.5, 0.2, 1.6), "tile")
	_box(Vector3(0, y + 0.01, LAND_Z0 + 0.06), Vector3(CELL_W - 0.2, 0.025, 0.05), "wainscot", false)
	if floor_num > 0:
		var sx := _stair_x(false)  # всегда правый верхний
		_box(Vector3(sx, y + 0.02, LAND_Z1 - 0.04), Vector3(0.55, 0.03, 0.22), "mark", false)

func _add_mid_landing(y: float) -> void:
	var depth := MID_Z1 - MID_Z0
	var zc := (MID_Z0 + MID_Z1) * 0.5
	_box(Vector3(0, y - 0.1, zc), Vector3(CELL_W - 0.15, 0.2, depth), "tile")
	_box(Vector3(0, y + 0.05, MID_Z0 - 0.06), Vector3(0.7, 0.1, 0.05), "rail")
	# Ограждение: поручень + нижняя тяга + стойки
	_box(Vector3(0, y + 0.9, MID_Z1), Vector3(CELL_W - 0.25, 0.05, 0.05), "metal", false)
	_box(Vector3(0, y + 0.25, MID_Z1), Vector3(CELL_W - 0.25, 0.03, 0.03), "metal", false)
	for i in range(6):
		var rx := -1.15 + float(i) * 0.46
		_box(Vector3(rx, y + 0.55, MID_Z1), Vector3(0.03, 0.85, 0.03), "metal", false)
	_box(Vector3(-1.2, y + 0.9, zc), Vector3(0.05, 0.05, depth * 0.85), "metal", false)
	_box(Vector3(1.2, y + 0.9, zc), Vector3(0.05, 0.05, depth * 0.85), "metal", false)
	_box(Vector3(-1.2, y + 0.55, zc), Vector3(0.03, 0.8, depth * 0.85), "metal", false)
	_box(Vector3(1.2, y + 0.55, zc), Vector3(0.03, 0.8, depth * 0.85), "metal", false)

func _add_u_flights(from_floor: int, y_top: float, y_bot: float) -> void:
	var mid_y := y_top - HALF_H
	_add_flight_segment(_stair_x(false), y_top, mid_y, FLIGHT_Z_A0, FLIGHT_Z_A1, false)
	_add_flight_segment(_stair_x(true), mid_y, y_bot, FLIGHT_Z_A1, FLIGHT_Z_A0, true)

func _add_flight_segment(x: float, y_top: float, y_bot: float, z0: float, z1: float, left: bool) -> void:
	var run := absf(z1 - z0)
	var rise := y_top - y_bot
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	if z1 < z0:
		angle = -angle

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(STAIR_W - 0.06, 0.16, length)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(x, (y_top + y_bot) * 0.5, (z0 + z1) * 0.5)
	body.rotation.x = angle
	add_child(body)

	# Реф Нижегородская: зелёная краска по краям, вытертый жёлтый бетон по центру
	var steps := 9
	var z_dir := 1.0 if z1 > z0 else -1.0
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y_top, y_bot, t)
		var z := lerpf(z0, z1, t)
		var tread_w := STAIR_W - 0.08
		_box(Vector3(x, y, z), Vector3(tread_w, 0.07, 0.22), "step_paint", false)
		# Вытертая середина (проходом)
		_box(Vector3(x, y + 0.012, z), Vector3(tread_w * 0.42, 0.02, 0.18), "step", false)
		_box(Vector3(x, y - 0.055, z - z_dir * 0.05), Vector3(tread_w - 0.02, 0.11, 0.08), "concrete", false)
		var nz := z + z_dir * 0.1
		_box(Vector3(x, y + 0.03, nz), Vector3(tread_w - 0.04, 0.015, 0.035), "step", false)
		if i % 2 == 0:
			_box(Vector3(x + (0.38 if left else -0.38), y + 0.04, z), Vector3(0.14, 0.012, 0.12), "dirt", false)

	_box(Vector3(x, y_top - 0.02, z0 + (0.1 if z1 > z0 else -0.1)), Vector3(STAIR_W - 0.06, 0.09, 0.28), "concrete", true)
	_box(Vector3(x, y_bot + 0.02, z1 + (-0.1 if z1 > z0 else 0.1)), Vector3(STAIR_W - 0.06, 0.09, 0.28), "concrete", true)

	# Перила: тёмный металл + бордовый поручень (реф)
	var rail_x := x + (STAIR_W * 0.46 if not left else -STAIR_W * 0.46)
	var wall_side := 1.0 if not left else -1.0
	var rail := StaticBody3D.new()
	rail.collision_layer = 1
	var rcs := CollisionShape3D.new()
	var rsh := BoxShape3D.new()
	rsh.size = Vector3(0.05, 0.85, length * 0.92)
	rcs.shape = rsh
	rail.add_child(rcs)
	var rmi := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = Vector3(0.055, 0.045, length * 0.92)
	rmi.mesh = rbm
	rmi.material_override = _mats["handrail"]
	rmi.position.y = 0.44
	rail.add_child(rmi)
	var low := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(0.03, 0.03, length * 0.9)
	low.mesh = lbm
	low.material_override = _mats["metal"]
	low.position.y = -0.05
	rail.add_child(low)
	rail.position = Vector3(rail_x, (y_top + y_bot) * 0.5 + 0.42, (z0 + z1) * 0.5)
	rail.rotation.x = angle
	add_child(rail)

	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var sy := lerpf(y_top, y_bot, t) + 0.4
		var sz := lerpf(z0, z1, t)
		_box(Vector3(rail_x, sy, sz), Vector3(0.026, 0.78, 0.026), "metal", false)
		_box(Vector3(rail_x + wall_side * 0.12, sy + 0.25, sz), Vector3(0.18, 0.03, 0.03), "metal", false)

	# Низ марша / «под лестницей» — граффити и мусор (реф)
	var under_y := (y_top + y_bot) * 0.5 - 0.55
	var under_z := (z0 + z1) * 0.5
	_box(Vector3(x - wall_side * 0.55, under_y + 0.35, under_z), Vector3(0.02, 0.35, 0.55), "graffiti", false)
	_box(Vector3(x - wall_side * 0.52, under_y + 0.15, under_z + 0.1), Vector3(0.18, 0.12, 0.18), "prop", false)

func _add_floor_wainscot(y: float) -> void:
	var h := 1.45
	var cy := y + h * 0.5
	# Чуть толще / ближе к игроку — иначе зелёнка тонет в стенке
	_box(Vector3(-CELL_HALF + 0.05, cy, 1.15), Vector3(0.08, h, 4.8), "wainscot", false)
	_box(Vector3(CELL_HALF - 0.05, cy, 1.15), Vector3(0.08, h, 4.8), "wainscot", false)
	_box(Vector3(0, cy, LAND_Z0 + 0.05), Vector3(CELL_W - 0.12, h, 0.08), "wainscot", false)
	# Линия раздела зелёнка / верх + плинтус
	_box(Vector3(0, y + h, 1.15), Vector3(CELL_W - 0.1, 0.02, 4.7), "dirt", false)
	_box(Vector3(-CELL_HALF + 0.04, y + 0.04, 1.15), Vector3(0.06, 0.08, 4.6), "concrete", false)
	_box(Vector3(CELL_HALF - 0.04, y + 0.04, 1.15), Vector3(0.06, 0.08, 4.6), "concrete", false)
	_box(Vector3(0, y + 0.04, LAND_Z0 + 0.04), Vector3(CELL_W - 0.2, 0.08, 0.06), "concrete", false)

func _add_floor_props(y: float, floor_num: int, has_elevator: bool) -> void:
	# Две двери на ЗАДНЕЙ стене — как в клетке, не «коридор»
	_apt_door(Vector3(-0.85, y + 1.0, LAND_Z0 + 0.1), floor_num * 2 - 1, true)
	_apt_door(Vector3(0.85, y + 1.0, LAND_Z0 + 0.1), floor_num * 2, true)
	# Батарея у боковой стены
	_box(Vector3(-CELL_HALF + 0.12, y + 0.5, 0.7), Vector3(0.1, 0.5, 0.55), "metal", false)
	for i in range(4):
		_box(Vector3(-CELL_HALF + 0.14, y + 0.5, 0.48 + float(i) * 0.12), Vector3(0.12, 0.45, 0.05), "metal", false)
	# Проводка под потолком + табличка этажа
	_box(Vector3(CELL_HALF - 0.12, y + 2.35, 0.8), Vector3(0.04, 0.04, 3.2), "metal", false)
	_box(Vector3(CELL_HALF - 0.12, y + 1.7, -0.5), Vector3(0.06, 0.7, 0.06), "metal", false)
	_box(Vector3(0.0, y + 1.9, LAND_Z0 + 0.06), Vector3(0.22, 0.28, 0.03), "number", false)
	# Грязные углы + потёртости на зелёнке
	_box(Vector3(-CELL_HALF + 0.15, y + 0.03, LAND_Z0 + 0.2), Vector3(0.28, 0.05, 0.28), "dirt", false)
	_box(Vector3(CELL_HALF - 0.15, y + 0.03, LAND_Z0 + 0.2), Vector3(0.28, 0.05, 0.28), "dirt", false)
	_box(Vector3(-CELL_HALF + 0.06, y + 0.55, 1.4), Vector3(0.03, 0.7, 0.9), "dirt", false)
	_box(Vector3(CELL_HALF - 0.06, y + 0.4, 0.2), Vector3(0.03, 0.5, 0.6), "dirt", false)
	# Граффити на верхней половине стены
	_box(Vector3(-CELL_HALF + 0.04, y + 1.85, 0.6), Vector3(0.02, 0.25, 0.4), "graffiti", false)
	_box(Vector3(CELL_HALF - 0.04, y + 2.0, 1.5), Vector3(0.02, 0.18, 0.3), "graffiti", false)
	if floor_num % 2 == 0:
		_box(Vector3(CELL_HALF - 0.2, y + 1.15, 0.15), Vector3(0.28, 0.85, 0.14), "metal", false)
		_box(Vector3(CELL_HALF - 0.2, y + 1.2, 0.08), Vector3(0.22, 0.5, 0.02), "dirt", false)
		_box(Vector3(-CELL_HALF + 0.18, y + 1.4, 0.3), Vector3(0.02, 0.45, 0.35), "paper", false)
	# Пакет/хлам в углу площадки
	if floor_num % 3 == 1:
		_box(Vector3(CELL_HALF - 0.35, y + 0.12, LAND_Z0 + 0.35), Vector3(0.22, 0.2, 0.18), "prop", false)
	if has_elevator:
		# Тяжёлая дверь лифта с рядами глазков (реф Нижегородская)
		_box(Vector3(0.0, y + 1.05, LAND_Z0 - 0.02), Vector3(0.95, 2.05, 0.08), "metal", false)
		_box(Vector3(-0.22, y + 1.05, LAND_Z0 + 0.03), Vector3(0.4, 1.95, 0.05), "door_metal", false)
		_box(Vector3(0.22, y + 1.05, LAND_Z0 + 0.03), Vector3(0.4, 1.95, 0.05), "door_metal", false)
		for row in range(3):
			var ey := y + 1.25 + float(row) * 0.28
			_box(Vector3(-0.22, ey, LAND_Z0 + 0.08), Vector3(0.22, 0.08, 0.02), "glass", false)
			_box(Vector3(0.22, ey, LAND_Z0 + 0.08), Vector3(0.22, 0.08, 0.02), "glass", false)
		_box(Vector3(0.55, y + 1.75, LAND_Z0 + 0.08), Vector3(0.18, 0.14, 0.02), "number", false)

func _apt_door(pos: Vector3, num: int, on_back: bool = false) -> void:
	if on_back:
		_box(pos, Vector3(0.78, 2.0, 0.07), "door_apt", false)
		_box(pos + Vector3(0.0, 0.5, 0.05), Vector3(0.07, 0.07, 0.04), "metal", false)
		_box(pos + Vector3(0.25, 0.0, 0.05), Vector3(0.14, 0.1, 0.04), "metal", false)
		_box(pos + Vector3(-0.22, 0.62, 0.05), Vector3(0.22, 0.14, 0.02), "number", false)
	else:
		_box(pos, Vector3(0.07, 2.0, 0.78), "door_apt", false)

func _add_floor_light(y: float) -> void:
	# Голая лампочка на проводе — как в живом подъезде
	_box(Vector3(0.15, y + 2.55, 0.1), Vector3(0.02, 0.25, 0.02), "metal", false)
	_box(Vector3(0.15, y + 2.38, 0.1), Vector3(0.07, 0.1, 0.07), "lamp", false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.42)
	lamp.light_energy = 1.35
	lamp.omni_range = 4.6
	lamp.omni_attenuation = 2.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.15, y + 2.35, 0.1)
	add_child(lamp)
	lights.append(lamp)
	# Дневной свет от окна на mid — жёстче, с бликом
	var ml := OmniLight3D.new()
	ml.light_color = Color(0.92, 0.94, 1.0)
	ml.light_energy = 1.55
	ml.omni_range = 4.0
	ml.omni_attenuation = 1.35
	ml.position = Vector3(0, y - HALF_H + 1.9, 2.55)
	add_child(ml)
	lights.append(ml)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	spawn_pos = Vector3(-0.85, y + 0.2, -0.35)
	_box(Vector3(-0.85, y + 1.0, LAND_Z0 + 0.12), Vector3(0.82, 2.0, 0.08), "door", false)
	_box(Vector3(-0.85, y + 0.02, -0.7), Vector3(0.55, 0.03, 0.4), "prop", false)
	_box(Vector3(-1.05, y + 1.62, LAND_Z0 + 0.18), Vector3(0.22, 0.14, 0.02), "number", false)

func _build_yard(ice: bool, night: bool) -> void:
	var ground := "ice" if ice else "asphalt"
	_box(Vector3(0, -0.1, 12.0), Vector3(24.0, 0.3, 18.0), ground)
	# Бордюр + клок зелёнки у дома
	_box(Vector3(0, 0.02, 5.4), Vector3(8.0, 0.12, 0.35), "concrete", false)
	_box(Vector3(-3.5, 0.01, 6.2), Vector3(2.2, 0.06, 1.4), "grass", false)
	_box(Vector3(3.8, 0.01, 6.0), Vector3(1.8, 0.06, 1.1), "grass", false)
	_box(Vector3(2.2, 0.03, 11.5), Vector3(1.4, 0.02, 0.9), "puddle", false)
	# Фасад с швами
	_box(Vector3(-4.2, 8.5, DOOR_Z + 0.25), Vector3(6.6, 17.0, 0.28), "panel")
	_box(Vector3(4.2, 8.5, DOOR_Z + 0.25), Vector3(6.6, 17.0, 0.28), "panel")
	_box(Vector3(0, 9.8, DOOR_Z + 0.25), Vector3(1.7, 14.2, 0.28), "panel")
	for row in range(6):
		var sy := 1.35 + float(row) * FLOOR_H
		_box(Vector3(0, sy, DOOR_Z + 0.42), Vector3(14.0, 0.06, 0.05), "concrete", false)
	for col in range(5):
		var sx := -7.0 + float(col) * 3.5
		if absf(sx) < 1.0:
			continue
		_box(Vector3(sx, 8.0, DOOR_Z + 0.42), Vector3(0.06, 16.0, 0.05), "concrete", false)
	for row in range(6):
		for col in range(4):
			var wx := -5.5 + float(col) * 3.6
			if absf(wx) < 1.2:
				continue
			var wy := 1.5 + float(row) * FLOOR_H
			var kind := (row * 3 + col) % 5
			_box(Vector3(wx, wy, DOOR_Z + 0.38), Vector3(1.28, 1.42, 0.05), "metal", false)
			_box(Vector3(wx, wy - 0.72, DOOR_Z + 0.5), Vector3(1.35, 0.08, 0.22), "concrete", false)
			if kind == 0 and night:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "window_lit", false)
			elif kind == 1:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "curtain", false)
			else:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "glass", false)
			# Разные балконы (реф Северодонецк): кто во что горазд
			if kind == 2:
				_box(Vector3(wx, wy - 0.15, DOOR_Z + 0.85), Vector3(1.4, 1.1, 0.7), "balcony", false)
				_box(Vector3(wx, wy + 0.35, DOOR_Z + 0.85), Vector3(1.42, 0.08, 0.72), "metal", false)
			elif kind == 3:
				_box(Vector3(wx, wy - 0.2, DOOR_Z + 0.75), Vector3(1.35, 0.9, 0.55), "wood", false)
			elif kind == 4:
				_box(Vector3(wx, wy - 0.35, DOOR_Z + 0.7), Vector3(1.3, 0.08, 0.5), "concrete", false)
				_box(Vector3(wx - 0.55, wy - 0.05, DOOR_Z + 0.7), Vector3(0.05, 0.7, 0.5), "metal", false)
				_box(Vector3(wx + 0.55, wy - 0.05, DOOR_Z + 0.7), Vector3(0.05, 0.7, 0.5), "metal", false)
	# Провода с крыши (реф)
	for i in range(5):
		var wx := -6.0 + float(i) * 3.0
		_box(Vector3(wx, 15.2, DOOR_Z + 2.0 + float(i) * 0.4), Vector3(0.03, 0.03, 4.5 + float(i)), "metal", false)
	# Козырёк толще + пятна
	_box(Vector3(0, 2.45, 4.75), Vector3(3.4, 0.16, 2.4), "concrete")
	_box(Vector3(0, 2.38, 4.9), Vector3(3.0, 0.04, 2.0), "dirt", false)
	_box(Vector3(-1.35, 1.15, 4.7), Vector3(0.12, 2.3, 0.12), "metal")
	_box(Vector3(1.35, 1.15, 4.7), Vector3(0.12, 2.3, 0.12), "metal")
	_box(Vector3(0, -0.05, 4.55), Vector3(2.4, 0.18, 2.4), "concrete")
	_box(Vector3(0, 0.04, 6.6), Vector3(0.7, 0.03, 3.0), "mark", false)
	_box(Vector3(1.3, 0.04, 10.6), Vector3(0.7, 0.03, 4.0), "mark", false)
	_box(Vector3(3.3, 0.04, 13.9), Vector3(2.2, 0.03, 2.6), "mark", false)
	# Сухая трава у забора
	_box(Vector3(-6.5, 0.08, 10.0), Vector3(1.5, 0.12, 4.0), "grass", false)
	_box(Vector3(7.0, 0.08, 13.0), Vector3(1.2, 0.1, 3.0), "grass", false)
	# Забор — сетка на столбах, не сплошной блок
	for i in range(8):
		var fx := -9.5 + float(i) * 2.7
		_box(Vector3(fx, 0.7, 19.3), Vector3(0.1, 1.4, 0.1), "metal", false)
	_box(Vector3(0, 1.35, 19.3), Vector3(20.0, 0.05, 0.05), "metal", false)
	_box(Vector3(0, 0.35, 19.3), Vector3(20.0, 0.05, 0.05), "metal", false)
	_box(Vector3(-10.0, 0.7, 12.0), Vector3(0.12, 1.4, 16.0), "metal", false)
	_box(Vector3(10.0, 0.7, 12.0), Vector3(0.12, 1.4, 16.0), "metal", false)
	_box(Vector3(-4.8, 0.3, 8.2), Vector3(1.7, 0.09, 0.4), "wood")
	_box(Vector3(-5.35, 0.38, 8.2), Vector3(0.09, 0.35, 0.35), "wood")
	_box(Vector3(-4.25, 0.38, 8.2), Vector3(0.09, 0.35, 0.35), "wood")
	_box(Vector3(-3.2, 0.4, 7.5), Vector3(0.32, 0.65, 0.32), "metal", false)
	# Фонарный столб
	_box(Vector3(-1.8, 2.0, 7.2), Vector3(0.12, 4.0, 0.12), "metal", false)
	_box(Vector3(-1.8, 4.05, 7.5), Vector3(0.5, 0.08, 0.08), "metal", false)
	_box(Vector3(-1.8, 3.95, 7.7), Vector3(0.28, 0.18, 0.28), "lamp" if night else "metal", false)
	_box(Vector3(6.8, 1.15, 11.5), Vector3(0.1, 2.2, 0.1), "metal")
	_box(Vector3(7.55, 1.15, 11.5), Vector3(0.1, 2.2, 0.1), "metal")
	_box(Vector3(7.15, 2.25, 11.5), Vector3(0.95, 0.07, 0.07), "metal", false)
	_box(Vector3(3.5, 0.65, 16.1), Vector3(4.3, 1.2, 0.1), "metal")
	_box(Vector3(1.45, 0.65, 14.5), Vector3(0.1, 1.2, 3.3), "metal")
	_box(Vector3(5.55, 0.65, 14.5), Vector3(0.1, 1.2, 3.3), "metal")
	if ice:
		_box(Vector3(0, 0.02, 9.0), Vector3(3.0, 0.05, 1.0), "ice")
		yard_ice_zones.append(Rect2(Vector2(-7, 7), Vector2(14, 10)))
	# Дневной fill у помойки + ночной фонарь
	var yl := OmniLight3D.new()
	yl.light_color = Color(1.0, 0.82, 0.5) if night else Color(0.95, 0.94, 0.9)
	yl.light_energy = 2.2 if night else 1.1
	yl.omni_range = 12.0 if night else 10.0
	yl.omni_attenuation = 1.4
	yl.shadow_enabled = night
	yl.position = Vector3(-1.8, 3.9, 7.7)
	add_child(yl)
	if night:
		lights.append(yl)
	if not night:
		var dump_fill := OmniLight3D.new()
		dump_fill.light_color = Color(0.95, 0.93, 0.88)
		dump_fill.light_energy = 0.85
		dump_fill.omni_range = 7.0
		dump_fill.omni_attenuation = 1.2
		dump_fill.position = Vector3(3.7, 3.2, 13.5)
		add_child(dump_fill)

func _build_detour_path() -> void:
	_box(Vector3(-7.0, -0.05, 11.0), Vector3(2.2, 0.12, 10.0), "asphalt")
	_box(Vector3(-7.0, 0.04, 15.0), Vector3(0.5, 0.06, 0.5), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(0.9, -FLOOR_H + 0.35, 1.0), Vector3(0.22, 0.22, 2.0), "metal")
	_box(Vector3(-0.8, -FLOOR_H + 0.12, 1.8), Vector3(0.9, 0.05, 0.9), "ice")

func _build_dumpster() -> void:
	# Контейнерная площадка: 3 бака + низкий забор + мусор вокруг (реф двор)
	_box(Vector3(3.7, 0.55, 15.5), Vector3(4.6, 1.0, 0.08), "metal", false)
	_box(Vector3(1.5, 0.55, 14.5), Vector3(0.08, 1.0, 2.2), "metal", false)
	_box(Vector3(5.9, 0.55, 14.5), Vector3(0.08, 1.0, 2.2), "metal", false)
	for i in range(5):
		_box(Vector3(1.9 + float(i) * 0.95, 0.95, 15.5), Vector3(0.05, 0.9, 0.05), "metal", false)
	for i in range(3):
		var dx := 2.6 + float(i) * 1.15
		_box(Vector3(dx, 0.7, 14.6), Vector3(1.0, 1.35, 1.15), "dumpster")
		_box(Vector3(dx, 0.7, 14.05), Vector3(0.95, 1.2, 0.04), "rust", false)
		_box(Vector3(dx - 0.48, 0.7, 14.6), Vector3(0.04, 1.2, 1.05), "rust", false)
		_box(Vector3(dx + 0.48, 0.7, 14.6), Vector3(0.04, 1.2, 1.05), "rust", false)
		_box(Vector3(dx, 1.42, 14.55), Vector3(1.08, 0.1, 1.22), "metal", false)
		_box(Vector3(dx + 0.15, 1.48, 14.55), Vector3(0.35, 0.06, 0.2), "rust", false)
		# Граффити на крышке
		if i == 1:
			_box(Vector3(dx, 1.5, 14.4), Vector3(0.4, 0.02, 0.25), "graffiti", false)
		_box(Vector3(dx - 0.35, 0.1, 15.05), Vector3(0.14, 0.14, 0.08), "metal", false)
		_box(Vector3(dx + 0.35, 0.1, 15.05), Vector3(0.14, 0.14, 0.08), "metal", false)
		_box(Vector3(dx - 0.35, 0.1, 14.15), Vector3(0.14, 0.14, 0.08), "metal", false)
		_box(Vector3(dx + 0.35, 0.1, 14.15), Vector3(0.14, 0.14, 0.08), "metal", false)
	_box(Vector3(3.7, 0.03, 13.8), Vector3(2.8, 0.02, 1.2), "puddle", false)
	_box(Vector3(2.4, 0.08, 13.5), Vector3(0.25, 0.08, 0.2), "dirt", false)
	_box(Vector3(4.8, 0.1, 15.2), Vector3(0.35, 0.12, 0.25), "prop", false)
	_box(Vector3(3.2, 0.15, 13.3), Vector3(0.4, 0.2, 0.3), "prop", false)
	# Табличка на заборе площадки, не «в воздухе»
	_box(Vector3(3.7, 1.35, 15.55), Vector3(0.9, 0.28, 0.04), "number", false)
	dumpster = Area3D.new()
	dumpster.name = "Dumpster"
	dumpster.collision_layer = 0
	dumpster.collision_mask = 2 | 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.2, 2.4, 3.2)
	cs.shape = sh
	dumpster.add_child(cs)
	dumpster.position = Vector3(3.7, 1.0, 14.6)
	add_child(dumpster)

func _build_elevator(floors: int) -> void:
	var start_f: int = int(_level.get("start_floor", floors))
	var y := float(start_f) * FLOOR_H
	_box(Vector3(0.0, floors * FLOOR_H * 0.5, LAND_Z0 - 0.45), Vector3(1.05, floors * FLOOR_H + 0.4, 0.55), "metal")
	elevator_area = Area3D.new()
	elevator_area.name = "Elevator"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.1, 0.9)
	cs.shape = sh
	elevator_area.add_child(cs)
	elevator_area.position = Vector3(0.0, y + 1.0, LAND_Z0 + 0.15)
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
	p.set_look_yaw(PI - 0.35)  # лицом к правому маршу (+Z)
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = spawn_pos + Vector3(0.25, 0.55, 0.2)
	bag = trash

func _build_level_flavor() -> void:
	## Уникальные маркеры уровней (ТЗ LVL-*-ART) — без неоновых меток.
	var id: int = int(_level.get("id", 1))
	# Номер подъезда у входа
	_box(Vector3(CELL_HALF - 0.2, 2.05, DOOR_Z - 0.05), Vector3(0.28, 0.35, 0.04), "number", false)
	match id:
		1:
			# Веник/совок у двери — «мама выставила»
			_box(Vector3(CELL_HALF - 0.25, 0.55, -0.3), Vector3(0.06, 1.0, 0.06), "wood", false)
			_box(Vector3(CELL_HALF - 0.25, 0.08, -0.15), Vector3(0.25, 0.04, 0.18), "metal", false)
		2:
			# Острый угол трубы — урок thin
			_box(Vector3(-CELL_HALF + 0.15, 1.1, 0.9), Vector3(0.12, 0.12, 0.9), "metal", false)
			_box(Vector3(-CELL_HALF + 0.15, 1.1, 1.35), Vector3(0.18, 0.18, 0.08), "metal", false)
		3, 4:
			# Табличка «Лифт» / этажность
			_box(Vector3(0.55, float(int(_level.get("start_floor", 9))) * FLOOR_H + 1.9, LAND_Z0 + 0.2), Vector3(0.35, 0.2, 0.03), "number", false)
		5:
			# Мигающий уже через light_timer; доп. провод
			_box(Vector3(0.0, FLOOR_H * 3.0 + 2.3, 0.5), Vector3(2.5, 0.04, 0.04), "metal", false)
		6:
			_box(Vector3(-0.8, -FLOOR_H + 0.4, 1.5), Vector3(0.3, 0.3, 1.5), "metal", false)
		7, 8:
			_box(Vector3(2.0, 0.05, 8.5), Vector3(1.2, 0.04, 2.5), "ice", false)
		9:
			_box(Vector3(0.5, 0.55, 11.0), Vector3(1.2, 1.0, 0.08), "metal", false)  # заборчик к собакам
		_:
			_box(Vector3(-5.5, 0.9, 10.0), Vector3(0.5, 1.6, 0.5), "prop", false)

func set_light_flicker(enabled: bool, period: float) -> void:
	if not enabled:
		return
	for lamp in lights:
		if lamp is OmniLight3D:
			var base_e: float = (lamp as OmniLight3D).light_energy
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "light_energy", base_e * 0.25, period * 0.5)
			tw.tween_property(lamp, "light_energy", base_e, period * 0.5)

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
		return "К контейнерам во дворе" if lang == "ru" else "To the yard dumpsters"
	if player_pos.y < 1.3 and player_pos.z > 2.4:
		return "На улицу через открытую дверь" if lang == "ru" else "Outside through the open door"
	var near_mid := player_pos.z > 2.0 and player_pos.z < 2.9 and fmod(player_pos.y + 0.35, FLOOR_H) > HALF_H - 0.55 and fmod(player_pos.y + 0.35, FLOOR_H) < HALF_H + 0.55
	if near_mid:
		return "Разворот — левый марш вниз" if lang == "ru" else "Turn — left flight down"
	if lang == "ru":
		return "Вниз по правому маршу к окну"
	return "Down the right flight toward the window"
