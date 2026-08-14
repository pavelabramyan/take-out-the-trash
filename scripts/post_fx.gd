class_name PostFx
extends CanvasLayer
## Плёночный слой поверх кадра: виньетка, зерно, хроматика.
## Живёт под HUD, чтобы текст оставался чистым и читаемым.

const SHADER := "res://shaders/post_grade.gdshader"

var rect: ColorRect
var _mat: ShaderMaterial
var _t: float = 0.0

func _ready() -> void:
	layer = -1
	if not ResourceLoader.exists(SHADER):
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	rect = ColorRect.new()
	rect.material = _mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)
	add_child(rect)

## Ночью виньетка глубже, зерно заметнее — как на плохой светочувствительности.
func set_night(night: bool) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("vignette_amount", 0.72 if night else 0.5)
	_mat.set_shader_parameter("grain_amount", 0.055 if night else 0.03)
	_mat.set_shader_parameter("lift_blue", 0.055 if night else 0.03)
	_mat.set_shader_parameter("saturation", 0.84 if night else 0.94)

func _process(delta: float) -> void:
	if _mat == null:
		return
	# Зерно должно жить: статичный шум выглядит как грязь на экране
	_t += delta
	_mat.set_shader_parameter("time_seed", _t * 37.0)
