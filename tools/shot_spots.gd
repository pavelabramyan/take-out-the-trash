extends SceneTree
## Прицельные кадры проблемных мест: газон, бордюр, площадка, горизонт.
## Своя камера вместо телепорта игрока: игрок цепляется за коллизии и
## возвращает вид обратно в подъезд.

const OUT := "res://launch/spot_shots"

const SHOTS := [
	{"name": "lawn_close", "pos": Vector3(-3.4, 1.55, 4.4), "look": Vector3(-3.0, 0.1, 7.0)},
	{"name": "curb_side", "pos": Vector3(-4.6, 1.55, 9.6), "look": Vector3(-2.0, 0.1, 11.0)},
	{"name": "bins_side", "pos": Vector3(0.9, 1.6, 12.2), "look": Vector3(3.6, 0.9, 14.6)},
	{"name": "horizon_left", "pos": Vector3(-6.0, 1.7, 12.0), "look": Vector3(-24.0, 6.0, 20.0)},
	{"name": "horizon_back", "pos": Vector3(0.0, 1.7, 17.0), "look": Vector3(2.0, 8.0, 40.0)},
	{"name": "tree", "pos": Vector3(-5.4, 1.6, 8.6), "look": Vector3(-8.0, 3.4, 12.0)},
	{"name": "yard_wide", "pos": Vector3(0.0, 2.4, 6.0), "look": Vector3(2.0, 1.0, 15.0)},
	{"name": "facade_back", "pos": Vector3(2.0, 1.7, 16.0), "look": Vector3(0.0, 7.0, -2.0)},
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
	await create_timer(1.6).timeout
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
	var src: Camera3D = p.camera
	var cam := Camera3D.new()
	cam.fov = src.fov if src else 68.0
	cam.attributes = src.attributes if src else null
	cam.environment = src.environment if src else null
	builder.add_child(cam)
	for s in SHOTS:
		cam.global_position = s["pos"]
		cam.look_at(s["look"], Vector3.UP)
		cam.make_current()
		await create_timer(0.3).timeout
		for _i in range(6):
			await process_frame
		var img := get_root().get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/%s.png" % [abs_out, s["name"]])
			print("SHOT ", s["name"], " cam=", cam.global_position)
	print("SPOTS_DONE")
	quit(0)
