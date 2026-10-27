class_name ItemsModule
extends WorldModule
const Area := preload("res://src/domain/combat/area.gd")
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
			var d_it: Dictionary = world.db.items.get(it, {})
			if it != "pocao_cura" and not bool(d_it.get("alimento", false)) and not bool(d_it.get("fonte_luz", false)): return PackedStringArray(["não é usável"])
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
			if bool(world.db.items.get(str(cmd.payload.item), {}).get("alimento", false)):
				return _comer(str(cmd.payload.item), str(cmd.payload.get("bonus", "pv")))
			if bool(world.db.items.get(str(cmd.payload.item), {}).get("fonte_luz", false)):
				# Tocha (LB p.158): acender é ação padrão; ilumina 9m e dura uma cena.
				var magia = world.module("magia")
				if magia != null:
					magia.carregar_luz(Area.quadrados(float(world.rules.value("luz.tocha").raio_m)))
				return [fact("ITEM_LOST", {"item": cmd.payload.item}, ["player"]), fact("LIGHT_LIT", {"item": cmd.payload.item}, ["player"])]
			var r := Dice.roll(str(world.rules.value("magia.curar_ferimentos").cura), world.rng, "world")
			s.pv = mini(s.pv_max, s.pv + int(r.total))
			return [fact("ITEM_LOST", {"item": cmd.payload.item}, ["player"]),
				fact("HEALED", {"actor": "player", "target": "player", "amount": r.total, "pv_after": s.pv, "source": cmd.payload.item}, ["player"])]
	return []


## Comer ou beber (LB p.161): a porção abençoada (Abençoar Alimentos) dá 5 PV temporários ou 1 PM temporário se
## consumida na cena, e só um bônus de alimentação por dia. Alimento estragado ou envenenado faz mal (Fortitude CD 15
## ou enjoado pelo dia; ORIGINAL_DO_JOGO), a menos que tenha sido purificado.
func _comer(item: String, bonus: String) -> Array:
	var s := world.player_sheet
	var out: Array = [fact("ITEM_LOST", {"item": item}, ["player"]), fact("ATE", {"item": item}, ["player"])]
	var d: Dictionary = world.db.items.get(item, {})
	var magia = world.module("magia")
	var abencoado: bool = magia != null and magia.consumir_abencoado(item)
	if (bool(d.get("estragado", false)) or bool(d.get("envenenado", false))) and not abencoado:
		if not Checks.skill(s, "fortitude", 15, world.rules, world.rng, "world").get("success", false):
			s.add_condition("enjoado", world.rules)
			s.add_efeito("alimento_estragado", "condicao", 1, "dia", "enjoado", world.day_index() + 1)
			out.append(fact("CONDITION_APPLIED", {"condition": "enjoado", "source": item}, ["player"]))
		return out
	if abencoado and s.efeito_bonus("bonus_alimentacao") <= 0:
		s.add_efeito("alimentacao", "bonus_alimentacao", 1, "dia", "", world.day_index() + 1)
		if bonus == "pm":
			s.pm += 1   # PM temporário: some no fim do dia se não for gasto (limpar_dia)
			s.add_efeito("alimentacao", "pm_temp", 1, "dia", "", world.day_index() + 1)
		else:
			s.add_efeito("alimentacao", "pv_temp_alimento", 5, "dia", "", world.day_index() + 1)
			s.pv_temp = maxi(s.pv_temp, 5)
		out.append(fact("FOOD_BONUS", {"item": item, "bonus": bonus}, ["player"]))
	return out
