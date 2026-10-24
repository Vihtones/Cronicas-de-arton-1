class_name Prototypes
extends RefCounted
## Laboratório de protótipos: um cenário pequeno e jogável por mecânica, montado
## sobre o MESMO mundo do jogo (sem atalhos de regra). Cada cenário tem teste em
## tests/unit/test_prototypes.gd. Apenas configura o estado inicial (camada de aplicação).

const LIST := [
	{"id": "misterio", "nome": "Mistério e exploração", "desc": "Comece ao lado de Hilda. Examine pistas (E), anote hipóteses (J)."},
	{"id": "combate", "nome": "Combate tático e fantasma", "desc": "Cripta à tarde: os bandidos estão acordados. Planeje com o mouse, Enter confirma."},
	{"id": "furtividade", "nome": "Furtividade e surpresa", "desc": "3h da madrugada na cripta, modo furtivo ligado. Chegue perto e ataque de surpresa (E)."},
	{"id": "magia", "nome": "Magia (Arcanista anã)", "desc": "Cripta à tarde, bandidos à frente. Tecla 4 + clique: Seta Infalível (1 PM, acerta sempre)."},
	{"id": "ladino", "nome": "Ataque furtivo (Ladino)", "desc": "Ladino humano contra bandidos surpreendidos: +1d6 em alvo desprevenido."},
	{"id": "criacao", "nome": "Criação de personagem", "desc": "Escolha raça, classe e distribuição de pontos (LB p.17-20)."},
	{"id": "progressao", "nome": "Progressão e XP dinâmica", "desc": "900 XP. Vença e veja a conta da XP (desempenho e circunstâncias). Suba de nível e escolha um poder (J)."},
	{"id": "emboscada", "nome": "Emboscada na estrada", "desc": "Partindo para Valkaria com o bando ativo: salteadores atacam. Percepção decide quem surpreende."},
	{"id": "equipamento", "nome": "Equipamento e loja", "desc": "T$ 200 na ferraria. Compre e equipe (J > Inventário). Garrick desconfia de estranhos."},
	{"id": "rumores", "nome": "Memória e rumores", "desc": "Tomas acaba de ser resgatado. O tempo corre rápido: veja a notícia se espalhar (J > Reputação)."},
	{"id": "crime", "nome": "Crime com testemunhas", "desc": "Mercado cheio às 10h. Pegue algo escondido (E) e veja quem viu."},
	{"id": "investigacao", "nome": "Investigação da Guarda", "desc": "Furto sem testemunhas de madrugada. Dias passam; a Guarda investiga por pistas indiretas."},
	{"id": "economia", "nome": "Economia e mensageira", "desc": "Saria chega de Valkaria com mercadoria; preços mudam com o estoque."},
	{"id": "clima", "nome": "Clima e visibilidade", "desc": "Noite de neblina: camuflagem leve em combate e CD maior para examinar ao ar livre."},
	{"id": "viagem", "nome": "Viagem a Valkaria", "desc": "Na estrada leste. E > Viajar. O bando ativo aumenta o risco de emboscada."},
	{"id": "dominio", "nome": "Administração de domínio", "desc": "Você administra o Moinho Brandt. J > Domínio: impostos, celeiro, patrulha, delegar."},
	{"id": "geracoes", "nome": "Gerações e herança", "desc": "Véspera de ano novo; o velho Teodoro chega ao fim da vida. Herança e luto."},
	{"id": "herdeiro", "nome": "Morte e sucessão do herói", "desc": "Seu herói morreu. Continue como herdeiro no mesmo mundo."},
	{"id": "fauna", "nome": "Fauna e 2º mistério", "desc": "A matilha está faminta. Logo uma ovelha aparece morta na estrada (E para examinar)."},
	{"id": "fe", "nome": "Fé e obrigações", "desc": "Templo e posto da Guarda: torne-se devota de Lena, Khalmyr ou Allihanna e respeite os votos."},
	{"id": "ia", "nome": "IA de diálogo (local)", "desc": "Provedor local reescreve só o tom das falas. Converse com Elsa, Dorn ou Rosana."},
	{"id": "aventureiros", "nome": "Aventureiros NPC e ritmo", "desc": "30 dias passam. As Lanternas de Valkaria progridem pelas mesmas regras; vinhetas na praça."},
]


static func ids() -> Array:
	return LIST.map(func(x): return x.id)


static func _put(w: WorldState, x: int, y: int) -> void:
	w.player.position = w.db.tile_to_world(Vector2i(x, y))


static func _hour(w: WorldState, day: int, h: int) -> void:
	w.clock.tick = day * 144 + h * 6
	var npcs: NpcModule = w.modules.npcs
	for id in npcs.state:
		npcs.state[id].location = npcs.desired_location(id)


static func _cmd(w: WorldState, type: String, payload: Dictionary = {}) -> GameCommand.Result:
	return w.apply_command(GameCommand.create("proto_%d" % w.revision, "player", type, payload))


## Configura o mundo. Retorna {intro, settings?: {...}, ui?: "criacao", provider?: "eco_local"}.
static func apply(id: String, w: WorldState) -> Dictionary:
	var out := {"intro": ""}
	match id:
		"misterio":
			_hour(w, 0, 9)
			var t: Vector2i = w.modules.npcs.npc_tile("hilda")
			_put(w, t.x + 1, t.y)
		"combate":
			_hour(w, 1, 14)
			_put(w, 14, 56)
		"furtividade":
			_hour(w, 1, 3)
			_put(w, 9, 55)
			w.modules.combat.stance_sneak = true
		"magia":
			w.player_sheet = CharacterBuilder.build(w.rules, "anao", "arcanista", CharacterBuilder.presets("arcanista")[0], [], "Arcanista Anã")
			_hour(w, 1, 14)
			_put(w, 14, 56)
		"ladino":
			w.player_sheet = CharacterBuilder.build(w.rules, "humano", "ladino", CharacterBuilder.presets("ladino")[0], ["des", "int", "car"], "Ladino")
			_hour(w, 1, 3)
			_put(w, 9, 55)
			w.modules.combat.stance_sneak = true
		"criacao":
			out["ui"] = "criacao"
		"progressao":
			w.player_sheet.xp = 900
			_hour(w, 1, 14)
			_put(w, 14, 56)
		"equipamento":
			w.player.gold = 200
			_hour(w, 0, 9)
			_put(w, 10, 31)
		"rumores":
			w.modules.objects.state.porta_cela.open = true
			w.modules.objects.state.porta_cela.locked = false
			var t: Vector2i = w.modules.npcs.npc_tile("tomas")
			_put(w, t.x - 1, t.y)
			_cmd(w, "RescueNPC", {"npc_id": "tomas"})
			_put(w, 23, 27)
			out["settings"] = {"seconds_per_tick": 0.15}
		"crime":
			_hour(w, 0, 10)
			_put(w, 17, 21)
		"investigacao":
			_hour(w, 0, 2)
			_put(w, 17, 21)
			_cmd(w, "StealFromStall", {"owner": "mara", "item": "corda"})
			_put(w, 23, 27)
			out["settings"] = {"seconds_per_tick": 0.1}
		"economia":
			_hour(w, 4, 23)
			w.modules.economy.regions.vila.stock.ferramentas = 5
			_put(w, 17, 22)
			out["settings"] = {"seconds_per_tick": 0.5}
		"clima":
			_hour(w, 0, 22)
			w.modules.weather.region.condition = "neblina"
			_put(w, 56, 25)
		"viagem":
			_hour(w, 0, 8)
			_put(w, 60, 26)
		"emboscada":
			_hour(w, 0, 8)
			_put(w, 60, 26)
			w.player.gold = 30
		"dominio":
			w.modules.exploration.mystery_state = "resolvido"
			_cmd(w, "GrantDomain", {"by": "orin"})
			_hour(w, 6, 20)
			_put(w, 40, 32)
			out["settings"] = {"seconds_per_tick": 0.05}
		"geracoes":
			var lin: LineageModule = w.modules.lineage
			w.modules.npcs.state.teodoro.age = int(lin.longevity.teodoro)
			w.clock.tick = 360 * 144 - 6
			lin._last_year = 1
			_put(w, 18, 39)
		"herdeiro":
			w.player.gold = 40
			w.player_sheet.pv = w.player_sheet.death_threshold() - 1
			out["ui"] = "gameover"
		"fauna":
			w.modules.fauna.food = 3
			_hour(w, 0, 23)
			_put(w, 57, 26)
			out["settings"] = {"seconds_per_tick": 0.3}
		"fe":
			w.modules.state.flags["personagem_feminina"] = true
			w.player_sheet.name = "Aventureira"
			_hour(w, 0, 10)
			_put(w, 30, 13)
		"ia":
			out["provider"] = "eco_local"
			_hour(w, 0, 19)
			_put(w, 11, 13)
		"aventureiros":
			_hour(w, 0, 7)
			for i in 30:
				_cmd(w, "AdvanceTime", {"ticks": 144})
			_hour(w, w.day_index(), 8)
			_put(w, 23, 27)
	for p in LIST:
		if p.id == id:
			out.intro = "[Protótipo: %s] %s" % [p.nome, p.desc]
	return out
