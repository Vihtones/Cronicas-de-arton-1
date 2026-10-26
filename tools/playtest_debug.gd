extends SceneTree
## Playtest do menu de debug (F2): abre o menu, teleporta, ajusta hora, ouro, estoque e morador, e confere o mundo.
## Uso: xvfb-run godot --path . -s res://tools/playtest_debug.gd -- <pasta_saida>

var out_dir := "user://shots"
var main: Node
var falhas := 0


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


func _espera_vila() -> void:
	for i in 600:
		var carregando: bool = main.ui._loading != null and main.ui._loading.visible
		if main._bakes_left <= 0 and not carregando:
			break
		await process_frame
	await _frames(5)


func _shot(name: String) -> void:
	await _espera_vila()
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _confere(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok:
		falhas += 1


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(10)
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 10
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(3)
	# 1. abre o menu com a tecla F2 (entrada real)
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F2
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await _frames(5)
	_confere("F2 abre o menu de debug", main.debug_menu.visible)
	await _shot("d1_menu")
	# 2. teleporte: vai à Torre Partida (local da história)
	var locs: Array = G.db.all_locations()
	var alvo := ""
	for l in locs:
		if str(l.get("name", "")).contains("Torre"):
			alvo = str(l.id)
	_confere("há um local 'Torre' no mapa", alvo != "")
	var r = G.send("DebugTeleport", {"location": alvo})
	_confere("teleporte aceito", r.accepted)
	_confere("jogador está no local", G.db.world_to_tile(G.world.player.position) == G.db.location_spot(alvo))
	# 3. hora: 22h
	r = G.send("DebugSet", {"key": "hour", "value": 22})
	_confere("hora ajustada para 22h", G.world.hour() == 22)
	# 4. estoque: comida baixa dispara a crise
	r = G.send("DebugSet", {"key": "stock", "good": "comida", "value": 5})
	_confere("estoque de comida ajustado", int(G.world.modules.economy.regions.vila.stock.comida) == 5)
	# 5. morador: Garrick com ouro e fome
	r = G.send("DebugSet", {"key": "npc_gold", "npc": "garrick", "value": 77})
	_confere("ouro do morador ajustado", G.world.modules.npc_needs.gold("garrick") == 77)
	r = G.send("DebugSet", {"key": "npc_hunger", "npc": "garrick", "value": 0.95})
	_confere("fome do morador ajustada", absf(float(G.world.modules.npc_needs.state.garrick.hunger) - 0.95) < 0.01)
	# 6. validação: valor inválido é recusado
	r = G.send("DebugSet", {"key": "hour", "value": 99})
	_confere("hora inválida é recusada pelo domínio", not r.accepted)
	r = G.send("DebugSet", {"key": "variavel_inexistente", "value": 1})
	_confere("variável desconhecida é recusada", not r.accepted)
	# 7. teleporte até morador
	r = G.send("DebugTeleport", {"npc": "garrick"})
	_confere("teleporte até o morador aceito", r.accepted)
	main.player.sync_from_world()
	await _frames(5)
	await _shot("d2_depois")
	print("FIM falhas=%d" % falhas)
	quit(1 if falhas > 0 else 0)
