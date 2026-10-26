class_name ContentDB
extends RefCounted
## Catálogos estáticos (definições) separados do estado mutável (§14).

var map: Dictionary = {}
var npcs: Dictionary = {}
var mystery: Dictionary = {}
var items: Dictionary = {}
var economy: Dictionary = {}
var laws: Dictionary = {}
var distant: Dictionary = {}
var dialogue: Dictionary = {}
var ambient: Dictionary = {}  # falas ambiente dos figurantes e latidos (data/dialogue/ambient.json)
var voices: Dictionary = {}   # vozes dos moradores (data/dialogue/voices.json)
var mysteries: Array = []          # todos os mistérios (principal + secundários)

var grid: PackedStringArray
var size := Vector2i.ZERO
var tile_px := 32
var _loc_by_id: Dictionary = {}
var _obj_by_id: Dictionary = {}
var _obj_by_tile: Dictionary = {}
var _target_by_id: Dictionary = {}
var _npc_by_id: Dictionary = {}
var _creature_by_id: Dictionary = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_dir("res://data/world")
	db.dialogue = _read("res://data/dialogue/dialogue.json")
	db.voices = _read("res://data/dialogue/voices.json")
	db.ambient = _read("res://data/dialogue/ambient.json")
	return db


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func load_dir(dir: String) -> void:
	map = _read(dir.path_join("map.json"))
	npcs = _read(dir.path_join("npcs.json"))
	mystery = _read(dir.path_join("mystery.json"))
	items = _read(dir.path_join("items.json"))
	economy = _read(dir.path_join("economy.json"))
	laws = _read(dir.path_join("laws.json"))
	distant = _read(dir.path_join("distant.json"))
	mysteries = [mystery]
	var extra := _read(dir.path_join("mysteries_extra.json"))
	for m in extra.get("mysteries", []):
		mysteries.append(m)
	_index()


func _index() -> void:
	grid = PackedStringArray(map.get("grid", []))
	size = Vector2i(int(map.get("size", [0, 0])[0]), int(map.get("size", [0, 0])[1]))
	tile_px = int(map.get("tile_px", 32))
	for l in map.get("locations", []): _loc_by_id[l.id] = l
	for o in map.get("objects", []):
		_obj_by_id[o.id] = o
		_obj_by_tile[Vector2i(int(o.tile[0]), int(o.tile[1]))] = o.id
	for t in map.get("targets", []): _target_by_id[t.id] = t
	for n in npcs.get("npcs", []): _npc_by_id[n.id] = n
	for c in npcs.get("creatures", []): _creature_by_id[c.id] = c


func tile_char(t: Vector2i) -> String:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return "X"
	return grid[t.y][t.x]


func tile_info(t: Vector2i) -> Dictionary:
	return map.legend.get(tile_char(t), {"walk": false})


## Caminhável estático (portas fechadas são decididas pelo ObjectsModule).
func static_walkable(t: Vector2i) -> bool:
	return bool(tile_info(t).get("walk", false))


func is_difficult(t: Vector2i) -> bool:
	return bool(tile_info(t).get("difficult", false))


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / tile_px), floori(p.y / tile_px))


func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t.x * tile_px + tile_px / 2.0, t.y * tile_px + tile_px / 2.0)


func fact_text(f: String) -> String:
	for m in mysteries:
		if m.get("facts", {}).has(f):
			return m.facts[f]
	return ""


func mystery_of_fact(f: String) -> String:
	for m in mysteries:
		if m.get("facts", {}).has(f):
			return m.truth_id
	return ""


func mystery_def(id: String) -> Dictionary:
	for m in mysteries:
		if m.get("truth_id", "") == id:
			return m
	return {}


func location(id: String) -> Dictionary: return _loc_by_id.get(id, {})
func object_def(id: String) -> Dictionary: return _obj_by_id.get(id, {})
func object_at(t: Vector2i) -> String: return _obj_by_tile.get(t, "")
func target_def(id: String) -> Dictionary: return _target_by_id.get(id, {})
func npc_def(id: String) -> Dictionary: return _npc_by_id.get(id, {})
func creature_def(id: String) -> Dictionary: return _creature_by_id.get(id, {})
func all_npc_ids() -> Array: return _npc_by_id.keys()
func all_creature_ids() -> Array: return _creature_by_id.keys()
func all_locations() -> Array: return map.get("locations", [])
func all_targets() -> Array: return map.get("targets", [])
func all_objects() -> Array: return map.get("objects", [])


## Local mais específico (interno antes de externo) que contém o tile.
func location_at(t: Vector2i) -> String:
	var best := ""
	var best_area := 1 << 30
	for l in map.get("locations", []):
		var r: Array = l.rect
		if t.x >= r[0] and t.y >= r[1] and t.x < r[0] + r[2] and t.y < r[1] + r[3]:
			var area: int = int(r[2]) * int(r[3])
			if area < best_area:
				best = l.id
				best_area = area
	return best


func zone_at(t: Vector2i) -> String:
	var best := ""
	var best_area := 1 << 30
	for z in map.get("zones", []):
		var r: Array = z.rect
		if t.x >= r[0] and t.y >= r[1] and t.x < r[0] + r[2] and t.y < r[1] + r[3]:
			var area: int = int(r[2]) * int(r[3])
			if area < best_area:
				best = z.id
				best_area = area
	return best


func location_spot(id: String) -> Vector2i:
	var l := location(id)
	if l.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(l.spot[0]), int(l.spot[1]))
