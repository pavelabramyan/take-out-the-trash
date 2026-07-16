extends Node3D
## Игровой цикл: carry-физика, пауза, juice, звёзды, лифт.

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
var slipped_this_level: bool = false
var elevator_used: bool = false
var elevator_jammed: bool = false
var armful: int = 0
var _shake: float = 0.0
var _slow_t: float = 0.0
var _replay: Array = []
var _babushka_listen_t: float = 0.0
var _babushka_listening: bool = false
var _mom_yelled: bool = false
var _music_started: bool = false

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	level_index = Svc.meta().current_level
	level = LevelData.get_level(level_index)
	if level.is_empty():
		level = LevelData.get_level(0)
		level_index = 0
	_apply_difficulty_hp()
	_start_level()
	end_panel.visible = false
	pause_panel.visible = false
	_localize_panels()

func _apply_difficulty_hp() -> void:
	level = level.duplicate(true)
	var diff: String = str(Svc.meta().settings.get("difficulty", "normal"))
	if diff == "easy" and level.has("bag_hp"):
		level["bag_hp"] = float(level["bag_hp"]) * 1.45
	if bool(Svc.meta().settings.get("ng_plus", false)):
		level = LevelData.apply_ng_plus(level)

func _localize_panels() -> void:
	var next_b: Button = $UI/EndPanel/VBox/Next
	var retry_b: Button = $UI/EndPanel/VBox/Retry
	var menu_b: Button = $UI/EndPanel/VBox/Menu
	var resume_b: Button = $UI/PausePanel/VBox/Resume
	var restart_b: Button = $UI/PausePanel/VBox/Restart
	var to_menu: Button = $UI/PausePanel/VBox/ToMenu
	var paused_l: Label = $UI/PausePanel/VBox/Paused
	next_b.text = Svc.loc().t("next")
	retry_b.text = Svc.loc().t("restart")
	menu_b.text = Svc.loc().t("menu")
	resume_b.text = Svc.loc().t("resume")
	restart_b.text = Svc.loc().t("restart")
	to_menu.text = Svc.loc().t("menu")
	paused_l.text = Svc.loc().t("paused")

func _start_level() -> void:
	if builder:
		builder.queue_free()
	var b = BuildingBuilderScr.new()
	add_child(b)
	builder = b
	builder.process_mode = Node.PROCESS_MODE_PAUSABLE
	builder.build(level)
	builder.player.game = self
	builder.bag.game = self
	builder.player.capture_mouse(true)
	builder.bag.grab(builder.player.hold_point)
	builder.player.set_cargo_feel(builder.bag.speed_mult(), builder.bag.fov_offset(), builder.bag.yaw_mult())
	builder.bag.damaged.connect(_on_bag_damaged)
	builder.bag.burst.connect(_on_bag_burst)
	builder.player.slipped.connect(_on_slipped)
	builder.player.fell_hard.connect(_on_fell_hard)
	builder.player.throw_pressed.connect(_on_throw)
	builder.player.drop_pressed.connect(_on_drop)
	for npc in builder.npcs:
		npc.set_player(builder.player)
		npc.game = self
		npc.spotted.connect(_on_spotted)
	builder.set_light_flicker(bool(level.get("night", false)) and float(level.get("light_timer", 0)) > 0.0, maxf(1.0, float(level.get("light_timer", 8.0))))
	elapsed = 0.0
	burst_count = 0
	spotted = false
	slipped_this_level = false
	armful = 0
	elevator_used = false
	elevator_jammed = false
	_babushka_listening = false
	_mom_yelled = false
	_music_started = false
	_replay.clear()
	state = State.PLAY
	title_label.text = "%s %d — %s" % [Svc.loc().t("level"), level_index + 1, level.get("title_%s" % Svc.loc().lang, level.get("title_en", ""))]
	hp_bar.max_value = float(level.get("bag_hp", 100))
	hp_bar.value = hp_bar.max_value
	prompt_label.text = str(level.get("hint_%s" % Svc.loc().lang, level.get("hint_en", "")))
	end_panel.visible = false
	Svc.steam().set_rich_presence(level_index + 1, str(level.get("cargo", "bag")))

func _process(delta: float) -> void:
	if state == State.PAUSE:
		if Input.is_action_just_pressed("pause_menu"):
			_toggle_pause()
		return
	if state == State.PLAY:
		elapsed += delta
		builder.player.on_ice = builder.is_on_ice(builder.player.global_position)
		builder.bag.careful = builder.player.careful
		_update_hud()
		_check_interactions()
		_update_shake(delta)
		_record_replay()
		_atmosphere_cues()
		if _slow_t > 0.0:
			_slow_t -= delta
			Engine.time_scale = 0.35 if _slow_t > 0.0 else 1.0
	if Input.is_action_just_pressed("restart") and state != State.PAUSE:
		Svc.steam().note_restart()
		Engine.time_scale = 1.0
		_restart()
	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause()
	if Input.is_action_just_pressed("photo_mode"):
		_photo_snap()

func _atmosphere_cues() -> void:
	if builder == null or builder.player == null:
		return
	if not _mom_yelled and builder.player.velocity.length() > 0.55:
		_mom_yelled = true
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			if state == State.PLAY:
				Svc.audio().yell_mom()
		)
	if not _music_started and elapsed > 14.0:
		_music_started = true
		Svc.audio().play_music("game_music")

func _update_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 4.0)
	if builder and builder.player and builder.player.camera:
		var cam: Camera3D = builder.player.camera
		if _shake > 0.0:
			cam.h_offset = randf_range(-0.04, 0.04) * _shake
			cam.v_offset = randf_range(-0.04, 0.04) * _shake
		else:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

func _record_replay() -> void:
	if builder == null or builder.player == null:
		return
	_replay.append({"t": elapsed, "p": builder.player.global_position, "y": builder.player.rotation.y})
	while _replay.size() > 150:
		_replay.pop_front()

func _photo_snap() -> void:
	prompt_label.text = "PHOTO" if Svc.loc().lang == "en" else "ФОТО"
	# Визуальный маркер — реальный захват экрана делает игрок/Steam

func _update_hud() -> void:
	var bag = builder.bag
	var hp: float = 0.0 if bag.bursted else float(bag.hp)
	hp_bar.value = hp
	var extra := ""
	if armful > 0:
		extra = "  [%d]" % armful
	var careful_s := " · CARE" if builder.player.careful else ""
	hud_label.text = "%s  %.0fs%s%s" % [Svc.loc().t("bag_hp"), elapsed, extra, careful_s]
	if bag.bursted:
		var left := get_tree().get_nodes_in_group("trash_piece").size()
		prompt_label.text = Svc.loc().t("pick_trash") + " (%d) · armful %d" % [left, armful]

func _check_interactions() -> void:
	var player: Node3D = builder.player
	var bag = builder.bag
	var prompt := ""

	if Input.is_action_just_pressed("interact"):
		# Re-grab bag
		if not bag.held and not bag.bursted and player.global_position.distance_to(bag.global_position) < 2.4:
			bag.grab(builder.player.hold_point)
			builder.player.set_cargo_feel(bag.speed_mult(), bag.fov_offset(), bag.yaw_mult())
			Svc.audio().play_sfx("pickup")
			return
		# Armful pieces
		for piece in get_tree().get_nodes_in_group("trash_piece"):
			if piece.has_method("try_pick") and piece.try_pick(player):
				armful += 1
				bag.add_to_armful()
				break
		if builder.elevator_area and player.global_position.distance_to(builder.elevator_area.global_position) < 2.0:
			_try_elevator()
			return
		if builder.dumpster and player.global_position.distance_to(builder.dumpster.global_position) < 3.6:
			_try_dump()
			return
		if _babushka_listening:
			_babushka_listen_t -= 0.0

	if not bag.held and not bag.bursted and player.global_position.distance_to(bag.global_position) < 2.4:
		prompt = Svc.loc().t("pick_bag")
	elif builder.dumpster and player.global_position.distance_to(builder.dumpster.global_position) < 4.0:
		if not bag.bursted or get_tree().get_nodes_in_group("trash_piece").is_empty() or armful > 0:
			prompt = Svc.loc().t("dumpster")
	elif builder.elevator_area and player.global_position.distance_to(builder.elevator_area.global_position) < 2.2:
		prompt = Svc.loc().t("elevator")
	elif bag.bursted and get_tree().get_nodes_in_group("trash_piece").size() > 0:
		prompt = Svc.loc().t("pick_trash")
	else:
		prompt = builder.guide_hint(player.global_position)
	if prompt != "":
		prompt_label.text = prompt

func _on_throw() -> void:
	if state != State.PLAY or builder.bag.bursted or not builder.bag.held:
		return
	var dir: Vector3 = -builder.player.camera.global_transform.basis.z
	builder.bag.throw_forward(dir, 6.0 if not builder.player.careful else 3.0)
	builder.player.clear_cargo_feel()

func _on_drop() -> void:
	if state != State.PLAY or builder.bag.bursted or not builder.bag.held:
		return
	builder.bag.drop_gentle()
	builder.player.clear_cargo_feel()

func _try_elevator() -> void:
	if elevator_used:
		return
	elevator_used = true
	Svc.audio().play_sfx("elevator")
	builder.player.active = false
	var jam := randf() < 0.4
	prompt_label.text = "…"
	var start_y: float = float(builder.player.global_position.y)
	var target_y: float = 0.2
	var land_z: float = -0.5
	if jam:
		elevator_jammed = true
		Svc.steam().unlock("elevator_fail")
		target_y = float(maxi(1, int(level.get("floors", 2)) / 2)) * BuildingBuilder.FLOOR_H + 0.25
	else:
		Svc.steam().unlock("elevator_luck")
	var start_xz: Vector3 = builder.player.global_position
	var t: float = 0.0
	while t < 1.4:
		await get_tree().process_frame
		if state != State.PLAY:
			builder.player.active = true
			return
		t += get_process_delta_time()
		var k: float = clampf(t / 1.4, 0.0, 1.0)
		var y: float = lerpf(start_y, target_y, k)
		builder.player.global_position = Vector3(
			lerpf(start_xz.x, 0.0, k),
			y,
			lerpf(start_xz.z, land_z, k)
		)
		if builder.bag.held and builder.player.hold_point:
			builder.bag.global_position = builder.player.hold_point.global_position
		else:
			builder.bag.global_position = builder.player.global_position + Vector3(0.3, 0.4, 0)
	builder.player.global_position = Vector3(0.0, target_y, land_z)
	builder.player.velocity = Vector3.ZERO
	builder.player.active = true
	prompt_label.text = Svc.loc().t("elevator") + (" ✕" if jam else " ✓")

func _try_dump() -> void:
	var bag = builder.bag
	if bag.bursted:
		var left := get_tree().get_nodes_in_group("trash_piece").size()
		if left > 0 and armful < 1:
			prompt_label.text = Svc.loc().t("pick_trash")
			return
		# Охапка или всё собрано
		if left > 0:
			# Сбрасываем охапку в бак порциями
			armful = 0
			for piece in get_tree().get_nodes_in_group("trash_piece"):
				piece.queue_free()
		_win(true)
		return
	if not bag.held and bag.global_position.distance_to(builder.dumpster.global_position) > 3.5:
		return
	Svc.audio().play_sfx("dump")
	_win(false)

func _win(after_burst: bool) -> void:
	if state != State.PLAY:
		return
	state = State.WIN
	Engine.time_scale = 1.0
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
	Svc.meta().add_stat("dumps", 1)
	Svc.meta().add_stat("bursts", burst_count)
	var note: String = str(level.get("note_%s" % Svc.loc().lang, level.get("note_en", "")))
	if not note.is_empty():
		Svc.meta().unlock_note(note)
	_grant_achievements(stars, intact, stealth, time_ok)

	end_title.text = Svc.loc().t("win")
	end_stars.text = "%s: %s%s%s\n%s %.1fs · best %.1fs" % [
		Svc.loc().t("stars"),
		"★" if time_ok else "☆",
		"★" if intact else "☆",
		"★" if stealth else "☆",
		Svc.loc().t("star_time"),
		elapsed,
		float(Svc.meta().progress["best_times"].get(str(level_index + 1), elapsed)),
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
	if slipped_this_level:
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
	var total := 0
	for i in range(LevelData.count()):
		total += Svc.meta().get_stars(i + 1)
	if total >= LevelData.count() * 3:
		Svc.steam().unlock("all_stars")

func _fail(reason_key: String) -> void:
	if state != State.PLAY:
		return
	state = State.FAIL
	Engine.time_scale = 1.0
	builder.player.active = false
	builder.player.capture_mouse(false)
	Svc.meta().add_stat("fails", 1)
	end_title.text = Svc.loc().t(reason_key)
	# Мини-replay текст
	var replay_s := ""
	if _replay.size() > 2:
		replay_s = "\n" + Svc.loc().t("replay_hint")
	end_stars.text = Svc.loc().t("restart") + replay_s
	end_panel.visible = true

func _on_bag_damaged(hp_left: float, _max_hp: float) -> void:
	hp_bar.value = hp_left

func _on_bag_burst() -> void:
	burst_count += 1
	_shake = 1.2
	_slow_t = 0.22
	builder.player.clear_cargo_feel()
	Svc.steam().unlock("burst_once")
	Svc.audio().yell_mom()
	prompt_label.text = Svc.loc().t("fail_burst") + "\n" + Svc.loc().t("pick_trash")

func _on_spotted(kind: int) -> void:
	# Бабушка: можно «выслушать» 3 сек вместо мгновенного fail
	if kind != 1 and bool(level.get("babushka_talk", true)):
		if not _babushka_listening:
			_babushka_listening = true
			_babushka_listen_t = 3.0
			prompt_label.text = Svc.loc().t("babushka_listen")
			spotted = true
			await get_tree().create_timer(3.0).timeout
			if state == State.PLAY and _babushka_listening:
				_babushka_listening = false
				# Отпустили с позором — стелс звезда потеряна, но уровень жив
				prompt_label.text = Svc.loc().t("babushka_ok")
			return
	spotted = true
	if kind == 1:
		_fail("fail_dog")
	else:
		_fail("fail_caught")

func _on_slipped() -> void:
	slipped_this_level = true
	_shake = 0.6
	if builder.bag.held:
		builder.bag.release(builder.player.velocity + Vector3(0, 1.5, 0))
		builder.player.clear_cargo_feel()

func _on_fell_hard(fall_speed: float) -> void:
	_shake = 0.8
	if builder.bag.held:
		builder.bag.apply_fall_damage(fall_speed)
	elif fall_speed > 14.0:
		_fail("fail_fall")

func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
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
		get_tree().paused = true

func _on_next_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if level_index + 1 >= LevelData.count():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	Svc.meta().current_level = level_index + 1
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_retry_pressed() -> void:
	_restart()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_resume_pressed() -> void:
	_toggle_pause()
