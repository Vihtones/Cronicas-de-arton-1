extends SceneTree
## Playtest das telas novas: inventário (I), loja (comprar/vender) e roda de magias (Tab).
## Uso: xvfb-run godot --path . -s res://tools/playtest_interface.gd -- <pasta_saida>

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


func _shot(name: String) -> void:
	for i in 600:
		if main._bakes_left <= 0 and not (main.ui._loading != null and main.ui._loading.visible):
			break
		await process_frame
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _confere(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok:
		falhas += 1


func panel_off() -> void:
	main.ui.close_panels()


func _tecla(k: int) -> void:
	var t := InputEventKey.new()
	t.keycode = k
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(4)


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(10)
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 10
	main.player.sync_from_world()
	await _frames(3)
	G.world.modules.state.inventory["espada_curta"] = 1
	G.world.modules.state.inventory["cota_malha"] = 1
	G.world.modules.state.inventory["pocao_cura"] = 2
	await _tecla(KEY_I)
	_confere("I abre o inventário", main.ui.panel_inv.visible)
	main.ui.panel_inv._sel = "cota_malha"
	main.ui.panel_inv.refresh()
	await _shot("i1_inventario")
	await _tecla(KEY_ESCAPE)
	main.ui.open_shop("garrick")
	main.ui.panel_shop._sel = "espada_longa"
	main.ui.panel_shop.refresh()
	await _shot("i2_loja")
	main.ui.close_panels()
	G.world.player_sheet.spells = PackedStringArray(["curar_ferimentos", "luz", "aviso", "bencao", "escuridao", "orientacao"])
	await _tecla(KEY_TAB)
	_confere("Tab abre a roda", main.ui.spell_wheel.visible)
	main.ui.spell_wheel.hover = 1
	main.ui.spell_wheel.queue_redraw()
	await _shot("i3_roda")
	main.ui.spell_wheel.visible = false
	main.ui._on_spell_picked("aviso")
	_confere("fora de combate, escolher abre como lançar", main.ui.panel_cast.visible)
	await _shot("i4_lancar")
	panel_off()
	# modo ação: mirar e bater numa criatura
	var c = G.world.modules.combat
	var alvo := ""
	for id in c.creature_state:
		if c.is_active_creature(id) and c._group_with([id]).size() <= 3:
			alvo = id
			break
	_confere("há uma criatura para lutar", alvo != "")
	G.world.player.position = G.db.tile_to_world(c.creature_tile(alvo) + Vector2i(2, 0))
	main.player.sync_from_world()
	await _frames(3)
	_confere("clique na criatura começa a luta", main._atacar_mirando(c.creature_tile(alvo)) and c.active)
	for i in 400:
		if main.combat_view.my_turn():
			break
		await process_frame
	_confere("modo ação ligado", main.combat_view.acao)
	await _shot("i5_mira")
	var antes := int(c.sim.c(alvo).sheet.pv) if c.sim.combatants.has(alvo) else -1
	main.combat_view.acao_clique(c.sim.c(alvo).tile)
	for i in 900:
		if main.combat_view.my_turn() and not main.combat_view.playing:
			break
		await process_frame
	_confere("o turno passou e voltou ao jogador (ou a luta acabou)", main.combat_view.my_turn() or not c.active)
	print("pv do alvo: ", antes, " -> ", (c.sim.c(alvo).sheet.pv if c.active and c.sim.combatants.has(alvo) else "fim"))
	await _shot("i6_depois")
	# guilda: inscreve, aceita uma caça e vê o quadro
	G.new_game(false, 8)
	await _frames(10)
	G.world.player.position = G.db.tile_to_world(G.db.location_spot("taverna"))
	G.world.player.gold = 200
	main.player.sync_from_world()
	await _frames(3)
	_confere("inscrição", G.send("JoinGuild", {}).accepted)
	var cacas: Array = G.world.modules.quests.contratos().filter(func(x): return str(x.tipo) == "cacar")
	_confere("aceita caça", G.send("AcceptQuest", {"quest_id": cacas[0].id}).accepted)
	main.ui.toggle_guild()
	await _shot("i7_guilda")
	main.ui.close_panels()
	G.world.clock.tick = 6 * 12
	await _frames(5)
	await _shot("i7b_hud")
	var q = G.world.modules.quests
	var cid: String = q.ativas.values()[0].criaturas[0]
	G.world.player.position = G.db.tile_to_world(G.world.modules.combat.creature_tile(cid) + Vector2i(3, 0))
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(5)
	_confere("criatura do contrato tem vista", main.npc_layer.creature_views.has(cid))
	await _shot("i8_cacada")
	print("falhas: ", falhas)
	quit(falhas)
