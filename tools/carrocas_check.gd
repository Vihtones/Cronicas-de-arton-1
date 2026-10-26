extends SceneTree
## Captura: carroças de entrega seguem o domínio (CartsModule). Uso: -s res://tools/carrocas_check.gd -- <pasta>
var out_dir := "user://carr"
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

func _run() -> void:
	var G = root.get_node("Game")
	await _frames(5)
	G.new_game(false, 7)
	G.world.clock.tick = 6 * 10
	var cm = G.world.modules.carts
	G.world.player.position = G.db.tile_to_world(Vector2i(30, 25))
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	for i in 400:
		G.world.modules.carts.on_tick(G.world.clock.tick)
		G.world.clock.tick += 1
		await process_frame
		if cm.carts.size() > 0 and cm.carts[0].phase == "chegando" and cm.carts[0].t >= 8:
			break
	for i in 600:
		if main.get("_bakes_left") == 0 or main.get("_bakes_left") == null:
			break
		await process_frame
	await _frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("carr.png"))
	var n: int = main.life.carts.size()
	print("DOMINIO=%d  NA_TELA=%d  fase=%s" % [cm.carts.size(), n, str(cm.carts.map(func(c): return c.phase))])
	quit(0 if n == cm.carts.size() and n >= 1 else 1)
