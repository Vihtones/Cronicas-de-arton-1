class_name LlmDialogueProvider
extends DialogueProvider
## Provedor de IA OPCIONAL (Fase 6). Desligado por padrão. Limites: timeout,
## orçamento de chamadas, cache, contexto mínimo e auditoria. Qualquer falha =>
## texto estruturado original (fallback). Nunca roda no loop de frame.
## Config em user://ai.json: {"enabled":true,"endpoint":"...","api_key":"...","model":"...","max_calls":50,"timeout_s":6}

var config: Dictionary = {}
var calls_made := 0
var audit: Array[Dictionary] = []
var _cache: Dictionary = {}
var _http_parent: Node
## Para testes: Callable(prompt:String) -> String ("" = falha)
var transport_override: Callable


func provider_id() -> String: return "llm"


static func load_config(path: String = "user://ai.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"enabled": false}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {"enabled": false}


func _init(p_config: Dictionary = {}, p_parent: Node = null) -> void:
	config = p_config
	_http_parent = p_parent


func available() -> bool:
	return bool(config.get("enabled", false)) and calls_made < int(config.get("max_calls", 50))


func build_prompt(npc_id: String, base_text: String, facts: Dictionary) -> String:
	return "Reescreva a fala abaixo em português, no tom de %s (%s). NÃO adicione fatos, nomes, lugares ou promessas novas. " % [facts.get("name", npc_id), facts.get("profession", "")] \
		+ "Mantenha o mesmo significado e no máximo 2 frases.\nFala: \"%s\"" % base_text


## Validação de saída: rejeita respostas longas demais ou que citem nomes próprios fora do contexto.
func accept(base_text: String, out: String, facts: Dictionary) -> bool:
	if out.strip_edges() == "" or out.length() > base_text.length() * 2 + 80:
		return false
	var allowed: Array = facts.get("allowed_names", [])
	var re := RegEx.create_from_string("\\b[A-ZÁÉÍÓÚÂÊÔÃÕ][a-záéíóúâêôãõç]{3,}\\b")
	for m in re.search_all(out):
		var w := m.get_string()
		if not base_text.contains(w) and not allowed.has(w) and m.get_start() > 0:
			return false
	return true


func verbalize_async(npc_id: String, base_text: String, facts: Dictionary, done: Callable) -> void:
	var key := (npc_id + "|" + base_text).sha256_text()
	if _cache.has(key):
		done.call(_cache[key]); return
	if not available():
		done.call(base_text); return
	calls_made += 1
	var prompt := build_prompt(npc_id, base_text, facts)
	var entry := {"npc": npc_id, "prompt_chars": prompt.length(), "result": "pendente"}
	audit.append(entry)
	if transport_override.is_valid():
		var out: String = transport_override.call(prompt)
		_finish(entry, key, base_text, out, facts, done)
		return
	if _http_parent == null:
		entry.result = "sem_transporte"; done.call(base_text); return
	var http := HTTPRequest.new()
	http.timeout = float(config.get("timeout_s", 6))
	_http_parent.add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		var out := ""
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary:
				out = _extract(parsed)
		_finish(entry, key, base_text, out, facts, done)
		http.queue_free())
	var headers := ["Content-Type: application/json", "x-api-key: " + str(config.get("api_key", "")), "anthropic-version: 2023-06-01"]
	var body := JSON.stringify({"model": config.get("model", ""), "max_tokens": 200, "messages": [{"role": "user", "content": prompt}]})
	if http.request(str(config.get("endpoint", "")), headers, HTTPClient.METHOD_POST, body) != OK:
		_finish(entry, key, base_text, "", facts, done)
		http.queue_free()


func _extract(parsed: Dictionary) -> String:
	if parsed.has("content") and parsed.content is Array and not parsed.content.is_empty():
		return str(parsed.content[0].get("text", ""))
	if parsed.has("choices"):
		return str(parsed.choices[0].message.content)
	return ""


func _finish(entry: Dictionary, key: String, base_text: String, out: String, facts: Dictionary, done: Callable) -> void:
	if accept(base_text, out, facts):
		entry.result = "aceito"
		_cache[key] = out.strip_edges()
		done.call(_cache[key])
	else:
		entry.result = "rejeitado" if out != "" else "falha"
		done.call(base_text)
