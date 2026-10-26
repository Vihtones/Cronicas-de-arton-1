extends SceneTree
## Capturas do mundo vivo: casas com telhado, caminhos, figurantes, feira, festa, chuva chegando,
## telhado abrindo ao entrar, HUD e árvore de poderes.
## Uso: xvfb-run godot --path . -s res://tools/falas_check.gd -- <pasta_saida>

var out_dir := "user://life"
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
	await RenderingServer.frame_post_draw   # captura só com o quadro completo (sob carga pegava quadros pela metade)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _goto(G: Node, tile: Vector2i, day: int, hour: int, weather := "limpo") -> void:
	var target := (day * 24 + hour) * 6
	if target > G.world.clock.tick:
		G.send("AdvanceTime", {"ticks": target - G.world.clock.tick})
	G.world.modules.weather.region.condition = weather
	G.world.modules.weather.region.intensity = 1.0 if weather in ["chuva", "tempestade", "neblina"] else 0.0
	G.world.player.position = G.db.tile_to_world(tile)
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	main.npc_layer.sync_all()
	for a in main.life.agents.duplicate():
		(a.view as Node).queue_free()
	main.life.agents.clear()
	main.life.prefill()


func _run() -> void:
	var G = root.get_node("Game")
	await _frames(5)
	G.new_game(false, 7)
	G.world.modules.weather.enabled = true
	await _frames(10)
	_goto(G, Vector2i(18, 24), 1, 10)
	var seen := {}
	var shots := 0
	for i in 900:
		await process_frame
		for l in main.life.find_children("*", "Label", true, false):
			var tx: String = (l as Label).text
			if (l as Label).modulate.a > 0.9 and tx.length() > 2 and not seen.has(tx):
				seen[tx] = true
				if shots < 3 and seen.size() >= 3 + shots * 3:
					await _shot("f%d" % shots)
					shots += 1
	print("falas vistas (%d): %s" % [seen.size(), str(seen.keys().slice(0, 14))])
	var generic := ["Hm.", "Sim, sim.", "Ouviu essa?", "Ha!", "Será?", "Que calor."]
	var bad := false
	for g in generic:
		if seen.has(g): bad = true
	print("RESULTADO falas=%s genericas=%s" % [seen.size() > 3, bad])
	quit(0 if seen.size() > 3 and not bad else 1)
