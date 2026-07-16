extends SceneTree
## Пандус этажа 2→1: y падает с ростом z.

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
	var z0: float = b._floor_z0(2) + BuildingBuilderScr.LAND_LEN
	var z1: float = z0 + BuildingBuilderScr.RAMP_RUN
	var prev := 99.0
	for i in range(10):
		var t := (float(i) + 0.5) / 10.0
		var z := lerpf(z0, z1, t)
		var rq := PhysicsRayQueryParameters3D.create(Vector3(0, 20, z), Vector3(0, -2, z))
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		assert(not hit.is_empty())
		assert(hit.position.y < prev + 0.05)
		prev = hit.position.y
	print("TEST_STAIRS_PASS last_y=", prev)
	quit(0)
