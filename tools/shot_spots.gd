extends SceneTree
## Прицельные кадры проблемных мест: газон, бордюр, площадка, горизонт.
## Игрока телепортируем так же, как в visual_reality_pass — иначе камера
## возвращается к своему владельцу и кадр уходит не туда.

const OUT := "res://launch/spot_shots"

const SHOTS := [
	{"name": "lawn_close", "pos": Vector3(-3.4, 0.05, 4.4), "yaw": 180.0, "pitch": -32.0},
	{"name": "curb_side", "pos": Vector3(-4.6, 0.05, 9.6), "yaw": 250.0, "pitch": -24.0},
	{"name": "bins_side", "pos": Vector3(0.9, 0.05, 12.2), "yaw": 215.0, "pitch": -8.0},
	{"name": "horizon_left", "pos": Vector3(-6.0, 0.05, 12.0), "yaw": 270.0, "pitch": 4.0},
	{"name": "horizon_back", "pos": Vector3(0.0, 0.05, 17.0), "yaw": 180.0, "pitch": 6.0},
	{"name": "tree", "pos": Vector3(-5.4, 0.05, 8.6), "yaw": 245.0, "pitch": 14.0},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var abs_out := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(abs_out)
	if change_scene_to_file("res://scenes/game.tscn") != OK:
		quit(1)
		return
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
	for s in SHOTS:
		p.global_transform = Transform3D(Basis.IDENTITY, s["pos"])
		p.velocity = Vector3.ZERO
		if p.has_method("set_look_yaw"):
			p.set_look_yaw(deg_to_rad(float(s["yaw"])))
		else:
			p.rotation.y = deg_to_rad(float(s["yaw"]))
		p.set("_pitch", deg_to_rad(float(s["pitch"])))
		if p.camera:
			p.camera.rotation.x = deg_to_rad(float(s["pitch"]))
			p.camera.current = true
		await create_timer(0.25).timeout
		for _i in range(6):
			await process_frame
		var img := get_root().get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/%s.png" % [abs_out, s["name"]])
			print("SHOT ", s["name"])
	print("SPOTS_DONE")
	quit(0)
