class_name EconomyModule
extends WorldModule
## Economia agregada por região (§11): produção/consumo diários e preços com limites.
## Não simula cada moeda. O mensageiro leva mercadoria entre regiões. ORIGINAL_DO_JOGO.

var regions: Dictionary = {}


func module_id() -> String: return "economy"
func handled_commands() -> PackedStringArray: return PackedStringArray(["Buy"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["DISTANT_EVENT", "NPC_MOVED", "DOMAIN_WEEK", "SHEEP_KILLED"])


func _ensure() -> void:
	if regions.is_empty():
		regions = world.db.economy.get("regions", {}).duplicate(true)


func price(item_id: String, region: String = "vila", seller: String = "") -> int:
	_ensure()
	var it: Dictionary = world.db.items.get(item_id, {})
	var base := int(it.get("price", 0))
	var mem = world.module("memory")
	if seller != "" and mem != null and mem.bias(seller, "player") < 0:
		base = int(ceil(base * 1.2))  # vendedor desconfiado cobra mais de estranhos (ORIGINAL)
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
	return [fact("ECONOMY_DAY", {"vila": regions.vila.stock.duplicate()})]


func on_event(e: GameEvent) -> Array:
	_ensure()
	match e.event_type:
		"DOMAIN_WEEK":
			regions.vila.stock.comida = int(regions.vila.stock.comida) + int(e.payload.get("food_out", 0))
		"SHEEP_KILLED":
			regions.vila.stock.comida = maxi(0, int(regions.vila.stock.comida) - 4 * int(e.payload.get("count", 1)))
		"DISTANT_EVENT":
			var eff: Dictionary = e.payload.get("effect", {}).get("economy", {})
			if not eff.is_empty() and regions.has(eff.region):
				var r: Dictionary = regions[eff.region]
				r.stock[eff.good] = maxi(0, int(r.stock[eff.good]) + int(eff.delta))
		"NPC_MOVED":
			# Mensageiro chegando de Valkaria traz mercadoria que falta na vila.
			for reg in world.db.distant.get("regions", []):
				if e.payload.npc == reg.courier and e.payload.from == reg.id:
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


func to_dict() -> Dictionary:
	_ensure()
	return {"regions": regions.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	regions = d.get("regions", {}).duplicate(true)
	for rid in regions:
		for f in ["stock", "production", "consumption", "target"]:
			for g in regions[rid][f]:
				regions[rid][f][g] = int(regions[rid][f][g])
