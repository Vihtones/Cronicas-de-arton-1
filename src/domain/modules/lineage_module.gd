class_name LineageModule
extends WorldModule
## Gerações (§8, §20.8): longevidade 70+2d20 rolada uma vez (LB p.108), morte por
## velhice, herança para o parente mais velho, nascimentos em casais e sucessão do
## herói morto por um herdeiro no MESMO mundo. Nascimentos/casais: ORIGINAL_DO_JOGO.

const COUPLES := [["otto", "hilda"], ["garrick", "mara"], ["rosana", "bento"], ["joran", "celia"]]
const BIRTH_CHANCE := 0.15  # por casal por ano, se a mais jovem do casal tiver < 40
const MARRIAGE_CHANCE := 0.1   # por ano, para o primeiro par elegível (ORIGINAL_DO_JOGO)
const BABY_NAMES := {"f": ["Ana", "Brisa", "Clara", "Dália", "Elin", "Flora", "Greta", "Ida", "Jade", "Lia"],
	"m": ["Abel", "Bruno", "Caio", "Dario", "Enzo", "Felix", "Gil", "Hugo", "Ivo", "Lauro"]}

var longevity: Dictionary = {}     # npc -> idade máxima
var newborns: Array[Dictionary] = []  # {id, name, family, born_year}
var deaths: Array[Dictionary] = []
var inheritance: Dictionary = {}   # npc falecido -> herdeiro
var heroes: Array[Dictionary] = [] # heróis anteriores do jogador
var dynamic_npcs: Dictionary = {}  # C7: NPCs nascidos no jogo (definição completa, persistida no save)
var home_override: Dictionary = {} # C8: quem casou e mudou de casa
var couples: Array = []            # C8: casais formados durante o jogo
var _last_year := 1


func module_id() -> String: return "lineage"
func handled_commands() -> PackedStringArray: return PackedStringArray(["ContinueAsHeir"])


func _ensure() -> void:
	if not longevity.is_empty():
		return
	var r: Dictionary = world.rules.value("envelhecimento")
	for id in world.all_npc_ids():
		var roll := int(Dice.roll("2d20", world.rng, "world").total)
		longevity[id] = 70 + roll


func on_tick(_tick: int) -> Array:
	_ensure()
	var c := world.clock.calendar()
	if c.year == _last_year:
		return []
	_last_year = c.year
	var out: Array = []
	var npcs = world.module("npcs")
	if npcs == null:
		return out
	# mortes por velhice
	for id in npcs.state:
		var s: Dictionary = npcs.state[id]
		if s.alive and int(s.age) >= int(longevity.get(id, 999)):
			var heir := _heir(id)
			deaths.append({"npc": id, "age": s.age, "year": c.year, "cause": "velhice", "heir": heir})
			inheritance[id] = heir
			out.append(fact("NPC_DIED", {"npc": id, "cause": "velhice", "age": s.age, "heir": heir, "location": s.location,
				"witnesses": _family(id).filter(func(x): return x != id and npcs.state.get(x, {}).get("alive", false))}, [id]))
			if heir != "":
				out.append(fact("INHERITANCE", {"from": id, "to": heir, "assets": ["casa", "economias"]}, [heir]))
	# casamentos (C8): adultos solteiros de famílias diferentes
	out.append_array(_marriages(c.year))
	# nascimentos
	for pair in COUPLES + couples:
		var a: Dictionary = npcs.state.get(pair[0], {})
		var b: Dictionary = npcs.state.get(pair[1], {})
		if a.is_empty() or b.is_empty() or not a.alive or not b.alive:
			continue
		if mini(int(a.age), int(b.age)) >= 40:
			continue
		if world.rng.stream("world").randf() < BIRTH_CHANCE:
			var fam: String = world.npc_def(pair[0]).get("family", "")
			var id := "nascido_%s_%d" % [fam, c.year]
			if dynamic_npcs.has(id):
				continue
			var g := "f" if world.rng.stream("world").randf() < 0.5 else "m"
			var names: Array = BABY_NAMES[g]
			var first: String = names[world.rng.stream("world").randi() % names.size()]
			var surname: String = str(world.npc_def(pair[0]).name).get_slice(" ", 1)
			var home: String = world.npc_def(pair[0]).home
			# C7: o bebê vira um NPC de verdade, com agenda, família e memória
			dynamic_npcs[id] = {"id": id, "name": ("%s %s" % [first, surname]).strip_edges(), "age": 0, "profession": "bebê",
				"schedule": "crianca", "home": home, "work": home, "family": fam, "faction": null, "devotion": "",
				"traits": [], "beliefs": {}, "gold": 0, "gender": g, "parents": pair, "born_year": c.year, "dynamic": true}
			newborns.append({"id": id, "name": dynamic_npcs[id].name, "family": fam, "born_year": c.year, "gender": g})
			out.append(fact("NPC_BORN", {"id": id, "name": dynamic_npcs[id].name, "family": fam, "parents": pair, "location": home,
				"gender": g, "witnesses": pair, "actor": "", "npc": id}, pair))
	return out


func _family(id: String) -> Array:
	var fam: String = world.npc_def(id).get("family", "")
	var out: Array = []
	for f in world.db.npcs.get("families", []):
		if f.id == fam:
			out = f.members.duplicate()
	for nid in dynamic_npcs:
		if dynamic_npcs[nid].family == fam and not out.has(nid):
			out.append(nid)
	return out


func _married(id: String) -> bool:
	for pair in COUPLES + couples:
		if (pair as Array).has(id): return true
	return false


func _marriages(year: int) -> Array:
	var npcs = world.module("npcs")
	if npcs == null or world.rng.stream("world").randf() >= MARRIAGE_CHANCE:
		return []
	var single: Array = []
	for id in world.all_npc_ids():
		var s: Dictionary = npcs.state.get(id, {})
		if s.get("alive", false) and not s.get("captive", false) and int(s.get("age", 0)) >= 18 and int(s.age) <= 45 and not _married(id):
			single.append(id)
	single.sort()
	for i in single.size():
		for j in range(i + 1, single.size()):
			var a: String = single[i]
			var b: String = single[j]
			if world.npc_def(a).get("family", "") == world.npc_def(b).get("family", "") and str(world.npc_def(a).get("family", "")) != "":
				continue
			couples.append([a, b])
			# quem é mais jovem muda para a casa do outro (ORIGINAL_DO_JOGO)
			var mover := a if int(npcs.state[a].age) <= int(npcs.state[b].age) else b
			var stay := b if mover == a else a
			home_override[mover] = world.npc_def(stay).home
			return [fact("NPC_MARRIED", {"a": a, "b": b, "year": year, "home": home_override[mover], "moved": mover,
				"location": world.npc_def(stay).home, "witnesses": [a, b], "actor": "", "npc": b}, [a, b])]
	return []


func _heir(id: String) -> String:
	var npcs = world.module("npcs")
	var best := ""
	var best_age := -1
	for m in _family(id):
		if m == id: continue
		var s: Dictionary = npcs.state.get(m, {})
		if s.get("alive", false) and int(s.age) >= 16 and int(s.age) > best_age:
			best = m; best_age = int(s.age)
	return best


## Sucessão: o herói morreu; um herdeiro assume no mesmo mundo, com parte do espólio.
func validate(cmd: GameCommand) -> PackedStringArray:
	if not world.player_sheet.is_dead() and not bool(cmd.payload.get("force", false)):
		return PackedStringArray(["o herói ainda vive"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var n := heroes.size() + 1
	var old_id := "heroi_anterior_%d" % n
	heroes.append({"id": old_id, "name": world.player_sheet.name, "level": world.player_sheet.level, "tick": world.clock.tick})
	var b: Dictionary = cmd.payload.get("build", {})
	var sheet: CharacterSheet
	if b.is_empty():
		sheet = CharacterSheet.premade_warrior(world.rules, "player", "Herdeiro de " + world.player_sheet.name)
	else:
		sheet = CharacterBuilder.build_from(world.rules, b)
	var inherited := int(world.player.gold) / 2  # testamento: metade do ouro (ORIGINAL)
	world.player_sheet = sheet
	world.player.gold = inherited
	world.player.position = world.db.tile_to_world(world.db.location_spot("taverna"))
	return [fact("HERO_SUCCEEDED", {"previous": old_id, "previous_name": heroes[-1].name, "new_name": sheet.name, "gold": inherited}, ["player"])]


func to_dict() -> Dictionary:
	_ensure()
	return {"longevity": longevity.duplicate(), "newborns": newborns.duplicate(true), "deaths": deaths.duplicate(true),
		"inheritance": inheritance.duplicate(), "heroes": heroes.duplicate(true), "last_year": _last_year,
		"dynamic_npcs": dynamic_npcs.duplicate(true), "home_override": home_override.duplicate(), "couples": couples.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	longevity = {}
	for k in d.get("longevity", {}): longevity[k] = int(d.longevity[k])
	newborns.clear(); for x in d.get("newborns", []): newborns.append(x)
	deaths.clear(); for x in d.get("deaths", []): deaths.append(x)
	inheritance = d.get("inheritance", {}).duplicate()
	heroes.clear(); for x in d.get("heroes", []): heroes.append(x)
	_last_year = int(d.get("last_year", 1))
	dynamic_npcs = d.get("dynamic_npcs", {}).duplicate(true)
	for id in dynamic_npcs: dynamic_npcs[id].age = int(dynamic_npcs[id].get("age", 0))
	home_override = d.get("home_override", {}).duplicate()
	couples = d.get("couples", []).duplicate(true)
