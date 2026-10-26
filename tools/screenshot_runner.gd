extends SceneTree
## Roteiro automático de capturas (verificação visual). Uso:
## xvfb-run godot --path . -s res://tools/screenshot_runner.gd -- <pasta_saida>

var out_dir := "user://shots"
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw   # captura só com o quadro completo (sob carga pegava quadros pela metade)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


## Espera a vila terminar de montar (a tela "Preparando a vila" some quando os desenhos ficam prontos).
func _espera_vila() -> void:
	for i in 600:
		var carregando: bool = main.ui._loading != null and main.ui._loading.visible
		if main._bakes_left <= 0 and not carregando:
			break
		await process_frame
	await _frames(5)


func _game() -> Node:
	return root.get_node("Game")


func _run() -> void:
	var G = _game()
	await _frames(10)
	await _shot("01_titulo")
	main.ui.panel_credits.visible = true
	await _shot("01b_creditos")
	main.ui.panel_credits.visible = false
	main.ui._creation["class"] = "arcanista"; main.ui._creation.path = "mago"
	main.ui._creation.class_picks = ["conhecimento", "intuicao"]; main.ui._creation.free_picks = ["percepcao"]
	main.ui.open_creation()
	await _frames(5)
	await _shot("01c_criacao_arcanista")
	main.ui.panel_creation.visible = false
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 10  # 10h
	G.world.player.position = G.db.tile_to_world(Vector2i(38, 15))
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	main.camera.reset_smoothing()
	G.send("AdvanceTime", {"ticks": 1})
	await _espera_vila()
	await _shot("02_vila_dia")
	# diálogo com Hilda
	var t: Vector2i = G.world.modules.npcs.npc_tile("hilda")
	G.world.player.position = G.db.tile_to_world(t + Vector2i(1, 0))
	main.player.sync_from_world(); main.camera.reset_smoothing()
	G.send("StartDialogue", {"npc_id": "hilda"})
	await _frames(10)
	await _shot("03_dialogo_hilda")
	G.send("ChooseOption", {"index": 0})
	G.send("ChooseOption", {"index": 0})
	G.send("EndDialogue")
	# examinar o baú
	G.world.player.position = G.db.tile_to_world(Vector2i(38, 12))
	main.player.sync_from_world()
	var acts: Array = main.build_actions()
	main.ui.show_interact(acts)
	await _frames(5)
	await _shot("04_menu_interacao")
	for i in acts.size():
		if acts[i].cmd == "InspectTarget":
			main.ui._do_interact(i)
			break
	G.world.modules.exploration.known_facts["f_tomas_levado"] = {"tick": 0}
	G.world.modules.exploration.notes.append({"tick": 0, "text": G.db.mystery.facts["f_tomas_levado"], "fact": "f_tomas_levado"})
	main.ui.toggle_journal()
	await _frames(5)
	await _shot("05_diario")
	main.ui.toggle_journal()
	# noite com chuva na praça
	G.world.clock.tick = 6 * 21
	G.world.modules.weather.region.condition = "chuva"
	G.world.player.position = G.db.tile_to_world(Vector2i(23, 27))
	main.player.sync_from_world(); main.camera.reset_smoothing()
	G.send("AdvanceTime", {"ticks": 1})
	G.world.modules.weather.region.condition = "chuva"
	main.npc_layer.sync_all()
	await _frames(40)
	await _shot("06_noite_chuva")
	# floresta com a vegetação aprovada (governador de arte): estrada, trilha e entardecer
	G.world.modules.weather.region.condition = "limpo"
	for spec in [[Vector2i(62, 26), 6 * 10 + 144, "06b_floresta_estrada"], [Vector2i(74, 17), 6 * 15 + 144, "06c_floresta_trilha"],
			[Vector2i(66, 31), 6 * 18 + 144, "06d_floresta_entardecer"]]:
		G.world.clock.tick = spec[1]
		G.world.player.position = G.db.tile_to_world(spec[0])
		main.player.sync_from_world(); main.camera.reset_smoothing()
		G.send("AdvanceTime", {"ticks": 1})
		G.world.modules.weather.region.condition = "limpo"
		main.npc_layer.sync_all()
		await _frames(30)
		await _shot(spec[2])
	# cripta e combate
	G.world.clock.tick = 6 * 14 + 144
	G.world.modules.weather.region.condition = "limpo"
	G.world.player.position = G.db.tile_to_world(Vector2i(8, 55))
	main.player.sync_from_world(); main.npc_layer.sync_all(); main.camera.reset_smoothing()
	await _frames(10)
	await _shot("07_cripta")
	G.world.player.position = G.db.tile_to_world(Vector2i(21, 56))
	main.player.sync_from_world()
	G.send("MovePlayer", {"to": G.world.player.position})
	await _frames(90)
	var cv = main.combat_view
	if G.world.modules.combat.active:
		var sim = G.world.modules.combat.sim
		for i in 30:
			if sim.current_id() == "player" and not cv.playing: break
			await _frames(10)
		var target := ""
		for id in sim.combatants:
			if id != "player" and sim.conscious(id): target = id
		cv.hover = sim.c(target).tile
		cv._update_preview()
		await _frames(5)
		await _shot("08_combate_fantasma")
		cv.add_hover_to_plan()
		cv.confirm()
		await _frames(60)
		await _shot("09_combate_execucao")
	main.ui.show_xp_summary({"amount": 390, "total": 390, "next": 1000, "level": 1, "outcome": "vitoria", "base": 250, "mult": 1.55,
		"breakdown": [["desvantagem numérica (3 inimigos)", 0.2], ["táticas: flanco, magia", 0.1], ["vitória rápida (3 rodadas)", 0.1], ["quase sem ferimentos", 0.15]]})
	await _frames(5)
	await _shot("10_resumo_xp")
	print("telemetria ", JSON.stringify(G.telemetry.report()))
	quit()
