"""Gera o conteúdo estático do vertical slice (ORIGINAL_DO_JOGO) em data/world/.
Determinístico: mesma execução => mesmos arquivos. Edite aqui, não os JSON gerados."""
import heapq, json, random, pathlib
from collections import deque

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "world"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 96, 64
rnd = random.Random(20261023)
g = [["." for _ in range(W)] for _ in range(H)]
locations, objects, targets = [], [], []

def fill(x, y, w, h, ch):
    for j in range(y, y + h):
        for i in range(x, x + w):
            g[j][i] = ch

def loc(id, name, zone, rect, spot, indoor=False):
    locations.append({"id": id, "name": name, "zone": zone, "rect": rect, "spot": spot, "indoor": indoor})

occupied = []
def building(id, name, x, y, w, h, door, locked=False):
    for (ox, oy, ow, oh) in occupied:
        assert x + w <= ox or ox + ow <= x or y + h <= oy or oy + oh <= y, f"sobreposição: {id}"
    occupied.append((x, y, w, h))
    fill(x, y, w, h, "#")
    fill(x + 1, y + 1, w - 2, h - 2, "_")
    dx, dy = door
    g[dy][dx] = "D"
    objects.append({"id": "porta_" + id, "type": "door", "tile": [dx, dy], "open": False, "locked": locked, "name": "Porta (" + name + ")",
                    "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239 Tabela 5-4 porta de madeira"}})
    loc(id, name, "vila", [x + 1, y + 1, w - 2, h - 2], [x + w // 2, y + h // 2], True)

# --- Terreno base ---------------------------------------------------------
for y in range(0, 50):
    for x in range(50, W):
        g[y][x] = "T" if rnd.random() < 0.33 else ","
for y in range(0, 50):  # rio
    g[y][46] = "~"; g[y][47] = "~"
for x in range(2, W):   # estrada leste-oeste
    g[25][x] = "="; g[26][x] = "="
for y in range(8, 46):  # rua norte-sul
    g[y][21] = "="; g[y][22] = "="
for x in range(30, 44):  # trilha para o moinho
    g[28][x] = ":"
# trilha da floresta até a ruína
tx, ty = 70, 24
while ty > 16:
    g[ty][tx] = ":"; g[ty][tx + 1] = ":"
    ty -= 1
    if tx < 85 and rnd.random() < 0.6:
        tx += 1
        g[ty][tx] = ":"
while tx < 86:
    g[ty][tx] = ":"; g[ty + 1][tx] = ":"; tx += 1
# campos dos Aldren
for y in range(38, 46):
    for x in range(26, 44):
        if g[y][x] == ".":
            g[y][x] = "c"

# --- Construções ------------------------------------------------------------
building("taverna", "Taverna do Galo Rubro", 6, 10, 10, 7, (11, 16))
building("templo", "Templo de Lena", 25, 9, 10, 8, (30, 16))
building("casa_brandt", "Casa dos Brandt", 37, 10, 6, 5, (40, 14))
building("quartel", "Posto da Guarda", 6, 19, 8, 5, (10, 23))
building("casa_ferro", "Casa dos Ferro", 25, 19, 6, 5, (28, 23))
building("casa_vasquel", "Casa dos Vasquel", 32, 19, 6, 5, (35, 23))
building("ferraria", "Ferraria", 6, 29, 8, 6, (10, 29))
building("prefeitura", "Casa do Alcaide", 15, 29, 6, 5, (18, 29))
building("casa_aldren", "Casa dos Aldren", 25, 30, 6, 5, (28, 30))
building("moinho", "Moinho", 37, 30, 7, 7, (40, 30))
building("casa_corvo", "Casa dos Corvo", 15, 37, 6, 5, (18, 37))
# cabana na floresta
fill(60, 40, 6, 5, "#"); fill(61, 41, 4, 3, "_"); g[40][62] = "D"
for x in range(62, 63):
    for y in range(27, 40): g[y][x] = ":"
objects.append({"id": "porta_cabana", "type": "door", "tile": [62, 40], "open": False, "locked": False, "name": "Porta (Cabana do Caçador)",
                "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239"}})
loc("cabana_quill", "Cabana do Caçador", "floresta", [61, 41, 4, 3], [62, 42], True)

# locais externos
loc("praca", "Praça do Poço", "vila", [18, 22, 8, 7], [23, 27])
loc("mercado", "Mercado", "vila", [14, 19, 6, 4], [17, 21])
loc("campos", "Campos dos Aldren", "vila", [26, 38, 18, 8], [34, 41])
loc("ponte", "Ponte do Rio", "estrada", [44, 24, 6, 4], [45, 27])
loc("estrada_leste", "Estrada Leste", "estrada", [48, 24, 22, 4], [60, 27])
loc("floresta", "Bosque Sombrio", "floresta", [50, 28, 45, 20], [70, 34])
loc("trilha_floresta", "Trilha Antiga", "floresta", [68, 16, 20, 10], [72, 20])
loc("ruina", "Ruína da Torre Partida", "ruina", [80, 4, 13, 11], [86, 12])
loc("valkaria", "Valkaria (distante)", "valkaria", [0, 0, 0, 0], [0, 0])
objects.append({"id": "poco", "type": "prop", "tile": [23, 24], "name": "Poço"})
g[24][23] = "o"

# ruína: paredes quebradas, entulho
for y in range(4, 15):
    for x in range(80, 93):
        g[y][x] = "%" if rnd.random() < 0.25 else "_"
for x in range(80, 93):
    if rnd.random() < 0.7: g[4][x] = "#"
    if rnd.random() < 0.7: g[14][x] = "#"
for y in range(4, 15):
    if rnd.random() < 0.7: g[y][80] = "#"
    if rnd.random() < 0.7: g[y][92] = "#"
g[14][86] = "_"; g[15][86] = ":"; g[16][86] = ":"
g[9][86] = "S"
objects.append({"id": "escada_ruina", "type": "stairs", "tile": [86, 9], "to": [7, 56], "name": "Escada para a cripta"})

# --- Masmorra (área separada, só por escada) ---------------------------------
fill(3, 50, 42, 13, "#")
fill(4, 52, 9, 8, "_")       # antecâmara
fill(13, 55, 12, 3, "_")     # corredor
fill(25, 51, 10, 10, "_")    # salão
fill(36, 53, 6, 5, "_")      # cela
g[55][35] = "D"
for (x, y) in [(27, 53), (32, 58), (29, 56)]: g[y][x] = "%"  # entulho = terreno difícil
g[56][5] = "U"
for yy in range(49, H):
    for xx in range(W):
        if not (3 <= xx <= 44 and 50 <= yy <= 62):
            g[yy][xx] = "X"
objects.append({"id": "escada_cripta", "type": "stairs", "tile": [5, 56], "to": [86, 10], "name": "Escada para a superfície"})
objects.append({"id": "porta_cela", "type": "door", "tile": [35, 55], "open": False, "locked": True, "key": "chave_cela", "name": "Porta da cela",
                "lock_cd": 20, "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239 Tabela 5-4 porta de madeira"}})
objects.append({"id": "bau_dizimo", "type": "chest", "tile": [33, 52], "open": False, "locked": False, "name": "Baú com selo do templo",
                "contents": ["dizimo_lena"]})
loc("cripta_antecamara", "Antecâmara", "cripta", [4, 52, 9, 8], [8, 55], True)
loc("cripta_corredor", "Corredor", "cripta", [13, 55, 12, 3], [18, 56], True)
loc("cripta_salao", "Salão dos Bandidos", "cripta", [25, 51, 10, 10], [29, 55], True)
loc("cripta_cela", "Cela", "cripta", [36, 53, 6, 5], [39, 55], True)
targets.append({"id": "placa_pressao", "tile": [16, 56], "name": "Laje solta",
  "signal": "Uma laje do corredor está mais limpa que as outras.",
  "actions": {"examinar": {"skill": "percepcao", "cd": 15, "reveals": [], "flag": "armadilha_corredor_vista",
     "ok": "Há um mecanismo sob a laje: uma armadilha de dardos. Você pode contorná-la.",
     "fail": "Parece só uma laje gasta."}}})

# --- Pistas do mistério (alvos de exploração) -----------------------------------
targets += [
 {"id": "bau_tomas", "tile": [38, 11], "name": "Baú de Tomas", "requires_location": "casa_brandt",
  "signal": "Um baú de rapaz, a tampa entreaberta.",
  "actions": {
   "investigar": {"skill": "investigacao", "cd": 15, "reveals": ["f_tomas_viu_carga"],
     "ok": "Sob as roupas, um bilhete com a letra de Tomas: \"luzes na torre partida de novo. carroça sem lanterna. vou ver.\"",
     "fail": "Roupas, uma funda, pedrinhas. Nada que pareça importante."},
   "examinar": {"skill": "percepcao", "cd": 20, "reveals": ["f_tomas_viu_carga"],
     "ok": "Um papel dobrado escapa do forro. É um bilhete sobre luzes na torre partida.",
     "fail": "À primeira vista, só roupas."}}},
 {"id": "rastros_moinho", "tile": [42, 29], "name": "Terra revolvida atrás do moinho",
  "signal": "A lama atrás do moinho está marcada, como se algo tivesse sido arrastado.",
  "actions": {
   "rastrear": {"skill": "sobrevivencia", "cd": 15, "reveals": ["f_tomas_levado"],
     "ok": "Duas pessoas de botas pesadas e um terceiro, mais leve, sendo arrastado. Seguem para a estrada leste.",
     "fail": "Pegadas demais. Você não consegue separar umas das outras."},
   "examinar": {"skill": "percepcao", "cd": 20, "reveals": ["f_tomas_levado"],
     "ok": "Marcas de calcanhares arrastados, e um botão de osso caído.",
     "fail": "Lama, muita lama."}}},
 {"id": "arbusto_estrada", "tile": [56, 24], "name": "Espinheiro à beira da estrada",
  "signal": "Algo claro está preso no espinheiro.",
  "actions": {"examinar": {"skill": "percepcao", "cd": 10, "reveals": ["f_tomas_levado"],
     "ok": "Um retalho de linho com bordado azul. A mãe de Tomas reconheceria.",
     "fail": "Só folhas e espinhos."}}},
 {"id": "trilha_marcas", "tile": [72, 22], "name": "Trilha antiga",
  "signal": "A trilha antiga, quase tomada pelo mato, tem galhos recém-quebrados.",
  "actions": {
   "rastrear": {"skill": "sobrevivencia", "cd": 15, "reveals": ["f_bandidos_na_ruina"],
     "ok": "Sulcos de rodas estreitas e muitas botas, indo e voltando da torre partida.",
     "fail": "Animais passam por aqui. Ou não."},
   "examinar": {"skill": "percepcao", "cd": 15, "reveals": ["f_bandidos_na_ruina"],
     "ok": "Cera de vela pingada nas pedras. Alguém anda aqui à noite.",
     "fail": "Galhos quebrados, mas por quem?"}}},
 {"id": "entrada_ruina", "tile": [86, 11], "name": "Escada da torre",
  "signal": "Fuligem fresca na parede ao lado da escada que desce.",
  "actions": {
   "examinar": {"skill": "percepcao", "cd": 10, "reveals": ["f_bandidos_na_ruina"],
     "ok": "Tochas foram acesas aqui nesta semana. E há cheiro de ensopado subindo da escada.",
     "fail": "Pedra antiga, preta de fumaça."},
   "escutar": {"skill": "percepcao", "cd": 15, "reveals": ["f_bandidos_na_ruina"],
     "ok": "Vozes abafadas lá embaixo. Alguém ri. Alguém tosse.",
     "fail": "Só o vento nas pedras."}}},
]

targets += [
 {"id": "carcaca_ovelha", "tile": [58, 26], "name": "Carcaça de ovelha", "requires_flag": "ovelha_morta",
  "signal": "Uma ovelha morta à beira da estrada. Moscas.",
  "actions": {
   "examinar": {"skill": "percepcao", "cd": 15, "reveals": ["f_ovelhas_mortas", "f_marcas_hiena"],
     "ok": "Mordidas largas e ossos partidos: mandíbula forte demais para lobo. Hienas.", "fail": "Uma ovelha morta. Lobos, talvez."},
   "rastrear": {"skill": "sobrevivencia", "cd": 15, "reveals": ["f_ovelhas_mortas", "f_toca_hienas"],
     "ok": "Pegadas de quatro patas, desiguais, rumo ao leste do bosque. Uma toca.", "fail": "O rastro some no capim."}}},
 {"id": "toca_hienas", "tile": [80, 37], "name": "Toca sob as raízes",
  "signal": "Ossos roídos e um cheiro azedo saem de baixo de um carvalho tombado.",
  "actions": {"examinar": {"skill": "percepcao", "cd": 10, "reveals": ["f_toca_hienas"], "ok": "É a toca da matilha.", "fail": "Ossos velhos."}}},
]

# --- Mistério -------------------------------------------------------------------
mystery = {
 "truth_id": "m_filho_do_moleiro", "status": "ORIGINAL_DO_JOGO",
 "title": "O Filho do Moleiro",
 "historical_context": "Há três noites, Tomas Brandt viu as Garras de Cinza levando o dízimo roubado do Templo de Lena para a cripta da Torre Partida. Dorn, bêbado da taverna e informante do bando, contou que o rapaz andava bisbilhotando. Kael mandou buscá-lo.",
 "facts": {
  "f_tomas_sumiu": "Tomas Brandt está desaparecido há três dias.",
  "f_tomas_viu_carga": "Tomas viu luzes e uma carroça sem lanterna perto da Torre Partida.",
  "f_tomas_levado": "Tomas foi arrastado por duas pessoas rumo à estrada leste.",
  "f_dizimo_roubado": "O dízimo do Templo de Lena foi roubado há uma semana.",
  "f_bandidos_na_ruina": "Há gente vivendo na cripta da Torre Partida.",
  "f_dorn_informante": "Dorn passou informações a desconhecidos em troca de bebida.",
  "f_tomas_na_masmorra": "Tomas está preso na cela da cripta.",
 },
 "hypotheses": {
  "h_fuga": {"text": "Tomas fugiu de casa.", "supported_by": [], "contradicted_by": ["f_tomas_levado", "f_tomas_na_masmorra"]},
  "h_bandidos": {"text": "Bandidos levaram Tomas para a Torre Partida.", "supported_by": ["f_tomas_levado", "f_bandidos_na_ruina"], "contradicted_by": []},
  "h_informante": {"text": "Alguém da vila avisou os sequestradores.", "supported_by": ["f_dorn_informante"], "contradicted_by": []},
  "h_dizimo": {"text": "O roubo do dízimo e o sumiço estão ligados.", "supported_by": ["f_tomas_viu_carga", "f_dizimo_roubado"], "contradicted_by": []},
 },
 "start_facts": ["f_tomas_sumiu"],
 "factions_interested": ["guarda_vila", "templo_lena", "garras_de_cinza"],
 "state_transitions": {
  "resolvido": {"requires_event": "NPC_RESCUED", "npc": "tomas"},
  "perdido": {"requires_event": "BANDITS_RELOCATED"},
 },
 "consequences": {
  "resolvido": ["familia_brandt_gratidao", "reputacao_vila"],
  "perdido": ["tomas_levado_para_longe"],
 },
 "deadline_day": 12,
}

# --- NPCs ----------------------------------------------------------------------------
SCHED = {
 "moleiro":    [[0, 6, "home"], [6, 12, "work"], [12, 13, "taverna"], [13, 18, "work"], [18, 21, "taverna"], [21, 24, "home"]],
 "artesao":    [[0, 7, "home"], [7, 12, "work"], [12, 13, "home"], [13, 18, "work"], [18, 21, "taverna"], [21, 24, "home"]],
 "comerciante":[[0, 7, "home"], [7, 12, "mercado"], [12, 13, "home"], [13, 18, "mercado"], [18, 24, "home"]],
 "taverneiro": [[0, 2, "taverna"], [2, 9, "home"], [9, 24, "taverna"]],
 "sacerdote":  [[0, 12, "templo"], [12, 13, "praca"], [13, 24, "templo"]],
 "guarda_dia": [[0, 7, "home"], [7, 12, "praca"], [12, 13, "taverna"], [13, 19, "ponte"], [19, 24, "quartel"]],
 "guarda_noite":[[0, 6, "praca"], [6, 14, "home"], [14, 18, "quartel"], [18, 24, "ponte"]],
 "lavrador":   [[0, 5, "home"], [5, 12, "campos"], [12, 13, "home"], [13, 18, "campos"], [18, 24, "home"]],
 "crianca":    [[0, 7, "home"], [7, 11, "praca"], [11, 13, "home"], [13, 16, "templo"], [16, 18, "praca"], [18, 24, "home"]],
 "idoso":      [[0, 8, "home"], [8, 11, "praca"], [11, 18, "home"], [18, 20, "taverna"], [20, 24, "home"]],
 "alcaide":    [[0, 8, "home"], [8, 18, "work"], [18, 20, "taverna"], [20, 24, "home"]],
 "cacador":    [[0, 5, "home"], [5, 12, "floresta"], [12, 14, "home"], [14, 18, "floresta"], [18, 20, "taverna"], [20, 24, "home"]],
 "pastora":    [[0, 6, "home"], [6, 17, "estrada_leste"], [17, 24, "home"]],
 "bebado":     [[0, 10, "taverna"], [10, 23, "taverna"], [23, 24, "trilha_floresta", 3]],
 "viajante":   [[0, 8, "taverna"], [8, 18, "mercado"], [18, 24, "taverna"]],
}
def npc(id, name, age, prof, sched, home, work=None, family=None, faction=None, devotion="", traits=None, beliefs=None, gold=5):
    return {"id": id, "name": name, "age": age, "profession": prof, "schedule": sched, "home": home, "work": work or home,
            "family": family, "faction": faction, "devotion": devotion, "traits": traits or [], "beliefs": beliefs or {}, "gold": gold}
npcs = [
 npc("otto", "Otto Brandt", 52, "moleiro", "moleiro", "casa_brandt", "moinho", "brandt", traits=["teimoso"]),
 npc("hilda", "Hilda Brandt", 44, "fiandeira", "artesao", "casa_brandt", "casa_brandt", "brandt", devotion="Lena", traits=["aflita"]),
 npc("tomas", "Tomas Brandt", 17, "ajudante de moleiro", "moleiro", "casa_brandt", "moinho", "brandt", traits=["curioso"]),
 npc("lisel", "Lisel Brandt", 12, "criança", "crianca", "casa_brandt", None, "brandt"),
 npc("garrick", "Garrick Ferro", 40, "ferreiro", "artesao", "casa_ferro", "ferraria", "ferro", traits=["desconfia_de_estrangeiros"], gold=30),
 npc("mara", "Mara Ferro", 38, "mercadora", "comerciante", "casa_ferro", "mercado", "ferro", gold=40),
 npc("davi", "Davi Ferro", 15, "aprendiz", "artesao", "casa_ferro", "ferraria", "ferro"),
 npc("rosana", "Rosana Vasquel", 35, "taverneira", "taverneiro", "casa_vasquel", "taverna", "vasquel", traits=["observadora"], gold=25),
 npc("bento", "Bento Vasquel", 39, "cozinheiro", "taverneiro", "casa_vasquel", "taverna", "vasquel"),
 npc("nina", "Nina Vasquel", 9, "criança", "crianca", "casa_vasquel", None, "vasquel"),
 npc("joran", "Joran Aldren", 60, "lavrador", "lavrador", "casa_aldren", "campos", "aldren"),
 npc("celia", "Celia Aldren", 58, "lavradora", "lavrador", "casa_aldren", "campos", "aldren", devotion="Allihanna"),
 npc("pell", "Pell Aldren", 30, "lavrador", "lavrador", "casa_aldren", "campos", "aldren"),
 npc("ivi", "Ivi Aldren", 27, "lavradora", "lavrador", "casa_aldren", "campos", "aldren"),
 npc("elsa", "Capitã Elsa Corvo", 45, "capitã da guarda", "guarda_dia", "casa_corvo", "quartel", "corvo", "guarda_vila", "Khalmyr", ["exige_provas"]),
 npc("rurik", "Rurik Corvo", 22, "guarda", "guarda_noite", "casa_corvo", "quartel", "corvo", "guarda_vila"),
 npc("teodoro", "Teodoro Corvo", 70, "guarda aposentado", "idoso", "casa_corvo", None, "corvo", traits=["memoria_longa"]),
 npc("ysolde", "Irmã Ysolde", 41, "clériga de Lena", "sacerdote", "templo", "templo", None, "templo_lena", "Lena"),
 npc("lucan", "Lucan", 19, "acólito", "sacerdote", "templo", "templo", None, "templo_lena", "Lena"),
 npc("quill", "Velho Quill", 63, "caçador", "cacador", "cabana_quill", "floresta", None, traits=["recluso"]),
 npc("saria", "Saria das Estradas", 33, "mercadora viajante", "viajante", "taverna", "mercado", None, traits=["traz_noticias"], gold=60),
 npc("orin", "Mestre Orin", 55, "alcaide", "alcaide", "prefeitura", "prefeitura", None, "guarda_vila", "Khalmyr", gold=50),
 npc("tobias", "Tobias", 28, "guarda", "guarda_dia", "quartel", "quartel", None, "guarda_vila"),
 npc("fenna", "Fenna", 24, "pastora", "pastora", "casa_aldren", "estrada_leste", "aldren"),
 npc("dorn", "Dorn", 47, "bêbado", "bebado", "taverna", "taverna", None, "garras_de_cinza", traits=["mentiroso"]),
]
# Fichas de ameaça dos NPCs que agem com regras (LB Tabela 7-2). O ND e o foco são escolhas de design (ORIGINAL_DO_JOGO).
NPC_FICHAS = {
    "elsa": {"nd": "2", "foco": ["investigacao", "intuicao", "percepcao", "luta", "intimidacao"]},
    "rurik": {"nd": "1/2", "foco": ["percepcao", "luta"]},
    "tobias": {"nd": "1/2", "foco": ["luta", "percepcao"]},
}
for _n in npcs:
    if _n["id"] in NPC_FICHAS:
        _n["ficha"] = NPC_FICHAS[_n["id"]]
families = [
 {"id": "brandt", "name": "Brandt", "members": ["otto", "hilda", "tomas", "lisel"]},
 {"id": "ferro", "name": "Ferro", "members": ["garrick", "mara", "davi"]},
 {"id": "vasquel", "name": "Vasquel", "members": ["rosana", "bento", "nina"]},
 {"id": "aldren", "name": "Aldren", "members": ["joran", "celia", "pell", "ivi", "fenna"]},
 {"id": "corvo", "name": "Corvo", "members": ["elsa", "rurik", "teodoro"]},
]
factions = [
 {"id": "guarda_vila", "name": "Guarda da Vila", "goals": ["manter_ordem", "proteger_estrada"], "resources": {"soldados": 3, "ouro": 80},
  "allies": ["templo_lena"], "rivals": ["garras_de_cinza"], "jurisdiction": "vila", "status": "ORIGINAL_DO_JOGO"},
 {"id": "templo_lena", "name": "Templo de Lena", "goals": ["recuperar_dizimo", "curar"], "resources": {"ouro": 10},
  "allies": ["guarda_vila"], "rivals": [], "status": "ORIGINAL_DO_JOGO"},
 {"id": "garras_de_cinza", "name": "Garras de Cinza", "goals": ["esconder_saque", "evitar_guarda"], "resources": {"membros": 3, "ouro": 120},
  "allies": [], "rivals": ["guarda_vila"], "hideout": "cripta_salao", "relocate_day": 12, "status": "ORIGINAL_DO_JOGO"},
]
creatures = [
 {"id": "kael", "name": "Kael Mão-Cinza", "rule": "criatura.bandido_ligeiro", "faction": "garras_de_cinza", "spawn": [29, 54], "zone": "cripta",
  "items": ["chave_cela"], "sleeps": [0, 6], "important": True,
  # Líder: habilidades de classe para NPC (LB p.322: "veja as classes de personagem"), 3 PM por ND. Escolha ORIGINAL_DO_JOGO.
  "poderes": ["ataque_reflexo", "impeto"], "pm": 3},
 {"id": "bandido_1", "name": "Bandido Magro", "rule": "criatura.bandido_comum", "faction": "garras_de_cinza", "spawn": [27, 57], "zone": "cripta", "sleeps": [0, 6]},
 {"id": "bandido_2", "name": "Bandido Ruivo", "rule": "criatura.bandido_comum", "faction": "garras_de_cinza", "spawn": [31, 57], "zone": "cripta", "sleeps": [1, 7]},
 {"id": "hiena_1", "name": "Hiena", "rule": "criatura.hiena", "faction": "fauna", "spawn": [78, 34], "zone": "floresta", "active_hours": [18, 6],
  "signal": "Risadas agudas ecoam entre as árvores."},
 {"id": "hiena_2", "name": "Hiena Malhada", "rule": "criatura.hiena", "faction": "fauna", "spawn": [80, 36], "zone": "floresta", "active_hours": [18, 6]},
 {"id": "salteador_1", "name": "Salteador", "rule": "criatura.bandido_comum", "faction": "salteadores", "spawn": [63, 24], "zone": "estrada", "start_present": False},
 {"id": "salteador_2", "name": "Salteador Caolho", "rule": "criatura.bandido_comum", "faction": "salteadores", "spawn": [64, 27], "zone": "estrada", "start_present": False},
 {"id": "hiena_3", "name": "Hiena Jovem", "rule": "criatura.hiena", "faction": "fauna", "spawn": [82, 35], "zone": "floresta", "active_hours": [18, 6], "start_present": False},
 {"id": "hiena_4", "name": "Hiena Jovem", "rule": "criatura.hiena", "faction": "fauna", "spawn": [79, 38], "zone": "floresta", "active_hours": [18, 6], "start_present": False},
]
items = {
 "chave_cela": {"name": "Chave de ferro", "price": 0},
 "dizimo_lena": {"name": "Bolsa do dízimo de Lena", "price": 0, "owner": "templo_lena"},
 "pao": {"name": "Pão", "price": 1, "good": "comida"},
 "cerveja": {"name": "Caneca de cerveja", "price": 1, "good": "bebida"},
 "corda": {"name": "Corda (15m)", "price": 1, "good": "ferramentas"},
 "tocha": {"name": "Tocha", "price": 1, "good": "ferramentas"},
 "pocao_cura": {"name": "Poção de Curar Ferimentos", "price": 30, "good": "remedio", "status": "PENDENTE_REVISAO"},
 "saco_de_dormir": {"name": "Saco de dormir", "price": 1, "good": "ferramentas", "rule": "item.saco_de_dormir"},
 # Armas e armaduras: preços do LB p.144 e p.153 (data/rules/equipamento.json)
 "espada_longa": {"name": "Espada longa", "price": 15, "good": "ferramentas", "rule": "arma.espada_longa"},
 "espada_curta": {"name": "Espada curta", "price": 10, "good": "ferramentas", "rule": "arma.espada_curta"},
 "adaga": {"name": "Adaga", "price": 2, "good": "ferramentas", "rule": "arma.adaga"},
 "machado_batalha": {"name": "Machado de batalha", "price": 10, "good": "ferramentas", "rule": "arma.machado_batalha"},
 "arco_curto": {"name": "Arco curto", "price": 30, "good": "ferramentas", "rule": "arma.arco_curto"},
 "couro_batido": {"name": "Couro batido", "price": 35, "good": "ferramentas", "rule": "armadura.couro_batido"},
 "cota_malha": {"name": "Cota de malha", "price": 150, "good": "ferramentas", "rule": "armadura.cota_malha"},
}
economy = {
 "goods": {"comida": {"base": 1.0}, "bebida": {"base": 1.0}, "ferramentas": {"base": 1.0}, "remedio": {"base": 1.0}},
 "regions": {
  "vila": {"stock": {"comida": 120, "bebida": 80, "ferramentas": 30, "remedio": 4}, "production": {"comida": 14, "bebida": 8, "ferramentas": 2, "remedio": 0},
           "consumption": {"comida": 13, "bebida": 8, "ferramentas": 1, "remedio": 0}, "target": {"comida": 120, "bebida": 80, "ferramentas": 30, "remedio": 6}},
  "valkaria": {"stock": {"comida": 5000, "bebida": 3000, "ferramentas": 2000, "remedio": 300}, "production": {"comida": 500, "bebida": 300, "ferramentas": 200, "remedio": 20},
           "consumption": {"comida": 500, "bebida": 300, "ferramentas": 190, "remedio": 18}, "target": {"comida": 5000, "bebida": 3000, "ferramentas": 2000, "remedio": 300}},
 },
 "price_limits": [0.5, 3.0], "status": "ORIGINAL_DO_JOGO",
 "shops": {"rosana": ["pao", "cerveja"], "mara": ["corda", "tocha", "pao", "saco_de_dormir"], "ysolde": ["pocao_cura"],
           "valkaria_mercado": ["pocao_cura", "saco_de_dormir", "arco_curto", "cota_malha", "espada_longa", "tocha", "corda"],
           "garrick": ["adaga", "espada_curta", "espada_longa", "machado_batalha", "arco_curto", "couro_batido", "cota_malha"]},
}
laws = {"vila": {"furto": {"multa": 10, "severidade": 1}, "invasao": {"multa": 3, "severidade": 0}, "dano_propriedade": {"multa": 5, "severidade": 1},
                 "agressao": {"multa": 20, "severidade": 2}}, "status": "ORIGINAL_DO_JOGO"}
distant = {"regions": [{"id": "valkaria", "name": "Valkaria", "lod": "L3", "events": [
   {"id": "caravana_chega", "chance": 0.3, "effect": {"economy": {"region": "valkaria", "good": "ferramentas", "delta": 150}}, "news": "Uma grande caravana chegou a Valkaria."},
   {"id": "colheita_ruim", "chance": 0.08, "effect": {"economy": {"region": "valkaria", "good": "comida", "delta": -800}}, "news": "Dizem que a colheita foi ruim nas fazendas ao redor de Valkaria."},
   {"id": "festival", "chance": 0.05, "effect": {"economy": {"region": "valkaria", "good": "bebida", "delta": -400}}, "news": "Houve um festival na capital; o vinho acabou em dois dias."},
   {"id": "patrulha", "chance": 0.1, "effect": {}, "news": "Patrulhas da capital foram vistas nas estradas do sul."}],
  "courier": "saria", "courier_cycle_days": 5, "courier_present_days": 2, "status": "ORIGINAL_DO_JOGO"}]}

# Barranco na floresta (desnível): só quem voa atravessa; a ponte é a passagem a pé.
for y in range(4, 16):
    for x in (60, 61):
        g[y][x] = "B"
for x in (60, 61):
    g[9][x] = "p"
legend = {".": {"name": "grama", "walk": True}, "=": {"name": "estrada", "walk": True}, ":": {"name": "trilha", "walk": True},
          ",": {"name": "chão de floresta", "walk": True}, "c": {"name": "plantação", "walk": True, "difficult": True},
          "T": {"name": "árvore", "walk": False, "cover": True}, "~": {"name": "rio", "walk": False, "water": True}, "#": {"name": "parede", "walk": False},
          "_": {"name": "piso", "walk": True}, "%": {"name": "entulho", "walk": True, "difficult": True}, "D": {"name": "porta", "walk": True, "object": True},
          "S": {"name": "escada", "walk": True}, "U": {"name": "escada", "walk": True}, "o": {"name": "poço", "walk": False}, "X": {"name": "vazio", "walk": False},
          "B": {"name": "barranco", "walk": False, "chasm": True}, "p": {"name": "ponte", "walk": True}}
## Bolsões de chão caminhável (superfície, y < 49) sem ligação com o início: abre caminho cortando árvores.
## Ordem fixa e desempate fixo, para o mapa sair igual a cada geração. A cripta liga por escada, não entra aqui.
def conectar_bolsoes(start: tuple, limite_y: int = 49) -> None:
    def passavel(t: tuple) -> bool:
        x, y = t
        return 0 <= x < W and 0 <= y < limite_y and bool(legend.get(g[y][x], {}).get("walk", False))
    def alcance(origem: tuple) -> set:
        seen = {origem}
        fila = deque([origem])
        while fila:
            x, y = fila.popleft()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in seen and passavel(n):
                    seen.add(n)
                    fila.append(n)
        return seen
    while True:
        seen = alcance(start)
        sobras = [(x, y) for y in range(limite_y) for x in range(W) if passavel((x, y)) and (x, y) not in seen]
        if not sobras:
            return
        alvo = sobras[0]
        custo = {alvo: 0}
        anterior = {}
        fila = [(0, alvo)]
        achado = None
        while fila and achado is None:
            c, t = heapq.heappop(fila)
            if c > custo[t]:
                continue
            if t in seen:
                achado = t
                break
            for n in ((t[0] + 1, t[1]), (t[0] - 1, t[1]), (t[0], t[1] + 1), (t[0], t[1] - 1)):
                if not (0 <= n[0] < W and 0 <= n[1] < limite_y):
                    continue
                if g[n[1]][n[0]] == "T":
                    w = 1
                elif passavel(n):
                    w = 0
                else:
                    continue
                if c + w < custo.get(n, 10 ** 9):
                    custo[n] = c + w
                    anterior[n] = t
                    heapq.heappush(fila, (c + w, n))
        if achado is None:
            raise RuntimeError("bolsão sem caminho até o início: %s" % (alvo,))
        t = achado
        while t != alvo:
            if g[t[1]][t[0]] == "T":
                g[t[1]][t[0]] = ","
            t = anterior[t]


conectar_bolsoes((23, 27))
grid = ["".join(r) for r in g]
zones = [{"id": "vila", "rect": [2, 6, 44, 42]}, {"id": "estrada", "rect": [44, 22, 52, 6]}, {"id": "floresta", "rect": [48, 0, 48, 50]},
         {"id": "ruina", "rect": [80, 4, 13, 11]}, {"id": "cripta", "rect": [3, 50, 42, 13]}]
world = {"schema_version": 1, "status": "ORIGINAL_DO_JOGO", "tile_px": 32, "size": [W, H], "grid": grid, "legend": legend, "zones": zones,
         "player_start": [23, 27], "locations": locations, "objects": objects, "targets": targets}
mysteries_extra = {"mysteries": [{
 "truth_id": "m_ovelhas", "status": "ORIGINAL_DO_JOGO", "title": "As Ovelhas de Fenna",
 "historical_context": "Quando a matilha passa fome, caça as ovelhas da estrada leste. Fenna acredita que são lobos.",
 "facts": {"f_ovelhas_mortas": "Algo está matando as ovelhas de Fenna na estrada leste.",
           "f_marcas_hiena": "As mordidas são de hienas, não de lobos.",
           "f_toca_hienas": "A matilha tem uma toca no leste do Bosque Sombrio."},
 "hypotheses": {"h_lobos": {"text": "Lobos estão atacando o rebanho.", "supported_by": [], "contradicted_by": ["f_marcas_hiena"]},
                "h_hienas": {"text": "As hienas do bosque atacam o rebanho por fome.", "supported_by": ["f_marcas_hiena", "f_toca_hienas"], "contradicted_by": []}},
 "start_facts": [], "factions_interested": [], "state_transitions": {"resolvido": {"requires": "matilha derrotada"}},
}]}
files = {"mysteries_extra": mysteries_extra, "map": world, "npcs": {"npcs": npcs, "schedule_templates": SCHED, "families": families, "factions": factions, "creatures": creatures},
         "mystery": mystery, "items": items, "economy": economy, "laws": laws, "distant": distant}
for k, v in files.items():
    (OUT / f"{k}.json").write_text(json.dumps(v, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(npcs), "npcs", len(locations), "locais", len(objects), "objetos", len(targets), "alvos")
print("\n".join(grid))
