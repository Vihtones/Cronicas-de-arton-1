extends TestCase
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
## Primeira leva de classes na criação (bárbaro, paladino, nobre, bucaneiro, cavaleiro, caçador, inventor)
## e habilidade mecânica do bárbaro (Fúria).


func _build(p_class: String, preset: int = 0) -> CharacterSheet:
	var r := RuleRegistry.load_default()
	return CharacterBuilder.build(r, "humano", p_class, CharacterBuilder.presets(p_class)[preset], ["for", "des", "con"], p_class)


func test_todas_as_classes_da_criacao_tem_presets_validos() -> void:
	var r := RuleRegistry.load_default()
	for c in CharacterBuilder.CLASSES:
		check(CharacterBuilder.presets(c).size() == 2, "%s tem 2 presets" % c)
		for p in CharacterBuilder.presets(c):
			check(CharacterBuilder.validate_points(r, p).is_empty(), "%s: preset dentro de 10 pontos" % c)
		var sh := _build(c)
		check(sh.pv_max > 0 and sh.pm_max > 0, "%s: PV e PM positivos" % c)
		check(CharacterBuilder.CLASS_NAMES.has(c), "%s tem nome de exibição" % c)


func test_lista_de_pericias_vem_da_classe_inteira_quando_nao_ha_sub_entrada() -> void:
	var r := RuleRegistry.load_default()
	check(CharacterBuilder.class_list(r, "barbaro").has("intimidacao"), "bárbaro tem Intimidação na lista")
	check(CharacterBuilder.class_list(r, "ladino").has("furtividade"), "ladino mantém a lista antiga")
	check(CharacterBuilder.class_list(r, "guerreiro").has("atletismo"), "guerreiro mantém a lista antiga")


func test_escolhas_padrao_validas_para_cada_classe() -> void:
	var r := RuleRegistry.load_default()
	for c in CharacterBuilder.CLASSES:
		var sh := _build(c)
		var slots := CharacterBuilder.skill_slots(r, c, "humano", sh.attrs)
		var picks := CharacterBuilder._default_choices(r, c)
		check(picks.size() == int(slots.classe), "%s: escolhas padrão = perícias da classe" % c)
		check(CharacterBuilder.validate_skills(r, c, "humano", sh.attrs, picks, []).is_empty(), "%s: escolhas padrão válidas" % c)
		for f in CharacterBuilder.fixed_skills(r, c):
			check(not picks.has(f), "%s: não repete fixa %s" % [c, f])


func test_equipamento_do_bardo_e_do_cacador() -> void:
	var sh := _build("cacador")
	check(sh.equipment.weapon == "arco_curto", "caçador usa arco curto")
	check(sh.attacks.size() > 0 and bool(sh.attacks[0].distancia), "caçador ataca à distância")
	var b := _build("barbaro")
	check(b.attacks.size() > 0 and not bool(b.attacks[0].distancia), "bárbaro ataca corpo a corpo")


func test_furia_do_barbaro_sobe_com_o_nivel() -> void:
	var sh := _build("barbaro")
	check(ClassFeatures.furia_bonus(sh) == 2, "nível 1: +2")
	sh.level = 6
	check(ClassFeatures.furia_bonus(sh) == 3, "nível 6: +3")
	sh.level = 11
	check(ClassFeatures.furia_bonus(sh) == 4, "nível 11: +4")
	sh.level = 16
	check(ClassFeatures.furia_bonus(sh) == 5, "nível 16: +5")
	check(ClassFeatures.furia_bonus(_build("guerreiro")) == 0, "guerreiro não tem Fúria")


func test_furia_entra_no_ataque_corpo_a_corpo_do_barbaro() -> void:
	var r := RuleRegistry.load_default()
	var w := WorldHelpers.world(5)
	w.player_sheet = _build("barbaro")
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	var v := GhostPlanner.validate_action(sim, "player", {"type": "attack", "target": "bandido_1"})
	check(v.ok, "ataque válido")
	var achou := false
	for m in v.mods:
		if m[0] == "fúria":
			achou = true
	check(achou, "Fúria aparece como modificador de ataque")


func test_clerigo_conjura_com_sabedoria_e_cura() -> void:
	var sh := _build("clerigo")
	check(sh.spells.has("curar_ferimentos"), "clérigo começa com Curar Ferimentos")
	check(sh.caster_attr == "sab", "atributo de conjuração é a Sabedoria")
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_1").sheet.pv = 1
	var a := {"type": "cast", "spell": "curar_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "cura em alvo adjacente é válida: %s" % str(v.get("reason", "")))
	var curou := false
	for f in c._cast("player", a, v):
		if f.type == "HEALED":
			curou = int(f.payload.amount) > 0
	check(curou, "Curar Ferimentos cura o alvo")


func test_perdicao_penaliza_inimigo_e_aprimoramento_custa_2_pm() -> void:
	var r := RuleRegistry.load_default()
	var sh := _build("clerigo")
	sh.spells = PackedStringArray(["curar_ferimentos", "perdicao"])
	sh.equipment["armor"] = ""   # sem armadura: não há teste de concentração/armadura ao lançar
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(28, 57)
	var base := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"]})
	check(base.ok and int(base.cost) == 1, "Perdição custa 1 PM na base: %s" % str(base))
	var com := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"], "aprimoramentos": [0]})
	check(not com.ok or int(com.cost) == 3, "aprimoramento soma 2 PM (círculo 1 limita a penalidade)")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"], "aprimoramentos": [3]}).ok, "aprimoramento inexistente é recusado")
	var fx := c._cast("player", {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"]}, base)
	check(fx.size() > 0 and str(fx[0].type) != "SPELL_FAILED", "lançou: %s" % str(fx[0].type))
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	check(alvo.efeito_bonus("ataque") == -1, "inimigo recebe –1 em ataques")
	check(alvo.efeito_bonus("dano") == -1, "inimigo recebe –1 no dano")
	check(SpellRules.penalidade_perdicao(sh, r, [0]) == 1, "círculo 1 limita a penalidade a –1")
	sh.level = 5
	check(SpellRules.penalidade_perdicao(sh, r, [0]) == 2, "com 2º círculo o aprimoramento dá –2")


func test_efeito_de_cena_acaba_com_o_combate() -> void:
	var sh := _build("clerigo")
	sh.add_efeito("magia.teste", "ataque", -1, "cena")
	sh.add_efeito("magia.outro", "ataque", -1, "turno")
	sh.limpar_efeitos("cena")
	check(sh.efeito_bonus("ataque") == -1 and not sh.has_efeito("magia.teste"), "cena limpa só o efeito de cena")
	var copia := CharacterSheet.from_dict(sh.to_dict())
	check(copia.efeito_bonus("ataque") == -1, "efeitos sobrevivem à gravação")
