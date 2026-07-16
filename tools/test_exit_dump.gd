extends SceneTree
## Полный путь: U-лестница → дверь во двор → помойка.

const LevelDataScr = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _walk(p: CharacterBody3D, dir: Vector3, frames: int) -> void:
	dir = dir.normalized()
	for i in range(frames):
		p.velocity.x = dir.x * 4.2
		p.velocity.z = dir.z * 4.2
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
	for i in range(4):
		await process_frame

	var p: CharacterBody3D = b.player
	p.active = false
	p.floor_max_angle = deg_to_rad(55.0)
	p.floor_snap_length = 0.45
	var H: float = BuildingBuilderScr.FLOOR_H
	var HH: float = BuildingBuilderScr.HALF_H

	p.global_position = Vector3(1.20, H * 2.0 + 0.4, 0.15)
	await _walk(p, Vector3(0, 0, 1), 150)
	p.global_position = Vector3(-1.20, H * 2.0 - HH + 0.35, 2.6)
	await _walk(p, Vector3(0, 0, -1), 150)
	p.global_position = Vector3(1.20, H + 0.4, 0.15)
	await _walk(p, Vector3(0, 0, 1), 150)
	p.global_position = Vector3(-1.20, H - HH + 0.35, 2.6)
	await _walk(p, Vector3(0, 0, -1), 170)
	print("AT_GROUND y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.y > 1.2:
		push_error("FAIL stairs")
		quit(1)
		return

	p.global_position = Vector3(0.0, 0.4, 3.2)
	await _walk(p, Vector3(0, 0, 1), 200)
	print("AFTER_DOOR y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.z < 4.5:
		push_error("FAIL exit blocked — still in stairwell z=%.2f" % p.global_position.z)
		quit(1)
		return

	var dump: Vector3 = b.dumpster.global_position
	for i in range(280):
		var to := dump - p.global_position
		to.y = 0.0
		if to.length() < 2.2:
			break
		await _walk(p, to, 1)
	var dist := p.global_position.distance_to(dump)
	print("NEAR_DUMP dist=%.2f pos=%s dump=%s" % [dist, p.global_position, dump])
	if dist > 3.5:
		push_error("FAIL reach dumpster")
		quit(1)
		return

	print("TEST_EXIT_DUMP_PASS")
	quit(0)
