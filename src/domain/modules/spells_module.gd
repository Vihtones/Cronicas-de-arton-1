extends WorldModule
## Magias fora de combate (docs/MAGIA_COMPLEXA.md): o comando CastSpell lança, fora de uma luta, a cura em si mesmo
## e as magias e versões de magia que agem sobre o mundo e não sobre a cena de combate (cadáveres, alimentos, áreas, sentidos).
## Em combate, as magias passam pelo CombatModule.
## Estado: cadáveres preservados pela Bênção (criatura -> último dia preservado).

const SpellRules := preload("res://src/domain/combat/spell_rules.gd")

## Magias e aprimoramentos que funcionam fora de combate: spell -> aprimoramentos que tornam isso possível
## ([] = a versão básica já funciona fora de combate).
const FORA_DE_COMBATE := {
	"bencao": [0],   # 1 cadáver por 1 semana
}
const DIAS_SEMANA := 7

var cadaveres: Dictionary = {}   # creature_id -> último dia (inclusive) em que está preservado


func module_id() -> String: return "magia"
func handled_commands() -> PackedStringArray: return PackedStringArray(["CastSpell"])


func validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate: use as ações de combate"])
	var sh: CharacterSheet = world.player_sheet
	if sh == null:
		return PackedStringArray(["sem personagem"])
	var sp_id := str(cmd.payload.get("spell", ""))
	var apr: Array = cmd.payload.get("aprimoramentos", [])
	if not sh.spells.has(sp_id):
		return PackedStringArray(["magia não conhecida"])
	if world.rules.value("magia." + sp_id, {}).has("cura"):
		if not apr.is_empty():
			return PackedStringArray(["fora de combate, a cura é lançada sem aprimoramentos"])
		if sh.pm < GhostPlanner.spell_cost(world.rules, GhostPlanner.spell_rule(world.rules, sp_id), cmd.payload):
			return PackedStringArray(["PM insuficiente"])
		return PackedStringArray()
	if not FORA_DE_COMBATE.has(sp_id):
		return PackedStringArray(["essa magia só é lançada em combate"])
	for i in FORA_DE_COMBATE[sp_id]:
		if not apr.has(i):
			return PackedStringArray(["essa versão da magia só é lançada em combate"])
	var sp := GhostPlanner.spell_rule(world.rules, sp_id)
	if int(sp.get("circulo", 0)) > SpellRules.circulo_maximo(sh, world.rules):
		return PackedStringArray(["magia acima do círculo que você conjura"])
	if not SpellRules.aprimoramentos_validos(sp_id, apr, sh, world.rules):
		return PackedStringArray(["aprimoramento não disponível para essa magia"])
	if sh.pm < GhostPlanner.spell_cost(world.rules, sp, cmd.payload):
		return PackedStringArray(["PM insuficiente"])
	match sp_id:
		"bencao":
			return _valida_cadaver(str(cmd.payload.get("target", "")), str(sp.get("alcance", "curto")))
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var sh: CharacterSheet = world.player_sheet
	var sp_id := str(cmd.payload.get("spell", ""))
	var sp := GhostPlanner.spell_rule(world.rules, sp_id)
	var custo := GhostPlanner.spell_cost(world.rules, sp, cmd.payload)
	sh.pm -= custo
	var out: Array = [fact("SPELL_CAST", {"caster": "player", "spell": sp_id, "cost": custo, "fora_de_combate": true,
		"aprimoramentos": cmd.payload.get("aprimoramentos", [])}, ["player"])]
	if sp.has("cura"):
		# Cura em si mesmo (Curar Ferimentos e afins), na versão básica.
		var r := Dice.roll(str(sp.cura), world.rng, "world")
		sh.pv = mini(sh.pv_max, sh.pv + int(r.total))
		out[0].payload["pm_cost"] = custo
		out[0].payload["pm_after"] = sh.pm
		out.append(fact("HEALED", {"actor": "player", "target": "player", "amount": r.total, "pv_after": sh.pv, "source": sp_id}, ["player"]))
		return out
	match sp_id:
		"bencao":
			var alvo := str(cmd.payload.get("target", ""))
			preservar_cadaver(alvo, DIAS_SEMANA)
			out.append(fact("CORPSE_PRESERVED", {"caster": "player", "target": alvo, "ate_dia": int(cadaveres[alvo])}, ["player"]))
	return out


## Bênção sobre cadáver (+1 PM): não se decompõe nem pode virar morto-vivo por `dias` dias a partir de hoje.
func preservar_cadaver(id: String, dias: int) -> void:
	cadaveres[id] = maxi(int(cadaveres.get(id, -1)), world.day_index() + dias - 1)


## Consultado pelas magias que criam mortos-vivos.
func cadaver_preservado(id: String) -> bool:
	return cadaveres.has(id) and int(cadaveres[id]) >= world.day_index()


func _valida_cadaver(id: String, alcance: String) -> PackedStringArray:
	var combat = world.module("combat")
	if combat == null or not combat.creature_state.has(id):
		return PackedStringArray(["escolha um cadáver"])
	var st_c: Dictionary = combat.creature_state[id]
	if bool(st_c.get("alive", true)):
		return PackedStringArray(["o alvo não é um cadáver"])
	var t: Array = st_c.get("tile", [0, 0])
	var p: Vector2i = world.db.world_to_tile(world.player.position)
	var dist := maxi(absi(p.x - int(t[0])), absi(p.y - int(t[1])))
	if dist > int(world.rules.value("alcance.quadrados", {}).get(alcance, 6)):
		return PackedStringArray(["cadáver fora do alcance"])
	return PackedStringArray()


func to_dict() -> Dictionary:
	return {"cadaveres": cadaveres.duplicate()}


func from_dict(d: Dictionary) -> void:
	cadaveres = (d.get("cadaveres", {}) as Dictionary).duplicate()
