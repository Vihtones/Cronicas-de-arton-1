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
		"MYSTERY_LOST", "FACTION_ALERTED", "STOLEN_GOODS_RECOVERED", "SHORTAGE_STARTED", "SHORTAGE_ENDED", "TRADE_DELIVERED", "CONTRACT_DONE", "CONTRACT_FAILED", "GUILD_SHARED"])


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
		"SHORTAGE_STARTED":
			cat = "economia"
			text = "Está faltando %s na vila: o estoque caiu bem abaixo do normal." % _bem(str(e.payload.good))
		"SHORTAGE_ENDED":
			cat = "economia"
			text = "O estoque de %s na vila voltou ao normal." % _bem(str(e.payload.good))
		"ROUTE_CHANGED":
			cat = "economia"
			text = "A %s foi reaberta." % _rota(str(e.payload.route)) if bool(e.payload.open) else "A %s foi fechada." % _rota(str(e.payload.route))
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
			text = "Os bandidos deixaram a cripta e levaram o rapaz. O caso do sumiço ficou sem solução."
		"FACTION_ALERTED":
			cat = "politica"
			text = "A facção %s está em alerta." % _faccao(str(e.payload.get("faction", "")))
		"STOLEN_GOODS_RECOVERED":
			if str(e.payload.get("owner", "")) == "guilda":
				return []   # encomenda da guilda não é furto
			cat = "economia"
			text = "Apareceu algo que tinham roubado: %s (dono: %s)." % [_item(str(e.payload.get("item", ""))), _dono(str(e.payload.get("owner", "")))]
		"CONTRACT_DONE":
			cat = "guildas"
			text = "A guilda cumpriu o contrato \"%s\" e recebeu T$ %d." % [_contrato_nome(str(e.payload.contrato)), int(e.payload.pagamento)]
		"CONTRACT_FAILED":
			cat = "guildas"
			text = "O contrato \"%s\" fracassou: %s morreu no meio do serviço." % [_contrato_nome(str(e.payload.contrato)), _nome(str(e.payload.npc))]
		"GUILD_SHARED":
			cat = "guildas"
			text = "A guilda dividiu o caixa: T$ %d para cada um dos %d membros." % [int(e.payload.por_membro), int(e.payload.membros)]
		"TRADE_DELIVERED":
			cat = "economia"
			var partes := PackedStringArray()
			for g in e.payload.goods:
				partes.append("%d de %s" % [int(e.payload.goods[g]), _bem(str(g))])
			text = "%s trouxe mercadoria de fora: %s." % [_nome(str(e.payload.by)), ", ".join(partes)]
	if cat == "":
		return []
	_seq += 1
	entries.append({"id": _seq, "tick": e.world_tick, "category": cat, "text": text})
	if entries.size() > CAP:
		entries = entries.slice(entries.size() - CAP)
	if not NAO_CORRE.has(e.event_type):
		_espalhar(_seq, cat, text, e.world_tick)
	return []


## Notícias que correm (Fase 9, rumores históricos): o fato da crônica chega primeiro a quem traz notícia pelo
## canal da categoria (mercador, mensageiro, taverneiro) e entra na memória dele. Dali em diante, passa de
## boca em boca pelo sistema de rumores da MemoryModule, só entre quem divide o mesmo local, e some com o
## esquecimento normal. Quem não ouviu continua sem saber; o jogador sabe perguntando ("O que se conta por aí?").
## A morte já vira memória de luto das testemunhas, por isso não corre de novo por aqui.
const NAO_CORRE := ["NPC_DIED"]
const PROFISSOES_DO_CANAL := {
	"mercador": ["mercador", "mercadora", "mercadora viajante"],
	"mensageiro": ["mensageiro", "mercadora viajante"],
	"taverneiro": ["taverneiro", "taverneira", "estalajadeiro", "estalajadeira"],
}


## Quem recebe primeiro as notícias de um canal: moradores vivos e livres da vila (região "vila" da economia),
## com a profissão do canal, mais os mensageiros entre regiões no canal "mensageiro". Ordem do catálogo.
func portadores(channel: String) -> Array:
	var profs: Array = PROFISSOES_DO_CANAL.get(channel, [])
	var couriers: Array = []
	if channel == "mensageiro":
		for r in world.db.distant.get("regions", []):
			couriers.append(str(r.get("courier", "")))
	var zonas: Dictionary = world.db.economy.get("regioes_por_zona", {})
	var npcs = world.module("npcs")
	var out: Array = []
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		if not profs.has(str(d.get("profession", ""))) and not couriers.has(id):
			continue
		var zona := str(world.db.location(str(d.get("home", ""))).get("zone", ""))
		if str(zonas.get(zona, "vila")) != "vila":
			continue
		if npcs != null:
			var st: Dictionary = npcs.npc(id)
			if st.is_empty() or not st.get("alive", false) or st.get("captive", false):
				continue
		out.append(id)
	return out


func _espalhar(entry_id: int, cat: String, text: String, tick: int) -> void:
	var mem = world.module("memory")
	if mem == null:
		return
	var npcs = world.module("npcs")
	for id in portadores(CHANNEL_BY_CATEGORY.get(cat, "taverneiro")):
		var loc := str(npcs.npc(id).get("location", "")) if npcs != null else ""
		mem.add_memory(id, {"key": "cronica:%d" % entry_id, "about": "vila", "subject": "", "valence": 0, "location": loc,
			"tick": tick, "emotion": "neutro", "reliability": 1.0, "source": "noticia", "durable": false,
			"text": text, "categoria": cat})


func _faccao(id: String) -> String:
	for f in world.db.npcs.get("factions", []):
		if str(f.get("id", "")) == id:
			return str(f.get("name", id))
	return id if id != "" else "Uma facção"


func _item(id: String) -> String:
	return str(world.db.items.get(id, {}).get("name", id if id != "" else "Mercadoria"))


func _dono(id: String) -> String:
	if id == "":
		return "alguém"
	for f in world.db.npcs.get("factions", []):
		if str(f.get("id", "")) == id:
			return str(f.get("name", id))
	return _nome(id)


func _contrato_nome(id: String) -> String:
	return str(world.db.economy.get("contratos_guilda", {}).get(id, {}).get("nome", id))


func _rota(id: String) -> String:
	return str(world.db.economy.get("routes", {}).get(id, {}).get("nome", id))


func _bem(good: String) -> String:
	return str(EconomyModule.GOOD_NAMES.get(good, good))


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
