class_name Prologue
extends RefCounted
## Prólogo Vivo (Arton Viva, Fase 3). ORIGINAL_DO_JOGO, homebrew separado da ficha T20.
## Respostas do questionário (ou sorteio por semente) viram um estado inicial válido: ouro, moradia,
## profissão, contatos reais do mundo e objetivo de médio prazo. Só devolve dados: quem aplica é `apply`.
## A origem T20 continua sendo a da ficha; isto é o passado do personagem, não um bônus mecânico.

## Perguntas e opções (ids estáveis). Ordem fixa: o sorteio por semente depende dela.
const QUESTIONS := ["onde_cresceu", "condicao", "vinculo", "ocupacao", "recente", "comeco"]
const OPTIONS := {
	"onde_cresceu": ["vila", "cidade", "estrada", "floresta"],
	"condicao": ["pobreza", "trabalhador", "familia_prospera", "nobreza", "sem_recursos"],
	"vinculo": ["familia", "mentor", "comunidade", "nenhum"],
	"ocupacao": ["ferreiro", "taverneiro", "lavrador", "aprendiz", "nomade", "herdeiro"],
	"recente": ["nada", "perda", "oportunidade", "divida"],
	"comeco": ["em_casa", "no_trabalho", "estrada", "acampamento"],
}
## Ouro inicial por condição social (moedas de prata da tabela de equipamento).
const GOLD_BY_CONDITION := {"sem_recursos": 2, "pobreza": 5, "trabalhador": 15, "familia_prospera": 40, "nobreza": 80}
const DEBT := 10                 # "divida" recente: some do ouro no começo
## Moradia por ocupação. "" = sem casa (acampamento).
const HOME_BY_JOB := {"ferreiro": "casa_ferro", "taverneiro": "casa_vasquel", "lavrador": "casa_aldren",
	"aprendiz": "casa_ferro", "herdeiro": "casa_brandt", "nomade": ""}
## Contato de ofício (mentor/emprego) por ocupação: um morador real do mundo.
const MENTOR_BY_JOB := {"ferreiro": "garrick", "taverneiro": "rosana", "lavrador": "joran", "aprendiz": "garrick",
	"herdeiro": "otto", "nomade": "saria"}
const OBJECTIVE_BY_JOB := {"ferreiro": "juntar_ouro", "taverneiro": "juntar_ouro", "lavrador": "juntar_ouro",
	"aprendiz": "abrir_negocio", "herdeiro": "", "nomade": "viajar"}
const WORK_BY_JOB := {"ferreiro": "ferraria", "taverneiro": "taverna", "lavrador": "campos", "aprendiz": "ferraria",
	"herdeiro": "prefeitura", "nomade": "campos"}
const START_BY_COMECO := {"em_casa": "home", "no_trabalho": "work", "estrada": "estrada_leste", "acampamento": "campos"}


## Estado inicial a partir das respostas. Respostas faltando usam a primeira opção.
static func from_answers(answers: Dictionary) -> Dictionary:
	var a := {}
	for q in QUESTIONS:
		var opts: Array = OPTIONS[q]
		a[q] = str(answers.get(q, opts[0]))
		if not opts.has(a[q]):
			a[q] = opts[0]
	var job: String = a.ocupacao
	var gold := int(GOLD_BY_CONDITION[a.condicao])
	if a.recente == "divida":
		gold = maxi(0, gold - DEBT)
	var home := str(HOME_BY_JOB.get(job, ""))
	if a.comeco == "acampamento" or a.condicao == "sem_recursos":
		home = ""
	var start_loc := str(START_BY_COMECO[a.comeco])
	if start_loc == "home":
		start_loc = home if home != "" else "campos"
	elif start_loc == "work":
		start_loc = str(WORK_BY_JOB.get(job, "campos"))
	var contacts: Array = []
	if a.vinculo != "nenhum":
		var mentor := str(MENTOR_BY_JOB.get(job, ""))
		if mentor != "" and a.vinculo in ["mentor", "comunidade"]:
			contacts.append(mentor)
		if a.vinculo == "familia" and home != "":
			contacts.append("__familia_de:" + home)  # resolvido em `resolve_contacts`
	return {"answers": a, "gold": gold, "profession": job, "home": home, "start_location": start_loc,
		"contacts": contacts, "objective": str(OBJECTIVE_BY_JOB.get(job, "")), "recent": a.recente}


## Destino: a mesma semente, com as mesmas opções, sempre gera o mesmo começo.
static func from_seed(seed_value: int) -> Dictionary:
	var answers := {}
	for i in QUESTIONS.size():
		var q: String = QUESTIONS[i]
		var opts: Array = OPTIONS[q]
		var h := ("%d|%s" % [seed_value, q]).hash()
		answers[q] = opts[absi(h) % opts.size()]
	return from_answers(answers)


## Confere se o começo aponta só para coisas que existem no mundo.
static func validate(start: Dictionary, db: ContentDB) -> PackedStringArray:
	var errs := PackedStringArray()
	if int(start.gold) < 0:
		errs.append("ouro negativo")
	if str(start.home) != "" and db.location(str(start.home)).is_empty():
		errs.append("moradia inexistente: " + str(start.home))
	if db.location(str(start.start_location)).is_empty():
		errs.append("local inicial inexistente: " + str(start.start_location))
	for c in resolve_contacts(start, db):
		if db.npc_def(c).is_empty():
			errs.append("contato inexistente: " + c)
	if str(start.objective) != "" and not ["juntar_ouro", "abrir_negocio", "viajar"].has(str(start.objective)):
		errs.append("objetivo desconhecido: " + str(start.objective))
	return errs


## Contatos reais: a família são os moradores que moram na casa escolhida.
static func resolve_contacts(start: Dictionary, db: ContentDB) -> Array:
	var out: Array = []
	for c in start.contacts:
		var s := str(c)
		if s.begins_with("__familia_de:"):
			var casa := s.trim_prefix("__familia_de:")
			for id in db.all_npc_ids():
				if str(db.npc_def(id).get("home", "")) == casa:
					out.append(id)
		else:
			out.append(s)
	out.sort()
	return out
