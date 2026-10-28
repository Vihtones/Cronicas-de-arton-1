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
	_build_lab(root)
	_build_credits(root)
	_build_xp_summary(root)
	_build_creation(root)
	_build_prologo(root)
	_build_hub(root)
	_build_debug(root)
	_build_tree(root)
	_build_inv(root)
	_build_guild(root)
	_build_wheel(root)
	_build_subida(root)
	Game.event_published.connect(_on_event)
	Game.mode_changed.connect(func(_m): _refresh_mode())
	_refresh_mode()


## Durante um momento cinematográfico a interface sai de cena (só fica a leitura do momento).
func set_cinematic(on: bool) -> void:
	var tw := create_tween()
	for c in get_children():
		if c is Control:
			tw.parallel().tween_property(c, "modulate:a", 0.0 if on else 1.0, 0.15)


# --- Tema ---------------------------------------------------------------------------
func _make_theme() -> Theme:
	## Tema inspirado na interface de Stoneshard (atualização #39): painéis escuros e "monumentais",
	## moldura sólida de bronze gasto com filete interno, títulos dourados e texto claro legível.
	var t := Theme.new()
	t.default_font_size = 9
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.065, 0.075, 0.94)
	sb.border_color = Color(0.62, 0.48, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(1)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.expand_margin_left = 1; sb.expand_margin_right = 1
	t.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.16, 0.13, 0.14)
	bn.border_color = Color(0.4, 0.31, 0.19)
	bn.border_width_left = 1; bn.border_width_right = 1; bn.border_width_top = 1; bn.border_width_bottom = 2
	bn.set_corner_radius_all(1)
	bn.content_margin_left = 6; bn.content_margin_right = 6; bn.content_margin_top = 2; bn.content_margin_bottom = 3
	var bh := bn.duplicate(); bh.bg_color = Color(0.27, 0.2, 0.17); bh.border_color = Color(0.86, 0.68, 0.36)
	var bp := bn.duplicate(); bp.bg_color = Color(0.12, 0.09, 0.09); bp.border_color = Color(0.86, 0.68, 0.36)
	bp.border_width_top = 2; bp.border_width_bottom = 1
	var bd := bn.duplicate(); bd.bg_color = Color(0.1, 0.09, 0.1); bd.border_color = Color(0.24, 0.21, 0.19)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("focus", "Button", bh)
	t.set_stylebox("disabled", "Button", bd)
	t.set_color("font_color", "Button", Color(0.93, 0.88, 0.78))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.7))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.44))
	t.set_color("font_color", "Label", Color(0.93, 0.9, 0.84))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0))
	t.set_constant("outline_size", "Label", 2)
	t.set_constant("line_spacing", "Label", 1)
	t.set_font_size("font_size", "Button", 9)
	var sep := StyleBoxLine.new()
	sep.color = Color(0.45, 0.35, 0.2, 0.8)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.55, 0.42, 0.22)
	grab.set_corner_radius_all(1)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.08, 0.09)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t


func _panel(parent: Control, anchor_preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	p.set_anchors_preset(anchor_preset)
	p.visibility_changed.connect(_on_panel_shown.bind(p))
	return p


## Janelas entram com um leve crescimento e fade (sensação de peso, sem demora: 0,12 s).
func _on_panel_shown(p: Control) -> void:
	if not p.visible or Game.settings.reduce_motion:
		return
	p.pivot_offset = p.size / 2.0
	p.scale = Vector2(0.96, 0.96)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.1)


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
var hud_status: PanelContainer
var hud_cond: Label
var hud_quests: Label
var hud_portrait: Portrait
var hud_name: Label
var bar_pv: ProgressBar
var bar_pm: ProgressBar
var bar_xp: ProgressBar
var lbl_pv: Label
var lbl_pm: Label
var hud_clock: PanelContainer
var minimap: Minimap
var event_ribbon: PanelContainer
var lbl_event: Label
var toast: Label
var belt: PanelContainer
var _belt_slots: Dictionary = {}
var _belt_key := ""
var panel_tree: PowerPanel
var panel_inv: InventoryPanel
var panel_guild: GuildPanel
var spell_wheel: SpellWheel
var panel_cast: PanelContainer
var _cast_row: HFlowContainer
var _cast_title: Label
var panel_subida: PanelContainer
var lbl_clock: Label
var lbl_place: Label


func _bar(col: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(110, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.05)
	bg.border_color = Color(0.36, 0.28, 0.17)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.border_color = col.lightened(0.35)
	fg.border_width_top = 1
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _build_hud(root: Control) -> void:
	# placa de estado (canto inferior direito): retrato com expressão, nome, PV, PM e XP
	hud_status = _panel(root, Control.PRESET_TOP_LEFT)
	hud_status.position = Vector2(4, 290)
	hud_status.custom_minimum_size = Vector2(194, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	hud_status.add_child(row)
	hud_portrait = Portrait.new()
	hud_portrait.custom_minimum_size = Vector2(44, 44)
	hud_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	hud_name = _label("", 8)
	hud_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_name.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	col.add_child(hud_name)
	var pv_row := HBoxContainer.new()
	bar_pv = _bar(Color(0.62, 0.12, 0.1), 7)
	pv_row.add_child(bar_pv)
	lbl_pv = _label("", 7)
	lbl_pv.autowrap_mode = TextServer.AUTOWRAP_OFF
	pv_row.add_child(lbl_pv)
	col.add_child(pv_row)
	var pm_row := HBoxContainer.new()
	bar_pm = _bar(Color(0.16, 0.3, 0.62), 5)
	pm_row.add_child(bar_pm)
	lbl_pm = _label("", 7)
	lbl_pm.autowrap_mode = TextServer.AUTOWRAP_OFF
	pm_row.add_child(lbl_pm)
	col.add_child(pm_row)
	bar_xp = _bar(Color(0.75, 0.6, 0.25), 2)
	col.add_child(bar_xp)
	hud_right = _label("", 7)
	hud_right.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(hud_right)
	hud_cond = _label("", 7)
	hud_cond.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_cond.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	col.add_child(hud_cond)
	# rastreador de contratos (abaixo do relógio)
	hud_quests = _label("", 7)
	hud_quests.position = Vector2(500, 150)
	hud_quests.size = Vector2(136, 60)
	hud_quests.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_quests.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	hud_quests.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud_quests.add_theme_constant_override("outline_size", 3)
	hud_quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_quests)
	# placa de hora e lugar (canto superior direito)
	hud_clock = _panel(root, Control.PRESET_TOP_LEFT)
	hud_clock.position = Vector2(500, 4)
	hud_clock.custom_minimum_size = Vector2(136, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	hud_clock.add_child(cv)
	minimap = Minimap.new()
	cv.add_child(minimap)
	lbl_clock = _label("", 8)
	lbl_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cv.add_child(lbl_clock)
	lbl_place = _label("", 8)
	lbl_place.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_place.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	cv.add_child(lbl_place)
	hud_top = _label("", 8)   # mantido para compatibilidade (texto completo, oculto)
	hud_top.visible = false
	root.add_child(hud_top)
	signals_label = _label("", 8)
	signals_label.position = Vector2(6, 6)
	signals_label.size = Vector2(380, 30)
	signals_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	root.add_child(signals_label)
	log_box = VBoxContainer.new()
	log_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)   # ancorado acima do HUD e cresce para cima (não cobre o retrato)
	log_box.offset_left = 6
	log_box.offset_right = 306
	log_box.offset_bottom = -78
	log_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_box.add_theme_constant_override("separation", 0)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)
	# faixa do evento da vila (topo, centro) e aviso grande (clima/eventos)
	event_ribbon = _panel(root, Control.PRESET_TOP_LEFT)
	event_ribbon.position = Vector2(200, 4)
	event_ribbon.custom_minimum_size = Vector2(240, 0)
	lbl_event = _label("", 8)
	lbl_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_event.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_event.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	event_ribbon.add_child(lbl_event)
	event_ribbon.visible = false
	toast = _label("", 14)
	toast.position = Vector2(0, 120)
	toast.size = Vector2(640, 24)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	toast.add_theme_constant_override("outline_size", 5)
	toast.modulate.a = 0.0
	root.add_child(toast)
	# cinto de atalhos da exploração (centro, embaixo)
	belt = _panel(root, Control.PRESET_TOP_LEFT)
	belt.position = Vector2(232, 322)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 2)
	belt.add_child(brow)
	for spec in [["interagir", "E", "Interagir [E]", func(): get_parent().call("_explore_key", KEY_E)],
			["diario", "J", "Diário [J]", func(): toggle_journal()],
			["poderes", "K", "Árvore de poderes [K]", func(): toggle_tree()],
			["inventario", "I", "Inventário [I]", func(): toggle_inv()],
			["missoes", "L", "Missões e guilda [L]", func(): toggle_guild()],
			["magia", "Tab", "Roda de magias [Tab]", func(): toggle_wheel()],
			["furtivo", "C", "Furtividade [C]", func(): Game.send("SetStance", {"sneak": not Game.world.modules.combat.stance_sneak})],
			["descansar", "R", "Descansar [R]", func(): get_parent().call("_explore_key", KEY_R)],
			["salvar", "F5", "Salvar [F5]", func(): log_msg("Jogo salvo." if Game.save_game() == OK else "Não é possível salvar agora.")]]:
		var hs := HotSlot.new().setup(spec[0], spec[1], spec[2], spec[3])
		brow.add_child(hs)
		_belt_slots[spec[0]] = hs
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
		l.custom_minimum_size = Vector2(300, 0)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))   # legível sobre qualquer fundo
		l.add_theme_constant_override("outline_size", 3)
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
	lbl_clock.text = "%02d:%02d · dia %d/%d · %d°C" % [c.hour, c.minute, c.day, c.month, int(wm.region.temp_c)]
	lbl_place.text = str(loc.get("name", "Ermo"))
	var s: CharacterSheet = w.modules.combat.sim.c("player").sheet if w.modules.combat.active else w.player_sheet
	var sneak: bool = w.modules.combat.stance_sneak
	hud_name.text = "%s · nível %d" % [s.name, s.level]
	bar_pv.max_value = maxi(1, s.pv_max); bar_pv.value = maxi(0, s.pv)
	bar_pm.max_value = maxi(1, s.pm_max); bar_pm.value = maxi(0, s.pm)
	lbl_pv.text = "%d/%d" % [s.pv, s.pv_max]
	lbl_pm.text = "%d/%d" % [s.pm, s.pm_max]
	var prog: ProgressionModule = w.modules.progression
	bar_xp.max_value = maxi(1, prog.xp_to_next()); bar_xp.value = s.xp
	hud_right.text = "%s %s · T$ %d%s" % [CharacterBuilder.RACE_NAMES.get(s.race_id, ""), s.class_id.capitalize(), w.player.gold, " · furtivo" if sneak else ""]
	var conds: Array = []
	for cd in s.conditions:
		conds.append(str(cd))
	hud_cond.text = ("⚠ " + ", ".join(conds)) if not conds.is_empty() else ""
	var qm: QuestModule = w.modules.quests
	var ql: Array = []
	for qid in qm.ativas:
		var qa: Dictionary = qm.ativas[qid]
		ql.append(("✔ " if bool(qa.progresso.feito) else "◆ ") + str(qa.titulo) + "\n" + qm.progresso_texto(qa).substr(0, 34))
	hud_quests.text = "\n".join(ql.slice(0, 3))
	hud_quests.visible = not w.modules.combat.active
	if hud_portrait.actor_id != "player" or hud_portrait.race != s.race_id:
		hud_portrait.set_actor("player", s.race_id)
	var ratio := float(s.pv) / maxf(1.0, s.pv_max)
	var expr := "neutro" if ratio > 0.6 else ("determinado" if ratio > 0.3 else "dor")
	if s.pv <= 0: expr = "medo"
	if hud_portrait.expression != expr:
		hud_portrait.set_expression(expr)
	var busy := panel_journal.visible or panel_shop.visible or panel_pause.visible or panel_dialogue.visible
	busy = busy or panel_tree.visible or panel_inv.visible or panel_guild.visible or spell_wheel.visible or panel_cast.visible
	log_box.visible = not panel_tree.visible and not panel_journal.visible and not panel_inv.visible and not panel_guild.visible and not panel_shop.visible
	hud_status.visible = Game.mode in [Game.Mode.EXPLORE, Game.Mode.COMBAT] and not busy
	hud_clock.visible = Game.mode == Game.Mode.EXPLORE and not busy
	belt.visible = Game.mode == Game.Mode.EXPLORE and not busy
	if _belt_slots.has("poderes"):
		(_belt_slots.poderes as HotSlot).active = s.pending_powers > 0
		(_belt_slots.poderes as HotSlot).badge = ("+%d" % s.pending_powers) if s.pending_powers > 0 else ""
		(_belt_slots.furtivo as HotSlot).active = sneak
		var key := "%d|%s" % [s.pending_powers, sneak]
		if key != _belt_key:
			_belt_key = key
			for k in _belt_slots: (_belt_slots[k] as HotSlot).queue_redraw()
	minimap.weather_icon = wm.region.condition if wm.enabled else "limpo"
	minimap.night = c.hour < 6 or c.hour >= 19
	var te: TownEventsModule = w.modules.town_events
	var evs: Array = te.active_ids()
	var nx: Dictionary = te.next_event()
	if not evs.is_empty():
		lbl_event.text = "⚑ " + " · ".join(evs.map(func(x): return TownEventsModule.EVENTS[x].name)) + " — " + str(Game.db.location(TownEventsModule.EVENTS[evs[0]].place).get("name", ""))
	elif not nx.is_empty() and int(nx.days) == 0:
		lbl_event.text = "Hoje: %s às %dh" % [nx.name, int(nx.from)]
	else:
		lbl_event.text = ""
	event_ribbon.visible = lbl_event.text != "" and Game.mode == Game.Mode.EXPLORE and not busy
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
	if a.has("ui"):
		call(str(a.ui))
		return
	var r := Game.send(a.cmd, a.payload)
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))


# --- Diálogo ----------------------------------------------------------------------------------
var dlg_portrait: Portrait
var _type_tween: Tween


func _build_dialogue(root: Control) -> void:
	panel_dialogue = _panel(root, Control.PRESET_BOTTOM_WIDE)
	panel_dialogue.offset_top = -132
	panel_dialogue.offset_left = 12
	panel_dialogue.offset_right = -12
	panel_dialogue.offset_bottom = -6
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel_dialogue.add_child(row)
	dlg_portrait = Portrait.new()
	dlg_portrait.custom_minimum_size = Vector2(76, 76)
	dlg_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dlg_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	dlg_name = _label("", 10)
	dlg_name.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	v.add_child(dlg_name)
	v.add_child(HSeparator.new())
	dlg_text = _label("", 9)
	dlg_text.custom_minimum_size = Vector2(500, 30)
	v.add_child(dlg_text)
	dlg_opts = VBoxContainer.new()
	dlg_opts.add_theme_constant_override("separation", 1)
	v.add_child(dlg_opts)
	panel_dialogue.visible = false


## Texto aparece letra a letra (rápido; reduzir movimento mostra tudo de uma vez).
func _typewrite(lbl: Label, txt: String) -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	lbl.text = txt
	if Game.settings.reduce_motion:
		lbl.visible_ratio = 1.0
		return
	lbl.visible_ratio = 0.0
	_type_tween = lbl.create_tween()
	_type_tween.tween_property(lbl, "visible_ratio", 1.0, clampf(txt.length() / 90.0, 0.15, 1.2))


func refresh_dialogue() -> void:
	var dlg: DialogueModule = Game.world.modules.dialogue
	var view := dlg.view()
	if view.is_empty():
		panel_dialogue.visible = false
		return
	panel_dialogue.visible = true
	dlg_name.text = view.name
	if dlg_portrait.actor_id != view.npc:
		dlg_portrait.set_actor(view.npc, "humano")
		dlg_portrait.set_expression("neutro")
	var base: String = view.text
	if base != _dlg_shown_text:
		_dlg_shown_text = base
		_typewrite(dlg_text, base)
		dlg_portrait.set_expression(_tone_expression(base))
		var d := Game.world.npc_def(view.npc)
		Game.dialogue_provider.verbalize_async(view.npc, base, {"name": d.get("name", ""), "profession": d.get("profession", ""),
			"allowed_names": ["Tomas", "Hilda", "Otto", "Lena", "Valkaria", "Khalmyr", "Kael", "Dorn", "Elsa", "Rosana"]},
			func(t: String): if _dlg_shown_text == base: dlg_text.text = t)
	for c in dlg_opts.get_children():
		c.queue_free()
	for o in view.options:
		dlg_opts.add_child(_button("%d. %s" % [o.index + 1, o.text], _choose.bind(o.index)))


## Expressão provisória pelo tom da fala (até o diálogo ter emoção explícita por nó).
func _tone_expression(txt: String) -> String:
	var t := txt.to_lower()
	if t.contains("!") and (t.contains("socorro") or t.contains("filho") or t.contains("por favor")): return "medo"
	if t.contains("obrigad") or t.contains("graças") or t.contains("bem-vind"): return "alegria"
	if t.contains("fora") or t.contains("suma") or t.contains("ladr") or t.contains("estranho"): return "furioso"
	if t.contains("?"): return "concentrado"
	return "neutro"


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


func _cmd_log(type: String, payload: Dictionary) -> void:
	var r := Game.send(type, payload)
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))


func _h(text: String) -> Label:
	var l := _label(text, 10)
	l.add_theme_color_override("font_color", Color(1, 0.82, 0.4))
	return l


## Grupo e guilda (Arton Viva, Fase 6): companheiros, ordens, contratos e caixa da guilda.
func _secao_grupo(w: WorldState) -> void:
	var party = w.modules.party
	journal_body.add_child(_h("Grupo e guilda"))
	if party.guild.is_empty():
		journal_body.add_child(_label("Sem guilda. Registrar custa T$ %d e pede %d membros." % [PartyModule.GUILD_COST, PartyModule.GUILD_MIN_MEMBERS], 9))
		journal_body.add_child(_button("Registrar guilda (T$ %d)" % PartyModule.GUILD_COST, func(): _acao("CreateGuild", {"name": "Guilda da vila"})))
	else:
		journal_body.add_child(_label("%s — caixa T$ %d" % [party.guild.name, party.caixa], 9))
		journal_body.add_child(_button("Distribuir o caixa entre os membros", func(): _acao("GuildDistribute", {})))
	if party.members.is_empty():
		journal_body.add_child(_label("Nenhum companheiro ainda.", 9))
	for id in party.members:
		var m: Dictionary = party.members[id]
		var situacao := "em contrato" if _em_contrato(party, id) else "livre"
		journal_body.add_child(_label("• %s — lealdade %d%%, %s" % [w.db.npc_def(id).name, int(m.loyalty), situacao], 9))
		var proxima: String = party.ORDERS[(party.ORDERS.find(m.order) + 1) % party.ORDERS.size()]
		journal_body.add_child(_button("Ordem: %s (trocar para %s)" % [m.order, proxima], func(): _acao("SetOrder", {"npc_id": id, "order": proxima})))
	if not party.guild.is_empty():
		journal_body.add_child(_h("Contratos da guilda"))
		for cid in w.db.economy.get("contratos_guilda", {}):
			var d: Dictionary = w.db.economy.contratos_guilda[cid]
			journal_body.add_child(_button("Aceitar: %s — T$ %d em %d dia(s), mínimo %d membro(s)" % [d.nome, d.pagamento, d.dias, d.membros_min], func(): _acao("AcceptContract", {"contrato": cid})))
		for c in party.contratos.values():
			journal_body.add_child(_label("Em curso: %s, até o dia %d" % [w.db.economy.contratos_guilda[c.contrato].nome, int(c.fim_dia)], 9))
	_secao_recrutar(w, party)


func _em_contrato(party: PartyModule, id: String) -> bool:
	for c in party.contratos.values():
		if c.membros.has(id):
			return true
	return false


## Candidatos a companheiro: os três moradores que mais conhecem o jogador. Quem não confia pede a taxa.
func _secao_recrutar(w: WorldState, party: PartyModule) -> void:
	var npcs = w.modules.npcs
	var rl = w.modules.relations
	var candidatos: Array = []
	for id in w.db.all_npc_ids():
		if party.members.has(id) or not npcs.npc(id).get("alive", false) or npcs.npc(id).get("captive", false):
			continue
		if int(w.db.npc_def(id).get("age", 0)) < PartyModule.MIN_AGE:
			continue
		candidatos.append({"id": id, "r": rl.dims(id, "player")})
	candidatos.sort_custom(func(a, b): return a.r.familiaridade > b.r.familiaridade)
	journal_body.add_child(_h("Recrutar"))
	for c in candidatos.slice(0, 3):
		var id: String = c.id
		var confia: bool = float(c.r.confianca) >= PartyModule.RECRUIT_TRUST and float(c.r.familiaridade) >= PartyModule.RECRUIT_FAMILIARITY
		var pagar := 0 if confia else PartyModule.RECRUIT_FEE
		var texto := "Convidar %s" % w.db.npc_def(id).name + ("" if confia else " (paga T$ %d)" % pagar)
		journal_body.add_child(_button(texto, func(): _acao("RecruitCompanion", {"npc_id": id, "pay": pagar})))


func _acao(tipo: String, payload: Dictionary) -> void:
	var r = Game.send(tipo, payload)
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))
	refresh_journal()


func _botao_construir(id: String, d: Dictionary, tesouro: int) -> Button:
	var b := _button("Construir por T$ %d" % int(d.custo), func(): _construir(id))
	b.disabled = tesouro < int(d.custo)
	return b


func _construir(id: String) -> void:
	Game.send("Build", {"id": id})
	refresh_journal()


func refresh_journal() -> void:
	for c in journal_body.get_children():
		c.queue_free()
	var w: WorldState = Game.world
	var ex: ExplorationModule = w.modules.exploration
	journal_body.add_child(_h("Diário — %s  [J fecha]" % Game.db.mystery.title + ("  (resolvido)" if ex.mystery_state == "resolvido" else ("  (perdido)" if ex.mystery_state == "perdido" else ""))))
	journal_body.add_child(_h("Pistas"))
	for n in ex.notes:
		var mt: String = Game.db.mystery_def(str(n.get("mystery", ""))).get("title", "")
		journal_body.add_child(_label("• " + (("[" + mt + "] ") if mt != "" and mt != Game.db.mystery.title else "") + str(n.text), 9))
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
	var inv_row := HFlowContainer.new()
	for it in w.modules.state.inventory:
		if ItemsModule.EQUIPPABLE.has(it):
			inv_row.add_child(_button("Equipar " + Game.db.items.get(it, {}).get("name", it), func(): _cmd_log("Equip", {"item": it}); refresh_journal()))
		elif it == "pocao_cura":
			inv_row.add_child(_button("Beber poção", func(): _cmd_log("UseItem", {"item": it}); refresh_journal()))
		elif bool(Game.db.items.get(it, {}).get("alimento", false)):
			inv_row.add_child(_button("Consumir " + str(Game.db.items.get(it, {}).get("name", it)), func(): _cmd_log("UseItem", {"item": it, "bonus": "pv"}); refresh_journal()))
	for sp in s.spells:
		if w.rules.value("magia." + sp, {}).has("cura"):
			inv_row.add_child(_button("Lançar " + sp, func(): _cmd_log("CastSpell", {"spell": sp}); refresh_journal()))
	_botoes_magia_fora(w, s, inv_row)
	if inv_row.get_child_count() > 0:
		journal_body.add_child(inv_row)
	var prog: ProgressionModule = w.modules.progression
	if prog.enabled:
		journal_body.add_child(_label("Experiência: %d XP · próximo nível em %d XP · modo de XP: %s · poderes: %s" % [s.xp, prog.xp_to_next(), prog.mode,
			", ".join(s.powers.keys()) if not s.powers.is_empty() else "—"], 9))
		var xrow := HFlowContainer.new()
		xrow.add_child(_button("XP: " + ("dinâmica → livro" if prog.mode == "dinamica" else "livro → dinâmica"), func():
			_cmd_log("SetXpMode", {"mode": "livro" if prog.mode == "dinamica" else "dinamica"}); refresh_journal()))
		if s.pending_powers > 0:
			for pw in prog.available_powers():
				var opt := "for" if pw == "aumento_atributo" else ""
				xrow.add_child(_button("Escolher: " + pw.replace("_", " ") + (" (+1 For)" if opt != "" else ""), func():
					_cmd_log("ChoosePower", {"power": pw, "option": opt}); refresh_journal()))
		journal_body.add_child(xrow)
		var cmb: CombatModule = w.modules.combat
		var prow := HFlowContainer.new()
		var labels := {"golpe_raspao": "Golpe de Raspão", "durao": "Durão", "rolamento_defensivo": "Rolamento Defensivo", "ataque_reflexo": "Ataque Reflexo"}
		var expl := {"auto": "usar ao errar", "nunca": "nunca", "fortes": "só golpes ≥ 1/4 dos PV", "sempre": "todo golpe"}
		for pw in CombatModule.POWER_POLICIES:
			if not s.has_power(pw):
				continue
			var opts: Array = CombatModule.POWER_POLICIES[pw]
			var cur: String = cmb.power_policy.get(pw, opts[0])
			var nxt: String = opts[(opts.find(cur) + 1) % opts.size()]
			prow.add_child(_button("%s: %s" % [labels[pw], expl[cur]], func():
				_cmd_log("SetPowerPolicy", {"power": pw, "policy": nxt}); refresh_journal()))
		if prow.get_child_count() > 0:
			journal_body.add_child(prow)
		for entry in prog.log.slice(maxi(0, prog.log.size() - 3)):
			journal_body.add_child(_label("  +%d XP: %s" % [entry.xp, entry.reason], 8))
	var dom: DomainModule = w.modules.domain
	if dom.enabled and dom.owned:
		journal_body.add_child(_h("Domínio — " + dom.domain_name))
		journal_body.add_child(_label("Tesouro T$ %d · moral %d · segurança %d · imposto %s · patrulha %s · celeiro %s · %s" % [dom.treasury, dom.morale, dom.security,
			dom.policy.imposto, "sim" if dom.policy.patrulha else "não", "sim" if dom.policy.celeiro else "não", "delegado aos conselheiros" if dom.delegated else "você decide"], 9))
		var drow := HFlowContainer.new()
		for tax in ["baixo", "medio", "alto"]:
			drow.add_child(_button("Imposto " + tax, func(): _cmd_log("SetPolicy", {"key": "imposto", "value": tax}); refresh_journal()))
		drow.add_child(_button("Patrulha", func(): _cmd_log("SetPolicy", {"key": "patrulha", "value": not dom.policy.patrulha}); refresh_journal()))
		drow.add_child(_button("Celeiro", func(): _cmd_log("SetPolicy", {"key": "celeiro", "value": not dom.policy.celeiro}); refresh_journal()))
		drow.add_child(_button("Delegar" if not dom.delegated else "Retomar", func(): _cmd_log("Delegate", {"on": not dom.delegated}); refresh_journal()))
		journal_body.add_child(drow)
		if not dom.reports.is_empty():
			var rp: Dictionary = dom.reports[-1]
			journal_body.add_child(_label("Última semana: renda %d, custos %d%s" % [rp.income, rp.upkeep, (" — " + rp.event) if rp.event != "" else ""], 8))
	var lin: LineageModule = w.modules.lineage
	if lin.enabled and (not lin.deaths.is_empty() or not lin.newborns.is_empty() or not lin.heroes.is_empty()):
		journal_body.add_child(_h("Gerações"))
		for d in lin.deaths:
			journal_body.add_child(_label("✝ %s (%d anos) — herdeiro: %s" % [Game.world.npc_def(d.npc).name, d.age, Game.world.npc_def(d.heir).get("name", "ninguém")], 8))
		for b in lin.newborns:
			journal_body.add_child(_label("✦ %s, ano %d" % [b.name, b.born_year], 8))
		for hh in lin.heroes:
			journal_body.add_child(_label("Herói anterior: %s (nível %d)" % [hh.name, hh.level], 8))
	var mem: MemoryModule = w.modules.memory
	if mem.enabled:
		var rep := mem.settlement_reputation()
		journal_body.add_child(_h("Reputação"))
		journal_body.add_child(_label("Na vila, %d pessoa(s) sabem algo sobre você (saldo %+.0f). Reputação só muda quando alguém fica sabendo." % [rep.known_by, rep.value], 9))
	var cr: CrimeModule = w.modules.crime
	if cr.enabled and cr.total_fines() > 0:
		journal_body.add_child(_label("Multas pendentes: T$ %d (pague à Guarda)." % cr.total_fines(), 9))
	_secao_grupo(w)
	# cidade (Arton Viva, Fase 5): indicadores e construções pagas pelo tesouro da vila
	journal_body.add_child(_h("Cidade da vila"))
	var ind: Dictionary = w.modules.cities.indicators()
	var nomes_ind := {"abastecimento": "Abastecimento", "saude": "Saúde", "prosperidade": "Prosperidade", "estabilidade": "Estabilidade", "seguranca": "Segurança", "moradia": "Moradia", "influencia": "Influência"}
	for chave in nomes_ind:
		journal_body.add_child(_label("• %s: %d%%" % [nomes_ind[chave], int(round(float(ind[chave]) * 100.0))], 9))
	var tesouro: int = int(w.modules.economy.treasury)
	journal_body.add_child(_label("Tesouro da vila: T$ %d" % tesouro, 9))
	for id in w.db.economy.get("construcoes", {}):
		journal_body.add_child(_label("%s: %s." % [w.db.economy.construcoes[id].nome, w.db.economy.construcoes[id].descricao], 9))
		journal_body.add_child(_botao_construir(id, w.db.economy.construcoes[id], tesouro))
	# rotas comerciais (Arton Viva, Fase 4): estado da estrada e quando o mensageiro chega
	journal_body.add_child(_h("Rotas comerciais"))
	for rota in w.modules.economy.route_summary():
		var estado := "aberta" if rota.aberta else "fechada"
		var quando := ("%s está na vila (vai embora em %d dia(s))" % [rota.mensageiro, rota.dias]) if rota.na_vila else ("%s chega em %d dia(s)" % [rota.mensageiro, rota.dias])
		if not rota.aberta and not rota.na_vila:
			quando += ", mas sem carga"
		var titulo := str(rota.nome)
		titulo = titulo.substr(0, 1).to_upper() + titulo.substr(1)
		journal_body.add_child(_label("• %s: %s. %s." % [titulo, estado, quando], 9))
	# crônica da vila: o que aconteceu no mundo, mais recente primeiro (Arton Viva, Fase 9)
	journal_body.add_child(_h("Crônica da vila"))
	var diario_mundo = w.modules.chronicle
	var recentes: Array = diario_mundo.entries.duplicate()
	recentes.reverse()
	if recentes.is_empty():
		journal_body.add_child(_label("Nada digno de registro ainda.", 9))
	for entrada in recentes.slice(0, 10):
		journal_body.add_child(_label("• %s" % str(entrada.text), 9))
	journal_body.add_child(_h("Regras"))
	journal_body.add_child(_label("%d regras com fonte e página; %d pendentes de revisão humana. Mecânicas originais do jogo estão marcadas." % [w.rules.size(), w.rules.unverified_ids().size()], 8))


# --- Loja --------------------------------------------------------------------------------------
func _build_shop(root: Control) -> void:
	var sp := ShopPanel.new()
	panel_shop = sp
	root.add_child(sp)
	sp.position = Vector2(40, 30)
	sp.visible = false
	sp.command.connect(func(t: String, p: Dictionary): _cmd_log(t, p))


func open_shop(npc: String) -> void:
	shop_npc = npc
	(panel_shop as ShopPanel).open(npc)


# --- Barra de combate -------------------------------------------------------------------------
func _build_combat_bar(root: Control) -> void:
	# topo: ordem de turno e dica; embaixo: cinto de ações (estilo Stoneshard)
	combat_bar = _panel(root, Control.PRESET_TOP_WIDE)
	combat_bar.offset_top = 4
	combat_bar.offset_left = 120
	combat_bar.offset_right = -120
	combat_info = _label("", 8)
	combat_bar.add_child(combat_info)
	combat_belt = _panel(root, Control.PRESET_TOP_LEFT)
	combat_belt.position = Vector2(204, 290)
	combat_belt.custom_minimum_size = Vector2(0, 0)
	var row := HFlowContainer.new()   # quebra linha em vez de cortar espaços para fora da tela
	row.custom_minimum_size = Vector2(424, 0)
	row.add_theme_constant_override("h_separation", 2)
	row.add_theme_constant_override("v_separation", 2)
	combat_belt.add_child(row)
	# [ícone, tecla, dica, ação, poder exigido ("" = sempre visível)]
	for spec in [["mover", "1", "Mover/Atacar", func(): combat_view.mode = "mover", ""], ["investida", "2", "Investida", func(): combat_view.mode = "investida", ""],
			["misericordia", "3", "Golpe de misericórdia", func(): combat_view.mode = "misericordia", ""], ["especial", "Q", "Ataque Especial (+4, 1 PM)", func(): combat_view.special = not combat_view.special, "@guerreiro"],
			["raspao", "R", "Golpe de Raspão", func(): combat_view.toggle_raspao(), "golpe_raspao"], ["magia", "Tab", "Roda de magias", func(): toggle_wheel(), "@magia"],
			["pocao", "5", "Beber poção", func(): combat_view.drink_potion(), ""], ["atirar", "6", "Atirar", func(): combat_view.mode = "atirar", ""],
			["levantar", "L", "Levantar", func(): combat_view.stand_up(), ""], ["impeto", "I", "Ímpeto (1 PM)", func(): combat_view.use_power("impeto"), "impeto"],
			["velocidade", "V", "Velocidade Ladina (2 PM)", func(): combat_view.use_power("velocidade_ladina"), "velocidade_ladina"], ["emboscar", "M", "Emboscar (2 PM)", func(): combat_view.use_power("emboscar"), "emboscar"],
			["pungente", "P", "Magia Pungente (+1 PM, +2 CD)", func(): combat_view.toggle_pungente(), "magia_pungente"], ["extra", "X", "Ataque extra", func(): combat_view.extra_attack(), "@extra"],
			["poderoso", "A", "Ataque Poderoso: -2 ataque, +5 dano (auto/sempre/nunca)", func(): _cycle_policy("ataque_poderoso"), "ataque_poderoso"],
			["defensivo", "D", "Combate Defensivo: -2 ataque, +5 Defesa (liga/desliga)", func(): _cycle_policy("combate_defensivo"), "combate_defensivo"],
			["cura", "U", "Cura pelas Mãos (1 PM): toque você ou um aliado adjacente", func(): combat_view.set_mode("cura"), "@paladino"],
			["passos", "N", "Cura: passo extra de +1d8+1 (+1 PM, a cada 4 níveis)", func(): combat_view.cycle_cura_passos(), "@paladino"],
			["remover", "H", "Cura: remover condição (+1 PM, 6º nível)", func(): combat_view.toggle_cura_remover(), "@paladino"],
			["golpe", "F", "Golpe Divino: +Car e +1d8 (2 PM; auto/nunca)", func(): _cycle_policy("golpe_divino"), "@paladino"],
			["golpe_extra", "Z", "Golpe Divino: dados extras (+1 PM cada; auto/nunca)", func(): _cycle_policy("golpe_divino_extra"), "@paladino"],
			["olhar", "O", "Olhar atordoante (medusa)", func(): combat_view.set_mode("olhar"), "@medusa"],
			["allihanna", "Y", "Armadura de Allihanna (1 PM)", func(): combat_view.use_allihanna(), "@dahllan"],
			["aura", "S", "Aura Sagrada (1 PM ao ligar; liga/desliga)", func(): combat_view.use_aura(), "@paladino"],
			["egide", "E", "Égide Sagrada (2 PM, até o fim da cena)", func(): combat_view.use_egide(), "egide_sagrada"],
			["ordem", "J", "Ordens de magias e parceiros (J troca; clique no mapa)", func(): combat_view.cycle_ordem(), "@ordens"],
			["desfazer", "⌫", "Desfazer", func(): combat_view.undo(), ""], ["confirmar", "↵", "Confirmar plano", func(): combat_view.confirm(), ""], ["fim", "␣", "Fim do turno", func(): combat_view.end_turn(), ""]]:
		var b := HotSlot.new().setup(spec[0], spec[1], spec[2], spec[3])
		b.set_meta("needs", spec[4])
		row.add_child(b)
		_combat_buttons.append(b)
	combat_bar.visible = false
	combat_belt.visible = false


var combat_belt: PanelContainer


func _cycle_policy(power: String) -> void:
	if combat_view: combat_view.cycle_policy(power)


var _combat_buttons: Array[HotSlot] = []


func update_combat_bar() -> void:
	var c: CombatModule = Game.world.modules.combat
	if not c.active:
		return
	var sh: CharacterSheet = c.sim.c("player").sheet
	for b in _combat_buttons:
		var need: String = b.get_meta("needs", "")
		match need:
			"": b.visible = true
			"@guerreiro": b.visible = sh.class_id in ["", "guerreiro"]
			"@magia": b.visible = not sh.spells.is_empty() or sh.has_power("raio_arcano")
			"@extra": b.visible = sh.class_id == "guerreiro" and sh.level >= 6
			"@paladino": b.visible = sh.class_id == "paladino"
			"@medusa": b.visible = sh.race_id == "medusa"
			"@dahllan": b.visible = sh.race_id == "dahllan"
			"@ordens": b.visible = not combat_view.ordens_disponiveis().is_empty()
			_: b.visible = sh.has_power(need)
		var ic := b.icon_id
		b.active = (ic == "especial" and combat_view.special) or (ic == "raspao" and combat_view.raspao) or (ic == "pungente" and combat_view.get("pungente") == true)
		b.badge = ""
		if ic in ["poderoso", "defensivo"]:
			var pol: String = c.power_policy.get("ataque_poderoso" if ic == "poderoso" else "combate_defensivo", "")
			b.badge = pol
			b.active = pol == "sempre"
		if ic in ["golpe", "golpe_extra"]:
			var pol_g: String = c.power_policy.get("golpe_divino" if ic == "golpe" else "golpe_divino_extra", "")
			b.badge = pol_g
			b.active = pol_g == "auto"
		elif ic == "passos":
			b.badge = str(combat_view.cura_passos)
		elif ic in ["cura", "olhar"]:
			b.active = combat_view.mode == ic
		elif ic == "aura":
			b.active = sh.aura_sagrada_ativa
		elif ic == "egide":
			b.active = sh.egide_ativa
		b.cost = {"especial": 1, "impeto": 1, "velocidade": 2, "emboscar": 2, "pungente": 1, "raspao": 2, "cura": 1, "olhar": 1, "allihanna": 1, "aura": 1, "egide": 2}.get(ic, 0)
		var st := "%s|%s|%s|%d" % [b.visible, b.active, b.badge, b.cost]
		if st != str(b.get_meta("st", "")):
			b.set_meta("st", st)
			b.queue_redraw()
	var s := c.sim
	var order: Array = []
	for id in s.order:
		var x := s.c(id)
		var nm: String = "Você" if id == "player" else x.sheet.name
		order.append(("▶" if id == s.current_id() else "") + "%s %d/%d" % [nm, x.sheet.pv, x.sheet.pv_max])
	var mine := s.current_id() == "player"
	if combat_view.acao:
		combat_info.text = "Rodada %d · %s\n%s" % [s.round_no, " | ".join(order), ("AÇÃO — mire e clique para golpear, clique no chão para andar, Tab magias, Espaço passa (%.1fs)" % maxf(0.0, combat_view.acao_relogio)) if mine else "Inimigos agindo..."]
		return
	combat_info.text = "Rodada %d · %s\n%s" % [s.round_no, " | ".join(order),
		("Seu turno — clique para planejar (modo: %s%s). Botão direito desfaz. Enter confirma." % [combat_view.mode, (", ESPECIAL" if combat_view.special else "") +
			(", raspão: " + ("sim" if combat_view.raspao else "não") if Game.world.player_sheet.has_power("golpe_raspao") else "")]) if mine else "Turno dos inimigos..."]


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
	v.add_child(_button("Lutas pequenas em tempo real: " + ("sim (%ds por turno)" % int(Game.settings.get("acao_segundos", 4.0)) if bool(Game.settings.get("combate_acao", true)) else "não (tático)"), func():
		if not bool(Game.settings.get("combate_acao", true)):
			Game.settings.combate_acao = true; Game.settings.acao_segundos = 4.0
		elif float(Game.settings.get("acao_segundos", 4.0)) < 6.0:
			Game.settings.acao_segundos = 6.0
		else:
			Game.settings.combate_acao = false
		Game.save_settings(); _refresh_pause()))
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
	v.add_child(_button("Continuar como herdeiro (mesmo mundo)", func():
		_heir_mode = true
		open_creation()))
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
	v.add_child(_button("Novo jogo — Aventureiro (Guerreiro pronto)", func(): request_new_game.emit(false)))
	v.add_child(_button("Novo jogo — Aventureira (Guerreira pronta)", func(): request_new_game.emit(true)))
	v.add_child(_button("Criar personagem…", func(): open_creation()))
	v.add_child(_button("Laboratório de protótipos…", func(): open_lab()))
	v.add_child(_button("Continuar (salvamento rápido)", func(): request_load.emit("quicksave")))
	v.add_child(_button("Continuar (autosave)", func(): request_load.emit("auto")))
	v.add_child(_button("Créditos de arte", func(): panel_credits.visible = true))
	v.add_child(_button("Sair", func(): get_tree().quit()))
	var disc := _label("Projeto pessoal de fã baseado em Tormenta20 (Jambô). Regras citadas com página. Vegetação da floresta: [LPC] Jungle, CC-BY 4.0 (ver Créditos); demais artes e textos são originais.", 7)
	disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(disc)


# --- Resumo pós-combate da XP dinâmica (C22) ---------------------------------------------
var panel_xp: PanelContainer
var _xp_box: VBoxContainer


func _build_xp_summary(root: Control) -> void:
	panel_xp = _panel(root, Control.PRESET_CENTER)
	panel_xp.custom_minimum_size = Vector2(340, 0)
	panel_xp.offset_left = -170; panel_xp.offset_right = 170; panel_xp.offset_top = -110; panel_xp.offset_bottom = 110
	_xp_box = VBoxContainer.new()
	panel_xp.add_child(_xp_box)
	panel_xp.visible = false


func show_xp_summary(p: Dictionary) -> void:
	for c in _xp_box.get_children():
		c.queue_free()
	var titles := {"vitoria": "Vitória", "fuga": "Fuga", "captura": "Derrota"}
	_xp_box.add_child(_h("%s — experiência" % titles.get(p.get("outcome", ""), "Combate")))
	_xp_box.add_child(_label("Base do livro (ND dos inimigos, com novidade): %d XP" % int(p.get("base", 0)), 8))
	for b in p.get("breakdown", []):
		var v := float(b[1])
		_xp_box.add_child(_label(("  • %s  %+d%%" % [b[0], int(round(v * 100))]) if v != 0.0 else "  • " + str(b[0]), 8))
	_xp_box.add_child(_label("Multiplicador: ×%.2f (limites ×0,5 a ×2,0)" % float(p.get("mult", 1.0)), 8))
	var t := _label("+%d XP   ·   total %d / %d para o nível %d" % [int(p.amount), int(p.total), int(p.get("next", 0)), int(p.get("level", 1)) + 1], 10)
	t.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	_xp_box.add_child(t)
	_xp_box.add_child(_button("Continuar", func(): panel_xp.visible = false))
	panel_xp.visible = true


# --- Créditos de arte (CC-BY exige atribuição integral, regra AD-03) -------------------
var panel_credits: PanelContainer


func _build_credits(root: Control) -> void:
	panel_credits = _panel(root, Control.PRESET_FULL_RECT)
	panel_credits.offset_left = 40; panel_credits.offset_top = 16; panel_credits.offset_right = -40; panel_credits.offset_bottom = -16
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_credits.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(_h("Créditos de arte"))
	v.add_child(_button("Fechar", func(): panel_credits.visible = false))
	for path in ArtGovernor.load_default().credits_paths():
		var l := _label(FileAccess.get_file_as_string(path), 7)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 520
		v.add_child(l)
	if FileAccess.file_exists("res://assets/CREDITOS_PERSONAGENS.txt"):   # personagens (camadas LPC, atribuição)
		var lp := _label(FileAccess.get_file_as_string("res://assets/CREDITOS_PERSONAGENS.txt"), 7)
		lp.custom_minimum_size.x = 520
		v.add_child(lp)
	panel_credits.visible = false


# --- Laboratório de protótipos ------------------------------------------------------
var panel_lab: PanelContainer
var panel_creation: PanelContainer
var panel_hub: PanelContainer
var debug_label: Label
var _heir_mode := false
var panel_prologo: PanelContainer
var _prologo: Dictionary = {}   # respostas do questionário (id da pergunta -> opção)
const PROLOGO_TITULOS := {"onde_cresceu": "Onde cresceu", "condicao": "Condição", "vinculo": "Vínculos",
	"ocupacao": "Ofício", "recente": "Algo recente", "comeco": "Onde começa"}


func _build_lab(root: Control) -> void:
	panel_lab = _panel(root, Control.PRESET_FULL_RECT)
	panel_lab.offset_left = 40; panel_lab.offset_top = 16; panel_lab.offset_right = -40; panel_lab.offset_bottom = -16
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_lab.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(_h("Laboratório de protótipos — uma mecânica por cenário"))
	for p in Prototypes.LIST:
		var row := HBoxContainer.new()
		var b := _button(p.nome, func(): panel_lab.visible = false; _start_proto(p.id))
		b.custom_minimum_size.x = 170
		row.add_child(b)
		var l := _label(p.desc, 8)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 360
		row.add_child(l)
		v.add_child(row)
	v.add_child(_button("Voltar", func(): panel_lab.visible = false))
	panel_lab.visible = false


func open_lab() -> void:
	panel_lab.visible = true


func _start_proto(id: String) -> void:
	var info: Dictionary = Game.start_prototype(id)
	log_msg(info.intro)
	if info.get("ui", "") == "criacao":
		open_creation()


# --- Criação de personagem ----------------------------------------------------------------
func _build_creation(root: Control) -> void:
	var cp := CreationPanel.new()
	panel_creation = cp
	root.add_child(cp)
	cp.position = Vector2(20, 12)
	cp.visible = false
	cp.concluido.connect(_criacao_concluida)
	cp.cancelado.connect(func(): panel_title.visible = _titulo_antes)


var _titulo_antes := false


func _row_label(t: String) -> Label:
	var l := _label(t, 9)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 60
	return l


func open_creation() -> void:
	_titulo_antes = panel_title.visible
	panel_title.visible = false
	(panel_creation as CreationPanel).abrir(_heir_mode)


func _criacao_concluida(b_dict: Dictionary, feminino: bool, destino: bool) -> void:
	if _heir_mode:
		_heir_mode = false
		var hb := b_dict.duplicate()
		if str(hb.name) in ["Aventureiro", "Aventureira"]:
			hb.name = "Herdeiro"
		var r := Game.send("ContinueAsHeir", {"build": hb})
		if r.accepted:
			Game.set_mode(Game.Mode.EXPLORE)
			Game.world_reloaded.emit()
		else:
			log_msg("✘ " + "; ".join(r.errors))
		return
	Game.new_game_with_build(b_dict, feminino)
	if destino:
		Game.start_prologue_from_seed(randi())
	else:
		open_prologo()


# --- Prólogo vivo (Arton Viva, Fase 3) --------------------------------------------------------
func _build_prologo(root: Control) -> void:
	panel_prologo = _panel(root, Control.PRESET_CENTER)
	panel_prologo.position = Vector2(80, 16)
	panel_prologo.custom_minimum_size = Vector2(460, 0)
	panel_prologo.visible = false


func open_prologo() -> void:
	_prologo = {}
	_refresh_prologo()
	panel_prologo.visible = true


func _refresh_prologo() -> void:
	for c in panel_prologo.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel_prologo.add_child(v)
	v.add_child(_label("Seu passado", 12))
	v.add_child(_label("Respostas curtas. Elas definem de onde você vem: ouro, casa, quem você conhece e o que faz. Não há resposta certa.", 8))
	for q in Prologue.QUESTIONS:
		var row := HFlowContainer.new()
		row.add_child(_row_label(str(PROLOGO_TITULOS[q])))
		var cur: String = str(_prologo.get(q, Prologue.OPTIONS[q][0]))
		for opt in Prologue.OPTIONS[q]:
			var on: bool = cur == opt
			row.add_child(_button(("● " if on else "") + str(opt).replace("_", " "), func(): _prologo[q] = opt; _refresh_prologo()))
		v.add_child(row)
	v.add_child(_button("Começar com este passado", func():
		var r := Game.start_prologue(Prologue.from_answers(_prologo))
		if r.accepted:
			panel_prologo.visible = false
		else:
			log_msg("✘ " + "; ".join(r.errors))))
	v.add_child(_button("Deixar o Destino Decidir", func():
		panel_prologo.visible = false
		Game.start_prologue_from_seed(randi())))
	v.add_child(_button("Pular (sem passado)", func(): panel_prologo.visible = false))


# --- Valkaria (região distante, LOD L3, sem mapa) --------------------------------------------
func _build_hub(root: Control) -> void:
	panel_hub = _panel(root, Control.PRESET_FULL_RECT)
	panel_hub.offset_left = 60; panel_hub.offset_top = 40; panel_hub.offset_right = -60; panel_hub.offset_bottom = -60
	panel_hub.visible = false


func refresh_hub() -> void:
	var tr: TravelModule = Game.world.modules.travel
	panel_hub.visible = tr.enabled and tr.current_region != "vila"
	if not panel_hub.visible:
		return
	for c in panel_hub.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	panel_hub.add_child(v)
	v.add_child(_h({"valkaria": "Valkaria, a capital", "ermos_norte": "Ermos do Norte"}.get(tr.current_region, tr.current_region)))
	v.add_child(_label("Protótipo de região distante (LOD L3): sem mapa, só decisões, mercado e notícias.", 8))
	var eco: EconomyModule = Game.world.modules.economy
	if tr.current_region == "valkaria" and eco.enabled:
		v.add_child(_label("Mercado: comida %d · ferramentas %d · remédios %d (estoques agregados)" % [eco.regions.valkaria.stock.comida, eco.regions.valkaria.stock.ferramentas, eco.regions.valkaria.stock.remedio], 9))
	var rs: RegionSimModule = Game.world.modules.region_sim
	for h in rs.history.slice(maxi(0, rs.history.size() - 4)):
		v.add_child(_label("• " + str(h.news), 8))
	var adv: AdventurersModule = Game.world.modules.adventurers
	for p in adv.parties:
		var mem: Array = p.members.map(func(m): return "%s (%s %d%s)" % [m.name, m["class"], m.level, "" if m.alive else ", morto"])
		v.add_child(_label("%s: %s" % [p.name, ", ".join(mem)], 8))
	if tr.current_region == "valkaria" and eco.enabled:
		var srow := HFlowContainer.new()
		for it in Game.db.economy.get("shops", {}).get("valkaria_mercado", []):
			srow.add_child(_button("%s T$%d" % [Game.db.items[it].name, eco.price(it, "valkaria")], func():
				_cmd_log("Buy", {"npc_id": "valkaria_mercado", "item": it}); refresh_hub()))
		v.add_child(srow)
		v.add_child(_label("Ouro: T$ %d" % Game.world.player.gold, 8))
	v.add_child(_button("Descansar numa estalagem (8h)", func(): var r := Game.send("Rest"); refresh_hub()))
	for route in tr.available_routes():
		v.add_child(_button("Viajar: " + route.replace("->", " → ").replace("_", " "), func():
			var r := Game.send("Travel", {"route": route})
			if not r.accepted: log_msg("✘ " + "; ".join(r.errors))
			refresh_hub()
			Game.world_reloaded.emit()))


# --- Depuração (F3) --------------------------------------------------------------------------
func _build_debug(root: Control) -> void:
	debug_label = _label("", 7)
	debug_label.position = Vector2(440, 44)
	debug_label.size = Vector2(196, 200)
	debug_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	debug_label.visible = false
	root.add_child(debug_label)


func toggle_debug() -> void:
	debug_label.visible = not debug_label.visible


func _update_debug() -> void:
	var w := Game.world
	var t := Game.telemetry.report()
	var mods: Array = []
	for id in w.modules:
		mods.append(("" if w.modules[id].enabled else "✘") + id)
	var npcs: NpcModule = w.modules.npcs
	var l1 := 0
	for id in npcs.state:
		if npcs.state[id].alive: l1 += 1
	debug_label.text = "FPS %d · frame p95 %.1fms · cmd p95 %.2fms\ntick %d · rev %d · journal %d\nNPCs L1 %d · seed %s\nRNG combat/world/weather separados\n%s" % [
		Engine.get_frames_per_second(), t.frame_p95_ms, t.cmd_p95_ms, w.clock.tick, w.revision, w.journal.size(), l1, str(w.rng.world_seed), " ".join(mods)]


func _refresh_mode() -> void:
	var m := Game.mode
	panel_title.visible = m == Game.Mode.TITLE
	if m != Game.Mode.TITLE:
		panel_lab.visible = false
	panel_over.visible = m == Game.Mode.GAMEOVER
	combat_bar.visible = m == Game.Mode.COMBAT
	combat_belt.visible = m == Game.Mode.COMBAT
	belt.visible = m == Game.Mode.EXPLORE
	hud_status.visible = m in [Game.Mode.EXPLORE, Game.Mode.COMBAT]
	hud_clock.visible = m == Game.Mode.EXPLORE
	if m != Game.Mode.DIALOGUE:
		panel_dialogue.visible = false
		_dlg_shown_text = ""
	else:
		refresh_dialogue()
	if m != Game.Mode.EXPLORE:
		panel_interact.visible = false


func any_panel_open() -> bool:
	return panel_journal.visible or panel_pause.visible or panel_shop.visible or panel_interact.visible or panel_creation.visible or panel_xp.visible or panel_tree.visible or panel_inv.visible or panel_guild.visible or spell_wheel.visible or panel_cast.visible


func close_panels() -> bool:
	var was := any_panel_open()
	panel_journal.visible = false
	panel_shop.visible = false
	panel_interact.visible = false
	panel_pause.visible = false
	panel_creation.visible = false
	panel_credits.visible = false
	panel_xp.visible = false
	panel_tree.visible = false
	panel_inv.visible = false
	panel_guild.visible = false
	spell_wheel.visible = false
	panel_cast.visible = false
	return was


func _build_inv(root: Control) -> void:
	panel_inv = InventoryPanel.new()
	root.add_child(panel_inv)
	panel_inv.position = Vector2(20, 14)
	panel_inv.visibility_changed.connect(_on_panel_shown.bind(panel_inv))
	panel_inv.visible = false
	panel_inv.command.connect(func(t: String, p: Dictionary): _cmd_log(t, p))


func _build_wheel(root: Control) -> void:
	spell_wheel = SpellWheel.new()
	root.add_child(spell_wheel)
	spell_wheel.visible = false
	spell_wheel.picked.connect(_on_spell_picked)
	panel_cast = _panel(root, Control.PRESET_CENTER)
	panel_cast.position = Vector2(180, 120)
	var v := VBoxContainer.new()
	panel_cast.add_child(v)
	_cast_title = _h("")
	v.add_child(_cast_title)
	_cast_row = HFlowContainer.new()
	_cast_row.custom_minimum_size = Vector2(300, 0)
	v.add_child(_cast_row)
	v.add_child(_button("Fechar", func(): panel_cast.visible = false))
	panel_cast.visible = false


func toggle_wheel() -> void:
	if spell_wheel.visible:
		spell_wheel.visible = false
	else:
		panel_cast.visible = false
		spell_wheel.open()


func _on_spell_picked(sp: String) -> void:
	if Game.mode == Game.Mode.COMBAT:
		combat_view.select_spell(sp)
		return
	var w: WorldState = Game.world
	var s := w.player_sheet
	for c in _cast_row.get_children():
		_cast_row.remove_child(c)
		c.queue_free()
	_cast_title.text = "Lançar " + str(GhostPlanner.spell_rule(w.rules, sp).get("nome", sp)) + " (fora de combate)"
	if w.rules.value("magia." + sp, {}).has("cura"):
		_cast_row.add_child(_button("Lançar em mim", func(): _cmd_log("CastSpell", {"spell": sp}); panel_cast.visible = false))
	_botoes_magia_fora(w, s, _cast_row, sp)
	if _cast_row.get_child_count() == 0:
		_cast_row.add_child(_label("Não há como lançar esta magia aqui fora de combate.", 9))
	panel_cast.visible = true


func _build_guild(root: Control) -> void:
	panel_guild = GuildPanel.new()
	root.add_child(panel_guild)
	panel_guild.position = Vector2(40, 24)
	panel_guild.visible = false
	panel_guild.command.connect(func(t: String, p: Dictionary): _cmd_log(t, p))


func toggle_guild() -> void:
	panel_guild.visible = not panel_guild.visible
	if panel_guild.visible:
		panel_guild.refresh()


func toggle_inv() -> void:
	panel_inv.visible = not panel_inv.visible
	if panel_inv.visible:
		panel_inv.refresh()


func _build_tree(root: Control) -> void:
	panel_tree = PowerPanel.new()
	root.add_child(panel_tree)
	panel_tree.position = Vector2(20, 14)
	panel_tree.visibility_changed.connect(_on_panel_shown.bind(panel_tree))
	panel_tree.visible = false
	panel_tree.chose.connect(func(pw: String, opt: String):
		_cmd_log("ChoosePower", {"power": pw, "option": opt})
		panel_tree.refresh())


## Subida de nível (Arton Viva, Fase 6 / progressão dinâmica): painel com o ganho de PV e PM e as opções
## atuais, cada uma com seu efeito. Some quando não há mais poder pendente.
func _build_subida(root: Control) -> void:
	panel_subida = PanelContainer.new()
	panel_subida.custom_minimum_size = Vector2(360, 0)
	root.add_child(panel_subida)
	panel_subida.position = Vector2(20, 22)
	panel_subida.visible = false


func _abre_subida() -> void:
	if Game.world == null or Game.world.player_sheet.pending_powers <= 0:
		return
	panel_subida.visible = true
	_refresh_subida()


func _refresh_subida() -> void:
	for c in panel_subida.get_children():
		c.queue_free()
	var s: CharacterSheet = Game.world.player_sheet
	var prog: ProgressionModule = Game.world.modules.progression
	if s.pending_powers <= 0:
		panel_subida.visible = false
		return
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(360, 240)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_subida.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(_h("Nível %d — escolha um poder (%d pendente%s)" % [s.level, s.pending_powers, "s" if s.pending_powers > 1 else ""]))
	v.add_child(_label("PV máx. %d · PM máx. %d · próximo nível em %d XP" % [s.pv_max, s.pm_max, prog.xp_to_next()], 8))
	for info in prog.available_powers().map(func(p): return prog.power_info(p)):
		var nome: String = PowerTreePanel.NAMES.get(info.id, info.id)
		var txt := "%s — %s" % [nome, info.efeito] if info.efeito != "" else nome
		if info.id == "aumento_atributo":
			v.add_child(_label("Aumento de atributo (+1 em um atributo):", 8))
			var linha := HFlowContainer.new()
			for a in ["for", "des", "con", "int", "sab", "car"]:
				linha.add_child(_button("%s (%d)" % [a.to_upper(), int(s.attrs[a])], func(): _escolhe_poder(info.id, a)))
			v.add_child(linha)
			continue
		var b := _button(txt, func(): _escolhe_poder(info.id, ""))
		b.add_theme_font_size_override("font_size", 8)
		v.add_child(b)
	v.add_child(_button("Escolher depois", func(): panel_subida.visible = false))


func _escolhe_poder(poder: String, opcao: String) -> void:
	var r = Game.send("ChoosePower", {"power": poder, "option": opcao})
	if not r.accepted:
		log_msg("✘ " + "; ".join(r.errors))
	_refresh_subida()


func toggle_tree() -> void:
	panel_tree.visible = not panel_tree.visible
	if panel_tree.visible:
		panel_tree.refresh()


func show_toast(text: String) -> void:
	if text == "":
		return
	toast.text = text
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)


func _on_event(e: GameEvent) -> void:
	log_msg(Narrator.line(e))
	match e.event_type:
		"TOWN_EVENT_STARTED":
			show_toast(str(e.payload.get("name", "")))
		"WEATHER_CHANGED":
			if Game.db.zone_at(Game.player_tile()) != "cripta" and e.payload.get("to", "") in ["chuva", "tempestade", "neblina"]:
				show_toast({"chuva": "A chuva chega", "tempestade": "Tempestade!", "neblina": "A neblina sobe"}.get(e.payload.to, ""))
		"LEVEL_UP":
			show_toast("Nível %d! Escolha um poder" % int(e.payload.get("level", 0)))
			_abre_subida()
		"OPEN_SHOP":
			var npc: String = Game.world.modules.dialogue.session.get("npc", "")
			if npc != "": open_shop(npc)
		"QUEST_ACCEPTED":
			show_toast("Contrato aceito: " + str(e.payload.get("titulo", "")))
		"QUEST_OBJECTIVE_DONE":
			show_toast("Cumprido: %s. %s" % [str(e.payload.get("titulo", "")), str(e.payload.get("texto", ""))])
		"QUEST_COMPLETED":
			show_toast("Contrato concluído: +T$ %d" % int(e.payload.get("ouro", 0)))
		"GUILD_RANK_UP":
			show_toast("Novo rank na guilda: " + str(e.payload.get("rank", "")))
		"FACT_REVEALED", "HYPOTHESIS_MARKED":
			if panel_journal.visible: refresh_journal()
		"XP_GAINED":
			if e.payload.get("combat", false):
				show_xp_summary(e.payload)


func _process(_d: float) -> void:
	if Game.world == null:
		return
	update_hud()
	if debug_label.visible:
		_update_debug()
	if Game.mode == Game.Mode.COMBAT:
		update_combat_bar()


# --- Tela de preparo ---------------------------------------------------------------------------
var _loading: ColorRect


func show_loading(on: bool) -> void:
	if _loading == null:
		_loading = ColorRect.new()
		_loading.color = Color(0.03, 0.025, 0.03)
		_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
		_loading.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := _label("Preparando a vila...", 12)
		l.position = Vector2(0, 170)
		l.size = Vector2(640, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
		_loading.add_child(l)
		add_child(_loading)
	if on:
		_loading.modulate.a = 1.0
		_loading.visible = true
	else:
		var tw := create_tween()
		tw.tween_property(_loading, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func(): _loading.visible = false)


## Magias fora de combate (SpellsModule.FORA_DE_COMBATE): um botão por versão útil, com o alvo por perto.
func _botoes_magia_fora(w: WorldState, s: CharacterSheet, row: HFlowContainer, so: String = "") -> void:
	var magia = w.module("magia")
	if magia == null:
		return
	if s.can_use_skill("misticismo", w.rules):
		if so == "": row.add_child(_button("Detectar magia (Misticismo)", func(): _cmd_log("DetectMagic", {}); refresh_journal()))
	var p := w.db.world_to_tile(w.player.position)
	var combat = w.module("combat")
	for sp in s.spells:
		if not magia.FORA_DE_COMBATE.has(sp) or (so != "" and sp != so):
			continue
		var nome := str(w.rules.value("magia." + sp, {}).get("nome", sp))
		match sp:
			"aviso":
				row.add_child(_button("Aviso: alerta em mim", func(): _cmd_log("CastSpell", {"spell": sp, "modo": "alerta"}); refresh_journal()))
			"visao_mistica":
				row.add_child(_button("Lançar " + nome, func(): _cmd_log("CastSpell", {"spell": sp}); refresh_journal()))
			"compreensao":
				var npcs_c = w.module("npcs")
				if npcs_c != null:
					for npc in npcs_c.npcs_at(w.db.location_at(p)):
						if s.efeito_tipo_existe("compreende", npc):
							row.add_child(_button("Ouvir pensamentos de " + str(npc), func(): _cmd_log("ReadThoughts", {"target": npc}); refresh_journal()))
						else:
							row.add_child(_button("Compreensão em " + str(npc), func(): _cmd_log("CastSpell", {"spell": sp, "targets": [npc]}); refresh_journal()))
			"criar_elementos":
				row.add_child(_button("Criar água", func(): _cmd_log("CastSpell", {"spell": sp, "elemento": "agua"}); refresh_journal()))
				row.add_child(_button("Chama na palma", func(): _cmd_log("CastSpell", {"spell": sp, "elemento": "fogo"}); refresh_journal()))
			"consagrar", "profanar", "caminhos_da_natureza", "detectar_ameacas", "suporte_ambiental":
				row.add_child(_button("Lançar " + nome, func(): _cmd_log("CastSpell", {"spell": sp}); refresh_journal()))
			"abencoar_alimentos":
				for it in w.modules.state.inventory:
					if bool(Game.db.items.get(it, {}).get("alimento", false)):
						row.add_child(_button("Abençoar " + str(Game.db.items.get(it, {}).get("name", it)), func(): _cmd_log("CastSpell", {"spell": sp, "item": it}); refresh_journal()))
				if w.modules.state.has_item("frasco_agua"):
					row.add_child(_button("Fazer água benta", func(): _cmd_log("CastSpell", {"spell": sp, "aprimoramentos": [1]}); refresh_journal()))
			"controlar_plantas":
				row.add_child(_button("Podar plantas", func(): _cmd_log("CastSpell", {"spell": sp, "aprimoramentos": [0]}); refresh_journal()))
				row.add_child(_button("Falar com plantas", func(): _cmd_log("CastSpell", {"spell": sp, "aprimoramentos": [2]}); refresh_journal()))
			"despedacar":
				for o in w.db.all_objects():
					var ot := Vector2i(int(o.tile[0]), int(o.tile[1]))
					if o.has("break") and maxi(absi(ot.x - p.x), absi(ot.y - p.y)) <= 6:
						row.add_child(_button("Despedaçar " + str(o.get("name", o.id)), func(): _cmd_log("CastSpell", {"spell": sp, "objeto": o.id}); refresh_journal()))
			"bencao", "acalmar_animal", "tranquilidade":
				if combat == null:
					continue
				for cid in combat.creature_state:
					var cs: Dictionary = combat.creature_state[cid]
					var ct: Array = cs.get("tile", [0, 0])
					if maxi(absi(int(ct[0]) - p.x), absi(int(ct[1]) - p.y)) > 6:
						continue
					if sp == "bencao" and not bool(cs.get("alive", true)):
						row.add_child(_button("Bênção no cadáver (" + str(cid) + ")", func(): _cmd_log("CastSpell", {"spell": sp, "target": cid, "aprimoramentos": [0]}); refresh_journal()))
					elif sp != "bencao" and combat.is_active_creature(cid):
						row.add_child(_button(nome + " (" + str(cid) + ")", func(): _cmd_log("CastSpell", {"spell": sp, "targets": [cid]}); refresh_journal()))
