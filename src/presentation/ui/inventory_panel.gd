class_name InventoryPanel
extends PanelContainer
## Inventário (tecla I): equipado à esquerda, mochila em grade, ficha do item selecionado com a comparação
## com o que está equipado. Tudo vira comando do domínio (Equip, Unequip, UseItem), que valida de novo.

signal command(type: String, payload: Dictionary)

const SLOTS := {"weapon": "Arma", "armor": "Armadura"}
const COR_TIPO := {"Arma": Color(0.85, 0.45, 0.35), "Armadura": Color(0.45, 0.6, 0.85), "Poção": Color(0.8, 0.35, 0.7),
	"Alimento": Color(0.7, 0.65, 0.35), "Luz": Color(0.95, 0.8, 0.35), "Item": Color(0.6, 0.6, 0.6)}

var _sel := ""
var _slots_box: VBoxContainer
var _grid: GridContainer
var _detalhe: VBoxContainer
var _rodape: Label


func _init() -> void:
	custom_minimum_size = Vector2(620, 330)
	var v := VBoxContainer.new()
	add_child(v)
	var t := _lbl("Inventário  [I fecha]", 11, Color(0.98, 0.82, 0.45))
	v.add_child(t)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	_slots_box = VBoxContainer.new()
	_slots_box.custom_minimum_size.x = 150
	h.add_child(_slots_box)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 270)
	h.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 4
	sc.add_child(_grid)
	_detalhe = VBoxContainer.new()
	_detalhe.custom_minimum_size.x = 190
	h.add_child(_detalhe)
	_rodape = _lbl("", 9)
	v.add_child(_rodape)


func refresh() -> void:
	var w: WorldState = Game.world
	if w == null:
		return
	var s := w.player_sheet
	for c in _slots_box.get_children() + _grid.get_children() + _detalhe.get_children():
		c.queue_free()
	_slots_box.add_child(_lbl("Equipado", 10, Color(1, 0.82, 0.4)))
	for sl in SLOTS:
		var it: String = s.equipment.get(sl, "")
		var b := _btn("%s: %s" % [SLOTS[sl], ItemsModule.info(w.rules, w.db, it).nome if it != "" else "—"], func(): _sel = "@" + sl; refresh())
		_slots_box.add_child(b)
	_slots_box.add_child(_lbl("Defesa %d · PV %d/%d · PM %d/%d" % [s.defense(w.rules), s.pv, s.pv_max, s.pm, s.pm_max], 8))
	for atk in s.attacks:
		_slots_box.add_child(_lbl("%s: %s, %s/x%d" % [atk.nome, atk.dano, str(atk.margem), int(atk.mult)], 8))
	var inv: Dictionary = w.modules.state.inventory
	for it in inv:
		if int(inv[it]) <= 0:
			continue
		var i := ItemsModule.info(w.rules, w.db, it)
		var b := _btn("%s\nx%d" % [i.nome, int(inv[it])], func(): _sel = it; refresh())
		b.custom_minimum_size = Vector2(60, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_color", COR_TIPO.get(i.tipo, Color.WHITE))
		if it == _sel:
			b.modulate = Color(1.3, 1.3, 1.0)
		_grid.add_child(b)
	_mostrar_detalhe(w, s)
	_rodape.text = "Ouro: T$ %d · %d tipos de item" % [int(w.player.gold), inv.size()]


func _mostrar_detalhe(w: WorldState, s: CharacterSheet) -> void:
	if _sel == "":
		_detalhe.add_child(_lbl("Clique num item para ver a ficha.", 9))
		return
	if _sel.begins_with("@"):
		var sl := _sel.substr(1)
		var eq: String = s.equipment.get(sl, "")
		if eq == "":
			_detalhe.add_child(_lbl("Nada equipado.", 9))
			return
		_ficha(w, eq)
		_detalhe.add_child(_btn("Desequipar", func(): command.emit("Unequip", {"slot": sl}); _sel = eq; refresh()))
		return
	if not w.modules.state.has_item(_sel):
		_sel = ""
		_mostrar_detalhe(w, s)
		return
	var i := _ficha(w, _sel)
	var cmp := ItemsModule.comparar(w.rules, w.db, _sel, s)
	if cmp != "":
		var bom := cmp.begins_with("+") or cmp.contains("+") and not cmp.contains("-")
		_detalhe.add_child(_lbl(cmp, 9, Color(0.5, 0.9, 0.5) if bom else Color(0.95, 0.55, 0.45)))
	var it := _sel
	if str(i.slot) != "":
		_detalhe.add_child(_btn("Equipar", func(): command.emit("Equip", {"item": it}); _sel = "@" + str(i.slot); refresh()))
	if bool(i.usavel):
		_detalhe.add_child(_btn("Usar", func(): command.emit("UseItem", {"item": it, "bonus": "pv"}); refresh()))


func _ficha(w: WorldState, id: String) -> Dictionary:
	var i := ItemsModule.info(w.rules, w.db, id)
	_detalhe.add_child(_lbl(i.nome, 11, COR_TIPO.get(i.tipo, Color.WHITE)))
	_detalhe.add_child(_lbl(i.tipo + ("  ·  T$ %d" % int(i.preco) if int(i.preco) > 0 else ""), 8, Color(0.75, 0.75, 0.75)))
	for l in i.linhas:
		_detalhe.add_child(_lbl("• " + str(l), 9))
	return i


func _lbl(text: String, size: int, cor: Color = Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
