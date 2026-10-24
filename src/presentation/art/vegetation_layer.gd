class_name VegetationLayer
extends Node2D
## Vegetação aprovada pelo Governador de Arte, posicionada sobre o mapa (só apresentação).
## A colisão continua vindo do mapa (tiles 'T' bloqueados, AD-09): a imagem nunca decide acesso.
## Árvores grandes ficam espaçadas e o resto dos tiles bloqueados vira sub-bosque (AD-11).
## Copas ficam translúcidas perto do jogador e durante o combate (AD-10).

const FEET_Y := 10.0   # base do sprite perto da borda inferior do tile, para o Y-sort com atores

var governor: ArtGovernor
var follow: Node2D            # jogador (definido pela cena principal)
var sprites: Array[Sprite2D] = []
var _combat := false
var _accum := 0.0


## Plano puro e determinístico: [{tile, asset_id, role}]. Testável sem texturas.
static func plan(db: ContentDB, gov: ArtGovernor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spacing: int = int(gov.policy("arvore_espacamento_tiles", 2))
	var big_w: int = int(gov.policy("arvore_grande_largura_px", 150))
	var big_spacing: int = int(gov.policy("arvore_grande_espacamento_tiles", 3))
	var ground_chance: float = float(gov.policy("chao_decorativo_chance", 0.05))
	var cand: Array[Vector2i] = []
	var floor_tiles: Array[Vector2i] = []
	for y in db.size.y:
		for x in db.size.x:
			var t := Vector2i(x, y)
			var ch := db.tile_char(t)
			if ch == "T":
				cand.append(t)
			elif ch == ",":
				floor_tiles.append(t)
	cand.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _key(a, 1) < _key(b, 1))
	var placed_trees: Array[Dictionary] = []   # {tile, radius}
	var last_id := ""
	for t in cand:
		var z := db.zone_at(t)
		var trees := gov.assets_for("floresta.arvore", z)
		var under := gov.assets_for("floresta.sub_bosque", z)
		var pick := ""
		if not trees.is_empty():
			var k := _key(t, 2)
			for i in trees.size():
				var a: Dictionary = trees[(k + i) % trees.size()]
				if a.asset_id == last_id or _covers_path(db, t, a):
					continue   # a copa não pode esconder trilhas e estradas (AD-10)
				var r: int = big_spacing if int(a.tamanho[0]) >= big_w else spacing
				var free := true
				for p in placed_trees:
					var d: Vector2i = (p.tile as Vector2i) - t
					if maxi(absi(d.x), absi(d.y)) <= maxi(r, int(p.radius)):
						free = false
						break
				if free:
					pick = a.asset_id
					placed_trees.append({"tile": t, "radius": r})
					last_id = pick
					out.append({"tile": t, "asset_id": pick, "role": "floresta.arvore"})
				break
		if pick == "" and not under.is_empty():
			var k3 := _key(t, 3)
			for i in under.size():
				var u: Dictionary = under[(k3 + i) % under.size()]
				if not _covers_path(db, t, u):
					pick = u.asset_id
					out.append({"tile": t, "asset_id": pick, "role": "floresta.sub_bosque"})
					break
			if pick == "":
				# junto à trilha: a planta mais baixa aprovada, para não sobrar placeholder misturado
				var low := gov.assets_for("floresta.chao_decorativo", z)
				if not low.is_empty():
					low.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tamanho[1]) < int(b.tamanho[1]))
					out.append({"tile": t, "asset_id": low[0].asset_id, "role": "floresta.sub_bosque"})
	var busy := {}
	for o in db.all_objects():
		busy[Vector2i(int(o.tile[0]), int(o.tile[1]))] = true
	for tg in db.all_targets():
		if tg.has("tile"):
			busy[Vector2i(int(tg.tile[0]), int(tg.tile[1]))] = true
	for t in floor_tiles:
		var ground := gov.assets_for("floresta.chao_decorativo", db.zone_at(t))
		if ground.is_empty() or busy.has(t) or _near_path(db, t):
			continue
		if float(_key(t, 4) % 1000) / 1000.0 < ground_chance:
			out.append({"tile": t, "asset_id": ground[_key(t, 5) % ground.size()].asset_id, "role": "floresta.chao_decorativo"})
	return out


## A silhueta (sem 1/4 de cada lado, onde ficam sombra e pontas) cobre algum tile de trilha ou estrada?
static func _covers_path(db: ContentDB, t: Vector2i, a: Dictionary) -> bool:
	var w := float(a.tamanho[0])
	var h := float(a.tamanho[1])
	var base := db.tile_to_world(t) + Vector2(0, FEET_Y)
	var left := base.x - float(a.pivot[0]) + w * 0.25
	var right := base.x - float(a.pivot[0]) + w * 0.75
	var top := base.y - float(a.pivot[1])
	var bottom := base.y
	var tp := float(db.tile_px)
	for ty in range(int(floor(top / tp)), int(floor(bottom / tp)) + 1):
		for tx in range(int(floor(left / tp)), int(floor(right / tp)) + 1):
			var c := db.tile_char(Vector2i(tx, ty))
			if c == ":" or c == "=":
				return true
	return false


## Trilhas e estradas ficam limpas para a leitura dos caminhos (AD-10).
static func _near_path(db: ContentDB, t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := db.tile_char(t + Vector2i(dx, dy))
			if c == ":" or c == "=" or c == "D" or c == "d":
				return true
	return false


static func _key(t: Vector2i, salt: int) -> int:
	return absi((t.x * 73856093) ^ (t.y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


## Tiles 'T' cobertos por vegetação aprovada: o WorldView pinta o chão da floresta por baixo.
static func dressed_tiles(p: Array[Dictionary]) -> Dictionary:
	var d := {}
	for e in p:
		if db_tile_role_blocks(e.role):
			d[e.tile] = true
	return d


static func db_tile_role_blocks(role: String) -> bool:
	return role == "floresta.arvore" or role == "floresta.sub_bosque"


func build(db: ContentDB, p: Array[Dictionary]) -> void:
	for s in sprites:
		s.queue_free()
	sprites.clear()
	y_sort_enabled = true
	var cache := {}
	for e in p:
		var a: Dictionary = governor.assets[e.asset_id]
		if not cache.has(e.asset_id):
			cache[e.asset_id] = load(a.caminho)
		var s := Sprite2D.new()
		s.texture = cache[e.asset_id]
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # AD-08
		s.offset = -Vector2(float(a.pivot[0]), float(a.pivot[1]))
		s.position = db.tile_to_world(e.tile) + Vector2(0, FEET_Y)
		s.set_meta("canopy", e.role != "floresta.chao_decorativo")
		add_child(s)
		sprites.append(s)


func set_combat(on: bool) -> void:
	_combat = on
	_accum = 1.0


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.1 or follow == null:
		return
	_accum = 0.0
	var p: Vector2 = follow.global_position
	var near_a: float = float(governor.policy("copa_alpha_perto_jogador", 0.45))
	var combat_a: float = float(governor.policy("copa_alpha_combate", 0.35))
	var radius: float = float(governor.policy("copa_raio_px", 56))
	for s in sprites:
		if not s.get_meta("canopy", false):
			continue
		var target := 1.0
		if _combat:
			target = combat_a
		else:
			var rect := Rect2(s.position + s.offset, s.texture.get_size()).grow(radius * 0.25)
			# só quando o jogador está atrás da planta (acima da base) e dentro da silhueta
			if p.y < s.position.y and rect.has_point(p):
				target = near_a
		s.modulate.a = lerpf(s.modulate.a, target, 0.5)
