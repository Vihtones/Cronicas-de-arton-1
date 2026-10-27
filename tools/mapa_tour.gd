extends SceneTree
## Capturas do mapa em pontos escolhidos (verificação visual). Uso:
## xvfb-run godot --path . -s res://tools/mapa_tour.gd -- <pasta> x,y [x,y ...]
var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var G = root.get_node("Game")
	await _frames(10)
	main.ui._creation["class"] = "guerreiro"
	G.new_game(false, 7)
	for i in 600:
		var carregando: bool = main.ui._loading != null and main.ui._loading.visible
		if main._bakes_left <= 0 and not carregando:
			break
		await process_frame
	G.world.clock.tick = 6 * 11 + 144
	for i in range(1, args.size()):
		var xy: PackedStringArray = args[i].split(",")
		G.world.player.position = G.db.tile_to_world(Vector2i(int(xy[0]), int(xy[1])))
		main.player.sync_from_world(); main.camera.reset_smoothing()
		G.send("AdvanceTime", {"ticks": 1})
		G.world.modules.weather.region.condition = "limpo"
		main.npc_layer.sync_all()
		await _frames(30)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("pt_%d_%s.png" % [i, args[i].replace(",", "_")]))
		print("shot ", args[i])
	quit()
