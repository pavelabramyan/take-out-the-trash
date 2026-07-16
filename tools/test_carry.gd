extends SceneTree
## Тест: bag held сохраняет collision; damage API; re-grab path.

const LevelDataScr = preload("res://scripts/level_data.gd")
const BuildingBuilderScr = preload("res://scripts/building_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var b = BuildingBuilderScr.new()
	root.add_child(b)
	b.build(LevelDataScr.get_level(0))
	b.bag.grab(b.player.hold_point)
	assert(b.bag.held)
	assert(b.bag.collision_mask == 1)
	assert(b.bag.collision_layer == 4)
	assert(b.bag.freeze == false)
	var hp0: float = b.bag.hp
	b.bag._apply_damage(10.0)
	assert(b.bag.hp < hp0)
	b.bag.release(Vector3(0, 1, 0))
	assert(not b.bag.held)
	b.bag.grab(b.player.hold_point)
	assert(b.bag.held)
	assert(b.bag.collision_mask == 1)
	print("TEST_CARRY_PASS hp=", b.bag.hp, " mask=", b.bag.collision_mask)
	quit(0)
