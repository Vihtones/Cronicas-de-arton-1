extends TestCase
## C17 (perícias), C4 (Arcanista: caminhos e 3 magias) e C5 (concentração e armadura ao lançar).


func _arc(path := "bruxo") -> CharacterSheet:
	var r := RuleRegistry.load_default()
	return CharacterBuilder.build(r, "humano", "arcanista", CharacterBuilder.presets("arcanista")[0], ["int", "des", "sab"], "Arcanista", [], [], path)


func _world_with(sheet: CharacterSheet) -> WorldState:
	var w := WorldHelpers.world(5)
	w.player_sheet = sheet
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	return w


func _cast(w: WorldState, a: Dictionary) -> Array:
	var c: CombatModule = w.modules.combat
	var v := GhostPlanner.validate_action(c.sim, "player", a)
	if not v.ok:
		return [{"type": "INVALID", "payload": v}]
	return c._cast("player", a, v)


func test_c17_escolha_de_pericias_valida_lista_e_quantidade() -> void:
	var r := RuleRegistry.load_default()
	var attrs := {"for": 0, "des": 2, "con": 1, "int": 2, "sab": 1, "car": 0}
	var slots := CharacterBuilder.skill_slots(r, "guerreiro", "humano", attrs)
	eq(slots.classe, 2, "guerreiro escolhe 2 (LB p.65)")
	eq(slots.livres, 4, "Int 2 + Versátil 2 (LB p.114, p.19)")
	check(CharacterBuilder.validate_skills(r, "guerreiro", "humano", attrs, ["atletismo", "percepcao"], ["misticismo"]).is_empty(), "válida")
	check(not CharacterBuilder.validate_skills(r, "guerreiro", "humano", attrs, ["misticismo", "percepcao"], []).is_empty(), "misticismo fora da lista")
	check(not CharacterBuilder.validate_skills(r, "guerreiro", "humano", attrs, ["atletismo"], []).is_empty(), "faltou uma")
	check(not CharacterBuilder.validate_skills(r, "guerreiro", "humano", attrs, ["fortitude", "percepcao"], []).is_empty(), "fixa não conta")
	var s := CharacterBuilder.build_from(r, {"race": "humano", "class": "guerreiro", "attrs": CharacterBuilder.presets("guerreiro")[0],
		"class_picks": ["cavalgar", "guerra"], "free_picks": ["cura"]})
	check(s.trained.has("cavalgar") and s.trained.has("guerra") and s.trained.has("cura"), "a ficha usa a escolha")


func test_c4_caminhos_do_arcanista() -> void:
	var b := _arc("bruxo")
	eq(b.caster_attr, "int", "bruxo usa Int (LB p.37)")
	eq(b.spells.size(), 3, "3 magias iniciais")
	var f := _arc("feiticeiro")
	eq(f.caster_attr, "car", "feiticeiro usa Car")
	check(f.pm_max != b.pm_max or f.attrs.car == f.attrs["int"], "PM somam o atributo do caminho")
	var m := _arc("mago")
	eq(m.arcane_path, "mago")
	eq(m.spells.size(), 3, "mago teria 4; só 3 implementadas (pendente registrado)")
	eq(CharacterSheet.from_dict(m.to_dict()).arcane_path, "mago", "caminho no save")


func test_c4_armadura_arcana_defesa_pela_cena() -> void:
	var s := _arc()
	var w := _world_with(s)
	var c: CombatModule = w.modules.combat
	var before: int = c.sim.c("player").sheet.defense(w.rules)
	var out := _cast(w, {"type": "cast", "spell": "armadura_arcana", "targets": ["player"]})
	check(out.any(func(f): return f.type == "BUFF_APPLIED"), "aplicou")
	eq(c.sim.c("player").sheet.defense(w.rules), before + 5, "+5 sem armadura (LB p.183)")
	c._end_combat("fuga")
	eq(w.player_sheet.scene_defense, 0, "termina com a cena")


func test_c4_toque_chocante_exige_adjacencia_e_permite_resistencia() -> void:
	var s := _arc()
	var w := _world_with(s)
	var c: CombatModule = w.modules.combat
	c.sim.c("bandido_1").tile = Vector2i(29, 57)
	check(not GhostPlanner.validate_action(c.sim, "player", {"type": "cast", "spell": "toque_chocante", "targets": ["bandido_1"]}).ok, "toque: fora de alcance")
	c.sim.c("bandido_1").tile = Vector2i(27, 57)
	var saved := 0
	var full := 0
	for i in 20:
		c.sim.c("player").sheet.pm = 10
		c.sim.c("bandido_1").sheet.pv = 50
		for f in _cast(w, {"type": "cast", "spell": "toque_chocante", "targets": ["bandido_1"], "target": "bandido_1"}):
			if f.type == "ATTACK_RESOLVED":
				check(int(f.payload.defense) == 10 + 0 + int(s.attrs["int"]), "CD = 10 + nível/2 + Int (LB p.173)")
				if f.payload.saved: saved += 1
				else: full += 1
	check(saved > 0 and full > 0, "Fortitude às vezes reduz à metade (%d/%d)" % [saved, full])


func test_c5_concentracao_caido_e_armadura() -> void:
	var s := _arc()
	var w := _world_with(s)
	var c: CombatModule = w.modules.combat
	var sp: Dictionary = w.rules.value("magia.seta_infalivel")
	eq(int(c.casting_cd(c.sim.c("player").sheet, sp, 1).concentration_cd), 0, "em pé e com tempo bom: sem teste")
	c.sim.c("player").sheet.conditions.append("caido")
	eq(int(c.casting_cd(c.sim.c("player").sheet, sp, 1).concentration_cd), 16, "caído: CD 15 + custo (LB p.170)")
	var failed := 0
	for i in 30:
		c.sim.c("player").sheet.pm = 10
		var out := _cast(w, {"type": "cast", "spell": "seta_infalivel", "targets": ["bandido_1"]})
		if out.any(func(f): return f.type == "SPELL_FAILED"):
			failed += 1
			eq(c.sim.c("player").sheet.pm, 9, "PM gastos mesmo falhando")
	check(failed > 0, "às vezes perde a magia caído")
	c.sim.c("player").sheet.remove_condition("caido")
	c.sim.c("player").sheet.equipment.armor = "couro_batido"
	var ar: Dictionary = c.casting_cd(c.sim.c("player").sheet, sp, 1).armor
	eq(int(ar.get("cd", 0)), 21, "arcana de armadura: Misticismo CD 20 + custo (LB p.171)")
