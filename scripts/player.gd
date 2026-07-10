class_name TrashPlayer
extends CharacterBody3D
## FPS-игрок: WASD, бег, присед, прыжок, несёт груз.

const WALK := 4.0
const SPRINT := 6.2
const CROUCH := 2.0
const JUMP_V := 5.2
const BASE_SENS := 0.0024

signal slipped
signal fell_hard

var game: Node = null
var active: bool = true
var on_ice: bool = false
var ice_factor: float = 1.0
var flashlight_on: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0
var camera: Camera3D
var flashlight: SpotLight3D
var hold_point: Node3D
var _col: CollisionShape3D
var _crouching: bool = false
var _slip_cd: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_col = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.5
	_col.shape = shape
	_col.position = Vector3(0, 0.95, 0)
	add_child(_col)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.position = Vector3(0, 1.55, 0)
	add_child(camera)

	hold_point = Node3D.new()
	hold_point.name = "HoldPoint"
	hold_point.position = Vector3(0.35, -0.25, -0.55)
	camera.add_child(hold_point)

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.95, 0.97, 1.0)
	flashlight.light_energy = 3.5
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 28.0
	flashlight.shadow_enabled = false
	flashlight.visible = false
	flashlight.position = Vector3(0.1, -0.05, -0.1)
	camera.add_child(flashlight)

	floor_snap_length = 0.15
	floor_max_angle = deg_to_rad(48.0)

func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := BASE_SENS * float(Svc.meta().settings.get("mouse_sens", 1.0))
		_yaw -= event.relative.x * sens
		_pitch -= event.relative.y * sens
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _yaw
		camera.rotation.x = _pitch
	if event.is_action_pressed("toggle_flashlight") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_F):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on

func _physics_process(delta: float) -> void:
	if not active:
		return
	_slip_cd = maxf(0.0, _slip_cd - delta)
	var grav := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= grav * delta

	_crouching = Input.is_action_pressed("crouch")
	var speed := CROUCH if _crouching else (SPRINT if Input.is_action_pressed("sprint") else WALK)
	if on_ice:
		speed *= 0.85

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target := dir * speed
	var accel := 18.0 if is_on_floor() else 6.0
	if on_ice and is_on_floor():
		accel = 3.5
		# Скольжение при спринте
		if Input.is_action_pressed("sprint") and dir.length() > 0.1 and _slip_cd <= 0.0 and randf() < 0.015:
			_slip_cd = 1.2
			velocity += dir.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * 6.0
			velocity.y = 2.0
			slipped.emit()
			Svc.audio().play_sfx("slip")

	velocity.x = move_toward(velocity.x, target.x, accel * delta * ice_factor)
	velocity.z = move_toward(velocity.z, target.z, accel * delta * ice_factor)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_V * (0.7 if _crouching else 1.0)

	var was_floor := is_on_floor()
	move_and_slide()
	if was_floor and not is_on_floor() and velocity.y < -8.0:
		fell_hard.emit()

	# Высота капсулы при приседе
	var target_h := 1.1 if _crouching else 1.5
	var sh: CapsuleShape3D = _col.shape
	sh.height = lerpf(sh.height, target_h, 12.0 * delta)
	_col.position.y = sh.height * 0.5 + 0.2
	camera.position.y = lerpf(camera.position.y, 1.15 if _crouching else 1.55, 12.0 * delta)
