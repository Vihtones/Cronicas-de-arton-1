extends SceneTree
## Capturas dos protótipos do laboratório. Uso:
## xvfb-run godot --path . -s res://tools/lab_runner.gd -- <pasta>

var out_dir := "user://lab"
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n: await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw   # captura só com o quadro completo (sob carga pegava quadros pela metade)
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _sync() -> void:
	main.player.sync_from_world(); main.npc_layer.sync_all(); main.camera.reset_smoothing()


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(8)
	main.ui.open_lab()
	await _shot("10_laboratorio")
	main.ui.panel_lab.visible = false
	main.ui.open_creation()
	main.ui._creation.race = "anao"; main.ui._creation["class"] = "arcanista"; main.ui._refresh_creation()
	await _shot("11_criacao")
	main.ui.panel_creation.visible = false
	# magia
	var info: Dictionary = G.start_prototype("magia")
	main.ui.log_msg(info.intro)
	G.world.player.position = G.db.tile_to_world(Vector2i(21, 56)); _sync()
	G.send("MovePlayer", {"to": G.world.player.position})
	await _frames(120)
	var cv = main.combat_view
	if G.world.modules.combat.active:
		var sim = G.world.modules.combat.sim
		for i in 40:
			if sim.current_id() == "player" and not cv.playing: break
			await _frames(10)
		var tgt := ""
		for id in sim.combatants:
			if id != "player" and sim.conscious(id): tgt = id
		cv.mode = "magia"
		cv.hover = sim.c(tgt).tile
		cv._update_preview()
		await _shot("12_magia_fantasma")
		cv.add_hover_to_plan(); cv.confirm()
		await _frames(80)
		await _shot("13_magia_execucao")
	# viagem / Valkaria
	G.start_prototype("viagem"); _sync()
	main.ui.show_interact(main.build_actions())
	await _shot("14_viagem_menu")
	G.send("Travel", {"route": "vila->valkaria"})
	await _frames(10)
	main.ui.refresh_hub()
	await _shot("15_valkaria")
	# domínio
	G.start_prototype("dominio"); _sync()
	for i in 2: G.send("AdvanceTime", {"ticks": 7 * 144})
	main.ui.toggle_journal()
	await _shot("16_dominio_diario")
	main.ui.toggle_journal()
	# herdeiro
	G.start_prototype("herdeiro")
	await _frames(5)
	await _shot("17_herdeiro")
	# fauna + debug
	G.start_prototype("fauna"); _sync()
	for d in 5:
		G.send("AdvanceTime", {"ticks": 144})
		if G.world.modules.state.has_flag("ovelha_morta"): break
	G.world.clock.tick = (G.world.clock.tick / 144) * 144 + 6 * 11
	G.world.player.position = G.db.tile_to_world(Vector2i(58, 27)); _sync()
	main.ui.toggle_debug()
	await _frames(10)
	await _shot("18_fauna_debug")
	quit()
