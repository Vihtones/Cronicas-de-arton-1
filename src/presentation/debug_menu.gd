class_name DebugMenu
extends PanelContainer
## Menu de debug (F2): teleporte e ajuste de variáveis do mundo, sem andar pelo mapa.
## Só envia comandos (DebugTeleport, DebugSet, AdvanceTime): quem muda o mundo é o domínio, com validação.
## Ferramenta de desenvolvimento. Para ocultar em builds de jogador, mude ENABLED para false.

const ENABLED := true

var _body: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -300
	offset_top = 4
	offset_right = -4
	offset_bottom = -4
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(288, 0)
	_body.add_theme_constant_override("separation", 3)
	sc.add_child(_body)


func toggle() -> void:
	if not ENABLED or Game.world == null:
		return
	visible = not visible
	if visible:
		rebuild()


func rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_title("DEBUG  (F2 fecha)")
	_info(_estado())
	_title("Tempo")
	_row([_btn("+1 hora", func(): _send("AdvanceTime", {"ticks": 6})), _btn("+1 dia", func(): _send("AdvanceTime", {"ticks": 144}))])
	var horas: Array = []
	for h in range(24):
		horas.append(str(h))
	var hora := _option(horas, Game.world.hour())
	_row([hora.control, _btn("Ir para a hora", func(): _ajustar({"key": "hour", "value": hora.index()}))])
	_title("Você")
	var ouro := _spin(Game.world.player.gold, 0, 9999)
	_row([_label("Ouro"), ouro.control, _btn("Aplicar", func(): _ajustar({"key": "gold", "value": int(ouro.value())}))])
	_title("Teleporte")
	var locs := _locations()
	var loc := _option(locs.names, 0)
	_row([loc.control, _btn("Ir", func(): _tele({"location": locs.ids[loc.index()]}))])
	var npcs := _npcs()
	var npc := _option(npcs.names, 0)
	_row([npc.control, _btn("Ir até", func(): _tele({"npc": npcs.ids[npc.index()]}))])
	_title("Vila")
	var bem := _option(["comida", "bebida", "ferramentas", "remedio", "madeira"], 0)
	var estoque := _spin(int(Game.world.modules.economy.regions.vila.stock.comida), 0, 9999)
	var aplicar_estoque := func(): _ajustar({"key": "stock", "good": bem.text(), "value": int(estoque.value())})
	_row([bem.control, estoque.control, _btn("Aplicar", aplicar_estoque)])
	var tes := _spin(int(Game.world.modules.economy.treasury), 0, 99999)
	_row([_label("Tesouro"), tes.control, _btn("Aplicar", func(): _ajustar({"key": "treasury", "value": int(tes.value())}))])
	var clima := _option(_climas(), 0)
	_row([_label("Clima"), clima.control, _btn("Aplicar", func(): _ajustar({"key": "weather", "value": clima.text()}))])
	_title("Morador")
	var alvo := _option(npcs.names, 0)
	var nid := func() -> String: return npcs.ids[alvo.index()]
	var mo := _spin(int(Game.world.modules.npc_needs.gold(npcs.ids[0])), 0, 9999)
	_row([alvo.control, _label("Ouro"), mo.control])
	_row([_btn("Aplicar ouro", func(): _ajustar({"key": "npc_gold", "npc": nid.call(), "value": int(mo.value())})),
		_btn("Ir até ele", func(): _tele({"npc": nid.call()}))])
	var fome := _spin(0.0, 0.0, 1.0, 0.1)
	var cansaco := _spin(0.0, 0.0, 1.0, 0.1)
	_row([_label("Fome"), fome.control, _btn("Aplicar", func(): _ajustar({"key": "npc_hunger", "npc": nid.call(), "value": fome.value()}))])
	_row([_label("Cansaço"), cansaco.control, _btn("Aplicar", func(): _ajustar({"key": "npc_tired", "npc": nid.call(), "value": cansaco.value()}))])
	var onde := _option(locs.names, 0)
	_row([_label("Mover para"), onde.control, _btn("Mover", func(): _ajustar({"key": "npc_location", "npc": nid.call(), "value": locs.ids[onde.index()]}))])


func _estado() -> String:
	var w: WorldState = Game.world
	var dia := int(w.clock.tick / (24 * 60 / w.clock.tick_minutes)) + 1
	var eco = w.modules.economy
	return "dia %d, %02dh · ouro %d · tesouro %d · comida %d · clima %s" % [dia, w.hour(), w.player.gold,
		eco.treasury, int(eco.regions.vila.stock.comida), str(w.modules.weather.region.condition)]


func _locations() -> Dictionary:
	var ids: Array = []
	var names: Array = []
	for l in Game.db.all_locations():
		ids.append(str(l.id))
		names.append(str(l.get("name", l.id)))
	return {"ids": ids, "names": names}


func _npcs() -> Dictionary:
	var ids: Array = []
	var names: Array = []
	for id in Game.world.all_npc_ids():
		ids.append(id)
		names.append(str(Game.world.npc_def(id).get("name", id)))
	return {"ids": ids, "names": names}


func _climas() -> Array:
	return WeatherModule.TRANSITIONS.keys()


func _send(tipo: String, payload: Dictionary) -> void:
	Game.send(tipo, payload)
	Game.world_reloaded.emit()
	rebuild()


func _ajustar(payload: Dictionary) -> void:
	_send("DebugSet", payload)


func _tele(payload: Dictionary) -> void:
	if Game.mode != Game.Mode.EXPLORE:
		return
	_send("DebugTeleport", payload)
	toggle()


func _title(t: String) -> void:
	var l := _label(t)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	_body.add_child(l)


func _info(t: String) -> void:
	var l := _label(t)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 8)
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	return b


func _row(items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	for it in items:
		h.add_child(it)
	_body.add_child(h)


## Lista suspensa com índice e texto do item escolhido.
class Opt:
	var control: OptionButton
	func index() -> int: return control.selected
	func text() -> String: return control.get_item_text(control.selected)


func _option(items: Array, selected: int) -> Opt:
	var o := Opt.new()
	o.control = OptionButton.new()
	o.control.add_theme_font_size_override("font_size", 8)
	for t in items:
		o.control.add_item(str(t))
	o.control.select(clampi(selected, 0, maxi(0, items.size() - 1)))
	return o


## Campo numérico com valor() (SpinBox).
class Num:
	var control: SpinBox
	func value() -> float: return control.value


func _spin(valor: float, lo: float, hi: float, passo: float = 1.0) -> Num:
	var n := Num.new()
	n.control = SpinBox.new()
	n.control.min_value = lo
	n.control.max_value = hi
	n.control.step = passo
	n.control.value = valor
	n.control.custom_minimum_size = Vector2(62, 0)
	n.control.add_theme_font_size_override("font_size", 8)
	return n
