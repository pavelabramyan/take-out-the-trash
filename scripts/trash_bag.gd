class_name TrashBag
extends RigidBody3D
## Груз с уронной коллизией в руках (spring-follow) и при дропе.

signal burst
signal damaged(hp_left: float, max_hp: float)
signal dumped

enum Cargo { BAG, BUCKETS, CARPET, FRIDGE, THIN }

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

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _hold_target: Node3D = null
var _mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _last_vel: Vector3 = Vector3.ZERO
var _pieces_spawned: bool = false
var _particles: GPUParticles3D = null
var _base_color: Color = Color(0.15, 0.45, 0.22)
var _hold_offset: Vector3 = Vector3.ZERO
var _yaw_slow: float = 1.0

func setup(kind: String, bag_hp: float) -> void:
	max_hp = bag_hp
	hp = bag_hp
	match kind:
		"buckets":
			cargo = Cargo.BUCKETS
			impact_threshold = 4.5
			_hold_offset = Vector3(0.15, -0.1, 0.05)
			_yaw_slow = 0.75
		"carpet":
			cargo = Cargo.CARPET
			impact_threshold = 5.0
			_hold_offset = Vector3(0.0, -0.15, -0.1)
			_yaw_slow = 0.45
		"fridge":
			cargo = Cargo.FRIDGE
			impact_threshold = 6.0
			_hold_offset = Vector3(0.1, -0.55, 0.0)
			_yaw_slow = 0.35
		"thin":
			cargo = Cargo.THIN
			impact_threshold = 2.2
			_hold_offset = Vector3.ZERO
			_yaw_slow = 1.0
		_:
			cargo = Cargo.BAG
			impact_threshold = 3.2
			_hold_offset = Vector3.ZERO
			_yaw_slow = 1.0
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
	add_to_group("trash_bag")

func _mass_for_cargo() -> float:
	match cargo:
		Cargo.BUCKETS: return 4.0
		Cargo.CARPET: return 6.0
		Cargo.FRIDGE: return 18.0
		Cargo.THIN: return 1.1
		_: return 1.6

func speed_mult() -> float:
	match cargo:
		Cargo.BUCKETS: return 0.85
		Cargo.CARPET: return 0.65
		Cargo.FRIDGE: return 0.45
		Cargo.THIN: return 1.05
		_: return 1.0

func fov_offset() -> float:
	match cargo:
		Cargo.CARPET: return -4.0
		Cargo.FRIDGE: return -8.0
		_: return 0.0

func yaw_mult() -> float:
	return _yaw_slow

func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.85
	match cargo:
		Cargo.BUCKETS:
			_base_color = Color(0.35, 0.45, 0.55)
		Cargo.CARPET:
			_base_color = Color(0.55, 0.22, 0.18)
		Cargo.FRIDGE:
			_base_color = Color(0.85, 0.88, 0.92)
		Cargo.THIN:
			_base_color = Color(0.2, 0.55, 0.3)
		_:
			_base_color = Color(0.12, 0.48, 0.22)
	_mat.albedo_color = _base_color

	_mesh = MeshInstance3D.new()
	_col = CollisionShape3D.new()
	match cargo:
		Cargo.BUCKETS:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.2
			cyl.height = 0.45
			_mesh.mesh = cyl
			var sh := CylinderShape3D.new()
			sh.radius = 0.2
			sh.height = 0.45
			_col.shape = sh
		Cargo.CARPET:
			var box := BoxMesh.new()
			box.size = Vector3(1.4, 0.12, 0.45)
			_mesh.mesh = box
			var sh2 := BoxShape3D.new()
			sh2.size = box.size
			_col.shape = sh2
		Cargo.FRIDGE:
			var box2 := BoxMesh.new()
			box2.size = Vector3(0.65, 1.5, 0.6)
			_mesh.mesh = box2
			var sh3 := BoxShape3D.new()
			sh3.size = box2.size
			_col.shape = sh3
			_col.position = Vector3(0, 0.75, 0)
			_mesh.position = Vector3(0, 0.75, 0)
		Cargo.THIN:
			var bag_t := BoxMesh.new()
			bag_t.size = Vector3(0.28, 0.5, 0.12)
			_mesh.mesh = bag_t
			var sh_t := BoxShape3D.new()
			sh_t.size = bag_t.size
			_col.shape = sh_t
		_:
			# Полиэтиленовый «пакет» — слегка сплюснутый
			var bag := BoxMesh.new()
			bag.size = Vector3(0.38, 0.48, 0.2)
			_mesh.mesh = bag
			var sh4 := BoxShape3D.new()
			sh4.size = bag.size
			_col.shape = sh4
	_mesh.material_override = _mat
	add_child(_mesh)
	add_child(_col)
	_build_burst_particles()

func _build_burst_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 28
	_particles.lifetime = 0.7
	_particles.explosiveness = 0.95
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.14
	mat.color = Color(0.4, 0.7, 0.3)
	_particles.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.06
	draw.height = 0.12
	_particles.draw_pass_1 = draw
	add_child(_particles)

func grab(hold: Node3D) -> void:
	_hold_target = hold
	held = true
	# Follow к hold_point без борьбы с миром; урон — от raycast при упоре
	freeze = false
	gravity_scale = 0.0
	linear_damp = 12.0
	angular_damp = 14.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 4
	collision_mask = 0

func release(impulse: Vector3 = Vector3.ZERO) -> void:
	held = false
	_hold_target = null
	freeze = false
	gravity_scale = 1.0
	linear_damp = 0.4
	angular_damp = 1.2
	collision_layer = 4
	collision_mask = 1
	linear_velocity = impulse

func throw_forward(dir: Vector3, strength: float = 7.0) -> void:
	release(dir.normalized() * strength + Vector3(0, 1.5, 0))

func drop_gentle() -> void:
	release(Vector3(0, -0.8, 0))

func apply_fall_damage(speed: float) -> void:
	if speed < 6.0:
		return
	var dmg := (speed - 6.0) * 12.0
	if careful:
		dmg *= 0.55
	_apply_damage(dmg)
	Svc.audio().play_sfx("impact", 0.85)

func _physics_process(delta: float) -> void:
	if bursted:
		return
	if held and _hold_target:
		_carry_follow(delta)
		return
	var speed := linear_velocity.length()
	var delta_v := (_last_vel - linear_velocity).length()
	var thr := impact_threshold * (1.35 if careful else 1.0)
	if delta_v > thr and speed > 1.2:
		var dmg := (delta_v - thr) * 8.0
		if careful:
			dmg *= 0.5
		_apply_damage(dmg)
		Svc.audio().play_sfx("impact", 0.9 + randf() * 0.2)
	_last_vel = linear_velocity

func _carry_follow(delta: float) -> void:
	var target_xf: Transform3D = _hold_target.global_transform
	target_xf.origin += target_xf.basis * _hold_offset
	var sway := 0.012 if careful else 0.028
	target_xf.basis = target_xf.basis.rotated(Vector3.RIGHT, sin(Time.get_ticks_msec() * 0.008) * sway)
	var desired: Vector3 = target_xf.origin
	# Плавный follow без физики-борьбы
	global_position = global_position.lerp(desired, clampf(18.0 * delta, 0.0, 1.0))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var q_from := global_transform.basis.get_rotation_quaternion()
	var q_to := target_xf.basis.get_rotation_quaternion()
	global_transform.basis = Basis(q_from.slerp(q_to, clampf(12.0 * delta, 0.0, 1.0)))
	# Урон: если hold упирается в стену (ray от игрока к пакету / вокруг)
	_carry_wall_damage(delta, desired)
	if wind_force > 0.0 and randf() < 0.015 * wind_force * delta * 60.0:
		_apply_damage(wind_force * 0.06)
		if hp < max_hp * 0.3 and randf() < 0.05:
			release(Vector3(randf_range(-1, 1), 0.4, randf_range(-1, 1)) * wind_force * 0.3)
	_last_vel = linear_velocity

func _carry_wall_damage(delta: float, desired: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	# Короткие лучи от центра пакета наружу
	var dirs := [
		Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN
	]
	var hit_n := 0
	for d in dirs:
		var from := desired
		var to := desired + (d as Vector3).normalized() * 0.38
		var rq := PhysicsRayQueryParameters3D.create(from, to)
		rq.collision_mask = 1
		rq.exclude = [get_rid()]
		var hit := space.intersect_ray(rq)
		if not hit.is_empty():
			hit_n += 1
	if hit_n >= 2:
		var dmg := float(hit_n) * (14.0 if not careful else 6.0) * delta
		_apply_damage(dmg)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if bursted or held:
		return
	var contact_count := state.get_contact_count()
	var thr := impact_threshold * (2.0 if careful else 1.6)
	for i in range(contact_count):
		var impulse := state.get_contact_impulse(i).length()
		if impulse > thr:
			var dmg := impulse * 1.5
			if careful:
				dmg *= 0.55
			_apply_damage(dmg)
			Svc.audio().play_sfx("impact", 0.95 + randf() * 0.1)

func _apply_damage(amount: float) -> void:
	if bursted or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	var t := 1.0 - (hp / max_hp)
	_mat.albedo_color = _base_color.lerp(Color(0.35, 0.22, 0.12), t * 0.75)
	# Трещины — emission flicker
	_mat.emission_enabled = t > 0.35
	if _mat.emission_enabled:
		_mat.emission = Color(0.5, 0.2, 0.05) * t
		_mat.emission_energy_multiplier = t * 1.2
	damaged.emit(hp, max_hp)
	if hp <= 0.0:
		_do_burst()

func _do_burst() -> void:
	if bursted:
		return
	bursted = true
	held = false
	_hold_target = null
	Svc.audio().play_sfx("burst")
	if _particles:
		_particles.restart()
		_particles.emitting = true
	_spawn_trash_pieces()
	_mesh.visible = false
	freeze = true
	collision_layer = 0
	burst.emit()

func _spawn_trash_pieces() -> void:
	if _pieces_spawned:
		return
	_pieces_spawned = true
	var n := 8 if cargo == Cargo.BAG or cargo == Cargo.THIN else 5
	if cargo == Cargo.FRIDGE:
		n = 10
	var kinds := ["scrap", "bottle", "banana", "box"]
	for i in range(n):
		var piece_scr = preload("res://scripts/trash_piece.gd")
		var piece = piece_scr.new()
		piece.collision_layer = 8
		piece.collision_mask = 1
		piece.mass = 0.2
		var kind: String = kinds[i % kinds.size()]
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		match kind:
			"bottle":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.04
				cyl.bottom_radius = 0.05
				cyl.height = 0.22
				mi.mesh = cyl
				mat.albedo_color = Color(0.3, 0.6, 0.85)
			"banana":
				var ban := CapsuleMesh.new()
				ban.radius = 0.04
				ban.height = 0.18
				mi.mesh = ban
				mat.albedo_color = Color(0.95, 0.85, 0.2)
			_:
				var bm := BoxMesh.new()
				bm.size = Vector3(randf_range(0.08, 0.16), randf_range(0.05, 0.12), randf_range(0.08, 0.14))
				mi.mesh = bm
				mat.albedo_color = Color(randf_range(0.2, 0.9), randf_range(0.2, 0.7), randf_range(0.1, 0.5))
		mi.material_override = mat
		piece.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.08
		cs.shape = sh
		piece.add_child(cs)
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.1, 0.5), randf_range(-0.3, 0.3))
		piece.apply_central_impulse(Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)))
		piece.setup_piece(game)

func add_to_armful() -> void:
	armful_count += 1
