extends SceneTree
## U-лестница: этаж 2 → mid → этаж 1 → mid → земля (правый/+Z, левый/−Z).

const LevelDataScr = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _walk(p: CharacterBody3D, dir: Vector3, frames: int) -> void:
	dir = dir.normalized()
	for i in range(frames):
		p.velocity.x = dir.x * 4.0
		p.velocity.z = dir.z * 4.0
		if not p.is_on_floor():
			p.velocity.y -= 24.0 / 60.0
		p.move_and_slide()
		await process_frame

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var b = BuildingBuilderScr.new()
	root.add_child(b)
	b.build(LevelDataScr.get_level(0))
	for i in range(5):
		await process_frame

	var p: CharacterBody3D = b.player
	p.active = false
	p.floor_max_angle = deg_to_rad(55.0)
	p.floor_snap_length = 0.45
	var H: float = BuildingBuilderScr.FLOOR_H
	var HH: float = BuildingBuilderScr.HALF_H

	# Этаж 2: правый марш (+Z) → mid
	p.global_position = Vector3(1.20, H * 2.0 + 0.4, 0.2)
	p.velocity = Vector3.ZERO
	await _walk(p, Vector3(0, 0, 1), 160)
	print("MID2 y=%.2f z=%.2f x=%.2f" % [p.global_position.y, p.global_position.z, p.global_position.x])
	if p.global_position.y > H * 2.0 - HH + 0.9:
		push_error("FAIL 2→mid")
		quit(1)
		return

	# Mid → левый марш (−Z) → этаж 1
	p.global_position = Vector3(-1.20, H * 2.0 - HH + 0.35, 2.6)
	await _walk(p, Vector3(0, 0, -1), 160)
	print("FL1 y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.y > H + 0.9:
		push_error("FAIL mid→1")
		quit(1)
		return

	# Этаж 1: снова правый (+Z) → mid
	p.global_position = Vector3(1.20, H + 0.4, 0.2)
	await _walk(p, Vector3(0, 0, 1), 160)
	print("MID1 y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.y > H - HH + 0.9:
		push_error("FAIL 1→mid")
		quit(1)
		return

	# Mid → левый (−Z) → земля
	p.global_position = Vector3(-1.20, H - HH + 0.35, 2.6)
	await _walk(p, Vector3(0, 0, -1), 180)
	print("GROUND y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.y > 1.2:
		push_error("FAIL mid→0")
		quit(1)
		return

	print("TEST_STAIR_WALK_PASS")
	quit(0)
