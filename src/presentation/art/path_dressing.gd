class_name PathDressing
extends Node2D
## Caminhos orgânicos (apresentação; o mapa de regras não muda).
## A grade de tiles deixa estradas com bordas retas. Esta camada:
##  - quebra as bordas: terra que "vaza" para a grama e tufos de grama que invadem a estrada;
##  - desenha trilhas de desejo (o chão gasto de quem sai de cada porta até a estrada mais próxima),
##    suavizadas por spline e com largura variando, como em vilas reais e nas referências
##    (Stoneshard/Graveyard Keeper: caminhos nascem do uso, não da régua);
##  - calça a praça em volta do poço com pedras irregulares;
##  - espalha flores, seixos e manchas de grama para tirar a repetição do tile;
##  - mostra poças quando o chão está molhado ou lamacento (estado do clima).
## Tudo determinístico (hash do tile) para não "piscar" entre quadros.

const TILE := 32
const ROAD := ["=", ":"]
const GRASS := [".", ","]

var world_view: WorldView
var puddles: Node2D
var _puddle_spots: Array = []
var _wet := -1.0
var _trails: Array = []          # Array[PackedVector2Array]
var _chunks: Array = []
const CHUNK := 16


func _init() -> void:
	puddles = Node2D.new()
	puddles.name = "Pocas"
	puddles.draw.connect(_draw_puddles)
	add_child(puddles)


func build(db: ContentDB, wv: WorldView) -> void:
	world_view = wv
	_trails = desire_trails(db, wv)
	_puddle_spots.clear()
	for y in db.size.y:
		for x in db.size.x:
			var t := Vector2i(x, y)
			if ROAD.has(db.tile_char(t)) and db.zone_at(t) in ["vila", "estrada"] and _h(t, 3) % 7 == 0:
				_puddle_spots.append(Vector2(x * TILE + 6 + _h(t, 5) % 20, y * TILE + 6 + _h(t, 9) % 20))
	for c in _chunks: (c as Node).queue_free()
	_chunks.clear()
	# desenho estático em pedaços de 16x16 tiles: cada pedaço fora da tela é descartado pelo
	# renderizador (um único item com dezenas de milhares de comandos estourava o buffer do
	# renderizador de compatibilidade e escurecia quadrantes da tela)
	for cy in range(0, db.size.y, CHUNK):
		for cx in range(0, db.size.x, CHUNK):
			var ch := Node2D.new()
			ch.name = "Chao_%d_%d" % [cx, cy]
			ch.draw.connect(_draw_chunk.bind(ch, Rect2i(cx, cy, CHUNK, CHUNK)))
			add_child(ch)
			move_child(ch, 0)
			_chunks.append(ch)
			ch.queue_redraw()
	call_deferred("_bake_chunks")
	var ex := Node2D.new()
	ex.draw.connect(_draw_extras.bind(ex))
	add_child(ex)
	move_child(ex, _chunks.size())
	_chunks.append(ex)
	ex.queue_redraw()
	puddles.queue_redraw()


static func _h(t: Vector2i, salt: int) -> int:
	return absi(hash(Vector3i(t.x, t.y, salt)))


## Trilhas de desejo: de cada porta da vila até o tile de estrada mais próximo (A* de animação),
## pontos suavizados por Catmull-Rom. Puro, testável.
static func desire_trails(db: ContentDB, wv: WorldView) -> Array:
	var out: Array = []
	var roads: Array[Vector2i] = []
	for y in db.size.y:
		for x in db.size.x:
			if ROAD.has(db.tile_char(Vector2i(x, y))):
				roads.append(Vector2i(x, y))
	for o in db.all_objects():
		if o.type != "door":
			continue
		var d := Vector2i(int(o.tile[0]), int(o.tile[1]))
		if db.zone_at(d) == "cripta":
			continue
		# lado de fora da porta: o vizinho caminhável que não está dentro do prédio
		var start := Vector2i(-1, -1)
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = d + off
			if db.static_walkable(n) and not bool(db.location(db.location_at(n)).get("indoor", false)):
				start = n
				break
		if start.x < 0:
			continue
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for r in roads:
			var dist := absi(r.x - start.x) + absi(r.y - start.y)
			if dist < bd:
				bd = dist; best = r
		if best.x < 0 or bd > 14 or bd <= 1:
			continue
		var path: Array[Vector2i] = wv.path_tiles(start, best) if wv != null else []
		if path.size() < 2:
			continue
		var pts := PackedVector2Array([Vector2(d.x, d.y) * TILE + Vector2(16, 16)])
		for i in path.size():
			var t: Vector2i = path[i]
			var jitter := Vector2((_h(t, 11) % 5) - 2, (_h(t, 13) % 5) - 2) if i > 0 and i < path.size() - 1 else Vector2.ZERO
			pts.append(Vector2(t.x, t.y) * TILE + Vector2(16, 16) + jitter)
		out.append(_smooth(pts))
	return out


static func _smooth(p: PackedVector2Array) -> PackedVector2Array:
	if p.size() < 3:
		return p
	var out := PackedVector2Array()
	for i in p.size() - 1:
		var p0 := p[maxi(0, i - 1)]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[mini(p.size() - 1, i + 2)]
		for k in 6:
			var t := k / 6.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(p[p.size() - 1])
	return out


func _draw_chunk(ci: CanvasItem, area: Rect2i) -> void:
	if Game.world == null and world_view == null:
		return
	var db: ContentDB = Game.db
	var dirt := Color(0.55, 0.43, 0.29)
	var dirt_dark := Color(0.45, 0.35, 0.24)
	var grass_dark := Color(0.24, 0.42, 0.16)
	# 1) manchas de grama (quebram a repetição) e enfeites
	for y in range(area.position.y, mini(area.end.y, db.size.y)):
		for x in range(area.position.x, mini(area.end.x, db.size.x)):
			var t := Vector2i(x, y)
			var ch := db.tile_char(t)
			var o := Vector2(x, y) * TILE
			if ch == ".":
				if _h(t, 1) % 5 == 0:
					ci.draw_circle(o + Vector2(_h(t, 2) % 32, _h(t, 4) % 32), 6.0 + _h(t, 6) % 8, Color(grass_dark, 0.18))
				if _h(t, 7) % 9 == 0 and db.zone_at(t) == "vila":
					var fc: Color = [Color(0.95, 0.9, 0.5), Color(0.9, 0.5, 0.6), Color(0.75, 0.7, 1.0), Color(1, 1, 1)][_h(t, 8) % 4]
					for k in 3:
						ci.draw_circle(o + Vector2(4 + (_h(t, 20 + k) % 24), 4 + (_h(t, 30 + k) % 24)), 1.2, fc)
				if _h(t, 15) % 11 == 0:
					ci.draw_circle(o + Vector2(_h(t, 16) % 30, _h(t, 17) % 30), 1.6, Color(0.6, 0.58, 0.52))
			elif ch == ":":
				# trilha: traço contínuo e sinuoso até as trilhas/estradas vizinhas (sem "contas" de terra)
				var c0 := o + Vector2(16, 16) + Vector2(_h(t, 90) % 7 - 3, _h(t, 91) % 7 - 3)
				for off in [Vector2i(1, 0), Vector2i(0, 1)]:
					var n2: Vector2i = t + off
					if ROAD.has(db.tile_char(n2)):
						var c1 := Vector2(n2.x, n2.y) * TILE + Vector2(16, 16) + Vector2(_h(n2, 90) % 7 - 3, _h(n2, 91) % 7 - 3)
						var mid := (c0 + c1) / 2.0 + Vector2(off.y, off.x) * float(_h(t, 92) % 5 - 2)
						ci.draw_polyline(PackedVector2Array([c0, mid, c1]), Color(dirt, 0.95), 17.0 + float(_h(t, 93) % 4))
				ci.draw_circle(c0, 9.0, Color(dirt, 0.95))
			elif ch == "=":
				# estrada: a terra avança irregular sobre a grama, sem linha reta
				for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = t + off
					if not GRASS.has(db.tile_char(n)):
						continue
					var edge := o + Vector2(16, 16) + Vector2(off) * 16.0
					var along := Vector2(off.y, off.x).abs()
					for k in 2:
						var s := (float(k) - 0.5) * 0.6 + float(_h(t, 44 + k) % 5 - 2) / 30.0
						var p := edge + along * s * 32.0 + Vector2(off) * float(_h(t, 40 + k + off.x * 3 + off.y * 5) % 6)
						ci.draw_circle(p, 7.0 + float(_h(t, 50 + k) % 6), Color(dirt, 0.5))
					if _h(t, 61 + off.x + off.y * 2) % 3 == 0:
						var q := edge - Vector2(off) * 2.0 + along * float(_h(t, 62) % 24 - 12)
						for b in 3:
							ci.draw_line(q + Vector2(b * 2 - 2, 0), q + Vector2(b * 3 - 3, -5 - b % 2 * 2), Color(0.3, 0.5, 0.2, 0.9), 1.0)
				# sulcos de roda
				if _h(t, 80) % 2 == 0:
					ci.draw_line(o + Vector2(0, 10 + _h(t, 81) % 3), o + Vector2(32, 10 + _h(t, 82) % 3), Color(dirt_dark, 0.3), 1.0)
					ci.draw_line(o + Vector2(0, 22 + _h(t, 83) % 3), o + Vector2(32, 22 + _h(t, 84) % 3), Color(dirt_dark, 0.3), 1.0)


func _draw_extras(ci: CanvasItem) -> void:
	var db: ContentDB = Game.db
	var dirt := Color(0.55, 0.43, 0.29)
	var dirt_dark := Color(0.45, 0.35, 0.24)
	_cobbled.clear()
	# 3) trilhas de desejo
	for tr in _trails:
		var pts: PackedVector2Array = tr
		# borda gasta (mais larga e transparente) + leito batido + rastro central de pés
		ci.draw_polyline(pts, Color(dirt, 0.35), 16.0, true)
		ci.draw_polyline(pts, Color(dirt, 0.8), 10.0, true)
		ci.draw_polyline(pts, Color(dirt_dark, 0.22), 3.0, true)
		for i in range(0, pts.size(), 5):
			ci.draw_circle(pts[i], 7.0, Color(dirt, 0.6))
	# 4) praça calçada em volta do poço
	for o in db.all_objects():
		if str(o.get("id", "")).begins_with("poco") or db.tile_char(Vector2i(int(o.tile[0]), int(o.tile[1]))) == "o":
			_cobbles(ci, Vector2(int(o.tile[0]), int(o.tile[1])) * TILE + Vector2(16, 16))
	for y in db.size.y:
		for x in db.size.x:
			if db.tile_char(Vector2i(x, y)) == "o":
				_cobbles(ci, Vector2(x, y) * TILE + Vector2(16, 16))


var _cobbled := {}



func _cobbles(ci: CanvasItem, c: Vector2) -> void:
	if _cobbled.has(c):
		return
	_cobbled[c] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	ci.draw_circle(c, 92.0, Color(0.5, 0.47, 0.42, 0.55))
	for ring in range(1, 9):
		var r := ring * 11.0
		var n := int(TAU * r / 10.0)
		for i in n:
			var a := TAU * i / n + ring * 0.37
			var p := c + Vector2(cos(a), sin(a)) * (r + rng.randf_range(-2, 2))
			var col := Color(0.62, 0.6, 0.56).darkened(rng.randf_range(0.0, 0.25))
			var w := rng.randf_range(6.0, 9.0)
			ci.draw_rect(Rect2(p - Vector2(w, 5) / 2.0, Vector2(w, 5)), col)
			ci.draw_rect(Rect2(p - Vector2(w, 5) / 2.0 + Vector2(0, 4), Vector2(w, 1)), Color(0.25, 0.23, 0.2, 0.6))
	# borda irregular onde a pedra encontra a terra
	for i in 40:
		var a2 := TAU * i / 40.0
		ci.draw_circle(c + Vector2(cos(a2), sin(a2)) * rng.randf_range(90, 98), rng.randf_range(3, 6), Color(0.55, 0.43, 0.29, 0.8))


func _process(_d: float) -> void:
	if Game.world == null:
		return
	var w: WeatherModule = Game.world.modules.weather
	var wet := 0.0
	if w.enabled:
		wet = {"seco": 0.0, "molhado": 0.6, "lamacento": 1.0}.get(str(w.region.surface), 0.0)
		wet = maxf(wet, float(w.region.get("intensity", 0.0)) * (1.0 if w.is_raining() else 0.0))
	if absf(wet - _wet) > 0.05:
		_wet = wet
		puddles.queue_redraw()


func _draw_puddles() -> void:
	if _wet <= 0.05:
		return
	for i in _puddle_spots.size():
		var p: Vector2 = _puddle_spots[i]
		var s := (0.6 + 0.4 * float(i % 3) / 2.0) * _wet
		var pts := PackedVector2Array()
		for k in 10:
			var a := TAU * k / 10.0
			pts.append(p + Vector2(cos(a) * (9.0 + (i * 7 + k * 3) % 4) * s, sin(a) * (4.0 + (i + k) % 2) * s))
		puddles.draw_colored_polygon(pts, Color(0.32, 0.36, 0.42, 0.55 * _wet))
		puddles.draw_line(p + Vector2(-4, -1) * s, p + Vector2(3, -2) * s, Color(0.75, 0.8, 0.88, 0.35 * _wet), 1.0)


## Assa cada pedaço numa textura (uma vez): o chão decorado vira um sprite por pedaço em vez de
## milhares de comandos de desenho por quadro. Sob carga, o renderizador de compatibilidade
## chegava a perder pedaços da tela (blocos pretos). Sem renderização (headless) mantém o desenho vivo.
func _bake_chunks() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gen := _chunks.duplicate()
	for ch in gen:
		if not is_instance_valid(ch) or not (ch is Node2D) or ch.get_child_count() > 0:
			continue
		var area: Rect2i = Rect2i()
		for c in (ch as Node2D).draw.get_connections():
			var args: Array = (c.callable as Callable).get_bound_arguments()
			if args.size() == 2 and args[1] is Rect2i: area = args[1]
		if area.size == Vector2i.ZERO:
			continue
		var vp := SubViewport.new()
		vp.size = area.size * TILE
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var painter := Node2D.new()
		painter.position = -Vector2(area.position * TILE)
		painter.draw.connect(_draw_chunk.bind(painter, area))
		vp.add_child(painter)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_instance_valid(ch):
			vp.queue_free()
			return
		var img := vp.get_texture().get_image()
		vp.queue_free()
		if img == null or img.is_empty():
			continue
		var spr := Sprite2D.new()
		spr.name = "ChaoAssado_%d_%d" % [area.position.x, area.position.y]
		spr.texture = ImageTexture.create_from_image(img)
		spr.centered = false
		spr.position = Vector2(area.position * TILE)
		var idx := (ch as Node).get_index()
		add_child(spr)
		move_child(spr, idx)
		_chunks[_chunks.find(ch)] = spr
		(ch as Node).queue_free()
