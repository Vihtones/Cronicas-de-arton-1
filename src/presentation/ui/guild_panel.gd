class_name GuildPanel
extends PanelContainer
## Guilda e missões. No quadro (na sede): inscrição, contratos oferecidos e entrega dos cumpridos.
## Fora da sede (tecla L): diário de missões com o progresso de cada contrato ativo.

signal command(type: String, payload: Dictionary)

var _v: VBoxContainer


func _init() -> void:
	UiEstilo.janela(self)
	custom_minimum_size = Vector2(560, 300)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 300)
	add_child(sc)
	_v = VBoxContainer.new()
	_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_v)


func refresh() -> void:
	var w: WorldState = Game.world
	if w == null:
		return
	var q: QuestModule = w.modules.quests
	for c in _v.get_children():
		_v.remove_child(c)
		c.queue_free()
	var g := q.guilda()
	var sede := q.na_sede()
	_v.add_child(_lbl(("Quadro da " if sede else "Missões — ") + str(g.get("nome", "Guilda")) + "  [L / Esc fecha]", 11, Color(0.98, 0.82, 0.45)))
	if q.membro:
		var prox := q.proximo_rank()
		_v.add_child(_lbl("Rank %s · %d pontos%s · contratos cumpridos: %d" % [str(q.rank().get("nome", "")), q.pontos,
			(" (próximo: %s em %d)" % [prox.nome, int(prox.pontos)]) if not prox.is_empty() else "", q.feitas.size()], 9))
	else:
		_v.add_child(_lbl("Você não é membro. A inscrição custa T$ %d e é feita na sede (%s)." % [int(g.get("taxa", 10)), str(w.db.location(str(g.get("sede", ""))).get("name", ""))], 9))
		if sede:
			_v.add_child(_btn("Inscrever-se (T$ %d)" % int(g.get("taxa", 10)), func(): command.emit("JoinGuild", {}); refresh()))
	_v.add_child(_lbl("Contratos ativos", 10, Color(1, 0.82, 0.4)))
	if q.ativas.is_empty():
		_v.add_child(_lbl("Nenhum.", 9))
	for qid in q.ativas:
		var a: Dictionary = q.ativas[qid]
		var row := HBoxContainer.new()
		var l := _lbl("• %s — %s  (T$ %d, %d pts)" % [a.titulo, q.progresso_texto(a), int(a.ouro), int(a.pontos)], 9, Color(0.6, 0.95, 0.6) if bool(a.progresso.feito) else Color(0.92, 0.9, 0.85))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if bool(a.progresso.feito):
			row.add_child(_btn("Receber", func(): command.emit("TurnInQuest", {"quest_id": qid}); refresh()))
		row.add_child(_btn("Abandonar", func(): command.emit("AbandonQuest", {"quest_id": qid}); refresh()))
		_v.add_child(row)
	if not sede or not q.membro:
		return
	_v.add_child(_lbl("No quadro", 10, Color(1, 0.82, 0.4)))
	for c in q.contratos():
		var box := VBoxContainer.new()
		var cab := "%s%s  —  T$ %d · %d pts%s" % [c.titulo, ("  [ARRISCADO]" if bool(c.get("risco", false)) else ""), int(c.ouro), int(c.pontos),
			("  · ND %s" % str(snappedf(float(c.nd), 0.25))) if float(c.nd) > 0 else ""]
		box.add_child(_lbl(cab, 10, Color(1, 0.55, 0.45) if bool(c.get("risco", false)) else Color(0.95, 0.88, 0.7)))
		box.add_child(_lbl(str(c.texto), 8, Color(0.82, 0.82, 0.8)))
		var cid: String = c.id
		box.add_child(_btn("Aceitar", func(): command.emit("AcceptQuest", {"quest_id": cid}); refresh()))
		_v.add_child(box)


func _lbl(text: String, size: int, cor: Color = Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
