extends SceneTree
## Headless: все 12 уровней строятся без ошибок.

const LevelData = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _initialize() -> void:
	# Autoloads already present when SceneTree starts with --path project
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	root.name = "TestRoot"
	get_root().add_child(root)
	for i in range(LevelData.count()):
		var lv: Dictionary = LevelData.get_level(i)
		var b = BuildingBuilderScr.new()
		root.add_child(b)
		b.build(lv)
		if b.player == null or b.bag == null or b.dumpster == null:
			push_error("LEVEL_FAIL %d" % (i + 1))
			quit(1)
			return
		print("LEVEL_OK ", i + 1, " floors=", lv.get("floors"), " cargo=", lv.get("cargo"), " bag_hp=", b.bag.hp)
		b.queue_free()
		await process_frame
	print("TEST_LEVELS_PASS count=", LevelData.count())
	quit(0)
