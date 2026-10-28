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
const ZONAS_ABERTAS := ["vila", "serra", "pedrabranca"]   # onde há flores, arbustos e pedras soltas

var world_view: WorldView
var puddles: Node2D
var _puddle_spots: Array = []
var _wet := -1.0
var _trails: Array = []          # Array[PackedVector2Array]
var _chunks: Array = []
static var _tex_cache: Dictionary = {}   # Rect2i -> ImageTexture (o mapa é estático: assa uma vez por sessão)
signal baked
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
				_ambiente_grama(ci, db, t, o)
				if _h(t, 7) % 9 == 0 and ZONAS_ABERTAS.has(db.zone_at(t)):
					var fc: Color = [Color(0.95, 0.9, 0.5), Color(0.9, 0.5, 0.6), Color(0.75, 0.7, 1.0), Color(1, 1, 1)][_h(t, 8) % 4]
					for k in 3:
						ci.draw_circle(o + Vector2(4 + (_h(t, 20 + k) % 24), 4 + (_h(t, 30 + k) % 24)), 1.2, fc)
				if _h(t, 15) % 11 == 0:
					ci.draw_circle(o + Vector2(_h(t, 16) % 30, _h(t, 17) % 30), 1.6, Color(0.6, 0.58, 0.52))
			elif ch == "~":
				_margem_da_agua(ci, db, t, o)
			elif ch == "c":
				_plantacao(ci, t, o)
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


## Grama com vida: tufos de lâminas, moitas, pedras, cogumelos e trevos, em densidade que varia pelo hash do tile
## (nada pisca). Nas zonas abertas (vila, serra, Pedra Branca); na mata de cima o chão já é coberto pela vegetação.
func _ambiente_grama(ci: CanvasItem, db: ContentDB, t: Vector2i, o: Vector2) -> void:
	if not ZONAS_ABERTAS.has(db.zone_at(t)):
		return
	var claro := Color(0.5, 0.74, 0.3)
	var escuro := Color(0.17, 0.34, 0.12)
	# tufos de lâminas (1 a 3 por tile em ~40% dos tiles)
	if _h(t, 101) % 5 < 2:
		for k in 1 + _h(t, 102) % 3:
			var b := o + Vector2(3 + _h(t, 103 + k) % 26, 8 + _h(t, 110 + k) % 22)
			for i in 4:
				var dx := float(i - 1) * 1.6
				ci.draw_line(b + Vector2(dx, 0), b + Vector2(dx * 1.8, -4.0 - float((i + k) % 3) * 1.4), escuro if i % 2 == 0 else claro, 1.0)
	# moita: arbusto redondo com sombra e luz (raro, só longe de portas)
	if _h(t, 120) % 41 == 0 and not _perto_de_porta(db, t):
		var c := o + Vector2(10 + _h(t, 121) % 12, 16 + _h(t, 122) % 10)
		ci.draw_circle(c + Vector2(1, 4), 8.0, Color(0, 0, 0, 0.22))
		ci.draw_circle(c, 7.0, Color(0.16, 0.36, 0.17))
		ci.draw_circle(c + Vector2(-2, -2), 5.0, Color(0.25, 0.5, 0.24))
		ci.draw_circle(c + Vector2(-3, -3), 2.0, Color(0.42, 0.68, 0.34))
		if _h(t, 123) % 3 == 0:
			for k in 3:
				ci.draw_circle(c + Vector2(_h(t, 124 + k) % 11 - 5, _h(t, 130 + k) % 9 - 4), 1.1, Color(0.9, 0.25, 0.3))
	# pedra solta com sombra
	elif _h(t, 140) % 37 == 0 and not _perto_de_porta(db, t):
		var c2 := o + Vector2(8 + _h(t, 141) % 16, 14 + _h(t, 142) % 12)
		ci.draw_circle(c2 + Vector2(1, 3), 5.0, Color(0, 0, 0, 0.25))
		ci.draw_circle(c2, 4.5, Color(0.5, 0.49, 0.46))
		ci.draw_circle(c2 + Vector2(-1, -1.5), 2.6, Color(0.66, 0.65, 0.6))
		ci.draw_circle(c2 + Vector2(4, 1), 2.5, Color(0.44, 0.43, 0.4))
	# cogumelos e trevos
	elif _h(t, 150) % 53 == 0:
		var c3 := o + Vector2(6 + _h(t, 151) % 20, 12 + _h(t, 152) % 16)
		ci.draw_line(c3, c3 + Vector2(0, 3), Color(0.9, 0.88, 0.8), 1.5)
		ci.draw_circle(c3, 2.4, Color(0.8, 0.2, 0.18))
		ci.draw_circle(c3 + Vector2(-0.8, -0.8), 0.7, Color(1, 1, 1))


## Lavoura: sulcos de terra revirada com plantas em fileira; trigo dourado em alguns trechos, verde em outros.
func _plantacao(ci: CanvasItem, t: Vector2i, o: Vector2) -> void:
	var trigo: bool = (t.x / 6 + t.y / 5) % 2 == 0
	for fila in 3:
		var y := o.y + 5.0 + fila * 10.0
		ci.draw_line(Vector2(o.x, y + 3), Vector2(o.x + 32, y + 3), Color(0.3, 0.2, 0.12, 0.55), 2.0)   # sulco
		for k in 5:
			var x := o.x + 3.0 + k * 6.5 + float(_h(t, 230 + fila * 5 + k) % 3)
			var topo := 7.0 + float(_h(t, 240 + fila * 5 + k) % 4)
			if trigo:
				ci.draw_line(Vector2(x, y + 3), Vector2(x + 0.5, y - topo + 3), Color(0.72, 0.6, 0.22), 1.0)
				ci.draw_circle(Vector2(x + 0.5, y - topo + 2), 1.4, Color(0.9, 0.78, 0.3))
			else:
				ci.draw_line(Vector2(x, y + 3), Vector2(x - 1.5, y - topo * 0.6 + 3), Color(0.3, 0.55, 0.22), 1.2)
				ci.draw_line(Vector2(x, y + 3), Vector2(x + 1.8, y - topo * 0.7 + 3), Color(0.38, 0.65, 0.26), 1.2)


func _perto_de_porta(db: ContentDB, t: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if db.tile_char(t + Vector2i(dx, dy)) == "D":
				return true
	return false


## Margem da água: lama e areia onde o rio ou o lago encosta na terra, espuma na beirada e juncos.
func _margem_da_agua(ci: CanvasItem, db: ContentDB, t: Vector2i, o: Vector2) -> void:
	for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = t + off
		var nc := db.tile_char(n)
		if nc == "~" or nc == "p" or nc == "X":
			continue
		var borda := o + Vector2(16, 16) + Vector2(off) * 14.0
		var ao_longo := Vector2(off.y, off.x).abs()
		for k in 5:
			var p := borda + ao_longo * float(k * 7 - 14 + _h(t, 160 + k) % 4)
			ci.draw_circle(p, 5.0 + float(_h(t, 170 + k) % 3), Color(0.62, 0.54, 0.38, 0.45))   # lama/areia molhada
		for k in 4:
			var q := borda - Vector2(off) * 4.0 + ao_longo * float(k * 9 - 13 + _h(t, 180 + k) % 3)
			ci.draw_circle(q, 1.6, Color(0.92, 0.97, 1.0, 0.55))   # espuma
		if _h(t, 190 + off.x + off.y * 2) % 4 == 0 and ZONAS_ABERTAS.has(db.zone_at(t)):   # juncos
			var j := borda + ao_longo * float(_h(t, 191) % 20 - 10)
			for i in 3:
				ci.draw_line(j + Vector2(i * 2.0, 0), j + Vector2(i * 2.0 + 1, -9.0 - i * 1.5), Color(0.3, 0.46, 0.2), 1.0)
				ci.draw_circle(j + Vector2(i * 2.0 + 1, -9.0 - i * 1.5), 1.3, Color(0.42, 0.28, 0.16))


## Adereços encostados nas paredes de fora: barris, caixotes, lenha, feno e canteiros de flores. Só enfeite (sem colisão),
## em tiles de grama colados à parede e longe das portas.
func _adercos_das_casas(ci: CanvasItem, db: ContentDB) -> void:
	for loc in db.map.locations:
		if not loc.get("indoor", false) or str(loc.get("zone", "")) == "cripta":
			continue
		var r: Array = loc.rect
		var x0 := int(r[0]) - 2
		var y0 := int(r[1]) - 2
		var x1 := int(r[0]) + int(r[2]) + 1
		var y1 := int(r[1]) + int(r[3]) + 1
		var anel: Array = []
		for x in range(x0, x1 + 1):
			anel.append(Vector2i(x, y0)); anel.append(Vector2i(x, y1))
		for y in range(y0 + 1, y1):
			anel.append(Vector2i(x0, y)); anel.append(Vector2i(x1, y))
		var feitos := 0
		for t in anel:
			if feitos >= 4 or _h(t, 200) % 4 != 0 or db.tile_char(t) != "." or _perto_de_porta(db, t):
				continue
			feitos += 1
			var o := Vector2(t) * TILE
			# o adereço fica no canto do tile voltado para a parede
			var para_dentro := Vector2(signi(int(r[0]) + int(r[2]) / 2 - t.x) if t.x < x0 + 1 or t.x > x1 - 1 else 0, signi(int(r[1]) + int(r[3]) / 2 - t.y) if t.y < y0 + 1 or t.y > y1 - 1 else 0)
			var c := o + Vector2(16, 16) + para_dentro * 8.0
			match _h(t, 201) % 5:
				0:   # barril
					ci.draw_circle(c + Vector2(1, 6), 8.0, Color(0, 0, 0, 0.25))
					ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 14)), Color(0.45, 0.3, 0.16))
					ci.draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 2)), Color(0.28, 0.2, 0.12))
					ci.draw_rect(Rect2(c + Vector2(-6, 2), Vector2(12, 2)), Color(0.28, 0.2, 0.12))
					ci.draw_rect(Rect2(c + Vector2(-5, -8), Vector2(10, 3)), Color(0.62, 0.45, 0.26))
				1:   # caixotes empilhados
					ci.draw_rect(Rect2(c + Vector2(-9, 0), Vector2(18, 10)), Color(0, 0, 0, 0.22))
					ci.draw_rect(Rect2(c + Vector2(-8, -2), Vector2(11, 10)), Color(0.58, 0.42, 0.24))
					ci.draw_rect(Rect2(c + Vector2(-8, -2), Vector2(11, 10)), Color(0.3, 0.21, 0.12), false, 1.0)
					ci.draw_rect(Rect2(c + Vector2(1, -9), Vector2(9, 9)), Color(0.66, 0.5, 0.3))
					ci.draw_rect(Rect2(c + Vector2(1, -9), Vector2(9, 9)), Color(0.3, 0.21, 0.12), false, 1.0)
					ci.draw_line(c + Vector2(1, -9), c + Vector2(10, 0), Color(0.3, 0.21, 0.12), 1.0)
				2:   # pilha de lenha
					for i in 3:
						for j in 3 - i:
							var cx := c + Vector2(-8 + i * 4 + j * 8, 6 - i * 6)
							ci.draw_circle(cx, 3.6, Color(0.42, 0.28, 0.16))
							ci.draw_circle(cx, 2.0, Color(0.74, 0.58, 0.36))
				3:   # fardo de feno
					ci.draw_rect(Rect2(c + Vector2(-9, -5), Vector2(18, 12)), Color(0.78, 0.65, 0.28))
					ci.draw_rect(Rect2(c + Vector2(-9, -5), Vector2(18, 12)), Color(0.5, 0.4, 0.15), false, 1.0)
					ci.draw_line(c + Vector2(-3, -5), c + Vector2(-3, 7), Color(0.5, 0.4, 0.15), 1.0)
					ci.draw_line(c + Vector2(3, -5), c + Vector2(3, 7), Color(0.5, 0.4, 0.15), 1.0)
				_:   # canteiro de flores
					ci.draw_rect(Rect2(c + Vector2(-10, -3), Vector2(20, 8)), Color(0.34, 0.24, 0.15))
					for k in 6:
						var fc: Color = [Color(0.95, 0.4, 0.45), Color(0.98, 0.85, 0.35), Color(0.85, 0.6, 0.95), Color(1, 1, 1)][(_h(t, 210 + k)) % 4]
						ci.draw_circle(c + Vector2(-8 + k * 3.2, -2 + float(k % 2) * 3.0), 1.9, fc)
						ci.draw_circle(c + Vector2(-8 + k * 3.2, -2 + float(k % 2) * 3.0), 0.7, Color(0.95, 0.8, 0.2))


## Cerca de madeira em volta das lavouras (enfeite; o acesso a pé continua o do mapa).
func _cercas_dos_campos(ci: CanvasItem, db: ContentDB) -> void:
	for loc in db.map.locations:
		if not str(loc.id).begins_with("campos"):
			continue
		var r: Array = loc.rect
		var a := Vector2(int(r[0]), int(r[1])) * TILE - Vector2(4, 6)
		var b := Vector2(int(r[0]) + int(r[2]), int(r[1]) + int(r[3])) * TILE + Vector2(4, 2)
		var pontos := [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y), a]
		for i in 4:
			var p0: Vector2 = pontos[i]
			var p1: Vector2 = pontos[i + 1]
			var len := p0.distance_to(p1)
			var dir := (p1 - p0) / len
			var n := int(len / 20.0)
			for k in n + 1:
				var q := p0 + dir * (len * float(k) / float(maxi(n, 1)))
				if i == 3 and k > n / 3 and k < n / 3 * 2:
					continue   # portão: vão na cerca de baixo
				ci.draw_rect(Rect2(q + Vector2(-1.5, -7), Vector2(3, 9)), Color(0.4, 0.28, 0.16))
				ci.draw_rect(Rect2(q + Vector2(-1.5, -7), Vector2(3, 2)), Color(0.62, 0.46, 0.28))
			for h in [-5.0, -1.0]:
				if i == 3:
					ci.draw_line(p0 + Vector2(0, h), p0 + dir * len / 3.0 + Vector2(0, h), Color(0.5, 0.36, 0.2), 1.5)
					ci.draw_line(p0 + dir * len * 2.0 / 3.0 + Vector2(0, h), p1 + Vector2(0, h), Color(0.5, 0.36, 0.2), 1.5)
				else:
					ci.draw_line(p0 + Vector2(0, h), p1 + Vector2(0, h), Color(0.5, 0.36, 0.2), 1.5)


func _draw_extras(ci: CanvasItem) -> void:
	var db: ContentDB = Game.db
	_adercos_das_casas(ci, db)
	_cercas_dos_campos(ci, db)
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
	# 5) esculturas (objetos com "escultura": estátua de pedra num pedestal)
	for o in db.all_objects():
		if bool(o.get("escultura", false)):
			_estatua(ci, Vector2(int(o.tile[0]), int(o.tile[1])) * TILE + Vector2(16, 16))


func _estatua(ci: CanvasItem, c: Vector2) -> void:
	var pedra := Color(0.62, 0.62, 0.66)
	var sombra := Color(0.38, 0.38, 0.42)
	ci.draw_rect(Rect2(c + Vector2(-11, 6), Vector2(22, 8)), sombra)
	ci.draw_rect(Rect2(c + Vector2(-9, 4), Vector2(18, 6)), pedra)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(6, 4), c + Vector2(4, -8), c + Vector2(-4, -8)]), pedra)
	ci.draw_circle(c + Vector2(0, -11), 4.0, pedra)
	ci.draw_line(c + Vector2(-4, -6), c + Vector2(-8, -12), sombra, 2.0)


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
		baked.emit()
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
		if _tex_cache.has(area):
			_swap_chunk(ch, area, _tex_cache[area])
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
		_tex_cache[area] = ImageTexture.create_from_image(img)
		_swap_chunk(ch, area, _tex_cache[area])
	baked.emit()


func _swap_chunk(ch: Node, area: Rect2i, tex: Texture2D) -> void:
	var spr := Sprite2D.new()
	spr.name = "ChaoAssado_%d_%d" % [area.position.x, area.position.y]
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(area.position * TILE)
	var idx := ch.get_index()
	add_child(spr)
	move_child(spr, idx)
	_chunks[_chunks.find(ch)] = spr
	ch.queue_free()
