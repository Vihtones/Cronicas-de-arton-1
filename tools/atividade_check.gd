extends SceneTree
## Captura: rótulo de um morador perto do jogador mostra a atividade. Uso: -s res://tools/atividade_check.gd -- <pasta>
var out_dir := "user://act"
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
	await _frames(10)
	var t: Vector2i = G.world.modules.npcs.npc_tile("garrick")
	G.world.player.position = G.db.tile_to_world(Vector2i(t.x + 1, t.y))
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	await _frames(60)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("act.png"))
	var lbl: String = main.npc_layer.npc_views["garrick"].label.text
	print("ROTULO=%s" % lbl)
	quit(0 if lbl.contains("·") else 1)
