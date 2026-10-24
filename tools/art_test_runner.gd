extends SceneTree
## Teste visual do acervo Tormenta20 (NÃO aprovado) dentro do cenário real do jogo.
## Os PNGs são lidos de uma pasta externa em tempo de execução: nada é copiado para o projeto
## nem registrado no manifesto, e o governador continua sem conhecê-los (AD-06).
## Uso: xvfb-run godot --path . -s res://tools/art_test_runner.gd -- <pasta_acervo_outputs> <pasta_saida>

var src := ""
var out_dir := ""
var main: Node
var extra: Array[Node] = []

const PEOPLE := ["vistas-recortadas-v3/bestiario-8v-004/03-bandido-comum", "vistas-recortadas-v3/bestiario-8v-004/04-bandido-ligeiro",
	"vistas-recortadas-v3/bestiario-8v-004/05-bandido-selvagem", "vistas-recortadas-v3/bestiario-8v-003/02-arqueiro-escravo",
	"vistas-recortadas-v3/bestiario-8v-005/02-bispo-de-guerra", "vistas-recortadas-v3/bestiario-8v-001-v4/01-acolito-de-kally",
	"vistas-recortadas-v3/bestiario-8v-005/07-bruxa-goblin"]
const CREATURES := ["vistas-recortadas-v3/bestiario-8v-004/06-bando-de-deinonicos", "vistas-recortadas-v3/bestiario-8v-005/06-brontoterio",
	"vistas-recortadas-v3/bestiario-8v-003/06-asa-assassina", "vistas-recortadas-v3/bestiario-8v-001-v4/06-alma-acorrentada"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	src = a[0]
	out_dir = a[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw   # captura só com o quadro completo (sob carga pegava quadros pela metade)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _tex(rel: String) -> ImageTexture:
	var img := Image.load_from_file(src.path_join(rel))
	return ImageTexture.create_from_image(img)


func _clear() -> void:
	for n in extra:
		n.queue_free()
	extra.clear()


## Sprite de 256×256 com pivô (128,240) do catálogo v3, nos pés, Y-sort com os atores.
func _figure(rel_dir: String, view: String, tile: Vector2i, sc: float, linear: bool, label := "") -> void:
	var G = root.get_node("Game")
	var s := Sprite2D.new()
	s.texture = _tex(rel_dir + "/vista-" + view + ".png")
	s.centered = false
	s.offset = Vector2(-128, -240)
	s.scale = Vector2(sc, sc)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = G.db.tile_to_world(tile) + Vector2(0, 10)
	main.get_node("Atores").add_child(s)
	extra.append(s)
	if label != "":
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 3)
		l.position = G.db.tile_to_world(tile) + Vector2(-20, 14)
		l.z_index = 50
		main.add_child(l)
		extra.append(l)


## Remendo de material repetido sobre o chão (abaixo dos atores), 128 px escalados.
func _patch(rel: String, tile: Vector2i, size_tiles: Vector2i, sc: float, label := "") -> void:
	var G = root.get_node("Game")
	var s := Sprite2D.new()
	s.texture = _tex(rel)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, Vector2(size_tiles * 32) / sc)
	s.scale = Vector2(sc, sc)
	s.position = Vector2(tile * 32)
	main.get_node("Mundo").add_child(s)
	extra.append(s)
	if label != "":
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 3)
		l.position = Vector2(tile * 32) + Vector2(2, 1)
		l.z_index = 50
		main.add_child(l)
		extra.append(l)


func _goto(tile: Vector2i, tick: int) -> void:
	var G = root.get_node("Game")
	G.world.clock.tick = tick
	G.world.player.position = G.db.tile_to_world(tile)
	main.player.sync_from_world()
	main.camera.reset_smoothing()
	G.send("AdvanceTime", {"ticks": 1})
	G.world.modules.weather.region.condition = "limpo"
	main.npc_layer.sync_all()


func _run() -> void:
	await _frames(10)
	var G = root.get_node("Game")
	G.new_game(false, 7)
	main.npc_layer.visible = false   # só o jogador como referência de escala
	# 1) escada de escala: jogador (placeholder ~28 px) ao lado do bandido em 1/2, 1/3, 1/4, 1/5 e 1/4 linear
	var base := Vector2i(30, 18)
	_goto(base, 6 * 10)
	var b: String = PEOPLE[0]
	var steps := [[0.5, false, "1/2"], [0.333, false, "1/3"], [0.25, false, "1/4"], [0.2, false, "1/5"], [0.25, true, "1/4 suave"]]
	for i in steps.size():
		_figure(b, "01", base + Vector2i(-5 + i * 2, 0), steps[i][0], steps[i][1], steps[i][2])
	await _frames(20)
	await _shot("t1_escala_bandido")
	_clear()
	# 2) vila de dia: pessoas a 1/4 sobre materiais (calçamento, terra, madeira, tijolo) a 1/2
	var v := Vector2i(30, 18)
	_patch("texturas-recortadas/11-calcamento.png", v + Vector2i(-9, -4), Vector2i(5, 3), 0.5, "calçamento")
	_patch("texturas-recortadas/03-terra.png", v + Vector2i(-4, -4), Vector2i(4, 3), 0.5, "terra")
	_patch("texturas-recortadas/19-madeira-envelhecida.png", v + Vector2i(0, -4), Vector2i(4, 3), 0.5, "madeira envelhecida")
	_patch("texturas-recortadas/12-tijolo.png", v + Vector2i(4, -4), Vector2i(4, 3), 0.5, "tijolo")
	var views := ["01", "03", "05", "07"]
	for i in PEOPLE.size():
		_figure(PEOPLE[i], views[i % 4], v + Vector2i(-8 + i * 2, 1), 0.25, false)
	_goto(v + Vector2i(0, 0), 6 * 10)
	await _frames(20)
	await _shot("t2_pessoas_materiais_dia")
	_goto(v + Vector2i(0, 0), 6 * 21)
	await _frames(30)
	await _shot("t3_pessoas_materiais_noite")
	_clear()
	# 3) floresta: criaturas a 1/4 e 1/3 entre as árvores LPC, materiais naturais
	var f := Vector2i(66, 31)
	_patch("texturas-recortadas/08-musgo.png", f + Vector2i(-6, 2), Vector2i(3, 2), 0.5, "musgo")
	_patch("texturas-recortadas/04-lama.png", f + Vector2i(-3, 2), Vector2i(3, 2), 0.5, "lama")
	_patch("texturas-recortadas/09-pedra.png", f + Vector2i(0, 2), Vector2i(3, 2), 0.5, "pedra")
	_patch("texturas-recortadas/01-grama.png", f + Vector2i(3, 2), Vector2i(3, 2), 0.5, "grama")
	_figure(CREATURES[0], "01", f + Vector2i(-4, 0), 0.333, false, "deinônicos 1/3")
	_figure(CREATURES[1], "03", f + Vector2i(-1, 1), 0.333, false, "brontotério 1/3")
	_figure(CREATURES[2], "01", f + Vector2i(2, -1), 0.25, false, "asa-assassina 1/4")
	_figure(CREATURES[3], "01", f + Vector2i(4, 1), 0.25, false, "alma acorrentada 1/4")
	_goto(f, 6 * 15 + 144)
	await _frames(20)
	await _shot("t4_criaturas_floresta")
	_clear()
	# 4) quatro direções do bandido ligeiro a 1/4, nearest
	for i in 4:
		_figure(PEOPLE[1], views[i], base + Vector2i(-3 + i * 2, 0), 0.25, false, "vista " + views[i])
	_goto(base, 6 * 10)
	await _frames(20)
	await _shot("t5_direcoes")
	quit()
