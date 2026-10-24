class_name ArtGovernor
extends RefCounted
## Governador de Direção de Arte (Beleza Marcada).
## Lê o registro gerado da pasta "arte do jogo" (data/art/direcao_de_arte.json) e o manifesto de assets,
## e decide quais assets podem aparecer, em que papel e em que zona. A apresentação pergunta ao
## governador; nunca carrega um asset de produção diretamente. Sem aprovação registrada, licença
## conhecida e créditos (quando exigidos), o asset é recusado e a apresentação usa o placeholder.

const DIRECTION_PATH := "res://data/art/direcao_de_arte.json"
const MANIFEST_PATH := "res://assets/manifest.json"
const BUILDABLE_STATES := ["approved_artistic", "approved"]

var direction: Dictionary = {}
var assets: Dictionary = {}       # asset_id -> entrada do manifesto
var refusals: Dictionary = {}     # asset_id -> motivo (para o relatório e o F3)
var _approvals: Dictionary = {}   # id -> aprovação


static func load_default() -> ArtGovernor:
	var g := ArtGovernor.new()
	g.load_from(_read_json(DIRECTION_PATH), _read_json(MANIFEST_PATH))
	return g


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func load_from(p_direction: Dictionary, manifest: Dictionary) -> void:
	direction = p_direction
	assets.clear()
	refusals.clear()
	_approvals.clear()
	for a in direction.get("aprovacoes", []):
		_approvals[a.id] = a
	for a in manifest.get("assets", []):
		assets[a.asset_id] = a
		var why := _refusal(a)
		if why != "":
			refusals[a.asset_id] = why


## Motivo da recusa ou "" se o asset pode entrar no build (regras AD-01..AD-06).
func _refusal(a: Dictionary) -> String:
	if not str(a.get("estado", "")) in BUILDABLE_STATES:
		return "estado '%s' não é aprovado" % a.get("estado", "")
	var apr_id := str(a.get("aprovacao", ""))
	if apr_id == "" or not _approvals.has(apr_id):
		return "sem aprovação registrada do usuário"
	var apr: Dictionary = _approvals[apr_id]
	if not (apr.get("assets", []) as Array).has(a.asset_id):
		return "aprovação %s não cobre este asset" % apr_id
	if str(apr.get("liberacao_uso", "")) == "" or str(a.get("licenca", "")) == "":
		return "sem liberação de uso/licença"
	if str(a.licenca).begins_with("CC-BY") and str(a.get("creditos", "")) == "":
		return "licença CC-BY sem arquivo de créditos"
	var origem := str(a.get("origem", ""))
	for f in direction.get("fontes_proibidas_no_build", []):
		if origem.contains(str(f)):
			return "origem proibida no build: " + str(f)
	return ""


func is_buildable(asset_id: String) -> bool:
	return assets.has(asset_id) and not refusals.has(asset_id)


## Assets aprovados para um papel numa zona (AD-07). Ordem estável, a do registro.
func assets_for(role: String, zone: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r: Dictionary = direction.get("papeis", {}).get(role, {})
	if not (r.get("zonas", []) as Array).has(zone):
		return out
	for id in r.get("assets", []):
		if not is_buildable(id):
			continue
		var a: Dictionary = assets[id]
		if (a.get("zonas_permitidas", []) as Array).has(zone):
			out.append(a)
	return out


func role_tile(role: String) -> String:
	return str(direction.get("papeis", {}).get(role, {}).get("tile", ""))


func policy(key: String, default_value = null):
	return direction.get("politicas_runtime", {}).get(key, default_value)


func credits_paths() -> Array[String]:
	var out: Array[String] = []
	for id in assets:
		if is_buildable(id):
			var c := str(assets[id].get("creditos", ""))
			if c != "" and not out.has(c):
				out.append(c)
	return out


func report() -> Dictionary:
	var ok := 0
	var pending := 0
	var placeholders := 0
	for id in assets:
		if is_buildable(id):
			ok += 1
			if str(assets[id].get("validacao_tecnica", "")).begins_with("pendente"):
				pending += 1
		elif str(assets[id].get("estado", "")) == "prototype":
			placeholders += 1
	return {"identidade": direction.get("identidade", {}).get("nome", "?"), "aprovados": ok,
		"placeholders": placeholders, "recusados": refusals.size() - placeholders,
		"validacao_tecnica_pendente": pending,
		"regras": (direction.get("regras", []) as Array).size()}
