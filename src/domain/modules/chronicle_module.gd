class_name ChronicleModule
extends WorldModule
## Diário vivo e crônicas do reino (Arton Viva, Fase 9). ORIGINAL_DO_JOGO.
## Registra acontecimentos históricos de cada área (§19.2): política, economia, Tormenta, guildas, vida de moradores.
## É a VERDADE da simulação: o que aconteceu. O que o jogador sabe é outra coisa e não sai daqui.
## Também consome fatos que antes ninguém escutava (auditoria de eventos, pendência O2).

const CAP := 200

var entries: Array = []   # [{id, tick, category, text}]
var _seq := 0


func module_id() -> String: return "chronicle"
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["LEADERSHIP_CHANGED", "CITY_STATUS_CHANGED", "TORMENTA_STAGE_CHANGED", "ROUTE_CHANGED",
		"GUILD_CREATED", "PARTY_LOST", "NPC_DIED",
		"MYSTERY_LOST", "FACTION_ALERTED", "STOLEN_GOODS_RECOVERED"])


func on_event(e: GameEvent) -> Array:
	var cat := ""
	var text := ""
	match e.event_type:
		"LEADERSHIP_CHANGED":
			cat = "guildas"
			text = "A organização %s trocou de liderança: %s." % [e.payload.faction, _nome(str(e.payload.to))] if str(e.payload.to) != "" else "A organização %s ficou sem líder." % e.payload.faction
		"CITY_STATUS_CHANGED":
			cat = "economia"
			text = "A vila entrou em decadência." if e.payload.status == "em_decadencia" else "A vila se recuperou."
		"TORMENTA_STAGE_CHANGED":
			cat = "tormenta"
			text = "A corrupção da Tormenta chegou ao estágio %d." % int(e.payload.stage)
		"ROUTE_CHANGED":
			cat = "economia"
			text = "A rota %s foi reaberta." % e.payload.route if bool(e.payload.open) else "A rota %s foi fechada." % e.payload.route
		"GUILD_CREATED":
			cat = "guildas"
			text = "A guilda %s foi registrada." % e.payload.name
		"PARTY_LOST":
			cat = "vida"
			text = "%s deixou o grupo." % _nome(str(e.payload.npc))
		"NPC_DIED":
			cat = "vida"
			text = "%s morreu." % _nome(str(e.payload.npc))
		"MYSTERY_LOST":
			cat = "politica"
			text = "Uma pista do mistério se perdeu para sempre."
		"FACTION_ALERTED":
			cat = "politica"
			text = "A facção %s se pôs em alerta." % str(e.payload.get("faction", ""))
		"STOLEN_GOODS_RECOVERED":
			cat = "economia"
			text = "Mercadoria roubada foi recuperada e voltou ao estoque."
	if cat == "":
		return []
	_seq += 1
	entries.append({"id": _seq, "tick": e.world_tick, "category": cat, "text": text})
	if entries.size() > CAP:
		entries = entries.slice(entries.size() - CAP)
	return []


func _nome(id: String) -> String:
	var d := world.db.npc_def(id)
	return str(d.get("name", id))


func by_category(cat: String) -> Array:
	return entries.filter(func(x): return x.category == cat)


## Canal pelo qual a notícia chega ao jogador (§19.4). Só o canal; a verdade continua no diário.
const CHANNEL_BY_CATEGORY := {"economia": "mercador", "tormenta": "mensageiro", "guildas": "taverneiro",
	"politica": "taverneiro", "vida": "taverneiro"}


func news_via(channel: String) -> Array:
	return entries.filter(func(x): return CHANNEL_BY_CATEGORY.get(x.category, "taverneiro") == channel)


func to_dict() -> Dictionary: return {"entries": entries.duplicate(true), "seq": _seq}


func from_dict(d: Dictionary) -> void:
	entries = d.get("entries", []).duplicate(true)
	_seq = int(d.get("seq", 0))
