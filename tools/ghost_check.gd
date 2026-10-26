extends SceneTree
## Verificação ponta a ponta da encenação de combate: um golpe que derruba o alvo (momento "ABATIDO!")
## pelo caminho real (ExecutePlan → eventos → reprodução). Confere que a reprodução termina, a escala
## de tempo volta a 1 e a interface reaparece. Uso: xvfb-run godot --path . -s res://tools/ghost_check.gd -- <pasta>
var out_dir := "user://cfx"
var main: Node

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out_dir = a[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(n: String) -> void:
	await _frames(1)
	await RenderingServer.frame_post_draw   # captura só com o quadro completo (sob carga pegava quadros pela metade)
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("shot ", n)

func _run() -> void:
	var G = root.get_node("Game")
	await _frames(5)
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 14 + 144
	G.world.player.position = G.db.tile_to_world(Vector2i(21, 56))
	main.player.sync_from_world()
	G.send("MovePlayer", {"to": G.world.player.position})
	var cv = main.combat_view
	for i in 600:
		await process_frame
		if G.world.modules.combat.active and cv.my_turn():
			break
	var c = G.world.modules.combat
	if not c.active:
		print("FALHA: combate não começou"); quit(1); return
	var s = c.sim
	var target := ""
	for id in s.combatants:
		if id != "player" and s.conscious(id):
			target = id; break
	var me: Vector2i = s.c("player").tile
	var tt: Vector2i = s.c(target).tile
	print("jogador=%s alvo=%s dist=%d" % [me, tt, CombatSim.cheb(me, tt)])
	cv.hover = tt
	cv.add_hover_to_plan()
	var ok := true
	print("my_turn=%s playing=%s valid=%s steps=%s" % [cv.my_turn(), cv.playing, cv.preview.get("valid"), str(cv.preview.get("steps", []).map(func(x): return [x.ok, x.get("reason", "")]))])
	for i in 6:
		var g = cv.ghost
		var times := [0.05, 0.12, 0.2, 0.26, 0.3, 0.38]
		await process_frame
		g._t = times[i] - 0.001
		g.set_process(false)
		g._process(0.001)
		await RenderingServer.frame_post_draw
		print("t=%.2f pos=%s vis=%s" % [times[i], g.position, g.visible])
		root.get_texture().get_image().save_png("/tmp/gh/g%d.png" % i)
		g.set_process(true)
	# caminhada + golpe: o fantasma anda até perto do alvo e só então ataca
	var g2 = cv.ghost
	var o := Vector2(100, 100)
	g2.set_script_data(o, [{"k": "walk", "pts": [Vector2(132, 100), Vector2(164, 100)]}, {"k": "hit", "from": Vector2(164, 100), "to": Vector2(196, 100)}],
		g2.sprite.texture, Color.WHITE, 1.0)
	var xs: Array = []
	for tm in [0.1, 0.3, 0.55, 0.62, 0.8, 0.9]:
		g2._t = tm - 0.001
		g2._process(0.001)
		xs.append(snappedf(g2.position.x, 0.1))
	print("caminhada xs=", xs)
	if not (xs[0] > 100 and xs[1] > xs[0] and xs[2] >= 160 and xs[3] < 164.5 and xs[4] > 170 and xs[5] < xs[4]):
		ok = false
		print("FALHA: trajetória do fantasma inesperada")
	cv.clear_plan()
	await _frames(3)
	if cv.ghost.visible: ok = false; print("FALHA: fantasma continua após limpar o plano")
	print("RESULTADO fantasma=%s" % ok)
	quit(0 if ok else 1)
