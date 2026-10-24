class_name CombatView
extends Node2D
## Combate na tela: grade, planejamento com projeção fantasma, confirmação e
## reprodução cinematográfica dos eventos. A animação NUNCA decide resultados.

signal message(text: String)
signal playback_finished

var npc_layer: NpcLayer
var player_view: PlayerView
var camera: CameraDirector
var cine: CinematicDirector
var fx_post: PostProcess
var fx_glow: Node   # camada de efeitos sem escurecimento (FxLayer.glow)
var plan: Array = []
var mode := "mover"          # mover | atacar | investida | misericordia
var special := false
var spell := "seta_infalivel"   # magia selecionada no modo magia (tecla 4 alterna)
var pungente := false   # Magia Pungente no próximo lançamento
var raspao := true   # C20: usar Golpe de Raspão neste turno (padrão vem da política)
var hover := Vector2i(-1, -1)
var preview: Dictionary = {}
var _queue: Array = []
var playing := false
var _skip := false
var _font: Font


func _ready() -> void:
	z_index = 5
	_font = ThemeDB.fallback_font
	Game.event_published.connect(_on_event)


func active() -> bool:
	return Game.world != null and Game.world.modules.combat.active


func sim() -> CombatSim:
	return Game.world.modules.combat.sim


func my_turn() -> bool:
	return active() and sim().current_id() == "player" and not playing


func cycle_spell() -> void:
	var known: Array = Array(Game.world.player_sheet.spells)
	if Game.world.player_sheet.has_power("raio_arcano"):
		known.append("raio_arcano")
	if known.is_empty():
		message.emit("Você não conhece magias.")
		return
	if mode != "magia" or not known.has(spell):
		spell = known[0]
	else:
		spell = known[(known.find(spell) + 1) % known.size()]
	mode = "magia"
	var sp: Dictionary = GhostPlanner.spell_rule(Game.world.rules, spell)
	var cost := GhostPlanner.spell_cost(Game.world.rules, sp, {"pungente": pungente})
	var c: Dictionary = Game.world.modules.combat.casting_cd(Game.world.player_sheet, sp, cost)
	var warn := ""
	if int(c.concentration_cd) > 0: warn += " · Vontade CD %d (%s)" % [c.concentration_cd, c.reason]
	if not (c.armor as Dictionary).is_empty(): warn += " · Misticismo CD %d (armadura)" % c.armor.cd
	message.emit("Magia: %s (%d PM, %s)%s. [4] troca de magia." % [spell.replace("_", " ").capitalize(), cost,
		"em você" if str(sp.get("alcance", "")) == "pessoal" else "clique no alvo", warn])
	_update_preview()


func toggle_raspao() -> void:
	raspao = not raspao
	for a in plan:
		if a.get("type", "") in ["attack", "charge"]:
			a["raspao"] = raspao
	message.emit("Golpe de Raspão (2 PM ao errar, metade do dano): %s neste turno" % ("usar" if raspao else "não usar"))


func clear_plan() -> void:
	plan.clear()
	preview = {}
	queue_redraw()


func _actor_view(id: String) -> Node2D:
	if id == "player":
		return player_view
	return npc_layer.creature_views.get(id)


# --- Planejamento -------------------------------------------------------------------
func _ghost_tile() -> Vector2i:
	var g: Dictionary = Game.world.modules.combat.preview(plan) if not plan.is_empty() else {}
	if g.get("valid", false):
		return g.end_tile
	return sim().c("player").tile


func _ghost_sim() -> CombatSim:
	var s := sim().clone()
	var g := GhostPlanner.simulate(s, "player", plan)
	# reaplica no clone para saber posição/orçamento após o plano (o original não muda)
	for st in g.steps:
		if st.ok and st.has("to"):
			s.c("player").tile = st.to
	s.budget = g.budget_after
	return s


func candidate_actions(t: Vector2i) -> Array:
	if not my_turn():
		return []
	var gs := _ghost_sim()
	var target := gs.occupant(t, "player")
	var me: Vector2i = gs.c("player").tile
	match mode:
		"mover":
			if target != "" and gs.is_enemy("player", target):
				var acts: Array = []
				if CombatSim.cheb(me, gs.c(target).tile) > 1:
					var path := gs.trim_path("player", gs.find_path("player", gs.c(target).tile), gs.speed_squares("player"))
					if not path.is_empty():
						acts.append({"type": "move", "path": path.map(func(x): return [x.x, x.y])})
				acts.append({"type": "attack", "target": target, "special": special, "raspao": raspao})
				return acts
			var path := gs.find_path("player", t, false)
			path = gs.trim_path("player", path, gs.speed_squares("player"))
			if path.is_empty():
				return []
			return [{"type": "move", "path": path.map(func(x): return [x.x, x.y])}]
		"investida":
			if target == "" or not gs.is_enemy("player", target):
				return []
			var dir := Vector2i(signi(gs.c(target).tile.x - me.x), signi(gs.c(target).tile.y - me.y))
			var path: Array = []
			var p := me
			for i in 30:
				p += dir
				if CombatSim.cheb(p, gs.c(target).tile) == 0:
					break
				path.append([p.x, p.y])
				if CombatSim.cheb(p, gs.c(target).tile) == 1:
					break
			return [{"type": "charge", "target": target, "path": path}]
		"misericordia":
			if target == "":
				return []
			return [{"type": "coup", "target": target}]
		"atirar":
			if target == "" or not gs.is_enemy("player", target):
				return []
			var idx := -1
			for i in gs.c("player").sheet.attacks.size():
				if gs.c("player").sheet.attacks[i].get("distancia", false): idx = i
			if idx < 0:
				message.emit("Sem arma de ataque à distância equipada.")
				return []
			return [{"type": "attack", "target": target, "attack": idx, "special": special, "raspao": raspao}]
		"magia":
			var sp: Dictionary = GhostPlanner.spell_rule(Game.world.rules, spell)
			if str(sp.get("alcance", "")) == "pessoal":
				return [{"type": "cast", "spell": spell, "targets": ["player"], "pungente": pungente}]
			if target == "" or not gs.is_enemy("player", target):
				return []
			return [{"type": "cast", "spell": spell, "targets": [target], "target": target, "pungente": pungente}]
	return []


func _update_preview() -> void:
	var cand := candidate_actions(hover)
	preview = Game.world.modules.combat.preview(plan + cand) if not (plan + cand).is_empty() else {}
	queue_redraw()


func add_hover_to_plan() -> void:
	var cand := candidate_actions(hover)
	if cand.is_empty():
		return
	var g: Dictionary = Game.world.modules.combat.preview(plan + cand)
	if not g.valid:
		message.emit("Inválido: " + str(g.steps[-1].reason))
		return
	plan.append_array(cand)
	_update_preview()


func undo() -> void:
	if not plan.is_empty():
		plan.pop_back()
	_update_preview()


func confirm() -> void:
	if plan.is_empty() or not my_turn():
		return
	# guarda o que o fantasma previa, para os momentos "contra as probabilidades" e "deu errado"
	if cine and not preview.is_empty():
		cine.expectations.clear()
		for st in preview.get("steps", []):
			if st.get("ok", false) and str(st.action.get("type", "")) in ["attack", "charge", "ataque_extra"]:
				cine.expectations[st.action.target] = float(st.get("hit_chance", -1.0))
	var r := Game.send("ExecutePlan", {"actions": plan})
	if not r.accepted:
		message.emit("Plano rejeitado: " + "; ".join(r.errors))
	plan.clear()
	preview = {}
	queue_redraw()


func end_turn() -> void:
	if not my_turn():
		return
	plan.clear()
	preview = {}
	Game.send("EndTurn")


func drink_potion() -> void:
	if not Game.world.modules.state.has_item("pocao_cura"):
		message.emit("Sem poção.")
		return
	plan.append({"type": "drink", "item": "pocao_cura"})
	_update_preview()


func stand_up() -> void:
	plan.append({"type": "stand"})
	_update_preview()


## Poderes de ação livre (Ímpeto, Velocidade Ladina, Emboscar): entram no plano e o fantasma mostra o efeito.
func use_power(p: String) -> void:
	var names := {"impeto": "Ímpeto (+6m nesta rodada)", "velocidade_ladina": "Velocidade Ladina (+1 ação de movimento)", "emboscar": "Emboscar (+1 ação padrão)"}
	if not Game.world.player_sheet.has_power(p):
		message.emit("Você não tem o poder %s." % names[p].get_slice(" (", 0))
		return
	plan.append({"type": p})
	message.emit("Planejado: " + names[p])
	_update_preview()


## Ataque Extra (guerreiro 6º nível): repete o alvo do último ataque planejado.
func extra_attack() -> void:
	for i in range(plan.size() - 1, -1, -1):
		if plan[i].get("type", "") in ["attack", "charge"]:
			plan.append({"type": "ataque_extra", "target": plan[i].target})
			message.emit("Planejado: Ataque Extra (2 PM) em " + Narrator._name(plan[i].target))
			_update_preview()
			return
	message.emit("Planeje um ataque primeiro; o Ataque Extra repete o alvo.")


func toggle_pungente() -> void:
	if not Game.world.player_sheet.has_power("magia_pungente"):
		pungente = false
		message.emit("Você não tem o poder Magia Pungente.")
		return
	pungente = not pungente
	message.emit("Magia Pungente (+1 PM, CD +2): %s" % ("ligada" if pungente else "desligada"))
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not active():
		return
	if playing and (event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed)):
		_skip = true
		if cine: cine.skip()
		get_viewport().set_input_as_handled()
		return
	if not my_turn():
		return
	if event is InputEventMouseMotion:
		var t := Game.db.world_to_tile(get_global_mouse_position())
		if t != hover:
			hover = t
			_update_preview()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hover = Game.db.world_to_tile(get_global_mouse_position())
			add_hover_to_plan()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			undo()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER: confirm()
			KEY_SPACE: end_turn()
			KEY_BACKSPACE: undo()
			KEY_1: mode = "mover"; _update_preview()
			KEY_2: mode = "investida"; _update_preview()
			KEY_3: mode = "misericordia"; _update_preview()
			KEY_4: cycle_spell()
			KEY_5: drink_potion()
			KEY_6: mode = "atirar"; message.emit("Modo tiro: clique no alvo (sem se mover)."); _update_preview()
			KEY_Q: special = not special; message.emit("Ataque Especial (1 PM, +4): %s" % ("ligado" if special else "desligado")); _update_preview()
			KEY_L: stand_up()
			KEY_R: toggle_raspao()
			KEY_I: use_power("impeto")
			KEY_V: use_power("velocidade_ladina")
			KEY_M: use_power("emboscar")
			KEY_P: toggle_pungente()
			KEY_X: extra_attack()
			KEY_A: cycle_policy("ataque_poderoso")
			KEY_D: cycle_policy("combate_defensivo")
			_: return
		get_viewport().set_input_as_handled()


# --- Desenho ---------------------------------------------------------------------------
func _draw() -> void:
	if not active():
		return
	var s := sim()
	var center: Vector2i = s.c("player").tile
	var rng := 9
	for y in range(center.y - rng, center.y + rng + 1):
		for x in range(center.x - rng - 3, center.x + rng + 4):
			var t := Vector2i(x, y)
			if not s.walk_fn.call(t):
				continue
			var r := Rect2(Vector2(x * 32, y * 32), Vector2(32, 32))
			draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
			if Game.db.is_difficult(t):
				draw_rect(r.grow(-10), Color(0.8, 0.6, 0.2, 0.18))
	# alcance de movimento restante
	if my_turn():
		var gs := _ghost_sim()
		var me: Vector2i = gs.c("player").tile
		if gs.can_spend("movimento"):
			var sp := gs.speed_squares("player")
			for y in range(me.y - sp, me.y + sp + 1):
				for x in range(me.x - sp, me.x + sp + 1):
					var t := Vector2i(x, y)
					if CombatSim.cheb(t, me) <= sp and gs.passable(t, "player") and gs.occupant(t, "player") == "":
						draw_rect(Rect2(Vector2(x * 32 + 2, y * 32 + 2), Vector2(28, 28)), Color(0.3, 0.6, 1.0, 0.10))
	# combatente atual
	var cur := s.current_id()
	if s.combatants.has(cur):
		var ct: Vector2i = s.c(cur).tile
		draw_rect(Rect2(Vector2(ct.x * 32, ct.y * 32), Vector2(32, 32)), Color(1, 0.85, 0.3, 0.6), false, 2.0)
	# fantasma
	if preview.is_empty():
		return
	var pos := Game.db.tile_to_world(s.c("player").tile)
	var y_text := 0
	for st in preview.steps:
		var a: Dictionary = st.action
		if not st.ok:
			var a_bad: Dictionary = st.action
			var at := pos
			if a_bad.has("path") and not a_bad.path.is_empty():
				var lp: Array = a_bad.path[-1]
				at = Game.db.tile_to_world(Vector2i(int(lp[0]), int(lp[1])))
				draw_line(pos, at, Color(1, 0.35, 0.35, 0.7), 2.0)
			draw_rect(Rect2(at - Vector2(15, 15), Vector2(30, 30)), Color(1, 0.3, 0.3, 0.5), false, 2.0)
			draw_string(_font, at + Vector2(-70, -20), "✘ " + str(st.reason), HORIZONTAL_ALIGNMENT_LEFT, 200, 8, Color(1, 0.45, 0.45))
			break
		if a.type in ["move", "charge"]:
			var prev := pos
			for p in a.path:
				var w := Game.db.tile_to_world(Vector2i(int(p[0]), int(p[1])))
				draw_line(prev, w, Color(0.5, 0.8, 1.0, 0.8), 2.0)
				prev = w
			pos = prev
			draw_circle(pos, 6, Color(0.5, 0.8, 1.0, 0.45))
			if a.type == "move":
				draw_string(_font, pos + Vector2(8, -8), "%d q" % int(st.cost), HORIZONTAL_ALIGNMENT_LEFT, 60, 8, Color(0.7, 0.9, 1))
		if a.type in ["attack", "charge", "ataque_extra"]:
			var tp := Game.db.tile_to_world(s.c(a.target).tile)
			draw_line(pos, tp, Color(1, 0.5, 0.3, 0.9), 1.5)
			var txt := "Acerto %d%%  Crít %d%%  ~%.1f dano" % [int(st.hit_chance * 100), int(st.crit_chance * 100), st.avg_damage]
			draw_string(_font, tp + Vector2(-60, -30 - y_text), txt, HORIZONTAL_ALIGNMENT_LEFT, 200, 8, Color(1, 0.85, 0.5))
			y_text += 10
		if a.type == "cast":
			for tg in a.get("targets", []):
				var tp := Game.db.tile_to_world(s.c(tg).tile)
				draw_line(pos, tp, Color(0.6, 0.6, 1.0, 0.9), 1.5)
				draw_string(_font, tp + Vector2(-60, -30), "Seta Infalível: acerta sempre, ~%.1f dano (−%d PM)" % [st.avg_damage, int(st.get("pm_cost", 1))], HORIZONTAL_ALIGNMENT_LEFT, 220, 8, Color(0.75, 0.8, 1))
		if a.type == "coup":
			var tp := Game.db.tile_to_world(s.c(a.target).tile)
			draw_string(_font, tp + Vector2(-50, -30), "Golpe de misericórdia", HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color(1, 0.4, 0.4))
	var b: Dictionary = preview.get("budget_after", {})
	draw_string(_font, Game.db.tile_to_world(s.c("player").tile) + Vector2(-40, 30), "Padrão %d · Movimento %d" % [int(b.get("std", 0)), int(b.get("move", 0))], HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color(0.85, 0.85, 0.95))


func _process(_d: float) -> void:
	if active():
		queue_redraw()


# --- Reprodução cinematográfica ----------------------------------------------------------
func _on_event(e: GameEvent) -> void:
	if e.event_type in ["COMBAT_STARTED", "COMBAT_MOVED", "ATTACK_RESOLVED", "COUP_DE_GRACE", "BLEED_CHECK", "TURN_STARTED", "COMBAT_ENDED", "STOOD_UP",
			"BUFF_APPLIED", "HEALED", "SPELL_FAILED", "REACTION", "POWER_USED"]:
		_queue.append(e)
		if not playing:
			_play()


func _speed() -> float:
	var s: float = float(Game.settings.combat_speed)
	return 0.0 if s <= 0.0 else 1.0 / s


func _wait(sec: float) -> void:
	var k := _speed()
	if k <= 0.0 or _skip:
		return
	await get_tree().create_timer(sec * k).timeout


func _play() -> void:
	playing = true
	while not _queue.is_empty():
		var e: GameEvent = _queue.pop_front()
		await _play_one(e)
	playing = false
	_skip = false
	camera.focus_override = null
	if Game.world and Game.world.modules.combat.active:
		npc_layer.sync_creatures()
		player_view.global_position = Game.db.tile_to_world(sim().c("player").tile)
	playback_finished.emit()


func _play_one(e: GameEvent) -> void:
	var p := e.payload
	match e.event_type:
		"COMBAT_STARTED":
			npc_layer.sync_creatures()
			player_view.global_position = Game.db.tile_to_world(sim().c("player").tile)
			camera.punch(1.1, 0.4)
			await _wait(0.4)
		"TURN_STARTED":
			if cine: cine.new_turn()
			if p.actor == "player":
				raspao = Game.world.modules.combat.power_policy.get("golpe_raspao", "auto") == "auto"
			var v := _actor_view(p.actor)
			if v and p.actor != "player":
				camera.focus_override = v.global_position
			else:
				camera.focus_override = null
			await _wait(0.15)
		"COMBAT_MOVED":
			var v := _actor_view(p.actor)
			if v == null:
				return
			var pts: Array = []
			for t in p.path:
				pts.append(Game.db.tile_to_world(Vector2i(int(t[0]), int(t[1]))))
			if _speed() <= 0.0 or _skip:
				v.global_position = pts[-1]
				return
			var tw := create_tween()
			var av: ActorView = v.view if v is PlayerView else v
			av.walking = true
			var prev: Vector2 = v.global_position
			for pt in pts:
				tw.tween_callback(av.face_dir.bind(pt - prev))
				tw.tween_property(v, "global_position", pt, (0.09 if p.get("charge", false) else 0.14) * _speed())
				prev = pt
			await tw.finished
			av.walking = false
		"ATTACK_RESOLVED", "COUP_DE_GRACE":
			await _play_attack(p, e.event_type == "COUP_DE_GRACE")
		"BUFF_APPLIED":
			var bv := _actor_view(p.actor)
			if bv:
				ImpactFx.aura(_fxp(), bv.global_position, Color(0.6, 0.75, 1.0))
				_float_text(bv.global_position, "+%d Defesa" % int(p.get("defense", 0)), Color(0.7, 0.85, 1.0))
				if fx_post: fx_post.flash(0.15, Color(0.7, 0.8, 1.0))
			await _wait(0.35)
		"HEALED":
			var hv := _actor_view(p.target)
			if hv:
				ImpactFx.aura(_fxp(), hv.global_position, Color(0.55, 1.0, 0.6), true)
				_float_text(hv.global_position, "+%d" % int(p.amount), Color(0.55, 1.0, 0.6))
			await _wait(0.35)
		"SPELL_FAILED":
			var fv := _actor_view(p.caster)
			if fv:
				ImpactFx.shockwave(_fxp(), fv.global_position + Vector2(0, -10), 10.0, Color(0.5, 0.5, 0.6, 0.8))
				_float_text(fv.global_position, "magia perdida", Color(0.7, 0.7, 0.8))
			await _wait(0.35)
		"REACTION", "POWER_USED":
			var rv := _actor_view(p.actor)
			if rv:
				_float_text(rv.global_position, "Ataque Reflexo!" if e.event_type == "REACTION" else str(p.power).replace("_", " ").capitalize() + "!", Color(1.0, 0.8, 0.4))
				if e.event_type == "POWER_USED":
					ImpactFx.dust(_fxp(), rv.global_position, Vector2.ZERO, 8)
					(rv.view if rv is PlayerView else rv).squash(0.15)
			await _wait(0.2)
		"BLEED_CHECK":
			var v := _actor_view(p.actor)
			if v: _float_text(v.global_position, "sangra -%d" % p.lost if p.lost > 0 else "estável", Color(0.9, 0.2, 0.2))
			await _wait(0.3)
		"COMBAT_ENDED":
			camera.focus_override = null
			npc_layer.sync_all()
			await _wait(0.3)


## Encenação de um ataque: momento cinematográfico (se merecer) → antecipação → rastro do golpe ou da
## magia → impacto (hit stop, partículas, recuo e flash do alvo, tremor) ou esquiva → números.
func _play_attack(p: Dictionary, coup: bool) -> void:
	var a := _actor_view(p.attacker)
	var t := _actor_view(p.target)
	if a == null or t == null:
		return
	var av: ActorView = a.view if a is PlayerView else a
	var tv: ActorView = t.view if t is PlayerView else t
	var hit: bool = p.get("hit", true)
	var crit: bool = p.get("crit", false)
	var spell: bool = p.get("spell", false)
	var a_pos: Vector2 = a.global_position + Vector2(0, -10)
	var t_pos: Vector2 = t.global_position + Vector2(0, -10)
	var dir: Vector2 = (t_pos - a_pos).normalized()
	var fast: bool = _speed() <= 0.0 or _skip
	var m: Dictionary = {} if (fast or cine == null) else cine.evaluate(p, sim())
	if not m.is_empty():
		await cine.begin(m, a_pos, t_pos)
	var kind := _weapon_kind(p)
	if not fast:
		var wind := av.play_attack(dir, crit or coup)
		await _wait(wind + 0.03)
		match str(p.get("weapon", "")):
			"Seta Infalível":
				ImpactFx.spell_bolt(_fxp(), a_pos, t_pos, Color(0.7, 0.6, 1.0), 0.2)
				await _wait(0.2)
			"Raio Arcano":
				ImpactFx.spell_bolt(_fxp(), a_pos, t_pos, Color(1.0, 0.8, 0.55), 0.16, 4.0)
				await _wait(0.16)
			"Toque Chocante":
				ImpactFx.lightning(_fxp(), a_pos, t_pos)
				if fx_post: fx_post.flash(0.25, Color(0.75, 0.9, 1.0))
			_:
				if not spell:
					ImpactFx.slash_trail(_fxp(), a_pos, t_pos, kind, hit, crit)
	if hit:
		if not fast:
			if not spell:
				ImpactFx.impact_burst(_fxp(), t_pos, dir, kind, crit, clampf(float(p.get("damage", 1)) / 6.0, 0.6, 2.0))
			tv.play_hit(dir, clampf(float(p.get("damage", 1)) / 8.0, 0.5, 1.6), crit)
			ImpactFx.hit_stop(get_tree(), 0.09 if crit else 0.045, 0.18 if crit else 0.0)
			if crit and fx_post:
				fx_post.flash(0.3, Color(1.0, 0.95, 0.85))
				fx_post.aberration(0.8)
		camera.react(p.get("tags", []))
	elif not fast:
		tv.play_dodge(dir)
	_float_text(t.global_position, (("%d!" if crit else "%d") % int(p.damage)) if hit else ("falha" if p.get("camo_roll", 0) > 0 else "erra"),
		Color(1, 0.3, 0.2) if crit else (Color(1, 0.9, 0.5) if hit else Color(0.7, 0.8, 1)))
	if t is ActorView and p.has("pv_after"):
		var sh: CharacterSheet = sim().c(p.target).sheet if sim() and sim().combatants.has(p.target) else null
		if sh: t.set_hp(int(p.pv_after), sh.pv_max)
	elif t is PlayerView:
		t.view.set_down(int(p.get("pv_after", 1)) <= 0)
	if not m.is_empty():
		await cine.reaction(m)
	else:
		await _wait(0.3)


func _fxp() -> Node:
	return fx_glow if fx_glow != null else get_parent()


func _weapon_kind(p: Dictionary) -> String:
	if p.get("spell", false):
		return "magia"
	var s := sim()
	if s and s.combatants.has(p.attacker):
		for atk in s.c(p.attacker).sheet.attacks:
			if str(atk.get("nome", "")) == str(p.get("weapon", "")) and atk.has("tipo"):
				return str(atk.tipo)
	var w := str(p.get("weapon", "")).to_lower()
	if w.contains("clava") or w.contains("funda") or w.contains("maça") or w.contains("martelo"): return "impacto"
	if w.contains("mordida") or w.contains("adaga") or w.contains("lança") or w.contains("chifre"): return "perfuracao"
	return "corte"


func _float_text(at: Vector2, txt: String, col: Color) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = at + Vector2(-20, -40)
	l.z_index = 40
	l.pivot_offset = Vector2(20, 8)
	l.scale = Vector2.ONE * 1.7
	_fxp().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 22, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Ataque Poderoso / Combate Defensivo (LB p.124-125): alterna a política do poder opcional.
func cycle_policy(power: String) -> void:
	if not Game.world.player_sheet.has_power(power):
		return
	var opts: Array = CombatModule.POWER_POLICIES[power]
	var cur: String = Game.world.modules.combat.power_policy.get(power, opts[0])
	var nxt: String = opts[(opts.find(cur) + 1) % opts.size()]
	Game.send("SetPowerPolicy", {"power": power, "policy": nxt})
	message.emit("%s: %s" % [PowerTreePanel.NAMES.get(power, power), nxt])
	_update_preview()
