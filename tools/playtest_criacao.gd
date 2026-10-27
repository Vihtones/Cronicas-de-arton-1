extends SceneTree
## Playtest da criação de ficha: abre a tela de criação e captura a lista de poderes da classe.
## Uso: xvfb-run godot --path . -s res://tools/playtest_criacao.gd -- <pasta_saida>

var out_dir := "user://shots"
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


func _run() -> void:
	await _frames(15)
	for cls in ["guerreiro", "ladino", "arcanista"]:
		main.ui._creation["class"] = cls
		main.ui.open_creation()
		await _frames(5)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("k_criacao_%s.png" % cls))
		print("shot k_criacao_%s" % cls)
	print("FIM")
	quit(0)
