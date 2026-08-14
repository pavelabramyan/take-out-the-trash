extends SceneTree
## Сколько инстансов растительности реально попало в сцену и куда.

func _initialize() -> void:
	for n in ["grass_medium_01", "weed_plant_02", "dandelion_01", "nettle_plant"]:
		for part in ["tall_a", "mid_b", "small_a", "_c_", "_e_"]:
			var got := PropLibrary.mesh_of(n, part)
			if got.is_empty():
				print("mesh_of %s/%s -> нет" % [n, part])
			else:
				var m: Mesh = got[0]
				var tr: Transform3D = got[1]
				print("mesh_of %s/%s -> aabb=%s scale=%s surf_mat=%s" % [n, part, str(m.get_aabb().size), str(tr.basis.get_scale()), str(m.surface_get_material(0) != null)])
	var b: Node = load("res://scripts/building_builder.gd").new()
	get_root().add_child(b)
	b.call("build", {"floors": 5, "start_floor": 5, "style": "panel"})
	var mm_count := 0
	var inst := 0
	var stack: Array = [b]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is MultiMeshInstance3D:
			var m := (x as MultiMeshInstance3D).multimesh
			if m != null:
				mm_count += 1
				inst += m.instance_count
				if m.instance_count > 0 and m.instance_count < 40:
					print("  MM count=%d first=%s" % [m.instance_count, str(m.get_instance_transform(0).origin)])
		for c in x.get_children():
			stack.append(c)
	print("MULTIMESH nodes=%d instances=%d" % [mm_count, inst])
	print("SCATTER_DONE")
	quit(0)
