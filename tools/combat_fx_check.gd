extends SceneTree
## Verificação ponta a ponta da encenação de combate: um golpe que derruba o alvo (momento "ABATIDO!")
## pelo caminho real (ExecutePlan → eventos → reprodução). Confere que a reprodução termina, a escala
## de tempo volta a 1 e a interface reaparece. Uso: xvfb-run godot --path . -s res://tools/combat_fx_check.gd -- <pasta>
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
	s.c(target).tile = me + Vector2i(1, 0)
	main.npc_layer.creature_views[target].global_position = G.db.tile_to_world(me + Vector2i(1, 0))
	s.c(target).sheet.pv = 1
	s.c(target).sheet.defense_fixed = 0
	cv.plan = [{"type": "attack", "target": target}]
	cv._update_preview()
	cv.confirm()
	var saw_cine := false
	for i in 400:
		await process_frame
		if main.cine.running and not saw_cine:
			saw_cine = true
			await _frames(8)
			await _shot("c1_momento")
		if saw_cine and not main.cine.running and not cv.playing:
			break
	await _frames(30)
	await _shot("c2_depois")
	var ui_alpha: float = main.ui.get_child(0).modulate.a
	print("RESULTADO cinematico=%s time_scale=%.2f playing=%s ui_alpha=%.2f" % [saw_cine, Engine.time_scale, cv.playing, ui_alpha])
	quit(0 if saw_cine and is_equal_approx(Engine.time_scale, 1.0) and not cv.playing and ui_alpha > 0.9 else 1)
