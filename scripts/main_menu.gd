extends Control
## Главное меню: играть, уровни, настройки, выход.

const LevelData = preload("res://scripts/level_data.gd")

@onready var title: Label = $Center/VBox/Title
@onready var tagline: Label = $Center/VBox/Tagline
@onready var btn_play: Button = $Center/VBox/Play
@onready var btn_levels: Button = $Center/VBox/Levels
@onready var btn_settings: Button = $Center/VBox/Settings
@onready var btn_quit: Button = $Center/VBox/Quit
@onready var levels_panel: PanelContainer = $LevelsPanel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var levels_list: VBoxContainer = $LevelsPanel/Margin/VBox/List
@onready var sens_slider: HSlider = $SettingsPanel/Margin/VBox/Sens
@onready var music_slider: HSlider = $SettingsPanel/Margin/VBox/Music
@onready var sfx_slider: HSlider = $SettingsPanel/Margin/VBox/SFX
@onready var lang_btn: OptionButton = $SettingsPanel/Margin/VBox/Lang

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_texts()
	levels_panel.visible = false
	settings_panel.visible = false
	music_slider.value = float(Svc.meta().settings.get("music", 0.7))
	sfx_slider.value = float(Svc.meta().settings.get("sfx", 0.9))
	sens_slider.value = float(Svc.meta().settings.get("mouse_sens", 1.0))
	lang_btn.clear()
	lang_btn.add_item("Русский", 0)
	lang_btn.add_item("English", 1)
	lang_btn.selected = 0 if Svc.loc().lang == "ru" else 1
	Svc.audio().play_music()
	_build_level_buttons()
	# Headless test hook
	if "--test-mode" in OS.get_cmdline_user_args() or "--test-mode" in OS.get_cmdline_args():
		print("TEST_MENU_OK")
		get_tree().quit(0)

func _refresh_texts() -> void:
	title.text = "ВЫНЕСИ МУСОР!" if Svc.loc().lang == "ru" else "TAKE OUT THE TRASH!"
	tagline.text = Svc.loc().t("tagline")
	btn_play.text = Svc.loc().t("play")
	btn_levels.text = Svc.loc().t("levels")
	btn_settings.text = Svc.loc().t("settings")
	btn_quit.text = Svc.loc().t("quit")

func _build_level_buttons() -> void:
	for c in levels_list.get_children():
		c.queue_free()
	var unlocked: int = int(Svc.meta().progress.get("unlocked", 1))
	for i in range(LevelData.count()):
		var lv: Dictionary = LevelData.get_level(i)
		var b := Button.new()
		var stars: int = int(Svc.meta().get_stars(i + 1))
		var star_s := ""
		for s in range(3):
			star_s += "★" if s < stars else "☆"
		var title_s: String = str(lv.get("title_%s" % Svc.loc().lang, lv.get("title_en", "")))
		b.text = "%d. %s  %s" % [i + 1, title_s, star_s]
		b.disabled = (i + 1) > unlocked
		b.pressed.connect(_on_level_chosen.bind(i))
		levels_list.add_child(b)

func _on_play_pressed() -> void:
	var unlocked: int = int(Svc.meta().progress.get("unlocked", 1))
	Svc.meta().current_level = mini(unlocked - 1, LevelData.count() - 1)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_levels_pressed() -> void:
	_build_level_buttons()
	levels_panel.visible = true

func _on_settings_pressed() -> void:
	settings_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_levels_back() -> void:
	levels_panel.visible = false

func _on_settings_back() -> void:
	Svc.meta().settings["music"] = music_slider.value
	Svc.meta().settings["sfx"] = sfx_slider.value
	Svc.meta().settings["mouse_sens"] = sens_slider.value
	Svc.meta().save_all()
	Svc.audio().refresh_volumes()
	settings_panel.visible = false

func _on_lang_selected(idx: int) -> void:
	Svc.loc().set_lang("ru" if idx == 0 else "en")
	_refresh_texts()
	_build_level_buttons()

func _on_level_chosen(i: int) -> void:
	Svc.meta().current_level = i
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_music_changed(v: float) -> void:
	Svc.meta().settings["music"] = v
	Svc.audio().refresh_volumes()

func _on_sfx_changed(v: float) -> void:
	Svc.meta().settings["sfx"] = v
	Svc.audio().refresh_volumes()
