extends SceneTree
## Capturas dos sistemas visuais (luz, sombras, desfoque, cinematográfico, retratos, rastros e impacto).
## Uso: xvfb-run godot --path . -s res://tools/fx_runner.gd -- <pasta_saida>

var out_dir := "user://fx"
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


func _goto(G, tile: Vector2i, tick: int, weather := "limpo") -> void:
	G.world.clock.tick = tick
	G.world.player.position = G.db.tile_to_world(tile)
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	G.send("AdvanceTime", {"ticks": 1})
	G.world.modules.weather.region.condition = weather
	main.npc_layer.sync_all()


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(5)
	G.new_game(false, 7)
	await _frames(5)
	# luz do dia: manhã, meio-dia, entardecer e noite na praça (sombras projetadas, janelas, tochas)
	for spec in [[6 * 7, "f01_manha"], [6 * 12, "f02_meio_dia"], [6 * 18 + 3, "f03_entardecer"], [6 * 22, "f04_noite"]]:
		_goto(G, Vector2i(22, 27), spec[0])
		await _frames(25)
		await _shot(spec[1])
	_goto(G, Vector2i(23, 27), 6 * 21, "chuva")
	await _frames(30)
	await _shot("f05_noite_chuva")
	# retratos: todas as expressões (sistema provisório)
	var cine = main.cine
	var exprs := ["neutro", "determinado", "furioso", "surpreso", "dor", "alegria", "medo", "concentrado"]
	var holders: Array = []
	for i in exprs.size():
		var p := Portrait.new()
		p.size = Vector2(72, 72)
		p.position = Vector2(8 + (i % 4) * 80, 30 + (i / 4) * 90)
		p.set_actor("player", ["humano", "elfo", "minotauro", "goblin"][i % 4])
		p.set_expression(exprs[i])
		cine.add_child(p)
		holders.append(p)
	for i in 2:
		var h := Portrait.new()
		h.size = Vector2(72, 72)
		h.position = Vector2(340 + i * 80, 30)
		h.set_actor("hiena_1", "humano", true)
		h.set_expression(["neutro", "furioso"][i])
		cine.add_child(h)
		holders.append(h)
	await _frames(10)
	await _shot("f06_retratos")
	for h in holders: h.queue_free()
	# combate na cripta: rastro do golpe e impacto congelados no meio da animação
	G.world.clock.tick = 6 * 14 + 144
	G.world.player.position = G.db.tile_to_world(Vector2i(21, 56))
	main.player.sync_from_world()
	G.send("MovePlayer", {"to": G.world.player.position})
	await _frames(90)
	var cv = main.combat_view
	if G.world.modules.combat.active:
		var s = G.world.modules.combat.sim
		var target := ""
		for id in s.combatants:
			if id != "player":
				target = id
				break
		var a_pos: Vector2 = main.player.global_position + Vector2(0, -10)
		var tv = main.npc_layer.creature_views.get(target)
		var t_pos: Vector2 = (tv.global_position if tv else a_pos + Vector2(40, 0)) + Vector2(0, -10)
		ImpactFx.slash_trail(main.fx.glow, a_pos, t_pos, "corte", true, false)
		ImpactFx.impact_burst(main.fx.glow, t_pos, t_pos - a_pos, "corte", false, 1.2)
		if tv: tv.play_hit(t_pos - a_pos, 1.2, false)
		await _frames(3)
		await _shot("f07_golpe_rastro_impacto")
		await _frames(30)
		ImpactFx.slash_trail(main.fx.glow, a_pos, t_pos, "impacto", false, false)
		await _frames(3)
		await _shot("f08_erro_vento")
		await _frames(30)
		ImpactFx.spell_bolt(main.fx.glow, a_pos, t_pos, Color(0.7, 0.6, 1.0), 0.6)
		await _frames(12)
		await _shot("f09_magia_seta")
		await _frames(40)
		ImpactFx.lightning(main.fx.glow, a_pos, t_pos)
		await _frames(2)
		await _shot("f10_toque_chocante")
		await _frames(30)
		# momento cinematográfico forçado (crítico do jogador)
		var m := {"caption": "CRÍTICO!", "sub": "Espada Longa · 14 de dano", "a": "furioso", "t": "dor", "zoom": 1.9, "slow": 0.55, "chroma": 1.0,
			"attacker": "player", "target": target}
		await cine.begin(m, a_pos, t_pos)
		await _shot("f11_cinema_antecipacao")
		cine.reaction(m)
		ImpactFx.impact_burst(main.fx.glow, t_pos, t_pos - a_pos, "corte", true, 2.0)
		await create_timer(0.3, true, false, true).timeout
		await _shot("f12_cinema_reacao")
		await cine.finished
		# inimigo: "por um fio"
		var m2 := {"caption": "POR UM FIO!", "sub": "Bandido quase acerta.", "a": "furioso", "t": "medo", "zoom": 1.5, "slow": 0.3, "chroma": 0.0,
			"attacker": target, "target": "player"}
		await cine.begin(m2, t_pos, a_pos)
		cine.reaction(m2)
		await create_timer(0.35, true, false, true).timeout
		await _shot("f13_cinema_inimigo")
		await cine.finished
	quit()
