class_name AmbientLife
extends Node2D
## Figurantes da vila (L0, só apresentação): gente andando, correndo da chuva, trabalhando, conversando,
## vendendo, crianças brincando de pega-pega, carroças na estrada; barracas no dia de feira; bandeirolas,
## lanternas, fogueira, música e dança na festa. NÃO são NPCs do domínio: não têm memória, não
## testemunham crimes, não podem ser alvo de diálogo. Quantidade e humor vêm do domínio (hora, clima,
## eventos da vila) e mudam sozinhos enquanto o jogador explora.
## Referências: densidade e "gente ocupada" de Stoneshard (Osbrook), rotinas de Graveyard Keeper.

const TILE := 32
const SHEETS := ["aldeao", "artesao", "idoso", "aldeao", "artesao"]
const TINTS := [Color(1, 1, 1), Color(0.92, 0.85, 0.8), Color(0.85, 0.92, 1.0), Color(1.0, 0.95, 0.82), Color(0.9, 1.0, 0.9), Color(0.95, 0.85, 0.95)]

var world_view: WorldView
var fx: FxLayer
var agents: Array = []          # {view, kind, state, t, speed, bubble_t, target, group, phase}
var carts: Array = []
var decor: Node2D
var _pois: Dictionary = {}      # categoria -> Array[Vector2i]
var _rng := RandomNumberGenerator.new()
var _spawn_t := 0.0
var _cart_t := 6.0
var _last_events := ""
var _fire: CPUParticles2D
var _lanterns: Array = []
var _music_t := 0.0
var _instant := false            # prefill: já nasce no meio da rua, sem surgir da porta


func _ready() -> void:
	y_sort_enabled = true
	_rng.seed = 4242
	decor = Node2D.new()
	decor.name = "Decoracao"
	decor.y_sort_enabled = true
	add_child(decor)


func rebuild() -> void:
	for a in agents: (a.view as Node).queue_free()
	for c in carts: (c.node as Node).queue_free()
	agents.clear(); carts.clear()
	_last_events = "?"
	_pois = compute_pois(Game.db)


## Pontos de interesse da vila (puros, testáveis): portas (lado de fora), saídas da estrada, praça,
## mercado, campos.
static func compute_pois(db: ContentDB) -> Dictionary:
	var out := {"portas": [], "saidas": [], "praca": [], "mercado": [], "campos": [], "rua": []}
	for o in db.all_objects():
		if o.type != "door": continue
		var d := Vector2i(int(o.tile[0]), int(o.tile[1]))
		if db.zone_at(d) != "vila": continue
		for off in [Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = d + off
			if db.static_walkable(n) and not bool(db.location(db.location_at(n)).get("indoor", false)):
				out.portas.append(n); break
	for y in range(24, 28):
		for x in [1, 46]:
			var t := Vector2i(x, y)
			if db.static_walkable(t): out.saidas.append(t)
	for k in ["praca", "mercado", "campos"]:
		var r: Array = db.location(k).get("rect", [0, 0, 0, 0])
		for y in range(int(r[1]), int(r[1]) + int(r[3])):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				var t2 := Vector2i(x, y)
				if db.static_walkable(t2) and db.tile_char(t2) != "o":
					out[k].append(t2)
	for y in db.size.y:
		for x in 46:
			var t3 := Vector2i(x, y)
			if db.tile_char(t3) in ["=", ":"] and db.zone_at(t3) == "vila":
				out.rua.append(t3)
	return out


## Quantas pessoas devem estar na rua agora (puro, testável).
static func target_count(hour: int, condition: String, events: Array) -> int:
	var base: int = [0, 0, 0, 0, 0, 1, 3, 6, 8, 9, 9, 10, 10, 9, 9, 9, 8, 8, 7, 5, 4, 3, 2, 1][clampi(hour, 0, 23)]
	var mult: float = {"chuva": 0.4, "tempestade": 0.12, "neblina": 0.7}.get(condition, 1.0)
	var n := int(round(base * mult))
	if events.has("feira"): n += 8 if condition != "tempestade" else 2
	if events.has("festa"): n += 14
	return n


func _in_vila() -> bool:
	return Game.db.zone_at(Game.player_tile()) in ["vila", "estrada"] and Game.world.modules.travel.current_region == "vila"


func _process(delta: float) -> void:
	if Game.world == null or _pois.is_empty():
		return
	var w: WeatherModule = Game.world.modules.weather
	var te: TownEventsModule = Game.world.modules.town_events
	var events: Array = te.active_ids() if te else []
	var ev_key := ",".join(events)
	if ev_key != _last_events:
		_last_events = ev_key
		_rebuild_decor(events)
	var raining: bool = w.is_raining()
	var cond: String = w.region.condition if w.enabled else "limpo"
	var want: int = target_count(Game.world.hour(), cond, events) if _in_vila() and Game.mode != Game.Mode.COMBAT else 0
	_spawn_t -= delta
	if agents.size() < want and _spawn_t <= 0.0:
		_spawn(events, raining)
		_spawn_t = _rng.randf_range(0.4, 1.4)
	elif agents.size() > want + 2:
		_send_home(agents[_rng.randi() % agents.size()])
	for a in agents.duplicate():
		_tick_agent(a, delta, raining, events)
	_tick_carts(delta, raining)
	_tick_decor(delta)


## Enche a vila de uma vez (ao chegar, ao carregar, depois de descansar): a rua já está viva.
func prefill() -> void:
	if Game.world == null or _pois.is_empty() or not _in_vila():
		return
	var w: WeatherModule = Game.world.modules.weather
	var te: TownEventsModule = Game.world.modules.town_events
	var events: Array = te.active_ids() if te else []
	_last_events = ",".join(events)
	_rebuild_decor(events)
	var want: int = target_count(Game.world.hour(), w.region.condition if w.enabled else "limpo", events)
	_instant = true
	var guard := 0
	while agents.size() < want and guard < 60:
		_spawn(events, w.is_raining())
		guard += 1
	_instant = false


# --- Agentes ------------------------------------------------------------------------------------
func _pick(cat: String) -> Vector2i:
	var arr: Array = _pois.get(cat, [])
	return arr[_rng.randi() % arr.size()] if not arr.is_empty() else Vector2i(22, 25)


func _new_view(sheet: String, scale_: float = 1.0) -> ActorView:
	var v := ActorView.new()
	v.setup("figurante_%d" % _rng.randi(), "res://assets/chars/%s.png" % sheet, "")
	v.name = "Figurante_%s" % sheet.capitalize()
	v.add_to_group("figurantes")
	v.sprite.self_modulate = TINTS[_rng.randi() % TINTS.size()]
	v.base_scale = scale_
	v.shadow_contact.scale = Vector2.ONE * scale_
	v.modulate.a = 0.0
	add_child(v)
	return v


func _spawn(events: Array, raining: bool) -> void:
	var h := Game.world.hour()
	var roll := _rng.randf()
	var kids_ok := h >= 7 and h < 20 and not raining
	if events.has("festa") and roll < 0.35:
		_spawn_group("danca", 4 + _rng.randi() % 3)
	elif events.has("feira") and roll < 0.3 and _count("vendedor") < 6:
		_spawn_one("vendedor", _pick("mercado"))
	elif kids_ok and roll < 0.42 and _count("crianca") < 6:
		_spawn_group("crianca", 2 + _rng.randi() % 2)
	elif roll < 0.58 and not raining:
		_spawn_group("conversa", 2)
	elif roll < 0.72 and not raining:
		_spawn_one("ocupado", _pick("portas"))
	else:
		_spawn_one("passante", _pick("saidas") if _rng.randf() < 0.4 else _pick("portas"))


func _count(kind: String) -> int:
	return agents.filter(func(a): return a.kind == kind).size()


func _spawn_one(kind: String, at: Vector2i, group: Dictionary = {}) -> Dictionary:
	var sheet: String = "crianca" if kind == "crianca" else SHEETS[_rng.randi() % SHEETS.size()]
	var v := _new_view(sheet, 0.9 if kind == "crianca" else 1.0)
	if _instant and kind in ["passante", "apressado", "ocupado"]:
		at = _pick(["rua", "praca", "mercado"][_rng.randi() % 3])
	v.position = Game.db.tile_to_world(at) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
	var a := {"view": v, "kind": kind, "state": "chegando", "t": 0.0, "speed": _rng.randf_range(38, 52), "bubble": null,
		"bubble_t": _rng.randf_range(1.0, 5.0), "group": group, "phase": _rng.randf() * TAU, "trips": 2 + _rng.randi() % 3,
		"prop": ["", "saco", "vassoura", "cesto", "lenha"][_rng.randi() % 5] if kind == "ocupado" else "",
		"ware": ["comida", "comida", "ferramenta", "remedio", "tecido"][_rng.randi() % 5] if kind == "vendedor" else ""}
	agents.append(a)
	if a.prop != "":
		var p := Prop.new()
		p.kind = a.prop
		v.add_child(p)
		a["prop_node"] = p
	if _instant:
		v.modulate.a = 1.0
	else:
		create_tween().tween_property(v, "modulate:a", 1.0, 0.5)
	_next_goal(a, false)
	return a


func _spawn_group(kind: String, n: int) -> void:
	var center: Vector2i = _pick("praca")
	if kind == "crianca" and _rng.randf() < 0.4:
		center = _pick("rua")
	var g := {"center": Game.db.tile_to_world(center), "kind": kind, "turn": 0, "wait": _rng.randf_range(1.0, 3.0), "script": []}
	if kind == "conversa":
		g.script = AmbientTalk.conversation(Game.db.ambient, AmbientTalk.context(Game.world), _rng.randi())
	for i in n:
		var a := _spawn_one(kind, _pick("portas") if kind != "danca" else _pick("praca"), g)
		a.phase = TAU * i / n
		a["seat"] = i


func _next_goal(a: Dictionary, leave: bool) -> void:
	var v: ActorView = a.view
	var from := Game.db.world_to_tile(v.position)
	var to: Vector2i
	match a.kind:
		"vendedor", "conversa", "danca", "crianca":
			to = Game.db.world_to_tile(a.group.center) if not a.group.is_empty() else _pick("praca")
			if a.kind == "vendedor": to = _pick("mercado")
			if a.kind == "conversa":
				to = Game.db.world_to_tile(a.group.center) + (Vector2i(1, 0) if a.phase > 1.0 else Vector2i(0, 0))
		"ocupado":
			to = _pick("portas") if _rng.randf() < 0.5 else _pick("rua")
		_:
			to = _pick(["praca", "mercado", "portas", "rua"][_rng.randi() % 4])
	if leave:
		to = _pick("portas") if _rng.randf() < 0.7 else _pick("saidas")
		a.state = "saindo"
	else:
		a.state = "indo"
	var path := world_view.path_tiles(from, to) if world_view else []
	var pts: Array = []
	for p in path.slice(1):
		pts.append(Game.db.tile_to_world(p) + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5)))
	a.target = to
	var raining: bool = Game.world.modules.weather.is_raining()
	var spd: float = a.speed * (1.9 if raining or a.kind == "apressado" else 1.0)
	if not v.arrived.is_connected(_on_arrived):
		v.arrived.connect(_on_arrived.bind(a))
	v.walk_path(pts, spd)


func _on_arrived(a: Dictionary) -> void:
	if not agents.has(a):
		return
	if a.state == "saindo":
		_despawn(a)
		return
	a.state = "parado"
	a.t = _rng.randf_range(3.0, 8.0) if a.kind in ["passante", "apressado"] else _rng.randf_range(12.0, 30.0)
	if a.kind == "ocupado":
		a.state = "trabalhando"


func _send_home(a: Dictionary) -> void:
	if a.state != "saindo":
		_next_goal(a, true)


func _despawn(a: Dictionary) -> void:
	agents.erase(a)
	var v: ActorView = a.view
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 0.0, 0.4)
	tw.tween_callback(v.queue_free)


func _tick_agent(a: Dictionary, delta: float, raining: bool, events: Array) -> void:
	var v: ActorView = a.view
	a.bubble_t -= delta
	if raining and a.state != "saindo" and a.kind != "danca":
		_send_home(a)   # chuva: todo mundo corre para dentro
		return
	match a.state:
		"parado":
			a.t -= delta
			if a.t <= 0.0:
				a.trips -= 1
				_next_goal(a, a.trips <= 0)
		"trabalhando":
			a.t -= delta
			a.phase += delta * 3.0
			if fmod(a.phase, 1.6) < delta * 3.0:
				v.squash(0.12)
			if a.has("prop_node"): (a.prop_node as Prop).working = true
			if a.t <= 0.0:
				a.trips -= 1
				_next_goal(a, a.trips <= 0)
		"indo", "chegando":
			if a.kind in ["crianca", "danca"] and v.position.distance_to(a.group.center) < 48.0:
				v.stop(); a.state = "brincando"
	if a.state == "brincando":
		var c: Vector2 = a.group.center
		a.phase += delta * (2.2 if a.kind == "crianca" else 1.1)
		var r: float = 30.0 if a.kind == "crianca" else 38.0
		var goal := c + Vector2(cos(a.phase), sin(a.phase) * 0.6) * r
		var d := goal - v.position
		v.walking = d.length() > 1.0
		v.face_dir(d)
		v.position += d.limit_length((110.0 if a.kind == "crianca" else 60.0) * delta)
		if a.kind == "danca" and fmod(a.phase, PI) < delta * 1.1:
			v.squash(0.15)
		if a.kind == "crianca" and _rng.randf() < delta * 0.02:
			a.trips -= 1
			if a.trips <= 0: _next_goal(a, true)
	if a.kind in ["conversa", "vendedor"] and a.state in ["parado", "trabalhando"]:
		if a.kind == "conversa" and not a.group.is_empty():
			v.face_towards(a.group.center + Vector2(16, 0))
	# balões de fala: conversas de verdade, pregões da mercadoria, falas por contexto
	if a.bubble_t <= 0.0 and v.modulate.a > 0.5:
		var ctx := AmbientTalk.context(Game.world)
		var txt := ""
		var data := Game.db.ambient
		match a.kind:
			"conversa": txt = _conversation_line(a)
			"vendedor": if a.state == "parado": txt = AmbientTalk.vendedor(data, a.ware, ctx, _rng.randi())
			"crianca": if a.state == "brincando": txt = AmbientTalk.crianca(data, ctx, _rng.randi())
			"danca": txt = AmbientTalk.danca(data, _rng.randi())
			"ocupado": if a.state == "trabalhando": txt = AmbientTalk.ocupado(data, a.prop, _rng.randi())
			"passante": if _rng.randf() < 0.18: txt = AmbientTalk.passante(data, ctx, _rng.randi())
		if txt != "":
			_bubble(v, txt)
		a.bubble_t = _rng.randf_range(0.6, 1.0) if a.kind == "conversa" and txt == "" else _rng.randf_range(2.5, 6.0)


## Fala da vez na conversa do grupo: só começa quando os dois chegaram, alterna entre os dois e, ao fim do
## roteiro, espera um tempo e puxa outro assunto (do contexto de agora).
func _conversation_line(a: Dictionary) -> String:
	var g: Dictionary = a.group
	if g.is_empty() or a.state != "parado":
		return ""
	for o in agents:
		if is_same(o.group, g) and o.state != "parado":
			return ""
	var script: Array = g.script
	if script.is_empty():
		return ""
	var turn := int(g.turn)
	if turn >= script.size():
		g.wait = float(g.wait) - 1.0
		if float(g.wait) <= -6.0:
			g.script = AmbientTalk.conversation(Game.db.ambient, AmbientTalk.context(Game.world), _rng.randi())
			g.turn = 0
			g.wait = 0.0
		return ""
	if turn % 2 != int(a.get("seat", 0)) % 2:
		return ""
	g.turn = turn + 1
	return str(script[turn])


func _bubble(v: ActorView, txt: String) -> void:
	SpeechBubble.show(self, v, txt)


# --- Carroças -----------------------------------------------------------------------------------
func _tick_carts(delta: float, raining: bool) -> void:
	var h := Game.world.hour()
	_cart_t -= delta
	if _cart_t <= 0.0 and _in_vila() and h >= 6 and h < 20 and carts.size() < 2:
		_cart_t = _rng.randf_range(18.0, 40.0) * (2.0 if raining else 1.0)
		var east := _rng.randf() < 0.5
		var node := Cart.new()
		node.name = "Carroca"
		node.add_to_group("figurantes")
		node.dir = -1.0 if east else 1.0
		node.position = Vector2((47 if east else 0) * TILE, (25 if east else 26) * TILE + 16)
		node.cargo = _rng.randi() % 3
		add_child(node)
		carts.append({"node": node, "speed": _rng.randf_range(34, 44), "stop": _rng.randf() < 0.5, "stopped": 0.0})
	for c in carts.duplicate():
		var n: Cart = c.node
		var mx: float = 19.5 * TILE
		if c.stop and absf(n.position.x - mx) < 4.0 and c.stopped < 5.0:
			c.stopped += delta   # para no mercado, descarrega e segue
			n.moving = false
			continue
		n.moving = true
		n.position.x += n.dir * c.speed * delta
		if n.position.x < -40 or n.position.x > 48 * TILE:
			carts.erase(c)
			n.queue_free()


# --- Decoração de eventos ---------------------------------------------------------------------
func _rebuild_decor(events: Array) -> void:
	for c in decor.get_children(): c.queue_free()
	_clear_lights()
	if Game.world == null:
		return
	var db: ContentDB = Game.db
	if events.has("feira"):
		var r: Array = db.location("mercado").rect
		var spots := [Vector2(int(r[0]) + 0.5, int(r[1]) + 0.2), Vector2(int(r[0]) + 3.0, int(r[1]) + 0.2), Vector2(int(r[0]) + 5.5, int(r[1]) + 0.2),
			Vector2(17.2, 28.6), Vector2(26.2, 28.6)]
		for i in spots.size():
			var s := Stall.new()
			s.name = "Barraca_%d" % i
			s.position = (spots[i] as Vector2) * TILE + Vector2(0, 24)
			s.stripe = [Color(0.7, 0.18, 0.15), Color(0.2, 0.4, 0.65), Color(0.85, 0.65, 0.2), Color(0.3, 0.55, 0.3), Color(0.55, 0.25, 0.55)][i % 5]
			s.goods = i % 4
			decor.add_child(s)
	if events.has("festa"):
		var pr: Array = db.location("praca").rect
		var x0 := int(pr[0]) * TILE
		var y0 := int(pr[1]) * TILE
		var x1 := (int(pr[0]) + int(pr[2])) * TILE
		var y1 := (int(pr[1]) + int(pr[3])) * TILE
		var b := Bunting.new()
		b.lines = [[Vector2(x0, y0), Vector2(x1, y0)], [Vector2(x0, y1), Vector2(x1, y1)], [Vector2(x0, y0), Vector2(x0, y1)], [Vector2(x1, y0), Vector2(x1, y1)],
			[Vector2(x0, y0), Vector2(x1, y1)]]
		b.position = Vector2.ZERO
		b.z_index = 2
		decor.add_child(b)
		# lanternas: brilho desenhado na camada que não escurece (o renderizador de compatibilidade
		# tem limite de luzes por item; dezenas de PointLight2D apagavam pedaços do chão)
		var lan := Lanterns.new()
		lan.lines = b.lines
		if fx and fx.glow: fx.glow.add_child(lan)
		else: decor.add_child(lan)
		_lanterns.append(lan)
		# fogueira a sudeste do poço
		var fire_pos := Vector2(x1 - 48, y1 - 40)
		var logs := Bonfire.new()
		logs.position = fire_pos
		decor.add_child(logs)
		_fire = CPUParticles2D.new()
		_fire.position = fire_pos + Vector2(0, -4)
		_fire.amount = 26; _fire.lifetime = 0.9; _fire.preprocess = 1.0
		_fire.direction = Vector2(0, -1); _fire.spread = 18.0; _fire.gravity = Vector2(0, -40)
		_fire.initial_velocity_min = 10.0; _fire.initial_velocity_max = 26.0
		_fire.scale_amount_min = 2.0; _fire.scale_amount_max = 4.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.4, 1.0)); g.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
		_fire.color_ramp = g
		_fire.z_index = 1
		if fx and fx.glow: fx.glow.add_child(_fire)
		else: decor.add_child(_fire)
		if fx:
			_lanterns.append(fx._make_light(fire_pos + Vector2(0, -6), Color(1.0, 0.6, 0.3), 0.0, 2.2, "fogueira"))
		var bard := _spawn_one("vendedor", Game.db.world_to_tile(Vector2(x0 + 40, y0 + 40)))
		bard.kind = "danca"
		bard.group = {"center": Vector2(x0 + 40, y0 + 40), "kind": "musico"}
		var lute := Prop.new(); lute.kind = "alaude"; (bard.view as Node).add_child(lute)


func _tick_decor(delta: float) -> void:
	_music_t += delta
	var n := fx.night if fx else 0.0
	for l in _lanterns:
		if is_instance_valid(l) and l is PointLight2D:
			(l as PointLight2D).energy = (0.35 + 0.9 * n) * (0.9 + 0.1 * sin(_music_t * 9.0 + l.position.x))
		elif is_instance_valid(l) and l is Lanterns:
			(l as Lanterns).night = n


func _exit_tree() -> void:
	_clear_lights()


func _clear_lights() -> void:
	for l in _lanterns:
		if is_instance_valid(l): (l as Node).queue_free()
	_lanterns.clear()
	if _fire and is_instance_valid(_fire): _fire.queue_free()
	_fire = null


# --- Peças desenhadas (provisórias, procedurais) -------------------------------------------------
class Prop extends Node2D:
	var kind := "saco"
	var working := false
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		match kind:
			"saco":
				draw_circle(Vector2(0, -30), 6.0, Color(0.72, 0.6, 0.4))
				draw_line(Vector2(-3, -35), Vector2(3, -35), Color(0.4, 0.3, 0.2), 1.0)
			"vassoura":
				var a := sin(_t * 6.0) * (0.5 if working else 0.1)
				var tip := Vector2(8 + 6 * a, 2)
				draw_line(Vector2(5, -14), tip, Color(0.5, 0.35, 0.2), 1.5)
				draw_line(tip + Vector2(-3, 0), tip + Vector2(3, 2), Color(0.8, 0.7, 0.4), 3.0)
			"cesto":
				draw_rect(Rect2(Vector2(5, -14), Vector2(8, 6)), Color(0.6, 0.45, 0.25))
				draw_circle(Vector2(8, -15), 1.5, Color(0.8, 0.2, 0.2)); draw_circle(Vector2(11, -15), 1.5, Color(0.9, 0.7, 0.2))
			"lenha":
				for i in 3: draw_line(Vector2(-6, -24 - i * 2), Vector2(6, -26 - i * 2), Color(0.45, 0.3, 0.18), 2.0)
			"alaude":
				draw_circle(Vector2(6, -10), 4.0, Color(0.6, 0.4, 0.2))
				draw_line(Vector2(6, -10), Vector2(-2, -20 + sin(_t * 8.0)), Color(0.45, 0.3, 0.15), 1.5)


class Cart extends Node2D:
	var dir := 1.0
	var cargo := 0
	var moving := true
	var _wheel := 0.0
	var _bob := 0.0
	func _process(d: float) -> void:
		if moving:
			_wheel += d * 6.0 * dir
			_bob += d * 9.0
		queue_redraw()
	func _draw() -> void:
		scale.x = dir
		var b := absf(sin(_bob)) * 1.5 if moving else 0.0
		draw_rect(Rect2(Vector2(-26, 2), Vector2(56, 6)), Color(0, 0, 0, 0.25))   # sombra
		# cavalo
		var hb := Vector2(22, -14 - b)
		draw_rect(Rect2(hb, Vector2(18, 9)), Color(0.42, 0.28, 0.17))
		draw_rect(Rect2(hb + Vector2(15, -7), Vector2(5, 9)), Color(0.42, 0.28, 0.17))
		draw_rect(Rect2(hb + Vector2(17, -9), Vector2(6, 5)), Color(0.38, 0.25, 0.15))
		draw_rect(Rect2(hb + Vector2(14, -7), Vector2(2, 7)), Color(0.15, 0.1, 0.08))
		for i in 4:
			var lx := hb.x + 2 + i * 4.5
			var sw := sin(_bob + i * 1.7) * 2.0 if moving else 0.0
			draw_line(Vector2(lx, hb.y + 9), Vector2(lx + sw, 4), Color(0.3, 0.2, 0.12), 2.0)
		draw_line(hb + Vector2(0, 3), hb + Vector2(-6, 2), Color(0.2, 0.15, 0.1), 2.0)   # cauda
		draw_line(Vector2(10, -10), hb + Vector2(2, 2), Color(0.35, 0.25, 0.15), 1.5)   # varal
		# carroça
		draw_rect(Rect2(Vector2(-24, -18 - b * 0.5), Vector2(36, 12)), Color(0.48, 0.33, 0.2))
		draw_rect(Rect2(Vector2(-24, -18 - b * 0.5), Vector2(36, 2)), Color(0.6, 0.45, 0.28))
		match cargo:
			0:
				for i in 3: draw_circle(Vector2(-16 + i * 10, -21 - b * 0.5), 5.0, Color(0.75, 0.62, 0.4))
			1:
				draw_rect(Rect2(Vector2(-22, -27 - b * 0.5), Vector2(14, 9)), Color(0.4, 0.28, 0.18)); draw_rect(Rect2(Vector2(-6, -25 - b * 0.5), Vector2(14, 7)), Color(0.45, 0.32, 0.2))
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(-24, -18), Vector2(12, -18), Vector2(8, -30), Vector2(-20, -30)]), Color(0.85, 0.8, 0.68))
		# condutor
		draw_rect(Rect2(Vector2(4, -30 - b), Vector2(7, 10)), Color(0.35, 0.3, 0.45))
		draw_circle(Vector2(7.5, -33 - b), 3.5, Color(0.9, 0.75, 0.6))
		# rodas
		for wx in [-16.0, 6.0]:
			var c := Vector2(wx, -4)
			draw_circle(c, 6.0, Color(0.25, 0.17, 0.1))
			draw_circle(c, 4.5, Color(0.5, 0.36, 0.22))
			for k in 4:
				var a := _wheel + k * PI / 4.0
				draw_line(c - Vector2(cos(a), sin(a)) * 4.5, c + Vector2(cos(a), sin(a)) * 4.5, Color(0.25, 0.17, 0.1), 1.0)


class Stall extends Node2D:
	var stripe := Color(0.7, 0.2, 0.15)
	var goods := 0
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-2, -2), Vector2(40, 6)), Color(0, 0, 0, 0.25))
		draw_line(Vector2(0, 0), Vector2(0, -30), Color(0.35, 0.24, 0.14), 2.0)
		draw_line(Vector2(36, 0), Vector2(36, -30), Color(0.35, 0.24, 0.14), 2.0)
		draw_rect(Rect2(Vector2(-1, -12), Vector2(38, 10)), Color(0.5, 0.36, 0.22))   # balcão
		draw_rect(Rect2(Vector2(-1, -12), Vector2(38, 2)), Color(0.62, 0.47, 0.3))
		for i in 6:   # toldo listrado
			draw_colored_polygon(PackedVector2Array([Vector2(-3 + i * 7, -36), Vector2(4 + i * 7, -36), Vector2(4 + i * 7, -28), Vector2(-3 + i * 7, -28)]),
				stripe if i % 2 == 0 else Color(0.95, 0.92, 0.85))
		for i in 6:
			draw_arc(Vector2(0.5 + i * 7, -28), 3.5, 0, PI, 5, stripe if i % 2 == 0 else Color(0.95, 0.92, 0.85), 2.0)
		for i in 5:
			var p := Vector2(4 + i * 7, -14)
			match goods:
				0: draw_circle(p, 2.5, Color(0.85, 0.2, 0.15))
				1: draw_rect(Rect2(p - Vector2(2.5, 2), Vector2(5, 3)), Color(0.85, 0.7, 0.4))
				2: draw_rect(Rect2(p - Vector2(2.5, 3), Vector2(5, 4)), [Color(0.3, 0.4, 0.7), Color(0.7, 0.3, 0.3), Color(0.3, 0.6, 0.35)][i % 3])
				_: draw_line(p + Vector2(-3, 0), p + Vector2(3, -2), Color(0.75, 0.78, 0.82), 2.0)


class Bunting extends Node2D:
	var lines: Array = []
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var cols := [Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.25), Color(0.25, 0.5, 0.8), Color(0.3, 0.65, 0.35), Color(0.9, 0.9, 0.85)]
		for ln in lines:
			var a: Vector2 = ln[0] + Vector2(0, -26)
			var b: Vector2 = ln[1] + Vector2(0, -26)
			var n := int(a.distance_to(b) / 10.0)
			var prev := a
			for i in range(1, n + 1):
				var t := float(i) / n
				var sag := sin(t * PI) * 14.0
				var p := a.lerp(b, t) + Vector2(0, sag)
				draw_line(prev, p, Color(0.3, 0.25, 0.2), 1.0)
				var sway := sin(_t * 2.0 + i) * 1.5
				draw_colored_polygon(PackedVector2Array([prev, p, (prev + p) / 2.0 + Vector2(sway, 7)]), cols[i % cols.size()])
				prev = p


class Lanterns extends Node2D:
	var lines: Array = []
	var night := 0.0
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var cols := [Color(1.0, 0.75, 0.35), Color(1.0, 0.55, 0.3), Color(1.0, 0.9, 0.5)]
		for ln in lines:
			var a: Vector2 = ln[0] + Vector2(0, -26)
			var b: Vector2 = ln[1] + Vector2(0, -26)
			var n := int(a.distance_to(b) / 40.0)
			for i in range(1, n):
				var t := float(i) / n
				var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * 14.0 + 5.0)
				var f := 0.85 + 0.15 * sin(_t * 7.0 + i * 1.3)
				var c: Color = cols[i % 3]
				var k := (0.25 + 0.75 * night) * f
				draw_circle(p, 14.0, Color(c, 0.07 * k))
				draw_circle(p, 7.0, Color(c, 0.18 * k))
				draw_circle(p, 2.5, Color(c.lightened(0.3), 0.9 * maxf(0.4, k)))


class Bonfire extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2(0, 0), 12.0, Color(0, 0, 0, 0.3))
		for i in 6:
			var a := i * PI / 3.0
			draw_circle(Vector2(cos(a), sin(a) * 0.5) * 10.0, 3.0, Color(0.5, 0.48, 0.45))
		draw_line(Vector2(-8, 2), Vector2(8, -4), Color(0.35, 0.22, 0.12), 3.0)
		draw_line(Vector2(-8, -4), Vector2(8, 2), Color(0.35, 0.22, 0.12), 3.0)
