extends WorldModule
## Magias fora de combate (docs/MAGIA_COMPLEXA.md): o comando CastSpell lança, fora de uma luta, a cura em si mesmo
## e as magias e versões de magia que agem sobre o mundo e não sobre a cena de combate (cadáveres, alimentos, áreas, sentidos).
## Em combate, as magias passam pelo CombatModule.
## Estado: cadáveres preservados pela Bênção (criatura -> último dia preservado) e áreas consagradas e profanadas.

const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
const Area := preload("res://src/domain/combat/area.gd")

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
	"condicao": [],   # companheiros e NPCs por perto; depois, a distância não importa   # conversar com qualquer criatura; interrogar cadáver; falar com plantas e rochas   # água no recipiente, chama na palma, terra; ar e fogo em quadrados só pesam numa cena
}
const PO_DE_PRATA := 5   # T$ de pó de prata da água benta
const RAIO_DETECTAR := 12   # esfera de 18m
const OPOSTA := {"consagrar": "profanar", "profanar": "consagrar"}
const ENERGIA := {"consagrar": "luz", "profanar": "trevas"}
const TOTAL_PERMANENTE := 1000   # T$ de incenso e óleos da versão permanente
const DIAS_SEMANA := 7
const MINUTOS_DIA := 24 * 60

var interrogados: Dictionary = {}   # Voz Divina: cadáveres que já responderam (um corpo só uma vez)
var cadaveres: Dictionary = {}   # creature_id -> último dia (inclusive) em que está preservado
var detectar: Dictionary = {}    # Detectar Ameaças ativa: {ate: tick, apr: [...]} (cena, até ser descarregada)
var protecao_detectar: Dictionary = {}   # aprimoramento de 2 PM depois de descarregada: {ate: tick}
var silencio_carregado: Dictionary = {}   # Silêncio (objeto, cena) fora de combate: {ate: tick}
var escuridao_carregada: Dictionary = {}   # objeto que emana sombras (Escuridão): {raio, total, ate}
var luz_carregada: Dictionary = {}   # luz que o jogador carrega fora de combate: {raio: quadrados, ate: tick}
var abencoados: Dictionary = {}  # item -> {n: porções abençoadas, ate: tick do fim da cena}
var podas: Dictionary = {}       # "x,y" -> true: vegetação podada por Controlar Plantas (instantânea, fica)
var areas: Array = []            # {tipo, centro:[x,y], raio, ate: minuto do fim (-1 permanente), mod_mv:int, conjurador}


func module_id() -> String: return "magia"
func handled_commands() -> PackedStringArray: return PackedStringArray(["CastSpell", "DetectMagic", "ReadThoughts"])


func validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate: use as ações de combate"])
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
	if not sh.spells.has(sp_id):
		return PackedStringArray(["magia não conhecida"])
	if world.rules.value("magia." + sp_id, {}).has("cura"):
		if not apr.is_empty():
			return PackedStringArray(["fora de combate, a cura é lançada sem aprimoramentos"])
		if sh.pm < GhostPlanner.spell_cost(world.rules, GhostPlanner.spell_rule(world.rules, sp_id), cmd.payload):
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
	if sh.pm < GhostPlanner.spell_cost(world.rules, sp, cmd.payload):
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


func execute(cmd: GameCommand) -> Array:
	var sh: CharacterSheet = world.player_sheet
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
	var custo := GhostPlanner.spell_cost(world.rules, sp, cmd.payload)
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
		"protecao_detectar": protecao_detectar.duplicate(), "abencoados": abencoados.duplicate(true), "luz_carregada": luz_carregada.duplicate(), "escuridao_carregada": escuridao_carregada.duplicate(), "silencio_carregado": silencio_carregado.duplicate(), "interrogados": interrogados.duplicate()}


func from_dict(d: Dictionary) -> void:
	cadaveres = (d.get("cadaveres", {}) as Dictionary).duplicate()
	areas = (d.get("areas", []) as Array).duplicate(true)
	podas = (d.get("podas", {}) as Dictionary).duplicate()
	detectar = (d.get("detectar", {}) as Dictionary).duplicate(true)
	protecao_detectar = (d.get("protecao_detectar", {}) as Dictionary).duplicate()
	abencoados = (d.get("abencoados", {}) as Dictionary).duplicate(true)
	luz_carregada = (d.get("luz_carregada", {}) as Dictionary).duplicate()
	escuridao_carregada = (d.get("escuridao_carregada", {}) as Dictionary).duplicate()
	silencio_carregado = (d.get("silencio_carregado", {}) as Dictionary).duplicate()
	interrogados = (d.get("interrogados", {}) as Dictionary).duplicate()
