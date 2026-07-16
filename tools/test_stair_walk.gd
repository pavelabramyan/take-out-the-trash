extends SceneTree
## Спуск с этажа 2 по правому маршу (f=2 → right) на этаж 1, затем налево вниз.

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
	p.floor_max_angle = deg_to_rad(55.0)
	p.floor_snap_length = 0.4
	# Этаж 2, у правого проёма
	p.global_position = Vector3(1.15, BuildingBuilderScr.FLOOR_H * 2.0 + 0.4, 0.2)
	p.velocity = Vector3.ZERO

	# Вперёд на пандус (+Z)
	for i in range(220):
		p.velocity = Vector3(0, p.velocity.y, 3.8)
		if not p.is_on_floor():
			p.velocity.y -= 22.0 / 60.0
		p.move_and_slide()
		await process_frame
		if p.global_position.y < BuildingBuilderScr.FLOOR_H + 0.7:
			break
	print("MID y=%.2f z=%.2f x=%.2f" % [p.global_position.y, p.global_position.z, p.global_position.x])
	if p.global_position.y > BuildingBuilderScr.FLOOR_H + 1.2:
		push_error("FAIL 2→1")
		quit(1)
		return

	# На этаже 1 — к левому маршу и вниз
	p.global_position = Vector3(-1.15, BuildingBuilderScr.FLOOR_H + 0.4, 0.2)
	for i in range(240):
		p.velocity = Vector3(0, p.velocity.y, 3.8)
		if not p.is_on_floor():
			p.velocity.y -= 22.0 / 60.0
		p.move_and_slide()
		await process_frame
		if p.global_position.y < 0.9:
			break
	print("GROUND y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	if p.global_position.y > 1.3:
		push_error("FAIL 1→0")
		quit(1)
		return
	print("TEST_STAIR_WALK_PASS")
	quit(0)
