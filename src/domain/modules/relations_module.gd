class_name RelationsModule
extends WorldModule
## Relações multidimensionais entre moradores (Arton Viva, Fase 2). ORIGINAL_DO_JOGO.
## - Cada par (quem sente, em relação a quem) tem dimensões separadas: confiança, afeto, respeito, medo,
##   ressentimento, admiração, lealdade, interesse e familiaridade. Ninguém tem uma barra única.
## - Muda só com fatos que a pessoa presenciou (MEMORY_FORMED, emitido pela memória) e com convivência no mesmo local.
## - Traços mudam a intensidade: teimoso resiste a mudar; memória longa guarda mais o que é ruim;
##   exige provas acredita menos em elogios.
## - Reação: rótulo derivado das dimensões, para que pessoas diferentes reajam diferente ao mesmo fato.
## Determinístico. Nenhuma IA generativa.

const DIMS := ["confianca", "afeto", "respeito", "medo", "ressentimento", "admiracao", "lealdade", "interesse", "familiaridade"]
const FAMILIARITY_PER_HOUR := 1.0
const MAX_VALUE := 100.0

var rel: Dictionary = {}  # quem -> {sobre_quem -> {dimensão: valor}}
## Índice derivado de rel: quem -> [os que têm afeto acima de AMIGO_ACIMA]. Mantido a cada escrita de afeto.
var amigos: Dictionary = {}
const AMIGO_ACIMA := 30.0


func module_id() -> String: return "relations"
func subscribed_events() -> PackedStringArray: return PackedStringArray(["MEMORY_FORMED", "PROLOGUE_STARTED"])


## Dimensões de um par (zeradas se nunca se viram). Puro para quem consulta.
func dims(npc_id: String, about: String) -> Dictionary:
	var out := {}
	for d in DIMS:
		out[d] = float(rel.get(npc_id, {}).get(about, {}).get(d, 0.0))
	return out


func reaction(npc_id: String, about: String) -> String:
	var r := dims(npc_id, about)
	if float(r.ressentimento) >= 40.0: return "guarda_rancor"
	if float(r.medo) >= 40.0: return "teme"
	if float(r.confianca) <= -20.0 and float(r.respeito) >= 20.0: return "respeita_mas_nao_confia"
	if float(r.afeto) >= 30.0 and float(r.familiaridade) >= 20.0: return "amigavel"
	if float(r.confianca) >= 30.0: return "confia"
	return "indiferente"


func on_event(e: GameEvent) -> Array:
	if e.event_type == "PROLOGUE_STARTED":
		# vínculos do começo: família, mentor ou comunidade já se conhecem do jogador
		var perda := str(e.payload.get("recent", "")) == "perda"
		for c in e.payload.get("contacts", []):
			var r := _pair(str(c), "player")
			r.familiaridade = maxf(float(r.familiaridade), 12.0)
			r.confianca = maxf(float(r.confianca), 10.0)
			r.afeto = maxf(float(r.afeto), 20.0 if perda else 10.0)
			_marcar_amigo(str(c), "player")
		return []
	if e.event_type != "MEMORY_FORMED":
		return []
	var who: String = e.payload.npc
	var about: String = e.payload.about
	if who == about or about == "desconhecido" or about == "":
		return []
	var v := float(e.payload.valence)
	var emotion := str(e.payload.get("emotion", ""))
	var t: Array = world.npc_def(who).get("traits", [])
	var gain := 0.6 if t.has("teimoso") else 1.0
	if v < 0.0 and t.has("memoria_longa"):
		gain *= 1.3
	if v > 0.0 and t.has("exige_provas"):
		gain *= 0.5
	var r := _pair(who, about)
	r.familiaridade = minf(MAX_VALUE, float(r.familiaridade) + 3.0)
	if v > 0.0:
		r.confianca = _clamp(float(r.confianca) + v * 0.5 * gain)
		r.afeto = _clamp(float(r.afeto) + v * 0.5 * gain)
		_marcar_amigo(who, about)
		r.respeito = _clamp(float(r.respeito) + v * 0.25 * gain)
	elif v < 0.0:
		r.confianca = _clamp(float(r.confianca) + v * 0.5 * gain)
		r.ressentimento = _clamp(float(r.ressentimento) - v * 0.6 * gain)
		r.afeto = _clamp(float(r.afeto) + v * 0.3 * gain)
		_marcar_amigo(who, about)
		if emotion == "raiva" or emotion == "medo":
			r.medo = _clamp(float(r.medo) - v * 0.3 * gain)
	return []


## Convivência: quem divide o mesmo local ganha familiaridade aos poucos.
func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	var npcs = world.module("npcs")
	if npcs == null:
		return []
	# agrupa por local numa passada só (antes: uma varredura completa por local)
	var seen: Dictionary = {}
	for id in npcs.state:
		var s: Dictionary = npcs.state[id]
		var loc := str(s.get("location", ""))
		if loc == "" or not s.get("alive", false):
			continue
		if not seen.has(loc):
			seen[loc] = []
		seen[loc].append(id)
	# C15: o laço é quadrático no tamanho do grupo; por isso cada linha de rel é buscada uma vez por morador,
	# o par completo não passa por _pair e quem já está no teto de familiaridade não é regravado.
	var n_dims := DIMS.size()
	for loc in seen:
		var here: Array = seen[loc]
		if here.size() < 2:
			continue
		for a in here:
			if not rel.has(a):
				rel[a] = {}
			var row: Dictionary = rel[a]
			for b in here:
				if a == b:
					continue
				var r = row.get(b)
				if r == null or (r as Dictionary).size() < n_dims:
					r = _pair(a, b)
				var f := float(r.familiaridade)
				if f < MAX_VALUE:
					r.familiaridade = minf(MAX_VALUE, f + FAMILIARITY_PER_HOUR)
	return []


## Conversa entre dois moradores: familiaridade e um pouco de afeto nos dois sentidos.
func registrar_conversa(a: String, b: String) -> void:
	for pair in [[a, b], [b, a]]:
		var r := _pair(pair[0], pair[1])
		r.familiaridade = minf(MAX_VALUE, float(r.familiaridade) + 2.0)
		r.afeto = _clamp(float(r.afeto) + 0.5)
		_marcar_amigo(pair[0], pair[1])


## Quem tem afeto acima de AMIGO_ACIMA por quem (ordem não importa para quem consulta).
func amigos_de(id: String) -> Array:
	return amigos.get(id, [])


## Reconstrói o índice de amigos a partir de rel (após carregar, ou quando rel é editado direto).
func reindexar_amigos() -> void:
	amigos = {}
	for who in rel:
		for about in rel[who]:
			_marcar_amigo(who, about)


func _marcar_amigo(who: String, about: String) -> void:
	var lista: Array = amigos.get(who, [])
	var acima := float(rel[who][about].get("afeto", 0.0)) > AMIGO_ACIMA
	if acima and not lista.has(about):
		lista.append(about)
	elif not acima and lista.has(about):
		lista.erase(about)
	amigos[who] = lista


func _pair(who: String, about: String) -> Dictionary:
	if not rel.has(who):
		rel[who] = {}
	if not rel[who].has(about):
		rel[who][about] = {}
	var r: Dictionary = rel[who][about]
	for d in DIMS:
		if not r.has(d):
			r[d] = 0.0
	return r


func _clamp(x: float) -> float:
	return clampf(x, -MAX_VALUE, MAX_VALUE)


## Só grava pares com alguma dimensão sensível (|valor| >= 0,5), com uma casa decimal.
## Sem isso, todo par de moradores que já dividiu um local entra no save, e ele cresce sem limite.
func to_dict() -> Dictionary:
	var out := {}
	for who in rel:
		for about in rel[who]:
			var r: Dictionary = rel[who][about]
			var kept := {}
			for d in DIMS:
				var v := float(r.get(d, 0.0))
				if absf(v) >= 0.5:
					kept[d] = snappedf(v, 0.1)
			if not kept.is_empty():
				if not out.has(who):
					out[who] = {}
				out[who][about] = kept
	return {"rel": out}


func from_dict(d: Dictionary) -> void:
	rel = d.get("rel", {}).duplicate(true)
	for who in rel:
		for about in rel[who]:
			for k in rel[who][about]:
				rel[who][about][k] = float(rel[who][about][k])
	reindexar_amigos()
