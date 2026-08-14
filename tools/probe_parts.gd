extends SceneTree
## Имена и габариты отдельных мешей внутри составных пропсов.

const TARGETS := ["modular_chainlink_fence", "grass_medium_01", "dandelion_01", "nettle_plant",
	"weed_plant_02", "modular_electricity_poles", "modular_pipes", "modular_street_seating", "trashbag"]

func _initialize() -> void:
	for n in TARGETS:
		var node := PropLibrary.instance(n)
		if node == null:
			print("MISS ", n)
			continue
		var stack: Array = [node]
		var rows: Array = []
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			if x is MeshInstance3D and (x as MeshInstance3D).mesh != null:
				var mi := x as MeshInstance3D
				var b: AABB = mi.mesh.get_aabb()
				var tris := 0
				for s in range(mi.mesh.get_surface_count()):
					var arr := mi.mesh.surface_get_arrays(s)
					if arr[Mesh.ARRAY_INDEX] != null:
						tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				rows.append("    %-46s size=(%.2f, %.2f, %.2f) tris=%d" % [mi.name, b.size.x, b.size.y, b.size.z, tris])
			for c in x.get_children():
				stack.append(c)
		rows.sort()
		print("== ", n)
		for r in rows:
			print(r)
		node.free()
	print("PARTS_DONE")
	quit(0)
