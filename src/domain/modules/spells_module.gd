extends WorldModule
## Magias fora de combate (docs/MAGIA_COMPLEXA.md): o comando CastSpell lança, fora de uma luta, a cura em si mesmo
## e as magias e versões de magia que agem sobre o mundo e não sobre a cena de combate (cadáveres, alimentos, áreas, sentidos).
## Em combate, as magias passam pelo CombatModule.
## Estado: cadáveres preservados pela Bênção (criatura -> último dia preservado) e áreas consagradas e profanadas.

const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
const Area := preload("res://src/domain/combat/area.gd")
const Atitudes := preload("res://src/domain/rules/atitudes.gd")

## Magias e aprimoramentos que funcionam fora de combate: spell -> aprimoramentos que tornam isso possível
## ([] = a versão básica já funciona fora de combate).
const FORA_DE_COMBATE := {
	"bencao": [0],   # 1 cadáver por 1 semana
	"consagrar": [],
	"profanar": [],
	"despedacar": [],   # contra um objeto mundano
	"caminhos_da_natureza": [],   # você e os companheiros presentes
	"controlar_plantas": [],   # poda, falar com plantas e truque (enredar só tem efeito numa cena de combate)
	"acalmar_animal": [],   # criaturas por perto, antes da luta
	"tranquilidade": [],
	"detectar_ameacas": [],
	"suporte_ambiental": [],   # você (e, com o aprimoramento, os companheiros presentes)
	"abencoar_alimentos": [],
	"criar_elementos": [],
	"luz": [],   # num objeto que você carrega (ou permanente, com pó de rubi)
	"aviso": [],   # aviso telepático a NPCs e companheiros, mesmo longe
	"compreensao": [],   # NPC no mesmo lugar (toque ou curto)
	"visao_mistica": [],
	"silencio": [0, 1],   # fora de combate, o objeto que você carrega, pela cena: nenhum som sai (furtividade)
	"escuridao": [],
	"voz_divina": [],
	"aliado_animal": [],   # animal prestativo por perto vira parceiro por um dia; ou mensageiro (aprimoramento)
	"condicao": [],
	"controlar_madeira": [],   # portas, baús, paredes de madeira e o seu equipamento; ou a forma de árvore
	"projetar_consciencia": [],   # um lugar do mapa ou um NPC (no mesmo plano); sustentada pela cena
	"controlar_terra": [1],   # fora de combate, só fundir-se à pedra ao lado (um dia)
	"viagem_arborea": [],   # de uma árvore ao lado para outra no mapa; com o aprimoramento, o grupo, até uma planta a 100km
	"globo_da_verdade": [],   # o que você (ou um NPC tocado) viu sobre um assunto; aprimoramentos: mês, ano, cadáver, 10 globos
	"missao_divina": [],   # num NPC aqui: ir a um lugar (uma semana, ou um ano); ou a marca (aprimoramento)
	"servo_divino": [],   # tarefa "entregar": o espírito leva um item a um lugar, para ser recolhido lá no prazo
	"intervencao_divina": [],   # curar o grupo, criar item, duplicar magia, proteger o povoado
	"conceder_milagre": [],   # num companheiro do grupo (fora de combate a magia fica com ele para a próxima luta)
	"runa_de_protecao": [],   # no chão onde você está (1 hora, pó de diamante T$ 200) ou no próprio corpo (aprimoramentos)
	"comunhao_com_a_natureza": [],   # dados de auxílio pelo dia, ou (aprimoramento) informações da região
	"despertar_consciencia": [],   # animal ou planta ao lado, escultura (aprimoramento) ou um parceiro seu
	"servo_morto_vivo": [],   # cadáver de humanoide, animal ou monstro vira parceiro morto-vivo permanente
	"videncia": [],   # um NPC a qualquer distância; a familiaridade muda a Vontade dele
	"lendas_e_historias": [],   # NPC, objeto ou lugar tocado; com o aprimoramento, qualquer um conhecido (um dia, T$ 1.000)
	"controlar_o_clima": [],   # fixa o clima da região (limpo, nublado, chuva, tempestade ou neblina) por 4d12 horas
	"augurio": [],   # sobre entrar ou explorar um lugar (felicidade, miséria, ambos ou nada); consultas a uma divindade
	"circulo_da_justica": [],   # num ponto em alcance curto: os NPCs do lugar não mentem (nem distorcem boatos)   # companheiros e NPCs por perto; depois, a distância não importa   # conversar com qualquer criatura; interrogar cadáver; falar com plantas e rochas   # água no recipiente, chama na palma, terra; ar e fogo em quadrados só pesam numa cena
}
const PO_DE_PRATA := 5   # T$ de pó de prata da água benta
const RAIO_DETECTAR := 12   # esfera de 18m
const OPOSTA := {"consagrar": "profanar", "profanar": "consagrar"}
const ENERGIA := {"consagrar": "luz", "profanar": "trevas"}
const TOTAL_PERMANENTE := 1000   # T$ de incenso e óleos da versão permanente
const DIAS_SEMANA := 7
const BALANCA_DE_PRATA := 5000   # T$ da versão permanente do Círculo da Justiça
const PERICIAS_JUSTICA := ["acrobacia", "enganacao", "furtividade", "ladinagem"]
const MINUTOS_DIA := 24 * 60

var mensageiros: Array = []   # Aliado Animal (mensageiro): {item, destino, chega_dia, ate_dia}
var augurios: Dictionary = {}   # Augúrio: assunto -> primeira resposta (lançar de novo sobre o mesmo assunto a repete)
var justicas: Array = []   # Círculo da Justiça: {centro:[x,y], raio, ate (minuto, -1 permanente), cd, forte, resistiu:{id: bool}}
var interrogados: Dictionary = {}   # Voz Divina: cadáveres que já responderam (um corpo só uma vez)
var cadaveres: Dictionary = {}   # creature_id -> último dia (inclusive) em que está preservado
var detectar: Dictionary = {}    # Detectar Ameaças ativa: {ate: tick, apr: [...]} (cena, até ser descarregada)
var protecao_detectar: Dictionary = {}   # aprimoramento de 2 PM depois de descarregada: {ate: tick}
var silencio_carregado: Dictionary = {}   # Silêncio (objeto, cena) fora de combate: {ate: tick}
var escuridao_carregada: Dictionary = {}   # objeto que emana sombras (Escuridão): {raio, total, ate}
var missoes: Dictionary = {}   # Missão Divina: npc -> {destino, ate_dia, recusou, penalidade, cd, marca, cumprida}
var _dia_missoes := -1
var _lancando_pela_projecao := false
var visitados: Dictionary = {}   # lugares onde o jogador já esteve (Projetar Consciência: lugar conhecido)
var projecao: Dictionary = {}   # Projetar Consciência ativa: {local, npc, ate, magias}
var arborea_ate := -1   # Viagem Arbórea ativa até este tick: pode passar de árvore em árvore (TreeHop, 1 PM)
var cidade_protegida: Dictionary = {}   # Intervenção Divina: {zona} protegida do próximo desastre
var _duplicando := false   # Intervenção Divina (duplicar): a magia duplicada não pede ser conhecida nem PM
var runas: Array = []   # Runa de Proteção no chão: {id, centro:[x,y], raio, tipo, dados, gatilho, palavra, cd, conj, dentro, achada}
var videncia: Dictionary = {}   # Vidência ativa: {alvo, ate: tick}; enquanto dura, `videncia_ver` mostra o alvo e os arredores
var luz_carregada: Dictionary = {}   # luz que o jogador carrega fora de combate: {raio: quadrados, ate: tick}
var abencoados: Dictionary = {}  # item -> {n: porções abençoadas, ate: tick do fim da cena}
var podas: Dictionary = {}       # "x,y" -> true: vegetação podada por Controlar Plantas (instantânea, fica)
var areas: Array = []            # {tipo, centro:[x,y], raio, ate: minuto do fim (-1 permanente), mod_mv:int, conjurador}


func module_id() -> String: return "magia"
func handled_commands() -> PackedStringArray: return PackedStringArray(["CastSpell", "DetectMagic", "ReadThoughts", "CollectMessenger", "SearchRunes", "DisarmRune", "TreeHop", "LeaveStone", "EndProjection"])


## Projetar Consciência (aprimoramento): "pela_projecao" lança a magia a partir da projeção — sem componente material
## e sem ser sustentada; os NPCs que a projeção vê contam como presentes.
func validate(cmd: GameCommand) -> PackedStringArray:
	if not bool(cmd.payload.get("pela_projecao", false)):
		return _validate(cmd)
	if projecao.is_empty() or not bool(projecao.magias) or projecao_local() == "":
		return PackedStringArray(["sem projeção capaz de lançar magias"])
	var regra: Dictionary = world.rules.value("magia." + str(cmd.payload.get("spell", "")), {})
	if "Componente material" in str(regra.get("texto", "")) or str(regra.get("duracao", "")) == "sustentada":
		return PackedStringArray(["pela projeção, só magias sem componente material e não sustentadas"])
	_lancando_pela_projecao = true
	var erros := _validate(cmd)
	_lancando_pela_projecao = false
	return erros


func _validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate: use as ações de combate"])
	if cmd.type == "CollectMessenger":
		return PackedStringArray() if mensageiros.any(func(m): return str(m.destino) == str(cmd.payload.get("destino", ""))) else PackedStringArray(["nenhum mensageiro lá"])
	if cmd.type == "EndProjection":
		return PackedStringArray() if not projecao.is_empty() else PackedStringArray(["sem projeção"])
	if cmd.type == "LeaveStone":
		return PackedStringArray() if world.player_sheet != null and world.player_sheet.efeito_bonus("mesclado") > 0 else PackedStringArray(["você não está fundido à pedra"])
	if cmd.type == "TreeHop":
		if world.clock.tick >= arborea_ate:
			return PackedStringArray(["a Viagem Arbórea não está ativa"])
		if world.player_sheet.pm < 1:
			return PackedStringArray(["PM insuficiente (1)"])
		return _valida_arvores(cmd.payload)
	if cmd.type == "SearchRunes":
		return PackedStringArray()
	if cmd.type == "DisarmRune":
		var rr := _runa(str(cmd.payload.get("id", "")))
		if rr.is_empty() or not (bool(rr.achada) or str(rr.conj) == "player"):
			return PackedStringArray(["nenhuma runa encontrada com esse id"])
		if _dist(rr, _tile_jogador()) > 1:
			return PackedStringArray(["chegue perto da runa"])
		if world.player_sheet == null or not world.player_sheet.can_use_skill("ladinagem", world.rules):
			return PackedStringArray(["Ladinagem é somente treinada"])
		return PackedStringArray()
	if cmd.type == "DetectMagic":
		if world.player_sheet == null or not world.player_sheet.can_use_skill("misticismo", world.rules):
			return PackedStringArray(["Misticismo é somente treinada"])
		return PackedStringArray()
	if cmd.type == "ReadThoughts":
		var alvo_rt := str(cmd.payload.get("target", ""))
		if world.player_sheet == null or not world.player_sheet.efeito_tipo_existe("compreende", alvo_rt):
			return PackedStringArray(["lance Compreensão nele antes"])
		if not _no_mesmo_lugar(alvo_rt):
			return PackedStringArray(["ele não está aqui"])
		return PackedStringArray()
	var sh: CharacterSheet = world.player_sheet
	if sh == null:
		return PackedStringArray(["sem personagem"])
	var sp_id := str(cmd.payload.get("spell", ""))
	var apr: Array = cmd.payload.get("aprimoramentos", [])
	if not sh.spells.has(sp_id) and not _duplicando:
		return PackedStringArray(["magia não conhecida"])
	if world.rules.value("magia." + sp_id, {}).has("cura"):
		if not apr.is_empty():
			return PackedStringArray(["fora de combate, a cura é lançada sem aprimoramentos"])
		if not _duplicando and sh.pm < GhostPlanner.spell_cost(world.rules, GhostPlanner.spell_rule(world.rules, sp_id), cmd.payload, sh):
			return PackedStringArray(["PM insuficiente"])
		return PackedStringArray()
	if not FORA_DE_COMBATE.has(sp_id):
		return PackedStringArray(["essa magia só é lançada em combate"])
	for i in FORA_DE_COMBATE[sp_id]:
		if not apr.has(i):
			return PackedStringArray(["essa versão da magia só é lançada em combate"])
	if cmd.payload.get("truque", false):
		if not SpellRules.tem_truque(world.rules, sp_id):
			return PackedStringArray(["essa magia não tem truque"])
		if not apr.is_empty():
			return PackedStringArray(["truques não se combinam com aprimoramentos"])
	var sp := GhostPlanner.spell_rule(world.rules, sp_id)
	if int(sp.get("circulo", 0)) > SpellRules.circulo_maximo(sh, world.rules):
		return PackedStringArray(["magia acima do círculo que você conjura"])
	if not SpellRules.aprimoramentos_validos(sp_id, apr, sh, world.rules):
		return PackedStringArray(["aprimoramento não disponível para essa magia"])
	if not _duplicando and sh.pm < GhostPlanner.spell_cost(world.rules, sp, cmd.payload, sh):
		return PackedStringArray(["PM insuficiente"])
	match sp_id:
		"bencao":
			return _valida_cadaver(str(cmd.payload.get("target", "")), str(sp.get("alcance", "curto")))
		"despedacar":
			if apr.has(5):
				return PackedStringArray(["a versão em área só é lançada em combate"])
			var od := world.db.object_def(str(cmd.payload.get("objeto", "")))
			if od.is_empty() or not od.has("break"):
				return PackedStringArray(["escolha um objeto mundano"])
			var objs = world.module("objects")
			if objs != null and bool(objs.obj(str(od.id)).get("broken", false)):
				return PackedStringArray(["o objeto já está destruído"])
			var tam := SpellRules.tamanho_indice(str(od["break"].get("tamanho", "")))
			if tam < 0 or tam > SpellRules.despedacar_tamanho_max(apr):
				return PackedStringArray(["objeto grande demais para o Despedaçar escolhido"])
			var p := _tile_jogador()
			if maxi(absi(p.x - int(od.tile[0])), absi(p.y - int(od.tile[1]))) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)):
				return PackedStringArray(["objeto fora do alcance"])
		"abencoar_alimentos":
			return _valida_abencoar(cmd.payload, apr)
		"aviso":
			if not ["alerta", "mensagem", "localizacao"].has(str(cmd.payload.get("modo", "alerta"))):
				return PackedStringArray(["escolha alerta, mensagem ou localização"])
			var alvos_av: Array = cmd.payload.get("targets", ["player"])
			if alvos_av.size() > 1 + apr.count(3):
				return PackedStringArray(["alvos demais"])
			var npcs_av = world.module("npcs")
			for tg in alvos_av:
				if tg != "player" and (npcs_av == null or npcs_av.npc(tg).is_empty() or not bool(npcs_av.npc(tg).alive)):
					return PackedStringArray(["alvo inválido"])
		"compreensao":
			if not apr.has(3):
				var alvos_co: Array = cmd.payload.get("targets", [])
				if alvos_co.is_empty() or (alvos_co.size() > 1 and not apr.has(1)):
					return PackedStringArray(["escolha quem tocar"])
				for tg in alvos_co:
					if not _no_mesmo_lugar(tg):
						return PackedStringArray(["%s não está aqui" % tg])
		"luz", "escuridao":
			if sp_id == "luz" and apr.has(2) and int(world.player.gold) < 50:
				return PackedStringArray(["faltam T$ 50 de pó de rubi"])
			if sp_id == "luz" and apr.has(2) and apr.size() > 1:
				return PackedStringArray(["a luz permanente não se combina com outros aprimoramentos"])
			if (sp_id == "luz" and (apr.has(3) or apr.has(4) or apr.has(6))) or (sp_id == "escuridao" and apr.has(2)):
				return PackedStringArray(["essa versão mira criaturas ou pontos de uma cena de combate"])
		"criar_elementos":
			if not SpellRules.ELEMENTOS.has(str(cmd.payload.get("elemento", ""))):
				return PackedStringArray(["escolha o elemento: água, ar, fogo ou terra"])
			if apr.has(1) or apr.has(2):
				return PackedStringArray(["arremessar e queimar são em combate"])
		"acalmar_animal", "tranquilidade":
			var combat_v = world.module("combat")
			var alvos_v: Array = cmd.payload.get("targets", [])
			var lim := 1 + apr.count(2 if sp_id == "acalmar_animal" else 1)
			if sp_id == "tranquilidade" and apr.has(2):
				lim = 999
			if alvos_v.is_empty() or alvos_v.size() > lim:
				return PackedStringArray(["escolha os alvos"])
			var alc := SpellRules.alcance_efetivo(sp_id, str(sp.get("alcance", "curto")), apr)
			var reach := int(world.rules.value("alcance.quadrados", {}).get(alc, 6))
			for tg in alvos_v:
				if combat_v == null or not combat_v.creature_state.has(tg) or not combat_v.is_active_creature(tg):
					return PackedStringArray(["alvo inválido"])
				var tc: Vector2i = combat_v.creature_tile(tg)
				var p_v := _tile_jogador()
				if maxi(absi(p_v.x - tc.x), absi(p_v.y - tc.y)) > reach:
					return PackedStringArray(["fora do alcance"])
				if not SpellRules.alvo_social_valido(sp_id, apr, CharacterSheet.from_dict(combat_v.creature_state[tg].sheet)):
					return PackedStringArray(["tipo de criatura que a magia não afeta"])
		"aliado_animal":
			var err_aa := validar_aliado_animal(cmd.payload, sh)
			if err_aa != "":
				return PackedStringArray([err_aa])
		"projetar_consciencia":
			var npc_pc := str(cmd.payload.get("npc", ""))
			var local_pc := str(cmd.payload.get("local", ""))
			if npc_pc != "":
				var npcs_pc = world.module("npcs")
				if npcs_pc == null or npcs_pc.npc(npc_pc).is_empty() or not bool(npcs_pc.npc(npc_pc).get("alive", true)):
					return PackedStringArray(["escolha um NPC vivo"])
			elif not _local_existe(local_pc):
				return PackedStringArray(["escolha um lugar conhecido ou um NPC"])
			elif not _visitado(local_pc):
				return PackedStringArray(["o lugar precisa ser conhecido por você"])
		"controlar_terra":
			var t_ct := _tile_jogador()
			var pedra := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					pedra = pedra or ["#", "B"].has(world.db.tile_char(t_ct + Vector2i(dx, dy)))
			if not pedra:
				return PackedStringArray(["é preciso pedra ou terra ao seu lado"])
		"viagem_arborea":
			var err_va := _valida_arvores(cmd.payload)
			if not err_va.is_empty():
				return err_va
		"globo_da_verdade":
			var alvo_gv := str(cmd.payload.get("target", "player"))
			if str(cmd.payload.get("pergunta", "")) == "":
				return PackedStringArray(["faça a pergunta (o assunto da cena)"])
			if alvo_gv != "player":
				var npcs_gv = world.module("npcs")
				if npcs_gv == null or npcs_gv.npc(alvo_gv).is_empty():
					return PackedStringArray(["toque você mesmo ou um NPC"])
				var morto_gv: bool = not bool(npcs_gv.npc(alvo_gv).get("alive", true))
				if morto_gv and not apr.has(2):
					return PackedStringArray(["um cadáver só com o aprimoramento"])
				if not morto_gv and not _no_mesmo_lugar(alvo_gv):
					return PackedStringArray(["o NPC precisa estar aqui para ser tocado"])
		"missao_divina":
			var alvo_md := str(cmd.payload.get("target", ""))
			if not _no_mesmo_lugar(alvo_md):
				return PackedStringArray(["o NPC precisa estar aqui"])
			if apr.has(0):
				if str(cmd.payload.get("gatilho", "")) != "crime":
					return PackedStringArray(["a marca é ativada por crimes (gatilho: crime)"])
			elif not _local_existe(str(cmd.payload.get("destino", ""))):
				return PackedStringArray(["escolha o lugar aonde ele deve ir (destino)"])
		"servo_divino":
			var apr_sd: Array = cmd.payload.get("aprimoramentos", [])
			if str(cmd.payload.get("tarefa", "")) != "entregar":
				return PackedStringArray(["fora de combate, a tarefa do espírito é entregar um item"])
			var st_sd = world.module("state")
			if st_sd == null or not st_sd.has_item(str(cmd.payload.get("item", ""))):
				return PackedStringArray(["você não tem esse item"])
			if not _local_existe(str(cmd.payload.get("destino", ""))):
				return PackedStringArray(["escolha o lugar de entrega"])
			if int(world.player.gold) < SpellRules.servo_divino_custo(apr_sd):
				return PackedStringArray(["faltam T$ %d para pagar o espírito" % SpellRules.servo_divino_custo(apr_sd)])
		"intervencao_divina":
			var err_iv := SpellRules.erro_intervencao(world.rules, sh, cmd.payload)
			if err_iv != "":
				return PackedStringArray([err_iv])
			match str(cmd.payload.opcao):
				"dissipar", "ressuscitar":
					return PackedStringArray(["essa opção é em combate"])
				"item":
					var it := str(cmd.payload.get("item", ""))
					var def_it: Dictionary = world.db.items.get(it, {})
					if def_it.is_empty() or int(def_it.get("price", 0)) <= 0 or int(def_it.price) > 30000:
						return PackedStringArray(["escolha um item mundano à venda de até T$ 30.000"])
				"duplicar":
					var sub_v := GameCommand.create("intervencao", "player", "CastSpell", (cmd.payload.acao as Dictionary).duplicate(true))
					_duplicando = true
					var errs_v := validate(sub_v)
					_duplicando = false
					if not errs_v.is_empty():
						return errs_v
		"conceder_milagre":
			var party_cm = world.module("party")
			if party_cm == null or not party_cm.members.has(str(cmd.payload.get("target", ""))):
				return PackedStringArray(["toque um companheiro do grupo"])
			var err_cm := SpellRules.erro_milagre(world.rules, sh, str(cmd.payload.get("magia", "")), apr.has(0))
			if err_cm != "":
				return PackedStringArray([err_cm])
		"runa_de_protecao":
			if int(world.player.gold) < 200:
				return PackedStringArray(["falta o pó de diamante (T$ 200)"])
			if apr.has(1) or apr.has(2):
				var sp_r := str(cmd.payload.get("magia", ""))
				var regra_r := GhostPlanner.spell_rule(world.rules, sp_r)
				if not sh.spells.has(sp_r) or not SpellRules.COMPLETAS.has(sp_r) or SpellRules.RUNA_SEM.has(sp_r):
					return PackedStringArray(["escolha uma magia que você conhece e que cabe na runa"])
				if int(regra_r.get("circulo", 9)) > (2 if apr.has(2) else 1):
					return PackedStringArray(["a magia da runa vai até o %dº círculo" % (2 if apr.has(2) else 1)])
				if not ["padrão", "movimento", "livre", "reação"].has(str(regra_r.get("execucao", ""))):
					return PackedStringArray(["só magias de execução padrão ou menor"])
				if not ["ataque", "magia"].has(str(cmd.payload.get("gatilho", ""))):
					return PackedStringArray(["condição: ataque (quando for alvo de um ataque) ou magia (de uma magia)"])
			elif not SpellRules.TIPOS_ENERGIA.has(str(cmd.payload.get("tipo_energia", ""))):
				return PackedStringArray(["tipo de dano: " + ", ".join(PackedStringArray(SpellRules.TIPOS_ENERGIA))])
		"comunhao_com_a_natureza":
			if not world.db.is_natural(_tile_jogador()):
				return PackedStringArray(["é preciso estar numa área natural"])
		"despertar_consciencia":
			var err_dc := _valida_despertar(cmd.payload)
			if err_dc != "":
				return PackedStringArray([err_dc])
		"servo_morto_vivo":
			var alvo_sm := str(cmd.payload.get("target", ""))
			var err_sm := _valida_cadaver(alvo_sm, "toque")
			if not err_sm.is_empty():
				return err_sm
			var st_sm: Dictionary = world.module("combat").creature_state[alvo_sm]
			if bool(st_sm.get("reanimado", false)):
				return PackedStringArray(["esse corpo já foi reanimado"])
			if not ["humanoide", "animal", "monstro"].has(str((st_sm.get("sheet", {}) as Dictionary).get("creature_type", ""))):
				return PackedStringArray(["só cadáveres de humanoides, animais ou monstros"])
			var servo := SpellRules.servo_de(apr)
			if not (servo.tipos as Array).has(str(cmd.payload.get("tipo", ""))):
				return PackedStringArray(["tipo de parceiro: " + ", ".join(PackedStringArray(servo.tipos))])
			if int(world.player.gold) < int(servo.custo):
				return PackedStringArray(["falta o componente (T$ %d)" % int(servo.custo)])
		"videncia":
			if world.db.npc_def(str(cmd.payload.get("alvo", ""))).is_empty():
				return PackedStringArray(["escolha um NPC"])
		"lendas_e_historias":
			var tipo_lh := str(cmd.payload.get("alvo_tipo", ""))
			var alvo_lh := str(cmd.payload.get("alvo", ""))
			if not ["criatura", "objeto", "local"].has(tipo_lh):
				return PackedStringArray(["alvo_tipo: criatura, objeto ou local"])
			if tipo_lh == "criatura" and world.db.npc_def(alvo_lh).is_empty():
				return PackedStringArray(["criatura desconhecida"])
			if tipo_lh == "objeto" and world.db.object_def(alvo_lh).is_empty():
				return PackedStringArray(["objeto desconhecido"])
			if tipo_lh == "local" and world.db.location(alvo_lh).is_empty():
				return PackedStringArray(["lugar desconhecido"])
			if apr.has(0):
				if int(world.player.gold) < 1000:
					return PackedStringArray(["falta a cuba de ouro com ingredientes (T$ 1.000)"])
			elif tipo_lh == "criatura" and not _no_mesmo_lugar(alvo_lh):
				return PackedStringArray(["%s não está aqui para ser tocado" % alvo_lh])
			elif tipo_lh == "objeto":
				var od_lh := world.db.object_def(alvo_lh)
				var t_lh := Vector2i(int(od_lh.tile[0]), int(od_lh.tile[1]))
				if maxi(absi(t_lh.x - _tile_jogador().x), absi(t_lh.y - _tile_jogador().y)) > 1:
					return PackedStringArray(["chegue perto do objeto para tocá-lo"])
			elif tipo_lh == "local" and world.db.location_at(_tile_jogador()) != alvo_lh:
				return PackedStringArray(["você precisa estar no lugar"])
		"controlar_o_clima":
			if not WeatherModule.CONDITIONS.has(str(cmd.payload.get("clima", ""))):
				return PackedStringArray(["escolha o clima: " + ", ".join(PackedStringArray(WeatherModule.CONDITIONS))])
		"augurio":
			var err_au := validar_augurio(cmd.payload)
			if err_au != "":
				return PackedStringArray([err_au])
		"circulo_da_justica":
			if apr.has(2) and int(world.player.gold) < BALANCA_DE_PRATA:
				return PackedStringArray(["falta a balança de prata (T$ %d)" % BALANCA_DE_PRATA])
		"condicao":
			var alvos_cd: Array = cmd.payload.get("targets", [])
			if alvos_cd.is_empty() or alvos_cd.size() > 5 + apr.count(0):
				return PackedStringArray(["escolha de 1 a %d alvos" % (5 + apr.count(0))])
			for tg in alvos_cd:
				if not _no_mesmo_lugar(str(tg)):
					return PackedStringArray(["%s não está aqui" % tg])
		"voz_divina":
			if apr.has(0):
				var alvo_vd := str(cmd.payload.get("target", ""))
				if interrogados.has(alvo_vd):
					return PackedStringArray(["esse corpo já respondeu uma vez"])
				return _valida_cadaver(alvo_vd, "toque")
		"controlar_madeira":
			if apr.has(1):
				return PackedStringArray(["a vegetação afiada só é lançada em combate"])
			var p_cm := _tile_jogador()
			var err_cm := SpellRules.erro_madeira(world.rules, world.db, cmd.payload, p_cm, p_cm, sh)
			if err_cm != "":
				return PackedStringArray([err_cm])
		"controlar_plantas":
			if not cmd.payload.get("truque", false) and not apr.has(0) and not apr.has(2):
				return PackedStringArray(["fora de combate, só a poda, falar com plantas ou o truque"])
			if not apr.has(2):
				var p_cp := _tile_jogador()
				var tiles_cp: Array = [p_cp] if cmd.payload.get("truque", false) else Area.quadrado(p_cp, Area.quadrados(9.0))
				if not tiles_cp.any(func(t): return world.db.is_vegetation(t)):
					return PackedStringArray(["Controlar Plantas precisa de vegetação"])
		"consagrar", "profanar":
			if SpellRules.simbolo_impede(world.db, _tile_jogador(), Area.quadrados(9.0), str(sh.devotion)):
				return PackedStringArray(["há um símbolo de outra divindade na área"])
			if apr.has(2) and int(world.player.gold) < TOTAL_PERMANENTE:
				return PackedStringArray(["faltam incenso e óleos (T$ %d)" % TOTAL_PERMANENTE])
	return PackedStringArray()


## Controlar Madeira fora de combate: objetos e paredes de madeira, o equipamento do próprio conjurador, ou a forma de árvore.
func _controlar_madeira(payload: Dictionary, sh: CharacterSheet) -> Array:
	var out: Array = []
	var dia := world.day_index()
	if (payload.get("aprimoramentos", []) as Array).has(0):
		sh.add_efeito("magia.controlar_madeira_arvore", "arvore", 1, "dia", "", dia + 1)
		sh.add_efeito("magia.controlar_madeira_arvore", "sobrevivencia_disfarce", 30, "dia", "", dia + 1)
		out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "arvore", "tags": ["magia"]}, ["player"]))
		return out
	var ef := str(payload.get("efeito", ""))
	var objs = world.module("objects")
	match str(payload.get("alvo", "")):
		"objeto":
			var oid := str(payload.get("object_id", ""))
			match ef:
				"fortalecer": out.append_array(objs.fortalecer(oid, dia + 1))
				"retorcer": out.append_array(objs.retorcer(oid))
				_: out.append_array(objs.repelir(oid))
		"parede":
			out.append_array(objs.abrir_passagem(payload.get("tile", _tile_jogador())))
		_:
			SpellRules.aplicar_madeira_equip(world.rules, ef, str(payload.alvo), sh, "player", str(payload.get("forma", "")))
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "controlar_madeira_" + ef, "tags": ["magia"]}, ["player"]))
	return out


func execute(cmd: GameCommand) -> Array:
	_lancando_pela_projecao = bool(cmd.payload.get("pela_projecao", false))
	var out := _execute(cmd)
	_lancando_pela_projecao = false
	return out


func _execute(cmd: GameCommand) -> Array:
	var sh: CharacterSheet = world.player_sheet
	if cmd.type == "CollectMessenger":
		return _coletar_mensageiro(str(cmd.payload.get("destino", "")))
	if cmd.type == "EndProjection":
		projecao = {}
		return [fact("SPELL_ENDED", {"spell": "projetar_consciencia", "target": "player", "reason": "encerrada"}, ["player"])]
	if cmd.type == "LeaveStone":
		world.player_sheet.remove_efeito("magia.controlar_terra")
		return [fact("SPELL_ENDED", {"spell": "controlar_terra", "target": "player", "reason": "saiu"}, ["player"])]
	if cmd.type == "TreeHop":
		world.player_sheet.pm -= 1
		return _viajar_pela_arvore(cmd.payload)
	if cmd.type == "SearchRunes":
		return _procurar_runas()
	if cmd.type == "DisarmRune":
		return _desarmar_runa(str(cmd.payload.id))
	if cmd.type == "DetectMagic":
		# Misticismo, Detectar Magia (LB p.121): ação completa, CD 15; presença e intensidade em alcance curto.
		var r := Checks.skill(sh, "misticismo", 15, world.rules, world.rng, "world")
		return [fact("MAGIC_DETECTED", {"actor": "player", "check": r, "auras": auras_no_mundo(_tile_jogador(), 6, false) if r.get("success", false) else []}, ["player"])]
	if cmd.type == "ReadThoughts":
		# Compreensão: ação de movimento; NPC involuntário faz Vontade (CD da magia) para proteger os pensamentos.
		var alvo := str(cmd.payload.target)
		var ns := _ficha_npc(alvo)
		var combat_rt = world.module("combat")
		var cd_rt: int = combat_rt.spell_dc(sh, {"spell": "compreensao"}) if combat_rt != null else 10
		if Checks.skill(ns, "vontade", cd_rt, world.rules, world.rng, "world").get("success", false):
			return [fact("SPELL_MISSED", {"caster": "player", "target": alvo, "spell": "compreensao", "saved": true}, ["player", alvo])]
		return _pensamentos(alvo, false)
	var sp_id := str(cmd.payload.get("spell", ""))
	var sp := GhostPlanner.spell_rule(world.rules, sp_id)
	var custo := 0 if _duplicando else GhostPlanner.spell_cost(world.rules, sp, cmd.payload, sh)
	sh.pm -= custo
	var out: Array = [fact("SPELL_CAST", {"caster": "player", "spell": sp_id, "cost": custo, "fora_de_combate": true,
		"aprimoramentos": cmd.payload.get("aprimoramentos", [])}, ["player"])]
	if sp.has("cura"):
		# Cura em si mesmo (Curar Ferimentos e afins), na versão básica.
		var cura := Dice.maximo(str(sp.cura)) if maximiza("luz", _tile_jogador()) else int(Dice.roll(str(sp.cura), world.rng, "world").total)
		sh.pv = mini(sh.pv_max, sh.pv + cura)
		out[0].payload["pm_cost"] = custo
		out[0].payload["pm_after"] = sh.pm
		out.append(fact("HEALED", {"actor": "player", "target": "player", "amount": cura, "pv_after": sh.pv, "source": sp_id}, ["player"]))
		return out
	match sp_id:
		"silencio":
			var combat_s = world.module("combat")
			silencio_carregado = {"ate": world.clock.tick + (combat_s.TICKS_CENA if combat_s != null else 6)}
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "silencio", "tags": ["magia"]}, ["player"]))
		"aviso":
			var modo := str(cmd.payload.get("modo", "alerta"))
			var party_av = world.module("party")
			var rel = world.module("relations")
			for tg in cmd.payload.get("targets", ["player"]):
				if modo == "alerta":
					if tg == "player":
						SpellRules.aplicar_alerta(sh)
					elif party_av != null and party_av.members.has(tg):
						party_av.aplicar_na_ficha(tg, func(f: CharacterSheet): SpellRules.aplicar_alerta(f))
				var info := {"caster": "player", "target": tg, "modo": modo, "texto": str(cmd.payload.get("texto", "")).substr(0, 200)}
				if modo == "mensagem" and (cmd.payload.get("aprimoramentos", []) as Array).has(1) and rel != null and tg != "player":
					info["resposta"] = str(rel.reaction(tg, "player"))   # a resposta reflete o que o NPC sente
				if modo == "localizacao":
					info["cena"] = (cmd.payload.get("aprimoramentos", []) as Array).has(2)
				out.append(fact("WARNING_SENT", info, ["player"]))
		"compreensao":
			var apr_co: Array = cmd.payload.get("aprimoramentos", [])
			if apr_co.has(3):
				sh.add_efeito("magia.compreensao", "todos_idiomas", 1, "cena")
			else:
				var combat_co = world.module("combat")
				var cd_co: int = 10
				if combat_co != null:
					cd_co = combat_co.spell_dc(sh, cmd.payload)
				for tg in cmd.payload.get("targets", []):
					sh.add_efeito("magia.compreensao", "compreende", 1, "cena", tg)
					out.append(fact("UNDERSTANDING", {"caster": "player", "target": tg}, ["player", tg]))
					if apr_co.has(2):
						if Checks.skill(_ficha_npc(tg), "vontade", cd_co, world.rules, world.rng, "world").get("success", false):
							out.append(fact("SPELL_MISSED", {"caster": "player", "target": tg, "spell": "compreensao", "saved": true}, ["player", tg]))
						else:
							out.append_array(_pensamentos(tg, true))
		"visao_mistica":
			var apr_vm: Array = cmd.payload.get("aprimoramentos", [])
			var dur_vm := "dia" if apr_vm.has(1) else "cena"
			sh.add_efeito("magia.visao_mistica", "visao_mistica", 1, dur_vm, "", world.day_index() + 1 if apr_vm.has(1) else -1)
			if apr_vm.has(0):
				sh.add_efeito("magia.visao_mistica", "visao_escuro", 1, dur_vm, "", world.day_index() + 1 if apr_vm.has(1) else -1)
			if apr_vm.has(2):
				sh.add_efeito("magia.visao_mistica", "ve_invisivel", 1, dur_vm, "", world.day_index() + 1 if apr_vm.has(1) else -1)
			out.append(fact("MAGIC_AURAS", {"caster": "player", "auras": auras_no_mundo(_tile_jogador(), 20, true), "conjuradores": _conjuradores_aqui()}, ["player"]))
		"luz", "escuridao":
			var apr_l: Array = cmd.payload.get("aprimoramentos", [])
			var combat_l = world.module("combat")
			var cena: int = combat_l.TICKS_CENA if combat_l != null else 6
			var ate_l := world.clock.tick + cena
			if (sp_id == "luz" and apr_l.has(1)) or (sp_id == "escuridao" and apr_l.has(3)):
				ate_l = world.clock.tick + 24 * 60 / world.clock.tick_minutes
			if sp_id == "luz":
				if apr_l.has(2):
					ate_l = -1
					out.append(fact("GOLD_CHANGED", {"delta": -50, "reason": "pó de rubi"}))
				escuridao_carregada = {}   # Luz anula Escuridão
				luz_carregada = {"raio": Area.quadrados(6.0 + 3.0 * apr_l.count(0)), "ate": ate_l}
			elif apr_l.has(4):
				sh.add_efeito("magia.escuridao", "pericia_furtividade", 10, "cena")
				sh.add_efeito("magia.escuridao", "camuflagem_sombras", 1, "cena")
			else:
				luz_carregada = {}   # Escuridão anula Luz
				escuridao_carregada = {"raio": Area.quadrados(6.0 + 1.5 * apr_l.count(0)), "total": apr_l.has(1), "ate": ate_l}
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": sp_id, "tags": ["magia"]}, ["player"]))
		"criar_elementos":
			match str(cmd.payload.elemento):
				"agua":
					out.append(fact("ITEM_GAINED", {"item": "frasco_agua", "from": "criar_elementos"}, ["player"]))
				"fogo":
					carregar_luz(Area.quadrados(9.0))   # chama na palma, como uma tocha
					out.append(fact("LIGHT_LIT", {"item": "criar_elementos"}, ["player"]))
				_:
					out.append(fact("ELEMENT_CREATED", {"caster": "player", "elemento": str(cmd.payload.elemento)}, ["player"]))
		"abencoar_alimentos":
			out.append_array(abencoar(cmd.payload))
		"suporte_ambiental":
			SpellRules.aplicar_suporte(sh, world.day_index() + 1)
			var alvos_s: Array = ["player"]
			var party_s = world.module("party")
			if (cmd.payload.get("aprimoramentos", []) as Array).has(0) and party_s != null:
				for npc in party_s.members:
					if party_s.destino_de(npc) == "":
						party_s.aplicar_na_ficha(npc, func(f: CharacterSheet): SpellRules.aplicar_suporte(f, world.day_index() + 1))
						alvos_s.append(npc)
			out.append(fact("BUFF_APPLIED", {"actor": "player", "targets": alvos_s, "buff": "suporte_ambiental", "tags": ["magia"]}, ["player"]))
		"detectar_ameacas":
			ativar_detectar(cmd.payload.get("aprimoramentos", []))
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "detectar_ameacas", "tags": ["magia"]}, ["player"]))
		"acalmar_animal", "tranquilidade":
			var combat_e = world.module("combat")
			var acalmar: bool = sp_id == "acalmar_animal"
			var cd: int = combat_e.spell_dc(sh, cmd.payload)
			for tg in cmd.payload.get("targets", []):
				var ts := CharacterSheet.from_dict(combat_e.creature_state[tg].sheet)
				var hostil: bool = combat_e.atitude_fora(tg) == "hostil"
				var sv := Checks.skill(ts, "vontade", cd, world.rules, world.rng, "world", 5 if acalmar and hostil else 0)
				if sv.get("success", false):
					if not acalmar:
						combat_e.penalizar_fora(tg, -2, combat_e.TICKS_CENA)
					out.append(fact("SPELL_MISSED", {"caster": "player", "target": tg, "spell": sp_id, "saved": true}, ["player", tg]))
					continue
				combat_e.acalmar_fora(tg, "prestativo" if acalmar else "indiferente", combat_e.TICKS_CENA)
				if acalmar:
					sh.add_efeito("magia.acalmar_animal", "diplomacia_vs", 10, "cena", tg)
					sh.add_efeito("magia.acalmar_animal", "adestramento_vs", 10, "cena", tg)
				out.append(fact("BUFF_APPLIED", {"actor": "player", "target": tg, "buff": sp_id, "tags": ["magia"]}, ["player", tg]))
		"controlar_madeira":
			out.append_array(_controlar_madeira(cmd.payload, sh))
		"controlar_plantas":
			var apr_p: Array = cmd.payload.get("aprimoramentos", [])
			var p_cp := _tile_jogador()
			if cmd.payload.get("truque", false):
				out.append(fact("PLANT_ANIMATED", {"caster": "player", "tile": [p_cp.x, p_cp.y]}, ["player"]))
			elif apr_p.has(0):
				var podadas: Array = Area.quadrado(p_cp, Area.quadrados(9.0)).filter(func(t): return world.db.is_vegetation(t))
				podar(podadas)
				out.append(fact("PLANTS_PRUNED", {"tiles": podadas.size()}, ["player"]))
			else:
				out.append(falar_com_plantas(p_cp))
		"aliado_animal":
			out.append_array(aliado_animal(cmd.payload, sh))
		"projetar_consciencia":
			var combat_pc = world.module("combat")
			projecao = {"local": str(cmd.payload.get("local", "")), "npc": str(cmd.payload.get("npc", "")), "magias": (cmd.payload.get("aprimoramentos", []) as Array).has(0),
				"ate": world.clock.tick + (combat_pc.TICKS_CENA if combat_pc != null else 6)}
			out.append(fact("PROJECTION", {"caster": "player", "visao": projecao_ver()}, ["player"]))
		"controlar_terra":
			sh.add_efeito("magia.controlar_terra", "mesclado", 1, "dia", "", world.day_index() + 1)
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "controlar_terra", "efeito": "fundir", "tags": ["magia"]}, ["player"]))
		"viagem_arborea":
			var combat_va = world.module("combat")
			if not (cmd.payload.get("aprimoramentos", []) as Array).has(0):
				arborea_ate = world.clock.tick + (combat_va.TICKS_CENA if combat_va != null else 6)
			out.append_array(_viajar_pela_arvore(cmd.payload))
		"globo_da_verdade":
			out.append_array(globo_da_verdade(cmd.payload, sh))
		"missao_divina":
			out.append_array(missao_divina(cmd.payload, sh))
		"servo_divino":
			var apr_sd2: Array = cmd.payload.get("aprimoramentos", [])
			out.append(fact("GOLD_CHANGED", {"delta": -SpellRules.servo_divino_custo(apr_sd2), "reason": "pagamento ao espírito (Servo Divino)"}))
			out.append(fact("ITEM_LOST", {"item": str(cmd.payload.item), "reason": "servo_divino"}))
			mensageiros.append({"item": str(cmd.payload.item), "destino": str(cmd.payload.destino), "chega_dia": world.day_index(), "ate_dia": world.day_index() + maxi(1, SpellRules.servo_divino_dias(apr_sd2)), "fonte": "servo_divino"})
			out.append(fact("MESSENGER_SENT", {"item": str(cmd.payload.item), "destino": str(cmd.payload.destino), "fonte": "servo_divino"}, ["player"]))
		"intervencao_divina":
			out.append_array(intervencao_divina(cmd.payload, sh))
		"conceder_milagre":
			var tg_cm := str(cmd.payload.target)
			var ficha_cm := CharacterSheet.from_dict(world.module("party").members[tg_cm].sheet)
			ficha_cm.add_efeito("magia.conceder_milagre", "milagre", 1, "permanente", str(cmd.payload.magia), -1, "player")
			sh.add_efeito("milagre." + tg_cm, "pm_max", -6 if (cmd.payload.get("aprimoramentos", []) as Array).has(0) else -3, "permanente")
			out.append(fact("COMPANION_STATE", {"npc": tg_cm, "sheet": ficha_cm.to_dict()}, [tg_cm]))
			out.append(fact("BUFF_APPLIED", {"actor": "player", "target": tg_cm, "buff": "conceder_milagre", "magia": str(cmd.payload.magia), "tags": ["magia"]}, ["player", tg_cm]))
		"runa_de_protecao":
			out.append_array(runa_de_protecao(cmd.payload, sh))
		"comunhao_com_a_natureza":
			out.append_array(comunhao_com_a_natureza(cmd.payload, sh))
		"despertar_consciencia":
			out.append_array(despertar_consciencia(cmd.payload))
		"servo_morto_vivo":
			out.append_array(servo_morto_vivo(cmd.payload))
		"videncia":
			out.append_array(lancar_videncia(str(cmd.payload.alvo), sh))
		"lendas_e_historias":
			out.append_array(lendas_e_historias(cmd.payload))
		"controlar_o_clima":
			if str(cmd.payload.clima) == "tempestade" and desastre_impedido(_tile_jogador()):
				out.append(fact("SPELL_MISSED", {"caster": "player", "spell": "controlar_o_clima", "reason": "povoado protegido pelos deuses"}, ["player"]))
				return out
			var clima_cc: WeatherModule = world.module("weather")
			var horas_cc := int(Dice.roll("4d12", world.rng, "world").total)
			var antes_cc: String = clima_cc.forcar(str(cmd.payload.clima), horas_cc)
			out.append(fact("WEATHER_CHANGED", {"from": antes_cc, "to": clima_cc.region.condition, "temp_c": clima_cc.region.temp_c, "surface": clima_cc.region.surface, "horas": horas_cc}, ["player"]))
		"augurio":
			out.append_array(augurio(cmd.payload))
		"circulo_da_justica":
			var apr_cj: Array = cmd.payload.get("aprimoramentos", [])
			if apr_cj.has(0):
				sh.add_efeito("magia.circulo_da_justica", "ve_invisivel", 1, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "circulo_da_justica", "tags": ["magia"]}, ["player"]))
			else:
				if apr_cj.has(2):
					out.append(fact("GOLD_CHANGED", {"delta": -BALANCA_DE_PRATA, "reason": sp_id}))
				var combat_cj = world.module("combat")
				var cd_cj: int = 10
				if combat_cj != null:
					cd_cj = combat_cj.spell_dc(sh, cmd.payload)
				criar_justica(_tile_jogador(), cd_cj, apr_cj)
				out.append(fact("AREA_BLESSED", {"caster": "player", "spell": sp_id, "permanente": apr_cj.has(2)}, ["player"]))
		"condicao":
			var apr_cd: Array = cmd.payload.get("aprimoramentos", [])
			for tg in cmd.payload.get("targets", []):
				sh.add_efeito("magia.condicao", "condicao", 1, "dia" if apr_cd.has(1) else "cena", str(tg), world.day_index() + 1 if apr_cd.has(1) else -1)
			out.append(fact("CREATURE_STATUS", {"caster": "player", "status": status_acompanhados()}, ["player"]))
		"voz_divina":
			var apr_vd: Array = cmd.payload.get("aprimoramentos", [])
			if apr_vd.has(0):
				out.append_array(interrogar_cadaver(str(cmd.payload.get("target", ""))))
			else:
				sh.add_efeito("magia.voz_divina", "voz_divina", 1, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "voz_divina", "tags": ["magia"]}, ["player"]))
				if apr_vd.has(1):
					out.append(falar_com_plantas(_tile_jogador(), true))
		"caminhos_da_natureza":
			var truque: bool = cmd.payload.get("truque", false)
			var apr_c: Array = cmd.payload.get("aprimoramentos", [])
			SpellRules.aplicar_caminhos(sh, apr_c, truque, world.day_index() + 1)
			var alvos: Array = ["player"]
			var party = world.module("party")
			if not truque and party != null:
				for npc in party.members:
					if party.destino_de(npc) == "":
						party.aplicar_na_ficha(npc, func(f: CharacterSheet): SpellRules.aplicar_caminhos(f, apr_c, false, world.day_index() + 1))
						alvos.append(npc)
			out.append(fact("BUFF_APPLIED", {"actor": "player", "targets": alvos, "buff": "caminhos_da_natureza", "tags": ["magia"]}, ["player"]))
		"despedacar":
			var objs_m = world.module("objects")
			var dano := 2 * int(Dice.roll(SpellRules.despedacar_dano(cmd.payload.get("aprimoramentos", [])), world.rng, "world").total)
			out.append_array(objs_m.danificar(str(cmd.payload.objeto), dano, true, "despedacar"))
		"consagrar", "profanar":
			var apr_a: Array = cmd.payload.get("aprimoramentos", [])
			if apr_a.has(2):
				# Versão permanente (Requer 4º círculo): execução de 1 hora e T$ 1.000 em incenso e óleos.
				out.append(fact("GOLD_CHANGED", {"delta": -TOTAL_PERMANENTE, "reason": sp_id}))
				out.append_array(world.advance_ticks(60 / world.clock.tick_minutes))
			criar_area(sp_id, _tile_jogador(), apr_a, sh, "player")
			out.append(fact("AREA_BLESSED", {"caster": "player", "spell": sp_id, "permanente": apr_a.has(2)}, ["player"]))
		"bencao":
			var alvo := str(cmd.payload.get("target", ""))
			preservar_cadaver(alvo, DIAS_SEMANA)
			out.append(fact("CORPSE_PRESERVED", {"caster": "player", "target": alvo, "ate_dia": int(cadaveres[alvo])}, ["player"]))
	return out


## Bênção sobre cadáver (+1 PM): não se decompõe nem pode virar morto-vivo por `dias` dias a partir de hoje.
func preservar_cadaver(id: String, dias: int) -> void:
	cadaveres[id] = maxi(int(cadaveres.get(id, -1)), world.day_index() + dias - 1)


## Consagrar / Profanar: esfera de 9m de raio por 1 dia (permanente com o aprimoramento de 9 PM). Uma anula a
## outra: as áreas opostas que se sobrepõem à nova somem. Aprimoramento de 1 PM: mortos-vivos na área sofrem –2
## (Consagrar) ou recebem +2 (Profanar) em Defesa e testes; +1 por aprimoramento de 2 PM, repetível.
func criar_area(tipo: String, centro: Vector2i, apr: Array, sh: CharacterSheet, conj: String) -> void:
	var raio := Area.quadrados(9.0)
	var mantidas: Array = []
	for ar in areas:
		if not (str(ar.tipo) == str(OPOSTA[tipo]) and _dist(ar, centro) <= int(ar.raio) + raio):
			mantidas.append(ar)
	areas = mantidas
	var mod := 0
	if apr.has(0):
		# Limite do aumento: o círculo máximo (interpretação: o –2/+2 básico não conta para o limite abaixo de 2).
		mod = mini(2 + apr.count(1), maxi(2, SpellRules.circulo_maximo(sh, world.rules)))
		if tipo == "consagrar":
			mod = -mod
	areas.append({"tipo": tipo, "centro": [centro.x, centro.y], "raio": raio, "ate": -1 if apr.has(2) else world.clock.total_minutes() + MINUTOS_DIA,
		"mod_mv": mod, "conjurador": conj})


## Aliado Animal (divina 2): vínculo com 1 animal prestativo em alcance curto por 1 dia. Ele vira um parceiro veterano
## (mestre com o aprimoramento do 3º círculo; 2 animais de tipos diferentes no 4º) de um tipo à escolha: ajudante,
## combatente, fortão, guardião, montaria ou perseguidor. Aprimoramento de 1 PM: animal Minúsculo por 1 semana leva um
## item a um local; espera lá e só entrega a quem o conjurador escolher.
const TIPOS_ALIADO := ["ajudante", "combatente", "fortao", "guardiao", "montaria", "perseguidor"]


func _tipo_do_animal(p: Dictionary, i: int) -> String:
	if p.has("parceiro_tipos"):
		return str((p.parceiro_tipos as Array)[i])
	return str(p.get("parceiro_tipo", ""))


func validar_aliado_animal(p: Dictionary, sh: CharacterSheet) -> String:
	var apr: Array = p.get("aprimoramentos", [])
	if apr.has(0):
		if apr.size() > 1: return "o mensageiro não se combina com outros aprimoramentos"
		var st = world.module("state")
		if st == null or not st.has_item(str(p.get("item", ""))): return "você não tem esse item"
		if not _local_existe(str(p.get("destino", ""))): return "escolha o local de destino"
	var animais: Array = p.get("targets", [p.get("target", "")])
	if animais.size() != (2 if apr.has(2) else 1): return "escolha %d animal(is)" % (2 if apr.has(2) else 1)
	var combat = world.module("combat")
	var tipos_vistos: Array = []
	for i in animais.size():
		var id := str(animais[i])
		if combat == null or not combat.creature_state.has(id) or not bool(combat.creature_state[id].get("alive", false)):
			return "escolha um animal vivo"
		var f := CharacterSheet.from_dict(combat.creature_state[id].sheet)
		if f.creature_type != "animal": return "o alvo precisa ser um animal"
		if apr.has(0) and f.size != "minusculo": return "o mensageiro é um animal Minúsculo"
		if combat.atitude_fora(id) != "prestativo": return "o animal precisa ser prestativo"
		var t: Vector2i = combat.creature_tile(id)
		var p_j := _tile_jogador()
		if maxi(absi(p_j.x - t.x), absi(p_j.y - t.y)) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)): return "animal fora do alcance"
		if not apr.has(0):
			var tipo := _tipo_do_animal(p, i)
			if not TIPOS_ALIADO.has(tipo) or tipos_vistos.has(tipo): return "escolha tipos de parceiro diferentes: " + ", ".join(TIPOS_ALIADO)
			tipos_vistos.append(tipo)
	return ""


func aliado_animal(p: Dictionary, sh: CharacterSheet) -> Array:
	var out: Array = []
	var apr: Array = p.get("aprimoramentos", [])
	var party = world.module("party")
	if apr.has(0):
		out.append(fact("ITEM_LOST", {"item": str(p.item), "reason": "aliado_animal"}))
		mensageiros.append({"item": str(p.item), "destino": str(p.destino), "chega_dia": world.day_index() + 1, "ate_dia": world.day_index() + DIAS_SEMANA})
		out.append(fact("MESSENGER_SENT", {"item": str(p.item), "destino": str(p.destino)}, ["player"]))
		return out
	var animais: Array = p.get("targets", [p.get("target", "")])
	for i in animais.size():
		var tipo := _tipo_do_animal(p, i)
		var novo := {"id": "aliado_animal_%s" % str(animais[i]), "tipo": tipo, "nivel": "mestre" if apr.has(1) else "veterano", "nome": str(animais[i]),
			"especie": str(animais[i]), "fonte": "aliado_animal", "ate_dia": world.day_index() + 1}
		if tipo == "ajudante":
			novo["pericias"] = (p.get("pericias", []) as Array).duplicate()
		var err: String = party.adicionar_parceiro(novo) if party != null else "sem módulo de parceiros"
		out.append(fact("PARTNER_JOINED" if err == "" else "SPELL_MISSED", {"partner": novo.id, "tipo": tipo, "nivel": novo.nivel, "reason": err}, ["player"]))
	return out


## Mensageiro de Aliado Animal: no local de destino, o jogador recebe o item.
func _coletar_mensageiro(destino: String) -> Array:
	var out: Array = []
	for m in mensageiros.duplicate(true):
		if str(m.destino) == destino and world.day_index() >= int(m.chega_dia) and world.day_index() <= int(m.ate_dia):
			mensageiros.erase(m)
			out.append(fact("ITEM_GAINED", {"item": str(m.item), "from": "aliado_animal"}))
	return out


## Augúrio (divina 2): o assunto é um lugar do mapa ("local") — a ação de entrar nele e explorá-lo em breve.
## Com o aprimoramento de 7 PM (4º), "perguntas": lista de {tipo: ameaca|tesouro|armadilha, local} de sim ou não.
func validar_augurio(payload: Dictionary) -> String:
	var apr: Array = payload.get("aprimoramentos", [])
	if apr.has(0) and apr.has(1):
		return "escolha uma forma de consulta"
	if apr.has(1):
		var perguntas: Array = payload.get("perguntas", [])
		if perguntas.is_empty() or perguntas.size() > 10:
			return "de 1 a 10 perguntas (uma por rodada, por 1 minuto)"
		for q in perguntas:
			if not ["ameaca", "tesouro", "armadilha"].has(str(q.get("tipo", ""))) or not _local_existe(str(q.get("local", ""))):
				return "pergunta inválida"
		return ""
	if not _local_existe(str(payload.get("local", ""))):
		return "escolha o lugar da ação"
	return ""


func _local_existe(loc: String) -> bool:
	return world.db.all_locations().any(func(l): return str(l.id) == loc)


## Chance de falha do Augúrio: 1 em 1d6 (1d12 e 1d20 com aprimoramentos). O resultado do dado é secreto.
func _augurio_funciona(apr: Array) -> bool:
	var dado := "1d20" if apr.has(3) else ("1d12" if apr.has(2) else "1d6")
	return int(Dice.roll(dado, world.rng, "world").total) > 1


## O que aguarda quem entra no lugar: miséria (criatura hostil ativa ou armadilha armada), felicidade (baú com
## conteúdo ainda fechado ou pista ainda não descoberta).
func _presagio(loc: String) -> Dictionary:
	return {"miseria": _ha_ameaca(loc) or _ha_armadilha(loc), "felicidade": _ha_tesouro(loc)}


func _ha_ameaca(loc: String) -> bool:
	var combat = world.module("combat")
	if combat == null:
		return false
	for id in combat.creature_state:
		if combat.is_active_creature(id) and world.db.location_at(combat.creature_tile(id)) == loc and Atitudes.agressiva(combat.atitude_fora(id)):
			return true
	return false


func _ha_armadilha(loc: String) -> bool:
	var ex = world.module("exploration")
	for t in world.db.all_targets():
		var tl: Array = t.get("tile", [0, 0])
		if ex != null and ex.armada(t) and world.db.location_at(Vector2i(int(tl[0]), int(tl[1]))) == loc:
			return true
	return false


func _ha_tesouro(loc: String) -> bool:
	var objs = world.module("objects")
	var ex = world.module("exploration")
	for o in world.db.all_objects():
		var ot: Array = o.get("tile", [0, 0])
		if str(o.type) == "chest" and world.db.location_at(Vector2i(int(ot[0]), int(ot[1]))) == loc and objs != null and not (objs.obj(str(o.id)).get("contents", []) as Array).is_empty():
			return true
	for t in world.db.all_targets():
		var tl: Array = t.get("tile", [0, 0])
		if world.db.location_at(Vector2i(int(tl[0]), int(tl[1]))) != loc:
			continue
		for act in (t.get("actions", {}) as Dictionary).values():
			for f in act.get("reveals", []):
				if ex == null or not ex.knows(str(f)):
					return true
	return false


## Projetar Consciência: onde a projeção está ("" se não há): o lugar escolhido ou onde o NPC está agora.
func projecao_local() -> String:
	if projecao.is_empty() or world.clock.tick >= int(projecao.ate):
		return ""
	if str(projecao.npc) != "":
		var npcs = world.module("npcs")
		return str(npcs.npc(str(projecao.npc)).get("location", "")) if npcs != null else ""
	return str(projecao.local)


## A projeção vê este NPC (está no mesmo lugar dela)?
func projecao_ve(npc: String) -> bool:
	var lugar := projecao_local()
	var npcs = world.module("npcs")
	return lugar != "" and npcs != null and str(npcs.npc(npc).get("location", "")) == lugar


## O que a projeção vê agora: quem está no lugar e os objetos dele.
func projecao_ver() -> Dictionary:
	var lugar := projecao_local()
	if lugar == "":
		return {}
	var npcs = world.module("npcs")
	var presentes: Array = []
	for n in world.db.all_npc_ids():
		if npcs != null and str(npcs.npc(n).get("location", "")) == lugar and bool(npcs.npc(n).get("alive", true)):
			presentes.append(n)
	var objs: Array = world.db.all_objects().filter(func(o): return world.db.location_at(Vector2i(int(o.tile[0]), int(o.tile[1]))) == lugar).map(func(o): return o.id)
	return {"lugar": lugar, "presentes": presentes, "objetos": objs}


## Lugar conhecido: já esteve nele (a exploração guarda os lugares visitados) ou é o lugar atual.
func _visitado(loc: String) -> bool:
	return loc == world.db.location_at(_tile_jogador()) or visitados.has(loc)


## Viagem Arbórea fora de combate: árvore ao seu lado e destino "arvore" (qualquer árvore do mapa, que está toda a menos
## de 1km; com o aprimoramento, o grupo vai junto, e 100km cobrem o mapa inteiro).
func _valida_arvores(p: Dictionary) -> PackedStringArray:
	if not SpellRules.arvore_ao_lado(world.db, _tile_jogador()):
		return PackedStringArray(["é preciso uma árvore ao seu lado"])
	var arv: Vector2i = _vec(p.get("arvore", [-1, -1]))
	if world.db.tile_char(arv) != "T":
		return PackedStringArray(["escolha a árvore de destino"])
	if SpellRules.saida_da_arvore(world.db, arv, func(_x): return false) == Vector2i(-1, -1):
		return PackedStringArray(["não há espaço livre junto dessa árvore"])
	return PackedStringArray()


func _vec(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	return Vector2i(int(v[0]), int(v[1]))


func _viajar_pela_arvore(p: Dictionary) -> Array:
	var saida := SpellRules.saida_da_arvore(world.db, _vec(p.arvore), func(_x): return false)
	world.player.position = world.db.tile_to_world(saida)
	return [fact("PLAYER_TELEPORTED", {"to": [saida.x, saida.y], "spell": "viagem_arborea"}, ["player"])] + ao_mover()


## Globo da Verdade de Gwen (divina 2): mostra o que você (a crônica) ou o NPC tocado (as memórias de quem viu) viu sobre
## a pergunta, até uma semana atrás (um mês, um ano). O NPC vivo faz Vontade para anular. Cadáver: a última cena vista.
## Com 10 globos em alcance longo, quem está no lugar também vê a cena (ganha a lembrança).
func globo_da_verdade(p: Dictionary, sh: CharacterSheet) -> Array:
	var apr: Array = p.get("aprimoramentos", [])
	var alvo := str(p.get("target", "player"))
	var pergunta := str(p.pergunta).to_lower()
	var por_dia := 24 * 60 / world.clock.tick_minutes
	var janela := por_dia * (365 if apr.has(1) else (30 if apr.has(0) else 7))
	var desde := world.clock.tick - janela
	var cenas: Array = []
	var npcs = world.module("npcs")
	var morto: bool = alvo != "player" and npcs != null and not bool(npcs.npc(alvo).get("alive", true))
	if alvo == "player":
		var cr = world.module("chronicle")
		for en in (cr.entries if cr != null else []):
			if int(en.tick) >= desde and str(en.text).to_lower().contains(pergunta):
				cenas.append({"tick": int(en.tick), "texto": str(en.text)})
	else:
		var combat = world.module("combat")
		var cd: int = combat.spell_dc(sh, {"spell": "globo_da_verdade"}) if combat != null else 15
		if not morto and Checks.skill(_ficha_npc(alvo), "vontade", cd, world.rules, world.rng, "world").get("success", false):
			return [fact("SPELL_MISSED", {"caster": "player", "target": alvo, "spell": "globo_da_verdade", "reason": "resistiu"}, ["player"])]
		var mem = world.module("memory")
		var lista: Array = mem.list(alvo) if mem != null else []
		for m in lista:
			if str(m.get("source", "")) == "boato":
				continue
			var bate := pergunta in str(m.get("text", "")).to_lower() or pergunta == str(m.get("about", "")) or pergunta == str(m.get("subject", "")) or pergunta == str(m.get("location", ""))
			if (morto or int(m.get("tick", 0)) >= desde) and bate:
				cenas.append({"tick": int(m.get("tick", 0)), "texto": str(m.get("text", "")), "lugar": str(m.get("location", ""))})
		if morto and not cenas.is_empty():
			cenas.sort_custom(func(x, y): return int(x.tick) > int(y.tick))
			cenas = [cenas[0]]   # a última cena vista
	var out: Array = [fact("TRUTH_GLOBE", {"caster": "player", "target": alvo, "pergunta": pergunta, "cenas": cenas, "globos": 10 if apr.has(3) else 1}, ["player"])]
	if apr.has(3) and npcs != null and not cenas.is_empty():
		var mem2 = world.module("memory")
		var lugar := world.db.location_at(_tile_jogador())
		for n in world.db.all_npc_ids():
			if n != alvo and str(npcs.npc(n).get("location", "")) == lugar and mem2 != null:
				mem2.add_memory(n, {"key": "globo:%s:%d" % [pergunta, int(cenas[0].tick)], "about": alvo, "subject": "", "valence": 0, "location": lugar,
					"tick": world.clock.tick, "emotion": "surpresa", "reliability": 1.0, "source": "visto", "durable": false, "text": "Vi no globo: " + str(cenas[0].texto)})
	return out


## Missão Divina (divina 3): o NPC faz Vontade (anula). Falhou: deve ir ao destino em até uma semana (um ano com o
## aprimoramento). Quem tem má reputação com o jogador recusa e, a cada fim de dia, faz Vontade ou sofre –2 cumulativo em
## todos os testes e rolagens (`penalidade_missao`, aplicado na ficha do NPC). Quem aceita vai até lá e a missão se cumpre.
## Marca (aprimoramento; toque, permanente, –1 PM do conjurador): a cada crime do marcado, –2 cumulativo.
func missao_divina(p: Dictionary, sh: CharacterSheet) -> Array:
	var apr: Array = p.get("aprimoramentos", [])
	var alvo := str(p.target)
	var combat = world.module("combat")
	var cd: int = combat.spell_dc(sh, {"spell": "missao_divina"}) if combat != null else 15
	if not apr.has(0) and Checks.skill(_ficha_npc(alvo), "vontade", cd, world.rules, world.rng, "world").get("success", false):
		return [fact("SPELL_MISSED", {"caster": "player", "target": alvo, "spell": "missao_divina", "reason": "resistiu"}, ["player"])]
	var mem = world.module("memory")
	var recusa: bool = mem != null and mem.reputation(alvo) < 0.0
	if apr.has(0):
		missoes[alvo] = {"marca": true, "gatilho": "crime", "penalidade": 0, "cd": cd, "ate_dia": -1, "recusou": true, "destino": ""}
		sh.add_efeito("missao." + alvo, "pm_max", -1, "permanente")
	else:
		missoes[alvo] = {"marca": false, "destino": str(p.destino), "ate_dia": world.day_index() + (365 if apr.has(1) else DIAS_SEMANA), "recusou": recusa, "penalidade": 0, "cd": cd}
	return [fact("BUFF_APPLIED", {"actor": "player", "target": alvo, "buff": "missao_divina", "recusou": recusa, "marca": apr.has(0), "tags": ["magia"]}, ["player", alvo])]


## Para onde o NPC vai por causa de uma Missão Divina aceita ("" se nenhuma).
func missao_destino(npc: String) -> String:
	var m: Dictionary = missoes.get(npc, {})
	if m.is_empty() or bool(m.recusou) or bool(m.get("marca", false)):
		return ""
	return str(m.destino)


func penalidade_missao(npc: String) -> int:
	return int((missoes.get(npc, {}) as Dictionary).get("penalidade", 0))


func on_tick(_tick: int) -> Array:
	var out: Array = []
	var npcs = world.module("npcs")
	for npc in missoes.keys():
		var m: Dictionary = missoes[npc]
		if not bool(m.get("marca", false)) and not bool(m.recusou) and npcs != null and str(npcs.npc(npc).get("location", "")) == str(m.destino):
			missoes.erase(npc)
			out.append(fact("QUEST_FULFILLED", {"npc": npc, "spell": "missao_divina", "destino": str(m.destino)}, [npc]))
	if world.day_index() != _dia_missoes:
		_dia_missoes = world.day_index()
		for npc in missoes.keys():
			var m2: Dictionary = missoes[npc]
			if not bool(m2.get("marca", false)) and int(m2.ate_dia) >= 0 and world.day_index() > int(m2.ate_dia):
				missoes.erase(npc)
				continue
			if bool(m2.recusou) and not bool(m2.get("marca", false)) and not Checks.skill(_ficha_npc(npc), "vontade", int(m2.cd), world.rules, world.rng, "world").get("success", false):
				m2.penalidade = int(m2.penalidade) + 2
				out.append(fact("QUEST_PENALTY", {"npc": npc, "penalidade": int(m2.penalidade)}, [npc]))
	return out


## Marca da Missão Divina: cada crime do marcado soma –2.
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["CRIME_COMMITTED"])


func on_event(e: GameEvent) -> Array:
	var quem := str(e.payload.get("actor", ""))
	var m: Dictionary = missoes.get(quem, {})
	if e.event_type == "CRIME_COMMITTED" and bool(m.get("marca", false)):
		m.penalidade = int(m.penalidade) + 2
		return [fact("QUEST_PENALTY", {"npc": quem, "penalidade": int(m.penalidade), "marca": true}, [quem])]
	return []


## Intervenção Divina fora de combate. Curar: o jogador e os companheiros, todos os PV e condições. Com o sacrifício de
## 2 PM (–2 PM máximos para sempre): criar um item mundano de até T$ 30.000, duplicar uma magia de até 4º círculo (sem PM)
## ou proteger o povoado da zona atual de um desastre (o próximo Terremoto ou tempestade de Controlar o Clima ali não vinga).
func intervencao_divina(p: Dictionary, sh: CharacterSheet) -> Array:
	var out: Array = []
	var op := str(p.opcao)
	if SpellRules.INTERVENCAO_SACRIFICIO.has(op):
		sh.add_efeito("sacrificio.intervencao_%d" % world.clock.tick, "pm_max", -2, "permanente")
	match op:
		"curar":
			sh.pv = maxi(sh.pv, sh.pv_max)
			for cond in Array(sh.conditions):
				sh.remove_condition(str(cond))
			var party = world.module("party")
			if party != null:
				for mid in party.members:
					var f := CharacterSheet.from_dict(party.members[mid].sheet)
					f.pv = maxi(f.pv, f.pv_max)
					for cond2 in Array(f.conditions):
						f.remove_condition(str(cond2))
					out.append(fact("COMPANION_STATE", {"npc": mid, "sheet": f.to_dict()}, [mid]))
		"item":
			out.append(fact("ITEM_GAINED", {"item": str(p.item), "from": "intervencao_divina"}, ["player"]))
		"duplicar":
			var sub := GameCommand.create("intervencao", "player", "CastSpell", (p.acao as Dictionary).duplicate(true))
			_duplicando = true
			out.append_array(execute(sub))
			_duplicando = false
		"proteger":
			cidade_protegida = {"zona": world.db.zone_at(_tile_jogador())}
	out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "intervencao_divina", "opcao": op, "tags": ["magia"]}, ["player"]))
	return out


## Proteção de Intervenção Divina: o desastre (Terremoto, tempestade) que cairia nesta zona não vinga; gasta a proteção.
func desastre_impedido(t: Vector2i) -> bool:
	if not cidade_protegida.is_empty() and str(cidade_protegida.zona) == world.db.zone_at(t):
		cidade_protegida = {}
		return true
	return false


## Runa de Proteção (universal 2). No chão: 1 hora e T$ 200; esfera de 6m; quem entra dispara 6d6 (+2d6) do tipo escolhido.
## Pode valer só para um tipo de criatura ou raça ("gatilho") e ter palavra mágica (o conjurador não a dispara).
## No corpo (aprimoramentos): a magia escolhida é lançada como reação quando a condição acontece (CombatModule._runa_corporal).
func runa_de_protecao(p: Dictionary, sh: CharacterSheet) -> Array:
	var apr: Array = p.get("aprimoramentos", [])
	var out: Array = [fact("GOLD_CHANGED", {"delta": -200, "reason": "pó de diamante (Runa de Proteção)"})]
	var combat = world.module("combat")
	var cd: int = combat.spell_dc(sh, {"spell": "runa_de_protecao"}) if combat != null else 15
	if apr.has(1) or apr.has(2):
		sh.remove_efeito("magia.runa_de_protecao")   # uma runa no corpo de cada vez
		sh.add_efeito("magia.runa_de_protecao", "runa_corporal", 1, "permanente", str(p.magia))
		sh.add_efeito("magia.runa_de_protecao", "runa_gatilho", 1, "permanente", str(p.gatilho))
		out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "runa_de_protecao", "magia": str(p.magia), "gatilho": str(p.gatilho), "tags": ["magia"]}, ["player"]))
		return out
	out.append_array(world.advance_ticks(60 / world.clock.tick_minutes))
	var t := _tile_jogador()
	var nova := {"id": "runa_%d" % (runas.size() + world.clock.tick), "centro": [t.x, t.y], "raio": Area.quadrados(6.0), "tipo": str(p.tipo_energia),
		"dados": "%dd6" % (6 + 2 * apr.count(0)), "gatilho": str(p.get("gatilho", "")), "palavra": bool(p.get("palavra", false)), "cd": cd, "conj": "player",
		"dentro": true, "achada": false}
	runas.append(nova)
	out.append(fact("RUNE_PLACED", {"rune": nova.id, "tile": [t.x, t.y], "tipo": nova.tipo}, ["player"]))
	return out


func _runa(id: String) -> Dictionary:
	for r in runas:
		if str(r.id) == id:
			return r
	return {}


## A runa dispara para esta criatura? Gatilho vazio: qualquer uma; senão, o tipo ou a raça. Com palavra mágica, o
## conjurador passa sem dispará-la.
func _runa_dispara(r: Dictionary, tipo: String, raca: String, eh_jogador: bool) -> bool:
	if bool(r.palavra) and eh_jogador and str(r.conj) == "player":
		return false
	var g := str(r.gatilho)
	return g == "" or g == tipo or g == raca


## Combate: a criatura foi de `de` a `para`; se entrou na área de uma runa que dispara para ela, a runa se descarrega.
func runa_disparada(de: Vector2i, para: Vector2i, tipo: String, raca: String, eh_jogador: bool) -> Dictionary:
	for r in runas.duplicate(true):
		if _dist(r, para) <= int(r.raio) and _dist(r, de) > int(r.raio) and _runa_dispara(r, tipo, raca, eh_jogador):
			runas = runas.filter(func(x): return str(x.id) != str(r.id))
			return r
	return {}


## Exploração: o jogador entrou na área de uma runa. Quem dispara não resiste; criaturas do mundo na área fazem Reflexos.
func _runas_ao_mover(t: Vector2i) -> Array:
	var out: Array = []
	var sh: CharacterSheet = world.player_sheet
	for r in runas.duplicate(true):
		var dentro: bool = _dist(r, t) <= int(r.raio)
		if dentro and not bool(r.dentro) and _runa_dispara(r, sh.creature_type, sh.race_id, true):
			runas = runas.filter(func(x): return str(x.id) != str(r.id))
			var dano := sh.dano_por_tipo(str(r.tipo), int(Dice.roll(str(r.dados), world.rng, "world").total))
			sh.pv -= dano
			out.append(fact("RUNE_EXPLODED", {"rune": str(r.id), "trigger": "player", "damage": dano, "pv_after": sh.pv, "tipo": str(r.tipo)}, ["player"]))
			var combat = world.module("combat")
			if combat != null:
				for cid in combat.creature_state:
					if bool(combat.creature_state[cid].get("alive", false)) and _dist(r, combat.creature_tile(cid)) <= int(r.raio):
						var fc := CharacterSheet.from_dict(combat.creature_state[cid].sheet)
						var d_c := fc.dano_por_tipo(str(r.tipo), int(Dice.roll(str(r.dados), world.rng, "world").total))
						if Checks.skill(fc, "reflexos", int(r.cd), world.rules, world.rng, "world").get("success", false):
							d_c = d_c / 2
						combat.ferir_fora(cid, d_c)
			continue
		for x in runas:
			if str(x.id) == str(r.id):
				x.dentro = dentro
	return out


## Investigação contra a CD de cada runa que não é sua, a até alcance curto. Achada, pode ser desarmada.
func _procurar_runas() -> Array:
	var achadas: Array = []
	for r in runas:
		if str(r.conj) == "player" or bool(r.achada) or _dist(r, _tile_jogador()) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)):
			continue
		if Checks.skill(world.player_sheet, "investigacao", int(r.cd), world.rules, world.rng, "world").get("success", false):
			r.achada = true
			achadas.append(str(r.id))
	return [fact("RUNES_FOUND", {"runas": achadas}, ["player"])]


## Ladinagem contra a CD da runa: passou, ela se desfaz.
func _desarmar_runa(id: String) -> Array:
	var r := _runa(id)
	if Checks.skill(world.player_sheet, "ladinagem", int(r.cd), world.rules, world.rng, "world").get("success", false):
		runas = runas.filter(func(x): return str(x.id) != id)
		return [fact("RUNE_DISARMED", {"rune": id}, ["player"])]
	return [fact("RUNE_DISARM_FAILED", {"rune": id}, ["player"])]


## Comunhão com a Natureza: 6d4 dados de auxílio pelo dia (+2 por aprimoramento; d6 ou d8), gastos 2 por vez (+2 por
## círculo acima do 3º) em testes em área natural (Checks._auxilio_natural). Com o aprimoramento de 1 minuto, em vez disso,
## 1d4+1 informações sobre a região: terreno, animais, vegetais, minerais, cursos d'água e criaturas antinaturais.
func comunhao_com_a_natureza(p: Dictionary, sh: CharacterSheet) -> Array:
	var apr: Array = p.get("aprimoramentos", [])
	if apr.has(0):
		var out: Array = world.advance_ticks(maxi(1, 1 / world.clock.tick_minutes))
		var temas: Array = _temas_da_natureza()
		var n := mini(temas.size(), int(Dice.roll("1d4+1", world.rng, "world").total))
		var escolhidos: Array = []
		while escolhidos.size() < n:
			var t: Dictionary = temas[world.rng.stream("world").randi() % temas.size()]
			if not escolhidos.has(t):
				escolhidos.append(t)
		out.append(fact("NATURE_INFO", {"caster": "player", "zona": world.db.zone_at(_tile_jogador()), "informacoes": escolhidos}, ["player"]))
		return out
	var lado := 8 if apr.has(3) else (6 if apr.has(2) else 4)
	var gasto := 2 + 2 * maxi(0, SpellRules.circulo_maximo(sh, world.rules) - 3)
	sh.add_efeito("magia.comunhao_com_a_natureza", "auxilio_dados", 6 + 2 * apr.count(1), "dia", str(lado), world.day_index() + 1)
	sh.add_efeito("magia.comunhao_com_a_natureza", "auxilio_gasto", gasto, "dia", "", world.day_index() + 1)
	ao_mover()
	return [fact("BUFF_APPLIED", {"actor": "player", "target": "player", "buff": "comunhao_com_a_natureza", "dados": 6 + 2 * apr.count(1), "lado": lado, "tags": ["magia"]}, ["player"])]


## Informações da zona natural onde o jogador está (Comunhão com a Natureza, aprimoramento).
func _temas_da_natureza() -> Array:
	var zona := world.db.zone_at(_tile_jogador())
	var agua := 0
	var veg := 0
	var duro := 0
	var dificil := 0
	for y in world.db.size.y:
		for x in world.db.size.x:
			var t := Vector2i(x, y)
			if world.db.zone_at(t) != zona:
				continue
			agua += 1 if world.db.is_water(t) else 0
			veg += 1 if world.db.is_vegetation(t) else 0
			duro += 1 if world.db.solo(t) == "duro" else 0
			dificil += 1 if world.db.is_difficult(t) or world.db.is_chasm(t) else 0
	var combat = world.module("combat")
	var animais: Array = []
	var antinaturais: Array = []
	if combat != null:
		for cid in combat.creature_state:
			var st: Dictionary = combat.creature_state[cid]
			if not bool(st.get("alive", false)):
				continue
			var tl: Array = st.get("tile", [0, 0])
			if world.db.zone_at(Vector2i(int(tl[0]), int(tl[1]))) != zona:
				continue
			var tp := str((st.get("sheet", {}) as Dictionary).get("creature_type", ""))
			if tp == "animal":
				animais.append(cid)
			elif tp in ["morto-vivo", "construto", "espirito"]:
				antinaturais.append(cid)
	return [{"tema": "terreno", "trechos_dificeis": dificil}, {"tema": "animais", "quais": animais}, {"tema": "vegetais", "trechos": veg},
		{"tema": "minerais", "solo_duro": duro}, {"tema": "cursos_dagua", "trechos": agua}, {"tema": "criaturas_antinaturais", "quais": antinaturais}]


## Chamado a cada passo do jogador (WorldState, MovePlayer): marca se ele está em área natural (Comunhão com a Natureza).
func ao_mover() -> Array:
	var sh: CharacterSheet = world.player_sheet
	if sh == null:
		return []
	var aqui := world.db.location_at(_tile_jogador())
	if aqui != "":
		visitados[aqui] = true
	sh.remove_efeito_stat("area_natural")
	if sh.efeito_bonus("auxilio_dados") > 0 and world.db.is_natural(_tile_jogador()):
		sh.add_efeito("comunhao.area", "area_natural", 1, "dia", "", world.day_index() + 1)
	return _runas_ao_mover(_tile_jogador())


## Despertar Consciência: alvo_tipo "animal" (criatura viva ao lado), "planta" (vegetação ao lado), "escultura" (objeto com
## "escultura", só com o aprimoramento) ou "parceiro" (um parceiro seu: sobe um passo de poder, uma vez; se já é mestre,
## ganha o bônus iniciante de outro tipo).
func _valida_despertar(p: Dictionary) -> String:
	var apr: Array = p.get("aprimoramentos", [])
	var tipo_alvo := str(p.get("alvo_tipo", ""))
	var alvo := str(p.get("alvo", ""))
	var pj := _tile_jogador()
	if not SpellRules.TIPOS_DESPERTAR.has(str(p.get("tipo", ""))):
		return "tipo de parceiro: " + ", ".join(PackedStringArray(SpellRules.TIPOS_DESPERTAR))
	if apr.has(0) and tipo_alvo != "escultura":
		return "com o aprimoramento, o alvo é uma escultura"
	match tipo_alvo:
		"animal":
			var combat = world.module("combat")
			if combat == null or not combat.creature_state.has(alvo) or not bool(combat.creature_state[alvo].get("alive", false)):
				return "escolha um animal vivo"
			if str((combat.creature_state[alvo].get("sheet", {}) as Dictionary).get("creature_type", "")) != "animal":
				return "o alvo precisa ser um animal"
			var t: Vector2i = combat.creature_tile(alvo)
			if maxi(absi(pj.x - t.x), absi(pj.y - t.y)) > 1:
				return "toque o animal"
		"planta":
			var ok := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					ok = ok or world.db.is_vegetation(pj + Vector2i(dx, dy))
			if not ok:
				return "não há planta ao seu lado"
		"escultura":
			if not apr.has(0):
				return "esculturas só com o aprimoramento"
			var od := world.db.object_def(alvo)
			if od.is_empty() or not bool(od.get("escultura", false)):
				return "escolha uma escultura"
			if maxi(absi(pj.x - int(od.tile[0])), absi(pj.y - int(od.tile[1]))) > 1:
				return "toque a escultura"
		"parceiro":
			var party = world.module("party")
			var par: Dictionary = party.parceiro(alvo) if party != null else {}
			if par.is_empty():
				return "parceiro desconhecido"
			if bool(par.get("despertado", false)):
				return "esse parceiro já foi despertado"
		_:
			return "alvo_tipo: animal, planta, escultura ou parceiro"
	return ""


func despertar_consciencia(p: Dictionary) -> Array:
	var apr: Array = p.get("aprimoramentos", [])
	var party = world.module("party")
	var tipo := str(p.tipo)
	var ate := -1 if apr.has(1) else world.day_index() + 1
	var novo := {}
	if str(p.alvo_tipo) == "parceiro":
		novo = (party.parceiro(str(p.alvo)) as Dictionary).duplicate(true)
		var niveis := ["iniciante", "veterano", "mestre"]
		var i := niveis.find(str(novo.nivel))
		if i < 2:
			novo["nivel"] = niveis[i + 1]
		else:
			novo["extra"] = {"tipo": tipo, "pericias": (p.get("pericias", []) as Array).duplicate()}
		novo["despertado"] = true
	else:
		var especie: String = {"animal": str(p.alvo), "planta": "planta", "escultura": "escultura (construto)"}[str(p.alvo_tipo)]
		novo = {"id": "despertar_%s" % str(p.alvo), "tipo": tipo, "nivel": "veterano", "nome": "%s desperto" % especie, "especie": especie,
			"fonte": "despertar_consciencia", "ate_dia": ate, "despertado": true, "inteligencia": -1}
		if tipo == "ajudante":
			novo["pericias"] = (p.get("pericias", []) as Array).duplicate()
	var err: String = party.adicionar_parceiro(novo) if party != null else "sem módulo de parceiros"
	if err != "":
		return [fact("SPELL_MISSED", {"caster": "player", "spell": "despertar_consciencia", "reason": err}, ["player"])]
	var out: Array = [fact("PARTNER_GAINED", {"partner": novo.id, "tipo": novo.tipo, "nivel": novo.nivel, "nome": str(novo.get("nome", ""))}, ["player"])]
	if apr.has(1):
		world.player_sheet.add_efeito("despertar." + str(novo.id), "pm_max", -3, "permanente")   # penalidade de –3 PM
	return out


## Servo Morto-Vivo: o cadáver vira esqueleto ou zumbi (zumbi se o corpo está preservado), carniçal, sombra ou múmia,
## e acompanha o jogador como parceiro permanente do tipo escolhido. Componente pago em T$.
func servo_morto_vivo(payload: Dictionary) -> Array:
	var out: Array = []
	var apr: Array = payload.get("aprimoramentos", [])
	var servo := SpellRules.servo_de(apr)
	var alvo := str(payload.target)
	var combat = world.module("combat")
	var nome: String = str(servo.criatura) if str(servo.criatura) != "" else ("zumbi" if cadaver_preservado(alvo) else "esqueleto")
	out.append(fact("GOLD_CHANGED", {"delta": -int(servo.custo), "reason": "componente (Servo Morto-Vivo)"}))
	var novo := {"id": "servo_%s" % alvo, "tipo": str(payload.tipo), "nivel": str(servo.nivel), "nome": nome, "especie": nome, "fonte": "servo_morto_vivo", "ate_dia": -1}
	if str(payload.tipo) == "ajudante":
		novo["pericias"] = (payload.get("pericias", []) as Array).duplicate()
	var party = world.module("party")
	var err: String = party.adicionar_parceiro(novo) if party != null else "sem módulo de parceiros"
	if err != "":
		return [fact("SPELL_MISSED", {"caster": "player", "spell": "servo_morto_vivo", "reason": err}, ["player"])]
	combat.marcar_reanimado(alvo)
	out.append(fact("PARTNER_GAINED", {"partner": novo.id, "tipo": novo.tipo, "nivel": novo.nivel, "nome": nome}, ["player"]))
	return out


## Vidência: o NPC faz Vontade com modificador pela familiaridade (pela memória que ele tem do jogador): nunca se viram
## +10; já se encontraram +0; conhece bem (5 lembranças ou mais) –5. Falhou: o jogador vê e ouve o alvo e os arredores
## pela cena. (Objetos de vínculo, como um pertence ou um fio de cabelo, ainda não existem no jogo.)
func lancar_videncia(alvo: String, sh: CharacterSheet) -> Array:
	var mem = world.module("memory")
	var n_mem: int = mem.list(alvo).size() if mem != null else 0
	var mod := 10 if n_mem == 0 else (-5 if n_mem >= 5 else 0)
	var cd := 10 + sh.level / 2 + int(sh.attrs.get(sh.caster_attr, 0))
	var r := Checks.skill(_ficha_npc(alvo), "vontade", cd, world.rules, world.rng, "world", mod)
	if r.get("success", false):
		return [fact("SPELL_MISSED", {"caster": "player", "target": alvo, "spell": "videncia", "reason": "resistiu", "mod": mod}, ["player"])]
	var combat = world.module("combat")
	videncia = {"alvo": alvo, "ate": world.clock.tick + (combat.TICKS_CENA if combat != null else 6)}
	return [fact("SCRYING", {"caster": "player", "target": alvo, "visao": videncia_ver()}, ["player"])]


## O que a Vidência mostra agora: onde o alvo está e quem está com ele. {} se não há Vidência ativa.
func videncia_ver() -> Dictionary:
	if videncia.is_empty() or world.clock.tick >= int(videncia.ate):
		return {}
	var npcs = world.module("npcs")
	if npcs == null:
		return {}
	var alvo := str(videncia.alvo)
	var lugar := str(npcs.npc(alvo).get("location", ""))
	var com: Array = []
	for n in world.db.all_npc_ids():
		if n != alvo and str(npcs.npc(n).get("location", "")) == lugar and bool(npcs.npc(n).get("alive", true)):
			com.append(n)
	return {"alvo": alvo, "lugar": lugar, "com_ele": com, "vivo": bool(npcs.npc(alvo).get("alive", true))}


## Lendas e Histórias fora de combate: tudo sobre um NPC (ficha, ofício, facção, devoção, onde está), um objeto ou um lugar
## (quem e o que há nele). Com o aprimoramento, à distância: um dia de execução e T$ 1.000 da cuba de ouro.
func lendas_e_historias(payload: Dictionary) -> Array:
	var out: Array = []
	var apr: Array = payload.get("aprimoramentos", [])
	if apr.has(0):
		out.append(fact("GOLD_CHANGED", {"delta": -1000, "reason": "cuba de ouro (Lendas e Histórias)"}))
		out.append_array(world.advance_ticks(24 * 60 / world.clock.tick_minutes))
	var tipo := str(payload.alvo_tipo)
	var alvo := str(payload.alvo)
	var info := {}
	match tipo:
		"criatura":
			var d := world.db.npc_def(alvo)
			var npcs = world.module("npcs")
			var estado: Dictionary = npcs.npc(alvo) if npcs != null else {}
			info = SpellRules.info_ficha(_ficha_npc(alvo), world.rules)
			for k in ["name", "age", "profession", "home", "work", "family", "faction", "devotion", "traits", "beliefs"]:
				info[k] = d.get(k, null)
			info["onde_esta"] = str(estado.get("location", ""))
			info["vivo"] = bool(estado.get("alive", true))
		"objeto":
			info = world.db.object_def(alvo).duplicate(true)
		"local":
			info = world.db.location(alvo).duplicate(true)
			var npcs_l = world.module("npcs")
			var presentes: Array = []
			if npcs_l != null:
				for n in world.db.all_npc_ids():
					if str(npcs_l.npc(n).get("location", "")) == alvo and bool(npcs_l.npc(n).get("alive", true)):
						presentes.append(n)
			info["presentes"] = presentes
			info["objetos"] = world.db.all_objects().filter(func(o): return world.db.location_at(Vector2i(int(o.tile[0]), int(o.tile[1]))) == alvo).map(func(o): return o.id)
	out.append(fact("LORE_REVEALED", {"caster": "player", "alvo_tipo": tipo, "alvo": alvo, "info": info}, ["player"]))
	return out


func augurio(payload: Dictionary) -> Array:
	var out: Array = []
	var apr: Array = payload.get("aprimoramentos", [])
	if apr.has(1):
		# Consulta de sim ou não (10 minutos de execução): cada pergunta tem a chance de falha; falhou, "não sei".
		out.append_array(world.advance_ticks(maxi(1, 10 / world.clock.tick_minutes)))
		var respostas: Array = []
		for q in payload.get("perguntas", []):
			var r := "nao_sei"
			if _augurio_funciona(apr):
				var loc_q := str(q.local)
				var sim_q: bool = _ha_ameaca(loc_q) if q.tipo == "ameaca" else (_ha_tesouro(loc_q) if q.tipo == "tesouro" else _ha_armadilha(loc_q))
				r = "sim" if sim_q else "nao"
			respostas.append({"tipo": q.tipo, "local": q.local, "resposta": r})
		out.append(fact("DIVINE_ANSWERS", {"caster": "player", "respostas": respostas}, ["player"]))
		return out
	var loc := str(payload.local)
	if apr.has(0):
		# Consulta a uma divindade (1 minuto): sobre o que acontecerá no lugar até um dia; a resposta é uma pista.
		out.append_array(world.advance_ticks(1))
		if not _augurio_funciona(apr):
			out.append(fact("DIVINE_ANSWERS", {"caster": "player", "local": loc, "pista": ""}, ["player"]))
			return out
		out.append(fact("DIVINE_ANSWERS", {"caster": "player", "local": loc, "pista": _pista(loc)}, ["player"]))
		var ex = world.module("exploration")
		for t in world.db.all_targets():
			var tl: Array = t.get("tile", [0, 0])
			if world.db.location_at(Vector2i(int(tl[0]), int(tl[1]))) == loc:
				for act in (t.get("actions", {}) as Dictionary).values():
					for f in act.get("reveals", []):
						if ex == null or not ex.knows(str(f)):
							out.append(fact("FACT_REVEALED", {"fact": str(f), "source": "augurio"}, ["player"]))
							return out
		return out
	if not augurios.has(loc):
		var r := "nada"
		if _augurio_funciona(apr):
			var p := _presagio(loc)
			r = "felicidade_e_miseria" if p.felicidade and p.miseria else ("felicidade" if p.felicidade else ("miseria" if p.miseria else "nada"))
		augurios[loc] = r
	out.append(fact("AUGURY", {"caster": "player", "local": loc, "resposta": str(augurios[loc])}, ["player"]))
	return out


func _pista(loc: String) -> String:
	if _ha_ameaca(loc):
		return "ameaca"
	if _ha_armadilha(loc):
		return "armadilha"
	if _ha_tesouro(loc):
		return "tesouro"
	return "caminho_livre"


## Círculo da Justiça (divina 2): esfera de 9m por um dia (permanente com a balança de prata).
func criar_justica(centro: Vector2i, cd: int, apr: Array) -> void:
	justicas.append({"centro": [centro.x, centro.y], "raio": Area.quadrados(9.0), "ate": -1 if apr.has(2) else world.clock.total_minutes() + MINUTOS_DIA,
		"cd": cd, "forte": apr.has(1), "resistiu": {}})


func _justicas_em(t: Vector2i) -> Array:
	var agora := world.clock.total_minutes()
	return justicas.filter(func(ar): return (int(ar.ate) < 0 or int(ar.ate) > agora) and _dist(ar, t) <= int(ar.raio))


## Efeito do Círculo da Justiça sobre a criatura `id` no quadrado `t`: {} fora da área; senão {penalidade, mente}.
## Cada criatura resiste (Vontade) uma vez por círculo: falhou, –10 (–20 com o aprimoramento) e não pode mentir;
## passou, –5 (–10) e pode mentir.
func justica_sobre(id: String, ficha: CharacterSheet, t: Vector2i) -> Dictionary:
	var pior := {}
	for ar in _justicas_em(t):
		if not (ar.resistiu as Dictionary).has(id):
			ar.resistiu[id] = Checks.skill(ficha, "vontade", int(ar.cd), world.rules, world.rng, "world").get("success", false)
		var passou: bool = ar.resistiu[id]
		var pen := (10 if passou else 20) if bool(ar.forte) else (5 if passou else 10)
		if pior.is_empty() or pen > int(pior.penalidade):
			pior = {"penalidade": pen, "mente": passou and bool(pior.get("mente", true))}
		elif not passou:
			pior["mente"] = false
	return pior


## Um NPC no lugar `loc` pode mentir (distorcer o que conta)? Não, se o centro de um Círculo da Justiça ativo fica
## nesse lugar e ele falhou na resistência.
func pode_mentir(npc: String, loc: String) -> bool:
	var agora := world.clock.total_minutes()
	for ar in justicas:
		if (int(ar.ate) < 0 or int(ar.ate) > agora) and world.db.location_at(Vector2i(int(ar.centro[0]), int(ar.centro[1]))) == loc:
			var j := justica_sobre(npc, _ficha_npc(npc), Vector2i(int(ar.centro[0]), int(ar.centro[1])))
			if not bool(j.get("mente", true)):
				return false
	return true


## Aplica na ficha as penalidades do Círculo da Justiça para quem está no quadrado (remove as antigas).
func aplicar_justica(id: String, ficha: CharacterSheet, t: Vector2i) -> void:
	ficha.anular_magia("magia.circulo_da_justica_area")
	var j := justica_sobre(id, ficha, t)
	if j.is_empty():
		return
	for p in PERICIAS_JUSTICA:
		ficha.add_efeito("magia.circulo_da_justica_area", "pericia_" + p, -int(j.penalidade), "cena")
	if not bool(j.mente):
		ficha.add_efeito("magia.circulo_da_justica_area", "nao_mente", 1, "cena")


func _areas_em(t: Vector2i) -> Array:
	var agora := world.clock.total_minutes()
	var out: Array = []
	for ar in areas:
		if (int(ar.ate) < 0 or int(ar.ate) > agora) and _dist(ar, t) <= int(ar.raio):
			out.append(ar)
	return out


func _dist(ar: Dictionary, t: Vector2i) -> int:
	return maxi(absi(int(ar.centro[0]) - t.x), absi(int(ar.centro[1]) - t.y))


## Dados de luz maximizados em área consagrada; de trevas, em área profanada.
func maximiza(tipo: String, t: Vector2i) -> bool:
	if tipo == "":
		return false
	for ar in _areas_em(t):
		if str(ENERGIA[str(ar.tipo)]) == tipo:
			return true
	return false


## Modificador de Defesa e testes para mortos-vivos no quadrado (soma das áreas que o cobrem).
func mod_morto_vivo_em(t: Vector2i) -> int:
	var m := 0
	for ar in _areas_em(t):
		m += int(ar.mod_mv)
	return m


func _tile_jogador() -> Vector2i:
	return world.db.world_to_tile(world.player.position)


## Controlar Plantas (poda): a vegetação fica podada (terreno difícil natural vira normal) nas próximas cenas.
func podar(tiles: Array) -> void:
	for t in tiles:
		podas["%d,%d" % [t.x, t.y]] = true


func tiles_podados() -> Array:
	var out: Array = []
	for k in podas:
		out.append(Vector2i(int(str(k).get_slice(",", 0)), int(str(k).get_slice(",", 1))))
	return out


## Controlar Plantas (falar com plantas, 2 PM): plantas prestativas dão respostas simplórias sobre os arredores —
## quantas criaturas estão por perto agora (percepção limitada: até alcance longo).
func falar_com_plantas(p: Vector2i, rochas: bool = false) -> Dictionary:
	var combat = world.module("combat")
	var perto: Array = []
	var longo := int(world.rules.value("alcance.quadrados", {}).get("longo", 60))
	if combat != null:
		for id in combat.creature_state:
			var st_c: Dictionary = combat.creature_state[id]
			var t: Array = st_c.get("tile", [0, 0])
			if bool(st_c.get("alive", false)) and bool(st_c.get("present", false)) and maxi(absi(p.x - int(t[0])), absi(p.y - int(t[1]))) <= longo:
				perto.append(id)
	return fact("PLANTS_TALKED", {"caster": "player", "criaturas_perto": perto.size(), "atitude": "prestativa", "rochas": rochas}, ["player"])


## Condição fora de combate: status dos companheiros e NPCs que o jogador acompanha, a qualquer distância.
func status_acompanhados() -> Array:
	var out: Array = []
	var npcs = world.module("npcs")
	if world.player_sheet == null or npcs == null:
		return out
	for e in world.player_sheet.efeitos:
		var tg := str(e.tipo)
		if e.stat == "condicao" and not npcs.npc(tg).is_empty() and bool(npcs.npc(tg).alive):
			var st_c := SpellRules.status_de(tg, _ficha_npc(tg), Vector2i.ZERO)
			st_c["local"] = str(npcs.npc(tg).location)
			out.append(st_c)
	return out


## Voz Divina (cadáver, 1 PM): o corpo responde com o que sabia em vida (respostas curtas: os fatos do diálogo que
## o jogador ainda não sabe). Um corpo só pode ser alvo uma vez.
func interrogar_cadaver(id: String) -> Array:
	var out: Array = []
	interrogados[id] = true
	out.append(fact("CORPSE_QUESTIONED", {"caster": "player", "target": id}, ["player"]))
	var ex = world.module("exploration")
	for f in fatos_que_sabe(id):
		if ex == null or not ex.knows(f):
			out.append(fact("FACT_REVEALED", {"fact": f, "source": "cadaver:" + id}, ["player"]))
	return out


## Abençoar Alimentos (divina 1): purifica e abençoa porções de comida ou bebida do inventário. Consumidas na cena,
## dão o bônus (ItemsModule._comer). Truque: só purifica (estragado ou envenenado vira próprio, sem bônus).
## Aprimoramentos: +1 alvo (1 PM, repetível); água benta permanente de 1 frasco com água e T$ 5 de pó de prata (1 PM).
func _valida_abencoar(payload: Dictionary, apr: Array) -> PackedStringArray:
	var st = world.module("state")
	var item := str(payload.get("item", ""))
	if apr.has(1):
		if apr.has(0): return PackedStringArray(["a água benta é de um frasco só"])
		if st == null or not st.has_item("frasco_agua"): return PackedStringArray(["precisa de um frasco com água"])
		if int(world.player.gold) < PO_DE_PRATA: return PackedStringArray(["faltam T$ %d de pó de prata" % PO_DE_PRATA])
		return PackedStringArray()
	if not bool(world.db.items.get(item, {}).get("alimento", false)) and not bool(world.db.items.get(item, {}).get("estragado", false)):
		return PackedStringArray(["escolha comida ou bebida"])
	if st == null or st.item_count(item) < (1 if payload.get("truque", false) else 1 + apr.count(0)):
		return PackedStringArray(["porções insuficientes"])
	return PackedStringArray()


func abencoar(payload: Dictionary) -> Array:
	var apr: Array = payload.get("aprimoramentos", [])
	var item := str(payload.get("item", ""))
	if apr.has(1):
		return [fact("ITEM_LOST", {"item": "frasco_agua"}, ["player"]), fact("GOLD_CHANGED", {"delta": -PO_DE_PRATA, "reason": "pó de prata"}),
			fact("ITEM_GAINED", {"item": "agua_benta", "from": "abencoar_alimentos"}, ["player"])]
	var d: Dictionary = world.db.items.get(item, {})
	var out: Array = []
	if bool(d.get("estragado", false)) or bool(d.get("envenenado", false)):
		var limpo := str(d.get("limpo", item))
		out.append(fact("ITEM_LOST", {"item": item}, ["player"]))
		out.append(fact("ITEM_GAINED", {"item": limpo, "from": "purificado"}, ["player"]))
		item = limpo
	if payload.get("truque", false):
		return out + [fact("FOOD_PURIFIED", {"item": item}, ["player"])]
	var combat = world.module("combat")
	var n := 1 + apr.count(0)
	var atual: Dictionary = abencoados.get(item, {})
	var antes := int(atual.get("n", 0)) if int(atual.get("ate", -1)) > world.clock.tick else 0
	abencoados[item] = {"n": antes + n, "ate": world.clock.tick + (combat.TICKS_CENA if combat != null else 6)}
	return out + [fact("FOOD_BLESSED", {"item": item, "portions": n}, ["player"])]


## Luz carregada (tocha acesa, chama na palma): dura a cena; entra no combate como efeito "fonte_luz".
func carregar_luz(raio_q: int) -> void:
	var combat = world.module("combat")
	luz_carregada = {"raio": maxi(raio_q, int(luz_carregada.get("raio", 0)) if luz_ativa() > 0 else 0), "ate": world.clock.tick + (combat.TICKS_CENA if combat != null else 6)}


func luz_ativa() -> int:
	if luz_carregada.is_empty() or (int(luz_carregada.ate) >= 0 and int(luz_carregada.ate) <= world.clock.tick):
		return 0
	return int(luz_carregada.raio)


func silencio_ativo() -> bool:
	return not silencio_carregado.is_empty() and int(silencio_carregado.ate) > world.clock.tick


func escuridao_ativa() -> Dictionary:
	if escuridao_carregada.is_empty() or int(escuridao_carregada.ate) <= world.clock.tick:
		return {}
	return escuridao_carregada


## Consome uma porção abençoada do item, se houver uma valendo. Chamado ao comer.
func consumir_abencoado(item: String) -> bool:
	var a: Dictionary = abencoados.get(item, {})
	if a.is_empty() or int(a.ate) <= world.clock.tick or int(a.n) <= 0:
		return false
	a.n = int(a.n) - 1
	if int(a.n) <= 0:
		abencoados.erase(item)
	return true


## Detectar Ameaças (divina 1): pessoal, esfera de 18m, pela cena (TICKS_CENA) ou até ser descarregada.
## Aprimoramentos: raça e aura da criatura (1 PM); não ser surpreendido pelo que detectou e +5 contra armadilhas
## (2 PM, 2º círculo).
func ativar_detectar(apr: Array) -> void:
	var combat = world.module("combat")
	detectar = {"ate": world.clock.tick + (combat.TICKS_CENA if combat != null else 6), "apr": apr.duplicate()}


func detectar_ativo() -> Dictionary:
	if detectar.is_empty() or int(detectar.ate) <= world.clock.tick:
		return {}
	return detectar


func descarregar_detectar() -> void:
	var apr: Array = detectar.get("apr", [])
	detectar = {}
	if apr.has(1):
		# o bônus contra armadilhas e a proteção contra surpresa valem pela cena, depois de descarregada
		protecao_detectar = {"ate": world.clock.tick + 6}



func bonus_contra_armadilhas() -> int:
	var ativo := detectar_ativo()
	if (not ativo.is_empty() and (ativo.apr as Array).has(1)) or (not protecao_detectar.is_empty() and int(protecao_detectar.ate) > world.clock.tick):
		return 5
	return 0


## --- Adivinhação fora de combate ---------------------------------------------------------------------
## NPC no mesmo local do jogador (toque ou alcance curto, fora de combate).
func _no_mesmo_lugar(npc: String) -> bool:
	var npcs = world.module("npcs")
	if npcs == null or npcs.npc(npc).is_empty() or not bool(npcs.npc(npc).alive):
		return false
	if _lancando_pela_projecao and projecao_ve(npc):
		return true   # Projetar Consciência (aprimoramento): a magia parte da projeção
	return str(npcs.npc(npc).location) == world.db.location_at(_tile_jogador())


func _ficha_npc(npc: String) -> CharacterSheet:
	var party = world.module("party")
	if party != null and party.members.has(npc) and party.members[npc].has("sheet"):
		return CharacterSheet.from_dict(party.members[npc].sheet)
	return party.ficha_de(npc) if party != null else CharacterSheet.new()


## O que um NPC (ou criatura) sabe: os fatos que o diálogo dele pode revelar.
func fatos_que_sabe(id: String) -> Array:
	var out: Array = []
	var d: Dictionary = world.db.dialogue.get("npcs", {}).get(id, {})
	_coletar_revelacoes(d, out)
	return out


func _coletar_revelacoes(v: Variant, out: Array) -> void:
	if v is Dictionary:
		if v.has("reveal") and not out.has(str(v.reveal)):
			out.append(str(v.reveal))
		for k in v:
			_coletar_revelacoes(v[k], out)
	elif v is Array:
		for x in v:
			_coletar_revelacoes(x, out)


func _pensamentos(npc: String, todos: bool) -> Array:
	var ex = world.module("exploration")
	var out: Array = []
	for f in fatos_que_sabe(npc):
		if ex != null and ex.knows(f):
			continue
		out.append(fact("FACT_REVEALED", {"fact": f, "source": "pensamentos:" + npc}, ["player"]))
		if not todos:
			break
	if out.is_empty():
		out.append(fact("THOUGHTS_READ", {"target": npc, "nada_novo": true}, ["player"]))
	return out


## Auras mágicas no mundo a até `raio` quadrados: áreas de Consagrar e Profanar, cadáveres abençoados, a luz ou as
## sombras de magia que o jogador carrega e os efeitos de magia na ficha dele.
func auras_no_mundo(centro: Vector2i, raio: int, completo: bool) -> Array:
	var out: Array = []
	for ar in _areas_em(centro):
		out.append(_aura(str(ar.tipo), Vector2i(int(ar.centro[0]), int(ar.centro[1])), completo))
	for ar in _justicas_em(centro):
		out.append(_aura("circulo_da_justica", Vector2i(int(ar.centro[0]), int(ar.centro[1])), completo))
	var combat = world.module("combat")
	for id in cadaveres:
		if cadaver_preservado(id) and combat != null and combat.creature_state.has(id):
			var t: Array = combat.creature_state[id].tile
			if maxi(absi(int(t[0]) - centro.x), absi(int(t[1]) - centro.y)) <= raio:
				out.append(_aura("bencao", Vector2i(int(t[0]), int(t[1])), completo))
	if not escuridao_ativa().is_empty():
		out.append(_aura("escuridao", _tile_jogador(), completo))
	var vistos := {}
	for e in world.player_sheet.efeitos:
		var eid := str(e.id)
		if eid.begins_with("magia.") and not vistos.has(eid):
			vistos[eid] = true
			out.append(_aura(eid.substr(6), _tile_jogador(), completo))
	return out


func _aura(sp: String, t: Vector2i, completo: bool) -> Dictionary:
	var circ := int(world.rules.value("magia." + sp, {}).get("circulo", 1))
	var a := {"intensidade": SpellRules.aura_por_circulo(circ)}
	if completo:
		a["magia"] = sp
		a["onde"] = [t.x, t.y]
	return a


## Visão Mística fora de combate: os NPCs presentes que lançam magias e a aura da magia mais alta.
func _conjuradores_aqui() -> Array:
	var npcs = world.module("npcs")
	var out: Array = []
	if npcs == null:
		return out
	for id in npcs.npcs_at(world.db.location_at(_tile_jogador())):
		var f := _ficha_npc(id)
		if not f.spells.is_empty():
			out.append({"npc": id, "aura": SpellRules.aura_por_circulo(SpellRules.circulo_maximo(f, world.rules))})
	return out


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
	if dist > int(world.rules.value("alcance.quadrados", {}).get(alcance, 1)):   # toque = 1
		return PackedStringArray(["cadáver fora do alcance"])
	return PackedStringArray()


func to_dict() -> Dictionary:
	return {"cadaveres": cadaveres.duplicate(), "areas": areas.duplicate(true), "podas": podas.duplicate(), "detectar": detectar.duplicate(true),
		"protecao_detectar": protecao_detectar.duplicate(), "abencoados": abencoados.duplicate(true), "luz_carregada": luz_carregada.duplicate(), "videncia": videncia.duplicate(), "runas": runas.duplicate(true), "cidade_protegida": cidade_protegida.duplicate(), "missoes": missoes.duplicate(true), "arborea_ate": arborea_ate, "projecao": projecao.duplicate(), "visitados": visitados.duplicate(), "dia_missoes": _dia_missoes, "escuridao_carregada": escuridao_carregada.duplicate(), "silencio_carregado": silencio_carregado.duplicate(), "interrogados": interrogados.duplicate(), "justicas": justicas.duplicate(true), "augurios": augurios.duplicate(), "mensageiros": mensageiros.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	cadaveres = (d.get("cadaveres", {}) as Dictionary).duplicate()
	areas = (d.get("areas", []) as Array).duplicate(true)
	podas = (d.get("podas", {}) as Dictionary).duplicate()
	detectar = (d.get("detectar", {}) as Dictionary).duplicate(true)
	protecao_detectar = (d.get("protecao_detectar", {}) as Dictionary).duplicate()
	abencoados = (d.get("abencoados", {}) as Dictionary).duplicate(true)
	luz_carregada = (d.get("luz_carregada", {}) as Dictionary).duplicate()
	videncia = (d.get("videncia", {}) as Dictionary).duplicate()
	runas = (d.get("runas", []) as Array).duplicate(true)
	cidade_protegida = (d.get("cidade_protegida", {}) as Dictionary).duplicate()
	missoes = (d.get("missoes", {}) as Dictionary).duplicate(true)
	arborea_ate = int(d.get("arborea_ate", -1))
	projecao = (d.get("projecao", {}) as Dictionary).duplicate()
	visitados = (d.get("visitados", {}) as Dictionary).duplicate()
	_dia_missoes = int(d.get("dia_missoes", -1))
	escuridao_carregada = (d.get("escuridao_carregada", {}) as Dictionary).duplicate()
	silencio_carregado = (d.get("silencio_carregado", {}) as Dictionary).duplicate()
	interrogados = (d.get("interrogados", {}) as Dictionary).duplicate()
	justicas = (d.get("justicas", []) as Array).duplicate(true)
	augurios = (d.get("augurios", {}) as Dictionary).duplicate()
	mensageiros = (d.get("mensageiros", []) as Array).duplicate(true)
