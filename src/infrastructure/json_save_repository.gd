class_name JsonSaveRepository
extends RefCounted
## Persistência JSON atômica (§14): cabeçalho, checksum SHA-256, arquivo temporário,
## backup do save anterior e recuperação automática se o principal estiver corrompido.

const FORMAT := "cronicas_de_arton_save"
const CURRENT_SCHEMA := 1

var base_dir: String
## Migrações N -> N+1: schema_version (int) -> Callable(Dictionary) -> Dictionary
var migrations: Dictionary = {}


func _init(p_base_dir: String = "user://saves") -> void:
	base_dir = p_base_dir
	DirAccess.make_dir_recursive_absolute(base_dir)


func _path(slot: String) -> String: return base_dir.path_join(slot + ".json")
func _tmp(slot: String) -> String: return base_dir.path_join(slot + ".json.tmp")
func _bak(slot: String) -> String: return base_dir.path_join(slot + ".json.bak")


static func checksum(data: Dictionary) -> String:
	# Normaliza via round-trip: JSON.parse_string lê números como float,
	# então int 1 e float 1.0 devem gerar o mesmo hash na escrita e na leitura.
	var normalized = JSON.parse_string(JSON.stringify(data))
	return JSON.stringify(normalized, "", true).sha256_text()


func save(slot: String, snapshot: Dictionary) -> Error:
	var doc := {
		"header": {"format": FORMAT, "schema_version": CURRENT_SCHEMA, "checksum": checksum(snapshot)},
		"data": snapshot,
	}
	var f := FileAccess.open(_tmp(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(doc, "  ", true))
	f.flush()
	f.close()
	# Valida o temporário antes de substituir.
	if _read_valid(_tmp(slot)).is_empty():
		return ERR_FILE_CORRUPT
	var dir := DirAccess.open(base_dir)
	if FileAccess.file_exists(_path(slot)):
		if FileAccess.file_exists(_bak(slot)):
			dir.remove(_bak(slot).get_file())
		dir.rename(_path(slot).get_file(), _bak(slot).get_file())
	return dir.rename(_tmp(slot).get_file(), _path(slot).get_file())


## Retorna {"data":..., "recovered_from_backup": bool} ou {} se nada válido.
func load_slot(slot: String) -> Dictionary:
	var main := _read_valid(_path(slot))
	if not main.is_empty():
		return {"data": _migrate(main), "recovered_from_backup": false}
	var bak := _read_valid(_bak(slot))
	if not bak.is_empty():
		return {"data": _migrate(bak), "recovered_from_backup": true}
	return {}


func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("header") or not parsed.has("data"):
		return {}
	var h: Dictionary = parsed.header
	if h.get("format") != FORMAT:
		return {}
	if h.get("checksum") != checksum(parsed.data):
		return {}
	var data: Dictionary = parsed.data
	data["_schema"] = int(h.get("schema_version", 0))
	return data


func _migrate(data: Dictionary) -> Dictionary:
	var v: int = data.get("_schema", CURRENT_SCHEMA)
	while v < CURRENT_SCHEMA:
		assert(migrations.has(v), "Falta migração %d -> %d" % [v, v + 1])
		data = migrations[v].call(data)
		v += 1
	data.erase("_schema")
	return data
