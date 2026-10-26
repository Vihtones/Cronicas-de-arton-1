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
		r.respeito = _clamp(float(r.respeito) + v * 0.25 * gain)
	elif v < 0.0:
		r.confianca = _clamp(float(r.confianca) + v * 0.5 * gain)
		r.ressentimento = _clamp(float(r.ressentimento) - v * 0.6 * gain)
		r.afeto = _clamp(float(r.afeto) + v * 0.3 * gain)
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
	var seen := {}
	for id in npcs.state:
		var loc := str(npcs.npc(id).get("location", ""))
		if loc == "" or not npcs.npc(id).get("alive", false):
			continue
		if not seen.has(loc):
			seen[loc] = npcs.npcs_at(loc)
	for loc in seen:
		var here: Array = seen[loc]
		for a in here:
			for b in here:
				if a != b:
					var r := _pair(a, b)
					r.familiaridade = minf(MAX_VALUE, float(r.familiaridade) + FAMILIARITY_PER_HOUR)
	return []


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


func to_dict() -> Dictionary:
	return {"rel": rel.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	rel = d.get("rel", {}).duplicate(true)
	for who in rel:
		for about in rel[who]:
			for k in rel[who][about]:
				rel[who][about][k] = float(rel[who][about][k])
