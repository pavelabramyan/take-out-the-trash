extends SceneTree
## Headless smoke: сцена game + пакет в руках.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("Failed to load game scene: %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var game: Node = null
	for c in get_root().get_children():
		if c is Node3D and c.get("builder") != null:
			game = c
			break
	if game == null:
		push_error("Game node not found — script parse/runtime error?")
		quit(1)
		return
	var builder = game.get("builder")
	if builder == null or builder.get("bag") == null:
		push_error("Builder/bag missing")
		quit(1)
		return
	if not bool(builder.bag.held):
		push_error("Bag not held")
		quit(1)
		return
	print("TEST_GAMEPLAY_PASS bag_hp=", builder.bag.hp)
	quit(0)
