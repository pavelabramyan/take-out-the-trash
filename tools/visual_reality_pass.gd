extends SceneTree
## Кадры ключевых точек уровня 0 → launch/reality_shots/ (+ /tmp).

const BuildingBuilderScr = preload("res://scripts/building_builder.gd")
const OUT_TMP := "/tmp/trash_reality_review"
const OUT_REPO := "res://launch/reality_shots"

var _last_shot_md5: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _abs_out() -> String:
	return ProjectSettings.globalize_path(OUT_REPO)

func _img_md5(img: Image) -> String:
	return img.get_data().hex_encode().substr(0, 32)

func _shot(name: String) -> void:
	var cam := get_root().get_viewport().get_camera_3d()
	var img: Image = null
	for attempt in range(8):
		await create_timer(0.12).timeout
		for _i in range(4):
			await process_frame
		img = get_root().get_viewport().get_texture().get_image()
		if img == null:
			continue
		var md := str(img.get_width()) + "x" + str(img.get_height()) + ":" + str(img.get_pixel(8, 8)) + ":" + str(img.get_pixel(img.get_width() - 9, img.get_height() - 9))
		if md != _last_shot_md5 or attempt == 7:
			_last_shot_md5 = md
			break
		print("RETRY_SHOT ", name, " attempt=", attempt)
	if img == null:
		push_error("No viewport image for %s" % name)
		return
	img.save_png("%s/%s.png" % [OUT_TMP, name])
	img.save_png("%s/%s.png" % [_abs_out(), name])
	print("SHOT ", name, " cam=", cam.global_position if cam else "?")

func _look(p: CharacterBody3D, yaw_deg: float, pitch_deg: float = -8.0) -> void:
	if p.has_method("set_look_yaw"):
		p.set_look_yaw(deg_to_rad(yaw_deg))
	else:
		p.rotation.y = deg_to_rad(yaw_deg)
	p.set("_pitch", deg_to_rad(pitch_deg))
	if p.camera:
		p.camera.rotation.x = deg_to_rad(pitch_deg)
		p.camera.current = true

func _place(p: CharacterBody3D, pos: Vector3, yaw_deg: float, pitch_deg: float = -8.0) -> void:
	p.global_transform = Transform3D(Basis.IDENTITY, pos)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	_look(p, yaw_deg, pitch_deg)
	for _i in range(6):
		await process_frame
	print("PLACE ", pos, " -> ", p.global_position)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_TMP)
	DirAccess.make_dir_recursive_absolute(_abs_out())
	var err := change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("scene fail %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	await create_timer(1.4).timeout

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
	var ui = game.get_node_or_null("UI")
	if ui:
		ui.visible = false

	var H: float = BuildingBuilderScr.FLOOR_H
	var HH: float = BuildingBuilderScr.HALF_H
	var sx: float = BuildingBuilderScr.STAIR_X
	var door_z: float = BuildingBuilderScr.DOOR_Z

	await _place(p, p.global_position, 180.0, -12.0)
	await _shot("01_start_apartment")

	# Крупный пакет: смотрим вниз на hold_point
	await _place(p, p.global_position, 0.0, -62.0)
	if builder.bag and builder.bag.held:
		builder.bag.global_position = p.camera.global_position + p.camera.global_transform.basis * Vector3(0.05, -0.25, -0.45)
	await _shot("02_bag_closeup")

	await _place(p, Vector3(sx, H * 2.0 + 0.05, 0.3), 0.0, -35.0)
	await _shot("03_stairs_top_down")

	# Смотрим на лестницу + зелёнку боковой стены (не в лифт)
	await _place(p, Vector3(0.15, H * 2.0 - HH + 0.05, 2.2), 35.0, -18.0)
	await _shot("04_mid_landing")

	await _place(p, Vector3(sx, H + 1.35, 1.35), 10.0, -28.0)
	await _shot("05_on_stairs")

	await _place(p, Vector3(0.0, 0.05, 1.8), 180.0, -6.0)
	await _shot("06_lobby_to_door")

	await _place(p, Vector3(0.0, 0.05, door_z - 0.6), 180.0, -10.0)
	await _shot("07_exit_door")

	# yaw=180 смотрит в +Z (двор/помойка); yaw=0 — в −Z (к дому)
	var dump: Node3D = builder.dumpster
	if dump:
		var dp: Vector3 = dump.global_position
		await _place(p, Vector3(dp.x, 0.05, dp.z - 3.5), 180.0, -12.0)
		await _shot("08_yard_dumpster")
		await _place(p, Vector3(dp.x - 1.4, 0.05, dp.z - 2.0), 140.0, -18.0)
		await _shot("09_dumpster_close")
	else:
		await _place(p, Vector3(0.0, 0.05, door_z + 4.0), 180.0, -10.0)
		await _shot("08_yard_dumpster")
		await _shot("09_dumpster_close")

	await _place(p, Vector3(0.0, H + 0.05, 1.0), 90.0, 0.0)
	await _shot("10_cell_narrow")

	if builder.bag and builder.bag.held:
		builder.bag.release(Vector3.ZERO)
		await create_timer(0.8).timeout
	var bag_pos: Vector3 = builder.bag.global_position
	await _place(p, bag_pos + Vector3(0.55, 0.0, 0.55), 225.0, -35.0)
	await _shot("11_bag_on_floor")

	if builder.bag and not builder.bag.held:
		builder.bag.grab(p.hold_point)
	await _place(p, Vector3(0.0, 0.05, door_z + 2.2), 180.0, -22.0)
	await _shot("12_carry_outside")

	print("VISUAL_REALITY_PASS_DONE out=", _abs_out())
	quit(0)
