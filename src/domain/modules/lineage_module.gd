class_name LineageModule
extends WorldModule
## Gerações (§8, §20.8): longevidade 70+2d20 rolada uma vez (LB p.108), morte por
## velhice, herança para o parente mais velho, nascimentos em casais e sucessão do
## herói morto por um herdeiro no MESMO mundo. Nascimentos/casais: ORIGINAL_DO_JOGO.

const COUPLES := [["otto", "hilda"], ["garrick", "mara"], ["rosana", "bento"], ["joran", "celia"]]
const BIRTH_CHANCE := 0.15  # por casal por ano, se a mais jovem do casal tiver < 40

var longevity: Dictionary = {}     # npc -> idade máxima
var newborns: Array[Dictionary] = []  # {id, name, family, born_year}
var deaths: Array[Dictionary] = []
var inheritance: Dictionary = {}   # npc falecido -> herdeiro
var heroes: Array[Dictionary] = [] # heróis anteriores do jogador
var _last_year := 1


func module_id() -> String: return "lineage"
func handled_commands() -> PackedStringArray: return PackedStringArray(["ContinueAsHeir"])


func _ensure() -> void:
	if not longevity.is_empty():
		return
	var r: Dictionary = world.rules.value("envelhecimento")
	for id in world.db.all_npc_ids():
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
	# nascimentos
	for pair in COUPLES:
		var a: Dictionary = npcs.state.get(pair[0], {})
		var b: Dictionary = npcs.state.get(pair[1], {})
		if a.is_empty() or b.is_empty() or not a.alive or not b.alive:
			continue
		if mini(int(a.age), int(b.age)) >= 40:
			continue
		if world.rng.stream("world").randf() < BIRTH_CHANCE:
			var fam: String = world.db.npc_def(pair[0]).get("family", "")
			var id := "bebe_%s_%d" % [fam, c.year]
			newborns.append({"id": id, "name": "Bebê %s" % fam.capitalize(), "family": fam, "born_year": c.year})
			out.append(fact("NPC_BORN", {"id": id, "family": fam, "parents": pair, "location": world.db.npc_def(pair[0]).home,
				"witnesses": pair}, pair))
	return out


func _family(id: String) -> Array:
	var fam: String = world.db.npc_def(id).get("family", "")
	for f in world.db.npcs.get("families", []):
		if f.id == fam:
			return f.members
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
		"inheritance": inheritance.duplicate(), "heroes": heroes.duplicate(true), "last_year": _last_year}


func from_dict(d: Dictionary) -> void:
	longevity = {}
	for k in d.get("longevity", {}): longevity[k] = int(d.longevity[k])
	newborns.clear(); for x in d.get("newborns", []): newborns.append(x)
	deaths.clear(); for x in d.get("deaths", []): deaths.append(x)
	inheritance = d.get("inheritance", {}).duplicate()
	heroes.clear(); for x in d.get("heroes", []): heroes.append(x)
	_last_year = int(d.get("last_year", 1))
