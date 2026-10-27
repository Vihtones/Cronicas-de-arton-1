class_name EconomyModule
extends WorldModule
## Economia agregada por região (§11): produção/consumo diários e preços com limites.
## Não simula cada moeda. O mensageiro leva mercadoria entre regiões. ORIGINAL_DO_JOGO.

var regions: Dictionary = {}
const FACTION_HOSTILE_AT := -20.0   # facção com reputação abaixo disso cobra 25% a mais de todos os seus vendedores
const FACTION_FRIENDLY_AT := 30.0   # acima disso, 10% de desconto
var treasury := 0  # ouro pago em refeições da vila (circulação monetária, ORIGINAL_DO_JOGO)
const SHORTAGE_AT := 0.3        # estoque da vila abaixo de 30% da meta: falta do bem (crise de escassez)
const SHORTAGE_END_AT := 0.7    # só acaba acima de 70% (histerese: não oscila em torno do limite)
const GOOD_NAMES := {"comida": "comida", "bebida": "bebida", "ferramentas": "ferramentas", "remedio": "remédios"}
var shortage: Dictionary = {}   # bem -> true enquanto a vila está em falta (Fase 4)
var routes: Dictionary = {}  # id -> {from, to, open}: rota comercial entre regiões (Arton Viva, Fase 4)


func module_id() -> String: return "economy"
func handled_commands() -> PackedStringArray: return PackedStringArray(["Buy"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["DISTANT_EVENT", "NPC_MOVED", "DOMAIN_WEEK", "SHEEP_KILLED", "TOWN_EVENT_STARTED", "CART_DELIVERED", "WORK_DONE", "TOOL_BOUGHT", "MEAL_SERVED", "TORMENTA_DAY"])


func _ensure() -> void:
	if regions.is_empty():
		regions = world.db.economy.get("regions", {}).duplicate(true)
	if routes.is_empty():
		routes = world.db.economy.get("routes", {"valkaria_vila": {"nome": "estrada de Valkaria", "from": "valkaria", "to": "vila", "open": true}}).duplicate(true)


func price(item_id: String, region: String = "vila", seller: String = "") -> int:
	_ensure()
	var it: Dictionary = world.db.items.get(item_id, {})
	var base := int(it.get("price", 0))
	var mem = world.module("memory")
	if seller != "" and mem != null and mem.bias(seller, "player") < 0:
		base = int(ceil(base * 1.2))  # vendedor desconfiado cobra mais de estranhos (ORIGINAL)
	# consequência por grupo: a reputação da facção do vendedor muda o preço de todos os seus vendedores
	var fac = world.npc_def(seller).get("faction") if seller != "" else null
	if fac != null and mem != null:
		var fr: Dictionary = mem.faction_reputation(str(fac), "player")
		if int(fr.known_by) >= 1:
			if float(fr.value) <= FACTION_HOSTILE_AT:
				base = int(ceil(base * 1.25))
			elif float(fr.value) >= FACTION_FRIENDLY_AT:
				base = maxi(1, int(floor(base * 0.9)))
	var good: String = it.get("good", "")
	if good == "" or not regions.has(region):
		return base
	var r: Dictionary = regions[region]
	var lim: Array = world.db.economy.get("price_limits", [0.5, 3.0])
	var ratio := float(r.target[good]) / maxf(1.0, float(r.stock[good]))
	return maxi(1, int(round(base * clampf(ratio, float(lim[0]), float(lim[1])))))


func validate(cmd: GameCommand) -> PackedStringArray:
	_ensure()
	var npc: String = cmd.payload.get("npc_id", "")
	var item: String = cmd.payload.get("item", "")
	if not world.db.economy.get("shops", {}).get(npc, []).has(item):
		return PackedStringArray(["não vende isso"])
	var region := "vila"
	if npc == "valkaria_mercado":
		var tr = world.module("travel")
		if tr == null or tr.current_region != "valkaria":
			return PackedStringArray(["o mercado da capital fica em Valkaria"])
		region = "valkaria"
	else:
		var npcs = world.module("npcs")
		if npcs != null:
			var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
			if npcs.npc(npc).get("location", "") != loc:
				return PackedStringArray(["o vendedor não está aqui"])
	var good: String = world.db.items[item].get("good", "")
	if good != "" and int(regions[region].stock[good]) <= 0:
		return PackedStringArray(["em falta"])
	if int(world.player.gold) < price(item, region, npc):
		return PackedStringArray(["ouro insuficiente"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var item: String = cmd.payload.item
	var region := "valkaria" if cmd.payload.npc_id == "valkaria_mercado" else "vila"
	var p := price(item, region, cmd.payload.npc_id)
	var good: String = world.db.items[item].get("good", "")
	if good != "":
		regions[region].stock[good] = int(regions[region].stock[good]) - 1
	return [fact("GOLD_CHANGED", {"delta": -p, "reason": "compra"}), fact("ITEM_GAINED", {"item": item, "qty": 1}, ["player"]),
		fact("ITEM_BOUGHT", {"item": item, "price": p, "seller": cmd.payload.npc_id}, ["player", cmd.payload.npc_id])]


func on_tick(tick: int) -> Array:
	_ensure()
	if tick % (24 * 60 / world.clock.tick_minutes) != 0:
		return []
	for rid in regions:
		var r: Dictionary = regions[rid]
		for g in r.stock:
			r.stock[g] = maxi(0, int(r.stock[g]) + int(r.production[g]) - int(r.consumption[g]))
	var out: Array = [fact("ECONOMY_DAY", {"vila": regions.vila.stock.duplicate(), "treasury": treasury})]
	out.append_array(_shortage_facts())
	return out


## Crise de escassez com histerese: começa abaixo de SHORTAGE_AT da meta e termina acima de SHORTAGE_END_AT.
## Recuperação vem da própria produção (sem intervenção do jogador).
func _shortage_facts() -> Array:
	var out: Array = []
	var v: Dictionary = regions.vila
	var goods: Array = v.stock.keys()
	goods.sort()
	for g in goods:
		var target := maxf(1.0, float(v.target.get(g, 1)))
		var ratio := float(v.stock[g]) / target
		var em_falta := bool(shortage.get(g, false))
		if not em_falta and ratio < SHORTAGE_AT:
			shortage[g] = true
			out.append(fact("SHORTAGE_STARTED", {"good": g, "stock": int(v.stock[g]), "target": int(target)}))
		elif em_falta and ratio >= SHORTAGE_END_AT:
			shortage.erase(g)
			out.append(fact("SHORTAGE_ENDED", {"good": g, "stock": int(v.stock[g])}))
	return out


func on_event(e: GameEvent) -> Array:
	_ensure()
	match e.event_type:
		"DOMAIN_WEEK":
			regions.vila.stock.comida = int(regions.vila.stock.comida) + int(e.payload.get("food_out", 0))
		"TOWN_EVENT_STARTED":
			# feira traz mascates (estoque sobe); festa consome (ORIGINAL_DO_JOGO)
			var gd: Dictionary = e.payload.get("goods", {})
			for g in gd:
				if regions.vila.stock.has(g):
					regions.vila.stock[g] = maxi(0, int(regions.vila.stock[g]) + int(gd[g]))
		"CART_DELIVERED":
			# a carga da carroça entra no estoque da vila
			for g in e.payload.get("goods", {}):
				if regions.vila.stock.has(g):
					regions.vila.stock[g] = int(regions.vila.stock[g]) + int(e.payload.goods[g])
		"TOOL_BOUGHT":
			# ferramenta comprada por morador: o ouro vai ao tesouro e sai uma unidade do estoque da vila
			treasury += int(e.payload.get("price", 0))
			regions.vila.stock.ferramentas = maxi(0, int(regions.vila.stock.ferramentas) - 1)
		"WORK_DONE":
			# turno cumprido: o morador produz um bem da profissão (Arton Viva, Fase 1)
			var g := str(e.payload.get("good", ""))
			if regions.vila.stock.has(g):
				regions.vila.stock[g] = int(regions.vila.stock[g]) + int(e.payload.get("amount", 1))
		"TORMENTA_DAY":
			# corrupção em estágio de crise ou pior estraga a comida da vila (ORIGINAL_DO_JOGO)
			var est := int(e.payload.get("stage", 0))
			if est >= 3:
				regions.vila.stock.comida = maxi(0, int(regions.vila.stock.comida) - 5 * (est - 2))
		"MEAL_SERVED":
			# refeição paga na taverna: consome comida da vila e leva o ouro ao tesouro local
			regions.vila.stock.comida = maxi(0, int(regions.vila.stock.comida) - 1)
			treasury += int(e.payload.get("cost", 0))
		"SHEEP_KILLED":
			regions.vila.stock.comida = maxi(0, int(regions.vila.stock.comida) - 4 * int(e.payload.get("count", 1)))
		"DISTANT_EVENT":
			var eff: Dictionary = e.payload.get("effect", {}).get("economy", {})
			if not eff.is_empty() and regions.has(eff.region):
				var r: Dictionary = regions[eff.region]
				r.stock[eff.good] = maxi(0, int(r.stock[eff.good]) + int(eff.delta))
			# rota fechada ou reaberta (guerra, bloqueio, reabertura): reversível, sem perda de dados
			var rt: Dictionary = e.payload.get("effect", {}).get("route", {})
			if rt.has("id") and routes.has(rt.id):
				routes[rt.id].open = bool(rt.get("open", true))
				return [fact("ROUTE_CHANGED", {"route": rt.id, "open": routes[rt.id].open})]
		"NPC_MOVED":
			# Mensageiro chegando de Valkaria traz mercadoria que falta na vila.
			for reg in world.db.distant.get("regions", []):
				if e.payload.npc == reg.courier and e.payload.from == reg.id:
					if not _route_open(reg.id):
						return []  # rota fechada: o mensageiro chega sem carga
					var moved := {}
					for g in regions.vila.stock:
						var deficit := int(regions.vila.target[g]) - int(regions.vila.stock[g])
						var avail := int(regions[reg.id].stock[g]) / 50
						var q := clampi(deficit, 0, mini(avail, 40))
						if q > 0:
							regions.vila.stock[g] = int(regions.vila.stock[g]) + q
							regions[reg.id].stock[g] = int(regions[reg.id].stock[g]) - q
							moved[g] = q
					if not moved.is_empty():
						return [fact("TRADE_DELIVERED", {"by": e.payload.npc, "goods": moved})]
	return []


func _route_open(from_region: String) -> bool:
	for id in routes:
		if routes[id].from == from_region and routes[id].open:
			return true
	return false


func to_dict() -> Dictionary:
	_ensure()
	return {"regions": regions.duplicate(true), "treasury": treasury, "routes": routes.duplicate(true), "shortage": shortage.duplicate()}


func from_dict(d: Dictionary) -> void:
	regions = d.get("regions", {}).duplicate(true)
	treasury = int(d.get("treasury", 0))
	routes = d.get("routes", {}).duplicate(true)
	shortage = d.get("shortage", {}).duplicate()
	for id in routes:
		routes[id].open = bool(routes[id].get("open", true))
	for rid in regions:
		for f in ["stock", "production", "consumption", "target"]:
			for g in regions[rid][f]:
				regions[rid][f][g] = int(regions[rid][f][g])
