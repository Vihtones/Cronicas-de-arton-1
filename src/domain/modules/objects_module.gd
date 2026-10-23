class_name ObjectsModule
extends WorldModule
## Portas, baús, escadas e barracas. Interação física só abre passagem se as
## pré-condições forem satisfeitas (§6, fluxo de exploração).

var state: Dictionary = {}  # object_id -> {open, locked, pv, contents}


func module_id() -> String: return "objects"
func essential() -> bool: return true
func handled_commands() -> PackedStringArray: return PackedStringArray(["UseObject"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["PLAYER_CAPTURED"])


func on_event(e: GameEvent) -> Array:
	_ensure()
	if e.event_type == "PLAYER_CAPTURED" and state.has("porta_cela") and not state.porta_cela.broken:
		state.porta_cela.open = false
		state.porta_cela.locked = true
	return []


func _ensure() -> void:
	if not state.is_empty():
		return
	for o in world.db.all_objects():
		state[o.id] = {"open": bool(o.get("open", false)), "locked": bool(o.get("locked", false)),
			"pv": int(o.get("break", {}).get("pv", 0)), "contents": o.get("contents", []).duplicate(), "broken": false}


func obj(id: String) -> Dictionary:
	_ensure()
	return state.get(id, {})


## Porta fechada bloqueia passagem.
func blocks(t: Vector2i) -> bool:
	var id := world.db.object_at(t)
	if id == "":
		return false
	var d := world.db.object_def(id)
	if d.type != "door":
		return false
	var s := obj(id)
	return not (s.open or s.broken)


func walkable(t: Vector2i) -> bool:
	return world.db.static_walkable(t) and not blocks(t)


func player_tile() -> Vector2i:
	return world.db.world_to_tile(world.player.position)


func is_adjacent(id: String) -> bool:
	var d := world.db.object_def(id)
	var t := Vector2i(int(d.tile[0]), int(d.tile[1]))
	var p := player_tile()
	return absi(p.x - t.x) <= 1 and absi(p.y - t.y) <= 1


func validate(cmd: GameCommand) -> PackedStringArray:
	_ensure()
	var id: String = cmd.payload.get("object_id", "")
	var action: String = cmd.payload.get("action", "")
	var d := world.db.object_def(id)
	if d.is_empty():
		return PackedStringArray(["objeto inexistente: " + id])
	if not is_adjacent(id):
		return PackedStringArray(["longe demais de " + d.name])
	var s: Dictionary = state[id]
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate: use as ações de combate"])
	match action:
		"open":
			if d.type not in ["door", "chest"]: return PackedStringArray(["não abre"])
			if s.open or s.broken: return PackedStringArray(["já está aberto"])
			if s.locked: return PackedStringArray(["trancado"])
		"close":
			if d.type != "door" or not s.open or s.broken: return PackedStringArray(["não pode fechar"])
		"unlock":
			if not s.locked: return PackedStringArray(["não está trancado"])
			var key: String = d.get("key", "")
			if key == "" or not world.module("state").has_item(key):
				return PackedStringArray(["você não tem a chave"])
		"pick_lock":
			if not s.locked: return PackedStringArray(["não está trancado"])
			if not world.player_sheet.can_use_skill("ladinagem", world.rules):
				return PackedStringArray(["Ladinagem é somente treinada (LB p.115)"])
			var ex = world.module("exploration")
			if ex != null:
				var why: String = ex.loop_block_reason("obj:" + id, "ladinagem")
				if why != "": return PackedStringArray([why])
		"break":
			if not d.has("break") or s.broken: return PackedStringArray(["não dá para quebrar"])
		"loot":
			if d.type != "chest" or not s.open: return PackedStringArray(["nada para pegar"])
			if s.contents.is_empty(): return PackedStringArray(["vazio"])
		"use_stairs":
			if d.type != "stairs": return PackedStringArray(["não é uma escada"])
		_:
			return PackedStringArray(["ação desconhecida: " + action])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var id: String = cmd.payload.object_id
	var action: String = cmd.payload.action
	var d := world.db.object_def(id)
	var s: Dictionary = state[id]
	var loc := world.db.location_at(Vector2i(int(d.tile[0]), int(d.tile[1])))
	match action:
		"open":
			s.open = true
			return [fact("OBJECT_OPENED", {"object": id, "location": loc}, ["player"])]
		"close":
			s.open = false
			return [fact("OBJECT_CLOSED", {"object": id, "location": loc}, ["player"])]
		"unlock":
			s.locked = false
			return [fact("OBJECT_UNLOCKED", {"object": id, "with": d.key, "location": loc}, ["player"])]
		"pick_lock":
			var r := Checks.skill(world.player_sheet, "ladinagem", int(d.get("lock_cd", 20)), world.rules, world.rng)
			var ex = world.module("exploration")
			if ex != null: ex.record_attempt("obj:" + id, "ladinagem", r.success)
			if r.success:
				s.locked = false
				return [fact("OBJECT_UNLOCKED", {"object": id, "with": "ladinagem", "check": r, "location": loc}, ["player"])]
			return [fact("CHECK_FAILED", {"object": id, "check": r}, ["player"])]
		"break":
			return _break(id, d, s, loc)
		"loot":
			var out: Array = []
			for it in s.contents:
				out.append(fact("ITEM_GAINED", {"item": it, "from": id, "location": loc}, ["player"]))
				var owner: String = world.db.items.get(it, {}).get("owner", "")
				if owner != "":
					out.append(fact("STOLEN_GOODS_RECOVERED", {"item": it, "owner": owner, "location": loc}, ["player"]))
			s.contents = []
			return out
		"use_stairs":
			var to: Array = d.to
			world.player.position = world.db.tile_to_world(Vector2i(int(to[0]), int(to[1])))
			return [fact("PLAYER_TELEPORTED", {"via": id, "to": to}, ["player"])]
	return []


## Quebrar objeto: ataque contra Defesa do objeto, dano menos RD (LB p.239).
func _break(id: String, d: Dictionary, s: Dictionary, loc: String) -> Array:
	var b: Dictionary = d["break"]
	var sheet := world.player_sheet
	var atk: Dictionary = sheet.attacks[0]
	var mod := sheet.skill_value("luta", world.rules)
	var d20: int = world.rng.roll("combat", 1, 20)[0]
	var hit := d20 + mod >= int(b.defesa)
	var out: Array = []
	var dmg := 0
	if hit:
		var roll := Dice.roll(atk.dano, world.rng, "combat", 1, int(sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0)
		dmg = maxi(0, int(roll.total) - int(b.rd))
		s.pv = int(s.pv) - dmg
	out.append(fact("OBJECT_DAMAGED", {"object": id, "d20": d20, "mod": mod, "hit": hit, "damage": dmg, "pv": s.pv, "noise": true, "location": loc}, ["player"]))
	if int(s.pv) <= 0:
		s.broken = true
		s.locked = false
		out.append(fact("OBJECT_BROKEN", {"object": id, "location": loc, "owner_location": loc}, ["player"]))
	return out


func to_dict() -> Dictionary:
	_ensure()
	return {"state": state.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate(true)
	for k in state:
		state[k].pv = int(state[k].pv)
