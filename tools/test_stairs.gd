extends SceneTree
## Верхний марш 2→mid: понижается по +Z (правый, STAIR_X).

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
	var x: float = BuildingBuilderScr.STAIR_X
	var prev := 99.0
	for i in range(10):
		var t := (float(i) + 0.5) / 10.0
		var z := lerpf(BuildingBuilderScr.FLIGHT_Z_A0, BuildingBuilderScr.FLIGHT_Z_A1, t)
		var rq := PhysicsRayQueryParameters3D.create(Vector3(x, 7.2, z), Vector3(x, 0, z))
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		assert(not hit.is_empty())
		assert(hit.position.y <= prev + 0.08)
		prev = hit.position.y
	print("TEST_STAIRS_PASS last_y=", prev)
	prev = 99.0
	x = -BuildingBuilderScr.STAIR_X
	for i in range(10):
		var t := (float(i) + 0.5) / 10.0
		var z := lerpf(BuildingBuilderScr.FLIGHT_Z_A1, BuildingBuilderScr.FLIGHT_Z_A0, t)
		var rq := PhysicsRayQueryParameters3D.create(Vector3(x, 7.2, z), Vector3(x, 0, z))
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		assert(not hit.is_empty())
		assert(hit.position.y <= prev + 0.08)
		prev = hit.position.y
	print("TEST_STAIRS_PASS lower last_y=", prev)
	quit(0)
