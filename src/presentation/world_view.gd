class_name WorldView
extends Node2D
## Desenha o mapa a partir do catálogo (TileMapLayer) com colisão para tiles
## bloqueados e portas fechadas. Só lê projeções; nunca altera o domínio.

const TILE := 32
var layer: TileMapLayer
var _cols: Dictionary = {}   # char -> coluna no atlas
var _blocked_chars: Dictionary = {}
var astar: AStarGrid2D


func build() -> void:
	for c in get_children():
		c.queue_free()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	var tiles: Dictionary = {}
	for a in manifest.assets:
		if a.asset_id == "tileset_base":
			tiles = a
	for ch in tiles.indice:
		_cols[ch] = int(tiles.indice[ch].col)
	var legend: Dictionary = Game.db.map.legend
	for ch in legend:
		if not legend[ch].get("walk", false):
			_blocked_chars[ch] = true
	_blocked_chars["D"] = true  # porta fechada (visual 'D'); aberta usa 'd'
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(tiles.caminho)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var poly := PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	for ch in _cols:
		for v in int(tiles.variantes):
			var ac := Vector2i(_cols[ch], v)
			src.create_tile(ac)
			if _blocked_chars.has(ch):
				var td := src.get_tile_data(ac, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, poly)
	layer = TileMapLayer.new()
	layer.tile_set = ts
	layer.name = "Chao"
	add_child(layer)
	var size: Vector2i = Game.db.size
	for y in size.y:
		for x in size.x:
			_paint(Vector2i(x, y))
	_build_astar()


func visual_char(t: Vector2i) -> String:
	var ch := Game.db.tile_char(t)
	if ch == "_":
		var z := Game.db.zone_at(t)
		if z == "cripta": return "k"
		if z == "ruina": return "r"
	if ch == "D" and Game.world != null:
		var id := Game.db.object_at(t)
		var o: Dictionary = Game.world.modules.objects.obj(id)
		if o.get("open", false) or o.get("broken", false):
			return "d"
	return ch


func _paint(t: Vector2i) -> void:
	var ch := visual_char(t)
	if not _cols.has(ch):
		ch = "X"
	var v := absi(hash(t)) % 3
	layer.set_cell(t, 0, Vector2i(_cols[ch], v))


func refresh_tile(t: Vector2i) -> void:
	_paint(t)


func refresh_object(id: String) -> void:
	var d := Game.db.object_def(id)
	if not d.is_empty():
		_paint(Vector2i(int(d.tile[0]), int(d.tile[1])))


## A* só para animação de NPCs (apresentação). NPCs atravessam portas.
func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, Game.db.size)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in Game.db.size.y:
		for x in Game.db.size.x:
			var t := Vector2i(x, y)
			if not Game.db.static_walkable(t):
				astar.set_point_solid(t, true)


func path_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if astar == null or not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to) or astar.is_point_solid(to) or astar.is_point_solid(from):
		return []
	return astar.get_id_path(from, to)
