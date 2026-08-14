extends SceneTree
## Как импортировались материалы пропсов: прозрачность, отсечение, тени.

const TARGETS := ["grass_medium_01", "weed_plant_02", "dandelion_01", "nettle_plant",
	"modular_chainlink_fence", "trashbag", "street_lamp_01"]

func _initialize() -> void:
	for n in TARGETS:
		var node := PropLibrary.instance(n)
		if node == null:
			print("MISS ", n)
			continue
		var seen := {}
		var stack: Array = [node]
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			if x is MeshInstance3D and (x as MeshInstance3D).mesh != null:
				var m: Mesh = (x as MeshInstance3D).mesh
				for s in range(m.get_surface_count()):
					var mat := m.surface_get_material(s)
					if mat == null or seen.has(mat.resource_name + str(mat.get_instance_id())):
						continue
					seen[mat.resource_name + str(mat.get_instance_id())] = true
					if mat is BaseMaterial3D:
						var bm := mat as BaseMaterial3D
						print("  %-24s transparency=%d cull=%d alpha_scissor=%.2f shading=%d" % [
							n, bm.transparency, bm.cull_mode, bm.alpha_scissor_threshold, bm.shading_mode])
					else:
						print("  %-24s не BaseMaterial3D: %s" % [n, mat.get_class()])
			for c in x.get_children():
				stack.append(c)
		node.free()
	print("MAT_PROBE_DONE")
	quit(0)
