extends SceneTree
## Кадры ключевых точек уровня 0 для разбора vs физическая реальность.

const BuildingBuilderScr = preload("res://scripts/building_builder.gd")
const OUT := "/tmp/trash_reality_review"

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = get_root().get_viewport().get_texture().get_image()
	if img == null:
		push_error("No viewport image for %s" % name)
		return
	img.save_png("%s/%s.png" % [OUT, name])
	print("SHOT ", name)

func _look(p: CharacterBody3D, yaw_deg: float, pitch_deg: float = -8.0) -> void:
	if p.has_method("set_look_yaw"):
		p.set_look_yaw(deg_to_rad(yaw_deg))
	else:
		p.rotation.y = deg_to_rad(yaw_deg)
	p.set("_pitch", deg_to_rad(pitch_deg))
	if p.camera:
		p.camera.rotation.x = deg_to_rad(pitch_deg)

func _place(p: CharacterBody3D, pos: Vector3, yaw_deg: float, pitch_deg: float = -8.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	_look(p, yaw_deg, pitch_deg)
	await process_frame
	await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var err := change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("scene fail %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	await create_timer(1.2).timeout

	var game: Node = null
	for c in get_root().get_children():
		if c is Node3D and c.get("builder") != null:
			game = c
			break
	if game == null:
		push_error("game missing")
		quit(1)
		return

	var builder = game.get("builder")
	var p: CharacterBody3D = builder.player
	p.active = false
	p.capture_mouse(false)
	# Спрятать HUD для чистого кадра мира
	var ui = game.get_node_or_null("UI")
	if ui:
		ui.visible = false

	var H: float = BuildingBuilderScr.FLOOR_H
	var HH: float = BuildingBuilderScr.HALF_H
	var sx: float = BuildingBuilderScr.STAIR_X
	var door_z: float = BuildingBuilderScr.DOOR_Z

	# 01 — старт: квартира / площадка, пакет в руках
	await _place(p, p.global_position, 180.0, -12.0)
	await _shot("01_start_apartment")

	# 02 — крупный пакет (смотреть вниз)
	await _place(p, p.global_position, 0.0, -55.0)
	await _shot("02_bag_closeup")

	# 03 — взгляд вниз по лестнице с 2 этажа
	await _place(p, Vector3(sx, H * 2.0 + 0.05, 0.3), 0.0, -35.0)
	await _shot("03_stairs_top_down")

	# 04 — mid landing
	await _place(p, Vector3(0.0, H * 2.0 - HH + 0.05, 2.35), 180.0, -10.0)
	await _shot("04_mid_landing")

	# 05 — марш по лестнице (идти вниз)
	await _place(p, Vector3(sx, H + 1.2, 1.2), 0.0, -20.0)
	await _shot("05_on_stairs")

	# 06 — лобби к выходу
	await _place(p, Vector3(0.0, 0.05, 2.8), 0.0, -5.0)
	await _shot("06_lobby_to_door")

	# 07 — выход / фасад
	await _place(p, Vector3(0.0, 0.05, door_z - 0.8), 0.0, -8.0)
	await _shot("07_exit_door")

	# 08 — двор / помойка
	var dump: Node3D = builder.dumpster
	if dump:
		var dp: Vector3 = dump.global_position
		await _place(p, Vector3(dp.x, 0.05, dp.z - 3.5), 0.0, -12.0)
		await _shot("08_yard_dumpster")
		await _place(p, Vector3(dp.x + 1.2, 0.05, dp.z - 1.8), -40.0, -15.0)
		await _shot("09_dumpster_close")
	else:
		await _place(p, Vector3(0.0, 0.05, door_z + 4.0), 0.0, -10.0)
		await _shot("08_yard_dumpster")
		await _shot("09_dumpster_close")

	# 10 — клетка узким кадром (стены рядом)
	await _place(p, Vector3(0.0, H + 0.05, 1.0), 90.0, 0.0)
	await _shot("10_cell_narrow")

	# 11 — пакет на полу
	if builder.bag and builder.bag.held:
		builder.bag.release(Vector3.ZERO)
		await create_timer(0.6).timeout
	await _place(p, builder.bag.global_position + Vector3(0.6, 0.0, 0.8), -90.0, -25.0)
	await _shot("11_bag_on_floor")

	# 12 — поднять снова и вид «несу по двору»
	if builder.bag and not builder.bag.held:
		builder.bag.grab(p.hold_point)
	await _place(p, Vector3(0.0, 0.05, door_z + 2.0), 0.0, -18.0)
	await _shot("12_carry_outside")

	print("VISUAL_REALITY_PASS_DONE")
	quit(0)
