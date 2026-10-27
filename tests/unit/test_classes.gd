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
	check(sh.spells.has("perdicao"), "clérigo começa com Perdição (magia completa)")
	check(sh.spells.has("infligir_ferimentos") and sh.spells.size() == 3, "clérigo começa com 3 magias completas")
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


func test_perdicao_em_varios_inimigos_com_aprimoramento_e_sem_aliados() -> void:
	var sh := _build("clerigo")
	sh.spells = PackedStringArray(["perdicao"])
	sh.equipment["armor"] = ""
	sh.level = 5
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1", "bandido_2"], false, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(28, 57)
	sim.c("bandido_2").tile = Vector2i(28, 58)
	var a := {"type": "cast", "spell": "perdicao", "targets": ["bandido_1", "bandido_2"], "aprimoramentos": [0]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok and int(v.cost) == 3, "dois alvos com aprimoramento: 3 PM (%s)" % str(v))
	c._cast("player", a, v)
	check(sim.c("bandido_1").sheet.efeito_bonus("ataque") == -2, "primeiro inimigo recebe –2 (círculo 2 permite)")
	check(sim.c("bandido_2").sheet.efeito_bonus("dano") == -2, "segundo inimigo recebe –2 no dano")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "perdicao", "targets": ["player"]}).ok, "não aceita a si mesmo")


func _cena_com(sp: String, nivel: int, pos_alvo: Vector2i = Vector2i(27, 57)) -> Array:
	var sh := _build("clerigo")
	sh.spells = PackedStringArray([sp])
	sh.equipment["armor"] = ""
	sh.level = nivel
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = pos_alvo
	return [w, w.modules.combat, sim, sh]


func test_infligir_ferimentos_causa_dano_e_respeita_aprimoramento_de_circulo() -> void:
	var r := RuleRegistry.load_default()
	var m := _cena_com("infligir_ferimentos", 1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var pv0: int = sim.c("bandido_1").sheet.pv
	var a := {"type": "cast", "spell": "infligir_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "infligir válido em alvo adjacente: %s" % str(v))
	c._cast("player", a, v)
	check(sim.c("bandido_1").sheet.pv < pv0, "infligir reduz os PV do alvo")
	check(SpellRules.aprimoramentos_validos("infligir_ferimentos", [3], m[3], r), "alcance curto e vários alvos não exigem círculo (LB)")
	check(SpellRules.multi_alvo("infligir_ferimentos", {}, [3]), "aprimoramento 3 permite vários alvos")
	check(SpellRules.aprimoramentos_validos("infligir_ferimentos", [1], m[3], r), "+1d8 vale no 1º círculo")


func test_resistencia_a_energia_reduz_dano_e_exclusivos_nao_combinam() -> void:
	var r := RuleRegistry.load_default()
	var m := _cena_com("resistencia_a_energia", 1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "resistencia_a_energia", "target": "bandido_1", "targets": ["bandido_1"], "tipo_energia": "frio"}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "resistência a energia válida em aliado adjacente: %s" % str(v))
	c._cast("player", a, v)
	check(sim.c("bandido_1").sheet.efeito_rd("frio") == 10, "RD 10 contra o tipo escolhido")
	check(sim.c("bandido_1").sheet.efeito_rd("fogo") == 0, "RD não vale para outro tipo")
	check(not SpellRules.aprimoramentos_validos("resistencia_a_energia", [3, 4], m[3], r), "imunidade e RD para todos não combinam")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "resistencia_a_energia", "target": "bandido_1", "targets": ["bandido_1"], "tipo_energia": "fogo_extra"}).ok, "tipo inexistente é recusado")


func test_efeito_de_um_dia_expira_na_virada_do_dia() -> void:
	var sh := _build("clerigo")
	sh.add_efeito("magia.resistencia_a_energia", "rd", 10, "dia", "fogo", 3)
	sh.limpar_dia(2)
	check(sh.efeito_rd("fogo") == 10, "ainda vale antes do dia de término")
	sh.limpar_dia(3)
	check(sh.efeito_rd("fogo") == 0, "acaba quando o dia de término chega")


func test_condicao_de_magia_acaba_com_a_cena() -> void:
	var sh := _build("clerigo")
	sh.add_efeito("magia.infligir_ferimentos", "condicao", 0, "cena", "fraco")
	sh.add_condition("fraco", RuleRegistry.load_default())
	sh.limpar_efeitos("cena")
	check(not sh.conditions.has("fraco"), "fraco some ao fim da cena")


func test_protecao_divina_base_esfera_e_medo() -> void:
	var m := _cena_com("protecao_divina", 5, Vector2i(27, 57))
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "protecao_divina", "target": "bandido_1", "targets": ["bandido_1"]}
	check(not GhostPlanner.validate_action(sim, "player", a).ok, "não protege inimigo")
	sim.c("bandido_1")["side"] = sim.c("player")["side"]   # o alvo é aliado nesta cena de teste
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "base válida em aliado adjacente: %s" % str(v))
	c._cast("player", a, v)
	check(sim.c("bandido_1").sheet.efeito_bonus("resistencia") == 2, "base: +2 em resistências")
	sim.c("bandido_1").sheet.add_efeito("magia.protecao_divina", "imune", 1, "cena", "apavorado")
	sim.c("bandido_1").sheet.add_condition("apavorado", sim.rules)
	check(not sim.c("bandido_1").sheet.conditions.has("apavorado"), "imunidade bloqueia medo")


func test_protecao_divina_3_imune_a_medo_e_mental() -> void:
	var m := _cena_com("protecao_divina", 9, Vector2i(27, 57))
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1")["side"] = sim.c("player")["side"]
	sim.c("player").sheet.pm = 20   # custo de +5 PM além da magia
	var a := {"type": "cast", "spell": "protecao_divina", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [3]}
	c._cast("player", a, {"ok": true, "cost": 7})   # ramo de efeito direto (sem validar aprimoramentos de reação)
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	for cond in ["apavorado", "abalado", "confuso", "enfeiticado", "fascinado"]:
		alvo.add_condition(cond, sim.rules)
		check(not alvo.conditions.has(cond), "imune (mental ou medo): %s" % cond)
	alvo.add_condition("fraco", sim.rules)
	check(alvo.conditions.has("fraco"), "sem imunidade a condições físicas: fraco")


func _duas_cenas(nivel: int) -> Array:
	var sh := _build("clerigo")
	sh.spells = PackedStringArray(["escudo_da_fe"])
	sh.equipment["armor"] = ""
	sh.level = nivel
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1", "bandido_2"], false, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_2").tile = Vector2i(28, 57)
	sim.c("bandido_1")["side"] = sim.c("player")["side"]   # aliado atacado pelo bandido_2
	return [w, c, sim, sh]


func test_escudo_da_fe_reacao_ao_aliado_atacado_uma_vez_por_rodada() -> void:
	var m := _duas_cenas(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet   # a simulação trabalha com cópia da ficha
	var pm0 := sh.pm
	var v := GhostPlanner.validate_action(sim, "bandido_2", {"type": "attack", "target": "bandido_1"})
	check(v.ok, "ataque válido: %s" % str(v))
	c._resolve_attack("bandido_2", "bandido_1", v, false)
	check(sim.c("bandido_1").sheet.has_efeito("magia.escudo_da_fe"), "reação lança o escudo no aliado atacado")
	check(sh.pm == pm0 - 1, "a reação custa 1 PM")
	var pm1 := sh.pm
	c._resolve_attack("bandido_2", "bandido_1", GhostPlanner.validate_action(sim, "bandido_2", {"type": "attack", "target": "bandido_1"}), false)
	check(sh.pm == pm1, "a reação não se repete na mesma rodada")


func test_escudo_da_fe_no_turno_exige_execucao_padrao_e_aprimoramento() -> void:
	var m := _duas_cenas(1)
	var sim: CombatSim = m[2]
	var sem := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "escudo_da_fe", "target": "bandido_1", "targets": ["bandido_1"]})
	check(not sem.ok, "reação não se lança no próprio turno sem aprimoramento de execução")
	var com := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "escudo_da_fe", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]})
	check(com.ok, "com o aprimoramento 0 é ação padrão no alcance de toque: %s" % str(com))


func test_escudo_da_fe_conexao_divide_o_dano_com_o_conjurador() -> void:
	var m := _duas_cenas(5)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("magia.escudo_da_fe", "link", 1, "cena", "player")
	var pv_alvo: int = sim.c("bandido_1").sheet.pv
	var eu: CharacterSheet = sim.c("player").sheet   # a simulação trabalha com cópia da ficha
	var pv_meu: int = eu.pv
	sim.apply_damage("bandido_1", 10)
	check(sim.c("bandido_1").sheet.pv == pv_alvo - 5, "alvo sofre metade")
	check(eu.pv == pv_meu - 5, "conjurador recebe a outra metade")


func test_protecao_divina_reacao_ap1_e_bloqueada_no_turno() -> void:
	var m := _cena_com("protecao_divina", 5, Vector2i(27, 57))
	var sim: CombatSim = m[2]
	sim.c("bandido_1")["side"] = sim.c("player")["side"]
	sim.c("player").sheet.pm = 20
	var a := {"type": "cast", "spell": "protecao_divina", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [1]}
	check(not GhostPlanner.validate_action(sim, "player", a).ok, "reação (ap1) não pode ser lançada no próprio turno")
	var base := {"type": "cast", "spell": "protecao_divina", "target": "bandido_1", "targets": ["bandido_1"]}
	check(GhostPlanner.validate_action(sim, "player", base).ok, "base de Proteção Divina é lançável no turno")


func test_protecao_divina_reacao_da_mais_cinco_no_teste() -> void:
	var m := _duas_cenas(5)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("player").sheet.spells = PackedStringArray(["protecao_divina"])
	sim.c("player").sheet.pm = 20
	var pm_antes: int = sim.c("player").sheet.pm
	var out: Array = []
	c._reacao_protecao("bandido_2", "bandido_1", out)
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	eq(alvo.efeito_bonus("proxima_resistencia"), 5, "reação dá +5 no próximo teste de resistência")
	check(sim.c("player").sheet.pm < pm_antes, "a reação custa PM")
	var pm_depois: int = sim.c("player").sheet.pm
	c._reacao_protecao("bandido_2", "bandido_1", out)
	eq(sim.c("player").sheet.pm, pm_depois, "uma reação por alvo por rodada")
	var base := alvo.skill_value("fortitude", sim.rules)
	var teste := Checks.skill(alvo, "fortitude", 10, sim.rules, RngStreams.new(3), "combat")
	eq(teste.mod, base + 5, "o +5 entra no teste de Fortitude")
	eq(alvo.efeito_bonus("proxima_resistencia"), 0, "o bônus é gasto no teste")
	var fora: Array = []
	c._reacao_protecao("bandido_2", "player", fora)
	eq(sim.c("player").sheet.pm, pm_depois, "não reage por quem não é aliado")


func test_curar_ferimentos_cura_anula_infligir_e_remove_cansaco() -> void:
	var m := _cena_com("curar_ferimentos", 1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1")["side"] = sim.c("player")["side"]
	sim.c("player").sheet.pm = 20
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	var a := {"type": "cast", "spell": "curar_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "curar válida em aliado adjacente: %s" % str(v))
	alvo.pv = 1
	c._cast("player", a, v)
	check(alvo.pv > 1, "cura PV: %d" % alvo.pv)
	alvo.pv = 1
	alvo.add_efeito("magia.infligir_ferimentos", "condicao", 0, "cena", "fraco")
	alvo.add_condition("fraco", sim.rules)
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not alvo.conditions.has("fraco") and not alvo.has_efeito("magia.infligir_ferimentos"), "anula Infligir Ferimentos")
	var a1 := {"type": "cast", "spell": "curar_ferimentos", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [1]}
	alvo.add_condition("fatigado", sim.rules)
	var v1 := GhostPlanner.validate_action(sim, "player", a1)
	check(v1.ok, "aprimoramento de cansaço válido: %s" % str(v1))
	c._cast("player", a1, v1)
	check(not alvo.conditions.has("fatigado"), "+2 PM remove cansaço")


func test_curar_ferimentos_truque_contra_morto_vivo_causa_dano() -> void:
	var m := _cena_com("curar_ferimentos", 1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	alvo.creature_type = "morto-vivo"
	alvo.pv = 10
	var a := {"type": "cast", "spell": "curar_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "truque válido contra morto-vivo adjacente: %s" % str(v))
	c._cast("player", a, v)
	check(alvo.pv < 10, "contra morto-vivo causa dano, não cura (PV %d)" % alvo.pv)


func test_vestimenta_da_fe_defesa_resistencia_e_reducao() -> void:
	var m := _cena_com("vestimenta_da_fe", 13)   # 4º círculo do clérigo (requerido pelo aprimoramento 2)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1")["side"] = sim.c("player")["side"]
	sim.c("player").sheet.pm = 30
	var alvo: CharacterSheet = sim.c("bandido_1").sheet
	var def_antes := alvo.defense(sim.rules)
	var res_antes := alvo.skill_value("fortitude", sim.rules)
	var a := {"type": "cast", "spell": "vestimenta_da_fe", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0, 1, 2]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "todos os aprimoramentos válidos com nível 9: %s" % str(v))
	c._cast("player", a, v)
	eq(alvo.defense(sim.rules) - def_antes, 3, "+2 da base e +1 do aprimoramento na Defesa")
	eq(Checks.skill(alvo, "fortitude", 10, sim.rules, RngStreams.new(2), "combat").mod - res_antes, 3, "+2 e +1 em resistências")
	eq(alvo.efeito_rd("fogo"), 5, "redução de dano 5 contra todos os tipos")
	alvo.limpar_dia(999)
	eq(alvo.efeito_bonus("defesa"), 0, "o efeito acaba no dia seguinte")


func test_habilidades_do_barbaro_escalam_com_o_nivel() -> void:
	var sh := _build("barbaro")
	sh.level = 2
	eq(ClassFeatures.instinto_bonus(sh), 0, "instinto só a partir do 3º nível")
	sh.level = 3
	eq(ClassFeatures.instinto_bonus(sh), 1, "instinto +1 no 3º nível")
	sh.level = 9
	eq(ClassFeatures.instinto_bonus(sh), 2, "instinto +2 no 9º nível")
	sh.level = 15
	eq(ClassFeatures.instinto_bonus(sh), 3, "instinto +3 no 15º nível")
	var rd := {4: 0, 5: 2, 8: 4, 11: 6, 14: 8, 17: 10, 20: 10}
	for nivel in rd:
		sh.level = nivel
		eq(ClassFeatures.reducao_dano(sh), rd[nivel], "redução de dano no %dº nível" % nivel)
	sh.level = 19
	eq(ClassFeatures.furia_bonus(sh), 5, "fúria +5 antes do 20º nível")
	sh.level = 20
	eq(ClassFeatures.furia_bonus(sh), 10, "fúria titânica dobra o bônus")
	eq(ClassFeatures.instinto_pericia(sh, "reflexos"), ClassFeatures.instinto_bonus(sh), "instinto vale em Reflexos")
	eq(ClassFeatures.instinto_pericia(sh, "atletismo"), 0, "instinto não vale em outras perícias")


func _cena_paladino(nivel: int) -> WorldState:
	var sh := _build("paladino")
	sh.level = nivel
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	w.modules.combat.sim.c("player").tile = Vector2i(26, 57)
	w.modules.combat.sim.c("bandido_1").tile = Vector2i(27, 57)
	return w


func test_golpe_divino_soma_carisma_e_dado_e_custa_pm() -> void:
	var w := _cena_paladino(1)
	var sim: CombatSim = w.modules.combat.sim
	var P: CharacterSheet = sim.c("player").sheet
	P.pm = 10
	sim.toggles["golpe_divino"] = "nunca"
	var off := sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(int(off.get("golpe_dados", 0)), 0, "desligado: sem dado extra")
	sim.toggles["golpe_divino"] = "auto"
	var on := sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(int(on.golpe_dados), 1, "nível 1: 1d8 por 2 PM")
	eq(int(on.mod) - int(off.mod), int(P.attrs["car"]), "+Carisma no ataque")
	eq(float(on.avg_damage) - float(off.avg_damage), 4.5, "+1d8 no dano médio")


func test_golpe_divino_passos_extras_em_niveis_altos() -> void:
	var w := _cena_paladino(8)
	var sim: CombatSim = w.modules.combat.sim
	var P: CharacterSheet = sim.c("player").sheet
	P.pm = 10
	sim.toggles["golpe_divino_extra"] = "auto"
	var p := sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(int(p.golpe_dados), 3, "nível 8: até 2 passos extras (1 + 2 dados)")
	P.pm = 3
	var pouco := sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(int(pouco.golpe_dados), 2, "com 3 PM: 2 PM do golpe e só 1 passo")
	sim.toggles["golpe_divino_extra"] = "nunca"
	eq(int(sim.attack_profile("player", "bandido_1", 0, false, false).golpe_dados), 1, "extras desligados")
