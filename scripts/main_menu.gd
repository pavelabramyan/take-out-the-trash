extends Control
## Главное меню: уровни, настройки, ачивки, статистика.

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

var _ach_panel: PanelContainer
var _stats_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_extra_buttons()
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
	if "--test-mode" in OS.get_cmdline_user_args() or "--test-mode" in OS.get_cmdline_args():
		print("TEST_MENU_OK")
		get_tree().quit(0)

func _ensure_extra_buttons() -> void:
	var vbox: VBoxContainer = $Center/VBox
	if OS.has_feature("demo") and not vbox.has_node("Wishlist"):
		var wl := Button.new()
		wl.name = "Wishlist"
		wl.text = Svc.loc().t("wishlist")
		wl.pressed.connect(func(): OS.shell_open("https://store.steampowered.com/app/0"))
		vbox.add_child(wl)
	if not vbox.has_node("Achievements"):
		var ba := Button.new()
		ba.name = "Achievements"
		ba.custom_minimum_size = Vector2(280, 40)
		ba.pressed.connect(_on_achievements_pressed)
		vbox.add_child(ba)
		vbox.move_child(ba, vbox.get_node("Quit").get_index())
	if not vbox.has_node("Controls"):
		var cl := Label.new()
		cl.name = "Controls"
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(420, 0)
		vbox.add_child(cl)
		vbox.move_child(cl, 2)
	# Settings extras
	var sv: VBoxContainer = $SettingsPanel/Margin/VBox
	if not sv.has_node("InvertY"):
		var inv := CheckButton.new()
		inv.name = "InvertY"
		inv.button_pressed = bool(Svc.meta().settings.get("invert_y", false))
		inv.toggled.connect(func(v): Svc.meta().settings["invert_y"] = v)
		sv.add_child(inv)
		sv.move_child(inv, sv.get_node("Back").get_index())
	if not sv.has_node("FOV"):
		var fl := Label.new(); fl.name = "FOVLabel"; fl.text = "FOV"
		var fs := HSlider.new(); fs.name = "FOV"; fs.min_value = 60; fs.max_value = 100; fs.step = 1
		fs.value = float(Svc.meta().settings.get("fov", 75))
		fs.value_changed.connect(func(v): Svc.meta().settings["fov"] = v)
		sv.add_child(fl); sv.add_child(fs)
		sv.move_child(fl, sv.get_node("Back").get_index())
		sv.move_child(fs, sv.get_node("Back").get_index())
	if not sv.has_node("Diff"):
		var db := OptionButton.new(); db.name = "Diff"
		db.add_item("Easy", 0); db.add_item("Normal", 1)
		db.selected = 0 if Svc.meta().settings.get("difficulty", "normal") == "easy" else 1
		db.item_selected.connect(func(i): Svc.meta().settings["difficulty"] = "easy" if i == 0 else "normal")
		sv.add_child(db)
		sv.move_child(db, sv.get_node("Back").get_index())
	if not sv.has_node("NGPlus"):
		var ng := CheckButton.new(); ng.name = "NGPlus"
		ng.button_pressed = bool(Svc.meta().settings.get("ng_plus", false))
		ng.toggled.connect(func(v): Svc.meta().settings["ng_plus"] = v)
		sv.add_child(ng)
		sv.move_child(ng, sv.get_node("Back").get_index())
	if not sv.has_node("Fullscreen"):
		var fs := CheckButton.new(); fs.name = "Fullscreen"
		fs.button_pressed = bool(Svc.meta().settings.get("fullscreen", false))
		fs.toggled.connect(func(v):
			Svc.meta().settings["fullscreen"] = v
			Svc.meta()._apply_display()
		)
		sv.add_child(fs)
		sv.move_child(fs, sv.get_node("Back").get_index())

func _refresh_texts() -> void:
	title.text = "ВЫНЕСИ МУСОР!" if Svc.loc().lang == "ru" else "TAKE OUT THE TRASH!"
	tagline.text = Svc.loc().t("tagline")
	btn_play.text = Svc.loc().t("play")
	btn_levels.text = Svc.loc().t("levels")
	btn_settings.text = Svc.loc().t("settings")
	btn_quit.text = Svc.loc().t("quit")
	if $Center/VBox.has_node("Achievements"):
		$Center/VBox/Achievements.text = Svc.loc().t("achievements")
	if $Center/VBox.has_node("Controls"):
		$Center/VBox/Controls.text = Svc.loc().t("controls_hint")
	if $SettingsPanel/Margin/VBox.has_node("InvertY"):
		$SettingsPanel/Margin/VBox/InvertY.text = Svc.loc().t("invert_y")
	if $SettingsPanel/Margin/VBox.has_node("NGPlus"):
		$SettingsPanel/Margin/VBox/NGPlus.text = Svc.loc().t("ng_plus")
	if $SettingsPanel/Margin/VBox.has_node("Fullscreen"):
		$SettingsPanel/Margin/VBox/Fullscreen.text = Svc.loc().t("fullscreen")

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
		var best = Svc.meta().progress["best_times"].get(str(i + 1), null)
		var best_s := ("  %.0fs" % float(best)) if best != null else ""
		var title_s: String = str(lv.get("title_%s" % Svc.loc().lang, lv.get("title_en", "")))
		b.text = "%d. %s  %s%s" % [i + 1, title_s, star_s, best_s]
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

func _on_achievements_pressed() -> void:
	var lines: PackedStringArray = []
	var ach = Svc.meta().progress.get("achievements", {})
	for id in Svc.steam().list_ids():
		var done := bool(ach.get(id, false))
		var label: String = str(Svc.steam().ach_label(id, Svc.loc().lang))
		lines.append(("%s %s" % ["✓" if done else "○", label]))
	var st = Svc.meta().progress.get("stats", {})
	lines.append("")
	lines.append("%s: dumps=%s bursts=%s fails=%s" % [
		Svc.loc().t("stats"), st.get("dumps", 0), st.get("bursts", 0), st.get("fails", 0)
	])
	var notes: Array = Svc.meta().get_notes()
	if not notes.is_empty():
		lines.append("")
		lines.append(Svc.loc().t("notes") + ":")
		for n in notes:
			lines.append("· " + str(n))
	OS.alert("\n".join(lines), Svc.loc().t("achievements"))
