class_name UiTheme
extends RefCounted
## Грязная панелька: не дефолтный серый Godot.

const FONT_BOLD := "res://assets/fonts/PT_Sans-Narrow-Web-Bold.ttf"
const FONT_TEXT := "res://assets/fonts/PT_Sans-Web-Regular.ttf"

## Узкий гротеск с кириллицей вместо дефолтного шрифта Godot.
static func _font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f: FontFile = load(path)
	if f:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

static func panelka() -> Theme:
	var t := Theme.new()
	var bold := _font(FONT_BOLD)
	var text := _font(FONT_TEXT)
	if text:
		t.default_font = text
		t.default_font_size = 18
	if bold:
		t.set_font("font", "Button", bold)
		t.set_font_size("font_size", "Button", 20)
	var font_c := Color(0.88, 0.84, 0.70)
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.04, 0.03, 0.9))
	t.set_constant("outline_size", "Button", 3)
	t.set_color("font_outline_color", "Button", Color(0.03, 0.04, 0.03, 0.85))
	t.set_color("font_color", "Label", font_c)
	t.set_color("font_color", "Button", font_c)
	t.set_color("font_hover_color", "Button", Color(0.96, 0.93, 0.80))
	t.set_color("font_pressed_color", "Button", Color(0.70, 0.68, 0.55))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.44, 0.40))
	t.set_color("font_color", "ProgressBar", font_c)
	t.set_constant("separation", "VBoxContainer", 10)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.13, 0.14, 0.11, 0.94)
	panel.border_color = Color(0.22, 0.38, 0.34)
	panel.set_border_width_all(2)
	panel.border_width_top = 6
	panel.set_corner_radius_all(2)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.18, 0.22, 0.17)
	btn.border_color = Color(0.28, 0.36, 0.28)
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(2)
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", btn)
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.38, 0.28)
	t.set_stylebox("hover", "Button", hover)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.16, 0.11)
	t.set_stylebox("pressed", "Button", pressed)
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.14, 0.14, 0.12)
	t.set_stylebox("disabled", "Button", disabled)

	# Полоса прочности: тонкая, с рамкой, чтобы не выглядела зелёной простынёй
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.07, 0.06, 0.75)
	bar_bg.border_color = Color(0.32, 0.33, 0.28, 0.8)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(1)
	bar_bg.content_margin_top = 1
	bar_bg.content_margin_bottom = 1
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.44, 0.52, 0.30, 0.92)
	bar_fill.set_corner_radius_all(1)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t
