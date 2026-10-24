extends SceneTree
## Capturas do mundo vivo: casas com telhado, caminhos, figurantes, feira, festa, chuva chegando,
## telhado abrindo ao entrar, HUD e árvore de poderes.
## Uso: xvfb-run godot --path . -s res://tools/life_runner.gd -- <pasta_saida>

var out_dir := "user://life"
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
	await _frames(2)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _goto(G, tile: Vector2i, day: int, hour: int, weather := "limpo") -> void:
	var target := (day * 24 + hour) * 6
	if target > G.world.clock.tick:
		G.send("AdvanceTime", {"ticks": target - G.world.clock.tick})
	G.world.modules.weather.region.condition = weather
	G.world.modules.weather.region.intensity = 1.0 if weather in ["chuva", "tempestade", "neblina"] else 0.0
	G.world.player.position = G.db.tile_to_world(tile)
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	main.npc_layer.sync_all()
	for a in main.life.agents.duplicate():
		(a.view as Node).queue_free()
	main.life.agents.clear()
	main.life.prefill()


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(5)
	G.new_game(false, 7)
	G.world.modules.weather.enabled = true
	await _frames(10)
	# 1) manhã comum na praça: telhados, fachadas, trilhas, gente na rua
	_goto(G, Vector2i(22, 27), 0, 9)
	await _frames(90)
	await _shot("v01_praca_manha")
	# 2) casas ao norte (taverna, templo com torre) e o moinho
	_goto(G, Vector2i(20, 18), 0, 10)
	await _frames(60)
	await _shot("v02_taverna_templo")
	_goto(G, Vector2i(36, 28), 0, 11)
	await _frames(60)
	await _shot("v03_moinho_casas")
	# 3) dentro da taverna: o telhado se abre
	_goto(G, Vector2i(11, 14), 0, 12)
	await _frames(60)
	await _shot("v04_dentro_taverna")
	# 4) dia de feira
	_goto(G, Vector2i(18, 24), 1, 10)
	await _frames(90)
	await _shot("v05_feira")
	# 5) festa à noite
	_goto(G, Vector2i(22, 27), 4, 20)
	await _frames(120)
	await _shot("v06_festa_noite")
	# 6) chuva: todos correm para casa, poças
	_goto(G, Vector2i(22, 26), 5, 14, "chuva")
	G.world.modules.weather.region.surface = "lamacento"
	await _frames(70)
	await _shot("v07_chuva_correria")
	# 7) estrada com carroça
	_goto(G, Vector2i(30, 25), 6, 9)
	main.life._cart_t = 0.0
	await _frames(240)
	await _shot("v08_estrada_carroca")
	# 8) árvore de poderes
	G.world.player_sheet.attrs["for"] = 2
	G.world.player_sheet.powers["ataque_poderoso"] = true
	G.world.player_sheet.pending_powers = 1
	if main.ui.has_method("toggle_tree"):
		main.ui.toggle_tree()
		await _frames(20)
		await _shot("v09_arvore_poderes")
		main.ui.toggle_tree()
	quit()
