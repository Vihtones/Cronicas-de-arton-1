extends SceneTree
## Benchmark da cena típica (§15): anda pela vila em cada perfil gráfico e mede
## p50/p95 de frame, tempo de comando, save e load. Uso:
## godot --path . -s res://tools/benchmark.gd -- [frames_por_perfil]

var main: Node
var frames := 400


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		frames = int(args[0])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _pct(a: Array, p: float) -> float:
	var s := a.duplicate(); s.sort()
	return s[clampi(int(round((s.size() - 1) * p)), 0, s.size() - 1)] if not s.is_empty() else 0.0


func _run() -> void:
	var G = root.get_node("Game")
	for i in 5: await process_frame
	G.new_game(false, 99)
	G.settings.seconds_per_tick = 0.1  # acelera o relógio para estressar agendas/rumores
	var route := [Vector2i(23, 27), Vector2i(12, 26), Vector2i(12, 18), Vector2i(30, 18), Vector2i(40, 27), Vector2i(23, 35)]
	var report := {}
	for prof in ["baixo", "medio", "alto"]:
		G.settings.graphics = prof
		main.fx.apply_profile()
		G.world.modules.weather.region.condition = "chuva"
		var times: Array = []
		var idx := 0
		var pos: Vector2 = G.db.tile_to_world(route[0])
		for f in frames:
			var t0 := Time.get_ticks_usec()
			var goal: Vector2 = G.db.tile_to_world(route[idx])
			pos = pos.move_toward(goal, 3.0)
			if pos.distance_to(goal) < 1.0: idx = (idx + 1) % route.size()
			main.player.global_position = pos
			await process_frame
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
		var vis := 0
		for v in main.npc_layer.npc_views.values():
			if v.visible: vis += 1
		report[prof] = {"frame_p50_ms": _pct(times, 0.5), "frame_p95_ms": _pct(times, 0.95), "npcs_L0": vis}
	var t0 := Time.get_ticks_usec()
	G.save_game("bench")
	var save_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	G.load_game("bench")
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	report["save_ms"] = save_ms
	report["load_ms"] = load_ms
	report["telemetria"] = G.telemetry.report()
	report["renderer"] = RenderingServer.get_video_adapter_name()
	report["tick"] = G.world.clock.tick
	print("BENCHMARK ", JSON.stringify(report))
	var f := FileAccess.open("user://benchmark.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	quit()
