extends SceneTree
## Замер кадра в ключевых точках уровня: подъезд, лестница, двор.

const BuildingBuilderScr = preload("res://scripts/building_builder.gd")
const WARMUP := 60
const SAMPLE := 150

func _initialize() -> void:
	call_deferred("_run")

func _measure(label: String) -> void:
	for _i in range(WARMUP):
		await process_frame
	var t0 := Time.get_ticks_usec()
	for _i in range(SAMPLE):
		await process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(SAMPLE)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("PERF %s ms=%.2f fps=%.1f objects=%d prims=%d draws=%d" % [label, ms, 1000.0 / maxf(ms, 0.001), objs, prims, draws])

func _place(p: CharacterBody3D, pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	p.global_transform = Transform3D(Basis.IDENTITY, pos)
	p.velocity = Vector3.ZERO
	if p.has_method("set_look_yaw"):
		p.set_look_yaw(deg_to_rad(yaw_deg))
	else:
		p.rotation.y = deg_to_rad(yaw_deg)
	p.set("_pitch", deg_to_rad(pitch_deg))
	if p.camera:
		p.camera.rotation.x = deg_to_rad(pitch_deg)
		p.camera.current = true
	for _i in range(4):
		await process_frame

func _run() -> void:
	var err := change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("scene fail %s" % err)
		quit(1)
		return
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
	var ui = game.get_node_or_null("UI")
	if ui:
		ui.visible = false
	var H: float = BuildingBuilderScr.FLOOR_H
	var sx: float = BuildingBuilderScr.STAIR_X

	# Без vsync — иначе замер упирается в 60 и не показывает запас
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("RENDER method=", RenderingServer.get_current_rendering_method(), " driver=", RenderingServer.get_video_adapter_name())
	await _place(p, Vector3(-0.85, H * 2.0 + 0.05, -0.55), 180.0, -8.0)
	await _measure("landing_top")
	await _place(p, Vector3(sx, H + 1.35, 1.35), 10.0, -25.0)
	await _measure("stairs")
	await _place(p, Vector3(0.0, 0.05, 6.0), 180.0, -6.0)
	await _measure("yard_wide")
	await _place(p, Vector3(3.7, 0.05, 11.1), 180.0, -10.0)
	await _measure("yard_dumpster")
	print("PERF_DONE")
	quit(0)
