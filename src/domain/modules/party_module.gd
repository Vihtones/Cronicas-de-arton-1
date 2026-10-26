class_name PartyModule
extends WorldModule
## Party e guildas (Arton Viva, Fase 6). ORIGINAL_DO_JOGO (homebrew: companheiros e guilda).
## - Recrutamento exige consentimento: confiança e familiaridade com o jogador, e pagamento ou afeto.
##   Não há controle mental: reputação alta sozinha não recruta ninguém.
## - Membros têm lealdade própria, que cresce a cada dia em grupo. Quem morre sai da party (PARTY_LOST).
## - Ordens (seguir, proteger, manter_posição, recuar) são guardadas; o combate as usará na fase de integração.
## - Guilda: exige pelo menos dois membros e ouro; é criada uma única vez.

const MIN_AGE := 16
const RECRUIT_TRUST := 20.0
const RECRUIT_FAMILIARITY := 15.0
const RECRUIT_FEE := 10
const GUILD_COST := 50
const GUILD_MIN_MEMBERS := 2
const ORDERS := ["seguir", "proteger", "manter_posicao", "recuar"]

var members: Dictionary = {}   # npc_id -> {loyalty: float, order: String}
var guild: Dictionary = {}     # {} ou {name, members}
var last_day := -1


func module_id() -> String: return "party"
func handled_commands() -> PackedStringArray: return PackedStringArray(["RecruitCompanion", "SetOrder", "CreateGuild"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["NPC_DIED", "TIME_ADVANCED"])


func validate(cmd: GameCommand) -> PackedStringArray:
	match cmd.type:
		"RecruitCompanion": return _validate_recruit(cmd)
		"SetOrder":
			if not members.has(str(cmd.payload.get("npc_id", ""))):
				return PackedStringArray(["não é membro da party"])
			if not ORDERS.has(str(cmd.payload.get("order", ""))):
				return PackedStringArray(["ordem desconhecida"])
			return PackedStringArray()
		"CreateGuild":
			if not guild.is_empty():
				return PackedStringArray(["a guilda já existe"])
			if members.size() < GUILD_MIN_MEMBERS:
				return PackedStringArray(["a guilda precisa de pelo menos %d membros" % GUILD_MIN_MEMBERS])
			if int(world.player.gold) < GUILD_COST:
				return PackedStringArray(["ouro insuficiente para registrar a guilda"])
			return PackedStringArray()
	return PackedStringArray(["comando desconhecido"])


func _validate_recruit(cmd: GameCommand) -> PackedStringArray:
	var id := str(cmd.payload.get("npc_id", ""))
	var npcs = world.module("npcs")
	if npcs == null or npcs.npc(id).is_empty():
		return PackedStringArray(["morador inexistente"])
	if members.has(id):
		return PackedStringArray(["já está na party"])
	if not npcs.npc(id).get("alive", false) or npcs.npc(id).get("captive", false):
		return PackedStringArray(["não pode se juntar agora"])
	if int(world.npc_def(id).get("age", 0)) < MIN_AGE:
		return PackedStringArray(["é jovem demais para se juntar"])
	var rl = world.module("relations")
	var r: Dictionary = rl.dims(id, "player") if rl != null else {}
	var pagou := int(cmd.payload.get("pay", 0))
	var confia := float(r.get("confianca", 0.0)) >= RECRUIT_TRUST and float(r.get("familiaridade", 0.0)) >= RECRUIT_FAMILIARITY
	if not confia and pagou < RECRUIT_FEE:
		return PackedStringArray(["não confia em você o bastante, e o pagamento não cobre o risco"])
	if pagou > int(world.player.gold):
		return PackedStringArray(["ouro insuficiente para pagar"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"RecruitCompanion":
			var id := str(cmd.payload.npc_id)
			var pagou := int(cmd.payload.get("pay", 0))
			members[id] = {"loyalty": 0.0, "order": "seguir"}
			var out: Array = [fact("PARTY_JOINED", {"npc": id}, [id])]
			if pagou > 0:
				out.append(fact("GOLD_CHANGED", {"delta": -pagou, "reason": "contrato de companheiro"}))
			return out
		"SetOrder":
			var id := str(cmd.payload.npc_id)
			members[id].order = str(cmd.payload.order)
			return [fact("ORDER_SET", {"npc": id, "order": members[id].order}, [id])]
		"CreateGuild":
			guild = {"name": str(cmd.payload.get("name", "Guilda")), "members": members.keys()}
			guild.members.sort()
			return [fact("GOLD_CHANGED", {"delta": -GUILD_COST, "reason": "registro de guilda"}), fact("GUILD_CREATED", {"name": guild.name, "members": guild.members})]
	return []


func on_event(e: GameEvent) -> Array:
	if e.event_type == "NPC_DIED":
		var id := str(e.payload.get("npc", ""))
		if members.erase(id):
			return [fact("PARTY_LOST", {"npc": id, "cause": "morte"}, [id])]
		return []
	if e.event_type == "TIME_ADVANCED" and world.day_index() != last_day:
		last_day = world.day_index()
		for id in members:
			members[id].loyalty = minf(100.0, float(members[id].loyalty) + 1.0)
	return []


func to_dict() -> Dictionary:
	return {"members": members.duplicate(true), "guild": guild.duplicate(true), "last_day": last_day}


func from_dict(d: Dictionary) -> void:
	members = d.get("members", {}).duplicate(true)
	guild = d.get("guild", {}).duplicate(true)
	last_day = int(d.get("last_day", -1))
