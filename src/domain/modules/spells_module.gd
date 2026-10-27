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
}
const OPOSTA := {"consagrar": "profanar", "profanar": "consagrar"}
const ENERGIA := {"consagrar": "luz", "profanar": "trevas"}
const TOTAL_PERMANENTE := 1000   # T$ de incenso e óleos da versão permanente
const DIAS_SEMANA := 7
const MINUTOS_DIA := 24 * 60

var cadaveres: Dictionary = {}   # creature_id -> último dia (inclusive) em que está preservado
var podas: Dictionary = {}       # "x,y" -> true: vegetação podada por Controlar Plantas (instantânea, fica)
var areas: Array = []            # {tipo, centro:[x,y], raio, ate: minuto do fim (-1 permanente), mod_mv:int, conjurador}


func module_id() -> String: return "magia"
func handled_commands() -> PackedStringArray: return PackedStringArray(["CastSpell"])


func validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate: use as ações de combate"])
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
func falar_com_plantas(p: Vector2i) -> Dictionary:
	var combat = world.module("combat")
	var perto: Array = []
	var longo := int(world.rules.value("alcance.quadrados", {}).get("longo", 60))
	if combat != null:
		for id in combat.creature_state:
			var st_c: Dictionary = combat.creature_state[id]
			var t: Array = st_c.get("tile", [0, 0])
			if bool(st_c.get("alive", false)) and bool(st_c.get("present", false)) and maxi(absi(p.x - int(t[0])), absi(p.y - int(t[1]))) <= longo:
				perto.append(id)
	return fact("PLANTS_TALKED", {"caster": "player", "criaturas_perto": perto.size(), "atitude": "prestativa"}, ["player"])


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
	if dist > int(world.rules.value("alcance.quadrados", {}).get(alcance, 6)):
		return PackedStringArray(["cadáver fora do alcance"])
	return PackedStringArray()


func to_dict() -> Dictionary:
	return {"cadaveres": cadaveres.duplicate(), "areas": areas.duplicate(true), "podas": podas.duplicate()}


func from_dict(d: Dictionary) -> void:
	cadaveres = (d.get("cadaveres", {}) as Dictionary).duplicate()
	areas = (d.get("areas", []) as Array).duplicate(true)
	podas = (d.get("podas", {}) as Dictionary).duplicate()
