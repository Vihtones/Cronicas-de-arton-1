extends TestCase
## Todas as raças jogáveis do Livro Básico (p.18-31): atributos, deslocamento, tamanho, sentidos e traços com sistema.


func _b(race: String, cls := "guerreiro", picks: Array = ["for", "des", "con"]) -> CharacterSheet:
	return CharacterBuilder.build(RuleRegistry.load_default(), race, cls, CharacterBuilder.presets(cls)[0], picks)


func test_todas_as_racas_constroem_e_salvam() -> void:
	var r := RuleRegistry.load_default()
	eq(CharacterBuilder.RACES.size(), 18, "17 raças do LB, com suraggel em duas variantes")
	for race in CharacterBuilder.RACES:
		for cls in CharacterBuilder.CLASSES:
			var s := _b(race, cls)
			check(s.pv_max > 0 and s.speed_m > 0, "%s %s válido" % [race, cls])
			var back := CharacterSheet.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			eq(back.defense(r), s.defense(r), "%s: defesa igual após salvar" % race)
			eq(back.skill_value("furtividade", r), s.skill_value("furtividade", r), "%s: perícias iguais após salvar" % race)


func test_atributos_da_tabela_1_2() -> void:
	var base: Dictionary = CharacterBuilder.presets("guerreiro")[0]
	var e := _b("elfo")
	eq(e.attrs["int"], int(base["int"]) + 2); eq(e.attrs.des, int(base.des) + 1); eq(e.attrs.con, int(base.con) - 1)
	var lf := _b("lefou", "guerreiro", ["car", "for", "des"])
	eq(lf.attrs.car, int(base.car) - 1, "lefou: não escolhe Carisma e perde 1")
	eq(lf.attrs["for"], int(base["for"]) + 1)
	var os := _b("osteon", "guerreiro", ["con", "for", "des"])
	eq(os.attrs.con, int(base.con) - 1, "osteon: exceção Con")


func test_tracos_com_sistema() -> void:
	var r := RuleRegistry.load_default()
	eq(_b("elfo").speed_m, 12.0, "Graça de Glórienn")
	eq(_b("golem").speed_m, 6.0, "Chassi")
	eq(_b("hynne").speed_m, 6.0)
	eq(_b("golem").defense(r), _b("humano").defense(r) + 2 + (_b("golem").attrs.des - _b("humano").attrs.des), "Chassi +2 Defesa")
	eq(_b("minotauro").race_defense, 1, "Couro Rígido")
	check(_b("minotauro").attacks.any(func(a): return a.get("natural", false) and a.nome == "Chifres"), "Chifres")
	check(_b("trog").attacks.any(func(a): return a.nome == "Mordida"), "Mordida")
	eq(_b("goblin").size, "pequeno"); eq(_b("silfide").size, "minusculo")
	var hum := _b("humano")
	var gob := _b("goblin")
	check(gob.skill_value("furtividade", r) >= hum.skill_value("furtividade", r) + 2 - 1, "Pequeno: +2 Furtividade (LB p.107)")
	eq(_b("osteon").dr.get("corte", 0), 5, "Armadura Óssea")
	eq(_b("qareen").dr.get("fogo", 0), 10, "Resistência Elemental (padrão fogo)")
	check(_b("qareen").spells.has("seta_infalivel"), "Tatuagem Mística")
	eq(_b("kliren").vuln.get("impacto", 0), 1, "Ossos Frágeis")
	eq(_b("elfo", "arcanista").pm_max, _b("humano", "arcanista").pm_max + 1 + (_b("elfo", "arcanista").attrs["int"] - _b("humano", "arcanista").attrs["int"]), "Sangue Mágico +1 PM")
	eq(_b("medusa").creature_type, "monstro"); eq(_b("osteon").creature_type, "morto-vivo")


func test_osteon_reduz_dano_de_corte_em_combate() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet = _b("osteon")
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var c: CombatModule = w.modules.combat
	c.sim.c("player").tile = Vector2i(26, 57)
	c.sim.c("bandido_1").tile = Vector2i(27, 57)
	var a: Dictionary = c.sim.c("bandido_1").sheet.attacks[0]
	a["tipo"] = "corte"
	var reduced := false
	for i in 30:
		c.sim.c("player").sheet.pv = 200
		var v := c.sim.attack_profile("bandido_1", "player", 0, false, false)
		for f in c._resolve_attack("bandido_1", "player", v, false):
			if f.type == "ATTACK_RESOLVED" and (f.payload.tags as Array).has("reducao"): reduced = true
	check(reduced, "RD 5 contra corte aplicada")
