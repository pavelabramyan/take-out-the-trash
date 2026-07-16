class_name TrashPlayer
extends CharacterBody3D
## FPS: вес груза, careful-режим, бросок/дроп, геймпад, invert Y.

const WALK := 4.0
const SPRINT := 6.2
const CROUCH := 2.0
const JUMP_V := 3.6
const BASE_SENS := 0.0024

signal slipped
signal fell_hard(fall_speed: float)
signal throw_pressed
signal drop_pressed

var game: Node = null
var active: bool = true
var on_ice: bool = false
var ice_factor: float = 1.0
var flashlight_on: bool = false
var cargo_speed_mult: float = 1.0
var cargo_fov: float = 0.0
var cargo_yaw_mult: float = 1.0
var careful: bool = false
var invert_y: bool = false
var base_fov: float = 75.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var camera: Camera3D
var flashlight: SpotLight3D
var hold_point: Node3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D
var _col: CollisionShape3D
var _crouching: bool = false
var _slip_cd: float = 0.0
var _air_time: float = 0.0
var _max_fall_speed: float = 0.0
var _step_acc: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	invert_y = bool(Svc.meta().settings.get("invert_y", false))
	base_fov = float(Svc.meta().settings.get("fov", 75.0))
	_ensure_gamepad_bindings()
	_build_body()

func _build_body() -> void:
	_col = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.5
	_col.shape = shape
	_col.position = Vector3(0, 0.95, 0)
	add_child(_col)

	camera = Camera3D.new()
	camera.fov = base_fov
	camera.position = Vector3(0, 1.55, 0)
	add_child(camera)

	hold_point = Node3D.new()
	hold_point.name = "HoldPoint"
	hold_point.position = Vector3(0.35, -0.25, -0.55)
	camera.add_child(hold_point)

	_build_hands()

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.95, 0.97, 1.0)
	flashlight.light_energy = 3.5
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 28.0
	flashlight.shadow_enabled = false
	flashlight.visible = false
	flashlight.position = Vector3(0.1, -0.05, -0.1)
	camera.add_child(flashlight)

	floor_snap_length = 0.4
	# Пандус клетки ~47°
	floor_max_angle = deg_to_rad(55.0)
	floor_block_on_wall = false
	floor_constant_speed = true

func _ensure_gamepad_bindings() -> void:
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("jump", JOY_BUTTON_B)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("crouch", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button("throw_bag", JOY_BUTTON_X)
	_add_joy_button("drop_bag", JOY_BUTTON_Y)
	_add_joy_button("careful", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("toggle_flashlight", JOY_BUTTON_DPAD_UP)
	_add_joy_button("pause_menu", JOY_BUTTON_START)
	_add_joy_button("restart", JOY_BUTTON_BACK)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis \
				and signf((e as InputEventJoypadMotion).axis_value) == signf(value):
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func _build_hands() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.86, 0.68, 0.55)
	left_hand = MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.08, 0.08, 0.22)
	left_hand.mesh = lb
	left_hand.material_override = skin
	left_hand.position = Vector3(-0.22, -0.28, -0.35)
	camera.add_child(left_hand)
	right_hand = MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.08, 0.08, 0.22)
	right_hand.mesh = rb
	right_hand.material_override = skin
	right_hand.position = Vector3(0.28, -0.32, -0.4)
	camera.add_child(right_hand)

func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _apply_gamepad_look(delta: float) -> void:
	if camera == null or not InputMap.has_action("look_left"):
		return
	var lx := Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var ly := Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	if absf(lx) < 0.15 and absf(ly) < 0.15:
		return
	var sens := 2.4 * float(Svc.meta().settings.get("mouse_sens", 1.0)) * cargo_yaw_mult * delta
	_yaw -= lx * sens
	var dy: float = ly * sens
	_pitch -= -dy if invert_y else dy
	_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
	rotation.y = _yaw
	camera.rotation.x = _pitch

func set_cargo_feel(speed_m: float, fov_off: float, yaw_m: float) -> void:
	cargo_speed_mult = speed_m
	cargo_fov = fov_off
	cargo_yaw_mult = yaw_m

func clear_cargo_feel() -> void:
	set_cargo_feel(1.0, 0.0, 1.0)

func set_look_yaw(yaw: float) -> void:
	_yaw = yaw
	rotation.y = yaw

func _unhandled_input(event: InputEvent) -> void:
	if not active or camera == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := BASE_SENS * float(Svc.meta().settings.get("mouse_sens", 1.0)) * cargo_yaw_mult
		_yaw -= motion.relative.x * sens
		var dy: float = motion.relative.y * sens
		_pitch -= -dy if invert_y else dy
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _yaw
		camera.rotation.x = _pitch
	if event.is_action_pressed("toggle_flashlight"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	if event.is_action_pressed("throw_bag"):
		throw_pressed.emit()
	if event.is_action_pressed("drop_bag"):
		drop_pressed.emit()

func _physics_process(delta: float) -> void:
	if not active or camera == null or _col == null:
		return
	careful = Input.is_action_pressed("careful")
	_apply_gamepad_look(delta)
	_slip_cd = maxf(0.0, _slip_cd - delta)
	var grav := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= grav * delta
		_air_time += delta
		_max_fall_speed = maxf(_max_fall_speed, -velocity.y)
	else:
		if _air_time > 0.25 and _max_fall_speed > 8.0:
			fell_hard.emit(_max_fall_speed)
		_air_time = 0.0
		_max_fall_speed = 0.0

	_crouching = Input.is_action_pressed("crouch")
	var speed := CROUCH if _crouching else (SPRINT if Input.is_action_pressed("sprint") and not careful else WALK)
	speed *= cargo_speed_mult
	if careful:
		speed *= 0.7
	if on_ice:
		speed *= 0.85

	camera.fov = lerpf(camera.fov, base_fov + cargo_fov, 6.0 * delta)

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target := dir * speed
	var accel := 18.0 if is_on_floor() else 6.0
	if on_ice and is_on_floor():
		accel = 3.5
		if Input.is_action_pressed("sprint") and dir.length() > 0.1 and _slip_cd <= 0.0 and randf() < 0.02:
			_slip_cd = 1.2
			velocity += dir.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * 7.0
			velocity.y = 2.2
			slipped.emit()
			Svc.audio().play_sfx("slip")

	velocity.x = move_toward(velocity.x, target.x, accel * delta * ice_factor)
	velocity.z = move_toward(velocity.z, target.z, accel * delta * ice_factor)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not careful:
		velocity.y = JUMP_V * (0.7 if _crouching else 1.0)

	move_and_slide()

	var horiz := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz > 0.7:
		_step_acc += horiz * delta
		if _step_acc >= 0.48:
			_step_acc = 0.0
			Svc.audio().play_step()
	else:
		_step_acc = 0.0

	var target_h := 1.1 if _crouching else 1.5
	var sh: CapsuleShape3D = _col.shape
	sh.height = lerpf(sh.height, target_h, 12.0 * delta)
	_col.position.y = sh.height * 0.5 + 0.2
	camera.position.y = lerpf(camera.position.y, 1.15 if _crouching else 1.55, 12.0 * delta)

	if left_hand and right_hand:
		var bob := sin(Time.get_ticks_msec() * 0.01) * (0.01 if careful else 0.02)
		left_hand.position.y = -0.28 + bob
		right_hand.position.y = -0.32 - bob
