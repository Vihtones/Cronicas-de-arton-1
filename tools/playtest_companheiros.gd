extends SceneTree
## Playtest dos companheiros na luta: recruta Garrick, começa uma luta com um bandido e confere que ele age.
## Uso: xvfb-run godot --path . -s res://tools/playtest_companheiros.gd -- <pasta_saida>

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
	G.world.player.gold = 500
	main.player.sync_from_world()
	main.npc_layer.sync_all()
	await _frames(3)
	var r = G.send("RecruitCompanion", {"npc_id": "garrick", "pay": 10})
	_confere("Garrick aceita se juntar pagando a taxa", r.accepted)
	G.send("SetOrder", {"npc_id": "garrick", "order": "proteger"})
	var c = G.world.modules.combat
	G.world.player.position = G.world.db.tile_to_world(Vector2i(25, 57))
	c._start(["bandido_1"], false, false)
	await _frames(5)
	_confere("Garrick entra na luta do lado do jogador", c.sim.combatants.has("garrick") and c.sim.c("garrick").side == "player")
	await _shot("p1_luta_inicio")
	var agiu := false
	var pos_inicio: Vector2i = c.sim.c("garrick").tile
	for i in 6:
		if not c.active:
			break
		var resp = G.send("EndTurn")
		for f in resp.emitted_events:
			if f.event_type == "TURN_STARTED" and str(f.payload.get("actor", "")) == "garrick":
				agiu = true
	_confere("Garrick age nos turnos seguintes", agiu)
	_confere("Garrick se move (ordem proteger)", c.sim.c("garrick").tile != pos_inicio)
	await _frames(5)
	await _shot("p2_luta_depois")
	print("FIM falhas=%d" % falhas)
	quit(falhas)
