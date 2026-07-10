extends Node3D
## Игровой цикл уровня: победа / поражение / звёзды / рестарт.

const LevelData = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

enum State { PLAY, WIN, FAIL, PAUSE }

var state: State = State.PLAY
var level_index: int = 0
var level: Dictionary = {}
var builder: Node3D
var elapsed: float = 0.0
var burst_count: int = 0
var spotted: bool = false
var pieces_left: int = 0
var elevator_used: bool = false
var elevator_jammed: bool = false

@onready var ui: CanvasLayer = $UI
@onready var hud_label: Label = $UI/HUD/Info
@onready var hp_bar: ProgressBar = $UI/HUD/BagHP
@onready var title_label: Label = $UI/HUD/Title
@onready var prompt_label: Label = $UI/HUD/Prompt
@onready var end_panel: PanelContainer = $UI/EndPanel
@onready var end_title: Label = $UI/EndPanel/VBox/EndTitle
@onready var end_stars: Label = $UI/EndPanel/VBox/Stars
@onready var pause_panel: PanelContainer = $UI/PausePanel

func _ready() -> void:
	level_index = Svc.meta().current_level
	level = LevelData.get_level(level_index)
	if level.is_empty():
		level = LevelData.get_level(0)
		level_index = 0
	_start_level()
	end_panel.visible = false
	pause_panel.visible = false
	Svc.audio().yell_mom()

func _start_level() -> void:
	if builder:
		builder.queue_free()
	var b = BuildingBuilderScr.new()
	add_child(b)
	builder = b
	builder.build(level)
	builder.player.game = self
	builder.bag.game = self
	builder.player.capture_mouse(true)
	builder.bag.grab(builder.player.hold_point)
	builder.bag.damaged.connect(_on_bag_damaged)
	builder.bag.burst.connect(_on_bag_burst)
	builder.player.slipped.connect(_on_slipped)
	for npc in builder.npcs:
		npc.set_player(builder.player)
		npc.game = self
		npc.spotted.connect(_on_spotted)
	builder.set_light_flicker(bool(level.get("night", false)) and float(level.get("light_timer", 0)) > 0.0, maxf(1.0, float(level.get("light_timer", 8.0))))
	elapsed = 0.0
	burst_count = 0
	spotted = false
	pieces_left = 0
	elevator_used = false
	elevator_jammed = false
	state = State.PLAY
	title_label.text = "%s %d — %s" % [Svc.loc().t("level"), level_index + 1, level.get("title_%s" % Svc.loc().lang, level.get("title_en", ""))]
	hp_bar.max_value = float(level.get("bag_hp", 100))
	hp_bar.value = hp_bar.max_value
	prompt_label.text = str(level.get("hint_%s" % Svc.loc().lang, level.get("hint_en", "")))
	end_panel.visible = false

func _process(delta: float) -> void:
	if state == State.PLAY:
		elapsed += delta
		builder.player.on_ice = builder.is_on_ice(builder.player.global_position)
		_update_hud()
		_check_interactions()
	if Input.is_action_just_pressed("restart") and state != State.PAUSE:
		Svc.steam().note_restart()
		_restart()
	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause()

func _update_hud() -> void:
	var bag = builder.bag
	var hp: float = 0.0 if bag.bursted else float(bag.hp)
	hp_bar.value = hp
	hud_label.text = "%s  %.0fs" % [Svc.loc().t("bag_hp"), elapsed]
	if bag.bursted:
		var left := get_tree().get_nodes_in_group("trash_piece").size()
		prompt_label.text = Svc.loc().t("pick_trash") + " (%d)" % left

func _check_interactions() -> void:
	var player: Node3D = builder.player
	var bag: RigidBody3D = builder.bag

	# Подбор кусков
	if Input.is_action_just_pressed("interact"):
		for piece in get_tree().get_nodes_in_group("trash_piece"):
			if piece.has_method("try_pick") and piece.try_pick(player):
				break
		# Если все куски собраны и пакет порван — «условно» можно донести «ничего» к помойке? 
		# Правило: после разрыва нужно собрать ВСЕ куски и донести их (считаем победой у помойки если pieces==0 и был у dumpster)
		# Лифт
		if builder.elevator_area and player.global_position.distance_to(builder.elevator_area.global_position) < 2.0:
			_try_elevator()
		# Помойка
		if builder.dumpster and player.global_position.distance_to(builder.dumpster.global_position) < 2.8:
			_try_dump()

	# Подсказка у помойки
	if builder.dumpster and player.global_position.distance_to(builder.dumpster.global_position) < 3.0:
		if not bag.bursted or get_tree().get_nodes_in_group("trash_piece").is_empty():
			prompt_label.text = Svc.loc().t("dumpster")
	elif builder.elevator_area and player.global_position.distance_to(builder.elevator_area.global_position) < 2.2:
		prompt_label.text = Svc.loc().t("elevator")

func _try_elevator() -> void:
	if elevator_used:
		return
	elevator_used = true
	Svc.audio().play_sfx("elevator")
	# 40% шанс застрять
	if randf() < 0.4:
		elevator_jammed = true
		Svc.steam().unlock("elevator_fail")
		prompt_label.text = "…"
		await get_tree().create_timer(2.5).timeout
		prompt_label.text = Svc.loc().t("elevator") + " ✕"
		# Телепорт на случайный этаж посередине
		var mid := maxi(1, int(level.get("floors", 2)) / 2)
		builder.player.global_position = Vector3(0.0, float(mid) * 3.0 + 0.2, 0.5)
		builder.bag.global_position = builder.player.global_position + Vector3(0.3, 0.5, 0)
		if builder.bag.held:
			builder.bag.grab(builder.player.hold_point)
	else:
		Svc.steam().unlock("elevator_luck")
		# Успех — на 1 этаж
		builder.player.global_position = Vector3(0.0, 0.2, 1.5)
		if builder.bag.held:
			builder.bag.grab(builder.player.hold_point)
		else:
			builder.bag.global_position = builder.player.global_position + Vector3(0.3, 0.4, 0)

func _try_dump() -> void:
	var bag: RigidBody3D = builder.bag
	if bag.bursted:
		if not get_tree().get_nodes_in_group("trash_piece").is_empty():
			prompt_label.text = Svc.loc().t("pick_trash")
			return
		# Все куски собраны — победа «с позором»
		_win(true)
		return
	if not bag.held and bag.global_position.distance_to(builder.dumpster.global_position) > 3.5:
		# Нужно нести пакет
		return
	_win(false)

func _win(after_burst: bool) -> void:
	if state != State.PLAY:
		return
	state = State.WIN
	builder.player.active = false
	builder.player.capture_mouse(false)
	Svc.audio().play_sfx("win")
	Svc.steam().note_win_reset_restarts()

	var stars := 0
	var time_ok := elapsed <= float(level.get("time_star", 999))
	var intact := burst_count == 0 and not after_burst
	var stealth := not spotted
	if time_ok:
		stars += 1
	if intact:
		stars += 1
	if stealth:
		stars += 1

	Svc.meta().set_stars(level_index + 1, stars)
	Svc.meta().set_best_time(level_index + 1, elapsed)
	Svc.meta().unlock_level(level_index + 2)
	_grant_achievements(stars, intact, stealth, time_ok)

	end_title.text = Svc.loc().t("win")
	end_stars.text = "%s: %s%s%s\n%.1fs" % [
		Svc.loc().t("stars"),
		"★" if time_ok else "☆",
		"★" if intact else "☆",
		"★" if stealth else "☆",
		elapsed,
	]
	end_panel.visible = true
	if level_index + 1 >= LevelData.count():
		end_stars.text += "\n\n" + Svc.loc().t("credits")
		Svc.steam().unlock("all_levels")
		Svc.steam().unlock("mom_proud")
		Svc.steam().unlock("fridge_done")

func _grant_achievements(stars: int, intact: bool, stealth: bool, time_ok: bool) -> void:
	if level_index == 0:
		Svc.steam().unlock("first_dump")
	if burst_count > 0:
		Svc.steam().unlock("burst_once")
	if intact:
		Svc.steam().unlock("no_tear_star")
	if stealth:
		Svc.steam().unlock("stealth_star")
	if time_ok:
		Svc.steam().unlock("speed_star")
	if stars == 3:
		Svc.steam().unlock("triple_star")
	if bool(level.get("ice", false)):
		Svc.steam().unlock("ice_slip")
	if int(level.get("dogs", 0)) > 0 and not spotted:
		Svc.steam().unlock("dog_escape")
	if int(level.get("babushkas", 0)) > 0 and stealth:
		Svc.steam().unlock("babushka_escape")
	if str(level.get("cargo", "")) == "carpet":
		Svc.steam().unlock("carpet_done")
	if str(level.get("cargo", "")) == "fridge":
		Svc.steam().unlock("fridge_done")
	if bool(level.get("basement", false)):
		Svc.steam().unlock("basement_run")
	if bool(level.get("night", false)):
		Svc.steam().unlock("night_dump")
	if float(level.get("wind", 0)) > 0.0 and burst_count == 0:
		Svc.steam().unlock("wind_hold")
	# all stars
	var total := 0
	for i in range(LevelData.count()):
		total += Svc.meta().get_stars(i + 1)
	if total >= LevelData.count() * 3:
		Svc.steam().unlock("all_stars")

func _fail(reason_key: String) -> void:
	if state != State.PLAY:
		return
	state = State.FAIL
	builder.player.active = false
	builder.player.capture_mouse(false)
	end_title.text = Svc.loc().t(reason_key)
	end_stars.text = Svc.loc().t("restart")
	end_panel.visible = true

func _on_bag_damaged(hp_left: float, max_hp: float) -> void:
	hp_bar.value = hp_left

func _on_bag_burst() -> void:
	burst_count += 1
	Svc.steam().unlock("burst_once")
	# Не мгновенный fail — собирай куски
	prompt_label.text = Svc.loc().t("fail_burst") + "\n" + Svc.loc().t("pick_trash")

func _on_spotted(kind: int) -> void:
	spotted = true
	if kind == 1:  # dog
		_fail("fail_dog")
	else:
		_fail("fail_caught")

func _on_slipped() -> void:
	Svc.steam().unlock("ice_slip")
	# Шанс выронить пакет
	if builder.bag.held and randf() < 0.55:
		builder.bag.release(builder.player.velocity + Vector3(0, 1, 0))

func _restart() -> void:
	get_tree().reload_current_scene()

func _toggle_pause() -> void:
	if state == State.WIN or state == State.FAIL:
		return
	if state == State.PAUSE:
		state = State.PLAY
		pause_panel.visible = false
		builder.player.active = true
		builder.player.capture_mouse(true)
		get_tree().paused = false
	else:
		state = State.PAUSE
		pause_panel.visible = true
		builder.player.active = false
		builder.player.capture_mouse(false)

func _on_next_pressed() -> void:
	if level_index + 1 >= LevelData.count():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	Svc.meta().current_level = level_index + 1
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_retry_pressed() -> void:
	_restart()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_resume_pressed() -> void:
	_toggle_pause()
