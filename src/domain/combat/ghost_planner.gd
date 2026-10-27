class_name GhostPlanner
extends RefCounted
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
const Area := preload("res://src/domain/combat/area.gd")
## Projeção fantasma (§9): recebe o estado (somente leitura), clona e simula o plano
## sem dados. Mostra custos, alcance, chance de acerto e onde o plano fica inválido.
## Regra crítica: nunca altera o CombatSim original.


## Validação compartilhada por fantasma e execução real.
## Condições que a Cura pelas Mãos remove (LB p.82).
const CONDICOES_CURA_MAOS := ["abalado", "apavorado", "atordoado", "cego", "doente", "exausto", "fatigado", "surdo"]


static func _tem_condicao_de_cura(sh: CharacterSheet) -> bool:
	for c in CONDICOES_CURA_MAOS:
		if sh.conditions.has(c):
			return true
	return false


static func validate_action(sim: CombatSim, actor: String, a: Dictionary) -> Dictionary:
	var A := sim.c(actor)
	if A.is_empty() or not sim.conscious(actor):
		return {"ok": false, "reason": "não pode agir"}
	if not A.sheet.can_act(sim.rules):
		return {"ok": false, "reason": "condição impede ações"}
	var t: String = a.get("type", "")
	match t:
		"move":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			var path: Array = _tiles(a.get("path", []))
			if path.is_empty(): return {"ok": false, "reason": "caminho vazio"}
			var pc := sim.path_cost(actor, path)
			if not pc.ok: return pc
			var sp := sim.speed_squares(actor)
			if int(pc.cost) > sp: return {"ok": false, "reason": "custa %d quadrados; deslocamento %d" % [pc.cost, sp]}
			return {"ok": true, "kind": "movimento", "cost": pc.cost, "end": pc.end}
		"attack":
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "ação padrão já usada"}
			var special: bool = a.get("special", false)
			if special and A.sheet.pm < 1: return {"ok": false, "reason": "PM insuficiente para Ataque Especial"}
			if special and A.sheet.class_id != "guerreiro" and not A.sheet.source_rule.contains("guerreiro"): return {"ok": false, "reason": "sem Ataque Especial"}
			var prof := sim.attack_profile(actor, a.get("target", ""), int(a.get("attack", 0)), special, false)
			if not prof.ok: return prof
			if not sim.is_enemy(actor, a.target): return {"ok": false, "reason": "não é inimigo"}
			prof["kind"] = "padrao"
			return prof
		"ataque_extra":
			var ae: Dictionary = sim.rules.value("classe.guerreiro.ataque_extra")
			if A.sheet.class_id != "guerreiro" or A.sheet.level < int(ae.nivel): return {"ok": false, "reason": "Ataque Extra é do guerreiro de 6º nível"}
			if not (A.flags as Array).has("agrediu_%d" % sim.round_no): return {"ok": false, "reason": "use primeiro a ação agredir"}
			if (A.flags as Array).has("ataque_extra_%d" % sim.round_no): return {"ok": false, "reason": "uma vez por rodada"}
			if A.sheet.pm < int(ae.custo_pm): return {"ok": false, "reason": "PM insuficiente (2)"}
			var prof2 := sim.attack_profile(actor, a.get("target", ""), int(a.get("attack", 0)), false, false)
			if not prof2.ok: return prof2
			if not sim.is_enemy(actor, a.target): return {"ok": false, "reason": "não é inimigo"}
			prof2["kind"] = "livre"
			return prof2
		"charge":
			if not sim.can_spend("completa"): return {"ok": false, "reason": "investida exige ação completa"}
			if A.sheet.has_effective_condition(sim.rules, "lento"): return {"ok": false, "reason": "lento não pode fazer investida"}
			var path: Array = _tiles(a.get("path", []))
			if path.size() < 2: return {"ok": false, "reason": "investida exige ao menos 3m"}
			var dir: Vector2i = path[0] - A.tile
			var pos: Vector2i = A.tile
			for p in path:
				if p - pos != dir: return {"ok": false, "reason": "investida exige linha reta"}
				if sim.db.is_difficult(p): return {"ok": false, "reason": "investida proibida em terreno difícil"}
				pos = p
			var pc := sim.path_cost(actor, path)
			if not pc.ok: return pc
			if int(pc.cost) > sim.speed_squares(actor) * 2: return {"ok": false, "reason": "além do dobro do deslocamento"}
			var target: String = a.get("target", "")
			if sim.c(target).is_empty() or CombatSim.cheb(pc.end, sim.c(target).tile) != 1:
				return {"ok": false, "reason": "investida deve terminar adjacente ao alvo"}
			var probe := sim.clone()
			probe.c(actor).tile = pc.end
			var prof := probe.attack_profile(actor, target, int(a.get("attack", 0)), false, true)
			if not prof.ok: return prof
			if prof.ranged: return {"ok": false, "reason": "investida é corpo a corpo"}
			prof["kind"] = "completa"; prof["end"] = pc.end; prof["cost"] = pc.cost
			return prof
		"stand":
			if not A.sheet.conditions.has("caido"): return {"ok": false, "reason": "não está caído"}
			if (A.flags as Array).has("comando_senta_%d" % sim.turn_counter): return {"ok": false, "reason": "Comando (Senta): não se levanta neste turno"}
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			return {"ok": true, "kind": "movimento"}
		"coup":
			if not sim.can_spend("completa"): return {"ok": false, "reason": "golpe de misericórdia exige ação completa"}
			var target: String = a.get("target", "")
			var T := sim.c(target)
			if T.is_empty() or CombatSim.cheb(A.tile, T.tile) != 1: return {"ok": false, "reason": "alvo não adjacente"}
			if not T.sheet.has_effective_condition(sim.rules, "indefeso"): return {"ok": false, "reason": "alvo não está indefeso"}
			if T.sheet.is_dead(): return {"ok": false, "reason": "alvo já morto"}
			return {"ok": true, "kind": "completa"}
		"cast":
			# Armamento da Natureza (aprimoramento de 2 PM): execução de ação de movimento.
			# Execução do catálogo (padrão, movimento, completa, livre); Armamento da Natureza com aprimoramento: movimento.
			var exec_c := str(spell_rule(sim.rules, str(a.get("spell", ""))).get("execucao", "padrão"))
			var kind_c: String = {"movimento": "movimento", "completa": "completa", "livre": "livre"}.get(exec_c, "padrao")
			if str(a.get("spell", "")) == "armamento_da_natureza" and (a.get("aprimoramentos", []) as Array).has(1):
				kind_c = "movimento"
			if not sim.can_spend(kind_c): return {"ok": false, "reason": "lançar magia exige ação padrão" if kind_c == "padrao" else "sem a ação que a magia exige"}
			var sp_id: String = a.get("spell", "")
			var sp := spell_rule(sim.rules, sp_id)
			if sp_id == "raio_arcano":
				if not A.sheet.has_power("raio_arcano"): return {"ok": false, "reason": "poder Raio Arcano não adquirido"}
			elif not A.sheet.spells.has(sp_id): return {"ok": false, "reason": "magia não conhecida"}
			if sp.is_empty(): return {"ok": false, "reason": "magia sem regra"}
			if a.get("pungente", false) and not A.sheet.has_power("magia_pungente"):
				return {"ok": false, "reason": "você não tem Magia Pungente"}
			var cost := spell_cost(sim.rules, sp, a)
			if A.sheet.pm < cost: return {"ok": false, "reason": "PM insuficiente (%d)" % cost}
			var targets: Array = a.get("targets", [a.get("target", actor)])
			var apr: Array = a.get("aprimoramentos", [])
			if not SpellRules.pode_lancar_no_turno(sp_id, apr):
				if sp_id == "protecao_divina":
					return {"ok": false, "reason": "com o aprimoramento de reação, Proteção Divina age quando um aliado vai fazer teste de resistência"}
				return {"ok": false, "reason": "Escudo da Fé é reação: age quando um aliado é atacado (ou escolha execução padrão)"}
			if int(sp.get("circulo", 0)) > SpellRules.circulo_maximo(A.sheet, sim.rules):
				return {"ok": false, "reason": "magia de %dº círculo acima do que você conjura" % int(sp.get("circulo", 0))}
			if a.get("truque", false):
				if not SpellRules.tem_truque(sim.rules, sp_id): return {"ok": false, "reason": "essa magia não tem truque"}
				if not apr.is_empty() or a.get("pungente", false): return {"ok": false, "reason": "truques não se combinam com aprimoramentos"}
				if sp_id == "curar_ferimentos":
					for tg in targets:
						if not sim.combatants.has(tg) or sim.c(tg).sheet.creature_type != "morto-vivo":
							return {"ok": false, "reason": "o truque de Curar Ferimentos só afeta mortos-vivos"}
			if not SpellRules.aprimoramentos_validos(sp_id, apr, A.sheet, sim.rules):
				return {"ok": false, "reason": "aprimoramento não disponível para essa magia"}
			if sp_id == "resistencia_a_energia" and not SpellRules.tipo_energia_valido(str(a.get("tipo_energia", "fogo"))):
				return {"ok": false, "reason": "tipo de energia inválido"}
			if sp_id == "protecao_divina":
				for tg in targets:
					if sim.is_enemy(actor, tg):
						return {"ok": false, "reason": "Proteção Divina só protege aliados"}
			if sp_id == "perdicao":
				for tg in targets:
					if tg == actor or not sim.is_enemy(actor, tg):
						return {"ok": false, "reason": "Perdição só afeta inimigos"}
			if sp_id == "arma_magica":
				var alvo_am: String = a.get("target", actor)
				if not sim.combatants.has(alvo_am) or str(sim.c(alvo_am).sheet.equipment.get("weapon", "")) == "":
					return {"ok": false, "reason": "Arma Mágica precisa de uma arma empunhada"}
				if apr.has(1) and not ["acido", "eletricidade", "fogo", "frio"].has(str(a.get("elemento", ""))):
					return {"ok": false, "reason": "escolha o tipo de dano: acido, eletricidade, fogo ou frio"}
				if apr.has(2) and not apr.has(1):
					return {"ok": false, "reason": "o aprimoramento de 2d6 exige o de 1d6"}
			if sp_id == "aviso":
				if not ["alerta", "mensagem", "localizacao"].has(str(a.get("modo", "alerta"))): return {"ok": false, "reason": "escolha alerta, mensagem ou localização"}
				if targets.size() > 1 + apr.count(3): return {"ok": false, "reason": "alvos demais"}
				if apr.has(1) and str(a.get("modo", "")) != "mensagem": return {"ok": false, "reason": "a resposta é da mensagem"}
				if apr.has(2) and str(a.get("modo", "")) != "localizacao": return {"ok": false, "reason": "a duração é da localização"}
			if sp_id == "compreensao" and not apr.has(3):
				if targets.size() > 1 and not apr.has(1): return {"ok": false, "reason": "várias criaturas pedem o aprimoramento"}
			if sp_id == "visao_mistica":
				targets = [actor]
			if sp_id == "luz" or sp_id == "escuridao":
				var luz_v: bool = sp_id == "luz"
				var tg_l: String = a.get("target", "")
				var precisa_criatura: bool = (luz_v and (apr.has(3) or apr.has(6))) or (not luz_v and apr.has(2))
				if precisa_criatura and not sim.combatants.has(tg_l): return {"ok": false, "reason": "escolha uma criatura"}
				if luz_v and apr.has(2) and apr.size() > 1: return {"ok": false, "reason": "a luz permanente não se combina com outros aprimoramentos"}
				if luz_v and apr.has(3) and sim.c(tg_l).sheet.has_effective_condition(sim.rules, "cego"): return {"ok": false, "reason": "não afeta criaturas cegas"}
				if luz_v and apr.has(4):
					for q in a.get("tiles", []):
						if CombatSim.cheb(A.tile, Vector2i(int(q[0]), int(q[1]))) > int(sim.rules.value("alcance.quadrados", {}).get("longo", 60)): return {"ok": false, "reason": "globo fora do alcance longo"}
					targets = [actor]
				if not precisa_criatura and not sim.combatants.has(tg_l):
					targets = [actor]
				if not luz_v and apr.has(4):
					targets = [actor]
			if sp_id == "criar_elementos":
				var el := str(a.get("elemento", ""))
				if not SpellRules.ELEMENTOS.has(el): return {"ok": false, "reason": "escolha o elemento: água, ar, fogo ou terra"}
				if apr.has(1) and not ["agua", "terra"].has(el): return {"ok": false, "reason": "só se arremessa água ou terra"}
				if apr.has(2) and el != "fogo": return {"ok": false, "reason": "o dano extra é do fogo"}
				var quads: Array = a.get("tiles", [])
				if quads.size() > 1 + apr.count(0): return {"ok": false, "reason": "quadrados demais"}
				for q in quads:
					var tq := Vector2i(int(q[0]), int(q[1])) if q is Array else q as Vector2i
					if CombatSim.cheb(A.tile, tq) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "fora do alcance"}
				if not apr.has(1):
					targets = [actor]
			if sp_id == "acalmar_animal" or sp_id == "tranquilidade":
				var lim := 1 + apr.count(2 if sp_id == "acalmar_animal" else 1)
				if sp_id == "tranquilidade" and apr.has(2):
					lim = 999   # criaturas escolhidas
				if targets.size() > lim: return {"ok": false, "reason": "alvos demais"}
				for tg in targets:
					if not sim.combatants.has(tg) or tg == actor: return {"ok": false, "reason": "alvo inválido"}
					if not SpellRules.alvo_social_valido(sp_id, apr, sim.c(tg).sheet): return {"ok": false, "reason": "tipo de criatura que a magia não afeta"}
			if sp_id == "comando":
				if not SpellRules.ORDENS_COMANDO.has(str(a.get("ordem", ""))):
					return {"ok": false, "reason": "escolha a ordem: fuja, largue, pare, senta ou venha"}
				if targets.size() > 1 + apr.count(1):
					return {"ok": false, "reason": "alvos demais para o Comando"}
				for tg in targets:
					if not sim.combatants.has(tg) or tg == actor:
						return {"ok": false, "reason": "alvo inválido"}
					if not apr.has(0) and sim.c(tg).sheet.creature_type != "humanoide":
						return {"ok": false, "reason": "Comando afeta humanoides (aprimoramento: qualquer criatura)"}
			if sp_id == "santuario" and apr.has(0) and not ["animal", "construto", "morto-vivo"].has(str(a.get("tipo_criatura", ""))):
				return {"ok": false, "reason": "escolha o tipo: animal, construto ou morto-vivo"}
			if sp_id == "controlar_plantas":
				var centro_cp: Vector2i = a.get("tile", sim.c(a.get("target", actor)).tile) if sim.combatants.has(a.get("target", actor)) else a.get("tile", A.tile)
				if CombatSim.cheb(A.tile, centro_cp) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)):
					return {"ok": false, "reason": "fora do alcance"}
				if not apr.has(2):
					var tiles_cp: Array = [centro_cp] if a.get("truque", false) else Area.quadrado(centro_cp, Area.quadrados(9.0))
					if not tiles_cp.any(func(t): return sim.db.is_vegetation(t)):
						return {"ok": false, "reason": "Controlar Plantas precisa de vegetação"}
				if apr.has(2) and (apr.has(0) or apr.has(1)):
					return {"ok": false, "reason": "falar com plantas não se combina com os outros aprimoramentos"}
				if apr.has(0) and apr.has(1):
					return {"ok": false, "reason": "a poda é instantânea: não prende ninguém"}
				targets = [actor]
			if sp_id == "caminhos_da_natureza" and not a.get("truque", false):
				for tg in targets:
					if not sim.combatants.has(tg) or sim.is_enemy(actor, tg):
						return {"ok": false, "reason": "Caminhos da Natureza abre o caminho de aliados"}
			if sp_id == "armamento_da_natureza":
				var alvo_an: String = a.get("target", actor)
				if not sim.combatants.has(alvo_an) or SpellRules.armamento_ataque(sim.rules, sim.c(alvo_an).sheet, str(a.get("arma", ""))).is_empty():
					return {"ok": false, "reason": "Armamento da Natureza precisa de arma primitiva, arma natural ou ataque desarmado"}
				if a.has("tipo_dano") and not ["corte", "impacto", "perfuracao"].has(str(a.tipo_dano)):
					return {"ok": false, "reason": "tipo de dano: corte, impacto ou perfuração"}
				if apr.has(2) and not apr.has(0):
					return {"ok": false, "reason": "o aumento no ataque exige o bônus de ataque"}
			if sp_id == "arma_espiritual":
				if SpellRules.arma_espiritual_tipo(sim.rules, str(A.sheet.devotion), str(a.get("tipo_dano", ""))) == "":
					return {"ok": false, "reason": "sua divindade não tem arma preferida (Nimb: escolha corte, impacto ou perfuração)"}
				if apr.has(1) and not apr.has(0):
					return {"ok": false, "reason": "o aumento na Defesa exige o aprimoramento de Defesa"}
			if sp_id == "despedacar" and not a.has("objeto") and not apr.has(5) and [1, 2, 3, 4].any(func(i): return apr.has(i)):
				return {"ok": false, "reason": "os aprimoramentos de tamanho são para objetos"}
			if sp_id == "despedacar" and a.has("objeto") and not apr.has(5):
				var od := sim.db.object_def(str(a.objeto))
				if od.is_empty() or not od.has("break"):
					return {"ok": false, "reason": "escolha um objeto mundano"}
				var tam_o := SpellRules.tamanho_indice(str(od["break"].get("tamanho", "")))
				if tam_o < 0 or tam_o > SpellRules.despedacar_tamanho_max(apr):
					return {"ok": false, "reason": "objeto grande demais para o Despedaçar escolhido"}
				if CombatSim.cheb(A.tile, Vector2i(int(od.tile[0]), int(od.tile[1]))) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)):
					return {"ok": false, "reason": "objeto fora do alcance"}
				targets = a.get("targets", [])
			if sp_id == "consagrar" or sp_id == "profanar":
				if apr.has(2): return {"ok": false, "reason": "a versão permanente leva 1 hora: só fora de combate"}
				if SpellRules.simbolo_impede(sim.db, A.tile, Area.quadrados(9.0), str(A.sheet.devotion)):
					return {"ok": false, "reason": "há um símbolo de outra divindade na área"}
			if sp_id == "bencao":
				for tg in targets:
					if not sim.combatants.has(tg):
						return {"ok": false, "reason": "alvo inválido"}
					if apr.has(0):
						if apr.has(1): return {"ok": false, "reason": "a Bênção sobre cadáver não recebe bônus"}
						if targets.size() != 1 or not sim.c(tg).sheet.is_dead(): return {"ok": false, "reason": "escolha um cadáver"}
					elif sim.is_enemy(actor, tg) or sim.c(tg).sheet.is_dead():
						return {"ok": false, "reason": "Bênção só abençoa aliados"}
			if sp_id == "nevoa" and apr.has(4) and not apr.has(3):
				return {"ok": false, "reason": "o aprimoramento de +2d4 exige a névoa cáustica"}
			if sp_id == "orientacao":
				if apr.has(0) and apr.has(1):
					return {"ok": false, "reason": "a Orientação de atributo e a de grupo de atributos não se combinam"}
				if apr.has(0) and not ["for", "des", "con", "int", "sab", "car"].has(str(a.get("atributo", ""))):
					return {"ok": false, "reason": "escolha um atributo para a Orientação"}
				if apr.has(1) and not ["fisicos", "mentais"].has(str(a.get("grupo", ""))):
					return {"ok": false, "reason": "escolha o grupo de atributos (fisicos ou mentais)"}
			if sp_id == "lagrimas_de_wynna":
				if apr.has(0) and apr.has(1):
					return {"ok": false, "reason": "o ritual de um dia não combina com a esfera"}
				if apr.has(1):
					if A.sheet.arcana_perdida:
						return {"ok": false, "reason": "você já perdeu as magias arcanas"}
			if str(sp.get("tipo", "")) == "arcana" and (A.sheet.efeito_bonus("bloqueio_arcana") > 0 or A.sheet.arcana_perdida):
				return {"ok": false, "reason": "você não consegue lançar magias arcanas"}
			if sp_id == "banimento":
				var tg_b: String = a.get("target", "")
				if tg_b == actor or not sim.combatants.has(tg_b):
					return {"ok": false, "reason": "Banimento precisa de outra criatura como alvo"}
				if sim.conjurando.has(actor):
					return {"ok": false, "reason": "você já está conjurando uma magia de execução longa"}
				if apr.has(0) and not tg_b.begins_with("inv_"):
					return {"ok": false, "reason": "o aprimoramento só devolve criatura conjurada"}
			if sp_id == "sopro_da_salvacao":
				return _validar_sopro(sim, actor, A, a, cost)
			var alc := SpellRules.alcance_efetivo(sp_id, str(sp.alcance), apr)
			if alc == "pessoal": targets = [actor]
			var reach := int(sim.rules.value("alcance.quadrados", {}).get(alc, 1))  # LB p.143 (toque/pessoal = 1)
			if sp_id == "aviso":
				reach *= int(pow(10, apr.count(0)))   # Aviso: alcance x10 por aprimoramento
			# Toque (LB p.225): o alvo precisa estar no alcance natural; o próprio conjurador está (pode tocar a si mesmo).
			for tg in targets:
				var T := sim.c(tg)
				if T.is_empty(): return {"ok": false, "reason": "alvo inválido"}
				if CombatSim.cheb(A.tile, T.tile) > reach: return {"ok": false, "reason": "fora do alcance da magia"}
			var avg := 0.0
			if sp.has("dano_por_seta"): avg = Dice.average(sp.dano_por_seta) * int(sp.setas)
			elif sp.has("dano"): avg = Dice.average(raio_dice(A.sheet) if sp_id == "raio_arcano" else str(sp.dano)) * 0.75   # resistência reduz à metade: média aproximada
			if avg > 0.0 and A.sheet.has_power("arcano_de_batalha"): avg += maxi(0, int(A.sheet.attrs.get(A.sheet.caster_attr, 0)))
			return {"ok": true, "kind": kind_c, "cost": cost, "hit_chance": 1.0, "crit_chance": 0.0, "avg_damage": avg, "mods": [], "defense": 0, "miss_chance": 0, "ranged": true}
		"agua_benta":
			# Água benta (LB p.160): ação padrão, morto-vivo ou abissal em alcance curto; 2d10 de luz (Reflexos CD Sab reduz).
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "usar água benta exige ação padrão"}
			var TB := sim.c(a.get("target", ""))
			if TB.is_empty() or TB.sheet.is_dead(): return {"ok": false, "reason": "alvo inválido"}
			if CombatSim.cheb(A.tile, TB.tile) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "fora do alcance curto"}
			return {"ok": true, "kind": "padrao"}
		"drink":
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "beber poção exige ação padrão (LB p.234)"}
			if str(a.get("item", "")) == "": return {"ok": false, "reason": "sem item"}
			return {"ok": true, "kind": "padrao"}
		"cura_maos":
			# Cura pelas Mãos (LB p.82, paladino): ação de movimento; 1 PM, +1 PM por passo (a cada 4 níveis),
			# +1 PM para remover uma condição da lista (a partir do 6º nível). Alcance corpo a corpo, inclusive você.
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "Cura pelas Mãos exige ação de movimento"}
			if A.sheet.class_id != "paladino" or A.sheet.level < 2: return {"ok": false, "reason": "Cura pelas Mãos é do paladino a partir do 2º nível"}
			var alvo_m: String = a.get("target", actor)
			var TM := sim.c(alvo_m)
			if TM.is_empty() or TM.sheet.is_dead(): return {"ok": false, "reason": "alvo inválido"}
			if alvo_m != actor and CombatSim.cheb(A.tile, TM.tile) > 1: return {"ok": false, "reason": "alvo fora do corpo a corpo"}
			var passos := clampi(int(a.get("passos", 0)), 0, A.sheet.level / 4)
			var remover := bool(a.get("remover", false))
			if remover and (A.sheet.level < 6 or not _tem_condicao_de_cura(TM.sheet)):
				return {"ok": false, "reason": "remover condição exige 6º nível e uma condição da lista"}
			var custo_m := 1 + passos + (1 if remover else 0)
			if A.sheet.pm < custo_m: return {"ok": false, "reason": "PM insuficiente (%d)" % custo_m}
			return {"ok": true, "kind": "movimento", "cost": custo_m, "passos": passos, "remover": remover}
		"olhar_atordoante":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			if not A.sheet.can_olhar_atordoante(): return {"ok": false, "reason": "só medusa, com PM, uma vez por cena"}
			var T := sim.c(a.get("target", ""))
			if T.is_empty() or not sim.is_enemy(actor, a.target) or not sim.conscious(a.target): return {"ok": false, "reason": "alvo inválido"}
			if CombatSim.cheb(A.tile, T.tile) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "fora do alcance curto"}
			return {"ok": true, "kind": "movimento", "cost": 1}
		"diplomacia":
			# Mudar Atitude em combate (LB p.118): ação completa, –10, Diplomacia oposta pela Vontade; uma vez por dia por alvo.
			if not sim.can_spend("completa"): return {"ok": false, "reason": "mudar atitude em combate exige ação completa"}
			var TD := sim.c(a.get("target", ""))
			if TD.is_empty() or not sim.is_enemy(actor, a.target) or not sim.conscious(a.target): return {"ok": false, "reason": "alvo inválido"}
			if CombatSim.cheb(A.tile, TD.tile) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "longe demais para conversar"}
			if int(TD.get("diplomacia_dia", -1)) == sim.dia: return {"ok": false, "reason": "já tentou mudar a atitude dele hoje"}
			return {"ok": true, "kind": "completa"}
		"adestrar":
			# Adestramento, Acalmar Animal (LB p.115): ação completa, apenas treinado, CD 25.
			if not sim.can_spend("completa"): return {"ok": false, "reason": "acalmar animal exige ação completa"}
			if not A.sheet.can_use_skill("adestramento", sim.rules): return {"ok": false, "reason": "Adestramento é apenas treinada"}
			var TN := sim.c(a.get("target", ""))
			if TN.is_empty() or TN.sheet.creature_type != "animal" or not sim.conscious(a.target): return {"ok": false, "reason": "escolha um animal"}
			if CombatSim.cheb(A.tile, TN.tile) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "longe demais"}
			return {"ok": true, "kind": "completa"}
		"pegar_arma":
			# Pegar a arma largada (Comando, "Largue"): ação de movimento, no mesmo quadrado ou adjacente; só a partir do
			# turno seguinte ao que largou.
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			var chao: Dictionary = A.get("arma_no_chao", {})
			if chao.is_empty(): return {"ok": false, "reason": "nada largado"}
			if sim.turn_counter <= int(chao.get("turno", -1)):
				return {"ok": false, "reason": "só no próximo turno"}
			var tc := Vector2i(int(chao.tile[0]), int(chao.tile[1]))
			if CombatSim.cheb(A.tile, tc) > 1: return {"ok": false, "reason": "longe da arma"}
			return {"ok": true, "kind": "movimento"}
		"ouvir_pensamentos":
			# Compreensão: ação de movimento, criatura tocada (ou no alcance da versão de curto alcance) com a magia ativa.
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			var TO := sim.c(a.get("target", ""))
			if TO.is_empty() or not A.sheet.efeito_tipo_existe("compreende", str(a.target)): return {"ok": false, "reason": "lance Compreensão na criatura antes"}
			return {"ok": true, "kind": "movimento"}
		"analisar_aura":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			if A.sheet.efeito_bonus("visao_mistica") <= 0: return {"ok": false, "reason": "precisa da Visão Mística"}
			var TV := sim.c(a.get("target", ""))
			if TV.is_empty() or CombatSim.cheb(A.tile, TV.tile) > int(sim.rules.value("alcance.quadrados", {}).get("medio", 20)): return {"ok": false, "reason": "fora do alcance médio"}
			return {"ok": true, "kind": "movimento"}
		"detectar_magia":
			if not sim.can_spend("completa"): return {"ok": false, "reason": "detectar magia exige ação completa"}
			if not A.sheet.can_use_skill("misticismo", sim.rules): return {"ok": false, "reason": "Misticismo é somente treinada"}
			return {"ok": true, "kind": "completa"}
		"mover_globos":
			# Luz (globos): ação livre, uma vez por rodada, dentro do alcance longo.
			if (A.flags as Array).has("globos_%d" % sim.round_no): return {"ok": false, "reason": "os globos já se moveram nesta rodada"}
			if not sim.zonas.any(func(z): return z.tipo == "globo_luz" and str(z.get("dados", {}).get("conjurador", "")) == actor): return {"ok": false, "reason": "sem globos de luz"}
			for q in a.get("tiles", []):
				if CombatSim.cheb(A.tile, Vector2i(int(q[0]), int(q[1]))) > int(sim.rules.value("alcance.quadrados", {}).get("longo", 60)): return {"ok": false, "reason": "fora do alcance longo"}
			return {"ok": true, "kind": "livre"}
		"guardar_fonte":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			if A.sheet.efeito_bonus("fonte_luz") <= 0 and not A.sheet.efeitos.any(func(e): return e.stat == "fonte_escuridao"): return {"ok": false, "reason": "nada emitindo luz ou sombras"}
			return {"ok": true, "kind": "movimento"}
		"escapar":
			# Libertar-se de efeito que prende (Controlar Plantas): ação padrão e Acrobacia ou Atletismo.
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "libertar-se exige ação padrão"}
			var preso := false
			for m in sim.marcas:
				if m.alvo == actor and m.tipo == "preso": preso = true
			if not preso: return {"ok": false, "reason": "você não está preso"}
			return {"ok": true, "kind": "padrao"}
		"arma_espiritual":
			# Arma Espiritual (aprimoramento sustentado): ação livre; a arma acerta automaticamente um alvo adjacente.
			if A.sheet.efeito_bonus("arma_espiritual_ataque") <= 0: return {"ok": false, "reason": "sem Arma Espiritual que ataca"}
			var TA := sim.c(a.get("target", ""))
			if TA.is_empty() or not sim.is_enemy(actor, a.target) or TA.sheet.is_dead(): return {"ok": false, "reason": "alvo inválido"}
			if CombatSim.cheb(A.tile, TA.tile) != 1: return {"ok": false, "reason": "alvo não adjacente"}
			if sim.arma_espiritual_livre(actor) < 0: return {"ok": false, "reason": "a arma já agiu nesta rodada"}
			return {"ok": true, "kind": "livre", "cost": 0}
		"aura_sagrada":
			# Aura Sagrada (LB p.84): ligar custa 1 PM; desligar é livre. Tipo de ação: padrão (o texto extraído do livro não traz o tipo; segue a Ladainha de combate, que é ação padrão).
			if not A.sheet.pode_aura_sagrada(): return {"ok": false, "reason": "Aura Sagrada é do paladino a partir do 3º nível"}
			if A.sheet.aura_sagrada_ativa: return {"ok": true, "kind": "livre", "cost": 0, "ligar": false}
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "sem ação padrão disponível"}
			if A.sheet.pm < 1: return {"ok": false, "reason": "PM insuficiente (1)"}
			return {"ok": true, "kind": "padrao", "cost": 1, "ligar": true}
		"egide":
			# Égide Sagrada (LB p.84): ação de movimento e 2 PM; dura até o fim da cena.
			if not A.sheet.pode_egide_sagrada(): return {"ok": false, "reason": "Égide Sagrada exige a Bênção da Justiça (5º nível)"}
			if A.sheet.egide_ativa: return {"ok": false, "reason": "já ativa nesta cena"}
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			if A.sheet.pm < 2: return {"ok": false, "reason": "PM insuficiente (2)"}
			return {"ok": true, "kind": "movimento", "cost": 2}
		"allihanna":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			if A.sheet.race_id != "dahllan": return {"ok": false, "reason": "só dahllan tem Armadura de Allihanna"}
			if A.sheet.allihanna_ativa: return {"ok": false, "reason": "já ativa nesta cena"}
			if A.sheet.pm < 1: return {"ok": false, "reason": "PM insuficiente"}
			return {"ok": true, "kind": "movimento", "cost": 0}
		"impeto", "velocidade_ladina", "emboscar":
			return validate_power_action(sim, actor, t)
	return {"ok": false, "reason": "ação desconhecida: " + t}


## Poderes ativados como ação livre (LB p.66, 73-74). Custo em PM, limite por rodada.
static func validate_power_action(sim: CombatSim, actor: String, t: String) -> Dictionary:
	var A := sim.c(actor)
	if not A.sheet.has_power(t): return {"ok": false, "reason": "poder não adquirido"}
	var cost := int(sim.rules.value("poder." + t).custo_pm)
	if A.sheet.pm < cost: return {"ok": false, "reason": "PM insuficiente (%d)" % cost}
	var key := "%s_%d" % [t, sim.round_no]
	if (A.flags as Array).has(key) or (t == "emboscar" and (A.flags as Array).has("emboscar_usado")):
		return {"ok": false, "reason": "já usado nesta rodada" if t != "emboscar" else "Emboscar só na primeira rodada do combate"}
	if t == "emboscar" and sim.round_no != 1: return {"ok": false, "reason": "Emboscar só na primeira rodada do combate"}
	return {"ok": true, "kind": "livre", "cost": cost, "flag": key}


## Aplica o efeito de um poder livre no simulador (usado pelo fantasma e pela execução real).
static func apply_power_action(sim: CombatSim, actor: String, t: String, v: Dictionary) -> void:
	var A := sim.c(actor)
	A.sheet.pm -= int(v.cost)
	(A.flags as Array).append(v.flag)
	match t:
		"velocidade_ladina": sim.budget.move += 1
		"emboscar":
			sim.budget.std += 1
			(A.flags as Array).append("emboscar_usado")


## Raio Arcano é um poder que "conta como magia" (LB p.39): regra própria, sem custo de círculo.
static func spell_rule(rules: RuleRegistry, sp_id: String) -> Dictionary:
	if sp_id == "raio_arcano":
		var r: Dictionary = rules.value("poder.raio_arcano", {}).duplicate()
		r["tipo"] = "arcana"; r["circulo"] = 0
		return r
	return rules.value("magia." + sp_id, {})


static func spell_cost(rules: RuleRegistry, sp: Dictionary, a: Dictionary) -> int:
	if a.get("truque", false):
		return 0   # Truque: custo zero
	var base := 0 if int(sp.get("circulo", 1)) == 0 else int(rules.value("magia.custo_por_circulo")[str(int(sp.circulo))])
	if a.get("pungente", false):
		base += int(rules.value("poder.magia_pungente").custo_pm)
	base += SpellRules.custo_aprimoramentos(rules, str(a.get("spell", "")), a.get("aprimoramentos", []))
	if str(a.get("spell", "")) == "lagrimas_de_wynna" and a.get("aprimoramentos", []).has(1):
		base += 1   # Lágrimas de Wynna (ritual): sacrifício de 1 PM além do custo do aprimoramento
	return base


## 1d8, +1d8 por círculo acima do 1º que o arcanista pode lançar (2º no 5º nível, 3º no 9º...).
static func raio_dice(sheet: CharacterSheet) -> String:
	var circles := 1 + maxi(0, (sheet.level - 1) / 4)
	return "%dd8" % circles


static func _tiles(path: Array) -> Array:
	var out: Array = []
	for p in path:
		out.append(Vector2i(int(p[0]), int(p[1])) if p is Array else p)
	return out


static func simulate(sim: CombatSim, actor: String, actions: Array) -> Dictionary:
	var g := sim.clone()
	var steps: Array = []
	var valid := true
	for a in actions:
		var v := validate_action(g, actor, a)
		if not v.ok:
			steps.append({"action": a, "ok": false, "reason": v.reason})
			valid = false
			break
		var step := {"action": a, "ok": true, "kind": v.kind}
		match a.type:
			"move":
				step["from"] = g.c(actor).tile
				g.c(actor).tile = v.end
				step["to"] = v.end
				step["cost"] = v.cost
			"charge":
				step["from"] = g.c(actor).tile
				g.c(actor).tile = v.end
				step["to"] = v.end
				step["hit_chance"] = v.hit_chance; step["crit_chance"] = v.crit_chance; step["avg_damage"] = v.avg_damage; step["mods"] = v.mods
			"cura_maos":
				g.c(actor).sheet.pm -= int(v.cost)
			"aura_sagrada":
				g.c(actor).sheet.aura_sagrada_ativa = bool(v.ligar)
				g.c(actor).sheet.pm -= int(v.cost)
			"egide":
				g.c(actor).sheet.egide_ativa = true
				g.c(actor).sheet.pm -= int(v.cost)
			"cast":
				step["hit_chance"] = 1.0; step["crit_chance"] = 0.0; step["avg_damage"] = v.avg_damage; step["mods"] = []; step["pm_cost"] = v.cost
				g.c(actor).sheet.pm -= int(v.cost)
			"attack", "ataque_extra":
				(g.c(actor).flags as Array).append("agrediu_%d" % g.round_no)
				if a.type == "ataque_extra":
					(g.c(actor).flags as Array).append("ataque_extra_%d" % g.round_no)
					g.c(actor).sheet.pm -= 2
				step["hit_chance"] = v.hit_chance; step["crit_chance"] = v.crit_chance; step["avg_damage"] = v.avg_damage
				step["mods"] = v.mods; step["defense"] = v.defense; step["miss_chance"] = v.miss_chance
			"stand":
				g.c(actor).sheet.remove_condition("caido")
			"impeto", "velocidade_ladina", "emboscar":
				apply_power_action(g, actor, a.type, v)
				step["pm_cost"] = v.cost
		g.spend(v.kind)
		steps.append(step)
	return {"valid": valid, "steps": steps, "budget_after": g.budget.duplicate(), "end_tile": g.c(actor).tile}


## Sopro da Salvação (3º círculo): o cone de 9m aponta do conjurador para o alvo escolhido. O alvo tem de estar
## dentro desse cone (até 6 quadrados). Não há custo extra além do das aprimoramentos.
static func _validar_sopro(sim: CombatSim, actor: String, A: Dictionary, a: Dictionary, cost: int) -> Dictionary:
	var alvo: String = a.get("target", "")
	if alvo == "" or alvo == actor or sim.c(alvo).is_empty():
		return {"ok": false, "reason": "escolha o alvo que orienta o cone"}
	var T: Dictionary = sim.c(alvo)
	var dir := Vector2i(signi(T.tile.x - A.tile.x), signi(T.tile.y - A.tile.y))
	var cone: Array = Area.cone(A.tile, dir, Area.quadrados(9.0))
	if not cone.has(T.tile):
		return {"ok": false, "reason": "alvo fora do cone de 9m"}
	return {"ok": true, "kind": "padrao", "cost": cost, "hit_chance": 1.0, "crit_chance": 0.0, "avg_damage": 0.0, "mods": [], "defense": 0, "miss_chance": 0, "ranged": true}
