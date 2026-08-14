extends SceneTree
## Габариты и полигонаж скачанных пропсов — чтобы ставить их в мир в масштабе.

func _initialize() -> void:
	var names := PackedStringArray()
	var dir := DirAccess.open("res://assets/models")
	if dir:
		for d in dir.get_directories():
			names.append(d)
	for n in names:
		var node := PropLibrary.instance(n)
		if node == null:
			print("MISS ", n)
			continue
		var tris := 0
		var meshes := 0
		var stack: Array = [node]
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			if x is MeshInstance3D and (x as MeshInstance3D).mesh != null:
				meshes += 1
				var m: Mesh = (x as MeshInstance3D).mesh
				for s in range(m.get_surface_count()):
					var arr := m.surface_get_arrays(s)
					if arr[Mesh.ARRAY_INDEX] != null:
						tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
					elif arr[Mesh.ARRAY_VERTEX] != null:
						tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			for c in x.get_children():
				stack.append(c)
		var sz := PropLibrary.size_of(n)
		print("PROP %-28s size=(%.2f, %.2f, %.2f) meshes=%d tris=%d" % [n, sz.x, sz.y, sz.z, meshes, tris])
		node.free()
	print("PROBE_DONE")
	quit(0)
