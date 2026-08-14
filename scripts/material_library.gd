class_name MaterialLibrary
extends RefCounted
## PBR-материалы из assets/pbr (ambientCG, CC0): albedo + normal + ORM в одном файле.
##
## UV задаётся в метрах через world-triplanar: текстура ложится по мировым
## координатам, поэтому один материал одинаково корректен и на стене 5 м,
## и на плинтусе 6 см — плюс исчезают швы на стыках соседних боксов.
## Если ассеты не скачаны (tools/fetch_assets.py), возвращается ровный
## материал по цвету fallback, чтобы игра оставалась запускаемой.

const ROOT := "res://assets/pbr/"

## Физический размер одного тайла текстуры в метрах.
const TILE_M := {
	"asphalt": 3.0,
	"bricks": 2.0,
	"carpet": 1.0,
	"concrete_floor": 2.0,
	"concrete_wall": 2.0,
	"grass": 2.0,
	"gravel": 2.0,
	"ground_dirt": 2.5,
	"ice": 2.0,
	"metal_painted": 1.5,
	"plaster_paint": 2.0,
	"plaster_white": 2.5,
	"road": 4.0,
	"snow": 2.5,
	"steel_corrugated": 1.5,
	"tiles_landing": 1.2,
	"wood_door": 1.6,
}

static var _cache: Dictionary = {}

static func available() -> bool:
	return ResourceLoader.exists(ROOT + "concrete_wall/albedo.webp")

static func has_set(name: String) -> bool:
	return ResourceLoader.exists(ROOT + name + "/albedo.webp")

## cfg: tint, rough, metal, tile_m, normal_scale, ao, triplanar, sharpness,
##      uv (если triplanar=false), fallback, alpha, unshaded
static func pbr(name: String, cfg: Dictionary = {}) -> StandardMaterial3D:
	var key := "%s|%d" % [name, cfg.hash()]
	var cached = _cache.get(key)
	if cached != null:
		return cached
	var m := StandardMaterial3D.new()
	var tint: Color = cfg.get("tint", Color.WHITE)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var alb := ROOT + name + "/albedo.webp"
	if ResourceLoader.exists(alb):
		m.albedo_texture = load(alb)
		var nrm := ROOT + name + "/normal.webp"
		if ResourceLoader.exists(nrm):
			m.normal_enabled = true
			m.normal_texture = load(nrm)
			m.normal_scale = float(cfg.get("normal_scale", 1.0))
		var orm_path := ROOT + name + "/orm.webp"
		if ResourceLoader.exists(orm_path):
			var orm: Texture2D = load(orm_path)
			m.ao_enabled = true
			m.ao_texture = orm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.ao_light_affect = float(cfg.get("ao", 0.55))
			m.roughness_texture = orm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.metallic_texture = orm
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			m.metallic = float(cfg.get("metal", 1.0))
		m.roughness = float(cfg.get("rough", 1.0))
		if bool(cfg.get("triplanar", true)):
			var tile: float = maxf(float(cfg.get("tile_m", TILE_M.get(name, 2.0))), 0.05)
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_triplanar_sharpness = float(cfg.get("sharpness", 1.0))
			m.uv1_scale = Vector3.ONE / tile
		else:
			var s: float = float(cfg.get("uv", 1.0))
			m.uv1_scale = Vector3(s, s, s)
	else:
		m.albedo_color = cfg.get("fallback", tint)
		m.roughness = clampf(float(cfg.get("rough", 0.9)), 0.04, 1.0)
		m.metallic = clampf(float(cfg.get("metal", 0.0)), 0.0, 1.0)
	var alpha: float = float(cfg.get("alpha", 1.0))
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	if bool(cfg.get("unshaded", false)):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m

## Ровный материал для мелочи, где текстура не читается (провода, скобы).
static func flat(color: Color, rough: float = 0.85, metal: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "flat|%s|%.3f|%.3f|%.3f" % [color.to_html(), rough, metal, alpha]
	var cached = _cache.get(key)
	if cached != null:
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	_cache[key] = m
	return m

## Светящийся материал (лампы, окна).
static func emissive(color: Color, energy: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var em := emission if emission != Color.BLACK else color
	var key := "em|%s|%.2f|%s" % [color.to_html(), energy, em.to_html()]
	var cached = _cache.get(key)
	if cached != null:
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = em
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m

## Рисованная карта из assets/textures (граффити, объявления, номера).
static func painted(path: String, tint: Color = Color.WHITE, uv: Vector3 = Vector3.ONE, rough: float = 0.9) -> StandardMaterial3D:
	var key := "paint|%s|%s|%s|%.2f" % [path, tint.to_html(), str(uv), rough]
	var cached = _cache.get(key)
	if cached != null:
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var nrm := path.get_basename() + "_normal.png"
		if ResourceLoader.exists(nrm):
			m.normal_enabled = true
			m.normal_texture = load(nrm)
			m.normal_scale = 0.6
		var rgh := path.get_basename() + "_rough.png"
		if ResourceLoader.exists(rgh):
			m.roughness_texture = load(rgh)
	_cache[key] = m
	return m

static func clear_cache() -> void:
	_cache.clear()
