extends SceneTree
## Симуляция: CharacterBody реально проходит марш вниз и вверх.

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
	# Дать физике прогрузиться
	for i in range(5):
		await process_frame

	var p: CharacterBody3D = b.player
	p.active = false
	# Старт у зелёной метки этажа 2 (правый марш)
	p.global_position = Vector3(1.0, 6.35, 0.2)
	p.velocity = Vector3.ZERO
	p.floor_max_angle = deg_to_rad(70.0)
	p.floor_snap_length = 0.4

	var y_start := p.global_position.y
	# Идём в +Z и чуть вниз по склону
	for i in range(180):
		var dir := Vector3(0, 0, 1)
		p.velocity.x = dir.x * 4.0
		p.velocity.z = dir.z * 4.0
		if not p.is_on_floor():
			p.velocity.y -= 20.0 * (1.0 / 60.0)
		p.move_and_slide()
		await process_frame
		if p.global_position.y < 3.6:
			break

	var y_after_down := p.global_position.y
	print("WALK_DOWN start_y=%.2f end_y=%.2f pos=%s on_floor=%s" % [
		y_start, y_after_down, p.global_position, p.is_on_floor()
	])
	if y_after_down > 4.5:
		push_error("FAIL: could not walk down stairs")
		quit(1)
		return

	# Подъём обратно
	for i in range(200):
		p.velocity.x = 0.0
		p.velocity.z = -4.0
		if not p.is_on_floor():
			p.velocity.y -= 20.0 * (1.0 / 60.0)
		p.move_and_slide()
		await process_frame
		if p.global_position.y > 5.7:
			break

	var y_after_up := p.global_position.y
	print("WALK_UP end_y=%.2f pos=%s" % [y_after_up, p.global_position])
	if y_after_up < 5.2:
		push_error("FAIL: could not walk up stairs")
		quit(1)
		return

	print("TEST_STAIR_WALK_PASS")
	quit(0)
