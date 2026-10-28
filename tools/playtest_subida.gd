extends SceneTree
## Playtest da subida de nível: dá XP pelo debug, confere o painel de escolha, escolhe um poder com o clique e
## mostra a árvore com o que falta nos bloqueados. Captura telas.
## Uso: xvfb-run godot --path . -s res://tools/playtest_subida.gd -- <pasta_saida>

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
	var s = G.world.player_sheet
	var r = G.send("DebugSet", {"key": "xp", "value": 1000})
	_confere("XP de debug aceito", r.accepted)
	await _frames(5)
	_confere("o nível sobe para 2", s.level == 2)
	_confere("o painel de escolha abre", main.ui.panel_subida.visible)
	var botoes: Array = []
	for b in main.ui.panel_subida.find_children("*", "Button", true, false):
		if not str(b.text).begins_with("Escolher depois") and not str(b.text).begins_with("FOR") and not str(b.text).begins_with("DES") and not str(b.text).begins_with("CON") and not str(b.text).begins_with("INT") and not str(b.text).begins_with("SAB") and not str(b.text).begins_with("CAR"):
			botoes.append(b)
	_confere("há opções de poder com efeito descrito", botoes.size() >= 1 and str(botoes[0].text).contains("—"))
	await _shot("s1_subida")
	var pendente_antes: int = s.pending_powers
	if botoes.size() > 0:
		botoes[0].pressed.emit()
	await _frames(5)
	_confere("escolher um poder consome o pendente", s.pending_powers == pendente_antes - 1)
	main.ui.toggle_tree()
	await _frames(5)
	main.ui.panel_tree.refresh()
	await _frames(3)
	main.ui.panel_tree.filtro = "todos"
	main.ui.panel_tree.refresh()
	await _frames(3)
	await _shot("s2_arvore")
	print("FIM falhas=%d" % falhas)
	quit(falhas)
