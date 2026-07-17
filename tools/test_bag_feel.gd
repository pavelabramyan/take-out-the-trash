extends SceneTree
## Wave1 пакет: не BoxMesh, стадии порчи, burst с кусками/лохмотьями.

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
	for i in range(4):
		await process_frame

	var bag = b.bag
	assert(bag != null)
	assert(bag.cargo == bag.Cargo.BAG)
	assert(bag._is_plastic_bag)
	assert(bag._visual != null)
	assert(bag._body_mi != null)
	assert(bag._handle_l != null and bag._handle_r != null)
	assert(bag._col != null and bag._col.shape is CapsuleShape3D)
	print("MESH_OK body=", bag._body_mi.mesh.get_class(), " col=", bag._col.shape.get_class())

	bag.grab(b.player.hold_point)
	assert(bag.held)
	# Симулируем carry (physics_frame в headless SceneTree ненадёжен)
	for i in range(8):
		bag._carry_follow(0.05)
		await process_frame
	assert(bag._grab_t >= 0.9)
	print("GRAB_OK grab_t=", bag._grab_t)

	bag.careful = false
	var hp0: float = bag.hp
	bag._apply_damage(bag.max_hp * 0.30)
	print("TEAR1 stage=", bag.tear_stage, " hp=", bag.hp, "/", bag.max_hp)
	assert(bag.hp < hp0)
	assert(bag.tear_stage == bag.TearStage.WORN)
	assert(bag._mat.emission_enabled == false)

	bag._apply_damage(bag.max_hp * 0.35)
	print("TEAR2 stage=", bag.tear_stage, " hp=", bag.hp)
	assert(bag.tear_stage >= bag.TearStage.HOLES)

	# Shape-cast урон: пакет «в стене»
	var desired := Vector3(-2.45, bag.global_position.y, 0.0)
	var hp_before: float = bag.hp
	for i in range(20):
		bag._carry_shape_cast_damage(0.05, desired)
		await process_frame
	print("WALL_RUB hp_before=", hp_before, " hp=", bag.hp)

	bag._apply_damage(bag.hp + 5.0)
	assert(bag.bursted)
	assert(bag._pieces_spawned)
	assert(bag._rag_left.visible and bag._rag_right.visible)
	assert(not bag._body_mi.visible)
	var pieces := 0
	for c in b.get_children():
		if c is RigidBody3D and c != bag and int(c.collision_layer) == 8:
			pieces += 1
	print("BURST_OK pieces=", pieces)
	assert(pieces >= 12)

	print("TEST_BAG_FEEL_PASS")
	quit(0)
