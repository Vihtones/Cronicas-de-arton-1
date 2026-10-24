class_name RuleRegistry
extends RefCounted
## Catálogo de regras com proveniência (§2). Toda regra tem fonte, página e status.
## Regras não VERIFICADAS continuam utilizáveis, mas são reportadas (ver unverified_ids()).

const ALLOWED_STATUS := ["VERIFICADA", "PENDENTE_REVISAO", "ADAPTADA", "ORIGINAL_DO_JOGO"]
const REQUIRED := ["id", "valor", "fonte", "pagina", "status"]

var _rules: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


static func load_default() -> RuleRegistry:
	var r := RuleRegistry.new()
	r.load_dir("res://data/rules")
	return r


func load_dir(path: String) -> void:
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".json"):
			load_file(path.path_join(f))


func load_file(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("rules"):
		errors.append("%s: formato inválido" % path)
		return
	for entry in parsed.rules:
		add(entry, path)


func add(entry: Dictionary, origin: String = "") -> bool:
	for k in REQUIRED:
		if not entry.has(k):
			errors.append("%s: regra sem campo '%s' (%s)" % [origin, k, entry.get("id", "?")])
			return false
	if not ALLOWED_STATUS.has(entry.status):
		errors.append("%s: status inválido '%s' em %s" % [origin, entry.status, entry.id])
		return false
	if entry.status != "ORIGINAL_DO_JOGO" and str(entry.fonte).is_empty():
		errors.append("%s: regra oficial sem fonte: %s" % [origin, entry.id])
		return false
	_rules[entry.id] = entry
	return true


func has(id: String) -> bool:
	return _rules.has(id)


func value(id: String, default: Variant = null) -> Variant:
	return _rules[id].valor if _rules.has(id) else default


func entry(id: String) -> Dictionary:
	return _rules.get(id, {})


func ids_with_prefix(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in _rules:
		if str(k).begins_with(prefix):
			out.append(k)
	out.sort()
	return out


func unverified_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _rules:
		if _rules[k].status == "PENDENTE_REVISAO":
			out.append(k)
	out.sort()
	return out


func size() -> int:
	return _rules.size()
