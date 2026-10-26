class_name NpcLifeModule
extends WorldModule
## Vida dos moradores: o que cada um ESTÁ FAZENDO agora e COMO se sente. ORIGINAL_DO_JOGO.
## - Atividade (pura, derivada de agenda, hora, clima, evento, humor): forjando, moendo, dormindo, comendo, vendendo...
## - Humor: medo (mortes, ferimentos, capturas, combate na vila) e alegria (festa, feira, resgate), com decaimento por hora.
## - Reação: quem está com medo corre para casa até acalmar. Guardas e presos não mudam de lugar.
## Não decide resultados de regras; só onde o morador está e o que a apresentação e o diálogo mostram.

const FEAR_DECAY_PER_HOUR := 0.2
const JOY_DECAY_PER_HOUR := 0.12
const FEAR_HOME_AT := 0.5          # a partir daqui o morador se recolhe
const STAY_PUT := ["guarda_dia", "guarda_noite"]

## Verbo do trabalho por profissão (fala/rótulo/animação).
const WORK_VERB := {
	"ferreiro": "forjando", "moleiro": "moendo grão", "ajudante de moleiro": "carregando sacos", "lavrador": "lavrando", "lavradora": "lavrando",
	"fiandeira": "fiando", "pastora": "pastoreando", "mercadora": "negociando", "mercadora viajante": "negociando", "taverneira": "servindo",
	"cozinheiro": "cozinhando", "clériga de Lena": "atendendo fiéis", "acólito": "estudando as preces", "caçador": "rastreando",
	"alcaide": "despachando", "guarda": "patrulhando", "capitã da guarda": "vigiando a vila", "guarda aposentado": "vigiando de longe",
	"aprendiz": "aprendendo o ofício", "bêbado": "bebendo", "criança": "brincando",
}
const WORKING := ["forjando", "moendo grão", "carregando sacos", "lavrando", "fiando", "pastoreando", "servindo", "cozinhando", "estudando as preces", "despachando", "aprendendo o ofício"]

var mood: Dictionary = {}   # id -> {"fear": float, "joy": float}


func module_id() -> String: return "npc_life"
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["NPC_DIED", "NPC_WOUNDED", "NPC_CAPTURED", "NPC_RESCUED", "COMBAT_STARTED", "TOWN_EVENT_STARTED", "TOWN_EVENT_ENDED"])


func _m(id: String) -> Dictionary:
	if not mood.has(id):
		mood[id] = {"fear": 0.0, "joy": 0.0}
	return mood[id]


func fear(id: String) -> float:
	return float(mood.get(id, {}).get("fear", 0.0))


func joy(id: String) -> float:
	return float(mood.get(id, {}).get("joy", 0.0))


func _bump(id: String, key: String, amount: float) -> void:
	var m := _m(id)
	m[key] = clampf(float(m[key]) + amount, 0.0, 1.0)


func _relatives(id: String) -> Array:
	var fam := str(world.npc_def(id).get("family", ""))
	var out: Array = []
	if fam == "":
		return out
	for other in world.all_npc_ids():
		if other != id and str(world.npc_def(other).get("family", "")) == fam:
			out.append(other)
	return out


func on_event(e: GameEvent) -> Array:
	var npcs = world.module("npcs")
	if npcs == null:
		return []
	match e.event_type:
		"NPC_DIED", "NPC_WOUNDED", "NPC_CAPTURED":
			var who := str(e.payload.get("npc", ""))
			var loc := str(npcs.npc(who).get("location", e.payload.get("location", "")))
			var amount := 1.0 if e.event_type == "NPC_DIED" else 0.7
			for id in _relatives(who):
				_bump(id, "fear", amount)
			for id in npcs.npcs_at(loc):
				if id != who:
					_bump(id, "fear", amount * 0.6)
		"NPC_RESCUED":
			var who2 := str(e.payload.get("npc", ""))
			for id in _relatives(who2):
				_bump(id, "joy", 1.0)
				_m(id)["fear"] = 0.0
			for id in npcs.state:
				_bump(id, "joy", 0.35)
		"COMBAT_STARTED":
			if world.db.zone_at(world.db.world_to_tile(world.player.position)) == "vila":
				for id in npcs.state:
					_bump(id, "fear", 0.6)
		"TOWN_EVENT_STARTED":
			var amt := 0.9 if e.payload.get("event", "") == "festa" else 0.4
			for id in npcs.state:
				_bump(id, "joy", amt)
		"TOWN_EVENT_ENDED":
			pass
	return []


func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	for id in mood:
		var m: Dictionary = mood[id]
		m.fear = maxf(0.0, float(m.fear) - FEAR_DECAY_PER_HOUR)
		m.joy = maxf(0.0, float(m.joy) - JOY_DECAY_PER_HOUR)
	return []


## Quem está assustado se recolhe em casa (guardas e presos ficam). Devolve "" se nada muda.
func location_override(id: String, d: Dictionary, age: int) -> String:
	if not enabled or STAY_PUT.has(str(d.get("schedule", ""))) or age < 6:
		return ""
	if fear(id) >= FEAR_HOME_AT:
		return str(d.home)
	return ""


## O que o morador está fazendo agora. Puro: depende só do estado do mundo.
func activity(id: String) -> String:
	var npcs = world.module("npcs")
	if npcs == null:
		return ""
	var s: Dictionary = npcs.npc(id)
	if s.is_empty() or not s.alive:
		return ""
	if s.captive:
		return "preso"
	var d := world.npc_def(id)
	var prof := str(d.get("profession", ""))
	var loc := str(s.location)
	var h := world.hour()
	var te = world.module("town_events")
	if int(s.wounded_until) > world.clock.tick:
		return "descansando, ferido"
	if fear(id) >= FEAR_HOME_AT and loc == str(d.home) and not STAY_PUT.has(str(d.get("schedule", ""))):
		return "assustado, em casa"
	if loc == str(d.home) and (h < 6 or h >= 22):
		return "dormindo"
	if te != null and te.is_active("festa") and loc == "praca":
		return "brincando na festa" if int(s.age) < 12 else "dançando na festa"
	if te != null and te.is_active("feira") and loc == "mercado":
		return "vendendo na feira" if prof in ["mercadora", "mercadora viajante", "ferreiro", "fiandeira", "cozinheiro", "pastora"] else "olhando as barracas"
	if prof == "criança":
		return "brincando" if loc in ["praca", "campos", "mercado"] else ("estudando as preces" if loc == "templo" else "em casa")
	if loc == "taverna" and str(d.work) != "taverna":
		return "comendo" if h in [12, 13] else "bebendo e conversando"
	if loc == str(d.work) or (loc == "praca" and prof in ["guarda", "capitã da guarda"]):
		return str(WORK_VERB.get(prof, "trabalhando"))
	if loc == "ponte" and prof == "guarda":
		return "vigiando a ponte"
	if loc == "templo":
		return "rezando"
	if loc == str(d.home):
		return "em casa"
	if loc == "praca":
		return "conversando na praça"
	return "ocupado"


func is_working(id: String) -> bool:
	return WORKING.has(activity(id))


func to_dict() -> Dictionary: return {"mood": mood.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	mood = d.get("mood", {}).duplicate(true)
