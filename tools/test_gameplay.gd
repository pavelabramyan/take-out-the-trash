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
	var game = null
	for c in get_root().get_children():
		if c is Node3D and c.get("builder") != null:
			game = c
			break
	if game == null:
		push_error("Game node not found")
		quit(1)
		return
	if game.builder == null or game.builder.bag == null:
		push_error("Builder/bag missing")
		quit(1)
		return
	if not game.builder.bag.held:
		push_error("Bag not held")
		quit(1)
		return
	print("TEST_GAMEPLAY_PASS bag_hp=", game.builder.bag.hp)
	quit(0)
