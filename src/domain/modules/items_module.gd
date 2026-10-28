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
func handled_commands() -> PackedStringArray: return PackedStringArray(["Equip", "Unequip", "UseItem"])


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
		"Unequip":
			var sl: String = cmd.payload.get("slot", "")
			if str(world.player_sheet.equipment.get(sl, "")) == "": return PackedStringArray(["nada equipado aí"])
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
		"Unequip":
			var sl: String = cmd.payload.slot
			var tirado: String = s.equipment.get(sl, "")
			s.equipment[sl] = ""
			CharacterBuilder.apply_equipment(world.rules, s)
			return [fact("ITEM_GAINED", {"item": tirado}, ["player"]), fact("UNEQUIPPED", {"item": tirado, "slot": sl, "defense": s.defense(world.rules)}, ["player"])]
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


## Ficha legível de um item (inventário e lojas): tipo, números de regra e preço.
static func info(rules: RuleRegistry, db: ContentDB, id: String) -> Dictionary:
	var d: Dictionary = db.items.get(id, {})
	var out := {"id": id, "nome": str(d.get("name", id.capitalize())), "preco": int(d.get("price", 0)), "slot": str(EQUIPPABLE.get(id, "")), "linhas": []}
	var a: Dictionary = rules.value("arma." + id, {})
	if not a.is_empty():
		out.tipo = "Arma"
		out.dano = str(a.dano)
		out.linhas = ["Dano %s (%s)" % [a.dano, a.tipo], "Crítico %s/x%d" % [("%d-20" % int(a.margem)) if int(a.margem) < 20 else "20", int(a.mult)],
			("Distância (%s)" % a.get("alcance", "médio")) if bool(a.get("disparo", false)) else "Corpo a corpo",
			"%d mão(s)%s" % [int(a.get("maos", 1)), " · leve" if bool(a.get("leve", false)) else ""]]
	var ar: Dictionary = rules.value("armadura." + id, {})
	if not ar.is_empty():
		out.tipo = "Armadura"
		out.defesa = int(ar.defesa)
		out.linhas = ["Defesa +%d" % int(ar.defesa), "Penalidade de armadura %d" % int(ar.get("penalidade", 0)), "Metal" if bool(ar.get("metal", false)) else "Sem metal"]
	if not out.has("tipo"):
		out.tipo = "Alimento" if bool(d.get("alimento", false)) else ("Poção" if id.begins_with("pocao") else ("Luz" if bool(d.get("fonte_luz", false)) else "Item"))
		if id == "pocao_cura":
			out.linhas = ["Cura %s PV" % str(rules.value("magia.curar_ferimentos", {}).get("cura", "2d8+2"))]
		if bool(d.get("alimento", false)):
			out.linhas = ["Comer: bônus de alimentação do dia"]
		if bool(d.get("fonte_luz", false)):
			out.linhas = ["Ilumina 9m por uma cena"]
	out.usavel = id == "pocao_cura" or bool(d.get("alimento", false)) or bool(d.get("fonte_luz", false))
	return out


## Diferença em relação ao que está equipado no mesmo espaço ("+2 Defesa", "dano médio +1.0").
static func comparar(rules: RuleRegistry, db: ContentDB, id: String, sheet: CharacterSheet) -> String:
	var sl: String = EQUIPPABLE.get(id, "")
	if sl == "":
		return ""
	var atual: String = sheet.equipment.get(sl, "")
	if atual == id:
		return "equipado"
	var novo := info(rules, db, id)
	var velho := info(rules, db, atual) if atual != "" else {}
	if sl == "armor":
		return "%+d Defesa em relação a %s" % [int(novo.get("defesa", 0)) - int(velho.get("defesa", 0)), velho.get("nome", "nenhuma")]
	return "dano médio %+.1f em relação a %s" % [_media(str(novo.get("dano", "0"))) - _media(str(velho.get("dano", "0"))), velho.get("nome", "mãos vazias")]


static func _media(dado: String) -> float:
	var p := dado.split("d")
	if p.size() != 2:
		return 0.0
	return float(p[0]) * (float(p[1]) + 1.0) / 2.0
