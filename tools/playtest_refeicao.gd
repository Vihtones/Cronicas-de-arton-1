extends SceneTree
## Playtest da Fase 4: na falta de comida, a refeição da taverna custa o dobro e muda o que os moradores fazem.
## Força a falta pelo menu de debug, confere o preço na tela e acompanha dois moradores: um sem ouro para o
## novo preço (fica com fome) e outro com ouro (vai à taverna e paga o dobro).
## Uso: xvfb-run godot --path . -s res://tools/playtest_refeicao.gd -- <pasta_saida>

const POBRE := "joran"
const RICO := "garrick"

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


func _menu() -> void:
	main.debug_menu.toggle()
	await _frames(5)


func _morador(G: Node, id: String) -> String:
	var nd = G.world.modules.npc_needs
	return "%s: ouro %d, fome %.2f, objetivo '%s', local %s" % [id, nd.gold(id), nd.hunger(id),
		str(nd.state[id].goal), str(G.world.modules.npcs.npc(id).location)]


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(10)
	G.new_game(false, 7)
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(3)
	var nd = G.world.modules.npc_needs
	var eco = G.world.modules.economy
	# 1. sem falta: preço normal, visível no menu de debug
	_confere("sem falta, a refeição custa %d" % NpcNeedsModule.MEAL_COST, nd.meal_cost() == NpcNeedsModule.MEAL_COST)
	await _menu()
	_confere("o menu mostra o preço normal", main.debug_menu._estado().contains("refeição %d ouro" % NpcNeedsModule.MEAL_COST))
	await _shot("r1_sem_falta")
	# 2. força a falta: comida da vila zerada pelo debug, e passa a meia-noite (a economia fecha o dia)
	var r = G.send("DebugSet", {"key": "stock", "good": "comida", "value": 0})
	_confere("estoque de comida zerado pelo debug", r.accepted)
	r = G.send("DebugSet", {"key": "hour", "value": 23})
	r = G.send("AdvanceTime", {"ticks": 6})
	_confere("a vila entra em falta de comida", bool(eco.shortage.get("comida", false)))
	var dobro: int = NpcNeedsModule.MEAL_COST * NpcNeedsModule.SHORTAGE_MEAL_MULT
	_confere("na falta, a refeição custa %d" % dobro, nd.meal_cost() == dobro)
	# 3. dois moradores com fome às 11h: um com 3 de ouro (paga o normal, não o dobro), outro com 20
	G.send("DebugSet", {"key": "hour", "value": 11})
	G.send("DebugSet", {"key": "npc_gold", "npc": POBRE, "value": NpcNeedsModule.MEAL_COST + 1})
	G.send("DebugSet", {"key": "npc_hunger", "npc": POBRE, "value": 0.9})
	G.send("DebugSet", {"key": "npc_gold", "npc": RICO, "value": 20})
	G.send("DebugSet", {"key": "npc_hunger", "npc": RICO, "value": 0.9})
	G.world_reloaded.emit()
	main.debug_menu.rebuild()
	await _frames(5)
	_confere("o menu mostra o preço dobrado e a falta",
		main.debug_menu._estado().contains("refeição %d ouro (falta de comida)" % dobro))
	await _shot("r2_falta_menu")
	# 4. passam três horas: o pobre não vai à taverna e segue com fome; o rico vai e paga o dobro
	var fome_pobre: float = nd.hunger(POBRE)
	var comeu_rico := false
	var preco_pago := -1
	for h in 3:
		r = G.send("AdvanceTime", {"ticks": 6})
		for e in r.emitted_events:
			if e.event_type == "MEAL_SERVED" and str(e.payload.npc) == RICO:
				comeu_rico = true
				preco_pago = int(e.payload.cost)
		print("  ", _morador(G, POBRE))
		print("  ", _morador(G, RICO))
	_confere("o morador sem ouro para o dobro não vai à taverna", str(G.world.modules.npcs.npc(POBRE).location) != "taverna")
	_confere("o ouro dele não muda (não pagou refeição)", nd.gold(POBRE) == NpcNeedsModule.MEAL_COST + 1)
	_confere("a fome dele continua subindo", nd.hunger(POBRE) > fome_pobre)
	_confere("o morador com ouro come na taverna", comeu_rico)
	_confere("e paga o preço dobrado (%d)" % dobro, preco_pago == dobro)
	_confere("o ouro dele cai %d" % dobro, nd.gold(RICO) == 20 - dobro)
	# 5. na tela: vai à taverna e mostra quem está lá
	main.debug_menu.toggle()
	G.send("DebugTeleport", {"location": "taverna"})
	G.world_reloaded.emit()
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(10)
	await _shot("r3_taverna")
	await _menu()
	await _shot("r4_taverna_menu")
	print("FIM falhas=%d" % falhas)
	quit(1 if falhas > 0 else 0)
