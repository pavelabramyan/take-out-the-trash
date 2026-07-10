class_name TrashBag
extends RigidBody3D
## Физический груз: пакет / вёдра / ковёр / холодильник. Рвётся от ударов.

signal burst
signal damaged(hp_left: float, max_hp: float)
signal dumped

enum Cargo { BAG, BUCKETS, CARPET, FRIDGE }

var cargo: Cargo = Cargo.BAG
var max_hp: float = 100.0
var hp: float = 100.0
var held: bool = false
var bursted: bool = false
var impact_threshold: float = 3.5
var wind_force: float = 0.0
var game: Node = null

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _hold_target: Node3D = null
var _mat: StandardMaterial3D
var _last_vel: Vector3 = Vector3.ZERO
var _pieces_spawned: bool = false

func setup(kind: String, bag_hp: float) -> void:
	max_hp = bag_hp
	hp = bag_hp
	match kind:
		"buckets":
			cargo = Cargo.BUCKETS
			impact_threshold = 4.5
		"carpet":
			cargo = Cargo.CARPET
			impact_threshold = 5.0
		"fridge":
			cargo = Cargo.FRIDGE
			impact_threshold = 6.0
		_:
			cargo = Cargo.BAG
			impact_threshold = 3.2
	_build_visual()
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	collision_layer = 4
	collision_mask = 1 | 4 | 8
	mass = _mass_for_cargo()
	gravity_scale = 1.0
	linear_damp = 0.4
	angular_damp = 1.2

func _mass_for_cargo() -> float:
	match cargo:
		Cargo.BUCKETS: return 4.0
		Cargo.CARPET: return 6.0
		Cargo.FRIDGE: return 18.0
		_: return 1.6

func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.85
	match cargo:
		Cargo.BUCKETS:
			_mat.albedo_color = Color(0.35, 0.45, 0.55)
		Cargo.CARPET:
			_mat.albedo_color = Color(0.55, 0.22, 0.18)
		Cargo.FRIDGE:
			_mat.albedo_color = Color(0.85, 0.88, 0.92)
		_:
			_mat.albedo_color = Color(0.15, 0.45, 0.22)

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
		_:
			var bag := BoxMesh.new()
			bag.size = Vector3(0.35, 0.45, 0.22)
			_mesh.mesh = bag
			var sh4 := BoxShape3D.new()
			sh4.size = bag.size
			_col.shape = sh4
	_mesh.material_override = _mat
	add_child(_mesh)
	add_child(_col)

func grab(hold: Node3D) -> void:
	_hold_target = hold
	held = true
	freeze = true
	# Скрываем коллизию с игроком пока несём — двигаем кинематически
	collision_layer = 0
	collision_mask = 0

func release(impulse: Vector3 = Vector3.ZERO) -> void:
	held = false
	_hold_target = null
	freeze = false
	collision_layer = 4
	collision_mask = 1 | 4 | 8
	linear_velocity = impulse
	apply_central_impulse(impulse)

func _physics_process(delta: float) -> void:
	if bursted:
		return
	if held and _hold_target:
		global_transform = _hold_target.global_transform
		# Лёгкое покачивание
		rotate_object_local(Vector3.RIGHT, sin(Time.get_ticks_msec() * 0.008) * 0.02)
		if wind_force > 0.0 and randf() < 0.02 * wind_force * delta * 60.0:
			# Ветер пытается вырвать
			var yank := Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)).normalized() * wind_force * 0.15
			_apply_damage(wind_force * 0.08)
			if hp < max_hp * 0.35 and randf() < 0.08:
				release(yank * 2.0)
		return

	# Урон от ударов когда не в руках
	var speed := linear_velocity.length()
	var delta_v := (_last_vel - linear_velocity).length()
	if delta_v > impact_threshold and speed > 1.5:
		var dmg := (delta_v - impact_threshold) * 8.0
		_apply_damage(dmg)
		Svc.audio().play_sfx("impact", 0.9 + randf() * 0.2)
	_last_vel = linear_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if held or bursted:
		return
	var contact_count := state.get_contact_count()
	for i in range(contact_count):
		var impulse := state.get_contact_impulse(i).length()
		if impulse > impact_threshold * 2.0:
			_apply_damage(impulse * 1.5)

func _apply_damage(amount: float) -> void:
	if bursted:
		return
	hp = maxf(0.0, hp - amount)
	# Визуал: зелёный → дырявый коричневый
	var t := 1.0 - (hp / max_hp)
	_mat.albedo_color = _mat.albedo_color.lerp(Color(0.35, 0.25, 0.15), t * 0.5)
	damaged.emit(hp, max_hp)
	if hp <= 0.0:
		_do_burst()

func _do_burst() -> void:
	if bursted:
		return
	bursted = true
	Svc.audio().play_sfx("burst")
	_spawn_trash_pieces()
	_mesh.visible = false
	freeze = true
	collision_layer = 0
	burst.emit()

func _spawn_trash_pieces() -> void:
	if _pieces_spawned:
		return
	_pieces_spawned = true
	var n := 8 if cargo == Cargo.BAG else 5
	for i in range(n):
		var piece_scr = preload("res://scripts/trash_piece.gd")
		var piece = piece_scr.new()
		piece.collision_layer = 8
		piece.collision_mask = 1
		piece.mass = 0.2
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.08, 0.18), randf_range(0.05, 0.12), randf_range(0.08, 0.16))
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0.2, 0.9), randf_range(0.2, 0.7), randf_range(0.1, 0.5))
		mi.material_override = mat
		piece.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bm.size
		cs.shape = sh
		piece.add_child(cs)
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.1, 0.5), randf_range(-0.3, 0.3))
		piece.apply_central_impulse(Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)))
		piece.setup_piece(game)

func heal_full() -> void:
	# После сбора всего мусора — «новый пакет» не даём, но можно продолжить с кусками
	pass
