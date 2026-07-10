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

func _build() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.2 if kind == Kind.BABUSHKA else 0.6
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
	add_child(col)

	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if kind == Kind.BABUSHKA:
		mat.albedo_color = Color(0.75, 0.55, 0.65)
		var body := CapsuleMesh.new()
		body.radius = 0.28
		body.height = 1.2
		_mesh.mesh = body
		_mesh.position = Vector3(0, 0.7, 0)
	else:
		mat.albedo_color = Color(0.35, 0.28, 0.2)
		var dog := BoxMesh.new()
		dog.size = Vector3(0.7, 0.45, 0.35)
		_mesh.mesh = dog
		_mesh.position = Vector3(0, 0.3, 0)
	_mesh.material_override = mat
	add_child(_mesh)

func set_player(p: Node3D) -> void:
	_target_player = p

func _player_in_yard(p: Node3D) -> bool:
	## Бабушки/собаки не видят сквозь этажи — только двор у земли.
	return p.global_position.y < 1.6 and p.global_position.z > 4.0

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
	if dist > aggro_range:
		return
	var to_p := (_target_player.global_position - global_position)
	to_p.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01 or to_p.length() < 0.01:
		return
	var ang := rad_to_deg(forward.normalized().angle_to(to_p.normalized()))
	if kind == Kind.DOG:
		if dist < 2.0:
			_caught = true
			Svc.audio().play_sfx("bark")
			barked.emit()
			spotted.emit(kind)
		elif dist < aggro_range and ang < vision_angle:
			velocity = to_p.normalized() * speed * 1.5
	else:
		# Бабушка: узкий конус, только если смотрит на тебя
		if ang < vision_angle and dist < aggro_range:
			_caught = true
			Svc.audio().play_sfx("babushka")
			spotted.emit(kind)
