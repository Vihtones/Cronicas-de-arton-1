extends SceneTree
## Playtest da Fase 5: dá ouro à vila, aperta o botão "Construir" no diário de verdade e confere o efeito.
## Uso: xvfb-run godot --path . -s res://tools/playtest_cidade.gd -- <pasta_saida>

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


func _botao(prefixo: String) -> Button:
	for b in main.ui.panel_journal.find_children("*", "Button", true, false):
		if str(b.text).begins_with(prefixo):
			return b
	return null


func _rola_ate(prefixo: String) -> void:
	for sc in main.ui.panel_journal.find_children("*", "ScrollContainer", true, false):
		var b := _botao(prefixo)
		if b != null:
			sc.ensure_control_visible(b)
	await _frames(3)


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(10)
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 10
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(3)
	var eco = G.world.modules.economy
	eco._ensure()
	eco.treasury = 0
	main.ui.toggle_journal()
	await _frames(5)
	var sem := _botao("Construir por T$ 120")
	_confere("sem ouro, o botão do celeiro aparece desabilitado", sem != null and sem.disabled)
	eco.treasury = 400
	main.ui.refresh_journal()
	await _frames(3)
	var producao_antes := int(eco.regions.vila.production.comida)
	await _rola_ate("Construir por T$ 120")
	var botao := _botao("Construir por T$ 120")
	_confere("com ouro, o botão do celeiro fica ativo", botao != null and not botao.disabled)
	await _shot("c1_cidade_antes")
	botao.pressed.emit()
	await _frames(5)
	_confere("o celeiro foi construído", int(G.world.modules.cities.built.get("celeiro", 0)) == 1)
	_confere("o tesouro pagou T$ 120", int(eco.treasury) == 280)
	_confere("a produção de comida subiu 6", int(eco.regions.vila.production.comida) == producao_antes + 6)
	await _rola_ate("Construir por T$ 100")
	await _shot("c2_cidade_depois")
	main.ui.toggle_journal()
	await _frames(3)
	print("FIM falhas=%d" % falhas)
	quit(falhas)
