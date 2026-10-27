extends TestCase
## Aptidões no estilo Nen (docs/PLANO_APTIDOES.md, fase 1). Ver src/domain/rules/aptitudes.gd.
const Apt := preload("res://src/domain/rules/aptitudes.gd")


func test_distancias_sao_simetricas_e_conectadas() -> void:
	for a in Apt.DOMINIOS:
		for b in Apt.DOMINIOS:
			eq(Apt.distancia(a, b), Apt.distancia(b, a), "simétrica %s-%s" % [a, b])
			check(Apt.distancia(a, b) >= 0, "conectada %s-%s" % [a, b])
	eq(Apt.distancia("fazer", "fazer"), 0, "mesmo domínio: 0 passos")
	eq(Apt.distancia("fazer", "criar"), 1, "vizinho: 1 passo")
	eq(Apt.distancia("fazer", "conhecer"), 2, "dois passos")
	eq(Apt.distancia("lutar", "comunicar"), 3, "lutar-sobreviver-cuidar-comunicar")
	eq(Apt.distancia("fazer", "nada"), -1, "domínio desconhecido")


func test_afinidade_precisa_somar_100_e_usar_dominios_conhecidos() -> void:
	eq(Apt.erro_afinidade({"fazer": 60, "criar": 40}), "", "válida")
	check(Apt.erro_afinidade({"fazer": 60}) != "", "soma 60 é inválida")
	check(Apt.erro_afinidade({"magia": 100}) != "", "domínio fora da lista")
	check(Apt.erro_afinidade({"fazer": -10, "criar": 110}) != "", "valor negativo")
	eq(Apt.afinidade_principal({"fazer": 30, "lutar": 70}), "lutar", "principal é o maior")
	eq(Apt.afinidade_principal({}), "", "sem afinidade, sem principal")


func test_ganho_cai_com_a_distancia_e_com_o_progresso() -> void:
	var aff := {"fazer": 70, "lutar": 30}
	var g0 := Apt.ganho(aff, "fazer", 0.0)
	var g1 := Apt.ganho(aff, "criar", 0.0)
	var g2 := Apt.ganho(aff, "conhecer", 0.0)
	check(g0 > g1 and g1 > g2, "quanto mais longe do principal, menor o ganho")
	check(Apt.ganho(aff, "fazer", 90.0) < g0, "retornos decrescentes perto de 100%")


func test_so_o_sucesso_gera_progresso_e_nomeia_no_limiar() -> void:
	var aff := {"fazer": 100}
	var e := Apt.praticar({}, aff, "fazer.cozinhar", false)
	eq(float(e.pct), 0.0, "falha não dá progresso")
	eq(int(e.pratica), 0, "falha não conta prática")
	for i in 200:
		e = Apt.praticar(e, aff, "fazer.cozinhar", true)
		if Apt.nomeada(float(e.pct)):
			break
	check(Apt.nomeada(float(e.pct)), "vira skill nomeada ao passar de 25%%: %.1f" % float(e.pct))
	check(not Apt.nomeada(0.0), "não nomeada no início")


func test_teto_de_80_sem_marco_e_100_com_marco() -> void:
	var aff := {"fazer": 100}
	var e := {}
	for i in 5000:
		e = Apt.praticar(e, aff, "fazer.cozinhar", true)
	check(float(e.pct) <= 80.0 and float(e.pct) > 79.0, "sem marco para em 80%%: %.2f" % float(e.pct))
	e["marco"] = true
	for i in 5000:
		e = Apt.praticar(e, aff, "fazer.cozinhar", true)
	check(float(e.pct) > 80.0, "com marco passa de 80%%: %.2f" % float(e.pct))
	check(float(e.pct) <= 100.0, "nunca passa de 100%%")


func test_bonus_de_teste_e_custo_de_aprender() -> void:
	eq(Apt.bonus(0.0), 0, "0% dá +0")
	eq(Apt.bonus(35.0), 3, "35% dá +3")
	eq(Apt.bonus(100.0), 10, "100% dá +10")
	var aff := {"fazer": 100}
	eq(Apt.custo_aprender(aff, "fazer"), 5, "domínio principal custa 5 XP")
	eq(Apt.custo_aprender(aff, "conhecer"), 15, "dois passos custam 15 XP")


func test_afinidade_e_aptidoes_sobrevivem_ao_save() -> void:
	var r := RuleRegistry.load_default()
	var s := CharacterSheet.premade_warrior(r)
	s.afinidade = {"fazer": 60, "criar": 40}
	s.praticar_aptidao("fazer.cozinhar", true)
	s.praticar_aptidao("fazer.cozinhar", true)
	var antes := float(s.aptidoes["fazer.cozinhar"].pct)
	var volta := CharacterSheet.from_dict(s.to_dict())
	eq(volta.afinidade, s.afinidade, "afinidade volta igual")
	eq(float(volta.aptidoes["fazer.cozinhar"].pct), antes, "progresso volta igual")
	eq(volta.bonus_aptidao("fazer.cozinhar"), Apt.bonus(antes), "bônus de teste volta igual")
	eq(s.bonus_aptidao("nao.existe"), 0, "aptidão ausente dá +0")
