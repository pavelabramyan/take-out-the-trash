class_name PropLibrary
extends RefCounted
## GLTF-пропсы из assets/models (Poly Haven, CC0).
##
## Одиночные предметы ставим целой сценой, повторяющиеся (сорняки, секции
## забора) — через MultiMesh по вытащенному мешу: у Forward+ с тенями дорог
## каждый лишний вызов отрисовки.

const ROOT := "res://assets/models/"

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}

static func path_of(name: String) -> String:
	return "%s%s/%s.gltf" % [ROOT, name, name]

static func has(name: String) -> bool:
	return ResourceLoader.exists(path_of(name))

static func scene(name: String) -> PackedScene:
	var hit = _scenes.get(name)
	if hit != null:
		return hit
	if not has(name):
		return null
	var ps: PackedScene = load(path_of(name))
	_scenes[name] = ps
	return ps

## Новый экземпляр модели целиком.
static func instance(name: String) -> Node3D:
	var ps := scene(name)
	if ps == null:
		return null
	return ps.instantiate() as Node3D

## Поставить модель в мир. scale_to > 0 — подгон по высоте в метрах.
static func spawn(parent: Node, name: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO,
		scale: float = 1.0, scale_to: float = 0.0) -> Node3D:
	var node := instance(name)
	if node == null:
		return null
	parent.add_child(node)
	if scale_to > 0.0:
		var h: float = _aabb_of(node).size.y
		if h > 0.001:
			scale = scale_to / h
	node.scale = Vector3.ONE * scale
	node.rotation_degrees = rot_deg
	node.position = pos
	return node

## Меш вместе с локальным трансформом узла — для MultiMesh.
## part: подстрока имени узла ("" — первый попавшийся меш).
static func mesh_of(name: String, part: String = "") -> Array:
	var key := name + "#" + part
	var hit = _meshes.get(key)
	if hit != null:
		return hit
	var node := instance(name)
	if node == null:
		return []
	var found := _find_mesh(node, part)
	if found.is_empty():
		node.free()
		return []
	var mi: MeshInstance3D = found[0]
	var res := [mi.mesh, mi.transform]
	_meshes[key] = res
	node.free()
	return res

static func _find_mesh(root: Node, part: String) -> Array:
	var stack: Array = [root]
	var fallback: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			if part == "" or part.to_lower() in n.name.to_lower():
				return [n]
			if fallback.is_empty():
				fallback = [n]
		for c in n.get_children():
			stack.append(c)
	return fallback

## Имена мешей внутри модели — удобно, когда в сцене много вариантов (трава).
static func mesh_names(name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var node := instance(name)
	if node == null:
		return out
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			out.append(n.name)
		for c in n.get_children():
			stack.append(c)
	node.free()
	return out

static func size_of(name: String) -> Vector3:
	var node := instance(name)
	if node == null:
		return Vector3.ZERO
	var box := _aabb_of(node)
	node.free()
	return box.size

static func _aabb_of(root: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var local := mi.mesh.get_aabb()
			var rel: Transform3D = (root as Node3D).global_transform.affine_inverse() * mi.global_transform \
				if mi.is_inside_tree() and (root as Node3D).is_inside_tree() else mi.transform
			var world := rel * local
			box = world if first else box.merge(world)
			first = false
		for c in n.get_children():
			stack.append(c)
	return box

static func clear_cache() -> void:
	_scenes.clear()
	_meshes.clear()
