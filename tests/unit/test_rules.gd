extends TestCase


func test_catalogo_carrega_sem_erros_e_com_proveniencia() -> void:
	var r := RuleRegistry.load_default()
	check(r.errors.is_empty(), "erros: %s" % str(r.errors))
	check(r.size() >= 50, "pelo menos 50 regras (%d)" % r.size())
	for id in r.ids_with_prefix(""):
		var e := r.entry(id)
		check(e.has("fonte") and e.has("pagina") and e.has("status"), "proveniência em " + id)


func test_regra_sem_fonte_e_rejeitada() -> void:
	var r := RuleRegistry.new()
	check(not r.add({"id": "x", "valor": 1, "pagina": 1, "status": "VERIFICADA"}), "sem fonte rejeitada")
	check(not r.add({"id": "y", "valor": 1, "fonte": "LB", "pagina": 1, "status": "INVENTADA"}), "status inválido rejeitado")
	check(r.add({"id": "z", "valor": 1, "fonte": "", "pagina": 0, "status": "ORIGINAL_DO_JOGO"}), "original sem fonte aceita")


func test_pendentes_sao_reportados() -> void:
	var r := RuleRegistry.load_default()
	check(not r.unverified_ids().has("criatura.hiena"), "hiena reconferida com layout (Bestiário p.120)")
	eq(r.unverified_ids().size(), 0, "R1: nenhuma regra pendente após a conferência de 24/10/2026")
	r.add({"id": "teste.pendente", "valor": 1, "fonte": "x", "pagina": 1, "pdf_page": 1, "status": "PENDENTE_REVISAO"})
	check(r.unverified_ids().has("teste.pendente"), "uma regra nova pendente continua sendo reportada")


func test_ficha_guerreiro_segue_regras() -> void:
	var r := RuleRegistry.load_default()
	var s := CharacterSheet.premade_warrior(r)
	eq(s.pv_max, 23, "PV = 20 + Con 3 (LB p.65)")
	eq(s.pm_max, 3, "PM = 3/nível")
	eq(s.skill_value("luta", r), 6, "Luta = 0 + For 4 + treino 2 (LB p.114)")
	eq(s.skill_value("conhecimento", r), 1, "não treinada = metade do nível + Int")
	check(not s.can_use_skill("ladinagem", r), "Ladinagem é somente treinada")
	eq(s.defense(r), 16, "Defesa = 10 + Des 3 + couro batido 3")
	eq(s.death_threshold(), -11, "morre em min(-10, -PV/2)")


func test_condicoes_nao_acumulam_e_implicam() -> void:
	var r := RuleRegistry.load_default()
	var s := CharacterSheet.premade_warrior(r)
	s.add_condition("desprevenido", r)
	s.add_condition("vulneravel", r)
	eq(s.defense(r), 11, "desprevenido -5 e vulnerável -2 => só -5 (LB p.394)")
	s.conditions.clear()
	s.pv = 0
	check(s.has_effective_condition(r, "indefeso"), "0 PV => inconsciente => indefeso")
	check(not s.can_act(r), "inconsciente não age")


func test_escada_de_condicoes_e_penalidades() -> void:
	var r := RuleRegistry.load_default()
	var s := CharacterSheet.premade_warrior(r)
	s.add_condition("abalado", r)
	s.add_condition("abalado", r)
	check(s.conditions.has("apavorado") and not s.conditions.has("abalado"), "abalado de novo vira apavorado (LB p.394)")
	s.add_condition("abalado", r)
	check(not s.conditions.has("abalado"), "abalado é ignorado com apavorado ativo")
	s.conditions.clear()
	s.add_condition("fraco", r)
	s.add_condition("fraco", r)
	check(s.conditions.has("debilitado") and not s.conditions.has("fraco"), "fraco de novo vira debilitado")
	s.add_condition("debilitado", r)
	s.add_condition("fraco", r)
	check(not s.conditions.has("fraco"), "fraco é ignorado com debilitado ativo")
	s.conditions.clear()
	s.add_condition("fatigado", r)
	check(s.has_effective_condition(r, "fraco") and s.has_effective_condition(r, "vulneravel"), "fatigado: fraco e vulnerável")
	s.add_condition("fatigado", r)
	check(s.conditions.has("exausto") and not s.conditions.has("fatigado"), "fatigado de novo vira exausto")
	check(s.has_effective_condition(r, "debilitado") and s.has_effective_condition(r, "lento"), "exausto: debilitado e lento")
	s.conditions.clear()
	s.add_condition("exausto", r)
	s.add_condition("fatigado", r)
	check(s.conditions.has("exausto") and not s.conditions.has("fatigado"), "fatigado é ignorado com exausto ativo")
	s.add_condition("exausto", r)
	check(s.conditions.has("inconsciente") and not s.conditions.has("exausto"), "exausto de novo vira inconsciente")
	var rng := RngStreams.new(5)
	s.conditions.clear()
	var base_atl := s.skill_value("atletismo", r)
	s.add_condition("fraco", r)
	eq(Checks.skill(s, "atletismo", 10, r, rng).mod, base_atl - 2, "fraco: -2 em perícias de For/Des/Con")
	s.conditions.clear()
	var base_per := s.skill_value("percepcao", r)
	s.add_condition("ofuscado", r)
	eq(Checks.skill(s, "percepcao", 10, r, rng).mod, base_per - 2, "ofuscado: -2 em Percepção")
	s.conditions.clear()
	var base_ref := s.skill_value("reflexos", r)
	s.add_condition("desprevenido", r)
	eq(Checks.skill(s, "reflexos", 10, r, rng).mod, base_ref - 5, "desprevenido: -5 em Reflexos")
	s.conditions.clear()
	s.add_condition("indefeso", r)
	var fr := Checks.skill(s, "reflexos", 1, r, rng)
	check(not fr.success and fr.falha_automatica, "indefeso falha sempre em Reflexos")
	s.conditions.clear()
	s.add_condition("debilitado", r)
	var at := Checks.attribute(s, "for", 1, r, rng)
	eq(at.total - at.d20, int(s.attrs["for"]) - 5, "debilitado: -5 em testes de For")


func test_critico_multiplica_so_dados() -> void:
	var rng := RngStreams.new(3)
	var normal := Dice.roll("1d8", rng, "combat", 1, 4)
	var crit := Dice.roll("1d8", rng, "combat", 2, 4)
	eq(normal.rolls.size(), 1, "1 dado")
	eq(crit.rolls.size(), 2, "x2 = 2 dados")
	eq(crit.bonus, 4, "bônus de Força não multiplicado")


func test_teste_de_pericia_e_d20_mais_mod() -> void:
	var r := RuleRegistry.load_default()
	var s := CharacterSheet.premade_warrior(r)
	var rng := RngStreams.new(11)
	var c := Checks.skill(s, "percepcao", 15, r, rng)
	eq(c.total, c.d20 + 3, "Percepção = 0 + Sab 1 + treino 2")
	eq(c.success, c.total >= 15, "sucesso se >= CD")
	eq(Checks.chance(5, 15), 0.55, "chance de 1d20+5 >= 15")


func test_r1_regras_conferidas_no_livro() -> void:
	var r := RuleRegistry.load_default()
	for id in ["defesa.base", "descanso.duracao_horas", "arma.funda", "item.pocao_curar_ferimentos", "perigo.jornada_ermos.cd", "panteao.nomes"]:
		eq(r.entry(id).status, "VERIFICADA", id)
	eq(int(r.value("perigo.jornada_ermos.cd").floresta), 20, "floresta CD 20 (LB p.320)")
	eq((r.value("panteao.nomes") as Array).size(), 20, "vinte deuses")
	var s := CharacterSheet.new()
	s.equipment = {"weapon": "funda", "armor": ""}
	CharacterBuilder.apply_equipment(r, s)
	check(s.attacks[0].for_no_dano, "funda soma Força no dano (LB p.148)")
