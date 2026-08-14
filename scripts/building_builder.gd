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
## Промежуточная — хватит развернуться с капсулой 0.56 м
const MID_Z0 := 2.15
const MID_Z1 := 3.05
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
		_build_basement_exit()
	_spawn_npcs(level)
	_spawn_player_and_bag(start_floor, level)
	_build_level_flavor()
	# Только гул подъезда — музыка позже из game.gd
	Svc.audio().play_ambient()

func _make_materials() -> void:
	## PBR из assets/pbr (ambientCG, CC0). Цвет задаётся тинтом поверх серой
	## albedo: краска по штукатурке, грязь по плитке, зелень по контейнерам.
	var style: String = str(_level.get("style", "khrushchev"))
	var wall_up := Color(0.66, 0.64, 0.58)      # известка, потемневшая от времени
	var wall_low := Color(0.25, 0.37, 0.34)     # зелёнка-бирюза, масляная краска
	var tile_c := Color(0.48, 0.45, 0.41)       # затёртая плитка площадок
	var panel_c := Color(0.58, 0.56, 0.53)      # серая панель фасада
	match style:
		"brezhnev":
			wall_up = Color(0.68, 0.66, 0.63)
			wall_low = Color(0.21, 0.32, 0.40)
			panel_c = Color(0.56, 0.58, 0.60)
		"courtyard":
			wall_up = Color(0.66, 0.61, 0.53)
			wall_low = Color(0.40, 0.32, 0.23)
			panel_c = Color(0.62, 0.57, 0.48)
		_:
			pass
	_mats["wall"] = MaterialLibrary.pbr("plaster_white", {"tint": wall_up, "rough": 1.0, "normal_scale": 0.8, "fallback": wall_up})
	_mats["wainscot"] = MaterialLibrary.pbr("plaster_paint", {"tint": wall_low, "rough": 0.72, "metal": 0.0, "normal_scale": 0.6, "fallback": wall_low})
	_mats["tile"] = MaterialLibrary.pbr("tiles_landing", {"tint": tile_c, "rough": 0.95, "tile_m": 1.15, "fallback": tile_c})
	_mats["concrete"] = MaterialLibrary.pbr("concrete_wall", {"tint": Color(0.58, 0.56, 0.53), "fallback": Color(0.70, 0.68, 0.64)})
	_mats["step"] = MaterialLibrary.pbr("concrete_floor", {"tint": Color(0.70, 0.66, 0.57), "tile_m": 1.4, "fallback": Color(0.72, 0.68, 0.58)})
	_mats["step_paint"] = MaterialLibrary.pbr("plaster_paint", {"tint": Color(0.30, 0.38, 0.30), "rough": 0.72, "tile_m": 1.2, "fallback": Color(0.30, 0.38, 0.30)})
	_mats["panel"] = MaterialLibrary.pbr("concrete_wall", {"tint": panel_c, "tile_m": 2.6, "normal_scale": 0.85, "fallback": panel_c})
	_mats["bricks"] = MaterialLibrary.pbr("bricks", {"tint": Color(0.82, 0.72, 0.64), "fallback": Color(0.60, 0.42, 0.34)})
	_mats["asphalt"] = MaterialLibrary.pbr("asphalt", {"tint": Color(0.42, 0.42, 0.42), "fallback": Color(0.20, 0.20, 0.19)})
	_mats["road"] = MaterialLibrary.pbr("road", {"tint": Color(0.46, 0.46, 0.46), "fallback": Color(0.17, 0.17, 0.16)})
	_mats["gravel"] = MaterialLibrary.pbr("gravel", {"tint": Color(0.66, 0.64, 0.61), "fallback": Color(0.32, 0.31, 0.29)})
	_mats["ground_dirt"] = MaterialLibrary.pbr("ground_dirt", {"tint": Color(0.68, 0.64, 0.58), "fallback": Color(0.28, 0.24, 0.18)})
	_mats["grass"] = MaterialLibrary.pbr("grass", {"tint": Color(0.60, 0.64, 0.46), "tile_m": 1.6, "fallback": Color(0.30, 0.36, 0.16)})
	_mats["ice"] = MaterialLibrary.pbr("ice", {"tint": Color(0.82, 0.88, 0.92), "rough": 0.85, "fallback": Color(0.72, 0.80, 0.85)})
	_mats["snow"] = MaterialLibrary.pbr("snow", {"tint": Color(0.95, 0.96, 1.0), "fallback": Color(0.88, 0.90, 0.94)})
	_mats["carpet"] = MaterialLibrary.pbr("carpet", {"tint": Color(0.52, 0.34, 0.28), "tile_m": 0.8, "fallback": Color(0.42, 0.26, 0.20)})
	_mats["wool"] = _mats["carpet"]
	# Металл: крашеный (перила, скобы), ржавый (петли, потёки), сталь (двери)
	_mats["metal"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.30, 0.31, 0.33), "metal": 0.75, "rough": 0.80, "tile_m": 0.7, "normal_scale": 0.7, "fallback": Color(0.22, 0.23, 0.24)})
	_mats["rail"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.22, 0.23, 0.25), "metal": 0.70, "rough": 0.68, "tile_m": 0.6, "fallback": Color(0.18, 0.18, 0.19)})
	_mats["handrail"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.34, 0.12, 0.10), "metal": 0.15, "rough": 0.52, "tile_m": 0.9, "fallback": Color(0.34, 0.12, 0.10)})
	_mats["rust"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.58, 0.33, 0.18), "metal": 0.45, "rough": 1.0, "tile_m": 0.8, "fallback": Color(0.42, 0.22, 0.10)})
	_mats["steel"] = MaterialLibrary.pbr("steel_corrugated", {"tint": Color(0.46, 0.47, 0.48), "metal": 1.0, "rough": 0.85, "tile_m": 1.2, "fallback": Color(0.32, 0.33, 0.34)})
	_mats["door_metal"] = MaterialLibrary.pbr("steel_corrugated", {"tint": Color(0.34, 0.33, 0.31), "metal": 0.90, "rough": 0.90, "tile_m": 1.0, "fallback": Color(0.26, 0.25, 0.24)})
	_mats["dumpster"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.26, 0.42, 0.26), "metal": 0.35, "rough": 0.72, "tile_m": 1.1, "fallback": Color(0.20, 0.34, 0.20)})
	_mats["dumpster_rust"] = _mats["rust"]
	_mats["mail"] = MaterialLibrary.pbr("metal_painted", {"tint": Color(0.26, 0.34, 0.36), "metal": 0.50, "rough": 0.65, "tile_m": 0.8, "fallback": Color(0.22, 0.30, 0.32)})
	# Дерево: квартирные двери, лавка, черенок веника
	_mats["door_apt"] = MaterialLibrary.pbr("wood_door", {"tint": Color(0.44, 0.30, 0.19), "rough": 0.75, "tile_m": 1.1, "fallback": Color(0.50, 0.36, 0.22)})
	_mats["door"] = MaterialLibrary.pbr("wood_door", {"tint": Color(0.38, 0.26, 0.17), "rough": 0.80, "tile_m": 1.1, "fallback": Color(0.44, 0.30, 0.18)})
	_mats["wood"] = MaterialLibrary.pbr("wood_door", {"tint": Color(0.34, 0.24, 0.15), "rough": 0.90, "tile_m": 0.9, "fallback": Color(0.34, 0.22, 0.12)})
	# Рисованные карты — там важен сам рисунок, а не микрорельеф
	_mats["graffiti"] = MaterialLibrary.painted("res://assets/textures/graffiti.png", Color(1, 1, 1), Vector3.ONE, 0.95)
	_mats["paper"] = MaterialLibrary.painted("res://assets/textures/paper_notice.png", Color(0.95, 0.93, 0.86), Vector3.ONE, 0.92)
	_mats["number"] = MaterialLibrary.flat(Color(0.62, 0.60, 0.50), 0.80)
	# Мелочь и полупрозрачное
	_mats["glass"] = MaterialLibrary.flat(Color(0.16, 0.20, 0.23), 0.12, 0.35, 0.55)
	_mats["mark"] = MaterialLibrary.flat(Color(0.14, 0.12, 0.10), 0.98, 0.0, 0.40)
	_mats["prop"] = MaterialLibrary.flat(Color(0.20, 0.19, 0.17), 0.90)
	_mats["dirt"] = MaterialLibrary.flat(Color(0.10, 0.09, 0.07), 1.0, 0.0, 0.50)
	_mats["curtain"] = MaterialLibrary.flat(Color(0.38, 0.26, 0.21), 0.95)
	_mats["panel_far"] = MaterialLibrary.pbr("concrete_wall", {"tint": Color(0.34, 0.34, 0.35), "tile_m": 3.2, "normal_scale": 0.4, "fallback": Color(0.34, 0.34, 0.35)})
	_mats["balcony"] = MaterialLibrary.pbr("concrete_wall", {"tint": Color(0.66, 0.65, 0.62), "tile_m": 1.4, "fallback": Color(0.62, 0.62, 0.60)})
	_mats["puddle"] = MaterialLibrary.flat(Color(0.06, 0.07, 0.08), 0.06, 0.20, 0.72)
	_mats["lamp"] = MaterialLibrary.emissive(Color(1.0, 0.90, 0.62), 3.0, Color(1.0, 0.76, 0.34))
	_mats["window_lit"] = MaterialLibrary.emissive(Color(0.95, 0.86, 0.60), 1.5, Color(1.0, 0.82, 0.45))

func _sky_hdri(night: bool) -> String:
	## Пасмурный городской день — базовый вид панельки; солнце оставлено
	## дворовым уровням, чтобы серия не выглядела снятой в один час.
	if night:
		return "res://assets/hdri/preller_drive_1k.hdr"
	if str(_level.get("style", "")) == "courtyard" and not bool(_level.get("ice", false)):
		return "res://assets/hdri/abandoned_parking_1k.hdr"
	return "res://assets/hdri/potsdamer_platz_2k.hdr"

func _add_world_env(night: bool) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var hdri := _sky_hdri(night)
	if ResourceLoader.exists(hdri):
		# HDRI даёт и небо, и заполняющий свет с настоящим распределением яркости
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(hdri)
		pano.energy_multiplier = 0.7 if night else 1.0
		sky.sky_material = pano
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
		env.ambient_light_energy = 0.28 if night else 0.42
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		if night:
			sky_mat.sky_top_color = Color(0.04, 0.05, 0.09)
			sky_mat.sky_horizon_color = Color(0.12, 0.11, 0.14)
			sky_mat.ground_horizon_color = Color(0.08, 0.07, 0.07)
			sky_mat.sky_energy_multiplier = 0.55
		else:
			sky_mat.sky_top_color = Color(0.38, 0.55, 0.78)
			sky_mat.sky_horizon_color = Color(0.70, 0.76, 0.82)
			sky_mat.ground_horizon_color = Color(0.42, 0.40, 0.36)
			sky_mat.sky_energy_multiplier = 1.05
		sky.sky_material = sky_mat
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.32, 0.30, 0.26) if night else Color(0.55, 0.52, 0.46)
		env.ambient_light_energy = 0.45 if night else 0.58
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(-115.0), 0)

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.10, 0.11, 0.14) if night else Color(0.62, 0.64, 0.66)
	env.fog_light_energy = 0.7 if night else 1.0
	env.fog_density = 0.012 if night else 0.004
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.5

	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	if forward_plus:
		# Контактные тени и переотражённый цвет: без них PBR читается как наклейки
		env.ssao_enabled = true
		env.ssao_radius = 1.1
		env.ssao_intensity = 2.6
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.15
		env.ssao_ao_channel_affect = 0.35
		env.ssil_enabled = true
		env.ssil_radius = 3.5
		env.ssil_intensity = 1.1
		env.ssil_normal_rejection = 1.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.028 if night else 0.014
		env.volumetric_fog_albedo = Color(0.82, 0.82, 0.86)
		env.volumetric_fog_emission = Color(0.02, 0.02, 0.03)
		env.volumetric_fog_anisotropy = 0.25
		env.volumetric_fog_length = 45.0
		env.volumetric_fog_gi_inject = 0.6
		env.volumetric_fog_ambient_inject = 0.35
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_strength = 0.9
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.94
	env.adjustment_contrast = 1.05
	# AgX держит пересветы окна и лампы, не выжигая их в белое пятно
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1 if night else 0.95
	env.tonemap_white = 6.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.25 if night else 1.35
	sun.light_color = Color(0.62, 0.70, 0.92) if night else Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.6
	# Угловой размер источника: пасмурное небо = широкая мягкая тень
	sun.light_angular_distance = 3.5 if night else 1.6
	# Два сплита вместо четырёх: каждый сплит — это ещё один проход по сцене
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_split_1 = 0.12
	sun.rotation_degrees = Vector3(-32, 42, 0) if night else Vector3(-38, 55, 0)
	add_child(sun)

	if forward_plus:
		var rp_cell := ReflectionProbe.new()
		rp_cell.size = Vector3(4.2, 12.0, 6.5)
		rp_cell.position = Vector3(0, 4.0, 1.2)
		rp_cell.update_mode = ReflectionProbe.UPDATE_ONCE
		rp_cell.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		rp_cell.box_projection = true
		rp_cell.intensity = 0.8
		add_child(rp_cell)
		var rp_yard := ReflectionProbe.new()
		rp_yard.size = Vector3(18.0, 8.0, 16.0)
		rp_yard.position = Vector3(0, 2.5, 10.0)
		rp_yard.update_mode = ReflectionProbe.UPDATE_ONCE
		rp_yard.box_projection = true
		add_child(rp_yard)

func _box(pos: Vector3, size: Vector3, mat_key: String, with_collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if with_collision else 0
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = Geo.rounded_box(size)
	mi.material_override = _mats[mat_key]
	body.add_child(mi)
	if with_collision:
		# Коллизия остаётся честным боксом исходного размера — фаска только визуал
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
	body.position = pos
	add_child(body)
	return body

func _vis(pos: Vector3, size: Vector3, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Geo.rounded_box(size)
	mi.material_override = _mats[mat_key]
	mi.position = pos
	add_child(mi)
	return mi

func _mesh_at(mesh: Mesh, pos: Vector3, mat_key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats[mat_key]
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi

func _cyl(pos: Vector3, r: float, h: float, mat_key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh_at(Geo.pipe(r, h), pos, mat_key, rot)

## Пачка одинаковых мелких деталей одним вызовом отрисовки: прутья, балясины,
## рёбра радиатора. На Forward+ с тенями это заметно дешевле, чем N инстансов.
func _multi(mesh: Mesh, mat_key: String, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mats[mat_key]
	add_child(mmi)
	return mmi

func _sph(pos: Vector3, radius: float, mat_key: String) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return _mesh_at(sm, pos, mat_key)

func _hide_mesh(body: StaticBody3D) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false

func _dress_rail(center: Vector3, width: float, tall: float, along_x: bool) -> void:
	var n := 7
	var posts: Array = []
	for i in range(n):
		var t := (float(i) + 0.5) / float(n)
		var off := lerpf(-width * 0.45, width * 0.45, t)
		posts.append(Transform3D(Basis.IDENTITY, center + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))))
	_multi(Geo.pipe(0.015, tall, 10), "rail", posts)
	var rot := Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
	_mesh_at(Geo.pipe(0.024, width * 0.96), center + Vector3(0, tall * 0.42, 0), "handrail", rot)
	_mesh_at(Geo.pipe(0.012, width * 0.94), center + Vector3(0, -tall * 0.12, 0), "rail", rot)

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
	# Потолок тамбура — не наезжает на промежуточную площадку
	_box(Vector3(0, FLOOR_H - 0.14, 3.55), Vector3(CELL_W - 0.1, 0.12, 0.7), "concrete")

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
		var wy := mid_y + 1.1
		# Проём с откосами, подоконником и отливом — окно перестаёт быть наклейкой
		_mesh_at(Geo.window_reveal(0.95, 1.15, 0.16, 0.16), Vector3(0, wy, DOOR_Z - 0.06), "concrete")
		_box(Vector3(0, wy, DOOR_Z - 0.03), Vector3(0.95, 1.15, 0.02), "glass", false)
		# Деревянный переплёт: две створки с форточкой
		_vis(Vector3(0, wy, DOOR_Z - 0.05), Vector3(0.045, 1.15, 0.05), "wood")
		_vis(Vector3(0, wy + 0.32, DOOR_Z - 0.05), Vector3(0.95, 0.04, 0.05), "wood")
		_vis(Vector3(0, wy - 0.575, DOOR_Z - 0.05), Vector3(0.99, 0.05, 0.06), "wood")
		_vis(Vector3(0, wy + 0.575, DOOR_Z - 0.05), Vector3(0.99, 0.05, 0.06), "wood")
		_box(Vector3(-0.3, wy + 0.05, DOOR_Z + 0.01), Vector3(0.22, 0.3, 0.01), "paper", false)

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
	slit.light_color = Color(0.82, 0.88, 1.0)
	slit.light_energy = 1.5
	slit.omni_range = 3.6
	slit.omni_attenuation = 1.5
	slit.position = Vector3(0.15, 1.1, DOOR_Z + 0.35)
	_tune_light(slit, false, 16.0)
	add_child(slit)
	# Светильник в решётке над входом
	var sconce := PropLibrary.spawn(self, "industrial_caged_sconce", Vector3(0.0, 2.34, DOOR_Z + 0.16), Vector3(0, 180, 0), 1.0, 0.34)
	if sconce == null:
		_box(Vector3(0, 2.35, DOOR_Z + 0.55), Vector3(0.35, 0.08, 0.35), "metal", false)
	_box(Vector3(0, 2.26, DOOR_Z + 0.30), Vector3(0.14, 0.04, 0.14), "lamp", false)
	# Хлам в тамбуре: урна, коробка, ящик
	PropLibrary.spawn(self, "metal_trash_can", Vector3(CELL_HALF - 0.34, 0.0, 3.25), Vector3(0, -40, 0), 1.0, 0.72)
	PropLibrary.spawn(self, "cardboard_box_01", Vector3(-CELL_HALF + 0.38, 0.0, 2.92), Vector3(0, 24, 0), 1.0, 0.34)
	PropLibrary.spawn(self, "plastic_crate_01", Vector3(-CELL_HALF + 0.36, 0.0, 2.35), Vector3(0, -12, 0), 1.0, 0.27)
	var el := OmniLight3D.new()
	el.light_color = Color(1.0, 0.78, 0.44)
	el.light_energy = 1.5
	el.omni_range = 5.0
	el.omni_attenuation = 1.8
	el.position = Vector3(0, 2.25, DOOR_Z + 0.55)
	_tune_light(el, true, 14.0)
	add_child(el)
	lights.append(el)

func _add_ground_mailboxes() -> void:
	for i in range(4):
		var bx := -1.05 + float(i) * 0.52
		_box(Vector3(bx, 1.0, LAND_Z0 + 0.08), Vector3(0.46, 0.9, 0.12), "mail", false)
		_vis(Vector3(bx, 1.18, LAND_Z0 + 0.15), Vector3(0.28, 0.025, 0.02), "metal")
		_cyl(Vector3(bx + 0.14, 0.82, LAND_Z0 + 0.15), 0.01, 0.03, "metal", Vector3(90, 0, 0))
		_vis(Vector3(bx - 0.12, 1.28, LAND_Z0 + 0.15), Vector3(0.10, 0.08, 0.01), "paper")

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
		_add_shaft_guard(y)

func _add_shaft_guard(y: float) -> void:
	## Перила по кромке площадки: проём только у правого марша вниз.
	var open_x := STAIR_X
	var open_w := STAIR_W + 0.14
	var z := LAND_Z1 + 0.03
	var left_end := open_x - open_w * 0.5
	var right_start := open_x + open_w * 0.5
	var left_w := left_end - (-CELL_HALF + 0.08)
	if left_w > 0.18:
		var lb := _box(Vector3(-CELL_HALF + 0.08 + left_w * 0.5, y + 0.5, z), Vector3(left_w, 1.0, 0.08), "metal", true)
		_hide_mesh(lb)
		_dress_rail(Vector3(-CELL_HALF + 0.08 + left_w * 0.5, y + 0.5, z), left_w, 0.92, true)
	var right_w := (CELL_HALF - 0.08) - right_start
	if right_w > 0.18:
		var rb := _box(Vector3(right_start + right_w * 0.5, y + 0.5, z), Vector3(right_w, 1.0, 0.08), "metal", true)
		_hide_mesh(rb)
		_dress_rail(Vector3(right_start + right_w * 0.5, y + 0.5, z), right_w, 0.92, true)

func _add_mid_landing(y: float) -> void:
	var depth := MID_Z1 - MID_Z0
	var zc := (MID_Z0 + MID_Z1) * 0.5
	_box(Vector3(0, y - 0.1, zc), Vector3(CELL_W - 0.15, 0.2, depth), "tile")
	_box(Vector3(0, y + 0.05, MID_Z0 - 0.06), Vector3(0.7, 0.1, 0.05), "rail")
	var front := _box(Vector3(0, y + 0.55, MID_Z1), Vector3(CELL_W - 0.25, 1.05, 0.07), "metal", true)
	_hide_mesh(front)
	_dress_rail(Vector3(0, y + 0.55, MID_Z1), CELL_W - 0.25, 0.95, true)
	var sl := _box(Vector3(-1.2, y + 0.55, zc), Vector3(0.08, 1.0, depth * 0.9), "metal", true)
	var sr := _box(Vector3(1.2, y + 0.55, zc), Vector3(0.08, 1.0, depth * 0.9), "metal", true)
	_hide_mesh(sl)
	_hide_mesh(sr)
	_dress_rail(Vector3(-1.2, y + 0.55, zc), depth * 0.9, 0.9, false)
	_dress_rail(Vector3(1.2, y + 0.55, zc), depth * 0.9, 0.9, false)

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

	var steps := 9
	var z_dir := 1.0 if z1 > z0 else -1.0
	var wall_side := 1.0 if not left else -1.0
	var tread_w := STAIR_W - 0.08
	var tread_d := run / float(steps)
	var riser := rise / float(steps)
	var step_mesh := Geo.stair_step(tread_w, tread_d, riser + 0.02)
	var paint_x: Array = []
	var dirt_x: Array = []
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var y := lerpf(y_top, y_bot, t)
		var z := lerpf(z0, z1, t)
		# Ступень одним мешем: проступь со свесом + подступёнок, фаска по кромке
		var mi := _mesh_at(step_mesh, Vector3(x, y, z), "step")
		mi.rotation_degrees.y = 0.0 if z_dir > 0.0 else 180.0
		# Затёртая до бетона середина и остатки краски по краям — как в подъезде
		var top_y := y + (riser + 0.02) * 0.5 + 0.003
		dirt_x.append(Transform3D(Basis.IDENTITY, Vector3(x, top_y, z - z_dir * 0.01)))
		paint_x.append(Transform3D(Basis.IDENTITY, Vector3(x + tread_w * 0.5 - 0.07, top_y, z)))
		paint_x.append(Transform3D(Basis.IDENTITY, Vector3(x - tread_w * 0.5 + 0.07, top_y, z)))
	_multi(Geo.rounded_box(Vector3(0.13, 0.008, tread_d * 0.92), 0.003), "step_paint", paint_x)
	_multi(Geo.rounded_box(Vector3(tread_w * 0.55, 0.006, tread_d * 0.6), 0.002), "dirt", dirt_x)
	# Косоур: крашеная боковина марша вдоль стены
	var side_len := length
	var side := _mesh_at(Geo.rounded_box(Vector3(0.06, 0.34, side_len), 0.008),
		Vector3(x + wall_side * (tread_w * 0.5 + 0.03), (y_top + y_bot) * 0.5 - 0.12, (z0 + z1) * 0.5), "step_paint")
	side.rotation.x = angle

	_box(Vector3(x, y_top - 0.02, z0 + (0.1 if z1 > z0 else -0.1)), Vector3(STAIR_W - 0.06, 0.09, 0.28), "concrete", false)
	_box(Vector3(x, y_bot + 0.02, z1 + (-0.1 if z1 > z0 else 0.1)), Vector3(STAIR_W - 0.06, 0.09, 0.28), "concrete", false)

	# Перила: круглый бордовый поручень на трубчатых стойках
	var rail_x := x + (STAIR_W * 0.46 if not left else -STAIR_W * 0.46)
	var rail := StaticBody3D.new()
	rail.collision_layer = 1
	var rcs := CollisionShape3D.new()
	var rsh := BoxShape3D.new()
	rsh.size = Vector3(0.05, 0.85, length * 0.92)
	rcs.shape = rsh
	rail.add_child(rcs)
	var rmi := MeshInstance3D.new()
	rmi.mesh = Geo.pipe(0.024, length * 0.92)
	rmi.material_override = _mats["handrail"]
	rmi.position.y = 0.44
	rmi.rotation_degrees.x = 90.0
	rail.add_child(rmi)
	var low := MeshInstance3D.new()
	low.mesh = Geo.pipe(0.014, length * 0.9)
	low.material_override = _mats["metal"]
	low.position.y = -0.06
	low.rotation_degrees.x = 90.0
	rail.add_child(low)
	rail.position = Vector3(rail_x, (y_top + y_bot) * 0.5 + 0.42, (z0 + z1) * 0.5)
	rail.rotation.x = angle
	add_child(rail)

	var balusters: Array = []
	var brackets: Array = []
	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var sy := lerpf(y_top, y_bot, t) + 0.4
		var sz := lerpf(z0, z1, t)
		balusters.append(Transform3D(Basis.IDENTITY, Vector3(rail_x, sy, sz)))
		brackets.append(Transform3D(Basis.IDENTITY, Vector3(rail_x + wall_side * 0.11, sy + 0.25, sz)))
	_multi(Geo.pipe(0.013, 0.78, 10), "rail", balusters)
	_multi(Geo.rounded_box(Vector3(0.15, 0.022, 0.022), 0.004), "rail", brackets)

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
	_vis(Vector3(0, y + h, 1.15), Vector3(CELL_W - 0.14, 0.035, 4.65), "concrete")
	_box(Vector3(-CELL_HALF + 0.04, y + 0.04, 1.15), Vector3(0.06, 0.08, 4.6), "concrete", false)
	_box(Vector3(CELL_HALF - 0.04, y + 0.04, 1.15), Vector3(0.06, 0.08, 4.6), "concrete", false)
	_box(Vector3(0, y + 0.04, LAND_Z0 + 0.04), Vector3(CELL_W - 0.2, 0.08, 0.06), "concrete", false)

func _add_floor_props(y: float, floor_num: int, has_elevator: bool) -> void:
	# Две двери на ЗАДНЕЙ стене — как в клетке, не «коридор»
	_apt_door(Vector3(-0.85, y + 1.0, LAND_Z0 + 0.1), floor_num * 2 - 1, true)
	_apt_door(Vector3(0.85, y + 1.0, LAND_Z0 + 0.1), floor_num * 2, true)
	# Батарея у боковой стены
	_box(Vector3(-CELL_HALF + 0.12, y + 0.5, 0.7), Vector3(0.1, 0.5, 0.55), "metal", false)
	for i in range(6):
		_vis(Vector3(-CELL_HALF + 0.14, y + 0.5, 0.42 + float(i) * 0.10), Vector3(0.12, 0.45, 0.04), "metal")
	_cyl(Vector3(-CELL_HALF + 0.12, y + 0.18, 0.48), 0.02, 0.36, "metal")
	_cyl(Vector3(-CELL_HALF + 0.12, y + 0.18, 0.92), 0.02, 0.36, "metal")
	# Проводка под потолком + табличка этажа
	_box(Vector3(CELL_HALF - 0.12, y + 2.35, 0.8), Vector3(0.04, 0.04, 3.2), "metal", false)
	_box(Vector3(CELL_HALF - 0.12, y + 1.7, -0.5), Vector3(0.06, 0.7, 0.06), "metal", false)
	_box(Vector3(0.0, y + 1.9, LAND_Z0 + 0.06), Vector3(0.22, 0.28, 0.03), "number", false)
	# Грязные углы + потёртости на зелёнке
	_box(Vector3(-CELL_HALF + 0.15, y + 0.03, LAND_Z0 + 0.2), Vector3(0.28, 0.05, 0.28), "dirt", false)
	_box(Vector3(CELL_HALF - 0.15, y + 0.03, LAND_Z0 + 0.2), Vector3(0.28, 0.05, 0.28), "dirt", false)
	_vis(Vector3(-CELL_HALF + 0.06, y + 0.45, 1.2), Vector3(0.01, 0.25, 0.35), "dirt")
	_vis(Vector3(CELL_HALF - 0.06, y + 0.38, 0.35), Vector3(0.01, 0.22, 0.28), "dirt")
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
		# Откос проёма, полотно с филёнками, наличник, порог и фурнитура
		_vis(pos + Vector3(0.0, 0.0, -0.03), Vector3(0.94, 2.16, 0.10), "concrete")
		_mesh_at(Geo.door_leaf(0.78, 2.0, 0.06), pos + Vector3(0, 0, 0.02), "door_apt")
		for sx in [-1.0, 1.0]:
			_vis(pos + Vector3(sx * 0.43, 0.0, 0.03), Vector3(0.07, 2.12, 0.03), "wood")
		_vis(pos + Vector3(0.0, 1.06, 0.03), Vector3(0.93, 0.07, 0.03), "wood")
		_vis(pos + Vector3(0.0, -1.02, 0.05), Vector3(0.80, 0.04, 0.10), "metal")
		# Ручка-скоба и накладка замка
		_mesh_at(Geo.pipe(0.011, 0.14), pos + Vector3(0.29, 0.0, 0.10), "metal", Vector3(0, 0, 0))
		_vis(pos + Vector3(0.29, 0.07, 0.07), Vector3(0.02, 0.02, 0.05), "metal")
		_vis(pos + Vector3(0.29, -0.07, 0.07), Vector3(0.02, 0.02, 0.05), "metal")
		_vis(pos + Vector3(0.30, -0.16, 0.06), Vector3(0.05, 0.09, 0.02), "metal")
		_mesh_at(Geo.pipe(0.014, 0.03), pos + Vector3(0.0, 0.44, 0.05), "metal", Vector3(90, 0, 0))
		_vis(pos + Vector3(-0.22, 0.62, 0.055), Vector3(0.22, 0.14, 0.01), "paper")
	else:
		_box(pos, Vector3(0.07, 2.0, 0.78), "door_apt", false)

func _tune_light(l: OmniLight3D, shadow: bool, fade_begin: float = 14.0) -> void:
	## Тени от ламп подъезда включены, но гаснут по дистанции: иначе десяток
	## омни-теней на девятиэтажке съедает и атлас теней, и кадр.
	l.shadow_enabled = shadow
	if shadow:
		l.shadow_bias = 0.05
		l.shadow_normal_bias = 1.4
		l.shadow_opacity = 0.92
	l.distance_fade_enabled = true
	l.distance_fade_begin = fade_begin
	l.distance_fade_shadow = fade_begin * 0.55
	l.distance_fade_length = 5.0

func _add_floor_light(y: float) -> void:
	# Плафон в решётке — типовой подъездный светильник
	var shade := PropLibrary.spawn(self, "caged_hanging_light", Vector3(0.15, y + 2.32, 0.1), Vector3(0, 0, 0), 1.0, 0.30)
	if shade == null:
		_cyl(Vector3(0.15, y + 2.52, 0.1), 0.006, 0.28, "metal")
		_vis(Vector3(0.15, y + 2.42, 0.1), Vector3(0.04, 0.05, 0.04), "concrete")
	_sph(Vector3(0.15, y + 2.30, 0.1), 0.035, "lamp")
	var lamp := OmniLight3D.new()
	# 2700K накаливания против 6500K из окна — контраст тёплого и холодного
	lamp.light_color = Color(1.0, 0.72, 0.36)
	lamp.light_energy = 1.5
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 1.8
	lamp.position = Vector3(0.15, y + 2.35, 0.1)
	_tune_light(lamp, true, 8.5)
	add_child(lamp)
	lights.append(lamp)
	# Свет, входящий через окно промежуточной площадки
	var ml := OmniLight3D.new()
	ml.light_color = Color(0.80, 0.87, 1.0)
	ml.light_energy = 1.7
	ml.omni_range = 4.6
	ml.omni_attenuation = 1.3
	ml.position = Vector3(0, y - HALF_H + 1.9, 2.55)
	_tune_light(ml, false, 10.0)
	add_child(ml)
	lights.append(ml)

func _build_apartment_door(start_floor: int) -> void:
	var y := float(start_floor) * FLOOR_H
	spawn_pos = Vector3(-0.85, y + 0.2, -0.55)
	_box(Vector3(-0.85, y + 1.0, LAND_Z0 + 0.12), Vector3(0.82, 2.0, 0.08), "door", false)
	_box(Vector3(-0.85, y + 0.02, -0.7), Vector3(0.55, 0.03, 0.4), "dirt", false)
	_box(Vector3(-1.05, y + 1.62, LAND_Z0 + 0.18), Vector3(0.22, 0.14, 0.02), "number", false)

func _build_yard(ice: bool, night: bool) -> void:
	var ground := "ice" if ice else "asphalt"
	_box(Vector3(0, -0.1, 12.0), Vector3(24.0, 0.3, 18.0), ground)
	# Бордюр + клок зелёнки у дома
	_box(Vector3(0, 0.02, 5.4), Vector3(8.0, 0.12, 0.35), "concrete", false)
	_box(Vector3(-3.5, 0.01, 6.2), Vector3(2.4, 0.06, 1.5), "ground_dirt", false)
	_box(Vector3(3.8, 0.01, 6.0), Vector3(1.9, 0.06, 1.2), "ground_dirt", false)
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
			_mesh_at(Geo.window_reveal(1.28, 1.42, 0.22, 0.2), Vector3(wx, wy, DOOR_Z + 0.30), "panel")
			_box(Vector3(wx, wy, DOOR_Z + 0.38), Vector3(1.28, 1.42, 0.05), "metal", false)
			if kind == 0 and night:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "window_lit", false)
			elif kind == 1:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "curtain", false)
			else:
				_box(Vector3(wx, wy, DOOR_Z + 0.45), Vector3(1.15, 1.3, 0.05), "glass", false)
			_vis(Vector3(wx, wy, DOOR_Z + 0.47), Vector3(1.15, 0.03, 0.02), "metal")
			_vis(Vector3(wx, wy, DOOR_Z + 0.47), Vector3(0.03, 1.3, 0.02), "metal")
			if kind == 2:
				_box(Vector3(wx, wy - 0.15, DOOR_Z + 0.85), Vector3(1.4, 1.1, 0.7), "balcony", false)
				_box(Vector3(wx, wy + 0.35, DOOR_Z + 0.85), Vector3(1.42, 0.08, 0.72), "metal", false)
				_vis(Vector3(wx + 0.2, wy + 0.1, DOOR_Z + 1.05), Vector3(0.7, 0.02, 0.25), "paper")
			elif kind == 3:
				_box(Vector3(wx, wy - 0.2, DOOR_Z + 0.75), Vector3(1.35, 0.9, 0.55), "wood", false)
			elif kind == 4:
				_box(Vector3(wx, wy - 0.35, DOOR_Z + 0.7), Vector3(1.3, 0.08, 0.5), "concrete", false)
				_box(Vector3(wx - 0.55, wy - 0.05, DOOR_Z + 0.7), Vector3(0.05, 0.7, 0.5), "metal", false)
				_box(Vector3(wx + 0.55, wy - 0.05, DOOR_Z + 0.7), Vector3(0.05, 0.7, 0.5), "metal", false)
				_vis(Vector3(wx + 0.35, wy - 0.55, DOOR_Z + 0.72), Vector3(0.35, 0.22, 0.28), "metal")
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
	_box(Vector3(-6.5, 0.04, 10.0), Vector3(1.7, 0.08, 4.2), "ground_dirt", false)
	_box(Vector3(7.0, 0.04, 13.0), Vector3(1.4, 0.08, 3.2), "ground_dirt", false)
	_build_chainlink()
	# Лавка у входа и урна
	PropLibrary.spawn(self, "modular_street_seating", Vector3(-4.8, 0.0, 8.2), Vector3(0, 90, 0), 1.0, 0.85)
	PropLibrary.spawn(self, "metal_trash_can", Vector3(-3.2, 0.0, 7.5), Vector3(0, -20, 0), 1.0, 0.9)
	# Фонарный столб: модель вместо палки с кубом
	var lamp_post := PropLibrary.spawn(self, "street_lamp_01", Vector3(-1.8, 0.0, 7.2), Vector3(0, 105, 0), 1.0, 4.6)
	if lamp_post == null:
		_box(Vector3(-1.8, 2.0, 7.2), Vector3(0.12, 4.0, 0.12), "metal", false)
		_box(Vector3(-1.8, 4.05, 7.5), Vector3(0.5, 0.08, 0.08), "metal", false)
		_box(Vector3(-1.8, 3.95, 7.7), Vector3(0.28, 0.18, 0.28), "lamp" if night else "metal", false)
	elif night:
		_vis(Vector3(-1.8, 4.32, 7.62), Vector3(0.26, 0.10, 0.42), "lamp")
	_box(Vector3(6.8, 1.15, 11.5), Vector3(0.1, 2.2, 0.1), "metal")
	_box(Vector3(7.55, 1.15, 11.5), Vector3(0.1, 2.2, 0.1), "metal")
	_box(Vector3(7.15, 2.25, 11.5), Vector3(0.95, 0.07, 0.07), "metal", false)
	# Боковины площадки: листы профнастила на стойках
	var enc_b := _box(Vector3(3.5, 0.65, 16.1), Vector3(4.3, 1.2, 0.1), "metal")
	var enc_l := _box(Vector3(1.45, 0.65, 14.5), Vector3(0.1, 1.2, 3.3), "metal")
	var enc_r := _box(Vector3(5.55, 0.65, 14.5), Vector3(0.1, 1.2, 3.3), "metal")
	_hide_mesh(enc_b)
	_hide_mesh(enc_l)
	_hide_mesh(enc_r)
	for sx in [1.45, 5.55]:
		_vis(Vector3(sx, 0.85, 14.5), Vector3(0.04, 1.7, 3.3), "steel")
		_vis(Vector3(sx, 1.74, 14.5), Vector3(0.06, 0.06, 3.34), "rust")
		for i in range(3):
			_mesh_at(Geo.pipe(0.032, 1.9), Vector3(sx, 0.95, 13.0 + float(i) * 1.5), "steel")
	_vis(Vector3(8.2, 14.6, DOOR_Z + 0.9), Vector3(0.55, 0.08, 0.55), "metal")
	_cyl(Vector3(8.2, 14.85, DOOR_Z + 0.9), 0.28, 0.04, "metal", Vector3(70, 20, 0))
	_vis(Vector3(-6.4, 6.4, DOOR_Z + 0.55), Vector3(0.55, 0.32, 0.42), "metal")
	_dress_yard(night, ice)
	if ice:
		_box(Vector3(0, 0.02, 9.0), Vector3(3.0, 0.05, 1.0), "ice")
		yard_ice_zones.append(Rect2(Vector2(-7, 7), Vector2(14, 10)))
	# Дневной fill у помойки + ночной фонарь
	var yl := OmniLight3D.new()
	yl.light_color = Color(1.0, 0.76, 0.42) if night else Color(0.95, 0.94, 0.9)
	yl.light_energy = 3.2 if night else 0.5
	yl.omni_range = 14.0 if night else 10.0
	yl.omni_attenuation = 1.4
	yl.position = Vector3(-1.8, 3.9, 7.7)
	_tune_light(yl, night, 22.0)
	add_child(yl)
	if night:
		lights.append(yl)

## Разнотравье вдоль бордюров и у забора: одна пачка на вид растения.
func _scatter_plants(rng: RandomNumberGenerator, model: String, part: String, spots: Array, scale_range: Vector2) -> void:
	var got := PropLibrary.mesh_of(model, part)
	if got.is_empty():
		return
	var xforms: Array = []
	for s in spots:
		var p: Vector3 = s
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y))
		xforms.append(Transform3D(b, p))
	# Травинки тени не бросают: на глаз незаметно, по кадру — заметно
	_multi_raw(got[0], xforms, got[1], false)

func _plant_spots(rng: RandomNumberGenerator, count: int, cx: float, cz: float, w: float, d: float, y: float = 0.0) -> Array:
	var out: Array = []
	for _i in range(count):
		out.append(Vector3(cx + rng.randf_range(-w, w), y, cz + rng.randf_range(-d, d)))
	return out

## Безлистное дерево поздней осени: ствол и ветки — листву в CC0 не найти
## дешевле 90 МБ геометрии, а голое дерево для нашей серости даже точнее.
func _bare_tree(base: Vector3, height: float, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var trunk_r := height * 0.045
	_mesh_at(Geo.pipe(trunk_r, height, 12), base + Vector3(0, height * 0.5, 0), "wood")
	var count := 11
	for i in range(count):
		var t := 0.42 + 0.54 * float(i) / float(count)
		var y := base.y + height * t
		var yaw := rng.randf_range(0.0, TAU)
		var tilt := deg_to_rad(rng.randf_range(25.0, 58.0))
		var len_b: float = height * rng.randf_range(0.16, 0.30) * (1.0 - t * 0.4)
		var dir := Vector3(sin(yaw) * sin(tilt), cos(tilt), cos(yaw) * sin(tilt)).normalized()
		var start := Vector3(base.x, y, base.z)
		var mid := start + dir * len_b * 0.5
		var branch := _mesh_at(Geo.pipe(trunk_r * (0.34 - t * 0.12), len_b, 6), mid, "wood")
		branch.rotation = Quaternion(Vector3.UP, dir).get_euler()
		# Второстепенная веточка от середины основной
		if i % 2 == 0:
			var yaw2 := yaw + rng.randf_range(0.6, 1.8)
			var dir2 := Vector3(sin(yaw2) * 0.8, 0.6, cos(yaw2) * 0.8).normalized()
			var len2 := len_b * 0.55
			var twig := _mesh_at(Geo.pipe(trunk_r * 0.14, len2, 5), mid + dir2 * len2 * 0.5, "wood")
			twig.rotation = Quaternion(Vector3.UP, dir2).get_euler()

## Соседние панельки за забором: без них небо садится прямо на землю.
func _background_blocks(night: bool) -> void:
	var blocks := [
		{"pos": Vector3(-22.0, 8.4, 44.0), "size": Vector3(26.0, 16.8, 11.0), "rot": -8.0},
		{"pos": Vector3(19.0, 10.2, 52.0), "size": Vector3(22.0, 20.4, 11.0), "rot": 6.0},
		{"pos": Vector3(2.0, 7.2, 68.0), "size": Vector3(34.0, 14.4, 12.0), "rot": 0.0},
	]
	var lit: Array = []
	var dark: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240814
	for b in blocks:
		var pos: Vector3 = b["pos"]
		var size: Vector3 = b["size"]
		var mi := _mesh_at(Geo.rounded_box(size, 0.05), pos, "panel_far", Vector3(0, b["rot"], 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var basis := Basis(Vector3.UP, deg_to_rad(float(b["rot"])))
		var cols := int(size.x / 3.2)
		var rows := int(size.y / 2.8)
		for r in range(rows):
			for c in range(cols):
				var local := Vector3(-size.x * 0.5 + 1.8 + float(c) * 3.2, -size.y * 0.5 + 1.9 + float(r) * 2.8, -size.z * 0.5 - 0.06)
				var t := Transform3D(basis, pos + basis * local)
				if night and rng.randf() < 0.45:
					lit.append(t)
				else:
					dark.append(t)
	_multi(Geo.rounded_box(Vector3(1.5, 1.3, 0.08), 0.01), "window_lit" if night else "glass", lit if night else dark)
	if night and not dark.is_empty():
		_multi(Geo.rounded_box(Vector3(1.5, 1.3, 0.08), 0.01), "glass", dark)

func _dress_yard(night: bool, ice: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	_background_blocks(night)
	if not ice:
		_scatter_plants(rng, "grass_medium_01", "tall_a", _plant_spots(rng, 26, -3.5, 6.2, 1.1, 0.7, 0.02), Vector2(0.8, 1.5))
		_scatter_plants(rng, "grass_medium_01", "mid_b", _plant_spots(rng, 22, 3.8, 6.0, 0.9, 0.55, 0.02), Vector2(0.9, 1.6))
		_scatter_plants(rng, "grass_medium_01", "small_a", _plant_spots(rng, 30, -6.5, 10.0, 0.8, 2.0, 0.02), Vector2(0.8, 1.4))
		_scatter_plants(rng, "weed_plant_02", "_c_", _plant_spots(rng, 18, 7.0, 13.0, 0.7, 1.6, 0.01), Vector2(0.9, 1.5))
		_scatter_plants(rng, "dandelion_01", "_e_", _plant_spots(rng, 12, -4.0, 8.4, 2.4, 0.5, 0.01), Vector2(0.8, 1.3))
		_scatter_plants(rng, "nettle_plant", "tall_a", _plant_spots(rng, 14, 9.4, 11.0, 0.5, 4.0, 0.01), Vector2(1.0, 1.8))
		_bare_tree(Vector3(-7.6, 0.0, 8.4), 7.5, 11)
		_bare_tree(Vector3(8.6, 0.0, 16.4), 6.2, 27)
	else:
		_scatter_plants(rng, "grass_medium_01", "tall_a", _plant_spots(rng, 14, -3.5, 6.2, 1.1, 0.6, 0.02), Vector2(0.6, 1.0))
	# Люк, машина под чехлом, шины
	PropLibrary.spawn(self, "water_manhole_cover", Vector3(-2.4, 0.0, 11.6), Vector3(0, 12, 0), 1.0, 0.08)
	PropLibrary.spawn(self, "covered_car", Vector3(-7.2, 0.0, 14.6), Vector3(0, 12, 0), 1.0, 1.55)
	PropLibrary.spawn(self, "old_tyre", Vector3(-9.2, 0.05, 11.2), Vector3(0, 0, 0), 1.0, 0.62)
	PropLibrary.spawn(self, "plastic_monobloc_chair_01", Vector3(-5.9, 0.0, 8.9), Vector3(0, 200, 0), 1.0, 0.85)
	# Фасадные детали: кондиционеры и провода к столбу
	PropLibrary.spawn(self, "exterior_aircon_unit", Vector3(-6.4, 6.4, DOOR_Z + 0.42), Vector3(0, 0, 0), 1.0, 0.62)
	PropLibrary.spawn(self, "exterior_aircon_unit", Vector3(5.6, 9.2, DOOR_Z + 0.42), Vector3(0, 0, 0), 1.0, 0.62)
	PropLibrary.spawn(self, "security_light", Vector3(2.2, 2.9, DOOR_Z + 0.30), Vector3(0, 180, 0), 1.0, 0.4)

## Сетка-рабица секциями по периметру двора: столбы и полотно — из модели.
func _build_chainlink() -> void:
	var panel := PropLibrary.mesh_of("modular_chainlink_fence", "fence_double")
	var post := PropLibrary.mesh_of("modular_chainlink_fence", "fence_post")
	if panel.is_empty() or post.is_empty():
		for i in range(8):
			_box(Vector3(-9.5 + float(i) * 2.7, 0.7, 19.3), Vector3(0.1, 1.4, 0.1), "metal", false)
		_box(Vector3(0, 1.35, 19.3), Vector3(20.0, 0.05, 0.05), "metal", false)
		return
	var panel_w := 1.91
	var panels: Array = []
	var posts: Array = []
	# Дальняя сторона и две боковых; поворот на 90° для боковых линий
	for i in range(11):
		var px := -9.55 + float(i) * panel_w
		panels.append(Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 19.3)))
		posts.append(Transform3D(Basis.IDENTITY, Vector3(px - panel_w * 0.5, 0.0, 19.3)))
	var side_rot := Basis(Vector3.UP, deg_to_rad(90.0))
	for side in [-10.2, 10.2]:
		for i in range(7):
			var pz := 6.4 + float(i) * panel_w
			panels.append(Transform3D(side_rot, Vector3(side, 0.0, pz)))
			posts.append(Transform3D(side_rot, Vector3(side, 0.0, pz - panel_w * 0.5)))
	_multi_raw(panel[0], panels, panel[1])
	_multi_raw(post[0], posts, post[1])

## MultiMesh для мешей из GLTF: материалы берутся из самого меша, не из _mats.
func _multi_raw(mesh: Mesh, xforms: Array, local: Transform3D = Transform3D.IDENTITY, shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func _build_detour_path() -> void:
	_box(Vector3(-7.0, -0.05, 11.0), Vector3(2.2, 0.12, 10.0), "asphalt")
	_box(Vector3(-7.0, 0.04, 15.0), Vector3(0.5, 0.06, 0.5), "mark", false)

func _build_basement_props() -> void:
	_box(Vector3(0.9, -FLOOR_H + 0.35, 1.0), Vector3(0.22, 0.22, 2.0), "metal")
	_box(Vector3(-0.8, -FLOOR_H + 0.12, 1.8), Vector3(0.9, 0.05, 0.9), "ice")
	# Трубы под потолком подвала и хлам у стены
	var pipes := PropLibrary.mesh_of("modular_pipes", "pipe")
	if not pipes.is_empty():
		var runs: Array = []
		for i in range(3):
			runs.append(Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-1.1 + float(i) * 0.18, -FLOOR_H + 1.95, 2.0)))
		_multi_raw(pipes[0], runs, pipes[1])
	PropLibrary.spawn(self, "plastic_crate_01", Vector3(1.05, -FLOOR_H + 0.02, 2.6), Vector3(0, 30, 0), 1.0, 0.28)
	PropLibrary.spawn(self, "cardboard_box_01", Vector3(0.75, -FLOOR_H + 0.02, 3.4), Vector3(0, -18, 0), 1.0, 0.35)

func _build_basement_exit() -> void:
	## Коридор + пандус во двор — «через подвал короче» должно быть правдой.
	_box(Vector3(0, -FLOOR_H - 0.1, 4.4), Vector3(1.7, 0.2, 4.2), "concrete")
	_box(Vector3(-0.85, -FLOOR_H + 1.1, 4.4), Vector3(0.1, 2.2, 4.0), "concrete")
	_box(Vector3(0.85, -FLOOR_H + 1.1, 4.4), Vector3(0.1, 2.2, 4.0), "concrete")
	var run := 5.2
	var rise := FLOOR_H
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.5, 0.16, length)
	cs.shape = sh
	ramp.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	mi.mesh = bm
	mi.material_override = _mats["concrete"]
	ramp.add_child(mi)
	ramp.position = Vector3(0.0, -FLOOR_H * 0.5, 8.8)
	ramp.rotation.x = -angle
	add_child(ramp)
	_box(Vector3(0, 0.02, 11.4), Vector3(1.8, 0.12, 1.6), "asphalt")

## Евроконтейнер 1.1 м³: корпус с уклоном, рёбра жёсткости, крышка на петлях,
## ручки, колёса и потёки ржавчины. Коллизия остаётся исходным боксом.
func _euro_bin(center: Vector3, lid_deg: float, tagged: bool) -> void:
	var body := _box(center, Vector3(1.0, 1.35, 1.15), "dumpster")
	_hide_mesh(body)
	var base_y := center.y - 0.675
	# Корпус: низ уже верха — у настоящего бака стенки с уклоном
	_vis(Vector3(center.x, base_y + 0.30, center.z), Vector3(0.88, 0.44, 1.02), "dumpster")
	_vis(Vector3(center.x, base_y + 0.78, center.z), Vector3(0.98, 0.56, 1.12), "dumpster")
	_vis(Vector3(center.x, base_y + 1.09, center.z), Vector3(1.0, 0.10, 1.14), "dumpster")
	var ribs: Array = []
	for k in range(3):
		ribs.append(Transform3D(Basis.IDENTITY, Vector3(center.x, base_y + 0.62 + float(k) * 0.20, center.z)))
	_multi(Geo.rounded_box(Vector3(1.01, 0.05, 1.15), 0.008), "dumpster", ribs)
	# Крышка на петлях, откинута назад
	var lid := _mesh_at(Geo.rounded_box(Vector3(1.04, 0.07, 1.16), 0.012),
		Vector3(center.x, base_y + 1.16, center.z + 0.02), "steel")
	lid.rotation_degrees.x = lid_deg
	_mesh_at(Geo.pipe(0.016, 0.98), Vector3(center.x, base_y + 1.14, center.z - 0.56), "rust", Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		_mesh_at(Geo.pipe(0.018, 0.30), Vector3(center.x + sx * 0.52, base_y + 0.92, center.z), "steel", Vector3(90, 0, 0))
		_vis(Vector3(center.x + sx * 0.51, base_y + 0.92, center.z - 0.15), Vector3(0.03, 0.06, 0.04), "steel")
		_vis(Vector3(center.x + sx * 0.51, base_y + 0.92, center.z + 0.15), Vector3(0.03, 0.06, 0.04), "steel")
	# Колёса на вилках
	for wz in [-0.42, 0.42]:
		for wx in [-0.34, 0.34]:
			var wp := Vector3(center.x + wx, base_y + 0.07, center.z + wz)
			_mesh_at(Geo.pipe(0.065, 0.05, 14), wp, "prop", Vector3(0, 0, 90))
			_vis(wp + Vector3(0, 0.09, 0), Vector3(0.07, 0.13, 0.05), "steel")
	# Потёки ржавчины и трафарет
	_vis(Vector3(center.x - 0.30, base_y + 0.55, center.z - 0.58), Vector3(0.12, 0.62, 0.01), "rust")
	_vis(Vector3(center.x + 0.22, base_y + 0.40, center.z - 0.58), Vector3(0.08, 0.44, 0.01), "rust")
	_vis(Vector3(center.x + 0.45, base_y + 0.70, center.z + 0.57), Vector3(0.06, 0.5, 0.01), "rust")
	_vis(Vector3(center.x, base_y + 0.80, center.z - 0.585), Vector3(0.34, 0.16, 0.01), "number")
	if tagged:
		_vis(Vector3(center.x - 0.02, base_y + 0.50, center.z - 0.59), Vector3(0.6, 0.4, 0.01), "graffiti")

func _build_dumpster() -> void:
	# Площадка: профнастил на стойках вместо решётки из палок
	for i in range(5):
		_mesh_at(Geo.pipe(0.035, 1.9), Vector3(1.9 + float(i) * 0.95, 0.95, 15.5), "steel")
	_vis(Vector3(3.7, 0.95, 15.56), Vector3(4.4, 1.7, 0.04), "steel")
	_vis(Vector3(3.7, 1.84, 15.5), Vector3(4.5, 0.06, 0.18), "rust")
	for i in range(3):
		_euro_bin(Vector3(2.6 + float(i) * 1.15, 0.7, 14.6), -62.0 if i != 2 else -18.0, i == 1)
	_box(Vector3(3.7, 0.03, 13.8), Vector3(2.8, 0.02, 1.2), "puddle", false)
	_box(Vector3(2.4, 0.08, 13.5), Vector3(0.25, 0.08, 0.2), "dirt", false)
	_vis(Vector3(3.7, 1.35, 15.53), Vector3(0.9, 0.28, 0.01), "paper")
	# Хлам вокруг баков
	PropLibrary.spawn(self, "metal_trash_can", Vector3(5.5, 0.0, 15.0), Vector3(0, 25, 0), 1.0, 0.9)
	PropLibrary.spawn(self, "plastic_crate_01", Vector3(1.75, 0.0, 13.6), Vector3(0, -35, 4), 1.0, 0.28)
	PropLibrary.spawn(self, "cardboard_box_01", Vector3(4.9, 0.0, 13.5), Vector3(0, 15, 0), 1.0, 0.36)
	PropLibrary.spawn(self, "old_tyre", Vector3(1.5, 0.03, 15.0), Vector3(90, 20, 0), 1.0, 0.6)
	PropLibrary.spawn(self, "street_rat", Vector3(5.15, 0.02, 14.2), Vector3(0, -120, 0), 1.0, 0.09)
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
		npc.setup(0, Vector3(-4.2 + i * 0.8, 0.2, 7.2 + i * 0.4), Vector3(-1.2, 0.2, 10.5 + i * 0.3), null)
		npcs.append(npc)
	for i in range(int(level.get("dogs", 0))):
		var dog = StairNpcScr.new()
		add_child(dog)
		# Патруль на коротком пути, не на баках (иначе вынос невозможен)
		dog.setup(1, Vector3(1.2 + float(i) * 0.6, 0.2, 8.6), Vector3(2.4 + float(i) * 0.4, 0.2, 11.2), null)
		npcs.append(dog)

func _spawn_player_and_bag(start_floor: int, level: Dictionary) -> void:
	var p = TrashPlayerScr.new()
	add_child(p)
	p.global_position = spawn_pos
	# Смотрим на пакет, дальше правый марш — не в шахту
	var look := Vector3(STAIR_X, spawn_pos.y, LAND_Z1) - spawn_pos
	p.set_look_yaw(atan2(-look.x, -look.z))
	player = p
	var trash = TrashBagScr.new()
	add_child(trash)
	trash.setup(str(level.get("cargo", "bag")), float(level.get("bag_hp", 100.0)))
	trash.wind_force = float(level.get("wind", 0.0))
	trash.global_position = Vector3(-0.85, float(start_floor) * FLOOR_H + 0.22, -0.62)
	trash.freeze = true
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
	if player_pos.y < -1.0:
		return "По пандусу из подвала во двор" if lang == "ru" else "Ramp from basement to the yard"
	var near_mid := player_pos.z > 2.0 and player_pos.z < 3.2 and fmod(player_pos.y + 0.35, FLOOR_H) > HALF_H - 0.55 and fmod(player_pos.y + 0.35, FLOOR_H) < HALF_H + 0.55
	if near_mid:
		return "Разворот — левый марш вниз" if lang == "ru" else "Turn — left flight down"
	if lang == "ru":
		return "Вниз по правому маршу к окну"
	return "Down the right flight toward the window"
