class_name UiRoot
extends CanvasLayer
## Toda a interface em código (sem cenas), legível a 640x360. Só lê projeções e
## envia comandos via Game.send().

signal request_new_game(feminine: bool)
signal request_load(slot: String)

var theme_res: Theme
var hud_top: Label
var hud_right: Label
var log_box: VBoxContainer
var prompt: Label
var signals_label: Label
var panel_interact: PanelContainer
var interact_list: VBoxContainer
var panel_dialogue: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_opts: VBoxContainer
var panel_journal: PanelContainer
var journal_body: VBoxContainer
var panel_shop: PanelContainer
var shop_list: VBoxContainer
var shop_npc := ""
var panel_pause: PanelContainer
var panel_title: Control
var panel_over: PanelContainer
var combat_bar: PanelContainer
var combat_info: Label
var _log_lines: Array[String] = []
var _interact_actions: Array = []
var _dlg_shown_text := ""
var combat_view: CombatView


func _ready() -> void:
	layer = 10
	theme_res = _make_theme()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_res
	add_child(root)
	_build_hud(root)
	_build_interact(root)
	_build_dialogue(root)
	_build_journal(root)
	_build_shop(root)
	_build_combat_bar(root)
	_build_pause(root)
	_build_gameover(root)
	_build_title(root)
	Game.event_published.connect(_on_event)
	Game.mode_changed.connect(func(_m): _refresh_mode())
	_refresh_mode()


# --- Tema ---------------------------------------------------------------------------
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 9
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.11, 0.92)
	sb.border_color = Color(0.78, 0.63, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	t.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.17, 0.13, 0.2)
	bn.border_color = Color(0.5, 0.4, 0.25)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(2)
	bn.content_margin_left = 6; bn.content_margin_right = 6; bn.content_margin_top = 2; bn.content_margin_bottom = 2
	var bh := bn.duplicate(); bh.bg_color = Color(0.3, 0.22, 0.32); bh.border_color = Color(0.9, 0.75, 0.4)
	var bd := bn.duplicate(); bd.bg_color = Color(0.12, 0.1, 0.13); bd.border_color = Color(0.3, 0.27, 0.25)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bh)
	t.set_stylebox("focus", "Button", bh)
	t.set_stylebox("disabled", "Button", bd)
	t.set_color("font_color", "Button", Color(0.95, 0.9, 0.8))
	t.set_color("font_color", "Label", Color(0.95, 0.92, 0.85))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0))
	t.set_constant("outline_size", "Label", 2)
	t.set_font_size("font_size", "Button", 9)
	return t


func _panel(parent: Control, anchor_preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	p.set_anchors_preset(anchor_preset)
	return p


func _label(text: String = "", size: int = 9) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


# --- HUD ------------------------------------------------------------------------------
func _build_hud(root: Control) -> void:
	hud_top = _label("", 9)
	hud_top.position = Vector2(6, 4)
	hud_top.size = Vector2(420, 24)
	hud_top.autowrap_mode = TextServer.AUTOWRAP_OFF
	root.add_child(hud_top)
	hud_right = _label("", 9)
	hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_right.position = Vector2(400, 4)
	hud_right.size = Vector2(234, 40)
	root.add_child(hud_right)
	signals_label = _label("", 8)
	signals_label.position = Vector2(6, 26)
	signals_label.size = Vector2(380, 30)
	signals_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	root.add_child(signals_label)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(6, 270)
	log_box.size = Vector2(400, 80)
	log_box.add_theme_constant_override("separation", 0)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)
	prompt = _label("", 9)
	prompt.position = Vector2(200, 238)
	prompt.size = Vector2(240, 14)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	root.add_child(prompt)


func log_msg(text: String) -> void:
	if text.strip_edges() == "":
		return
	_log_lines.append(text)
	if _log_lines.size() > 7:
		_log_lines = _log_lines.slice(_log_lines.size() - 7)
	for c in log_box.get_children():
		c.queue_free()
	for i in _log_lines.size():
		var l := _label(_log_lines[i], 8)
		l.modulate.a = 0.45 + 0.55 * float(i + 1) / _log_lines.size()
		log_box.add_child(l)


func update_hud() -> void:
	if Game.world == null:
		return
	var w: WorldState = Game.world
	var c := w.clock.calendar()
	var wm: WeatherModule = w.modules.weather
	var loc := Game.db.location(Game.db.location_at(Game.player_tile()))
	var weather_txt: String = ("%s, %d°C" % [wm.region.condition, wm.region.temp_c]) if wm.enabled else "—"
	hud_top.text = "Dia %d do mês %d, ano %d — %02d:%02d · %s · %s" % [c.day, c.month, c.year, c.hour, c.minute, weather_txt, loc.get("name", "Ermo")]
	var s := w.player_sheet
	var sneak: bool = w.modules.combat.stance_sneak
	hud_right.text = "PV %d/%d · PM %d/%d · T$ %d\n%s" % [s.pv, s.pv_max, s.pm, s.pm_max, w.player.gold, "[Furtivo]" if sneak else ""]
	var sig: Array = []
	for x in w.modules.exploration.nearby_signals(2):
		sig.append(x.signal)
	for x in w.modules.combat.creature_signals():
		sig.append(x.signal)
	signals_label.text = "\n".join(sig.slice(0, 2))


# --- Menu de interação -------------------------------------------------------------------
func _build_interact(root: Control) -> void:
	panel_interact = _panel(root, Control.PRESET_CENTER_RIGHT)
	panel_interact.position = Vector2(440, 90)
	panel_interact.custom_minimum_size = Vector2(190, 0)
	var v := VBoxContainer.new()
	panel_interact.add_child(v)
	v.add_child(_label("Ações (1-9, Esc fecha)", 8))
	interact_list = VBoxContainer.new()
	interact_list.add_theme_constant_override("separation", 2)
	v.add_child(interact_list)
	panel_interact.visible = false


func show_interact(actions: Array) -> void:
	_interact_actions = actions
	for c in interact_list.get_children():
		c.queue_free()
	if actions.is_empty():
		panel_interact.visible = false
		log_msg("Nada para fazer aqui.")
		return
	for i in actions.size():
		var a: Dictionary = actions[i]
		interact_list.add_child(_button("%d. %s" % [i + 1, a.label], _do_interact.bind(i)))
	panel_interact.visible = true


func _do_interact(i: int) -> void:
	panel_interact.visible = false
	if i < 0 or i >= _interact_actions.size():
		return
	var a: Dictionary = _interact_actions[i]
	var r := Game.send(a.cmd, a.payload)
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))


# --- Diálogo ----------------------------------------------------------------------------------
func _build_dialogue(root: Control) -> void:
	panel_dialogue = _panel(root, Control.PRESET_BOTTOM_WIDE)
	panel_dialogue.offset_top = -150
	panel_dialogue.offset_left = 20
	panel_dialogue.offset_right = -20
	panel_dialogue.offset_bottom = -8
	var v := VBoxContainer.new()
	panel_dialogue.add_child(v)
	dlg_name = _label("", 10)
	dlg_name.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	v.add_child(dlg_name)
	dlg_text = _label("", 9)
	dlg_text.custom_minimum_size = Vector2(560, 30)
	v.add_child(dlg_text)
	dlg_opts = VBoxContainer.new()
	dlg_opts.add_theme_constant_override("separation", 1)
	v.add_child(dlg_opts)
	panel_dialogue.visible = false


func refresh_dialogue() -> void:
	var dlg: DialogueModule = Game.world.modules.dialogue
	var view := dlg.view()
	if view.is_empty():
		panel_dialogue.visible = false
		return
	panel_dialogue.visible = true
	dlg_name.text = view.name
	var base: String = view.text
	if base != _dlg_shown_text:
		_dlg_shown_text = base
		dlg_text.text = base
		var d := Game.db.npc_def(view.npc)
		Game.dialogue_provider.verbalize_async(view.npc, base, {"name": d.get("name", ""), "profession": d.get("profession", ""),
			"allowed_names": ["Tomas", "Hilda", "Otto", "Lena", "Valkaria", "Khalmyr", "Kael", "Dorn", "Elsa", "Rosana"]},
			func(t: String): if _dlg_shown_text == base: dlg_text.text = t)
	for c in dlg_opts.get_children():
		c.queue_free()
	for o in view.options:
		dlg_opts.add_child(_button("%d. %s" % [o.index + 1, o.text], _choose.bind(o.index)))


func _choose(i: int) -> void:
	var r := Game.send("ChooseOption", {"index": i})
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))
	refresh_dialogue()


func dialogue_key(n: int) -> void:
	if panel_dialogue.visible:
		_choose(n)


# --- Diário ------------------------------------------------------------------------------------
func _build_journal(root: Control) -> void:
	panel_journal = _panel(root, Control.PRESET_FULL_RECT)
	panel_journal.offset_left = 30; panel_journal.offset_top = 20; panel_journal.offset_right = -30; panel_journal.offset_bottom = -20
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_journal.add_child(sc)
	journal_body = VBoxContainer.new()
	journal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(journal_body)
	panel_journal.visible = false


func toggle_journal() -> void:
	panel_journal.visible = not panel_journal.visible
	if panel_journal.visible:
		refresh_journal()


func _h(text: String) -> Label:
	var l := _label(text, 10)
	l.add_theme_color_override("font_color", Color(1, 0.82, 0.4))
	return l


func refresh_journal() -> void:
	for c in journal_body.get_children():
		c.queue_free()
	var w: WorldState = Game.world
	var ex: ExplorationModule = w.modules.exploration
	journal_body.add_child(_h("Diário — %s  [J fecha]" % Game.db.mystery.title + ("  (resolvido)" if ex.mystery_state == "resolvido" else ("  (perdido)" if ex.mystery_state == "perdido" else ""))))
	journal_body.add_child(_h("Pistas"))
	for n in ex.notes:
		journal_body.add_child(_label("• " + str(n.text), 9))
	journal_body.add_child(_h("Hipóteses (você decide no que acredita)"))
	for h in ex.hypothesis_view():
		var row := HBoxContainer.new()
		var l := _label("%s  [%s]  a favor: %d · contra: %d" % [h.text, h.state, h.supporting.size(), h.contradicting.size()], 9)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 330
		row.add_child(l)
		for st in ["acredito", "descartada", "aberta"]:
			row.add_child(_button(st, func(): Game.send("MarkHypothesis", {"hypothesis_id": h.id, "state": st}); refresh_journal()))
		journal_body.add_child(row)
	journal_body.add_child(_h("Ficha"))
	var s := w.player_sheet
	journal_body.add_child(_label("%s — Guerreiro humano nível %d. PV %d/%d, PM %d/%d, Defesa %d. Luta +%d (Espada longa 1d8+%d, 19/x2). Percepção +%d, Furtividade +%d (−1 armadura), Intuição +%d, Investigação +%d. %s" % [
		s.name, s.level, s.pv, s.pv_max, s.pm, s.pm_max, s.defense(w.rules), s.skill_value("luta", w.rules), s.attrs["for"], s.skill_value("percepcao", w.rules),
		s.skill_value("furtividade", w.rules), s.skill_value("intuicao", w.rules), s.skill_value("investigacao", w.rules), ("Devoção: " + s.devotion) if s.devotion != "" else ""], 9))
	var inv: Array = []
	for it in w.modules.state.inventory:
		inv.append("%s x%d" % [Game.db.items.get(it, {}).get("name", it), w.modules.state.inventory[it]])
	journal_body.add_child(_label("Inventário: %s · Ouro: T$ %d" % [", ".join(inv) if not inv.is_empty() else "—", w.player.gold], 9))
	var mem: MemoryModule = w.modules.memory
	if mem.enabled:
		var rep := mem.settlement_reputation()
		journal_body.add_child(_h("Reputação"))
		journal_body.add_child(_label("Na vila, %d pessoa(s) sabem algo sobre você (saldo %+.0f). Reputação só muda quando alguém fica sabendo." % [rep.known_by, rep.value], 9))
	var cr: CrimeModule = w.modules.crime
	if cr.enabled and cr.total_fines() > 0:
		journal_body.add_child(_label("Multas pendentes: T$ %d (pague à Guarda)." % cr.total_fines(), 9))
	journal_body.add_child(_h("Regras"))
	journal_body.add_child(_label("%d regras com fonte e página; %d pendentes de revisão humana. Mecânicas originais do jogo estão marcadas." % [w.rules.size(), w.rules.unverified_ids().size()], 8))


# --- Loja --------------------------------------------------------------------------------------
func _build_shop(root: Control) -> void:
	panel_shop = _panel(root, Control.PRESET_CENTER)
	panel_shop.position = Vector2(200, 80)
	panel_shop.custom_minimum_size = Vector2(240, 0)
	var v := VBoxContainer.new()
	panel_shop.add_child(v)
	v.add_child(_h("Comprar"))
	shop_list = VBoxContainer.new()
	v.add_child(shop_list)
	v.add_child(_button("Fechar", func(): panel_shop.visible = false))
	panel_shop.visible = false


func open_shop(npc: String) -> void:
	shop_npc = npc
	for c in shop_list.get_children():
		c.queue_free()
	var eco: EconomyModule = Game.world.modules.economy
	for it in Game.db.economy.get("shops", {}).get(npc, []):
		var price: int = eco.price(it) if eco.enabled else int(Game.db.items[it].price)
		shop_list.add_child(_button("%s — T$ %d" % [Game.db.items[it].name, price], func():
			var r := Game.send("Buy", {"npc_id": npc, "item": it})
			if not r.accepted: log_msg("✘ " + "; ".join(r.errors))
			open_shop(npc)))
	panel_shop.visible = true


# --- Barra de combate -------------------------------------------------------------------------
func _build_combat_bar(root: Control) -> void:
	combat_bar = _panel(root, Control.PRESET_TOP_WIDE)
	combat_bar.offset_top = 40
	combat_bar.offset_left = 120
	combat_bar.offset_right = -120
	var v := VBoxContainer.new()
	combat_bar.add_child(v)
	combat_info = _label("", 8)
	v.add_child(combat_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	for spec in [["1 Mover/Atacar", func(): combat_view.mode = "mover"], ["2 Investida", func(): combat_view.mode = "investida"],
			["3 Misericórdia", func(): combat_view.mode = "misericordia"], ["Q Especial", func(): combat_view.special = not combat_view.special],
			["L Levantar", func(): combat_view.stand_up()], ["⌫ Desfazer", func(): combat_view.undo()],
			["↵ Confirmar", func(): combat_view.confirm()], ["␣ Fim do turno", func(): combat_view.end_turn()]]:
		var b := _button(spec[0], spec[1])
		b.add_theme_font_size_override("font_size", 8)
		row.add_child(b)
	combat_bar.visible = false


func update_combat_bar() -> void:
	var c: CombatModule = Game.world.modules.combat
	if not c.active:
		return
	var s := c.sim
	var order: Array = []
	for id in s.order:
		var x := s.c(id)
		var nm: String = "Você" if id == "player" else x.sheet.name
		order.append(("▶" if id == s.current_id() else "") + "%s %d/%d" % [nm, x.sheet.pv, x.sheet.pv_max])
	var mine := s.current_id() == "player"
	combat_info.text = "Rodada %d · %s\n%s" % [s.round_no, " | ".join(order),
		("Seu turno — clique para planejar (modo: %s%s). Botão direito desfaz. Enter confirma." % [combat_view.mode, ", ESPECIAL" if combat_view.special else ""]) if mine else "Turno dos inimigos..."]


# --- Pausa / opções ------------------------------------------------------------------------------
func _build_pause(root: Control) -> void:
	panel_pause = _panel(root, Control.PRESET_CENTER)
	panel_pause.position = Vector2(220, 40)
	panel_pause.custom_minimum_size = Vector2(200, 0)
	panel_pause.visible = false


func toggle_pause() -> void:
	panel_pause.visible = not panel_pause.visible
	if panel_pause.visible:
		_refresh_pause()


func _refresh_pause() -> void:
	for c in panel_pause.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	panel_pause.add_child(v)
	v.add_child(_h("Pausa"))
	v.add_child(_button("Continuar", func(): panel_pause.visible = false))
	v.add_child(_button("Salvar (F5)", func(): log_msg("Jogo salvo." if Game.save_game() == OK else "Falha ao salvar.")))
	v.add_child(_button("Carregar (F9)", func(): panel_pause.visible = false; request_load.emit("quicksave")))
	v.add_child(_button("Gráficos: " + Game.settings.graphics, func():
		Game.settings.graphics = {"baixo": "medio", "medio": "alto", "alto": "baixo"}[Game.settings.graphics]; Game.save_settings(); _refresh_pause()))
	var spd: float = float(Game.settings.combat_speed)
	v.add_child(_button("Velocidade do combate: " + ("instantâneo" if spd <= 0 else "%dx" % int(spd)), func():
		Game.settings.combat_speed = {1.0: 2.0, 2.0: 0.0, 0.0: 1.0}.get(float(Game.settings.combat_speed), 1.0); Game.save_settings(); _refresh_pause()))
	v.add_child(_button("Reduzir movimento de câmera: " + ("sim" if Game.settings.reduce_motion else "não"), func():
		Game.settings.reduce_motion = not Game.settings.reduce_motion; Game.save_settings(); _refresh_pause()))
	v.add_child(_button("Reduzir flashes: " + ("sim" if Game.settings.reduce_flashes else "não"), func():
		Game.settings.reduce_flashes = not Game.settings.reduce_flashes; Game.save_settings(); _refresh_pause()))
	v.add_child(_label("IA de diálogo: %s" % Game.dialogue_provider.provider_id(), 8))
	v.add_child(_label("WASD mover · E interagir · J diário · C furtivo · R descansar · F5/F9 salvar/carregar", 8))
	v.add_child(_button("Sair para o título", func(): panel_pause.visible = false; Game.world = null; Game.set_mode(Game.Mode.TITLE)))


# --- Fim de jogo e título ----------------------------------------------------------------------
func _build_gameover(root: Control) -> void:
	panel_over = _panel(root, Control.PRESET_CENTER)
	panel_over.position = Vector2(200, 120)
	panel_over.custom_minimum_size = Vector2(240, 0)
	var v := VBoxContainer.new()
	panel_over.add_child(v)
	v.add_child(_h("Você morreu."))
	v.add_child(_label("Arton não protege ninguém. O mundo segue sem você.", 9))
	v.add_child(_button("Carregar último salvamento", func(): request_load.emit("quicksave" if Game.has_save("quicksave") else "auto")))
	v.add_child(_button("Carregar autosave", func(): request_load.emit("auto")))
	v.add_child(_button("Voltar ao título", func(): Game.world = null; Game.set_mode(Game.Mode.TITLE)))
	panel_over.visible = false


func _build_title(root: Control) -> void:
	panel_title = ColorRect.new()
	(panel_title as ColorRect).color = Color(0.05, 0.03, 0.07, 1)
	panel_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel_title)
	var v := VBoxContainer.new()
	v.position = Vector2(200, 70)
	v.custom_minimum_size = Vector2(240, 0)
	v.add_theme_constant_override("separation", 6)
	panel_title.add_child(v)
	var t := _label("CRÔNICAS DE ARTON", 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	v.add_child(t)
	var st := _label("O Filho do Moleiro — vertical slice", 9)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	v.add_child(_button("Novo jogo — Aventureiro", func(): request_new_game.emit(false)))
	v.add_child(_button("Novo jogo — Aventureira", func(): request_new_game.emit(true)))
	v.add_child(_button("Continuar (salvamento rápido)", func(): request_load.emit("quicksave")))
	v.add_child(_button("Continuar (autosave)", func(): request_load.emit("auto")))
	v.add_child(_button("Sair", func(): get_tree().quit()))
	var disc := _label("Projeto pessoal de fã baseado em Tormenta20 (Jambô). Regras citadas com página; arte e textos do jogo são originais.", 7)
	disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(disc)


func _refresh_mode() -> void:
	var m := Game.mode
	panel_title.visible = m == Game.Mode.TITLE
	panel_over.visible = m == Game.Mode.GAMEOVER
	combat_bar.visible = m == Game.Mode.COMBAT
	if m != Game.Mode.DIALOGUE:
		panel_dialogue.visible = false
		_dlg_shown_text = ""
	else:
		refresh_dialogue()
	if m != Game.Mode.EXPLORE:
		panel_interact.visible = false


func any_panel_open() -> bool:
	return panel_journal.visible or panel_pause.visible or panel_shop.visible or panel_interact.visible


func close_panels() -> bool:
	var was := any_panel_open()
	panel_journal.visible = false
	panel_shop.visible = false
	panel_interact.visible = false
	panel_pause.visible = false
	return was


func _on_event(e: GameEvent) -> void:
	log_msg(Narrator.line(e))
	match e.event_type:
		"OPEN_SHOP":
			var npc: String = Game.world.modules.dialogue.session.get("npc", "")
			if npc != "": open_shop(npc)
		"FACT_REVEALED", "HYPOTHESIS_MARKED":
			if panel_journal.visible: refresh_journal()


func _process(_d: float) -> void:
	if Game.world == null:
		return
	update_hud()
	if Game.mode == Game.Mode.COMBAT:
		update_combat_bar()
