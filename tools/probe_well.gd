extends SceneTree
## Какие плиты пересекают шахту марша на высоте площадок.

const LevelDataScr = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _aabb_of(n: Node3D) -> AABB:
	var acc := AABB()
	var got := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		acc = a
		got = true
	for c in n.get_children():
		if c is Node3D:
			var ca := _aabb_of(c)
			if ca.size.length() > 0.001:
				if not got:
					acc = ca
					got = true
				else:
					acc = acc.merge(ca)
	return acc

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var b = BuildingBuilderScr.new()
	root.add_child(b)
	b.build(LevelDataScr.get_level(0))
	await process_frame
	var H: float = BuildingBuilderScr.FLOOR_H
	var well := AABB(Vector3(-1.2, 0.15, 0.50), Vector3(2.4, 8.0, 1.55))
	var hits: int = 0
	for n in b.get_children():
		if not (n is StaticBody3D or n is MeshInstance3D):
			continue
		var a := _aabb_of(n)
		if a.size.length() < 0.01:
			continue
		if not a.intersects(well):
			continue
		# Только горизонтальные плиты толще 8 см — ступени и перила не считаем
		if a.size.y < 0.08 or a.size.y > 0.45:
			continue
		if a.size.x < 0.8 and a.size.z < 0.8:
			continue
		hits += 1
		print("WELL_HIT y=%.2f..%.2f z=%.2f..%.2f x=%.2f..%.2f size=%s name=%s" % [
			a.position.y, a.position.y + a.size.y,
			a.position.z, a.position.z + a.size.z,
			a.position.x, a.position.x + a.size.x,
			a.size, n.name
		])
	print("WELL_HITS=%d floors=%s" % [hits, H])
	quit(0)
