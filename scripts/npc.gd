class_name StairNpc
extends CharacterBody3D
## Сосед: бабушка-детектор или собака. Только во дворе, не сквозь этажи.

enum Kind { BABUSHKA, DOG }

signal spotted(kind: Kind)
signal barked

var kind: Kind = Kind.BABUSHKA
var aggro_range: float = 4.5
var vision_angle: float = 50.0
var patrol_a: Vector3
var patrol_b: Vector3
var speed: float = 1.4
var active: bool = true
var game: Node = null
## Задержка, чтобы не ловить игрока в момент выхода из подъезда
var grace: float = 2.5

var _target_player: Node3D = null
var _t: float = 0.0
var _mesh: MeshInstance3D
var _caught: bool = false
var _alive: float = 0.0

func setup(k: Kind, a: Vector3, b: Vector3, g: Node) -> void:
	kind = k
	patrol_a = a
	patrol_b = b
	game = g
	global_position = a
	collision_layer = 16
	collision_mask = 1
	_build()
	if kind == Kind.DOG:
		speed = 3.0
		aggro_range = 4.0
		vision_angle = 80.0
		grace = 1.5
	else:
		speed = 1.0
		aggro_range = 4.2
		vision_angle = 45.0
		grace = 2.5

func _mat(c: Color, rough: float = 0.9, wool: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if wool and ResourceLoader.exists("res://assets/textures/wool.png"):
		m.albedo_texture = load("res://assets/textures/wool.png")
		m.uv1_scale = Vector3(2.4, 2.4, 2.4)
	return m

func _add_box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _add_sph(parent: Node3D, r: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _add_cap(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _build() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.2 if kind == Kind.BABUSHKA else 0.6
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
	add_child(col)
	if kind == Kind.BABUSHKA:
		_build_babushka()
	else:
		_build_dog()

func _build_babushka() -> void:
	# Лицо из примитивов выдаёт себя мгновенно, поэтому фигура тёмная и
	# сгорбленная: в полумраке подъезда читается силуэт, а не игрушка
	var coat := _mat(Color(0.17, 0.15, 0.17), 0.96, true)
	var skin := _mat(Color(0.42, 0.33, 0.28), 0.85)
	var scarf := _mat(Color(0.24, 0.21, 0.24), 0.94, true)
	var boot := _mat(Color(0.08, 0.07, 0.07), 0.72)
	var bag_m := _mat(Color(0.16, 0.13, 0.10), 0.9)
	# Корпус наклонён вперёд — узнаваемая согнутая спина
	_mesh = _add_cap(self, 0.27, 1.0, coat, Vector3(0, 0.64, 0.02), Vector3(9, 0, 0))
	_add_cap(self, 0.29, 0.34, coat, Vector3(0, 0.28, 0.0))
	_add_sph(self, 0.115, skin, Vector3(0, 1.16, 0.08))
	# Платок: две доли и узел под подбородком
	_add_sph(self, 0.135, scarf, Vector3(0, 1.20, 0.05))
	_add_cap(self, 0.055, 0.16, scarf, Vector3(0, 1.06, 0.13), Vector3(24, 0, 0))
	_add_cap(self, 0.10, 0.30, scarf, Vector3(0, 0.99, -0.02), Vector3(-8, 0, 0))
	_add_cap(self, 0.05, 0.44, coat, Vector3(-0.23, 0.68, 0.06), Vector3(14, 0, 16))
	_add_cap(self, 0.05, 0.44, coat, Vector3(0.24, 0.60, 0.10), Vector3(22, -12, -26))
	for sx in [-0.10, 0.10]:
		_add_cap(self, 0.055, 0.34, boot, Vector3(sx, 0.20, 0.0))
		_add_cap(self, 0.055, 0.14, boot, Vector3(sx, 0.05, 0.03), Vector3(90, 0, 0))
	_add_cap(self, 0.09, 0.26, bag_m, Vector3(0.30, 0.44, 0.10), Vector3(6, -18, 10))

func _build_dog() -> void:
	# Дворовый пёс: тёмная шерсть и капсулы вместо кубиков
	var fur := _mat(Color(0.15, 0.13, 0.12), 0.96)
	var dark := _mat(Color(0.07, 0.06, 0.06), 0.92)
	var nose := _mat(Color(0.05, 0.05, 0.05), 0.55)
	_mesh = _add_cap(self, 0.135, 0.52, fur, Vector3(0, 0.34, 0.04), Vector3(90, 0, 0))
	_add_cap(self, 0.115, 0.34, fur, Vector3(0, 0.36, -0.16), Vector3(80, 0, 0))
	_add_sph(self, 0.10, fur, Vector3(0, 0.42, -0.30))
	_add_cap(self, 0.055, 0.20, fur, Vector3(0, 0.38, -0.40), Vector3(84, 0, 0))
	_add_sph(self, 0.028, nose, Vector3(0, 0.38, -0.49))
	# Уши висят вдоль головы
	for ex in [-0.07, 0.07]:
		_add_cap(self, 0.028, 0.13, dark, Vector3(ex, 0.46, -0.27), Vector3(16, 0, signf(ex) * 28.0))
	for lx in [-0.075, 0.075]:
		for lz in [-0.16, 0.16]:
			_add_cap(self, 0.032, 0.26, fur, Vector3(lx, 0.15, lz), Vector3(signf(lz) * 6.0, 0, 0))
			_add_cap(self, 0.038, 0.07, dark, Vector3(lx, 0.035, lz - 0.02), Vector3(90, 0, 0))
	_add_cap(self, 0.022, 0.26, fur, Vector3(0, 0.40, 0.30), Vector3(48, 0, 0))

func set_player(p: Node3D) -> void:
	_target_player = p

func _player_in_yard(p: Node3D) -> bool:
	## Бабушки/собаки не видят сквозь этажи — только двор у земли.
	return p.global_position.y < 1.6 and p.global_position.z > 4.0

func _player_stealthed(p: Node3D) -> bool:
	## Присед режет конус зрения.
	if p.get("careful") == true:
		return true
	if p.get("_crouching") == true:
		return true
	return false

func _physics_process(delta: float) -> void:
	if not active or _caught:
		return
	_alive += delta
	_t += delta
	var phase := (sin(_t * speed * 0.35) + 1.0) * 0.5
	var dest := patrol_a.lerp(patrol_b, phase)
	var to := dest - global_position
	to.y = 0.0
	if to.length() > 0.15:
		velocity = to.normalized() * speed
		look_at(global_position + to.normalized(), Vector3.UP)
	else:
		velocity = Vector3.ZERO
	velocity.y = -2.0
	move_and_slide()

	if _target_player == null or _alive < grace:
		return
	if not _player_in_yard(_target_player):
		return

	var dist := global_position.distance_to(_target_player.global_position)
	var range_m := aggro_range
	var ang_m := vision_angle
	if _player_stealthed(_target_player):
		range_m *= 0.45
		ang_m *= 0.55
	if dist > range_m:
		return
	var to_p := (_target_player.global_position - global_position)
	to_p.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01 or to_p.length() < 0.01:
		return
	var ang := rad_to_deg(forward.normalized().angle_to(to_p.normalized()))
	# Поведения собак: 0 трусливая, 1 злая, 2 хочет пакет
	var dog_mood := int(abs(get_instance_id())) % 3
	if kind == Kind.DOG:
		Svc.audio().set_danger(dist < range_m)
		if dog_mood == 0 and dist < 3.0:
			# Трусливая — отбегает
			velocity = -to_p.normalized() * speed
			return
		if dist < 2.0:
			_caught = true
			Svc.audio().play_sfx("bark")
			barked.emit()
			spotted.emit(kind)
		elif dist < range_m and ang < ang_m:
			velocity = to_p.normalized() * speed * (1.8 if dog_mood == 1 else 1.3)
	else:
		if ang < ang_m and dist < range_m:
			_caught = true
			Svc.audio().play_sfx("babushka")
			spotted.emit(kind)
