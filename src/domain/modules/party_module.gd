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
const CONTRACT_LOYALTY_GAIN := 5.0   # lealdade de quem cumpre um contrato
const SHARE_LOYALTY_GAIN := 3.0      # lealdade de quem recebe parte do caixa da guilda

const Doencas := preload("res://src/domain/rules/doencas.gd")
const Parceiros := preload("res://src/domain/rules/parceiros.gd")

var members: Dictionary = {}   # npc_id -> {loyalty: float, order: String}
var guild: Dictionary = {}     # {} ou {name, members}
var last_day := -1
var parceiros: Array = []   # parceiros do jogador (LB p.260): {id, tipo, nivel, nome, especie, pericias, fonte, ate_dia (-1: sem fim)}
var caixa: int = 0                 # ouro da guilda (contratos pagam aqui; administração distribui)
var contratos: Dictionary = {}    # id da instância -> {contrato, membros, fim_dia}


func module_id() -> String: return "party"
func handled_commands() -> PackedStringArray: return PackedStringArray(["RecruitCompanion", "SetOrder", "CreateGuild", "AcceptContract", "GuildDistribute"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["NPC_DIED", "TIME_ADVANCED", "COMPANION_STATE"])

## Ficha de combate completa do companheiro, montada pelo construtor de personagens (raça, classe, atributos, equipamento).
func ficha_de(id: String) -> CharacterSheet:
	var d := world.db.npc_def(id)
	var f: Dictionary = d.get("combate", {"raca": "humano", "classe": "guerreiro", "preset": 1})
	var attrs: Dictionary = CharacterBuilder.presets(str(f.classe))[int(f.preset)]
	var sh := CharacterBuilder.build(world.rules, str(f.raca), str(f.classe), attrs, ["for", "des", "con"], str(d.get("name", id)))
	CharacterBuilder.apply_equipment(world.rules, sh)
	return sh


## Onde o companheiro está agora: o destino do contrato em curso, ou "" se não estiver em serviço.
func destino_de(id: String) -> String:
	for c in contratos.values():
		if c.membros.has(id):
			return str(_contrato_def(c.contrato).get("destino", ""))
	return ""


func _contrato_def(id: String) -> Dictionary:
	return world.db.economy.get("contratos_guilda", {}).get(id, {})


func _livres() -> Array:
	var ocupados := {}
	for c in contratos.values():
		for m in c.membros:
			ocupados[m] = true
	var out: Array = []
	for id in members:
		if not ocupados.has(id):
			out.append(id)
	out.sort()
	return out


func validate(cmd: GameCommand) -> PackedStringArray:
	match cmd.type:
		"RecruitCompanion": return _validate_recruit(cmd)
		"SetOrder":
			if not members.has(str(cmd.payload.get("npc_id", ""))):
				return PackedStringArray(["não é membro da party"])
			if not ORDERS.has(str(cmd.payload.get("order", ""))):
				return PackedStringArray(["ordem desconhecida"])
			return PackedStringArray()
		"AcceptContract":
			if guild.is_empty():
				return PackedStringArray(["sem guilda não há contratos"])
			var d := _contrato_def(str(cmd.payload.get("contrato", "")))
			if d.is_empty():
				return PackedStringArray(["contrato desconhecido"])
			if _livres().size() < int(d.membros_min):
				return PackedStringArray(["membros livres insuficientes (precisa de %d)" % int(d.membros_min)])
			return PackedStringArray()
		"GuildDistribute":
			if guild.is_empty():
				return PackedStringArray(["sem guilda não há caixa"])
			if members.is_empty():
				return PackedStringArray(["não há membros para receber o caixa"])
			if caixa <= 0:
				return PackedStringArray(["o caixa da guilda está vazio"])
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
			members[id] = {"loyalty": 0.0, "order": "seguir", "sheet": ficha_de(id).to_dict()}
			var out: Array = [fact("PARTY_JOINED", {"npc": id}, [id])]
			if pagou > 0:
				out.append(fact("GOLD_CHANGED", {"delta": -pagou, "reason": "contrato de companheiro"}))
			return out
		"SetOrder":
			var id := str(cmd.payload.npc_id)
			members[id].order = str(cmd.payload.order)
			return [fact("ORDER_SET", {"npc": id, "order": members[id].order}, [id])]
		"AcceptContract":
			var d := _contrato_def(str(cmd.payload.contrato))
			var escolhidos: Array = _livres().slice(0, int(d.membros_min))
			var id := "%s_%d" % [cmd.payload.contrato, world.day_index()]
			var fim := world.day_index() + int(d.dias)
			contratos[id] = {"contrato": cmd.payload.contrato, "membros": escolhidos, "fim_dia": fim}
			return [fact("CONTRACT_ACCEPTED", {"contrato": cmd.payload.contrato, "membros": escolhidos, "fim_dia": fim})]
		"GuildDistribute":
			var n := members.size()
			var parte := caixa / n
			caixa -= parte * n
			for id in members:
				members[id].loyalty = minf(100.0, float(members[id].loyalty) + SHARE_LOYALTY_GAIN)
			return [fact("GUILD_SHARED", {"por_membro": parte, "membros": n})]
		"CreateGuild":
			guild = {"name": str(cmd.payload.get("name", "Guilda")), "members": members.keys()}
			guild.members.sort()
			return [fact("GOLD_CHANGED", {"delta": -GUILD_COST, "reason": "registro de guilda"}), fact("GUILD_CREATED", {"name": guild.name, "members": guild.members})]
	return []


func on_event(e: GameEvent) -> Array:
	if e.event_type == "NPC_DIED":
		var id := str(e.payload.get("npc", ""))
		var out: Array = []
		# contrato em curso com o morto falha: sem pagamento, os outros voltam a ficar livres
		for cid in contratos.keys():
			if contratos[cid].membros.has(id):
				out.append(fact("CONTRACT_FAILED", {"contrato": contratos[cid].contrato, "npc": id}, [id]))
				contratos.erase(cid)
		if members.erase(id):
			out.append(fact("PARTY_LOST", {"npc": id, "cause": "morte"}, [id]))
		return out
	if e.event_type == "COMPANION_STATE":
		var id := str(e.payload.get("npc", ""))
		if members.has(id):
			members[id].sheet = e.payload.sheet
		return []
	if e.event_type == "TIME_ADVANCED" and world.day_index() != last_day:
		last_day = world.day_index()
		var doentes: Array = []
		if world.player_sheet != null:
			world.player_sheet.limpar_dia(world.day_index())   # efeitos de magia "por um dia" acabam
			doentes.append_array(_teste_de_doencas("player", world.player_sheet))
		for id_d in members:
			var f_d := CharacterSheet.from_dict(members[id_d].sheet) if members[id_d].has("sheet") else ficha_de(id_d)
			f_d.limpar_dia(world.day_index())
			doentes.append_array(_teste_de_doencas(id_d, f_d))
			if members[id_d].has("sheet") or not f_d.doencas.is_empty():
				members[id_d].sheet = f_d.to_dict()
		var rituais: Array = doentes
		rituais.append_array(_parceiros_expirados())
		var combat = world.module("combat")
		if combat != null:
			rituais = combat.processar_rituais_do_dia()   # Lágrimas de Wynna: o ritual de um dia termina aqui
		for id in members:
			members[id].loyalty = minf(100.0, float(members[id].loyalty) + 1.0)
			_descansa(id)
		return rituais + _resolve_contracts()
	return []


## Parceiro novo do jogador (magia, habilidade, contrato). Devolve o erro ("" se entrou). Os bônus são reaplicados.
func adicionar_parceiro(p: Dictionary) -> String:
	var err := Parceiros.validar(world.rules, p)
	if err != "":
		return err
	remover_parceiro(str(p.id))
	parceiros.append(p.duplicate(true))
	_reaplicar_parceiros()
	return ""


func remover_parceiro(id: String) -> void:
	parceiros = parceiros.filter(func(p): return str(p.id) != id)
	_reaplicar_parceiros()


func parceiro(id: String) -> Dictionary:
	for p in parceiros:
		if str(p.id) == id:
			return p
	return {}


func _reaplicar_parceiros() -> void:
	if world.player_sheet != null:
		Parceiros.aplicar(world.player_sheet, parceiros, world.rules)


## Parceiros temporários (Aliado Animal) que acabam hoje.
func _parceiros_expirados() -> Array:
	var out: Array = []
	for p in parceiros.duplicate(true):
		if int(p.get("ate_dia", -1)) >= 0 and world.day_index() >= int(p.ate_dia):
			remover_parceiro(str(p.id))
			out.append(fact("PARTNER_LEFT", {"partner": str(p.id), "fonte": str(p.get("fonte", ""))}, ["player"]))
	return out


## Doenças (LB p.318): o teste de Fortitude do início do dia de quem está contaminado.
func _teste_de_doencas(quem: String, f: CharacterSheet) -> Array:
	var out: Array = []
	for r in Doencas.teste_diario(f, world.rules, world.rng, "world", world.day_index()):
		r["who"] = quem
		out.append(fact("DISEASE_CHECK", r, [quem]))
	return out


## Muda a ficha guardada de um companheiro (magias lançadas nele fora de combate). `fn` recebe a CharacterSheet.
func aplicar_na_ficha(id: String, fn: Callable) -> void:
	if not members.has(id):
		return
	var sh := CharacterSheet.from_dict(members[id].sheet) if members[id].has("sheet") else ficha_de(id)
	fn.call(sh)
	members[id].sheet = sh.to_dict()


## Um dia de descanso recupera um quarto dos PV máximos (companheiro ferido não entra em luta até se recuperar).
## Efeitos de magia "por um dia" também acabam.
func _descansa(id: String) -> void:
	var sh := CharacterSheet.from_dict(members[id].sheet) if members[id].has("sheet") else ficha_de(id)
	sh.limpar_dia(world.day_index())
	sh.pv = mini(sh.pv_max, sh.pv + maxi(1, sh.pv_max / 4))
	members[id].sheet = sh.to_dict()


## Contratos que chegaram ao prazo: pagam ao caixa da guilda e dão lealdade aos que cumpriram.
func _resolve_contracts() -> Array:
	var out: Array = []
	for cid in contratos.keys():
		var c: Dictionary = contratos[cid]
		if world.day_index() < int(c.fim_dia):
			continue
		var pago := int(_contrato_def(c.contrato).get("pagamento", 0))
		caixa += pago
		for id in c.membros:
			if members.has(id):
				members[id].loyalty = minf(100.0, float(members[id].loyalty) + CONTRACT_LOYALTY_GAIN)
		contratos.erase(cid)
		out.append(fact("CONTRACT_DONE", {"contrato": c.contrato, "pagamento": pago, "membros": c.membros}))
	return out


func to_dict() -> Dictionary:
	return {"members": members.duplicate(true), "guild": guild.duplicate(true), "last_day": last_day, "caixa": caixa, "contratos": contratos.duplicate(true), "parceiros": parceiros.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	members = d.get("members", {}).duplicate(true)
	guild = d.get("guild", {}).duplicate(true)
	last_day = int(d.get("last_day", -1))
	caixa = int(d.get("caixa", 0))
	contratos = d.get("contratos", {}).duplicate(true)
	parceiros = (d.get("parceiros", []) as Array).duplicate(true)
