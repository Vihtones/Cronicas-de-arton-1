extends SceneTree
## Playtest do prólogo: criação -> questionário -> começo -> vila. Confere a posição do jogador e tira capturas.
## Uso: xvfb-run godot --path . -s res://tools/playtest_prologo.gd -- <pasta_saida>

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


## Aperta um botão pelo texto, como o jogador faria (dentro do painel dado).
func _aperta(painel: Node, texto: String) -> bool:
	for b in painel.find_children("*", "Button", true, false):
		if b.text.ends_with(texto):
			b.pressed.emit()
			return true
	return false


func _confere(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok:
		falhas += 1


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(10)
	# 1. criação do personagem com o botão de destino
	main.ui._creation["class"] = "arcanista"; main.ui._creation.path = "mago"
	main.ui._creation.class_picks = ["conhecimento", "intuicao"]; main.ui._creation.free_picks = ["percepcao"]
	main.ui.open_creation()
	await _frames(5)
	await _shot("p1_criacao")
	# 2. "Começar" na criação inicia o personagem e abre o questionário do passado
	main.ui.open_creation()
	await _frames(3)
	_confere("botão 'Começar' da criação existe", _aperta(main.ui.panel_creation, "Começar"))
	await _frames(5)
	_confere("criação fecha e abre o questionário", not main.ui.panel_creation.visible and main.ui.panel_prologo.visible)
	await _frames(5)
	await _shot("p2_questionario")
	_confere("questionário aberto", main.ui.panel_prologo.visible)
	# 3. escolhe um passado: ferreiro que começa no trabalho
	main.ui._prologo = {"ocupacao": "ferreiro", "comeco": "no_trabalho"}
	main.ui._refresh_prologo()
	await _frames(3)
	await _shot("p3_escolhido")
	var start: Dictionary = Prologue.from_answers(main.ui._prologo.duplicate())
	_confere("botão 'Começar com este passado' existe", _aperta(main.ui.panel_prologo, "Começar com este passado"))
	await _frames(5)
	_confere("painel fecha ao começar", not main.ui.panel_prologo.visible)
	var spot: Vector2i = G.db.location_spot(str(start.start_location))
	_confere("jogador nasce em %s (%s)" % [start.start_location, spot], G.db.world_to_tile(G.world.player.position) == spot)
	await _shot("p4_vila_inicio")
	# 4. "Deixar o Destino Decidir": nova partida, semente sorteada, começo válido
	G.new_game_with_build({"race": "humano", "class": "guerreiro", "attrs": {}, "human_picks": ["for", "des", "con"],
		"class_picks": [], "free_picks": [], "path": "", "name": "Aventureiro"}, false)
	main.ui.open_prologo()
	await _frames(3)
	_confere("botão 'Deixar o Destino Decidir' existe", _aperta(main.ui.panel_prologo, "Deixar o Destino Decidir"))
	await _frames(5)
	_confere("destino decidido fecha o painel", not main.ui.panel_prologo.visible)
	_confere("destino decidido deixa o jogador num lugar válido", G.world.modules.prologue.started)
	await _frames(5)
	await _shot("p5_destino")
	print("FIM falhas=%d" % falhas)
	quit(1 if falhas > 0 else 0)
