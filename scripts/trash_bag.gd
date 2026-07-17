class_name TrashBag
extends RigidBody3D
## Геройский груз: полиэтиленовый пакет (силуэт, плёнка, spring, порча, разрыв).

signal burst
signal damaged(hp_left: float, max_hp: float)
signal dumped

enum Cargo { BAG, BUCKETS, CARPET, FRIDGE, THIN }
enum TearStage { WHOLE, WORN, HOLES, CRITICAL, BURST }

var cargo: Cargo = Cargo.BAG
var max_hp: float = 100.0
var hp: float = 100.0
var held: bool = false
var bursted: bool = false
var impact_threshold: float = 3.2
var wind_force: float = 0.0
var game: Node = null
var careful: bool = false
var armful_count: int = 0
var tear_stage: TearStage = TearStage.WHOLE

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _visual: Node3D
var _body_mi: MeshInstance3D
var _neck_mi: MeshInstance3D
var _handle_l: MeshInstance3D
var _handle_r: MeshInstance3D
var _seam_mi: MeshInstance3D
var _rag_left: MeshInstance3D
var _rag_right: MeshInstance3D
var _hold_target: Node3D = null
var _mat: StandardMaterial3D
var _last_vel: Vector3 = Vector3.ZERO
var _pieces_spawned: bool = false
var _particles: GPUParticles3D = null
var _crumb_particles: GPUParticles3D = null
var _base_color: Color = Color(0.14, 0.43, 0.23)
var _hold_offset: Vector3 = Vector3.ZERO
var _yaw_slow: float = 1.0
var _grab_t: float = 1.0
var _compress: float = 0.0
var _sway_vel: Vector3 = Vector3.ZERO
var _ang_lag: Quaternion = Quaternion.IDENTITY
var _rustle: AudioStreamPlayer3D
var _filling: int = 0  # 0 organic, 1 glass mix
var _color_preset: int = 0
var _is_plastic_bag: bool = false
var _body_base_scale: Vector3 = Vector3.ONE
var _debug_last_impulse: float = 0.0

const POS_K := 16.0
const ROT_K := 7.5
const SWAY_DAMP := 8.0

func setup(kind: String, bag_hp: float) -> void:
	max_hp = bag_hp
	hp = bag_hp
	_filling = randi() % 2
	_color_preset = randi() % 3
	match kind:
		"buckets":
			cargo = Cargo.BUCKETS
			impact_threshold = 4.5
			_hold_offset = Vector3(0.15, -0.1, 0.05)
			_yaw_slow = 0.75
			_is_plastic_bag = false
		"carpet":
			cargo = Cargo.CARPET
			impact_threshold = 5.0
			_hold_offset = Vector3(0.0, -0.15, -0.1)
			_yaw_slow = 0.45
			_is_plastic_bag = false
		"fridge":
			cargo = Cargo.FRIDGE
			impact_threshold = 6.0
			_hold_offset = Vector3(0.1, -0.55, 0.0)
			_yaw_slow = 0.35
			_is_plastic_bag = false
		"thin":
			cargo = Cargo.THIN
			impact_threshold = 2.2
			_hold_offset = Vector3(0.0, -0.08, 0.02)
			_yaw_slow = 0.95
			_is_plastic_bag = true
		_:
			cargo = Cargo.BAG
			impact_threshold = 3.2
			_hold_offset = Vector3(0.0, -0.06, 0.02)
			_yaw_slow = 0.9
			_is_plastic_bag = true
	_build_visual()
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	collision_layer = 4
	collision_mask = 1
	mass = _mass_for_cargo()
	gravity_scale = 1.0
	linear_damp = 0.4
	angular_damp = 1.2
	if _is_plastic_bag:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0.0, -0.14, 0.0)
	_setup_rustle()
	add_to_group("trash_bag")

func _mass_for_cargo() -> float:
	match cargo:
		Cargo.BUCKETS: return 4.0
		Cargo.CARPET: return 6.0
		Cargo.FRIDGE: return 18.0
		Cargo.THIN: return 1.15
		_: return 2.1

func speed_mult() -> float:
	match cargo:
		Cargo.BUCKETS: return 0.85
		Cargo.CARPET: return 0.65
		Cargo.FRIDGE: return 0.45
		Cargo.THIN: return 1.02
		_: return 0.92

func fov_offset() -> float:
	match cargo:
		Cargo.CARPET: return -4.0
		Cargo.FRIDGE: return -8.0
		Cargo.BAG: return -2.5
		Cargo.THIN: return -1.5
		_: return 0.0

func yaw_mult() -> float:
	var m := _yaw_slow
	if tear_stage >= TearStage.HOLES:
		m *= 0.85
	return m

func _setup_rustle() -> void:
	_rustle = AudioStreamPlayer3D.new()
	_rustle.volume_db = -80.0
	_rustle.max_distance = 12.0
	_rustle.bus = "Master"
	add_child(_rustle)
	if ResourceLoader.exists("res://assets/sfx/rustle.wav"):
		_rustle.stream = load("res://assets/sfx/rustle.wav")
		_rustle.autoplay = false

func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	match cargo:
		Cargo.BUCKETS:
			_base_color = Color(0.35, 0.45, 0.55)
		Cargo.CARPET:
			_base_color = Color(0.55, 0.22, 0.18)
		Cargo.FRIDGE:
			_base_color = Color(0.85, 0.88, 0.92)
		Cargo.THIN:
			_base_color = [Color(0.18, 0.52, 0.30), Color(0.14, 0.48, 0.28), Color(0.22, 0.55, 0.32)][_color_preset]
		_:
			_base_color = [Color(0.12, 0.42, 0.22), Color(0.10, 0.38, 0.20), Color(0.16, 0.46, 0.24)][_color_preset]
	_mat.albedo_color = _base_color
	_mat.roughness = 0.82
	_mat.metallic = 0.0

	_mesh = MeshInstance3D.new()
	_col = CollisionShape3D.new()
	match cargo:
		Cargo.BUCKETS:
			_build_simple_primitive()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.2
			cyl.height = 0.45
			_mesh.mesh = cyl
			var sh := CylinderShape3D.new()
			sh.radius = 0.2
			sh.height = 0.45
			_col.shape = sh
			_mesh.material_override = _mat
			add_child(_mesh)
			add_child(_col)
		Cargo.CARPET:
			_build_simple_primitive()
			var box := BoxMesh.new()
			box.size = Vector3(1.4, 0.12, 0.45)
			_mesh.mesh = box
			var sh2 := BoxShape3D.new()
			sh2.size = box.size
			_col.shape = sh2
			_mesh.material_override = _mat
			add_child(_mesh)
			add_child(_col)
		Cargo.FRIDGE:
			_build_simple_primitive()
			var box2 := BoxMesh.new()
			box2.size = Vector3(0.65, 1.5, 0.6)
			_mesh.mesh = box2
			var sh3 := BoxShape3D.new()
			sh3.size = box2.size
			_col.shape = sh3
			_col.position = Vector3(0, 0.75, 0)
			_mesh.position = Vector3(0, 0.75, 0)
			_mesh.material_override = _mat
			add_child(_mesh)
			add_child(_col)
		_:
			_build_plastic_bag()
	_build_burst_particles()
	_build_crumb_particles()

func _build_simple_primitive() -> void:
	pass

func _apply_bag_material() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	_mat.roughness = 0.78 if cargo != Cargo.THIN else 0.65
	_mat.metallic = 0.02
	if cargo == Cargo.THIN:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color.a = 0.82
	var albedo_path := "res://assets/textures/bag/bag_thin_albedo.png" if cargo == Cargo.THIN else "res://assets/textures/bag/bag_albedo.png"
	if ResourceLoader.exists(albedo_path):
		_mat.albedo_texture = load(albedo_path)
		_mat.uv1_scale = Vector3(1.2, 1.2, 1.2)
	if ResourceLoader.exists("res://assets/textures/bag/bag_rough.png"):
		_mat.roughness_texture = load("res://assets/textures/bag/bag_rough.png")
	if ResourceLoader.exists("res://assets/textures/bag/bag_normal.png"):
		_mat.normal_enabled = true
		_mat.normal_texture = load("res://assets/textures/bag/bag_normal.png")
		_mat.normal_scale = 0.55
	# Лёгкая «просвечиваемость» краёв через rim-ish: emission off, slightly lower AO feel
	_mat.emission_enabled = false

func _build_plastic_bag() -> void:
	_apply_bag_material()
	_visual = Node3D.new()
	_visual.name = "BagVisual"
	# Pivot у ручек; тело висит ниже
	add_child(_visual)

	var thin_s := 0.88 if cargo == Cargo.THIN else 1.0
	var asym := 0.04 if _color_preset != 1 else -0.03

	# Тело — сплюснутая сфера (низ тяжёлый)
	_body_mi = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.155 * thin_s
	sphere.height = 0.34 * thin_s
	sphere.radial_segments = 20
	sphere.rings = 12
	_body_mi.mesh = sphere
	_body_mi.material_override = _mat
	_body_base_scale = Vector3(1.15 + asym, 1.25, 0.78 - asym * 0.5)
	_body_mi.scale = _body_base_scale
	_body_mi.position = Vector3(asym * 0.5, -0.20, 0.0)
	_visual.add_child(_body_mi)

	# Горловина
	_neck_mi = MeshInstance3D.new()
	var neck := CylinderMesh.new()
	neck.top_radius = 0.06 * thin_s
	neck.bottom_radius = 0.11 * thin_s
	neck.height = 0.12
	neck.radial_segments = 14
	_neck_mi.mesh = neck
	_neck_mi.material_override = _mat
	_neck_mi.position = Vector3(0.0, -0.02, 0.0)
	_visual.add_child(_neck_mi)

	# Шов (зона разрыва)
	_seam_mi = MeshInstance3D.new()
	var seam := BoxMesh.new()
	seam.size = Vector3(0.01, 0.32, 0.02)
	_seam_mi.mesh = seam
	var seam_mat := _mat.duplicate() as StandardMaterial3D
	seam_mat.albedo_color = _base_color.darkened(0.25)
	_seam_mi.material_override = seam_mat
	_seam_mi.position = Vector3(0.0, -0.18, 0.12)
	_visual.add_child(_seam_mi)

	# Ручки (ушки)
	_handle_l = _make_handle(-1.0, thin_s)
	_handle_r = _make_handle(1.0, thin_s)
	_visual.add_child(_handle_l)
	_visual.add_child(_handle_r)

	# Лохмотья после разрыва (скрыты)
	_rag_left = _make_rag(-1.0)
	_rag_right = _make_rag(1.0)
	_rag_left.visible = false
	_rag_right.visible = false
	_visual.add_child(_rag_left)
	_visual.add_child(_rag_right)

	# Невидимый «главный» mesh для совместимости
	_mesh = _body_mi

	# Коллизия — капсула, COM ниже
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.14 * thin_s
	cap.height = 0.36 * thin_s
	_col.shape = cap
	_col.position = Vector3(0.0, -0.16, 0.0)
	add_child(_col)

func _make_handle(side: float, thin_s: float) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	# Тонкий U из трёх боксов через MultiMesh — проще: Torus сегмент как capsule loop
	var t := TorusMesh.new()
	t.inner_radius = 0.035
	t.outer_radius = 0.055 * thin_s
	t.rings = 10
	t.ring_segments = 8
	root.mesh = t
	root.material_override = _mat
	root.position = Vector3(side * 0.07, 0.06, 0.0)
	root.rotation_degrees = Vector3(70.0, 0.0, side * 18.0)
	root.scale = Vector3(0.7, 0.55, 0.7)
	return root

func _make_rag(side: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.28, 0.02)
	mi.mesh = bm
	var m := _mat.duplicate() as StandardMaterial3D
	m.albedo_color = _base_color.darkened(0.1)
	if cargo == Cargo.THIN:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.7
	mi.material_override = m
	mi.position = Vector3(side * 0.08, -0.12, 0.0)
	mi.rotation_degrees = Vector3(0, 0, side * 25.0)
	return mi

func _build_burst_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 36
	_particles.lifetime = 0.75
	_particles.explosiveness = 0.92
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 85.0
	mat.initial_velocity_min = 2.2
	mat.initial_velocity_max = 6.5
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	mat.color = Color(0.35, 0.65, 0.28)
	_particles.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.05
	draw.height = 0.1
	_particles.draw_pass_1 = draw
	add_child(_particles)

func _build_crumb_particles() -> void:
	_crumb_particles = GPUParticles3D.new()
	_crumb_particles.emitting = false
	_crumb_particles.amount = 6
	_crumb_particles.lifetime = 0.9
	_crumb_particles.explosiveness = 0.2
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, -6.0, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	mat.color = Color(0.45, 0.35, 0.2)
	_crumb_particles.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.025
	draw.height = 0.05
	_crumb_particles.draw_pass_1 = draw
	_crumb_particles.position = Vector3(0, -0.22, 0.1)
	add_child(_crumb_particles)

func grab(hold: Node3D) -> void:
	_hold_target = hold
	held = true
	_grab_t = 0.0
	freeze = false
	gravity_scale = 0.0
	linear_damp = 12.0
	angular_damp = 14.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 4
	collision_mask = 0
	_ang_lag = global_transform.basis.get_rotation_quaternion()
	Svc.audio().play_sfx("bag_grab" if _streams_has("bag_grab") else "pickup", 0.95 + randf() * 0.1)
	if _rustle and _rustle.stream:
		_rustle.play()

func _streams_has(key: String) -> bool:
	return ResourceLoader.exists("res://assets/sfx/%s.wav" % key)

func release(impulse: Vector3 = Vector3.ZERO) -> void:
	held = false
	_hold_target = null
	freeze = false
	gravity_scale = 1.0
	linear_damp = 0.45
	angular_damp = 1.1
	collision_layer = 4
	collision_mask = 1
	linear_velocity = impulse
	if _rustle:
		_rustle.volume_db = -80.0
	if impulse.length() < 1.5:
		Svc.audio().play_sfx("bag_drop" if _streams_has("bag_drop") else "impact", 0.9 + randf() * 0.1)

func throw_forward(dir: Vector3, strength: float = 7.0) -> void:
	release(dir.normalized() * strength + Vector3(0, 1.5, 0))
	angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))

func drop_gentle() -> void:
	release(Vector3(0, -0.6, 0))

func apply_fall_damage(speed: float) -> void:
	if speed < 6.0:
		return
	var dmg := (speed - 6.0) * 12.0
	if careful:
		dmg *= 0.55
	if cargo == Cargo.THIN:
		dmg *= 1.35
	_apply_damage(dmg)
	var pitch := 1.15 if _filling == 1 else 0.9
	Svc.audio().play_sfx("impact", pitch)

func _physics_process(delta: float) -> void:
	if bursted:
		return
	if held and _hold_target:
		_carry_follow(delta)
		_update_rustle(delta, _sway_vel.length() + 0.4)
		return
	var speed := linear_velocity.length()
	var delta_v := (_last_vel - linear_velocity).length()
	var thr := impact_threshold * (1.35 if careful else 1.0)
	if delta_v > thr and speed > 1.2:
		var dmg := (delta_v - thr) * 8.0
		if careful:
			dmg *= 0.5
		if cargo == Cargo.THIN:
			dmg *= 1.5
		_debug_last_impulse = delta_v
		_apply_damage(dmg)
		var pitch := 1.2 if _filling == 1 else 0.88
		Svc.audio().play_sfx("impact", pitch + randf() * 0.1)
	_update_rustle(delta, speed)
	_last_vel = linear_velocity
	_relax_compress(delta)

func _update_rustle(delta: float, speed: float) -> void:
	if _rustle == null or _rustle.stream == null:
		return
	if not _rustle.playing and held:
		_rustle.play()
	var target_db := -80.0
	if speed > 0.35:
		var n := clampf((speed - 0.35) / 4.0, 0.0, 1.0)
		if cargo == Cargo.THIN:
			n *= 1.15
			_rustle.pitch_scale = 1.15
		else:
			_rustle.pitch_scale = 1.0
		target_db = lerpf(-28.0, -8.0, n)
	_rustle.volume_db = lerpf(_rustle.volume_db, target_db, clampf(10.0 * delta, 0.0, 1.0))

func _carry_follow(delta: float) -> void:
	_grab_t = minf(1.0, _grab_t + delta / 0.12)
	var ease := _grab_t * _grab_t * (3.0 - 2.0 * _grab_t)

	var target_xf: Transform3D = _hold_target.global_transform
	target_xf.origin += target_xf.basis * _hold_offset

	# Дыхание + careful/sprint sway
	var breath := sin(Time.get_ticks_msec() * 0.0022) * 0.006
	var sway_amp := 0.01 if careful else 0.032
	if tear_stage >= TearStage.HOLES:
		sway_amp *= 1.45
	var tsec := Time.get_ticks_msec() * 0.001
	target_xf.origin += target_xf.basis.x * sin(tsec * 5.5) * sway_amp
	target_xf.origin += target_xf.basis.y * (breath + sin(tsec * 9.0) * sway_amp * 0.5)

	var desired: Vector3 = target_xf.origin
	# Spring position (тяжесть снизу через отставание)
	var pos_k := POS_K * (0.7 if tear_stage >= TearStage.CRITICAL else 1.0)
	var to := desired - global_position
	_sway_vel = _sway_vel.lerp(to * pos_k, clampf(SWAY_DAMP * delta, 0.0, 1.0))
	var next := global_position + _sway_vel * delta
	global_position = global_position.lerp(next, ease)
	# Anti-jitter когда почти на месте
	if to.length() < 0.008 and _sway_vel.length() < 0.05:
		global_position = desired
		_sway_vel = Vector3.ZERO

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Angular lag сильнее positional
	var q_to := target_xf.basis.get_rotation_quaternion()
	# Низ «отстаёт»: доп. pitch от горизонтальной скорости камеры
	var lag_pitch := clampf(_sway_vel.dot(target_xf.basis.z) * 0.08, -0.25, 0.25)
	q_to = q_to * Quaternion(Vector3.RIGHT, lag_pitch)
	var rot_k := ROT_K * (0.65 if careful else 1.0)
	_ang_lag = _ang_lag.slerp(q_to, clampf(rot_k * delta, 0.0, 1.0))
	global_transform.basis = Basis(_ang_lag)

	var hit_n := _carry_shape_cast_damage(delta, desired)
	if hit_n > 0:
		_compress = minf(0.35, _compress + delta * 2.5)
		if Engine.get_frames_drawn() % 12 == 0:
			Svc.audio().play_sfx("wall_rub" if _streams_has("wall_rub") else "impact", 1.05)
	else:
		_relax_compress(delta)

	if _is_plastic_bag and _body_mi:
		var sq := 1.0 - _compress * 0.55
		_body_mi.scale = _body_base_scale * Vector3(sq, 1.0 + _compress * 0.2, sq)

	if wind_force > 0.0 and randf() < 0.015 * wind_force * delta * 60.0:
		_apply_damage(wind_force * 0.06)
		if hp < max_hp * 0.3 and randf() < 0.05:
			release(Vector3(randf_range(-1, 1), 0.4, randf_range(-1, 1)) * wind_force * 0.3)
	_last_vel = _sway_vel
	_maybe_crumbs(delta)

func _relax_compress(delta: float) -> void:
	_compress = maxf(0.0, _compress - delta * 1.8)
	if _is_plastic_bag and _body_mi and not held:
		_body_mi.scale = _body_mi.scale.lerp(_body_base_scale, clampf(8.0 * delta, 0.0, 1.0))

func _carry_shape_cast_damage(delta: float, desired: Vector3) -> int:
	var space := get_world_3d().direct_space_state
	if space == null or _col == null or _col.shape == null:
		return 0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _col.shape
	q.transform = Transform3D(global_transform.basis, desired + _col.position)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hits := space.intersect_shape(q, 6)
	var hit_n := hits.size()
	if hit_n >= 1:
		var mult := 1.0
		if cargo == Cargo.THIN:
			mult = 2.0
		if careful:
			mult *= 0.5
		var dmg := float(hit_n) * (12.0 if not careful else 5.5) * delta * mult
		# Углы: если нормаль «острая» — сильнее (эвристика: много хитов)
		if hit_n >= 3:
			dmg *= 1.4
		_apply_damage(dmg)
	return hit_n

func _maybe_crumbs(delta: float) -> void:
	if tear_stage < TearStage.HOLES or _crumb_particles == null:
		return
	if randf() < (0.08 if tear_stage == TearStage.HOLES else 0.2) * delta * 60.0:
		_crumb_particles.emitting = true
		_crumb_particles.restart()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if bursted or held:
		return
	var contact_count := state.get_contact_count()
	var thr := impact_threshold * (2.0 if careful else 1.6)
	for i in range(contact_count):
		var impulse := state.get_contact_impulse(i).length()
		if impulse > thr:
			_debug_last_impulse = impulse
			var dmg := impulse * 1.5
			if careful:
				dmg *= 0.55
			if cargo == Cargo.THIN:
				dmg *= 1.5
			_apply_damage(dmg)
			var pitch := 1.15 if _filling == 1 else 0.92
			Svc.audio().play_sfx("impact", pitch + randf() * 0.08)

func _tear_stage_for_hp() -> TearStage:
	var r := hp / maxf(max_hp, 0.01)
	if r > 0.75:
		return TearStage.WHOLE
	if r > 0.45:
		return TearStage.WORN
	if r > 0.2:
		return TearStage.HOLES
	if r > 0.0:
		return TearStage.CRITICAL
	return TearStage.BURST

func _apply_damage(amount: float) -> void:
	if bursted or amount <= 0.0:
		return
	if careful and _is_plastic_bag:
		amount *= 0.5  # visual tear rate / damage
	hp = maxf(0.0, hp - amount)
	tear_stage = _tear_stage_for_hp()
	_update_damage_visual()
	damaged.emit(hp, max_hp)
	if hp <= 0.0:
		_do_burst()

func _update_damage_visual() -> void:
	if _mat == null:
		return
	var t := 1.0 - (hp / maxf(max_hp, 0.01))
	# Порча через albedo/alpha — без emission-лавы
	_mat.emission_enabled = false
	var dirt := Color(0.28, 0.18, 0.10)
	_mat.albedo_color = _base_color.lerp(dirt, t * 0.55)
	if cargo == Cargo.THIN:
		_mat.albedo_color.a = lerpf(0.82, 0.55, t)
	# Шов темнеет / «дыры»
	if _seam_mi and _seam_mi.material_override is StandardMaterial3D:
		var sm: StandardMaterial3D = _seam_mi.material_override
		sm.albedo_color = _base_color.darkened(0.2 + t * 0.5)
		if tear_stage >= TearStage.HOLES:
			sm.albedo_color = Color(0.15, 0.08, 0.05)
			_seam_mi.scale = Vector3(1.0 + t, 1.0, 1.0 + t * 2.0)
	# Критика — содержимое просвечивает (теплее)
	if tear_stage >= TearStage.CRITICAL and _body_mi:
		_mat.albedo_color = _mat.albedo_color.lerp(Color(0.4, 0.28, 0.12), 0.35)

func _do_burst() -> void:
	if bursted:
		return
	bursted = true
	tear_stage = TearStage.BURST
	held = false
	_hold_target = null
	Svc.audio().play_sfx("burst", 0.95)
	# слой «содержимого»
	Svc.audio().play_sfx("impact", 0.7 if _filling == 0 else 1.25)
	if _rustle:
		_rustle.stop()
	if _particles:
		_particles.restart()
		_particles.emitting = true
	_spawn_trash_pieces()
	# Плёнка остаётся лохмотьями
	if _is_plastic_bag:
		if _body_mi:
			_body_mi.visible = false
		if _neck_mi:
			_neck_mi.visible = false
		if _handle_l:
			_handle_l.visible = false
		if _handle_r:
			_handle_r.visible = false
		if _seam_mi:
			_seam_mi.visible = false
		if _rag_left:
			_rag_left.visible = true
		if _rag_right:
			_rag_right.visible = true
	elif _mesh:
		_mesh.visible = false
	freeze = true
	collision_layer = 0
	burst.emit()

func _spawn_trash_pieces() -> void:
	if _pieces_spawned:
		return
	_pieces_spawned = true
	var n := 16 if _is_plastic_bag else 8
	if cargo == Cargo.FRIDGE:
		n = 10
	if cargo == Cargo.THIN:
		n = 14
	var kinds := ["scrap", "bottle", "banana", "box", "paper", "bone", "can"]
	var space := get_world_3d().direct_space_state
	for i in range(n):
		var piece_scr = preload("res://scripts/trash_piece.gd")
		var piece = piece_scr.new()
		piece.collision_layer = 8
		piece.collision_mask = 1
		piece.mass = 0.18
		piece.physics_material_override = PhysicsMaterial.new()
		piece.physics_material_override.friction = 0.85
		piece.physics_material_override.bounce = 0.05
		var kind: String = kinds[i % kinds.size()]
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		match kind:
			"bottle":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.035
				cyl.bottom_radius = 0.045
				cyl.height = 0.2
				mi.mesh = cyl
				mat.albedo_color = Color(0.25, 0.55, 0.8)
				mat.roughness = 0.25
			"banana":
				var ban := CapsuleMesh.new()
				ban.radius = 0.035
				ban.height = 0.16
				mi.mesh = ban
				mat.albedo_color = Color(0.92, 0.8, 0.18)
			"paper":
				var pb := BoxMesh.new()
				pb.size = Vector3(0.12, 0.01, 0.09)
				mi.mesh = pb
				mat.albedo_color = Color(0.85, 0.82, 0.72)
			"can":
				var can := CylinderMesh.new()
				can.top_radius = 0.04
				can.bottom_radius = 0.04
				can.height = 0.1
				mi.mesh = can
				mat.albedo_color = Color(0.55, 0.55, 0.5)
				mat.metallic = 0.6
			"bone":
				var bone := CapsuleMesh.new()
				bone.radius = 0.02
				bone.height = 0.12
				mi.mesh = bone
				mat.albedo_color = Color(0.9, 0.88, 0.8)
			_:
				var bm := BoxMesh.new()
				bm.size = Vector3(randf_range(0.06, 0.14), randf_range(0.04, 0.1), randf_range(0.06, 0.12))
				mi.mesh = bm
				mat.albedo_color = Color(randf_range(0.2, 0.8), randf_range(0.15, 0.6), randf_range(0.1, 0.4))
		mi.material_override = mat
		piece.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.07
		cs.shape = sh
		piece.add_child(cs)
		get_parent().add_child(piece)
		var spawn := global_position + Vector3(randf_range(-0.25, 0.25), randf_range(0.05, 0.35), randf_range(-0.25, 0.25))
		# Не спавнить в стене — луч вниз
		if space:
			var rq := PhysicsRayQueryParameters3D.create(spawn + Vector3(0, 0.4, 0), spawn + Vector3(0, -0.8, 0))
			rq.collision_mask = 1
			var hit := space.intersect_ray(rq)
			if not hit.is_empty():
				spawn = hit.position + Vector3(0, 0.08, 0)
		piece.global_position = spawn
		piece.apply_central_impulse(Vector3(randf_range(-3.5, 3.5), randf_range(2.0, 5.5), randf_range(-3.5, 3.5)))
		piece.setup_piece(game)

func add_to_armful() -> void:
	armful_count += 1

func get_debug_info() -> Dictionary:
	return {
		"hp": hp,
		"stage": tear_stage,
		"impulse": _debug_last_impulse,
		"compress": _compress,
		"held": held,
		"filling": _filling,
	}
