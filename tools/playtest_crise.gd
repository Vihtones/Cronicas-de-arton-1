extends SceneTree
## Playtest da crise de escassez: começa um jogo, esvazia a comida da vila, passa um dia, abre o diário e captura.
## Uso: xvfb-run godot --path . -s res://tools/playtest_crise.gd -- <pasta_saida>

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
	await _shot("c1_antes")
	# a comida da vila acaba (ex.: uma seca); passa-se um dia no jogo
	G.world.modules.economy.regions.vila.stock.comida = 10
	var r = G.send("AdvanceTime", {"ticks": 144})
	_confere("o dia passa", r.accepted)
	await _frames(5)
	var achou := false
	for e in G.world.modules.chronicle.entries:
		if str(e.text).contains("Está faltando comida"):
			achou = true
	_confere("o diário registra a falta de comida", achou)
	main.ui.toggle_journal()
	await _frames(5)
	await _shot("c2_diario")
	for sc in main.ui.panel_journal.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 100000
	await _shot("c3_diario_fim")
	print("FIM falhas=%d" % falhas)
	quit(1 if falhas > 0 else 0)
