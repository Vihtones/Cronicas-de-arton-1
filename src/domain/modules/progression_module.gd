class_name ProgressionModule
extends WorldModule
## Progressão. Dois modos:
## - "livro": XP = ND × 1000 / personagens; empate ½, derrota ¼; ND 5+ abaixo do nível = 0 (LB p.326).
## - "dinamica" (padrão, ORIGINAL_DO_JOGO): mesma base do livro × multiplicador de
##   desempenho e circunstâncias do combate, com retorno decrescente por repetição,
##   XP de aprendizado (testes difíceis) e de evasão. A conta é sempre mostrada ao jogador.
## Subida de nível: PV/PM pela classe e escolha de poder (ChoosePower).

const MYSTERY_ND := 1.0
const MULT_MIN := 0.5
const MULT_MAX := 2.0
const NOVELTY_DECAY := 0.25       # cada vitória anterior sobre o mesmo tipo reduz 25%...
const NOVELTY_FLOOR := 0.4        # ...até 40% da base
const LEARN_XP_PER_CD := 20       # (CD - 10) × 20 XP por teste difícil bem-sucedido, uma vez por alvo/abordagem
const LEARN_MIN_CD := 15

var mode := "dinamica"
var log: Array[Dictionary] = []
var kills_by_rule: Dictionary = {}   # regra da criatura -> vitórias anteriores
var learned: Dictionary = {}         # chave de teste -> true
var evaded: Dictionary = {}          # grupo -> true

const POWERS := {
	"guerreiro": ["especializacao_arma", "valentao", "golpe_raspao", "ataque_reflexo", "impeto", "arqueiro", "aumento_atributo"],
	"ladino": ["gatuno", "truque_magico", "emboscar", "velocidade_ladina", "rolamento_defensivo", "sombra", "aumento_atributo"],
	"arcanista": ["arcano_de_batalha", "magia_pungente", "poder_magico", "raio_arcano", "aumento_atributo"],
}
## Poderes gerais (LB p.124: um poder de classe pode ser trocado por um geral). Só os implementados
## entram como opção; a árvore também mostra os ainda não implementados (marcados).
const GENERAL_POWERS := ["ataque_poderoso", "trespassar", "combate_defensivo", "esquiva", "reflexos_combate",
	"saque_rapido", "vitalidade", "vontade_de_ferro"]
const GENERAL_TREE_ONLY := ["quebrar_aprimorado", "derrubar_aprimorado", "desarmar_aprimorado",
	"acuidade_com_arma", "ataque_com_escudo", "ataque_preciso", "ataque_pesado", "arma_secundaria_grande", "arremesso_multiplo", "arremesso_potente", "bloqueio_com_escudo", "carga_de_cavalaria", "disparo_preciso", "disparo_rapido", "empunhadura_poderosa", "encouracado", "estilo_de_arma_e_escudo", "estilo_de_arma_longa", "estilo_de_arremesso", "estilo_de_disparo", "estilo_de_duas_armas", "estilo_de_duas_maos", "estilo_de_uma_arma", "estilo_desarmado", "fanatico", "finta_aprimorada", "foco_em_arma", "ginete", "inexpugnavel", "mira_apurada", "piqueiro", "presenca_aterradora", "proficiencia",
	"acrobatico", "ao_sabor_do_destino", "aparencia_inofensiva", "atletico", "atraente", "comandar", "costas_largas", "foco_em_pericia", "inventario_organizado", "investigador", "lobo_solitario", "medicina", "parceiro", "sentidos_agucados", "sortudo", "surto_heroico", "torcida", "treinamento_em_pericia", "venefico", "celebrar_ritual", "escrever_pergaminho", "preparar_pocao", "foco_em_magia", "magia_acelerada", "magia_ampliada", "magia_discreta", "magia_ilimitada",
	"afinidade_com_a_tormenta", "almejar_o_impossivel", "anfibio", "apostar_com_o_trapaceiro", "armas_da_ambicao", "arsenal_das_profundezas", "astucia_da_serpente", "ataque_piedoso", "aura_de_medo", "aura_de_paz", "aura_restauradora", "bencao_do_mana", "caricia_sombria", "centelha_magica", "compreender_os_ermos", "conhecimento_enciclopedico", "conjurar_arma", "coragem_total", "cura_gentil", "curandeira_perfeita", "dedo_verde", "descanso_natural", "dom_da_esperanca", "dom_da_imortalidade", "dom_da_profecia", "dom_da_ressurreicao", "dom_da_verdade", "escamas_draconicas", "escudo_magico", "espada_justiceira", "espada_solar", "extase_da_loucura", "familiar_ofidico", "farsa_do_fingidor", "fe_guerreira", "forma_de_macaco", "fulgor_solar", "furia_divina", "golpista_divino", "habitante_do_deserto", "inimigo_de_tenebra", "kiai_divino", "liberdade_divina", "manto_da_penumbra", "mente_analitica", "mente_vazia", "mestre_dos_mares", "olhar_amedrontador", "palavras_de_bondade", "percepcao_temporal", "pesquisa_abencoada", "poder_oculto", "presas_primordiais", "sopro_do_mar", "presas_venenosas", "rejeicao_divina", "reparar_injustica", "sangue_de_ferro", "sangue_ofidico", "servos_do_dragao", "sorte_dos_loucos", "talento_artistico", "teurgista_mistico", "tradicao_de_lin_wu", "transmissao_da_loucura", "tropas_duyshidakk", "urro_divino", "visao_nas_trevas", "voz_da_civilizacao", "voz_da_natureza", "voz_dos_monstros", "zumbificar", "anatomia_insana", "antenas", "armamento_aberrante", "articulacoes_flexiveis", "asas_insetoides", "carapaca", "corpo_aberrante", "cuspir_enxame", "dentes_afiados", "desprezar_a_realidade", "empunhadura_rubra", "fome_de_mana", "larva_explosiva", "legiao_aberrante", "maos_membranosas", "membros_estendidos", "membros_extras", "mente_aberrante", "olhos_vermelhos", "pele_corrompida", "sangue_acido", "visco_rubro"]
## Poderes de classe do livro ainda sem efeito no jogo: aparecem na árvore como "não implementado",
## mas não entram nas opções de subida de nível (available_powers só lê POWERS e GENERAL_POWERS).
const CLASS_TREE_ONLY := {
	"guerreiro": ["ambidestria", "esgrimista", "especializacao_armadura", "golpe_pessoal", "bater_e_correr", "golpe_demolidor", "destruidor", "mestre_em_arma", "planejamento_marcial", "romper_resistencias", "solidez", "tornado_de_dor"],
	"ladino": ["assassinar", "contatos_no_submundo", "escapista", "fuga_formidavel", "ladrao_arcano", "mao_na_boca", "maos_rapidas", "mente_criminosa", "oportunismo", "roubo_de_mana", "saqueador_de_tumbas", "veneno_persistente", "veneno_potente"],
	"arcanista": ["caldeirao_do_bruxo", "conhecimento_magico", "contramagica_aprimorada", "envolto_em_misterio", "escriba_arcano", "especialista_em_escola", "familiar", "fluxo_de_mana", "foco_vital", "fortalecimento_arcano", "heranca_aprimorada", "heranca_superior", "mestre_em_escola", "raio_elemental", "raio_poderoso", "tinta_do_mago"],
}


func module_id() -> String: return "progression"
func handled_commands() -> PackedStringArray: return PackedStringArray(["ChoosePower", "SetXpMode"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["CREATURE_DEFEATED", "COMBAT_ENDED", "MYSTERY_RESOLVED", "TARGET_INSPECTED", "DIALOGUE_TEST", "STEALTH_CHECK"])


static func nd_value(nd: Variant) -> float:
	var s := str(nd)
	if s.contains("/"):
		return float(s.get_slice("/", 0)) / float(s.get_slice("/", 1))
	return float(s)


func _nd_of(creature: String) -> float:
	return nd_value(world.rules.value(world.db.creature_def(creature).get("rule", ""), {}).get("nd", "0"))


func xp_for(nd: float, result: String = "vitoria", party: int = 1) -> int:
	var rule: Dictionary = world.rules.value("progressao.xp_desafio")
	if nd <= world.player_sheet.level - int(rule.irrelevante_se_nd_menor_que_nivel_menos):
		return 0
	var mult := 1.0
	if result == "empate": mult = float(rule.empate)
	elif result == "derrota": mult = float(rule.derrota)
	return int(nd * 1000.0 * mult / maxi(1, party))


func xp_to_next() -> int:
	return xp_do_nivel(world.player_sheet.level + 1)


## XP total para alcançar o nível n. A tabela do LB vai até o 10; depois a curva continua (extensão ORIGINAL),
## a mesma que gera a tabela inteira: 500 × n × (n−1). Sem teto: o personagem pode subir sem limite.
func xp_do_nivel(n: int) -> int:
	var t: Dictionary = world.rules.value("progressao.xp_por_nivel")
	if t.has(str(n)):
		return int(t[str(n)])
	return 500 * n * (n - 1)


## O que falta para o poder ficar disponível: atributo, perícia ou poder exigido. Vazio se nada falta.
func falta_texto(p: String) -> String:
	var s := world.player_sheet
	var pre: Dictionary = world.rules.value("poder." + p, {}).get("prereq", {})
	var falta: Array = []
	for k in pre:
		if k == "treinado":
			if not s.trained.has(str(pre[k])):
				falta.append("treinar " + str(pre[k]).capitalize())
		elif k == "poder":
			if not s.has_power(str(pre[k])):
				falta.append("poder " + str(pre[k]).replace("_", " ").capitalize())
		elif k == "nivel":
			if s.level < int(pre[k]):
				falta.append("%dº nível (tem %d)" % [int(pre[k]), s.level])
		elif k == "texto":
			pass
		elif int(s.attrs.get(k, 0)) < int(pre[k]):
			falta.append("%s %d (tem %d)" % [str(k).to_upper(), int(pre[k]), int(s.attrs.get(k, 0))])
	return ", ".join(falta)


## Detalhes de um poder para a interface: efeito, pré-requisito, o que falta, custo e página do livro.
func power_info(p: String) -> Dictionary:
	var r: Dictionary = world.rules.value("poder." + p, {})
	return {"id": p, "efeito": efeito_texto(r), "pre": prereq_texto(r.get("prereq", {})), "falta": falta_texto(p),
		"pagina": int(world.rules.entry("poder." + p).get("pagina", 0)), "custo": int(r.get("custo_pm", 0))}


## Multiplicador dinâmico a partir das estatísticas do combate. Retorna {mult, breakdown}.
func combat_multiplier(stats: Dictionary, outcome: String) -> Dictionary:
	var lines: Array = []
	var bonus := 0.0
	var enemies: Array = stats.get("enemies", [])
	var n := enemies.size()
	if n > 1:
		var b := minf(0.3, 0.1 * (n - 1))
		bonus += b; lines.append(["desvantagem numérica (%d inimigos)" % n, b])
	var nd_total := 0.0
	for id in enemies: nd_total += _nd_of(id)
	var lvl := world.player_sheet.level
	if nd_total > lvl:
		var b := minf(0.45, 0.15 * (nd_total - lvl))
		bonus += b; lines.append(["desafio acima do nível (ND %.2g vs nível %d)" % [nd_total, lvl], b])
	for k in stats.get("adverse", {}):
		bonus += 0.1; lines.append(["circunstância adversa: " + str(k), 0.1])
	if stats.get("went_down", false) and outcome == "vitoria":
		bonus += 0.15; lines.append(["virou o jogo depois de cair", 0.15])
	var tactics: Array = stats.get("tactics", {}).keys()
	if not tactics.is_empty():
		var b := minf(0.2, 0.05 * tactics.size())
		bonus += b; lines.append(["táticas: " + ", ".join(tactics), b])
	if outcome == "vitoria":
		var pv_max := maxi(1, int(stats.get("pv_max", 1)))
		if int(stats.get("dmg_taken", 0)) <= pv_max / 4:
			bonus += 0.1; lines.append(["quase sem ferimentos", 0.1])
		elif int(stats.get("pv_end", pv_max)) <= pv_max / 4:
			bonus += 0.1; lines.append(["por um fio", 0.1])
		if int(stats.get("rounds", 99)) <= n + 1:
			bonus += 0.1; lines.append(["vitória rápida (%d rodadas)" % int(stats.get("rounds", 0)), 0.1])
	var mult := clampf(1.0 + bonus, MULT_MIN, MULT_MAX)
	return {"mult": mult, "breakdown": lines}


func novelty(rule_id: String) -> float:
	return maxf(NOVELTY_FLOOR, 1.0 - NOVELTY_DECAY * int(kills_by_rule.get(rule_id, 0)))


func on_event(e: GameEvent) -> Array:
	match e.event_type:
		"CREATURE_DEFEATED":
			if mode == "livro" and e.payload.get("by", "") == "player":
				return _award(xp_for(_nd_of(e.payload.creature)), "derrotou " + str(e.payload.get("name", "")), [])
		"COMBAT_ENDED":
			return _combat_xp(e.payload)
		"MYSTERY_RESOLVED":
			if e.payload.get("by", "") == "player":
				var base := xp_for(MYSTERY_ND)
				if mode == "dinamica":
					var ex = world.module("exploration")
					var right := 0
					var wrong := 0
					if ex != null:
						for h in ex.hypothesis_view():
							if h.mystery != e.payload.mystery: continue
							if h.state == "acredito" and h.contradicting.is_empty() and not h.supporting.is_empty(): right += 1
							elif h.state == "acredito" and not h.contradicting.is_empty(): wrong += 1
					var m := clampf(1.0 + 0.15 * right - 0.1 * wrong, MULT_MIN, MULT_MAX)
					return _award(int(base * m), "mistério resolvido", [["hipóteses certas: %d, erradas: %d" % [right, wrong], m - 1.0]])
				return _award(base, "mistério resolvido", [])
		"TARGET_INSPECTED", "DIALOGUE_TEST":
			if mode != "dinamica":
				return []
			var c: Dictionary = e.payload.get("check", {})
			if not c.get("success", false) or int(c.get("cd", 0)) < LEARN_MIN_CD:
				return []
			var key := "%s|%s|%s" % [e.payload.get("target", e.payload.get("npc", "")), e.payload.get("approach", ""), c.get("skill", "")]
			if learned.has(key):
				return []
			learned[key] = true
			return _award((int(c.cd) - 10) * LEARN_XP_PER_CD, "aprendizado: %s CD %d" % [c.get("skill", ""), int(c.cd)], [])
		"STEALTH_CHECK":
			if mode != "dinamica" or not e.payload.get("success", false):
				return []
			# Uma vez por criatura (não por grupo): o grupo muda conforme quem está perto, e isso reabria o XP.
			var fresh := false
			for id in e.payload.group:
				if not evaded.has(str(id)):
					fresh = true
				evaded[str(id)] = true
			if not fresh:
				return []
			var nd := 0.0
			for id in e.payload.group: nd += _nd_of(id)
			return _award(int(xp_for(nd) * 0.25), "passou despercebido", [])
	return []


func _combat_xp(p: Dictionary) -> Array:
	var outcome: String = p.get("outcome", "")
	if outcome == "morte":
		return []
	var stats: Dictionary = p.get("stats", {})
	# Fugir e ser capturado NÃO rendem XP: recompensar a fuga permitia entrar e sair da visão do inimigo para farmar XP.
	if outcome in ["fuga", "captura"]:
		return []
	var result := "vitoria"
	if mode == "livro":
		return []
	# dinâmica: base do livro por inimigo (com novidade) × multiplicador de desempenho
	var base := 0.0
	var lines: Array = []
	for id in p.get("enemies", []):
		var rule_id: String = world.db.creature_def(id).get("rule", "")
		var x := float(xp_for(_nd_of(id), result))
		var nov := novelty(rule_id) if outcome == "vitoria" else 1.0
		if nov < 1.0:
			lines.append(["repetição: %s (×%.2f)" % [world.db.creature_def(id).name, nov], 0.0])
		base += x * nov
	if outcome == "vitoria":
		for id in p.get("enemies", []):
			var rule_id: String = world.db.creature_def(id).get("rule", "")
			kills_by_rule[rule_id] = int(kills_by_rule.get(rule_id, 0)) + 1
	var cm := combat_multiplier(stats, outcome)
	lines.append_array(cm.breakdown)
	return _award(int(round(base * cm.mult)), "combate (%s, ×%.2f)" % [outcome, cm.mult], lines,
		{"combat": true, "outcome": outcome, "base": int(round(base)), "mult": cm.mult})


## Entrada pública para ganhar XP fora de combate (ex.: debug, recompensas). Mesmo caminho do combate.
func ganha_xp(amount: int, reason: String) -> Array:
	return _award(amount, reason, [])


func _award(amount: int, reason: String, breakdown: Array, extra: Dictionary = {}) -> Array:
	if amount <= 0:
		return []
	var s := world.player_sheet
	s.xp += amount
	log.append({"tick": world.clock.tick, "xp": amount, "reason": reason, "breakdown": breakdown})
	if log.size() > 200: log.pop_front()
	var payload := {"amount": amount, "total": s.xp, "reason": reason, "breakdown": breakdown, "mode": mode,
		"next": xp_to_next(), "level": s.level}
	payload.merge(extra)
	var out: Array = [fact("XP_GAINED", payload, ["player"])]
	while s.xp >= xp_to_next():
		out.append(_level_up())
	return out


func _level_up() -> Dictionary:
	var s := world.player_sheet
	var c: Dictionary = world.rules.value("classe." + (s.class_id if s.class_id != "" else "guerreiro"))
	s.level += 1
	var pv_gain := int(c.pv_nivel) + int(s.attrs.con)
	var race: Dictionary = {} if s.race_id in ["", "humano"] else world.rules.value("raca." + s.race_id, {})
	pv_gain += int(race.get("pv_por_nivel", 0))
	if s.has_power("vitalidade"): pv_gain += 1                                   # Vitalidade (LB p.129)
	var pm_gain := int(c.pm_nivel) + (1 if s.has_power("poder_magico") else 0) + int(race.get("pm_por_nivel", 0))
	if s.has_power("vontade_de_ferro") and s.level % 2 == 0: pm_gain += 1       # Vontade de Ferro (LB p.131): +1 PM a cada dois níveis
	s.pv_max += pv_gain
	s.pv += pv_gain
	s.pm_max += pm_gain
	s.pm += pm_gain
	if s.class_id == "guerreiro" and s.level == 3:
		s.powers["durao"] = true  # habilidade de classe no 3º nível (LB p.66)
	s.pending_powers += 1
	return fact("LEVEL_UP", {"level": s.level, "pv_gain": pv_gain, "pm_gain": pm_gain, "pending_powers": s.pending_powers,
		"options": available_powers(), "opcoes": _opcoes_info()}, ["player"])


func _opcoes_info() -> Array:
	var out: Array = []
	for p in available_powers():
		out.append(power_info(p))
	return out


## Árvore de poderes para a interface: nós com estado (possui / disponível / bloqueado / não implementado),
## pré-requisitos em texto e arestas pai -> filho. Só leitura.
func power_tree() -> Dictionary:
	var s := world.player_sheet
	var cls := s.class_id if s.class_id != "" else "guerreiro"
	var avail := available_powers()
	var nodes: Array = []
	var branches := {cls: POWERS.get(cls, []) + CLASS_TREE_ONLY.get(cls, []), "geral": GENERAL_POWERS + GENERAL_TREE_ONLY}
	for br in branches:
		for p in branches[br]:
			var r: Dictionary = world.rules.value("poder." + p, {})
			var meta: Dictionary = world.rules.entry("poder." + p)
			var implemented := bool(r.get("implementado", true))
			var owned: bool = s.has_power(p) or (p == "aumento_atributo" and s.powers.keys().any(func(k): return str(k).begins_with("aumento_atributo")))
			var state := "possui" if owned else ("disponivel" if avail.has(p) else ("nao_implementado" if not implemented else "bloqueado"))
			if owned and (p == "aumento_atributo" or p == "especializacao_arma") and avail.has(p):
				state = "possui_repetivel"
			nodes.append({"id": p, "branch": br, "group": str(r.get("grupo", "classe")), "state": state, "parent": str(r.get("prereq", {}).get("poder", "")),
				"prereq": prereq_texto(r.get("prereq", {})), "effect": efeito_texto(r), "page": int(meta.get("pagina", 0)),
				"cost": int(r.get("custo_pm", 0)), "falta": falta_texto(p) if state == "bloqueado" else ""})
	return {"nodes": nodes, "pending": s.pending_powers, "class": cls}


static func prereq_texto(pre: Dictionary) -> String:
	var parts: Array = []
	for k in pre:
		match k:
			"treinado": parts.append("treinado em " + str(pre[k]).capitalize())
			"poder": parts.append(str(pre[k]).replace("_", " ").capitalize())
			"nivel": parts.append("%dº nível" % int(pre[k]))
			"texto": parts.append(str(pre[k]))
			_: parts.append("%s %d" % [str(k).capitalize(), int(pre[k])])
	return ", ".join(parts) if not parts.is_empty() else "—"


static func efeito_texto(r: Dictionary) -> String:
	if r.has("efeito"): return str(r.efeito)
	var parts: Array = []
	for k in ["defesa", "reflexos", "fortitude", "vontade", "iniciativa", "furtividade"]:
		if r.has(k): parts.append("+%d %s" % [int(r[k]), k.capitalize()])
	if r.has("pv_por_nivel"): parts.append("+%d PV por nível" % int(r.pv_por_nivel))
	if r.has("pm_por_nivel"): parts.append("+%d PM por nível" % int(r.pm_por_nivel))
	if r.has("pm_por_dois_niveis"): parts.append("+1 PM a cada dois níveis")
	if r.has("dano"): parts.append("dano %s (%s)" % [r.dano, r.get("dano_tipo", "")])
	if r.has("cd_bonus"): parts.append("+%d na CD" % int(r.cd_bonus))
	if r.has("deslocamento_m"): parts.append("+%dm de deslocamento" % int(r.deslocamento_m))
	return ", ".join(parts)


func available_powers() -> Array:
	var s := world.player_sheet
	var out: Array = []
	for p in POWERS.get(s.class_id if s.class_id != "" else "guerreiro", []) + GENERAL_POWERS:
		if p == "truque_magico" and int(s.attrs["int"]) < 1: continue
		if not prereq_ok(s, p): continue
		if p != "aumento_atributo" and p != "especializacao_arma" and s.powers.has(p): continue
		out.append(p)
	return out


## Pré-requisitos do livro registrados na regra do poder (atributo mínimo, perícia treinada).
func prereq_ok(s: CharacterSheet, p: String) -> bool:
	var pre: Dictionary = world.rules.value("poder." + p, {}).get("prereq", {})
	for k in pre:
		if k == "treinado":
			if not s.trained.has(str(pre[k])): return false
		elif k == "poder":
			if not s.has_power(str(pre[k])): return false
		elif k == "nivel":
			if s.level < int(pre[k]): return false
		elif k == "texto":
			pass  # condição de caminho ou de outro poder descrita em texto; não verificada aqui
		elif int(s.attrs.get(k, 0)) < int(pre[k]):
			return false
	return true


func validate(cmd: GameCommand) -> PackedStringArray:
	if cmd.type == "SetXpMode":
		return PackedStringArray() if cmd.payload.get("mode", "") in ["livro", "dinamica"] else PackedStringArray(["modo inválido"])
	var s := world.player_sheet
	if s.pending_powers <= 0: return PackedStringArray(["nenhum poder a escolher"])
	var p: String = cmd.payload.get("power", "")
	if not available_powers().has(p): return PackedStringArray(["poder indisponível: " + p])
	if p == "aumento_atributo" and not ["for", "des", "con", "int", "sab", "car"].has(cmd.payload.get("option", "")):
		return PackedStringArray(["escolha um atributo"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	if cmd.type == "SetXpMode":
		mode = cmd.payload.mode
		return [fact("XP_MODE_SET", {"mode": mode}, ["player"])]
	var s := world.player_sheet
	var p: String = cmd.payload.power
	var opt: String = str(cmd.payload.get("option", ""))
	match p:
		"especializacao_arma":
			s.powers[p] = opt if opt != "" else str(s.equipment.get("weapon", ""))
		"aumento_atributo":
			s.attrs[opt] = int(s.attrs[opt]) + 1
			if opt == "con":
				s.pv_max += s.level; s.pv += s.level  # Con retroativa (LB p.17)
			s.powers["aumento_atributo_%s_%d" % [opt, s.level]] = true
		"poder_magico":
			# +1 PM por nível de arcanista, retroativo (LB p.38)
			s.powers[p] = true
			s.pm_max += s.level; s.pm += s.level
		"vitalidade":
			s.powers[p] = true
			s.pv_max += s.level; s.pv += s.level        # +1 PV por nível de personagem (LB p.129)
		"vontade_de_ferro":
			s.powers[p] = true
			s.pm_max += s.level / 2; s.pm += s.level / 2  # +1 PM a cada dois níveis (LB p.131)
		"truque_magico":
			s.powers[p] = "seta_infalivel"
			if not s.spells.has("seta_infalivel"): s.spells.append("seta_infalivel")
		_:
			s.powers[p] = true
	s.pending_powers -= 1
	return [fact("POWER_CHOSEN", {"power": p, "option": opt, "rule": "poder." + p}, ["player"])]


func to_dict() -> Dictionary:
	return {"log": log.duplicate(true), "mode": mode, "kills_by_rule": kills_by_rule.duplicate(), "learned": learned.duplicate(), "evaded": evaded.duplicate()}


func from_dict(d: Dictionary) -> void:
	log.clear()
	for l in d.get("log", []):
		log.append(l)
	mode = d.get("mode", "dinamica")
	kills_by_rule = {}
	for k in d.get("kills_by_rule", {}): kills_by_rule[k] = int(d.kills_by_rule[k])
	learned = d.get("learned", {}).duplicate()
	evaded = d.get("evaded", {}).duplicate()
