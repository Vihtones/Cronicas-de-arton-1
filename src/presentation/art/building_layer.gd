class_name BuildingLayer
extends Node2D
## Casas com volume (apresentação, PROVISÓRIO procedural até haver arte aprovada pelo governador):
## telhado de quatro águas por cima dos atores, fachada em enxaimel com janelas que acendem à noite,
## placas de ofício, chaminé com fumaça levada pelo vento e as pás do moinho girando.
## O telhado some quando o jogador entra (como em Stoneshard: o interior aparece ao cruzar a porta).
## Nada aqui muda colisão nem regras: o mapa continua o mesmo; só o desenho ganha volume.
## Referências: Stoneshard (telhados que se abrem ao entrar), Graveyard Keeper (paleta terrosa, enxaimel).

const TILE := 32
const STYLES := {
	"taverna": {"roof": "telha", "sign": "caneca", "chimney": true, "wall": Color(0.86, 0.78, 0.62)},
	"templo": {"roof": "ardosia", "sign": "", "tower": true, "wall": Color(0.88, 0.86, 0.8)},
	"casa_brandt": {"roof": "palha", "chimney": true, "wall": Color(0.84, 0.76, 0.6)},
	"quartel": {"roof": "ardosia", "sign": "escudo", "wall": Color(0.7, 0.68, 0.64), "banner": Color(0.55, 0.12, 0.1)},
	"casa_ferro": {"roof": "telha", "chimney": true, "wall": Color(0.82, 0.74, 0.6)},
	"casa_vasquel": {"roof": "palha", "chimney": true, "wall": Color(0.85, 0.8, 0.66)},
	"ferraria": {"roof": "ardosia", "sign": "bigorna", "chimney": true, "forge": true, "wall": Color(0.66, 0.6, 0.54)},
	"prefeitura": {"roof": "telha", "sign": "pergaminho", "wall": Color(0.88, 0.82, 0.68), "banner": Color(0.2, 0.3, 0.6)},
	"casa_aldren": {"roof": "palha", "chimney": true, "wall": Color(0.83, 0.75, 0.6)},
	"moinho": {"roof": "palha", "sign": "trigo", "mill": true, "wall": Color(0.86, 0.8, 0.66)},
	"casa_corvo": {"roof": "telha", "chimney": true, "wall": Color(0.78, 0.72, 0.62)},
	"cabana_quill": {"roof": "palha", "chimney": true, "mossy": true, "wall": Color(0.62, 0.5, 0.36)},
}
const ROOF_COLORS := {
	"telha": [Color(0.56, 0.24, 0.17), Color(0.7, 0.33, 0.22), Color(0.63, 0.29, 0.2)],
	"ardosia": [Color(0.24, 0.27, 0.32), Color(0.36, 0.4, 0.46), Color(0.3, 0.33, 0.39)],
	"palha": [Color(0.52, 0.41, 0.22), Color(0.72, 0.58, 0.32), Color(0.62, 0.5, 0.27)],
}

var buildings: Array = []       # {id, rect: Rect2i, door: Vector2i, door_top: bool, style, alpha}
var facade: Node2D              # camada do chão (fica sob os atores)
var fx: FxLayer
var _mill_angle := 0.0
var _smokes: Array = []
var _last_night := -1.0
var _mills: Array = []


func _init() -> void:
	z_index = 3   # acima dos atores (telhado cobre quem está dentro)
	facade = Node2D.new()
	facade.name = "Fachadas"


## Prédios = locais internos fora da cripta cujo contorno de paredes confere com o mapa.
static func plan(db: ContentDB) -> Array:
	var out: Array = []
	var doors := {}
	for o in db.all_objects():
		if o.type == "door":
			doors[o.id] = Vector2i(int(o.tile[0]), int(o.tile[1]))
	for loc in db.map.locations:
		if not loc.get("indoor", false) or str(loc.get("zone", "")) == "cripta":
			continue
		var r: Array = loc.rect
		var rect := Rect2i(int(r[0]) - 1, int(r[1]) - 1, int(r[2]) + 2, int(r[3]) + 2)
		if db.tile_char(rect.position) != "#":
			continue
		var door := Vector2i(-1, -1)
		for did in doors:
			var t: Vector2i = doors[did]
			if rect.has_point(t) and (t.y == rect.position.y or t.y == rect.end.y - 1 or t.x == rect.position.x or t.x == rect.end.x - 1):
				door = t
		out.append({"id": loc.id, "rect": rect, "door": door, "door_top": door.y == rect.position.y,
			"style": STYLES.get(loc.id, {"roof": "palha", "wall": Color(0.84, 0.76, 0.6)}), "alpha": 1.0})
	return out


func build(db: ContentDB) -> void:
	for c in get_children():
		c.queue_free()
	_smokes.clear()
	_mills.clear()
	buildings = plan(db)
	for c in facade.get_children():
		c.queue_free()
	# um item de desenho por prédio (telhado) e por fachada: só redesenha o que mudou, e cada um
	# fica bem abaixo do limite de comandos do renderizador de compatibilidade
	for b in buildings:
		var rn := Node2D.new()
		rn.name = "Telhado_" + str(b.id)
		rn.add_to_group("telhados")
		rn.draw.connect(_draw_roof_on.bind(rn, b))
		add_child(rn)
		b["node"] = rn
		var fn := Node2D.new()
		fn.name = "Fachada_" + str(b.id)
		fn.draw.connect(_draw_facade_on.bind(fn, b))
		facade.add_child(fn)
		b["fnode"] = fn
		if b.style.get("mill", false):
			var mn := Node2D.new()
			mn.z_index = 1
			mn.draw.connect(_draw_mill_on.bind(mn, b))
			add_child(mn)
			b["mnode"] = mn
	for b in buildings:
		var st: Dictionary = b.style
		if st.get("chimney", false):
			_add_smoke(b, st.get("forge", false))
		if st.get("mill", false):
			_mills.append(b)
	for b in buildings:
		(b.node as CanvasItem).queue_redraw()
		(b.fnode as CanvasItem).queue_redraw()


func _roof_rect(b: Dictionary) -> Rect2:
	var r: Rect2i = b.rect
	var y0 := float(r.position.y + (1 if b.door_top else 0)) * TILE - 10.0
	var y1 := float(r.end.y - 1) * TILE + 4.0
	return Rect2(Vector2(r.position.x * TILE - 3.0, y0), Vector2(r.size.x * TILE + 6.0, y1 - y0))


func _chimney_pos(b: Dictionary) -> Vector2:
	var rr := _roof_rect(b)
	return Vector2(rr.end.x - minf(30.0, rr.size.x * 0.25), rr.position.y + rr.size.y * 0.22)


func _add_smoke(b: Dictionary, heavy: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = _chimney_pos(b) + Vector2(0, -10)
	p.amount = 18 if heavy else 10
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.direction = Vector2(0.3, -1)
	p.spread = 12.0
	p.gravity = Vector2(6, -6)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 4.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4)); curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	var base := Color(0.32, 0.3, 0.3) if heavy else Color(0.62, 0.6, 0.58)
	g.set_color(0, Color(base, 0.55))
	g.set_color(1, Color(base.lightened(0.2), 0.0))
	p.color_ramp = g
	p.z_index = 1
	add_child(p)
	_smokes.append(p)


func _process(delta: float) -> void:
	if Game.world == null:
		return
	var pt := Game.player_tile()
	var changed := false
	for b in buildings:
		var r: Rect2i = b.rect
		var inside: bool = r.grow(-1).has_point(pt) or (r.has_point(pt) and pt == b.door)
		var target := 0.12 if inside else 1.0
		var a := move_toward(float(b.alpha), target, delta * 4.0)
		if a != b.alpha:
			b.alpha = a
			(b.node as CanvasItem).queue_redraw()
	# vento leva a fumaça (direção vem do domínio do clima)
	var w: WeatherModule = Game.world.modules.weather
	var wind := float(w.region.get("wind", 0.2))
	var wdir := deg_to_rad(float(w.region.get("wind_dir", 200.0)))
	for s in _smokes:
		(s as CPUParticles2D).gravity = Vector2(cos(wdir), 0.0) * (10.0 + wind * 40.0) + Vector2(0, -6)
	if not _mills.is_empty():
		_mill_angle += delta * (0.6 + wind * 1.8)
		for m in _mills:
			if m.has("mnode"): (m.mnode as CanvasItem).queue_redraw()
	var n := fx.night if fx else 0.0
	if absf(n - _last_night) > 0.04:
		_last_night = n
		for b in buildings:
			if b.has("fnode"): (b.fnode as CanvasItem).queue_redraw()


# --- Telhados -------------------------------------------------------------------------------------
var _ci: CanvasItem   # item onde as rotinas de desenho escrevem agora


func _draw_roof_on(ci: CanvasItem, b: Dictionary) -> void:
	_ci = ci
	_draw_roof(b)


func _draw_mill_on(ci: CanvasItem, b: Dictionary) -> void:
	_ci = ci
	var rr := _roof_rect(b)
	_draw_mill(Vector2(rr.get_center().x, rr.position.y + rr.size.y * 0.42 - 2), float(b.alpha))


func _draw_facade_on(ci: CanvasItem, b: Dictionary) -> void:
	_ci = ci
	var r: Rect2i = b.rect
	var night := fx.night if fx else 0.0
	_facade_row(b, r.end.y - 1, night)
	if b.door_top:
		_facade_row(b, r.position.y, night)
	_sign(b)


func _draw_roof(b: Dictionary) -> void:
	var a := float(b.alpha)
	if a <= 0.01:
		return
	var st: Dictionary = b.style
	var kind: String = st.get("roof", "palha")
	var cols: Array = ROOF_COLORS[kind]
	var rr := _roof_rect(b)
	var x0 := rr.position.x
	var x1 := rr.end.x
	var y0 := rr.position.y
	var y1 := rr.end.y
	var ym := y0 + rr.size.y * 0.42
	var inset := minf(rr.size.y * 0.45, rr.size.x * 0.35)
	var north := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - inset, ym), Vector2(x0 + inset, ym)])
	var south := PackedVector2Array([Vector2(x0 + inset, ym), Vector2(x1 - inset, ym), Vector2(x1, y1), Vector2(x0, y1)])
	var west := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + inset, ym), Vector2(x0, y1)])
	var east := PackedVector2Array([Vector2(x1, y0), Vector2(x1, y1), Vector2(x1 - inset, ym)])
	# sombra projetada do beiral sobre a fachada e o chão
	_ci.draw_rect(Rect2(Vector2(x0 + 2, y1), Vector2(rr.size.x - 4, 6)), Color(0, 0, 0, 0.32 * a))
	_ci.draw_colored_polygon(north, Color(cols[0], a))
	_ci.draw_colored_polygon(south, Color(cols[1], a))
	_ci.draw_colored_polygon(west, Color(cols[2], a))
	_ci.draw_colored_polygon(east, Color((cols[2] as Color).darkened(0.12), a))
	var seed := absi(hash(b.id))
	# textura: fiadas de telha/ardósia, ou palha em feixes
	var step := 5.0 if kind != "palha" else 4.0
	var y := ym + step
	var row := 0
	while y < y1 - 1:
		var t := (y - ym) / maxf(1.0, y1 - ym)
		var lx := lerpf(x0 + inset, x0, t)
		var rx := lerpf(x1 - inset, x1, t)
		_course(kind, lx, rx, y, row, Color((cols[1] as Color).darkened(0.22), a), seed)
		y += step; row += 1
	y = y0 + step
	row = 0
	while y < ym - 1:
		var t2 := (y - y0) / maxf(1.0, ym - y0)
		var lx2 := lerpf(x0, x0 + inset, t2)
		var rx2 := lerpf(x1, x1 - inset, t2)
		_course(kind, lx2, rx2, y, row, Color((cols[0] as Color).darkened(0.25), a), seed + 7)
		y += step; row += 1
	# cumeeira e espigões
	var ridge := Color((cols[1] as Color).lightened(0.18), a)
	_ci.draw_line(Vector2(x0 + inset, ym), Vector2(x1 - inset, ym), ridge, 2.0)
	_ci.draw_line(Vector2(x0, y0), Vector2(x0 + inset, ym), Color(ridge, a * 0.7), 1.0)
	_ci.draw_line(Vector2(x1, y0), Vector2(x1 - inset, ym), Color(ridge, a * 0.7), 1.0)
	_ci.draw_line(Vector2(x0, y1), Vector2(x0 + inset, ym), Color(ridge, a * 0.7), 1.0)
	_ci.draw_line(Vector2(x1, y1), Vector2(x1 - inset, ym), Color(ridge, a * 0.7), 1.0)
	# beiral (borda clara de baixo) e contorno
	_ci.draw_line(Vector2(x0, y1), Vector2(x1, y1), Color((cols[1] as Color).darkened(0.45), a), 2.0)
	_ci.draw_polyline(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1), Vector2(x0, y0)]), Color(0.08, 0.06, 0.05, 0.6 * a), 1.0)
	# musgo e desgaste
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var moss := 10 if st.get("mossy", false) else 3
	for i in moss:
		var p := Vector2(rng.randf_range(x0 + 6, x1 - 6), rng.randf_range(ym + 3, y1 - 3))
		_ci.draw_circle(p, rng.randf_range(2.0, 4.5), Color(0.28, 0.36, 0.18, 0.45 * a))
	if st.get("chimney", false):
		var c := _chimney_pos(b)
		_ci.draw_rect(Rect2(c + Vector2(-5, -10), Vector2(10, 14)), Color(0.42, 0.36, 0.33, a))
		_ci.draw_rect(Rect2(c + Vector2(-6, -12), Vector2(12, 3)), Color(0.3, 0.26, 0.24, a))
		_ci.draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 2)), Color(0.06, 0.05, 0.05, a))
		_ci.draw_rect(Rect2(c + Vector2(-5, 3), Vector2(10, 2)), Color(0, 0, 0, 0.25 * a))
	if st.get("tower", false):
		_draw_tower(Vector2((x0 + x1) / 2.0, ym), a)
	if st.has("banner"):
		var bp := Vector2(x0 + 10, y0 + 2)
		_ci.draw_line(bp, bp + Vector2(0, -22), Color(0.3, 0.22, 0.14, a), 2.0)
		var wave := sin(Time.get_ticks_msec() / 300.0) * 2.0
		_ci.draw_colored_polygon(PackedVector2Array([bp + Vector2(1, -22), bp + Vector2(15, -20 + wave), bp + Vector2(1, -13)]), Color(st.banner, a))


func _course(kind: String, lx: float, rx: float, y: float, row: int, col: Color, seed: int) -> void:
	match kind:
		"palha":
			var x := lx + 1.0
			var i := 0
			while x < rx - 1:
				var h := 2.0 + float((seed + i * 13 + row * 7) % 3)
				_ci.draw_line(Vector2(x, y - h), Vector2(x + 1.0, y), col, 1.0)
				x += 3.0 + float((seed + i) % 2)
				i += 1
		"telha":
			_ci.draw_line(Vector2(lx, y), Vector2(rx, y), col, 1.0)
			var x2 := lx + (3.0 if row % 2 == 0 else 0.0)
			while x2 < rx - 3:
				_ci.draw_arc(Vector2(x2 + 3.0, y - 1.0), 3.0, 0.0, PI, 4, col, 1.0)
				x2 += 6.0
		_:
			_ci.draw_line(Vector2(lx, y), Vector2(rx, y), col, 1.0)
			var x3 := lx + (4.0 if row % 2 == 0 else 0.0)
			while x3 < rx - 2:
				_ci.draw_line(Vector2(x3, y - 4.0), Vector2(x3, y), col, 1.0)
				x3 += 8.0


func _draw_tower(c: Vector2, a: float) -> void:
	var stone := Color(0.74, 0.72, 0.68, a)
	_ci.draw_rect(Rect2(c + Vector2(-9, -26), Vector2(18, 26)), stone)
	_ci.draw_rect(Rect2(c + Vector2(-9, -26), Vector2(18, 26)), Color(0.2, 0.18, 0.18, 0.6 * a), false, 1.0)
	_ci.draw_rect(Rect2(c + Vector2(-4, -21), Vector2(8, 9)), Color(0.1, 0.09, 0.1, a))   # abertura do sino
	_ci.draw_circle(c + Vector2(0, -14), 2.5, Color(0.75, 0.6, 0.25, a))
	_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -26), c + Vector2(11, -26), c + Vector2(0, -42)]), Color(0.3, 0.33, 0.39, a))
	_ci.draw_line(c + Vector2(0, -42), c + Vector2(0, -48), Color(0.8, 0.7, 0.35, a), 1.0)
	_ci.draw_circle(c + Vector2(0, -49), 1.5, Color(0.9, 0.78, 0.4, a))


func _draw_mill(c: Vector2, a: float) -> void:
	var wood := Color(0.42, 0.3, 0.18, a)
	var cloth := Color(0.9, 0.86, 0.76, a * 0.95)
	for i in 4:
		var ang := _mill_angle + i * PI / 2.0
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x)
		var tip := c + d * 44.0
		_ci.draw_line(c, tip, wood, 2.0)
		_ci.draw_colored_polygon(PackedVector2Array([c + d * 12.0, tip, tip + n * 9.0, c + d * 12.0 + n * 9.0]), cloth)
		_ci.draw_line(c + d * 12.0 + n * 9.0, tip + n * 9.0, wood, 1.0)
	_ci.draw_circle(c, 4.0, Color(0.25, 0.18, 0.12, a))


# --- Fachadas (camada do chão) -----------------------------------------------------------------


func _facade_row(b: Dictionary, ty: int, night: float) -> void:
	var r: Rect2i = b.rect
	var st: Dictionary = b.style
	var wall: Color = st.get("wall", Color(0.84, 0.76, 0.6))
	var beam := Color(0.3, 0.2, 0.13)
	var y := float(ty * TILE)
	for tx in range(r.position.x, r.end.x):
		var t := Vector2i(tx, ty)
		var x := float(tx * TILE)
		if t == b.door:
			# lintel e soleira; porta de cima ganha um alpendre
			draw_rect_on(Rect2(x - 2, y - 1, 36, 4), beam)
			if b.door_top:
				_ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y + 3), Vector2(x + 36, y + 3), Vector2(x + 32, y - 7), Vector2(x, y - 7)]), (ROOF_COLORS[st.get("roof", "palha")][1] as Color))
			continue
		var plinth := 8.0
		draw_rect_on(Rect2(x, y, TILE, TILE - plinth), wall)
		# pedras do embasamento
		draw_rect_on(Rect2(x, y + TILE - plinth, TILE, plinth), Color(0.45, 0.43, 0.41))
		for k in 3:
			draw_rect_on(Rect2(x + 1 + k * 11 + (ty % 2) * 3, y + TILE - plinth + 1, 9, 3), Color(0.55, 0.53, 0.5))
			draw_rect_on(Rect2(x + 5 + k * 11, y + TILE - 4, 9, 3), Color(0.52, 0.5, 0.47))
		# enxaimel
		draw_rect_on(Rect2(x, y, TILE, 3), beam)
		draw_rect_on(Rect2(x, y, 3, TILE - plinth), beam)
		var local := tx - r.position.x
		var near_door: bool = absi(tx - b.door.x) <= 0 and ty == b.door.y
		if local % 2 == 1 and tx != r.end.x - 1 and not near_door:
			# janela com venezianas; à noite acende
			var glass := Color(0.32, 0.4, 0.46).lerp(Color(1.0, 0.78, 0.42), smoothstep(0.35, 0.75, night))
			draw_rect_on(Rect2(x + 9, y + 7, 14, 12), Color(0.18, 0.12, 0.08))
			draw_rect_on(Rect2(x + 10, y + 8, 12, 10), glass)
			draw_rect_on(Rect2(x + 15, y + 8, 2, 10), Color(0.18, 0.12, 0.08))
			draw_rect_on(Rect2(x + 5, y + 7, 4, 12), Color(0.36, 0.26, 0.16))
			draw_rect_on(Rect2(x + 23, y + 7, 4, 12), Color(0.36, 0.26, 0.16))
			draw_rect_on(Rect2(x + 8, y + 19, 16, 2), Color(0.3, 0.22, 0.14))
			if absi(hash(Vector2i(tx, ty))) % 3 == 0:
				for f in 3:   # floreira
					_ci.draw_circle(Vector2(x + 11 + f * 5, y + 20), 1.8, [Color(0.85, 0.3, 0.3), Color(0.95, 0.8, 0.3), Color(0.7, 0.4, 0.8)][f])
		elif local % 2 == 0:
			_ci.draw_line(Vector2(x + 3, y + TILE - plinth), Vector2(x + TILE, y + 3), beam, 2.0)


func draw_rect_on(rc: Rect2, c: Color) -> void:
	_ci.draw_rect(rc, c)


func _sign(b: Dictionary) -> void:
	var icon := str(b.style.get("sign", ""))
	if icon == "" or b.door.x < 0:
		return
	var p := Vector2(b.door.x * TILE + TILE + 4, b.door.y * TILE + (TILE + 6 if not b.door_top else 4))
	if b.door_top:
		p.y = b.door.y * TILE - 2
	var wood := Color(0.35, 0.24, 0.14)
	_ci.draw_line(p + Vector2(0, -8), p + Vector2(12, -8), Color(0.15, 0.12, 0.1), 2.0)
	_ci.draw_line(p + Vector2(3, -8), p + Vector2(3, -5), Color(0.15, 0.12, 0.1), 1.0)
	_ci.draw_line(p + Vector2(11, -8), p + Vector2(11, -5), Color(0.15, 0.12, 0.1), 1.0)
	_ci.draw_rect(Rect2(p + Vector2(0, -5), Vector2(14, 11)), wood)
	_ci.draw_rect(Rect2(p + Vector2(0, -5), Vector2(14, 11)), Color(0.75, 0.6, 0.3), false, 1.0)
	var c := p + Vector2(7, 0.5)
	var ink := Color(0.95, 0.85, 0.55)
	match icon:
		"caneca":
			_ci.draw_rect(Rect2(c + Vector2(-3, -3), Vector2(5, 6)), ink)
			_ci.draw_arc(c + Vector2(3, 0), 2.0, -PI / 2, PI / 2, 5, ink, 1.0)
		"bigorna":
			_ci.draw_rect(Rect2(c + Vector2(-4, -2), Vector2(8, 2)), ink)
			_ci.draw_rect(Rect2(c + Vector2(-1, 0), Vector2(3, 3)), ink)
		"escudo":
			_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)]), ink)
		"pergaminho":
			_ci.draw_rect(Rect2(c + Vector2(-3, -3), Vector2(6, 6)), ink)
			_ci.draw_line(c + Vector2(-2, -1), c + Vector2(2, -1), wood, 1.0)
			_ci.draw_line(c + Vector2(-2, 1), c + Vector2(2, 1), wood, 1.0)
		"trigo":
			_ci.draw_line(c + Vector2(0, 4), c + Vector2(0, -3), ink, 1.0)
			for k in 3:
				_ci.draw_circle(c + Vector2(-1.5, -2 + k * 2), 1.0, ink)
				_ci.draw_circle(c + Vector2(1.5, -2 + k * 2), 1.0, ink)
