class_name Geo
extends RefCounted
## Геометрия со фасками. Прямой BoxMesh выдаёт идеально острое ребро, которого
## в реальном бетоне и жести не бывает — именно этот блик по кромке и делает
## кадр «настоящим». Меши кешируются по параметрам: одинаковые ступени и
## балясины переиспользуют один ресурс.

static var _cache: Dictionary = {}

static func _key(prefix: String, args: Array) -> String:
	var parts := PackedStringArray()
	for a in args:
		parts.append(str(a))
	return prefix + "|" + "|".join(parts)

## Скруглённый (точнее — фасочный) бокс: проекция сетки куба на SDF
## «бокс + сфера радиуса chamfer».
static func rounded_box(size: Vector3, chamfer: float = -1.0, segs: int = 3) -> ArrayMesh:
	var sz := size.abs()
	var r: float = chamfer
	if r < 0.0:
		r = clampf(minf(minf(sz.x, sz.y), sz.z) * 0.10, 0.003, 0.016)
	r = minf(r, minf(minf(sz.x, sz.y), sz.z) * 0.45)
	var key := _key("rbox", [snappedf(sz.x, 0.001), snappedf(sz.y, 0.001), snappedf(sz.z, 0.001), snappedf(r, 0.0005), segs])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var half := sz * 0.5
	var inner := Vector3(maxf(half.x - r, 0.0), maxf(half.y - r, 0.0), maxf(half.z - r, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n in axes:
		var normal: Vector3 = n
		var tangent := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
		var u := normal.cross(tangent).normalized()
		var v := u.cross(normal).normalized()
		var base := Vector3(normal.x * half.x, normal.y * half.y, normal.z * half.z)
		var su := Vector3(absf(u.x) * half.x, absf(u.y) * half.y, absf(u.z) * half.z)
		var sv := Vector3(absf(v.x) * half.x, absf(v.y) * half.y, absf(v.z) * half.z)
		for iy in range(segs):
			for ix in range(segs):
				var quad := [
					Vector2(float(ix) / segs, float(iy) / segs),
					Vector2(float(ix + 1) / segs, float(iy) / segs),
					Vector2(float(ix + 1) / segs, float(iy + 1) / segs),
					Vector2(float(ix) / segs, float(iy + 1) / segs),
				]
				var pts := PackedVector3Array()
				var nrm := PackedVector3Array()
				for c in quad:
					var a: float = lerpf(-1.0, 1.0, c.x)
					var b: float = lerpf(-1.0, 1.0, c.y)
					var p := base + u * (su * a) + v * (sv * b)
					# Проекция на фасочную поверхность: ближайшая точка внутреннего
					# бокса плюс сдвиг на радиус вдоль направления
					var q := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
					var dir := p - q
					var nn: Vector3 = normal if dir.length() < 0.00001 else dir.normalized()
					pts.append(q + nn * r)
					nrm.append(nn)
				_add_quad(st, pts, nrm, quad)
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

static func _add_quad(st: SurfaceTool, p: PackedVector3Array, n: PackedVector3Array, uv: Array) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])

## Ступень: проступь со свесом + подступёнок, одним мешем.
static func stair_step(width: float, tread: float, riser: float, nose: float = 0.025) -> ArrayMesh:
	var key := _key("step", [snappedf(width, 0.001), snappedf(tread, 0.001), snappedf(riser, 0.001), snappedf(nose, 0.001)])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tread_h := 0.04
	_merge(st, rounded_box(Vector3(width, tread_h, tread + nose), 0.008), Transform3D(Basis.IDENTITY, Vector3(0, riser * 0.5 - tread_h * 0.5, -nose * 0.5)))
	# Подступёнок прижат к передней кромке — под свесом появляется тень
	var riser_d: float = tread * 0.55
	_merge(st, rounded_box(Vector3(width - 0.012, riser - tread_h, riser_d), 0.006),
		Transform3D(Basis.IDENTITY, Vector3(0, -tread_h * 0.5, (tread + nose) * 0.5 - nose - riser_d * 0.5)))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## Труба с гладкой боковиной: поручни, стойки, стояки.
static func pipe(radius: float, length: float, segs: int = 16) -> CylinderMesh:
	var key := _key("pipe", [snappedf(radius, 0.0005), snappedf(length, 0.001), segs])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = segs
	cm.rings = 1
	cm.cap_top = true
	cm.cap_bottom = true
	_cache[key] = cm
	return cm

## Дверное полотно: рамка, две филёнки, фаска по кромке.
static func door_leaf(width: float, height: float, thick: float) -> ArrayMesh:
	var key := _key("door", [snappedf(width, 0.001), snappedf(height, 0.001), snappedf(thick, 0.001)])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_merge(st, rounded_box(Vector3(width, height, thick), 0.006), Transform3D.IDENTITY)
	var frame := 0.11
	var panel_w := width - frame * 2.0
	var gap := 0.06
	var panel_h := (height - frame * 2.0 - gap) * 0.5
	for i in range(2):
		var cy := (panel_h + gap * 0.5) * (1.0 if i == 0 else -1.0)
		# Филёнка выступает наружу: тень по контуру читается даже в полумраке
		_merge(st, rounded_box(Vector3(panel_w, panel_h, thick * 0.45), 0.005),
			Transform3D(Basis.IDENTITY, Vector3(0, cy, thick * 0.42)))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## Оконный проём: откосы, подоконник, наружный отлив.
static func window_reveal(width: float, height: float, wall_thick: float, sill: float = 0.14) -> ArrayMesh:
	var key := _key("reveal", [snappedf(width, 0.001), snappedf(height, 0.001), snappedf(wall_thick, 0.001), snappedf(sill, 0.001)])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var jamb := 0.07
	for sx in [-1.0, 1.0]:
		_merge(st, rounded_box(Vector3(jamb, height + jamb * 2.0, wall_thick), 0.008),
			Transform3D(Basis.IDENTITY, Vector3(sx * (width * 0.5 + jamb * 0.5), 0, 0)))
	_merge(st, rounded_box(Vector3(width + jamb * 2.0, jamb, wall_thick), 0.008),
		Transform3D(Basis.IDENTITY, Vector3(0, height * 0.5 + jamb * 0.5, 0)))
	_merge(st, rounded_box(Vector3(width + jamb * 2.4, 0.05, wall_thick + sill), 0.01),
		Transform3D(Basis.IDENTITY, Vector3(0, -height * 0.5 - 0.025, sill * 0.35)))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## Профиль плинтуса/отбойника: скос сверху, чтобы пыль «ложилась» правдоподобно.
static func skirting(length: float, height: float, depth: float) -> ArrayMesh:
	var key := _key("skirt", [snappedf(length, 0.001), snappedf(height, 0.001), snappedf(depth, 0.001)])
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_merge(st, rounded_box(Vector3(depth, height, length), 0.005), Transform3D.IDENTITY)
	_merge(st, rounded_box(Vector3(depth * 0.6, 0.012, length), 0.004),
		Transform3D(Basis.IDENTITY, Vector3(-depth * 0.18, height * 0.5, 0)))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

static func _merge(st: SurfaceTool, mesh: Mesh, xform: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		uvs = arrays[Mesh.ARRAY_TEX_UV]
	# SurfaceTool.commit() без index() отдаёт меш без индексов
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	var basis := xform.basis
	if idx.is_empty():
		for i in range(verts.size()):
			st.set_normal(basis * norms[i])
			if i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(xform * verts[i])
	else:
		for i in idx:
			st.set_normal(basis * norms[i])
			if i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(xform * verts[i])

static func clear_cache() -> void:
	_cache.clear()
