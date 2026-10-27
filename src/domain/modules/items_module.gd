class_name ItemsModule
extends WorldModule
## Equipamento e consumíveis (protótipo). Equipar recalcula Defesa e ataques pelas
## regras de arma/armadura; poção replica Curar Ferimentos; magia fora de combate.

const EQUIPPABLE := {
	"espada_longa": "weapon", "espada_curta": "weapon", "adaga": "weapon", "clava": "weapon", "lanca": "weapon",
	"machado_batalha": "weapon", "arco_curto": "weapon", "couro_batido": "armor", "gibao_peles": "armor", "cota_malha": "armor",
}


func module_id() -> String: return "items"
func handled_commands() -> PackedStringArray: return PackedStringArray(["Equip", "UseItem"])


func validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate, use as ações do turno"])
	var st = world.module("state")
	match cmd.type:
		"Equip":
			var it: String = cmd.payload.get("item", "")
			if not EQUIPPABLE.has(it): return PackedStringArray(["não equipável"])
			if not st.has_item(it) and world.player_sheet.equipment.values().find(it) < 0:
				return PackedStringArray(["você não tem " + it])
			var rel = world.module("religion")
			if rel != null and EQUIPPABLE[it] == "armor":
				var why: String = rel.forbids_armor(it)
				if why != "": return PackedStringArray([why])
		"UseItem":
			var it: String = cmd.payload.get("item", "")
			if not st.has_item(it): return PackedStringArray(["você não tem " + it])
			if it != "pocao_cura": return PackedStringArray(["não é usável"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var s := world.player_sheet
	match cmd.type:
		"Equip":
			var it: String = cmd.payload.item
			var slot: String = EQUIPPABLE[it]
			var old: String = s.equipment.get(slot, "")
			s.equipment[slot] = it
			CharacterBuilder.apply_equipment(world.rules, s)
			var out: Array = [fact("ITEM_LOST", {"item": it}, ["player"])]
			if old != "":
				out.append(fact("ITEM_GAINED", {"item": old}, ["player"]))
			out.append(fact("EQUIPPED", {"item": it, "slot": slot, "previous": old, "defense": s.defense(world.rules)}, ["player"]))
			return out
		"UseItem":
			var r := Dice.roll(str(world.rules.value("magia.curar_ferimentos").cura), world.rng, "world")
			s.pv = mini(s.pv_max, s.pv + int(r.total))
			return [fact("ITEM_LOST", {"item": cmd.payload.item}, ["player"]),
				fact("HEALED", {"actor": "player", "target": "player", "amount": r.total, "pv_after": s.pv, "source": cmd.payload.item}, ["player"])]
	return []
