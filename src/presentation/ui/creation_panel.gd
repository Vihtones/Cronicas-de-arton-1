class_name CreationPanel
extends PanelContainer
## Criação de personagem em etapas (LB cap. 1): Raça → Classe → Atributos (compra de 10 pontos, LB p.17) →
## Perícias e magias → Resumo. Cada etapa mostra o que a escolha dá em números de regra; o domínio
## (CharacterBuilder) monta e valida a ficha. A prévia à direita acompanha todas as etapas.

signal concluido(build: Dictionary, feminino: bool, destino: bool)
signal cancelado

const ETAPAS := ["Raça", "Classe", "Atributos", "Perícias e magias", "Resumo"]
const ATR := ["for", "des", "con", "int", "sab", "car"]
const ATR_NOME := {"for": "Força", "des": "Destreza", "con": "Constituição", "int": "Inteligência", "sab": "Sabedoria", "car": "Carisma"}
const RACA_TXT := {
	"humano": "Versáteis e ambiciosos, estão em toda parte de Arton.", "anao": "Robustos, teimosos e mestres da forja; enxergam no escuro.",
	"dahllan": "Meio-dríades ligadas às plantas e à deusa Allihanna.", "elfo": "Graciosos e longevos, de mente afiada e sentidos aguçados.",
	"goblin": "Pequenos, engenhosos e difíceis de matar.", "lefou": "Tocados pela Tormenta; carregam deformidades e poder aberrante.",
	"minotauro": "Fortes e orgulhosos, com chifres e faro apurado.", "qareen": "Descendentes de gênios, com uma tatuagem mística.",
	"golem": "Construtos despertos, de corpo duro e mente nova.", "hynne": "Pequeninos ágeis e sortudos, de pés ligeiros.",
	"kliren": "Inventores curiosos, metade gnomo, metade humano.", "medusa": "Olhar que petrifica e cabelos de serpente.",
	"osteon": "Esqueletos que voltaram à vida sem perder a consciência.", "sereia": "Povo do mar que caminha em terra, de voz encantadora.",
	"silfide": "Fadas pequenas e aladas, travessas e mágicas.", "aggelus": "Tocados pelos deuses do bem, de presença radiante.",
	"sulfure": "Tocados pelas trevas, ardilosos e sombrios.", "trog": "Homens-lagarto das cavernas, de cheiro repulsivo e mordida forte."}
const CLASSE_TXT := {
	"guerreiro": "Mestre das armas e das táticas. Muitos ataques e poderes de combate.", "ladino": "Ágil e esperto; Ataque Furtivo e muitas perícias.",
	"arcanista": "Conjura magias arcanas: bruxo (foco), feiticeiro (linhagem) ou mago (grimório).", "barbaro": "Fúria selvagem que aumenta o dano e a resistência.",
	"paladino": "Guerreiro sagrado: cura pelas mãos, golpe divino e aura.", "nobre": "Líder e diplomata: comanda aliados e usa a palavra como arma.",
	"bucaneiro": "Espadachim audaz que luta com estilo e sorte.", "cavaleiro": "Defensor de armadura pesada que protege os aliados.",
	"cacador": "Rastreador e arqueiro, inimigo jurado de certas presas.", "inventor": "Cria engenhocas, poções e armas melhoradas.",
	"clerigo": "Servo de um deus: magias divinas de cura e proteção."}

const PER_NOME := {"acrobacia": "Acrobacia", "adestramento": "Adestramento", "atletismo": "Atletismo", "atuacao": "Atuação", "cavalgar": "Cavalgar",
	"conhecimento": "Conhecimento", "cura": "Cura", "diplomacia": "Diplomacia", "enganacao": "Enganação", "fortitude": "Fortitude", "furtividade": "Furtividade",
	"guerra": "Guerra", "iniciativa": "Iniciativa", "intimidacao": "Intimidação", "intuicao": "Intuição", "investigacao": "Investigação", "jogatina": "Jogatina",
	"ladinagem": "Ladinagem", "luta": "Luta", "misticismo": "Misticismo", "nobreza": "Nobreza", "oficio": "Ofício", "percepcao": "Percepção",
	"pilotagem": "Pilotagem", "pontaria": "Pontaria", "reflexos": "Reflexos", "religiao": "Religião", "sobrevivencia": "Sobrevivência", "vontade": "Vontade"}
var etapa := 0
var c := {"race": "humano", "class": "guerreiro", "attrs": {"for": 0, "des": 0, "con": 0, "int": 0, "sab": 0, "car": 0}, "human_picks": ["for", "des", "con"],
	"class_picks": [], "free_picks": [], "path": "bruxo", "spells": [], "name": "", "feminino": false}
var herdeiro := false
var _corpo: VBoxContainer
var _previa: VBoxContainer
var _abas: HBoxContainer


func _init() -> void:
	UiEstilo.janela(self)
	custom_minimum_size = Vector2(600, 330)
	var v := VBoxContainer.new()
	add_child(v)
	_abas = HBoxContainer.new()
	v.add_child(_abas)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(440, 290)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_corpo)
	_previa = VBoxContainer.new()
	_previa.custom_minimum_size = Vector2(140, 0)
	h.add_child(_previa)


func abrir(p_herdeiro: bool = false) -> void:
	herdeiro = p_herdeiro
	etapa = 0
	if c.attrs.values().all(func(x): return int(x) == 0):
		c.attrs = (CharacterBuilder.presets(c["class"])[0] as Dictionary).duplicate()
	visible = true
	refresh()


func refresh() -> void:
	for n in _abas.get_children() + _corpo.get_children() + _previa.get_children():
		n.get_parent().remove_child(n)
		n.queue_free()
	for i in ETAPAS.size():
		var b := _btn("%d. %s" % [i + 1, ETAPAS[i]], func(): etapa = i; refresh())
		b.modulate = Color(1.3, 1.2, 0.8) if i == etapa else Color(0.7, 0.7, 0.7)
		_abas.add_child(b)
	match etapa:
		0: _etapa_raca()
		1: _etapa_classe()
		2: _etapa_atributos()
		3: _etapa_pericias()
		4: _etapa_resumo()
	var nav := HBoxContainer.new()
	if etapa > 0:
		nav.add_child(_btn("◀ Voltar", func(): etapa -= 1; refresh()))
	if etapa < ETAPAS.size() - 1:
		nav.add_child(_btn("Avançar ▶", func(): etapa += 1; refresh()))
	nav.add_child(_btn("Cancelar", func(): visible = false; cancelado.emit()))
	_corpo.add_child(nav)
	_mostrar_previa()


func build_dict() -> Dictionary:
	var nome := str(c.name).strip_edges()
	return {"race": c.race, "class": c["class"], "attrs": c.attrs.duplicate(), "human_picks": c.human_picks.duplicate(), "class_picks": c.class_picks.duplicate(),
		"free_picks": c.free_picks.duplicate(), "path": c.path, "spells": c.spells.duplicate(),
		"name": nome if nome != "" else ("Aventureira" if c.feminino else "Aventureiro")}


func ficha() -> CharacterSheet:
	return CharacterBuilder.build_from(Game.rules, build_dict())


func erros() -> PackedStringArray:
	var e := CharacterBuilder.validate_points(Game.rules, c.attrs)
	if not c.class_picks.is_empty():
		var base := CharacterBuilder.build(Game.rules, c.race, c["class"], c.attrs, c.human_picks)
		e.append_array(CharacterBuilder.validate_skills(Game.rules, c["class"], c.race, base.attrs, c.class_picks, c.free_picks))
	return e


# --- etapas ---------------------------------------------------------------------------------------
func _etapa_raca() -> void:
	_corpo.add_child(_tit("Escolha sua raça"))
	var grade := GridContainer.new()
	grade.columns = 3
	for r in CharacterBuilder.RACES:
		var b := _btn(("● " if c.race == r else "") + str(CharacterBuilder.RACE_NAMES[r]), func(): c.race = r; c.class_picks = []; c.free_picks = []; refresh())
		b.custom_minimum_size.x = 140
		grade.add_child(b)
	_corpo.add_child(grade)
	_corpo.add_child(_lbl(str(RACA_TXT.get(c.race, "")), 9, Color(0.95, 0.88, 0.7)))
	for l in _linhas_raca(c.race):
		_corpo.add_child(_lbl("• " + l, 9))
	if CharacterBuilder.FREE_ATTR_RACES.has(c.race):
		var ex: Array = [] if c.race == "humano" else Game.rules.value("raca." + c.race).atributos_livres.excecao
		_corpo.add_child(_lbl("Escolha 3 atributos para +1%s:" % ((" (exceto " + ", ".join(ex) + ")") if not ex.is_empty() else ""), 9, Color(1, 0.82, 0.4)))
		var row := HBoxContainer.new()
		for k in ATR:
			if ex.has(k):
				continue
			var on: bool = c.human_picks.has(k)
			row.add_child(_btn(("● " if on else "") + str(k).to_upper(), func():
				if c.human_picks.has(k): c.human_picks.erase(k)
				elif c.human_picks.size() < 3: c.human_picks.append(k)
				refresh()))
		_corpo.add_child(row)


func _linhas_raca(r: String) -> Array:
	if r == "humano":
		return ["+1 em três atributos à sua escolha", "Versátil: perícias treinadas extras", "Deslocamento 9m"]
	var d: Dictionary = Game.rules.value("raca." + r, {})
	var out: Array = []
	if d.has("atributos"):
		var p: Array = []
		for k in d.atributos:
			p.append("%s %+d" % [str(k).capitalize(), int(d.atributos[k])])
		out.append("Atributos: " + ", ".join(p))
	if d.has("atributos_livres"):
		out.append("+1 em três atributos (penalidade: %s)" % JSON.stringify(d.atributos_livres.get("penalidade", {})).replace("\"", ""))
	out.append("Deslocamento %dm" % int(d.get("deslocamento_m", 9)))
	if d.has("sentidos"):
		out.append("Sentidos: " + ", ".join(PackedStringArray(d.sentidos)).replace("_", " "))
	if d.has("pv_nivel1"):
		out.append("+%d PV no 1º nível" % int(d.pv_nivel1))
	if d.has("pm_por_nivel"):
		out.append("+%d PM por nível" % int(d.pm_por_nivel))
	if d.has("pericias"):
		var ps: Array = []
		for k in d.pericias:
			ps.append("%s +%d" % [k, int(d.pericias[k])])
		out.append("Perícias: " + ", ".join(ps))
	if d.has("imune"):
		out.append("Imune: " + ", ".join(PackedStringArray(d.imune)))
	if d.has("tipo"):
		out.append("Tipo: " + str(d.tipo))
	if d.has("pendente"):
		out.append("Ainda sem efeito no jogo: " + ", ".join(PackedStringArray(d.pendente)))
	return out


func _etapa_classe() -> void:
	_corpo.add_child(_tit("Escolha sua classe"))
	var grade := GridContainer.new()
	grade.columns = 3
	for k in CharacterBuilder.CLASSES:
		var b := _btn(("● " if c["class"] == k else "") + str(CharacterBuilder.CLASS_NAMES.get(k, k)), func():
			c["class"] = k; c.class_picks = []; c.free_picks = []; c.spells = []
			c.attrs = (CharacterBuilder.presets(k)[0] as Dictionary).duplicate()
			refresh())
		b.custom_minimum_size.x = 140
		grade.add_child(b)
	_corpo.add_child(grade)
	var d: Dictionary = Game.rules.value("classe." + str(c["class"]), {})
	_corpo.add_child(_lbl(str(CLASSE_TXT.get(c["class"], "")), 9, Color(0.95, 0.88, 0.7)))
	_corpo.add_child(_lbl("• PV iniciais %d + Con, +%d por nível · PM %d por nível" % [int(d.get("pv_inicial", 0)), int(d.get("pv_nivel", 0)), int(d.get("pm_nivel", 0))], 9))
	var fixas: Array = []
	for f in d.get("pericias_fixas", []):
		fixas.append(str(f).replace("|", " ou "))
	_corpo.add_child(_lbl("• Perícias: %s, mais %d da lista" % [", ".join(fixas), int(d.get("pericias_escolha", 0))], 9))
	_corpo.add_child(_lbl("Poderes da classe (escolhidos ao subir de nível):", 9, Color(1, 0.82, 0.4)))
	for p in ProgressionModule.POWERS.get(c["class"], []).slice(0, 10):
		var ef := ProgressionModule.efeito_texto(Game.rules.value("poder." + p, {}))
		_corpo.add_child(_lbl("• %s%s" % [PowerTreePanel.NAMES.get(p, p), (" — " + ef) if ef != "" else ""], 8))
	if c["class"] == "arcanista":
		_corpo.add_child(_lbl("Caminho:", 9, Color(1, 0.82, 0.4)))
		var row := HBoxContainer.new()
		var desc := {"bruxo": "Int, usa foco", "feiticeiro": "Car, linhagem", "mago": "Int, grimório, +1 magia"}
		for pth in CharacterBuilder.ARCANE_PATHS:
			row.add_child(_btn(("● " if c.path == pth else "") + "%s (%s)" % [pth.capitalize(), desc[pth]], func(): c.path = pth; c.spells = []; refresh()))
		_corpo.add_child(row)


func _etapa_atributos() -> void:
	var tabela: Dictionary = Game.rules.value("atributos.compra_pontos")
	var custo: Dictionary = tabela.custo
	var gasto := 0
	for k in ATR:
		gasto += int(custo.get(str(int(c.attrs[k])), 0))
	_corpo.add_child(_tit("Atributos — %d de %d pontos (LB p.17)" % [gasto, int(tabela.pontos)]))
	_corpo.add_child(_lbl("Custo: −1 devolve 1 ponto · 0 grátis · 1 custa 1 · 2 custa 2 · 3 custa 4 · 4 custa 7. O valor final soma a raça.", 8))
	var s := ficha()
	for k in ATR:
		var row := HBoxContainer.new()
		var l := _lbl(str(ATR_NOME[k]), 9)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size.x = 100
		row.add_child(l)
		row.add_child(_btn("−", func(): _muda(k, -1)))
		var v := _lbl("%+d" % int(c.attrs[k]), 10)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.custom_minimum_size.x = 30
		row.add_child(v)
		row.add_child(_btn("+", func(): _muda(k, 1)))
		row.add_child(_sem_quebra(_lbl("   final %+d" % int(s.attrs[k]), 9, Color(0.6, 0.9, 0.6) if int(s.attrs[k]) > int(c.attrs[k]) else (Color(0.95, 0.55, 0.45) if int(s.attrs[k]) < int(c.attrs[k]) else Color(0.85, 0.85, 0.85)))))
		_corpo.add_child(row)
	var pr := HBoxContainer.new()
	pr.add_child(_sem_quebra(_lbl("Sugestões:", 8)))
	for pre in CharacterBuilder.presets(c["class"]):
		var pd: Dictionary = pre
		pr.add_child(_btn("F%d D%d C%d I%d S%d Ca%d" % [pd["for"], pd.des, pd.con, pd["int"], pd.sab, pd.car], func(): c.attrs = pd.duplicate(); refresh()))
	_corpo.add_child(pr)
	for e in CharacterBuilder.validate_points(Game.rules, c.attrs):
		_corpo.add_child(_lbl("✘ " + e, 9, Color(1, 0.5, 0.4)))


func _muda(k: String, d: int) -> void:
	var novo := clampi(int(c.attrs[k]) + d, -1, 4)
	var teste: Dictionary = c.attrs.duplicate()
	teste[k] = novo
	if d > 0 and not CharacterBuilder.validate_points(Game.rules, teste).is_empty():
		return
	c.attrs[k] = novo
	c.class_picks = []
	c.free_picks = []
	refresh()


func _etapa_pericias() -> void:
	var base := CharacterBuilder.build(Game.rules, c.race, c["class"], c.attrs, c.human_picks)
	var slots := CharacterBuilder.skill_slots(Game.rules, c["class"], c.race, base.attrs)
	var fixed: Array = []
	for f in Game.rules.value("classe." + c["class"]).pericias_fixas:
		fixed.append(str(f).get_slice("|", 0))
	_corpo.add_child(_tit("Perícias da classe (%d/%d)" % [c.class_picks.size(), int(slots.classe)]))
	_corpo.add_child(_lbl("Fixas: " + ", ".join(fixed) + ". Sem escolha, o jogo usa as sugeridas.", 8))
	var fl := HFlowContainer.new()
	for k in CharacterBuilder.class_list(Game.rules, c["class"]):
		if fixed.has(k):
			continue
		fl.add_child(_btn(("● " if c.class_picks.has(k) else "") + str(PER_NOME.get(k, k)), func(): _alterna(c.class_picks, k, int(slots.classe))))
	_corpo.add_child(fl)
	if int(slots.livres) > 0:
		_corpo.add_child(_tit("Perícias livres por Inteligência/raça (%d/%d)" % [c.free_picks.size(), int(slots.livres)]))
		var fl2 := HFlowContainer.new()
		for k in Game.rules.value("pericia.tabela").keys():
			if fixed.has(k) or c.class_picks.has(k):
				continue
			fl2.add_child(_btn(("● " if c.free_picks.has(k) else "") + str(PER_NOME.get(k, k)), func(): _alterna(c.free_picks, k, int(slots.livres))))
		_corpo.add_child(fl2)
	var possiveis := CharacterBuilder.magias_iniciais_possiveis(Game.rules, c["class"])
	if not possiveis.is_empty():
		var qtd := CharacterBuilder.magias_iniciais_qtd(Game.rules, c["class"], c.path)
		_corpo.add_child(_tit("Magias iniciais (%d/%d)" % [c.spells.size(), qtd]))
		_corpo.add_child(_lbl("Sem escolha, o jogo usa as sugeridas. Passe o mouse para ler a magia.", 8))
		var fl3 := HFlowContainer.new()
		for sp in possiveis:
			var m: Dictionary = Game.rules.value("magia." + sp, {})
			var b := _btn(("● " if c.spells.has(sp) else "") + str(m.get("nome", sp)), func(): _alterna(c.spells, sp, qtd))
			b.tooltip_text = str(m.get("texto", "")).substr(0, 400)
			fl3.add_child(b)
		_corpo.add_child(fl3)
	for e in erros():
		_corpo.add_child(_lbl("✘ " + e, 9, Color(1, 0.5, 0.4)))


func _alterna(arr: Array, k: String, limite: int) -> void:
	if arr.has(k):
		arr.erase(k)
	elif arr.size() < limite:
		arr.append(k)
	refresh()


func _etapa_resumo() -> void:
	_corpo.add_child(_tit("Resumo"))
	var row := HBoxContainer.new()
	row.add_child(_sem_quebra(_lbl("Nome:", 9)))
	var le := LineEdit.new()
	le.text = str(c.name)
	le.placeholder_text = "Aventureira" if c.feminino else "Aventureiro"
	le.custom_minimum_size.x = 200
	le.text_changed.connect(func(t: String): c.name = t)
	row.add_child(le)
	row.add_child(_btn("Gênero: " + ("feminino" if c.feminino else "masculino"), func(): c.feminino = not c.feminino; refresh()))
	_corpo.add_child(row)
	var s := ficha()
	_corpo.add_child(_lbl("%s %s, nível 1" % [CharacterBuilder.RACE_NAMES[c.race], CharacterBuilder.CLASS_NAMES.get(c["class"], c["class"])], 10, Color(0.95, 0.88, 0.7)))
	var at: Array = []
	for k in ATR:
		at.append("%s %+d" % [str(k).capitalize(), int(s.attrs[k])])
	_corpo.add_child(_lbl(" · ".join(at), 9))
	_corpo.add_child(_lbl("PV %d · PM %d · Defesa %d · Deslocamento %.0fm" % [s.pv_max, s.pm_max, s.defense(Game.rules), s.speed_m], 9))
	_corpo.add_child(_lbl("Perícias treinadas: " + ", ".join(Array(s.trained)), 9))
	for atk in s.attacks:
		_corpo.add_child(_lbl("Ataque: %s +%d (%s)" % [atk.nome, s.skill_value(str(atk.skill), Game.rules) if atk.has("skill") else int(atk.get("bonus_fixo", 0)), atk.dano], 9))
	if not s.spells.is_empty():
		var nomes: Array = []
		for sp in s.spells:
			nomes.append(str(Game.rules.value("magia." + sp, {}).get("nome", sp)))
		_corpo.add_child(_lbl("Magias: " + ", ".join(nomes), 9))
	var errs := erros()
	for e in errs:
		_corpo.add_child(_lbl("✘ " + e, 9, Color(1, 0.5, 0.4)))
	var b := _btn("Começar a aventura", func(): visible = false; concluido.emit(build_dict(), c.feminino, false))
	b.disabled = not errs.is_empty()
	_corpo.add_child(b)
	if not herdeiro:
		var b2 := _btn("Deixar o Destino decidir o passado", func(): visible = false; concluido.emit(build_dict(), c.feminino, true))
		b2.disabled = not errs.is_empty()
		_corpo.add_child(b2)


func _mostrar_previa() -> void:
	var ptr := Portrait.new()
	ptr.custom_minimum_size = Vector2(110, 110)
	ptr.set_actor("player", c.race)
	ptr.set_expression("determinado")
	_previa.add_child(ptr)
	var s := ficha()
	_previa.add_child(_lbl("%s\n%s" % [CharacterBuilder.RACE_NAMES[c.race], CharacterBuilder.CLASS_NAMES.get(c["class"], c["class"])], 10, Color(0.95, 0.88, 0.7)))
	_previa.add_child(_lbl("PV %d\nPM %d\nDefesa %d\n%.0fm" % [s.pv_max, s.pm_max, s.defense(Game.rules), s.speed_m], 9))
	var at: Array = []
	for k in ATR:
		at.append("%s %+d" % [str(k).to_upper(), int(s.attrs[k])])
	_previa.add_child(_lbl("\n".join(at), 8))


func _sem_quebra(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _tit(t: String) -> Label:
	return _lbl(t, 10, Color(1, 0.82, 0.4))


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
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	return b
