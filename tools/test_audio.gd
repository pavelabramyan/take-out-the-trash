extends SceneTree
## Дым-тест звука: все стримы на месте, шины созданы, вызовы не падают.

func _init() -> void:
	var audio_scr := load("res://scripts/audio.gd")
	var a: Node = audio_scr.new()
	root.add_child(a)
	await process_frame
	var need := ["burst", "pickup", "dump", "impact", "slip", "bark", "babushka",
		"mom", "mom2", "mom3", "elevator", "win", "fail", "step", "step2", "step3",
		"step4", "rustle", "bag_grab", "bag_drop", "wall_rub", "music", "game_music",
		"danger_music", "ambient"]
	var streams: Dictionary = a.get("_streams")
	var missing: Array = []
	for k in need:
		if not streams.has(k):
			missing.append(k)
	var buses := [AudioServer.get_bus_index("SFX"), AudioServer.get_bus_index("Music")]
	var sr_bad: Array = []
	for k in streams.keys():
		var s = streams[k]
		if s is AudioStreamWAV and s.mix_rate < 44100:
			sr_bad.append("%s=%d" % [k, s.mix_rate])
	for surf in ["concrete", "asphalt", "ice"]:
		a.call("play_step", surf)
	a.call("set_indoor", true)
	a.call("set_indoor", false)
	a.call("yell_mom")
	a.call("play_sfx", "dump", 1.0, -2.0)
	await process_frame
	var loops: Array = []
	for k in ["rustle", "ambient", "game_music"]:
		if streams.has(k) and streams[k] is AudioStreamWAV:
			if streams[k].loop_mode == AudioStreamWAV.LOOP_DISABLED:
				loops.append(k)
	if missing.is_empty() and buses[0] != -1 and buses[1] != -1 and sr_bad.is_empty() and loops.is_empty():
		print("TEST_AUDIO_PASS streams=%d" % streams.size())
	else:
		print("TEST_AUDIO_FAIL missing=%s buses=%s low_rate=%s no_loop=%s" % [missing, buses, sr_bad, loops])
	quit()
