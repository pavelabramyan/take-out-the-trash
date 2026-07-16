extends SceneTree

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
	for i in range(3):
		await process_frame

	var space := root.get_world_3d().direct_space_state
	var x := 1.0
	print("=== RAMP SURFACE y along z (floor2→1) ===")
	for zi in range(0, 31):
		var z := 0.2 + float(zi) * 0.1
		var from := Vector3(x, 8.0, z)
		var to := Vector3(x, 2.0, z)
		var rq := PhysicsRayQueryParameters3D.create(from, to)
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		if hit.is_empty():
			print("z=%.2f MISS" % z)
		else:
			var n: Vector3 = hit.get("normal", Vector3.UP)
			print("z=%.2f y=%.3f normal=(%.2f,%.2f,%.2f) collider=%s" % [
				z, hit.position.y, n.x, n.y, n.z, hit.collider
			])

	# Corners of all StaticBody under stair x
	print("=== STATIC BODIES near stair ===")
	_dump(b, 0)
	quit(0)

func _dump(n: Node, depth: int) -> void:
	if n is StaticBody3D:
		var sb := n as StaticBody3D
		if absf(sb.global_position.x - 1.0) < 1.5 and sb.global_position.y > 2.0 and sb.global_position.y < 7.0:
			print("SB pos=%s rot=%s" % [sb.global_position, sb.rotation_degrees])
			for c in sb.get_children():
				if c is CollisionShape3D:
					var cs := c as CollisionShape3D
					if cs.shape is BoxShape3D:
						print("  box size=", (cs.shape as BoxShape3D).size)
	for c in n.get_children():
		_dump(c, depth + 1)
