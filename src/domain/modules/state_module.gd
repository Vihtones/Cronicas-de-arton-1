class_name StateModule
extends WorldModule
## Flags do mundo e inventário do jogador. Muda apenas por eventos (event-sourced).

var flags: Dictionary = {}
var inventory: Dictionary = {}   # item_id -> quantidade


func module_id() -> String: return "state"
func essential() -> bool: return true
func handled_commands() -> PackedStringArray: return PackedStringArray(["Rest"])


## Descanso (LB p.106): recupera PV e PM conforme a condição do local.
func rest_quality() -> String:
	var tr = world.module("travel")
	if tr != null and tr.current_region != "vila":
		return "normal" if int(world.player.gold) >= 1 else "ruim"  # estalagem comum (LB p.163) ou relento
	var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
	if loc == "taverna" and int(world.player.gold) >= 1:
		return "normal"  # salão comunal / quarto simples
	if bool(world.db.location(loc).get("indoor", false)):
		return "ruim" if world.db.zone_at(world.db.world_to_tile(world.player.position)) == "cripta" else "normal"
	if has_item("saco_de_dormir"):
		return "normal"  # ADAPTADA: relento COM saco de dormir deixa de ser condição ruim (LB p.106)
	return "ruim"  # relento sem acampamento


func validate(cmd: GameCommand) -> PackedStringArray:
	var c = world.module("combat")
	if c != null and c.active:
		return PackedStringArray(["impossível descansar em combate"])
	if c != null:
		for id in c.visible_creatures():
			if not c.is_asleep(id) and world.db.location_at(world.db.world_to_tile(world.player.position)) != "cripta_cela":
				return PackedStringArray(["há perigo por perto"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var hours := int(world.rules.value("descanso.duracao_horas", 8))
	var quality := rest_quality()
	var mult: float = float(world.rules.value("descanso.recuperacao", {}).get(quality, 1))
	var amount := maxi(int(world.rules.value("descanso.minimo", {"minimo": 1}).minimo), int(floor(world.player_sheet.level * mult)))
	var out: Array = []
	var tr2 = world.module("travel")
	var in_town: bool = tr2 != null and tr2.current_region != "vila"
	if quality == "normal" and (in_town or world.db.location_at(world.db.world_to_tile(world.player.position)) == "taverna"):
		out.append(fact("GOLD_CHANGED", {"delta": -1, "reason": "pernoite na taverna"}))
	out.append_array(world.advance_ticks(hours * 60 / world.clock.tick_minutes))
	var s := world.player_sheet
	s.pv = mini(s.pv_max, s.pv + amount)
	s.pm = mini(s.pm_max, s.pm + amount)
	if s.pv > 0:
		s.remove_condition("caido")
	out.append(fact("RESTED", {"quality": quality, "recovered": amount, "pv": s.pv, "pm": s.pm, "hours": hours}, ["player"]))
	return out
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["FLAG_SET", "ITEM_GAINED", "ITEM_LOST", "GOLD_CHANGED"])


func has_flag(f: String) -> bool: return flags.get(f, false)
func has_item(i: String) -> bool: return int(inventory.get(i, 0)) > 0
func item_count(i: String) -> int: return int(inventory.get(i, 0))


func on_event(e: GameEvent) -> Array:
	match e.event_type:
		"FLAG_SET":
			flags[e.payload.flag] = e.payload.get("value", true)
		"ITEM_GAINED":
			inventory[e.payload.item] = item_count(e.payload.item) + int(e.payload.get("qty", 1))
		"ITEM_LOST":
			var n := item_count(e.payload.item) - int(e.payload.get("qty", 1))
			if n <= 0:
				inventory.erase(e.payload.item)
			else:
				inventory[e.payload.item] = n
		"GOLD_CHANGED":
			world.player.gold = maxi(0, int(world.player.gold) + int(e.payload.delta))
	return []


func to_dict() -> Dictionary: return {"flags": flags.duplicate(), "inventory": inventory.duplicate()}
func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {}).duplicate()
	inventory = {}
	for k in d.get("inventory", {}):
		inventory[k] = int(d.inventory[k])
