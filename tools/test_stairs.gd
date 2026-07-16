extends SceneTree
## Проверка: от спавна до низа марша есть поверхность под ногами (не дыра).

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
	await process_frame
	await process_frame

	var space := root.get_world_3d().direct_space_state
	assert(space != null)
	# Этаж старта (2): марш слева (f%2==0 → right? f=2 left=false → x=+1)
	# f=2: left = (2%2==1)=false → right side x=+1
	var stair_x := 1.0
	var y_top := 6.0
	var hits := 0
	var misses := 0
	for i in range(14):
		var t := (float(i) + 0.5) / 14.0
		var z := lerpf(0.5, 2.7, t)
		var y_expect := lerpf(y_top, 3.0, t)
		var from := Vector3(stair_x, y_expect + 1.2, z)
		var to := Vector3(stair_x, y_expect - 1.5, z)
		var rq := PhysicsRayQueryParameters3D.create(from, to)
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		if hit.is_empty():
			misses += 1
			print("STAIR_MISS t=%.2f z=%.2f expect_y=%.2f" % [t, z, y_expect])
		else:
			hits += 1
	print("STAIR_RAYS hits=", hits, " misses=", misses)
	assert(hits >= 12)
	assert(misses <= 2)
	# Перила: сбоку от проёма луч должен упереться (не упасть вбок)
	var side := PhysicsRayQueryParameters3D.create(
		Vector3(stair_x - 1.1, y_top + 0.9, 1.6),
		Vector3(stair_x - 0.2, y_top + 0.9, 1.6)
	)
	side.collision_mask = 1
	var side_hit := space.intersect_ray(side)
	assert(not side_hit.is_empty())
	print("TEST_STAIRS_PASS")
	quit(0)
