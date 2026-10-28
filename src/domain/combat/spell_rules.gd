extends RefCounted
## Regras de magias já completas no jogo. Só aparece para o jogador (e só pode ser escolhida) a magia
## com todos os aprimoramentos implementados. COMPLETAS guarda, por magia, os índices de aprimoramento
## (ordem do catálogo `magia.<id>.aprimoramentos`) que já têm efeito.

const Area := preload("res://src/domain/combat/area.gd")
const COMPLETAS := {
	"perdicao": {"aprimoramentos": [0]},
	"infligir_ferimentos": {"aprimoramentos": [0, 1, 2, 3]},
	"resistencia_a_energia": {"aprimoramentos": [0, 1, 2, 3, 4]},
	"escudo_da_fe": {"aprimoramentos": [0, 1, 2, 3, 4]},
	"protecao_divina": {"aprimoramentos": [0, 1, 2, 3]},
	"heroismo": {"aprimoramentos": [0]},   # imune a medo; 40 PV temporários; +4 (+6 com o aprimoramento) contra o maior ND
	"protecao_contra_magia": {"aprimoramentos": [0, 1, 2]},   # +5 em resistências (+10); imune a 1 ou 2 escolas de magia
	"potencia_divina": {"aprimoramentos": [0, 1, 2]},   # sustentada; Força +4 (+1); RD 10 (+5); toque em aliado (devoto da mesma divindade)
	"dispersar_as_trevas": {"aprimoramentos": [0, 1, 2, 3]},   # dissipa até 3º (4º, 5º); aliados +4 e RD 10; inimigos cegos 1x por cena
	"missao_divina": {"aprimoramentos": [0, 1]},   # fora de combate: NPC deve ir a um lugar; recusou, Vontade por dia ou –2 cumulativo; marca; um ano
	"servo_divino": {"aprimoramentos": [0, 1]},   # espírito cumpre uma tarefa: lutar (cena) ou entregar um item; um dia; uma semana
	"intervencao_divina": {"aprimoramentos": []},   # cura total de 10; dissipa magia até 4º; com sacrifício de 2 PM: item, duplicar magia, proteger povoado, ressuscitar
	"reanimacao_impura": {"aprimoramentos": []},   # quem morreu nesta cena volta como morto-vivo que obedece; volta a morrer no fim da cena
	"conceder_milagre": {"aprimoramentos": [0]},   # um companheiro lança uma magia sua de até 2º (3º) círculo, uma vez, sem PM; –3 (–6) PM até lá
	"cupula_de_repulsao": {"aprimoramentos": [0, 1]},   # sustentada: um tipo ou raça não se aproxima (Vontade); 4,5m; desvia ataques à distância (5º)
	"terremoto": {"aprimoramentos": []},   # atordoa quem está no solo; efeito pelo terreno (teto, desabamento, fendas, desmoronamento, lamaçal)
	"muralha_de_ossos": {"aprimoramentos": [0, 1]},   # muro de 15m (+15m) que fere e prende; trechos destrutíveis; escalar fere; esqueletos animados agarram
	"runa_de_protecao": {"aprimoramentos": [0, 1, 2]},   # runa no chão que explode (+2d6); runa no corpo com magia de 1º (ou 2º) círculo como reação
	"comunhao_com_a_natureza": {"aprimoramentos": [0, 1, 2, 3]},   # dados de auxílio em áreas naturais; informações da região; +2 dados; d6; d8
	"despertar_consciencia": {"aprimoramentos": [0, 1]},   # animal, planta ou parceiro vira parceiro veterano por um dia; escultura; permanente (–3 PM)
	"servo_morto_vivo": {"aprimoramentos": [0, 1, 2]},   # cadáver vira parceiro morto-vivo (esqueleto/zumbi, carniçal, sombra, múmia)
	"videncia": {"aprimoramentos": []},   # fora de combate: vê e ouve um NPC a qualquer distância (Vontade anula, com modificador por familiaridade)
	"lendas_e_historias": {"aprimoramentos": [0]},   # tudo sobre criatura, objeto ou lugar tocado; à distância por um dia (T$ 1.000)
	"buraco_negro": {"aprimoramentos": [0]},   # 3 turnos puxando 30m (Fortitude); quem termina o turno nele é sugado; você não é afetado
	"manto_de_sombras": {"aprimoramentos": [0]},   # sustentada: incorpóreo, 1 de dano por rodada na luz, salto entre sombras; toque (4º)
	"selo_de_mana": {"aprimoramentos": [0]},   # ações que gastam PM exigem Vontade; falhou, sem efeito (PM gastos); curto e vários alvos (4º)
	"libertacao": {"aprimoramentos": [0, 1, 2, 3, 4]},   # imune a efeitos de movimento; anda na água; 20 em Atletismo; 20 em Acrobacia; 5 alvos; Aprisionamento
	"marca_da_obediencia": {"aprimoramentos": [0, 1]},   # ordem (não ataque, siga, fique); Vontade a cada rodada; um dia; 3d6 psíquico ao falhar
	"controlar_o_clima": {"aprimoramentos": []},   # fora de combate: fixa um dos climas do jogo por 4d12 horas
	"visao_da_verdade": {"aprimoramentos": [0, 1, 2, 3]},   # ignora camuflagem e escuridão; toque; +10 Percepção; +10 Intuição; paredes finas
	"furia_do_panteao": {"aprimoramentos": []},   # nuvem de 90m sustentada; ordens de movimento: nevasca, raios, siroco, trovões
	"toque_da_morte": {"aprimoramentos": [0, 1]},   # 10d8+10 de trevas; abaixo da metade dos PV, Fortitude ou PV a –10; raio; todos os inimigos em curto
	"palavra_primordial": {"aprimoramentos": []},   # atordoar, cegar ou matar (Vontade parcial); alvo de nível menor que o seu
	"segunda_chance": {"aprimoramentos": [0, 1, 2]},   # cura 200 e condições; +20; até 5 alvos; quem morreu há até uma rodada
	"imobilizar": {"aprimoramentos": [0, 1, 2]},   # paralisado (Vontade: lento); espírito; +1 alvo; qualquer criatura (4º círculo)
	"pele_de_pedra": {"aprimoramentos": [0, 1, 2, 3, 4]},   # RD 5; toque; um dia; aço RD 10; estátua 1d4 rodadas; estátua permanente
	"conjurar_mortos_vivos": {"aprimoramentos": [0, 1, 2]},   # 6 esqueletos (+1 cada); carniçais (3º círculo); sombras (4º)
	"dissipar_magia": {"aprimoramentos": [0]},   # Misticismo dissipa magias de CD até o resultado; disjunção de 9m (5º círculo)
	"anular_a_luz": {"aprimoramentos": [0, 1, 2]},   # dissipa até 3º (4º, 5º); aliados +4 Defesa (+1); inimigos enjoados 1x por cena
	"curar_ferimentos": {"aprimoramentos": [0, 1, 2, 3]},
	"vestimenta_da_fe": {"aprimoramentos": [0, 1, 2]},
	"manto_do_cruzado": {"aprimoramentos": []},   # sem aprimoramentos; versão luz ou trevas escolhida ao aprender
	"coluna_de_chamas": {"aprimoramentos": [0, 1]},   # cilindro de 3m de raio em volta do alvo; +1 PM por +1d6 de fogo ou de luz
	"arma_magica": {"aprimoramentos": [0, 1, 2]},   # +1/+2 em ataque e dano; atributo-chave; dano elemental 1d6 / 2d6
	"orientacao": {"aprimoramentos": [0, 1, 2]},   # vantagem em perícia (2 dados); por atributo; por grupo; alvos escolhidos
	"bencao": {"aprimoramentos": [0, 1]},   # 1 cadáver por 1 semana (também fora de combate); +1 de bônus, repetível
	"consagrar": {"aprimoramentos": [0, 1, 2]},   # esfera de 9m, luz maximizada; –2 a mortos-vivos (+1, repetível); permanente
	"profanar": {"aprimoramentos": [0, 1, 2]},   # esfera de 9m, trevas maximizadas; +2 a mortos-vivos (+1, repetível); permanente
	"despedacar": {"aprimoramentos": [0, 1, 2, 3, 4, 5]},   # +1d8+2 (repetível); objeto Médio/Grande/Enorme/Colossal; esfera de 6m
	"arma_espiritual": {"aprimoramentos": [0, 1, 2, 3, 4, 5]},   # +1 Defesa (+1 repetível); sustentada com ataque livre; essência; +1d6; duas armas
	"armamento_da_natureza": {"aprimoramentos": [0, 1, 2, 3]},   # +1 ataque; execução de movimento; +1 ataque (repetível); +1 passo (repetível)
	"caminhos_da_natureza": {"aprimoramentos": [0, 1]},   # rastrear os alvos: CD +10; +3m (repetível); truque: +5 em Sobrevivência para se orientar
	"controlar_plantas": {"aprimoramentos": [0, 1, 2]},   # poda (instantânea); também imóvel; falar com plantas; truque: anima 1 planta
	"santuario": {"aprimoramentos": [0, 1]},   # não inteligentes do tipo escolhido não percebem; também contra área
	"comando": {"aprimoramentos": [0, 1]},   # qualquer criatura; +1 alvo (repetível); ordens fuja, largue, pare, senta, venha
	"acalmar_animal": {"aprimoramentos": [0, 1, 2, 3]},   # médio; monstro/espírito Int –5/–4; +1 alvo; qualquer monstro/espírito
	"tranquilidade": {"aprimoramentos": [0, 1, 2]},   # qualquer criatura; +1 alvo; médio e criaturas escolhidas
	"detectar_ameacas": {"aprimoramentos": [0, 1]},   # raça e aura; não surpreendido e +5 contra armadilhas
	"suporte_ambiental": {"aprimoramentos": [0]},   # alcance curto e criaturas escolhidas
	"abencoar_alimentos": {"aprimoramentos": [0, 1]},   # +1 alvo (repetível); água benta; truque: só purifica
	"criar_elementos": {"aprimoramentos": [0, 1, 2]},   # +1 passo de quantidade; arremesso 2d4 (água/terra); +1d6 de fogo
	"luz": {"aprimoramentos": [0, 1, 2, 3, 4, 5, 6]},   # +3m; dia; permanente; olhos (arcano); globos (arcano); luz solar (divino); halo (divino)
	"escuridao": {"aprimoramentos": [0, 1, 2, 3, 4]},   # +1,5m; escuridão total; olhos (cego); dia; sombras pessoais
	"aviso": {"aprimoramentos": [0, 1, 2, 3]},   # alcance x10 (repetível); resposta; localização pela cena; +1 alvo
	"compreensao": {"aprimoramentos": [0, 1, 2, 3]},   # curto; curto e criaturas escolhidas; vasculhar pensamentos; todos os idiomas
	"visao_mistica": {"aprimoramentos": [0, 1, 2]},   # visão no escuro; um dia; ver o invisível
	"armadura_arcana": {"aprimoramentos": [0, 1, 2]},   # reação +5 contra um ataque; +1 (repetível); um dia
	"toque_chocante": {"aprimoramentos": [0, 1, 2]},   # +1d8+1 (repetível); com ataque corpo a corpo; esfera de 6m
	"seta_infalivel": {"aprimoramentos": [0, 1, 2, 3]},   # lanças 1d8+1; três, cinco ou dez setas
	"fisico_divino": {"aprimoramentos": [0, 1, 2, 3]},   # curto e criaturas escolhidas; +2 nos três; +4; +4 nos três
	"mente_divina": {"aprimoramentos": [0, 1, 2, 3]},
	"oracao": {"aprimoramentos": [0, 1, 2, 3]},   # +1 bônus; –1 penalidade (repetíveis, até o círculo); médio; cena
	"purificacao": {"aprimoramentos": [0, 1, 2, 3]},   # PV de veneno; todas as condições; soltar item amaldiçoado; dissipar
	"raio_solar": {"aprimoramentos": [0, 1, 2]},   # +1d8 (+1d12); cura vivos escolhidos; cegos; truque: facho de luz
	"silencio": {"aprimoramentos": [0, 1]},   # objeto que emana 3m; nenhum som sai da área (cena)
	"circulo_da_justica": {"aprimoramentos": [0, 1, 2]},   # pessoal: ver o invisível em alcance curto; –10/–20; permanente
	"controlar_madeira": {"aprimoramentos": [0, 1, 2, 3]},   # árvore (pessoal, um dia); vegetação afiada; Enorme; Colossal
	"aliado_animal": {"aprimoramentos": [0, 1, 2]},   # mensageiro Minúsculo; parceiro mestre (3º); 2 animais (4º)
	"tempestade_divina": {"aprimoramentos": [0, 1, 2, 3, 4, 5]},   # raios; +1d8; chuva grossa; granizo 2d6; neve 2d6 de frio; 90m
	"rogar_maldicao": {"aprimoramentos": [0, 1]},   # +1 efeito (repetível); permanente, Fortitude parcial
	"enxame_de_pestes": {"aprimoramentos": [0, 1, 2, 3]},   # +1d12; criaturas maiores; +1 enxame; elementais
	"miasma_mefitico": {"aprimoramentos": [0, 1]},   # +1d6 (repetível); trevas; truque: mata quem está com 0 PV ou menos
	"controlar_fogo": {"aprimoramentos": [0, 1, 2]},   # labaredas (sustentada); +1d6 (repetível, exceto chamejar); criatura de fogo
	"augurio": {"aprimoramentos": [0, 1, 2, 3]},   # consultar a divindade (pista); perguntas de sim ou não; falha só em 1 no 1d12 / 1d20
	"condicao": {"aprimoramentos": [0, 1]},   # +1 alvo (repetível); um dia
	"voz_divina": {"aprimoramentos": [0, 1]},   # interrogar um cadáver (uma vez por corpo); falar com plantas e rochas
	"soco_de_arsenal": {"aprimoramentos": [0, 1, 2, 3]},   # alcance natural +3m (cena); +1d6 (repetível); +3m de empurrão (repetível); essência
	"nevoa": {"aprimoramentos": [0, 1, 2, 3, 4, 5]},   # sob a água; quem enxerga; cheiro (enjoado); ácido 2d4 / +2d4; espessa
	"lagrimas_de_wynna": {"aprimoramentos": [0, 1]},   # esfera de 6m com criaturas escolhidas (2 PM); ritual de um dia (5 PM + 1 PM)
	"guardiao_divino": {"aprimoramentos": []},   # elemental de luz com 100 pontos: cura PV e remove condições; some sem luz
	"banimento": {"aprimoramentos": [0]},   # execução de 1d3+1 rodadas; 0 PM: devolve criatura conjurada ao plano
	"aura_divina": {"aprimoramentos": [0]},   # esfera de 9m que segue o conjurador; +1 de bônus com 2 PM
	"ligacao_sombria": {"aprimoramentos": [0]},   # 1 dia; o alvo sofre o dano e as condições do conjurador; 5 PM: a ligação não acaba a 0 PV
	"colera_de_azgher": {"aprimoramentos": [0, 1, 2]},   # esfera de 6m; cega e põe em chamas quem falha; dissipa necromancia com 5 PM
	"premonicao": {"aprimoramentos": [0, 1]},   # reação de 3 PM após um teste; 10 PM: dura um dia
	"invulnerabilidade": {"aprimoramentos": [0]},   # proteção mental ou física (escolha) até o fim da cena
	"poeira_da_podridao": {"aprimoramentos": [0]},   # nuvem de 6m; dano de trevas no início do turno do conjurador; bloqueia cura
	"circulo_da_restauracao": {"aprimoramentos": [0]},   # esfera de 3m por 5 rodadas; cura no fim do turno de quem está dentro
	"sopro_da_salvacao": {"aprimoramentos": [0, 1, 2]},   # cone de 9m orientado para o alvo; cura aliados e remove condições
}
## Condições que o Sopro da Salvação pode remover (uma, ou todas no aprimoramento de 4 PM).
const SOPRO_CONDICOES := ["abalado", "atordoado", "apavorado", "alquebrado", "cego", "confuso", "debilitado", "enfeiticado", "enjoado",
	"esmorecido", "exausto", "fascinado", "fatigado", "fraco", "frustrado", "lento", "paralisado", "pasmo", "surdo"]
## Magias que são reação: o base só ocorre como reação (quando um aliado é atacado). Aprimoramentos
## que mudam a execução para ação padrão permitem lançar no próprio turno.
## Invulnerabilidade (LB p.195): condições de cada proteção. A física inclui doenças (condição "doente"); acertos críticos e
## ataques furtivos entram à parte, como tipos de imunidade.
const INVULN_MENTAL := ["abalado", "alquebrado", "apavorado", "atordoado", "confuso", "esmorecido", "fascinado", "frustrado", "pasmo"]
const INVULN_FISICA := ["atordoado", "cego", "debilitado", "doente", "enjoado", "envenenado", "exausto", "fatigado", "fraco", "lento", "ofuscado", "paralisado"]
const REACAO := ["escudo_da_fe"]
const EXECUCAO_PADRAO_APR := {"escudo_da_fe": [0, 3]}
## Aprimoramentos que trocam a execução para reação mesmo sem a magia ser reação no base (Proteção Divina +2 PM).
const REACAO_APR := {"armadura_arcana": [0], "protecao_divina": [1], "premonicao": [0]}
## Aprimoramentos que trocam o alvo por "criaturas escolhidas" (vários alvos).
const ELEMENTOS := ["agua", "ar", "fogo", "terra"]
## Magias que podem mirar um quadrado vazio (o clique dá o ponto de origem).
const ALVO_QUADRADO := ["terremoto", "muralha_de_ossos", "buraco_negro", "furia_do_panteao", "conjurar_mortos_vivos", "dissipar_magia", "controlar_madeira", "tempestade_divina", "enxame_de_pestes", "miasma_mefitico", "circulo_da_justica", "criar_elementos", "nevoa", "controlar_plantas", "luz", "escuridao"]
const MULTI_APR := {"infligir_ferimentos": [3], "resistencia_a_energia": [2], "curar_ferimentos": [3], "comando": [1], "acalmar_animal": [2], "tranquilidade": [1, 2], "suporte_ambiental": [0], "aviso": [3], "compreensao": [1], "fisico_divino": [0], "mente_divina": [0]}
## Aprimoramentos que mudam o alcance: {magia: {índice: novo alcance}}.
const ALCANCE_APR := {"controlar_madeira": {0: "pessoal"}, "circulo_da_justica": {0: "pessoal"}, "soco_de_arsenal": {0: "pessoal"}, "fisico_divino": {0: "curto"}, "mente_divina": {0: "curto"}, "oracao": {2: "medio"}, "toque_chocante": {2: "pessoal"}, "compreensao": {0: "curto", 1: "curto", 3: "pessoal"}, "luz": {4: "longo", 6: "toque"}, "escuridao": {4: "pessoal"}, "suporte_ambiental": {0: "curto"}, "acalmar_animal": {0: "medio"}, "tranquilidade": {2: "medio"}, "invulnerabilidade": {0: "curto"}, "infligir_ferimentos": {3: "curto"}, "resistencia_a_energia": {2: "curto"}, "escudo_da_fe": {0: "toque", 3: "toque"},
	"protecao_divina": {1: "curto"}, "potencia_divina": {2: "toque"}, "pele_de_pedra": {0: "toque", 3: "toque", 4: "toque"}, "toque_da_morte": {0: "curto", 1: "curto"}, "visao_da_verdade": {0: "toque"}, "selo_de_mana": {0: "curto"}, "manto_de_sombras": {0: "toque"}, "segunda_chance": {1: "curto"}, "dispersar_as_trevas": {1: "curto"}, "curar_ferimentos": {2: "curto", 3: "curto"}}
## Aprimoramentos que se excluem entre si (mudam o mesmo efeito).
const EXCLUSIVOS := {"resistencia_a_energia": [[3, 4]], "protecao_contra_magia": [[1, 2]], "conjurar_mortos_vivos": [[1, 2]], "servo_morto_vivo": [[0, 1], [0, 2], [1, 2]], "runa_de_protecao": [[0, 1], [0, 2], [1, 2]], "servo_divino": [[0, 1]], "missao_divina": [[0, 1]], "pele_de_pedra": [[1, 3], [1, 4], [2, 3], [2, 4], [3, 4]]}
## Escolas de magia (LB, Proteção contra Magia): minúsculas, sem acento na comparação (ver `escola_valida`).
## Lendas e Histórias: tudo o que a ficha diz de uma criatura (estatísticas, magias, resistências e magias ativas).
static func info_ficha(sh: CharacterSheet, rules: RuleRegistry) -> Dictionary:
	var imunes: Array = []
	var rd: Dictionary = sh.dr.duplicate()
	var ativas: Array = []
	for e in sh.efeitos:
		if e.stat == "imune" and not imunes.has(str(e.tipo)):
			imunes.append(str(e.tipo))
		elif e.stat == "rd":
			rd[str(e.tipo)] = int(rd.get(str(e.tipo), 0)) + int(e.bonus)
		if str(e.id).begins_with("magia.") and not ativas.has(str(e.id).trim_prefix("magia.")):
			ativas.append(str(e.id).trim_prefix("magia."))
	return {"nome": sh.name, "raca": sh.race_id, "classe": sh.class_id, "nivel": sh.level, "tipo": sh.creature_type, "atributos": sh.attrs.duplicate(),
		"pv": sh.pv, "pv_max": sh.pv_max, "pm": sh.pm, "pm_max": sh.pm_max,
		"resistencias": {"fortitude": sh.skill_value("fortitude", rules), "reflexos": sh.skill_value("reflexos", rules), "vontade": sh.skill_value("vontade", rules)},
		"magias": Array(sh.spells), "poderes": sh.powers.keys(), "imunidades": imunes, "reducao_de_dano": rd, "magias_ativas": ativas, "condicoes": Array(sh.conditions)}


## Servo Morto-Vivo: por aprimoramento (-1 = sem), a criatura, o poder de parceiro, os tipos possíveis e o componente (T$).
## Runa de Proteção no corpo: magias que precisam de escolhas na hora (quadrado, ordem, tipo) não cabem na runa.
const RUNA_SEM := ["comando", "orientacao", "arma_magica", "fisico_divino", "mente_divina", "controlar_madeira", "controlar_fogo",
	"rogar_maldicao", "criar_elementos", "aliado_animal", "augurio", "condicao", "circulo_da_justica", "luz", "escuridao", "nevoa",
	"controlar_plantas", "enxame_de_pestes", "miasma_mefitico", "tempestade_divina", "resistencia_a_energia"]
## Conceder Milagre: a magia concedida é sua, completa, de até 2º (3º) círculo e não pede escolhas na hora.
static func erro_milagre(rules: RuleRegistry, sh: CharacterSheet, sp: String, terceiro: bool) -> String:
	if not sh.spells.has(sp) or not COMPLETAS.has(sp) or RUNA_SEM.has(sp) or sp == "conceder_milagre":
		return "escolha uma magia que você conhece e que pode ser concedida"
	if int(rules.value("magia." + sp, {}).get("circulo", 9)) > (3 if terceiro else 2):
		return "a magia concedida vai até o %dº círculo" % (3 if terceiro else 2)
	return ""


## Servo Divino: pagamento ao espírito (T$) e prazo da tarefa em dias, pelo aprimoramento.
static func servo_divino_custo(apr: Array) -> int:
	return 1000 if apr.has(1) else (500 if apr.has(0) else 100)


static func servo_divino_dias(apr: Array) -> int:
	return 7 if apr.has(1) else (1 if apr.has(0) else 0)


const OPCOES_INTERVENCAO := ["curar", "dissipar", "item", "duplicar", "proteger", "ressuscitar"]
const INTERVENCAO_SACRIFICIO := ["item", "duplicar", "proteger", "ressuscitar"]   # pedem o sacrifício de 2 PM (permanente)


## Intervenção Divina: erro de uma escolha comum aos dois lados (combate e mundo); "" se válida.
static func erro_intervencao(rules: RuleRegistry, sh: CharacterSheet, a: Dictionary) -> String:
	var op := str(a.get("opcao", ""))
	if not OPCOES_INTERVENCAO.has(op):
		return "opção: " + ", ".join(PackedStringArray(OPCOES_INTERVENCAO))
	if INTERVENCAO_SACRIFICIO.has(op) and sh.pm_max < 2:
		return "sem PM para sacrificar"
	if op == "dissipar" and int(rules.value("magia." + str(a.get("magia", "")), {}).get("circulo", 99)) > 4:
		return "escolha uma magia de até 4º círculo"
	if op == "duplicar":
		var sub: Dictionary = a.get("acao", {})
		var sp := str(sub.get("spell", ""))
		if not COMPLETAS.has(sp) or sp == "intervencao_divina" or int(rules.value("magia." + sp, {}).get("circulo", 99)) > 4:
			return "escolha uma magia do jogo de até 4º círculo para duplicar"
	return ""


const TIPOS_DESPERTAR := ["ajudante", "combatente", "fortao", "guardiao", "medico", "perseguidor", "vigilante"]


const SERVOS := {
	-1: {"criatura": "", "nivel": "iniciante", "tipos": ["ajudante", "atirador", "combatente", "fortao", "guardiao", "montaria"], "custo": 100},
	0: {"criatura": "carniçal", "nivel": "veterano", "tipos": ["ajudante", "atirador", "combatente", "fortao", "guardiao"], "custo": 500},
	1: {"criatura": "sombra", "nivel": "veterano", "tipos": ["assassino", "combatente", "perseguidor"], "custo": 500},
	2: {"criatura": "múmia", "nivel": "mestre", "tipos": ["ajudante", "destruidor", "guardiao", "medico"], "custo": 1000},
}


static func servo_de(apr: Array) -> Dictionary:
	for i in [2, 1, 0]:
		if apr.has(i):
			return SERVOS[i]
	return SERVOS[-1]


const ESCOLAS := ["abjuração", "adivinhação", "convocação", "encantamento", "evocação", "ilusão", "necromancia", "transmutação"]


static func escola_valida(nome: String) -> bool:
	return ESCOLAS.has(nome.to_lower())
const TIPOS_ENERGIA := ["acido", "eletricidade", "fogo", "frio", "luz", "trevas"]


## Círculo máximo que o conjurador pode lançar. Usa a tabela de conjuração da classe (ex.: clérigo: 2º no 5º nível).
## Magia que o conjurador aprende ao subir de nível (catálogo: "aprende_a_cada_nivel"): a de maior círculo que ele já
## pode lançar, divina ou universal, completa e ainda não conhecida. Empate: ordem alfabética. "" se não há nenhuma.
static func magia_aprendida_no_nivel(sheet: CharacterSheet, rules: RuleRegistry) -> String:
	var max_c := circulo_maximo(sheet, rules)
	var ids: Array = COMPLETAS.keys()
	ids.sort()
	var best := ""
	var best_c := -1
	for sp_id in ids:
		var sp: Dictionary = rules.value("magia." + str(sp_id), {})
		if sp.is_empty() or not ["divina", "universal"].has(str(sp.get("tipo", ""))):
			continue
		var circ := int(sp.get("circulo", 0))
		if circ > max_c or circ <= best_c or sheet.spells.has(sp_id):
			continue
		best = str(sp_id)
		best_c = circ
	return best


static func circulo_maximo(sheet: CharacterSheet, rules: RuleRegistry) -> int:
	var magia: Dictionary = rules.value("classe." + sheet.class_id, {}).get("magia", {})
	var circulos: Dictionary = magia.get("circulos", {})
	if circulos.is_empty():
		return 1 + maxi(0, (sheet.level - 1) / 4)   # arcanista e demais: mesmo ritmo do raio arcano
	var best := 1
	for c in circulos:
		if sheet.level >= int(circulos[c]):
			best = maxi(best, int(c))
	return best


## Círculo exigido pelo aprimoramento, lido do texto do catálogo ("Requer 2º círculo.").
static func circulo_exigido(sp_id: String, i: int, rules: RuleRegistry) -> int:
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	if i < 0 or i >= lista.size():
		return 99
	var m := RegEx.create_from_string("Requer (\\d)º círculo").search(str(lista[i].texto))
	return int(m.get_string(1)) if m else 1


static func multi_alvo(sp_id: String, sp: Dictionary, apr: Array) -> bool:
	if str(sp.get("alvo_tipo", "")) == "Alvos" or str(sp.get("alvo", "")).begins_with("até "):
		return true
	for i in MULTI_APR.get(sp_id, []):
		if apr.has(i):
			return true
	return false


## Alcance efetivo com os aprimoramentos escolhidos (ex.: Infligir Ferimentos muda para curto).
static func alcance_efetivo(sp_id: String, base: String, apr: Array) -> String:
	for i in ALCANCE_APR.get(sp_id, {}):
		if apr.has(i):
			return str(ALCANCE_APR[sp_id][i])
	var b := base.replace("é", "e").to_lower()   # o catálogo escreve "médio"; a tabela de alcance usa "medio"
	return "ilimitado" if b.begins_with("ilimitado") else b


static func aprimoramentos_disponiveis(sp_id: String) -> Array:
	return COMPLETAS.get(sp_id, {}).get("aprimoramentos", [])


static func aprimoramentos_validos(sp_id: String, idx: Array, sheet: CharacterSheet, rules: RuleRegistry) -> bool:
	if not COMPLETAS.has(sp_id):
		return idx.is_empty()
	var permitidos: Array = COMPLETAS[sp_id].aprimoramentos
	var cmax := circulo_maximo(sheet, rules)
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	var tradicao := str(rules.value("classe." + sheet.class_id, {}).get("magia", {}).get("tipo", "arcana"))
	for i in idx:
		if not permitidos.has(int(i)) or circulo_exigido(sp_id, int(i), rules) > cmax:
			return false
		# "Apenas Arcanos" / "Apenas Divinos" (magias universais): só para quem lança pela tradição indicada
		var apenas := str(lista[int(i)].get("apenas", "")) if int(i) < lista.size() else ""
		if (apenas == "arcanos" and tradicao != "arcana") or (apenas == "divinos" and tradicao != "divina"):
			return false
	for par in EXCLUSIVOS.get(sp_id, []):
		if idx.has(par[0]) and idx.has(par[1]):
			return false
	return true


static func custo_aprimoramentos(rules: RuleRegistry, sp_id: String, idx: Array) -> int:
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	var total := 0
	for i in idx:
		if int(i) >= 0 and int(i) < lista.size():   # índice inválido é recusado na validação, não aqui
			total += int(lista[int(i)].pm)
	return total


## Perdição (divina 1): –1 em ataques e dano; +2 PM: –1 a mais (limite = círculo máximo do conjurador).
static func penalidade_perdicao(sheet: CharacterSheet, rules: RuleRegistry, idx: Array) -> int:
	return mini(1 + idx.count(0), circulo_maximo(sheet, rules))


## Bênção (divina 1): +1 em ataques e dano; +2 PM: +1 a mais, repetível (limite = círculo máximo do conjurador).
static func bonus_bencao(sheet: CharacterSheet, rules: RuleRegistry, idx: Array) -> int:
	return mini(1 + idx.count(1), circulo_maximo(sheet, rules))


static func e_reacao(sp_id: String) -> bool:
	return REACAO.has(sp_id)


## Lançar manualmente (no próprio turno): magias de reação só com aprimoramento de execução padrão.
static func pode_lancar_no_turno(sp_id: String, apr: Array) -> bool:
	for i in REACAO_APR.get(sp_id, []):
		if apr.has(i):
			return false   # execução de reação: só dispara em resposta a um evento
	if not REACAO.has(sp_id):
		return true
	for i in EXECUCAO_PADRAO_APR.get(sp_id, []):
		if apr.has(i):
			return true
	return false


static func tipo_energia_valido(t: String) -> bool:
	return TIPOS_ENERGIA.has(t)


## Consagrar / Profanar: não podem ser lançadas em área com símbolo visível de outra divindade. Locais do mapa podem
## ter "simbolo_divindade" (ex.: o Templo de Lena). Quem não tem devoção não tem divindade própria.
static func simbolo_impede(db: ContentDB, centro: Vector2i, raio_q: int, devocao: String) -> bool:
	for l in db.all_locations():
		var dono := str(l.get("simbolo_divindade", ""))
		if dono == "" or dono == devocao:
			continue
		var r: Array = l.rect
		var px := clampi(centro.x, int(r[0]), int(r[0]) + int(r[2]) - 1)
		var py := clampi(centro.y, int(r[1]), int(r[1]) + int(r[3]) - 1)
		if maxi(absi(px - centro.x), absi(py - centro.y)) <= raio_q:
			return true
	return false


const TAMANHOS := ["Minúsculo", "Pequeno", "Médio", "Grande", "Enorme", "Colossal"]
const DESPEDACAR_TAMANHO := {1: 2, 2: 3, 3: 4, 4: 5}   # aprimoramento -> índice em TAMANHOS


## Despedaçar: maior categoria de objeto mundano que a magia atinge (Pequeno sem aprimoramento de tamanho).
static func despedacar_tamanho_max(apr: Array) -> int:
	var t := 1
	for i in DESPEDACAR_TAMANHO:
		if apr.has(i):
			t = maxi(t, int(DESPEDACAR_TAMANHO[i]))
	return t


## Despedaçar: 1d8+2 de impacto, +1d8+2 por aprimoramento de 2 PM (repetível).
static func despedacar_dano(apr: Array) -> String:
	var n := 1 + apr.count(0)
	return "%dd8+%d" % [n, 2 * n]


static func tamanho_indice(nome: String) -> int:
	return TAMANHOS.find(nome)


const EFEITOS_MADEIRA := ["fortalecer", "modelar", "repelir", "retorcer"]


static func objeto_de_madeira(db: ContentDB, id: String) -> bool:
	var d := db.object_def(id)
	return not d.is_empty() and (str(d.type) == "chest" or str(d.get("break", {}).get("rule", "")).contains("madeira"))


## Controlar Madeira (divina 2, LB p.186): erro de validação ("" se válido). `a`: efeito, alvo (objeto, arma, escudo,
## parede), object_id / target / tile / forma. `de` é o quadrado do conjurador; `alvo` a ficha de quem empunha (arma, escudo).
static func erro_madeira(rules: RuleRegistry, db: ContentDB, a: Dictionary, de: Vector2i, alvo_tile: Vector2i, alvo: CharacterSheet) -> String:
	var apr: Array = a.get("aprimoramentos", [])
	if apr.has(0):
		return "" if apr.size() == 1 else "a forma de árvore não se combina com outros aprimoramentos"
	var medio := int(rules.value("alcance.quadrados", {}).get("medio", 20))
	if apr.has(1):
		var c: Vector2i = a.get("tile", de)
		if maxi(absi(de.x - c.x), absi(de.y - c.y)) > medio: return "fora do alcance"
		return "" if Area.quadrado(c, Area.quadrados(9.0)).any(func(t): return db.is_vegetation(t)) else "sem vegetação na área"
	var ef := str(a.get("efeito", ""))
	if not EFEITOS_MADEIRA.has(ef): return "escolha: fortalecer, modelar, repelir ou retorcer"
	var tam_max := 5 if apr.has(3) else (4 if apr.has(2) else 3)
	match str(a.get("alvo", "")):
		"objeto":
			var id := str(a.get("object_id", ""))
			if not objeto_de_madeira(db, id): return "escolha um objeto de madeira"
			var d := db.object_def(id)
			var o: Array = d.tile
			if maxi(absi(de.x - int(o[0])), absi(de.y - int(o[1]))) > medio: return "fora do alcance"
			var tam := tamanho_indice(str(d.get("break", {}).get("tamanho", "Grande")))
			if tam < 0 or tam > tam_max: return "objeto grande demais"
			if ef == "modelar" and not ["door", "chest"].has(str(d.type)): return "só portas e baús"
			if ef == "retorcer" and str(d.type) != "door": return "só portas emperram"
			if ef == "repelir" and not ["door", "chest"].has(str(d.type)): return "só portas e baús se abrem"
		"parede":
			if ef != "modelar": return "numa parede só se modela uma passagem"
			var t: Vector2i = a.get("tile", de)
			if maxi(absi(de.x - t.x), absi(de.y - t.y)) > medio: return "fora do alcance"
			if db.tile_info(t).get("name", "") != "parede" or not bool(db.location(db.location_at(t)).get("parede_madeira", false)): return "não é uma parede de madeira"
		"arma", "escudo":
			if alvo == null: return "escolha quem empunha"
			if maxi(absi(de.x - alvo_tile.x), absi(de.y - alvo_tile.y)) > medio: return "fora do alcance"
			var item := str(alvo.equipment.get("weapon" if a.alvo == "arma" else "shield", ""))
			if item == "": return "ele não empunha isso"
			if not bool(rules.value(("arma." if a.alvo == "arma" else "escudo.") + item, {}).get("madeira", false)): return "não é de madeira"
			if a.alvo == "escudo" and (ef == "repelir" or ef == "modelar"): return "escudos só podem ser fortalecidos ou retorcidos"
			if ef == "modelar":
				var forma := str(a.get("forma", ""))
				if forma == "" or not bool(rules.value("arma." + forma, {}).get("madeira", false)): return "escolha uma arma de madeira como forma"
		_:
			return "escolha o alvo: objeto, arma, escudo ou parede"
	return ""


## Efeito de Controlar Madeira sobre arma ou escudo de madeira empunhados. `conj`: id de quem lançou.
static func aplicar_madeira_equip(rules: RuleRegistry, ef: String, alvo_item: String, sh: CharacterSheet, conj: String, forma: String) -> void:
	var arma := str(sh.equipment.get("weapon", ""))
	var nome := arma.capitalize().replace("_", " ")
	match [ef, alvo_item]:
		["fortalecer", "arma"]:
			sh.add_efeito("magia.controlar_madeira", "armamento_passos", 1, "cena", nome)
		["fortalecer", "escudo"]:
			sh.add_efeito("magia.controlar_madeira", "escudo_defesa", 2, "cena")
		["repelir", "arma"]:
			sh.add_efeito("magia.controlar_madeira", "repele_arma", 1, "cena", conj)
		["retorcer", "arma"]:
			sh.add_efeito("magia.controlar_madeira", "ataque", -5, "cena")
		["retorcer", "escudo"]:
			sh.add_efeito("magia.controlar_madeira", "escudo_retorcido", 1, "cena")
		["modelar", "arma"]:
			sh.equipment["weapon"] = forma
			CharacterBuilder.apply_equipment(rules, sh)


## Arma Espiritual: tipo de dano da arma preferida da divindade ("" se a divindade não tem arma preferida).
## Nimb: qualquer arma; o jogador escolhe o tipo (corte, impacto ou perfuração).
static func arma_espiritual_tipo(rules: RuleRegistry, devocao: String, escolha: String) -> String:
	var tab: Dictionary = rules.value("panteao.arma_preferida", {})
	var v = tab.get(devocao, null)
	if v == null:
		return ""
	if v is String and str(v) == "qualquer":
		return escolha if ["corte", "impacto", "perfuracao"].has(escolha) else ""
	return str((v as Dictionary).get("dano", ""))


## Armamento da Natureza: o ataque (pelo nome; "" = o primeiro válido) que a magia pode fortalecer: arma mundana
## primitiva (sem custo em T$: "primitiva" no catálogo), arma natural ou ataque desarmado. {} se não há.
static func armamento_ataque(rules: RuleRegistry, sheet: CharacterSheet, nome: String) -> Dictionary:
	for atk in sheet.attacks:
		if nome != "" and str(atk.get("nome", "")) != nome:
			continue
		var arma_id := str(atk.get("arma_id", ""))
		if bool(atk.get("natural", false)) or bool(atk.get("desarmado", false)) or bool(rules.value("arma." + arma_id, {}).get("primitiva", false)):
			return atk
	return {}


## Truque (LB p.171): versão mais simples descrita no texto da magia ("Truque: ..."); custa 0 PM e não se combina
## com aprimoramentos.
static func tem_truque(rules: RuleRegistry, sp_id: String) -> bool:
	return str(rules.value("magia." + sp_id, {}).get("texto", "")).contains("Truque:")


## Caminhos da Natureza nos alvos (em combate ou fora): 1 dia. Normal: +3m de deslocamento (+3m por aprimoramento de
## 2 PM) e ignora terreno difícil natural; aprimoramento de 1 PM: CD +10 para rastreá-los em terreno natural.
## Truque: só o conjurador, +5 em Sobrevivência para se orientar.
static func aplicar_caminhos(sh: CharacterSheet, apr: Array, truque: bool, ate_dia: int) -> void:
	sh.remove_efeito("magia.caminhos_da_natureza")
	if truque:
		sh.add_efeito("magia.caminhos_da_natureza", "sobrevivencia_orientar", 5, "dia", "", ate_dia)
		return
	sh.add_efeito("magia.caminhos_da_natureza", "deslocamento_m", 3 * (1 + apr.count(1)), "dia", "", ate_dia)
	sh.add_efeito("magia.caminhos_da_natureza", "ignora_dificil_natural", 1, "dia", "", ate_dia)
	if apr.has(0):
		sh.add_efeito("magia.caminhos_da_natureza", "rastro_dificil", 10, "dia", "", ate_dia)


const ORDENS_COMANDO := ["fuja", "largue", "pare", "senta", "venha"]
const ORDENS_MARCA := ["nao_ataque", "siga", "fique"]   # Marca da Obediência: o alvo gasta o turno obedecendo


## Acalmar Animal: animal; monstro ou espírito com Int –5 ou –4 (1 PM); qualquer monstro ou espírito (5 PM).
## Tranquilidade: animal ou humanoide; qualquer criatura (1 PM, ou criaturas escolhidas com o de 5 PM).
const CLIMAS_TEMPESTADE := ["", "chuva", "neve", "granizo"]
const MALDICOES := ["debilidade", "doenca", "fraqueza", "isolamento"]
const SENTIDOS := ["visao", "audicao", "olfato", "paladar", "tato"]
const PO_DE_ONIX := 10   # T$ do truque do Miasma Mefítico
const EFEITOS_FOGO := ["chamejar", "esquentar", "extinguir", "modelar"]


## Criatura composta principalmente por fogo, lava ou magma (bestiário: "composicao").
static func criatura_de_fogo(rules: RuleRegistry, sh: CharacterSheet) -> bool:
	return ["fogo", "lava", "magma"].has(str(rules.value(sh.source_rule, {}).get("composicao", "")))


## Condição (divina 2): o que o conjurador sabe de um alvo — posição, PV, condições e magias ativas sobre ele.
static func status_de(id: String, sh: CharacterSheet, tile: Vector2i) -> Dictionary:
	var magias: Array = []
	for e in sh.efeitos:
		var fonte := str(e.id)
		if fonte.begins_with("magia.") and not magias.has(fonte.trim_prefix("magia.")):
			magias.append(fonte.trim_prefix("magia."))
	return {"target": id, "tile": [tile.x, tile.y], "pv": sh.pv, "pv_max": sh.pv_max, "condicoes": sh.conditions.duplicate(), "magias": magias}


## Comunicação para Mudar Atitude: humanoides falam; outros tipos só com Voz Divina (ou Compreensão nesse alvo).
static func pode_conversar(fala: CharacterSheet, alvo_id: String, alvo: CharacterSheet) -> bool:
	if alvo.creature_type == "" or alvo.creature_type == "humanoide":
		return true
	return fala.efeito_bonus("voz_divina") > 0 or fala.efeitos.any(func(e): return e.stat == "compreende" and str(e.tipo) == alvo_id)


static func alvo_social_valido(sp_id: String, apr: Array, alvo: CharacterSheet) -> bool:
	var tipo := alvo.creature_type
	if sp_id == "acalmar_animal":
		if tipo == "animal":
			return true
		if ["monstro", "espirito"].has(tipo):
			return apr.has(3) or (apr.has(1) and int(alvo.attrs.get("int", 0)) <= -4)
		return false
	if apr.has(0) or apr.has(2):
		return true
	return tipo == "animal" or tipo == "humanoide"


## Detectar Ameaças: aura pelo nível ou ND (1-6 tênue, 7-12 moderada, 13-20 poderosa, acima avassaladora).
static func aura_por_nd(nd: String) -> String:
	var v := float(nd.get_slice("/", 0)) / float(nd.get_slice("/", 1)) if nd.contains("/") else float(nd)
	if v > 20.0:
		return "avassaladora"
	if v >= 13.0:
		return "poderosa"
	if v >= 7.0:
		return "moderada"
	return "tenue"


## Suporte Ambiental: por 1 dia, imune ao clima extremo, respira na água e não sufoca em fumaça.
static func aplicar_suporte(sh: CharacterSheet, ate_dia: int) -> void:
	sh.add_efeito("magia.suporte_ambiental", "imune_clima", 1, "dia", "", ate_dia)
	sh.add_efeito("magia.suporte_ambiental", "respira_agua", 1, "dia", "", ate_dia)
	sh.add_efeito("magia.suporte_ambiental", "imune_fumaca", 1, "dia", "", ate_dia)


## Aviso (alerta): +5 no próximo teste de Iniciativa e de Percepção, até o fim da próxima cena.
static func aplicar_alerta(sh: CharacterSheet) -> void:
	sh.add_efeito("magia.aviso", "proxima_iniciativa", 5, "cena")
	sh.add_efeito("magia.aviso", "proxima_percepcao", 5, "cena")


## Intensidade da aura de uma magia pelo círculo (Misticismo, LB p.121): 1º-2º tênue, 3º-4º moderada, 5º poderosa.
static func aura_por_circulo(circulo: int) -> String:
	if circulo >= 5:
		return "poderosa"
	if circulo >= 3:
		return "moderada"
	return "tenue"


const ATRIBUTOS_FISICOS := ["for", "des", "con"]
const ATRIBUTOS_MENTAIS := ["int", "sab", "car"]
## Purificação: condições que pode remover.
const CONDICOES_PURIFICACAO := ["abalado", "apavorado", "alquebrado", "atordoado", "cego", "confuso", "debilitado", "enjoado", "envenenado",
	"esmorecido", "exausto", "fascinado", "fatigado", "fraco", "frustrado", "lento", "ofuscado", "paralisado", "pasmo", "surdo"]


## Físico Divino / Mente Divina: {atributo: bônus}. Normal: +2 no escolhido. "Em vez do normal": +2 nos três (3º),
## +4 no escolhido (4º), +4 nos três (5º); vale o maior.
static func bonus_atributos(sp_id: String, apr: Array, escolhido: String) -> Dictionary:
	var grupo: Array = ATRIBUTOS_FISICOS if sp_id == "fisico_divino" else ATRIBUTOS_MENTAIS
	var out := {}
	if apr.has(3):
		for a in grupo: out[a] = 4
	elif apr.has(2):
		out[escolhido] = 4
		if apr.has(1):
			for a in grupo: out[a] = maxi(int(out.get(a, 0)), 2)
	elif apr.has(1):
		for a in grupo: out[a] = 2
	else:
		out[escolhido] = 2
	return out
