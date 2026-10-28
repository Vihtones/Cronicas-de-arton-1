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


var passagens: Dictionary = {}   # "x,y" -> true: passagem aberta em parede de madeira (Controlar Madeira, modelar)


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
	return (world.db.static_walkable(t) or passagens.has("%d,%d" % [t.x, t.y])) and not blocks(t)


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
			if bool(s.get("emperrada", false)):   # Controlar Madeira (retorcer): Força CD 25
				var rf := Checks.skill(world.player_sheet, "atletismo", 25, world.rules, world.rng)
				if not rf.success:
					return [fact("CHECK_FAILED", {"object": id, "check": rf, "reason": "emperrada"}, ["player"])]
				s.emperrada = false
			s.open = true
			return [fact("OBJECT_OPENED", {"object": id, "location": loc}, ["player"])]
		"close":
			s.open = false
			return [fact("OBJECT_CLOSED", {"object": id, "location": loc}, ["player"])]
		"unlock":
			s.locked = false
			return [fact("OBJECT_UNLOCKED", {"object": id, "with": d.key, "location": loc}, ["player"])]
		"pick_lock":
			var r := Checks.skill(world.player_sheet, "ladinagem", int(d.get("lock_cd", 20)) + int(s.get("tranca_arcana", 0)), world.rules, world.rng)
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


## Dano direto num objeto (magias como Despedaçar). `ignora_rd`: o dano não é reduzido pela RD do objeto.
func danificar(id: String, dano: int, ignora_rd: bool, fonte: String) -> Array:
	_ensure()
	var d := world.db.object_def(id)
	if d.is_empty() or not d.has("break") or not state.has(id) or state[id].broken:
		return []
	var s: Dictionary = state[id]
	var final := dano if ignora_rd else maxi(0, dano - int(d["break"].rd) - int(s.get("rd_extra", 0)))
	s.pv = int(s.pv) - final
	var loc := world.db.location_at(Vector2i(int(d.tile[0]), int(d.tile[1])))
	var out: Array = [fact("OBJECT_DAMAGED", {"object": id, "hit": true, "damage": final, "pv": s.pv, "noise": true, "location": loc, "source": fonte}, ["player"])]
	if int(s.pv) <= 0:
		s.broken = true
		s.locked = false
		out.append(fact("OBJECT_BROKEN", {"object": id, "location": loc, "owner_location": loc}, ["player"]))
	return out


## Controlar Madeira. Fortalecer: +5 na RD e dobra os PV (uma vez) até o fim do dia. Retorcer: a porta emperra (Força
## CD 25 para abrir). Repelir: porta ou baú se abre sozinho e destranca. Modelar: abre passagem numa parede de madeira.
## Tranca Arcana: tranca o objeto (+bônus na CD de Ladinagem e de Força para abrir); o conjurador abre livremente.
func trancar_arcana(id: String, bonus: int) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	if s.is_empty():
		return []
	s.open = false
	s.locked = true
	s.tranca_arcana = bonus
	return [fact("OBJECT_LOCKED", {"object": id, "by": "tranca_arcana", "bonus": bonus}, ["player"])]


## Tranca Arcana (aprimoramento) e truque: abre (destranca e dissipa a tranca) ou só abre/fecha o que não está trancado.
func abrir_magico(id: String, destrancar: bool) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	if s.is_empty() or (bool(s.locked) and not destrancar):
		return []
	s.locked = false
	s.erase("tranca_arcana")
	s.open = not bool(s.open) if not destrancar else true
	return [fact("OBJECT_OPENED" if bool(s.open) else "OBJECT_CLOSED", {"object": id, "by": "magia"}, ["player"])]


## Transmutar Objetos (restaurar): o objeto volta a ficar inteiro.
func restaurar(id: String) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	var d := world.db.object_def(id)
	if s.is_empty() or not d.has("break"):
		return []
	s.broken = false
	s.pv = int(d["break"].get("pv", s.get("pv", 1)))
	return [fact("OBJECT_RESTORED", {"object": id}, ["player"])]


func fortalecer(id: String, ate_dia: int) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	if s.is_empty() or bool(s.get("fortalecida", false)):
		return []
	s.fortalecida = true
	s.rd_extra = int(s.get("rd_extra", 0)) + 5
	s.pv = int(s.pv) * 2
	s.fortalecida_ate = ate_dia
	return [fact("OBJECT_STRENGTHENED", {"object": id}, ["player"])]


func retorcer(id: String) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	if s.is_empty() or world.db.object_def(id).type != "door":
		return []
	s.emperrada = true
	return [fact("OBJECT_TWISTED", {"object": id}, ["player"])]


func repelir(id: String) -> Array:
	_ensure()
	var s: Dictionary = state.get(id, {})
	if s.is_empty() or not ["door", "chest"].has(str(world.db.object_def(id).type)):
		return []
	s.locked = false
	s.emperrada = false
	s.open = true
	return [fact("OBJECT_OPENED", {"object": id, "location": world.db.location_at(Vector2i(int(world.db.object_def(id).tile[0]), int(world.db.object_def(id).tile[1]))), "by": "repelir"}, ["player"])]


## Parede de madeira: o quadrado é '#' dentro de um lugar com "parede_madeira".
func parede_de_madeira(t: Vector2i) -> bool:
	return world.db.tile_info(t).get("name", "") == "parede" and bool(world.db.location(world.db.location_at(t)).get("parede_madeira", false))


func abrir_passagem(t: Vector2i) -> Array:
	if not parede_de_madeira(t):
		return []
	passagens["%d,%d" % [t.x, t.y]] = true
	return [fact("WALL_OPENED", {"tile": [t.x, t.y]}, ["player"])]


## O dia virou: as melhorias de Controlar Madeira acabam (PV voltam ao normal, sem passar do que restava).
func fim_do_dia(dia: int) -> void:
	_ensure()
	for id in state:
		var s: Dictionary = state[id]
		if bool(s.get("fortalecida", false)) and dia >= int(s.get("fortalecida_ate", 0)):
			s.fortalecida = false
			s.rd_extra = 0
			s.pv = maxi(1, int(s.pv) / 2) if int(s.pv) > 0 else int(s.pv)
		s.emperrada = false


## Categoria de tamanho do objeto quebrável ("" se não é quebrável).
func tamanho(id: String) -> String:
	return str(world.db.object_def(id).get("break", {}).get("tamanho", ""))


func to_dict() -> Dictionary:
	_ensure()
	return {"state": state.duplicate(true), "passagens": passagens.duplicate()}


func from_dict(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate(true)
	passagens = (d.get("passagens", {}) as Dictionary).duplicate()
	for k in state:
		state[k].pv = int(state[k].pv)
