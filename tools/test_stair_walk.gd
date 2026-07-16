extends SceneTree
## Спуск только вперёд (+Z) со старта до земли.

const LevelDataScr = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

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
	p.global_position = b.spawn_pos
	p.velocity = Vector3.ZERO
	p.floor_max_angle = deg_to_rad(50.0)
	p.floor_snap_length = 0.35

	var y0 := p.global_position.y
	for i in range(500):
		p.velocity.x = 0.0
		p.velocity.z = 4.5
		if not p.is_on_floor():
			p.velocity.y -= 24.0 / 60.0
		p.move_and_slide()
		await process_frame
		if p.global_position.y < 0.9 and p.global_position.z > 1.0:
			break

	print("WALK y0=%.2f y=%.2f z=%.2f" % [y0, p.global_position.y, p.global_position.z])
	if p.global_position.y > 1.2:
		push_error("FAIL: did not reach ground walking forward")
		quit(1)
		return
	print("TEST_STAIR_WALK_PASS")
	quit(0)
