class_name Minimap
extends Control
## Minimapa (canto superior direito, estilo Stoneshard): recorte da região em volta do jogador,
## com prédios, estradas, água, NPCs conhecidos por perto, o evento da vila e um ícone do clima.
## Só lê projeções do domínio.

const PX := 2                    # pixels por tile no minimapa
var _tex: ImageTexture
var _size := Vector2i.ZERO
var weather_icon := "limpo"
var night := false
var _t := 0.0
var _acc := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func build(db: ContentDB) -> void:
	_size = db.size
	var img := Image.create(_size.x * PX, _size.y * PX, false, Image.FORMAT_RGBA8)
	var col := {".": Color(0.3, 0.45, 0.22), ",": Color(0.2, 0.33, 0.17), "T": Color(0.12, 0.24, 0.12), "=": Color(0.62, 0.52, 0.36),
		":": Color(0.52, 0.44, 0.3), "c": Color(0.62, 0.58, 0.28), "~": Color(0.2, 0.35, 0.55), "#": Color(0.55, 0.3, 0.22),
		"_": Color(0.45, 0.36, 0.28), "D": Color(0.8, 0.65, 0.3), "%": Color(0.4, 0.38, 0.35), "o": Color(0.4, 0.55, 0.75),
		"X": Color(0.05, 0.05, 0.06), "S": Color(0.6, 0.6, 0.6), "U": Color(0.6, 0.6, 0.6),
		"B": Color(0.08, 0.06, 0.05), "p": Color(0.55, 0.42, 0.25)}
	for y in _size.y:
		for x in _size.x:
			var t := Vector2i(x, y)
			var ch := db.tile_char(t)
			var c: Color = col.get(ch, Color(0.1, 0.1, 0.1))
			if db.zone_at(t) == "cripta" and ch != "X":
				c = c.darkened(0.45)
			if (ch == "_" or ch == "#") and db.zone_at(t) == "vila":
				c = Color(0.62, 0.28, 0.2) if ch == "#" else Color(0.58, 0.3, 0.22)   # telhados
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), c)
	_tex = ImageTexture.create_from_image(img)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if visible and _acc >= 0.1:   # 10 quadros/s bastam para o minimapa
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.035, 0.04))
	if _tex == null or Game.world == null:
		return
	var pt := Game.player_tile()
	var center := Vector2(pt) * PX + Vector2(PX, PX) / 2.0
	var off := (size / 2.0 - center).round()
	draw_texture(_tex, off, Color(0.72, 0.72, 0.85) if night else Color.WHITE)
	# NPCs do domínio presentes por perto (pontos claros)
	var npcs: NpcModule = Game.world.modules.npcs
	for id in Game.world.all_npc_ids():
		if not npcs.is_present(id): continue
		var t: Vector2i = npcs.npc_tile(id)
		if t.x < 0 or Game.db.zone_at(t) != Game.db.zone_at(pt): continue
		var p := off + Vector2(t) * PX + Vector2(1, 1)
		if r.has_point(p):
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.95, 0.9, 0.75))
	# evento da vila: estandarte piscando no lugar
	var te: TownEventsModule = Game.world.modules.town_events
	for ev in te.active_ids():
		var loc := Game.db.location(TownEventsModule.EVENTS[ev].place)
		var lr: Array = loc.get("rect", [0, 0, 0, 0])
		var p2 := off + Vector2(int(lr[0]) + int(lr[2]) / 2.0, int(lr[1]) + int(lr[3]) / 2.0) * PX
		var a := 0.6 + 0.4 * sin(_t * 4.0)
		draw_line(p2, p2 + Vector2(0, -8), Color(0.9, 0.85, 0.7, a), 1.0)
		draw_colored_polygon(PackedVector2Array([p2 + Vector2(0, -8), p2 + Vector2(6, -6), p2 + Vector2(0, -4)]), Color(0.9, 0.25, 0.2, a))
	# contratos ativos: alvo marcado em vermelho (caça), azul (entrega/exploração)
	var qm: QuestModule = Game.world.modules.quests
	for qid in qm.ativas:
		var qa: Dictionary = qm.ativas[qid]
		if not qa.has("alvo_tile") or bool(qa.progresso.feito) and str(qa.tipo) != "entregar":
			continue
		var at := Vector2(int(qa.alvo_tile[0]), int(qa.alvo_tile[1]))
		var pq := (off + at * PX).clamp(Vector2(4, 4), size - Vector2(4, 4))
		var cq := Color(1, 0.3, 0.25) if str(qa.tipo) == "cacar" else Color(0.4, 0.7, 1.0)
		draw_circle(pq, 2.5 + 0.8 * sin(_t * 4.0), cq)
	# jogador
	var pc := size / 2.0
	draw_colored_polygon(PackedVector2Array([pc + Vector2(0, -3), pc + Vector2(3, 2), pc + Vector2(-3, 2)]), Color(1.0, 0.85, 0.3))
	draw_rect(Rect2(pc - Vector2(4, 4), Vector2(8, 8)), Color(1, 0.85, 0.3, 0.25 + 0.2 * sin(_t * 5.0)), false, 1.0)
	# moldura e rosa dos ventos
	draw_rect(r, Color(0.72, 0.56, 0.28), false, 2.0)
	draw_rect(r.grow(-3), Color(0.35, 0.27, 0.16), false, 1.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x / 2.0 - 2, 10), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.98, 0.82, 0.45))
	_draw_weather(Vector2(size.x - 13, 13))


func _draw_weather(c: Vector2) -> void:
	draw_circle(c, 10.0, Color(0.06, 0.05, 0.06, 0.85))
	draw_arc(c, 10.0, 0, TAU, 20, Color(0.72, 0.56, 0.28), 1.0)
	var cloud := Color(0.82, 0.84, 0.9)
	match weather_icon:
		"limpo":
			if night:
				draw_circle(c, 5.0, Color(0.9, 0.9, 1.0)); draw_circle(c + Vector2(2.5, -2), 4.0, Color(0.06, 0.05, 0.06))
			else:
				draw_circle(c, 4.0, Color(1.0, 0.82, 0.3))
				for i in 8:
					var a := i * PI / 4 + _t * 0.3
					draw_line(c + Vector2(cos(a), sin(a)) * 5.5, c + Vector2(cos(a), sin(a)) * 7.5, Color(1.0, 0.82, 0.3), 1.0)
		"nublado", "chuva", "tempestade":
			draw_circle(c + Vector2(-2, 0), 3.5, cloud); draw_circle(c + Vector2(2, -1), 4.0, cloud); draw_rect(Rect2(c + Vector2(-5, 0), Vector2(10, 3)), cloud)
			if weather_icon != "nublado":
				for i in 3: draw_line(c + Vector2(-4 + i * 3, 4), c + Vector2(-5 + i * 3, 7), Color(0.5, 0.7, 1.0), 1.0)
			if weather_icon == "tempestade":
				draw_polyline(PackedVector2Array([c + Vector2(1, 2), c + Vector2(-1, 5), c + Vector2(1, 5), c + Vector2(-1, 8)]), Color(1, 0.9, 0.4), 1.0)
		"neblina":
			for i in 3: draw_line(c + Vector2(-6, -3 + i * 3), c + Vector2(6, -3 + i * 3), Color(cloud, 0.8), 1.5)
