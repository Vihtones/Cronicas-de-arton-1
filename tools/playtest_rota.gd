extends SceneTree
## Playtest da segunda rota: esvazia o remédio da vila, passa seis dias e confere se o mensageiro de Sambúrdia entrega.
## Depois fecha a rota e confere que ela deixa de entregar. Captura telas.
## Uso: xvfb-run godot --path . -s res://tools/playtest_rota.gd -- <pasta_saida>

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


## avança um dia de jogo e devolve as entregas de carga que aconteceram nele
func _dia(G) -> Array:
	var entregas: Array = []
	for i in 6:
		var r = G.send("AdvanceTime", {"ticks": 24})
		for f in r.emitted_events:
			if f.event_type == "TRADE_DELIVERED":
				entregas.append(f.payload)
	return entregas


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
	# só a rota de Sambúrdia fica aberta para remédio: Valkaria fica fechada nesta fase
	eco.routes.valkaria_vila.open = false
	eco.regions.vila.stock.remedio = 0
	await _shot("r1_vila_sem_remedio")

	var entregas: Array = []
	for d in 6:
		entregas.append_array(_dia(G))
	var de_tarso := entregas.filter(func(p): return p.get("by", "") == "tarso")
	var carga := 0
	for p in de_tarso:
		for g in p.goods:
			carga += int(p.goods[g])
	_confere("o mensageiro de Sambúrdia entrega em seis dias", de_tarso.size() >= 1)
	_confere("a carga de Sambúrdia tem mercadoria (%d unidades)" % carga, carga > 0)
	await _frames(5)
	await _shot("r2_entrega_samburdia")

	# estrada bloqueada: a rota fecha e o mensageiro chega sem carga
	eco.routes.samburdia_vila.open = false
	eco.regions.vila.stock.remedio = 0
	var entregas2: Array = []
	for d in 6:
		entregas2.append_array(_dia(G))
	var de_tarso2 := entregas2.filter(func(p): return p.get("by", "") == "tarso")
	_confere("com a estrada fechada, Tarso não entrega", de_tarso2.is_empty())
	_confere("a rota de Sambúrdia está fechada", eco.routes.samburdia_vila.open == false)
	print("FIM falhas=%d" % falhas)
	quit(falhas)
