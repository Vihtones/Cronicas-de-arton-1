"""Gera o conteúdo estático do vertical slice (ORIGINAL_DO_JOGO) em data/world/.
Determinístico: mesma execução => mesmos arquivos. Edite aqui, não os JSON gerados — EXCETO map.json e items.json, que hoje são
mantidos à mão (armadilhas, objetos, madeira, ampliação a leste por tools/gen_mapa_leste.py, itens de magia): o gerador não os
sobrescreve, a não ser com --forcar (o que perde essas edições)."""
import heapq, json, random, pathlib, sys
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
 # Pedra Branca (a leste, no fim da estrada)
 "estalajadeiro": [[0, 2, "work"], [2, 8, "home"], [8, 24, "work"]],
 "barqueiro":  [[0, 6, "home"], [6, 12, "cais"], [12, 13, "estalagem"], [13, 18, "cais"], [18, 21, "estalagem"], [21, 24, "home"]],
 "comerciante_pb": [[0, 8, "home"], [8, 18, "work"], [18, 21, "estalagem"], [21, 24, "home"]],
 "vigia_dia":  [[0, 7, "home"], [7, 19, "work"], [19, 24, "home"]],
 "vigia_noite":[[0, 7, "work"], [7, 19, "home"], [19, 24, "work"]],
 "anciao_vale": [[0, 8, "home"], [8, 11, "praca_vale"], [11, 18, "home"], [18, 20, "taverna_vale"], [20, 24, "home"]],
 "lavrador_pb":[[0, 5, "home"], [5, 12, "work"], [12, 13, "home"], [13, 18, "work"], [18, 24, "home"]],
 # Fronteira do Leste: Junco Alto (brejo), Areia Dourada (deserto), Rocha Negra (montanha)
 "pescador":   [[0, 5, "home"], [5, 12, "work"], [12, 13, "taberna_sapo"], [13, 17, "work"], [17, 21, "taberna_sapo"], [21, 24, "home"]],
 "cacador_brejo": [[0, 5, "home"], [5, 12, "work"], [12, 14, "home"], [14, 18, "work"], [18, 21, "taberna_sapo"], [21, 24, "home"]],
 "anciao_junco": [[0, 8, "home"], [8, 11, "passarela_junco"], [11, 18, "home"], [18, 21, "taberna_sapo"], [21, 24, "home"]],
 "curandeira": [[0, 7, "home"], [7, 19, "work"], [19, 24, "home"]],
 "taverneiro_junco": [[0, 2, "work"], [2, 9, "home"], [9, 24, "work"]],
 "crianca_junco": [[0, 7, "home"], [7, 11, "passarela_junco"], [11, 13, "home"], [13, 17, "passarela_junco"], [17, 24, "home"]],
 "estalajadeiro_d": [[0, 2, "work"], [2, 8, "home"], [8, 24, "work"]],
 "comerciante_d": [[0, 8, "home"], [8, 18, "work"], [18, 21, "pousada_camelo"], [21, 24, "home"]],
 "guarda_areia": [[0, 7, "home"], [7, 12, "praca_areia"], [12, 13, "pousada_camelo"], [13, 19, "praca_areia"], [19, 24, "home"]],
 "atendente_guilda": [[0, 8, "home"], [8, 20, "work"], [20, 22, "pousada_camelo"], [22, 24, "home"]],
 "erudito_oasis": [[0, 8, "home"], [8, 17, "oasis"], [17, 24, "pousada_camelo"]],
 "crianca_d": [[0, 7, "home"], [7, 18, "praca_areia"], [18, 24, "home"]],
 "artesao_rn": [[0, 7, "home"], [7, 12, "work"], [12, 13, "taverna_picareta"], [13, 18, "work"], [18, 21, "taverna_picareta"], [21, 24, "home"]],
 "minerador": [[0, 6, "home"], [6, 12, "casa_mina"], [12, 13, "taverna_picareta"], [13, 18, "casa_mina"], [18, 22, "taverna_picareta"], [22, 24, "home"]],
 "estalajadeiro_rn": [[0, 2, "work"], [2, 8, "home"], [8, 24, "work"]],
 "capataz": [[0, 6, "home"], [6, 18, "work"], [18, 21, "taverna_picareta"], [21, 24, "home"]],
 "sacerdote_rn": [[0, 12, "work"], [12, 13, "praca_rocha"], [13, 24, "work"]],
 "guarda_rocha_dia": [[0, 7, "home"], [7, 12, "praca_rocha"], [12, 13, "taverna_picareta"], [13, 19, "praca_rocha"], [19, 24, "work"]],
 "guarda_rocha_noite": [[0, 6, "praca_rocha"], [6, 14, "home"], [14, 18, "work"], [18, 24, "praca_rocha"]],
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
 npc("tarso", "Tarso Pedrada", 28, "mensageiro", "viajante", "taverna", "mercado", None, traits=["traz_noticias"], gold=30),
 npc("saria", "Saria das Estradas", 33, "mercadora viajante", "viajante", "taverna", "mercado", None, traits=["traz_noticias"], gold=60),
 npc("orin", "Mestre Orin", 55, "alcaide", "alcaide", "prefeitura", "prefeitura", None, "guarda_vila", "Khalmyr", gold=50),
 npc("tobias", "Tobias", 28, "guarda", "guarda_dia", "quartel", "quartel", None, "guarda_vila"),
 npc("fenna", "Fenna", 24, "pastora", "pastora", "casa_aldren", "estrada_leste", "aldren"),
 npc("dorn", "Dorn", 47, "bêbado", "bebado", "taverna", "taverna", None, "garras_de_cinza", traits=["mentiroso"]),
 # Pedra Branca
 npc("berta", "Berta Pontes", 46, "estalajadeira", "estalajadeiro", "estalagem", "estalagem", "pontes", traits=["fofoqueira"], gold=45),
 npc("caio", "Caio Pontes", 49, "cozinheiro", "estalajadeiro", "estalagem", "estalagem", "pontes", gold=20),
 npc("tuco", "Tuco Pontes", 34, "barqueiro", "barqueiro", "casa_barqueiro", "cais", "pontes", traits=["calado"]),
 npc("gunther", "Gunther Pontes", 62, "lavrador", "lavrador_pb", "casa_barqueiro", "campos_pedrabranca", "pontes"),
 npc("marta", "Marta Brisa", 41, "mercadora", "comerciante_pb", "entreposto", "entreposto", None, traits=["traz_noticias"], gold=70),
 npc("lia", "Lia Vento", 26, "vigia", "vigia_noite", "torre_vigia", "torre_vigia", None),
 npc("hesk", "Sargento Hesk", 50, "vigia", "vigia_dia", "torre_vigia", "torre_vigia", None, devotion="Khalmyr", traits=["exige_provas"]),
 # --- Fronteira do Leste: Junco Alto (brejo) ---
 npc("zeca", "Zeca Sapo", 48, "taverneiro", "taverneiro_junco", "taberna_sapo", "taberna_sapo", "sapo", traits=["fofoqueiro"], gold=35),
 npc("juta", "Juta Sapo", 44, "cozinheira", "taverneiro_junco", "taberna_sapo", "taberna_sapo", "sapo", gold=15),
 npc("nico", "Nico Sapo", 36, "pescador", "pescador", "casa_pescador", "passarela_junco", "sapo", traits=["calado"], gold=12),
 npc("pipo", "Pipo Sapo", 10, "criança", "crianca_junco", "casa_pescador", None, "sapo", traits=["curioso"]),
 npc("mirta", "Vovó Mirta", 71, "curandeira", "curandeira", "cabana_curandeira", "cabana_curandeira", None, devotion="Allihanna", traits=["recluso"], gold=60),
 npc("tica", "Tica", 15, "aprendiz", "curandeira", "cabana_curandeira", "cabana_curandeira", None, traits=["curioso"]),
 npc("brutus", "Brutus Garra", 52, "caçador", "cacador_brejo", "casa_cacador_croc", "brejo_norte", None, traits=["recluso", "desconfia_de_estrangeiros"], gold=45),
 npc("jurandi", "Ancião Jurandi", 78, "ancião", "anciao_junco", "palanque_anciao", None, None, devotion="Allihanna", traits=["memoria_longa"], gold=20),
 # --- Posto Areia Dourada (deserto) ---
 npc("haziz", "Haziz Al-Dahab", 55, "estalajadeiro", "estalajadeiro_d", "pousada_camelo", "pousada_camelo", "dahab", traits=["fofoqueiro"], gold=80),
 npc("nadia", "Nadia Al-Dahab", 30, "cozinheira", "estalajadeiro_d", "pousada_camelo", "pousada_camelo", "dahab", gold=20),
 npc("yara", "Yara Al-Dahab", 11, "criança", "crianca_d", "pousada_camelo", None, "dahab", traits=["curioso"]),
 npc("kharim", "Kharim Bazari", 47, "mercador", "comerciante_d", "bazar_tendas", "bazar_tendas", None, traits=["traz_noticias"], gold=200),
 npc("sulema", "Sulema Forja-Vento", 40, "armeira", "artesao", "armaria_deserto", "armaria_deserto", None, traits=["exige_provas"], gold=150),
 npc("dara", "Dara Ventania", 26, "curandeira", "curandeira", "casa_curandeira_d", "casa_curandeira_d", None, devotion="Lena", gold=50),
 npc("iben", "Iben Caravaneiro", 33, "atendente da guilda", "atendente_guilda", "guilda_filial", "guilda_filial", "dahab", gold=40),
 npc("zahir", "Capitão Zahir", 45, "capitão de caravana", "guarda_areia", "praca_areia", "praca_areia", None, "guarda_fronteira", "Khalmyr", ["exige_provas"], gold=60),
 npc("ossian", "Ossian Vale", 58, "erudito", "erudito_oasis", "oasis", "oasis", None, traits=["memoria_longa", "curioso"], gold=40),
 # --- Rocha Negra (montanha) ---
 npc("durin", "Durin Martelo-Negro", 88, "ferreiro", "artesao_rn", "alojamento_mineiros", "forja_ana", "martelo_negro", traits=["teimoso"], gold=300),
 npc("brenna", "Brenna Martelo-Negro", 80, "estalajadeira", "estalajadeiro_rn", "alojamento_mineiros", "alojamento_mineiros", "martelo_negro", gold=90),
 npc("hakon", "Hakon Barba-Ruiva", 44, "taverneiro", "estalajadeiro_rn", "taverna_picareta", "taverna_picareta", None, traits=["observador"], gold=60),
 npc("gorm", "Gorm Cinzento", 50, "capataz", "capataz", "casa_mina", "casa_mina", None, traits=["exige_provas"], gold=80),
 npc("pedro_pa", "Pedro Pá", 38, "minerador", "minerador", "alojamento_mineiros", "casa_mina", None, gold=15),
 npc("olga", "Olga Veio", 42, "mineradora", "minerador", "alojamento_mineiros", "casa_mina", None, traits=["calada"], gold=18),
 npc("thyra", "Thyra Fiel-Martelo", 36, "sacerdotisa de Khalmyr", "sacerdote_rn", "capela_khalmyr", "capela_khalmyr", None, "templo_khalmyr", "Khalmyr", gold=60),
 npc("rolf", "Capitão Rolf", 46, "capitão da guarda", "guarda_rocha_dia", "posto_guarda_rn", "posto_guarda_rn", None, "guarda_fronteira", "Khalmyr", ["exige_provas"], gold=50),
 npc("ysa", "Ysa", 28, "guarda", "guarda_rocha_noite", "posto_guarda_rn", "posto_guarda_rn", None, "guarda_fronteira"),
 # --- Horizonte (leste, além da Fronteira) ---
 npc("bram", "Bram Estradeiro", 54, "guia", "viajante", "casa_guia", "praca_horizonte", "estradeiros", traits=["traz_noticias"], gold=40),
 npc("lotte", "Lotte Estradeira", 36, "estalajadeira", "estalajadeiro", "estalagem_horizonte", "estalagem_horizonte", "estradeiros", traits=["fofoqueira"], gold=50),
 npc("hogan", "Hogan Martelo", 47, "ferreiro", "artesao", "casa_ferreiro_estrada", "casa_ferreiro_estrada", None, traits=["exige_provas"], gold=120),
 npc("ilka", "Ilka Carroceira", 31, "carroceira", "comerciante", "casa_guia", "armazem_horizonte", None, traits=["traz_noticias"], gold=90),
 # --- Aldeia do Vale (sul, subindo do deserto) ---
 npc("ancia", "Anciã Revas", 81, "anciã", "idoso", "casa_anciao", "casa_anciao", None, devotion="Allihanna", traits=["memoria_longa"], gold=10),
 npc("gorvo", "Gorvo Fundo", 43, "taverneiro", "taverneiro", "taverna_vale", "taverna_vale", None, traits=["fofoqueiro"], gold=55),
 npc("sela", "Sela Caçadora", 29, "caçador", "cacador", "casa_cacadores", "praca_vale", None, traits=["recluso"], gold=25),
 npc("teo", "Teo Ferro-Vale", 22, "ferreiro", "artesao", "ferreiro_vale", "ferreiro_vale", None, gold=40),
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
 {"id": "pontes", "name": "Pontes", "members": ["berta", "caio", "tuco", "gunther"]},
 {"id": "sapo", "name": "Sapo", "members": ["zeca", "juta", "nico", "pipo"]},
 {"id": "dahab", "name": "Al-Dahab", "members": ["haziz", "nadia", "yara", "iben"]},
 {"id": "martelo_negro", "name": "Martelo-Negro", "members": ["durin", "brenna"]},
 {"id": "estradeiros", "name": "Estradeiros", "members": ["bram", "lotte", "ilka"]},
]
factions = [
 {"id": "guarda_vila", "name": "Guarda da Vila", "goals": ["manter_ordem", "proteger_estrada"], "resources": {"soldados": 3, "ouro": 80},
  "allies": ["templo_lena"], "rivals": ["garras_de_cinza"], "jurisdiction": "vila", "status": "ORIGINAL_DO_JOGO"},
 {"id": "templo_lena", "name": "Templo de Lena", "goals": ["recuperar_dizimo", "curar"], "resources": {"ouro": 10},
  "allies": ["guarda_vila"], "rivals": [], "status": "ORIGINAL_DO_JOGO"},
 {"id": "garras_de_cinza", "name": "Garras de Cinza", "goals": ["esconder_saque", "evitar_guarda"], "resources": {"membros": 3, "ouro": 120},
  "allies": [], "rivals": ["guarda_vila"], "hideout": "cripta_salao", "relocate_day": 12, "status": "ORIGINAL_DO_JOGO"},
 {"id": "guarda_fronteira", "name": "Guarda da Fronteira", "goals": ["proteger_caravanas", "manter_ordem"], "resources": {"soldados": 4, "ouro": 150},
  "allies": ["guarda_vila", "templo_khalmyr"], "rivals": [], "status": "ORIGINAL_DO_JOGO"},
 {"id": "templo_khalmyr", "name": "Capela de Khalmyr", "goals": ["fazer_justica", "curar"], "resources": {"ouro": 30},
  "allies": ["guarda_fronteira"], "rivals": [], "status": "ORIGINAL_DO_JOGO"},
]

# Posições das criaturas da Fronteira: o ponto andável mais próximo do pedido, lido do mapa já ampliado (map.json é mantido à mão).
_MAPA_ATUAL = json.loads((OUT / "map.json").read_text(encoding="utf-8")) if (OUT / "map.json").exists() else {"grid": [], "legend": {}}
def ponto(x, y):
    gr, lg = _MAPA_ATUAL["grid"], _MAPA_ATUAL["legend"]
    if not gr or len(gr[0]) <= x:
        return [x, y]
    for r in range(0, 12):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                xx, yy = x + dx, y + dy
                if 0 <= yy < len(gr) and 0 <= xx < len(gr[0]) and lg.get(gr[yy][xx], {}).get("walk") and gr[yy][xx] not in "pDSU=":
                    return [xx, yy]
    return [x, y]
def fera(id, nome, regra, fac, x, y, zona, **extra):
    d = {"id": id, "name": nome, "rule": "criatura." + regra, "faction": fac, "spawn": ponto(x, y), "zone": zona}
    d.update(extra)
    return d
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
 # Serra do Leste: matilha que desce das cristas à noite
 {"id": "hiena_5", "name": "Hiena da Serra", "rule": "criatura.hiena", "faction": "fauna", "spawn": [116, 31], "zone": "serra", "active_hours": [19, 5],
  "signal": "Um riso agudo desce das cristas da serra."},
 {"id": "hiena_6", "name": "Hiena da Serra", "rule": "criatura.hiena", "faction": "fauna", "spawn": [118, 33], "zone": "serra", "active_hours": [19, 5]},
 # --- Fronteira do Leste -------------------------------------------------------------------------------------------
 # Brejo da Névoa: répteis e gosmas fora da passarela; o Culto da Serpente no altar, ao norte
 fera("naja_1", "Naja do Brejo", "naja", "fauna", 196, 40, "brejo", signal="Um chiado baixo vem da lama."),
 fera("naja_2", "Naja do Brejo", "naja", "fauna", 190, 44, "brejo"),
 fera("sucuri_1", "Sucuri Anciã", "sucuri", "fauna", 178, 11, "brejo", signal="A água parada se mexe devagar demais."),
 fera("jiboia_1", "Jiboia", "jiboia", "fauna", 172, 38, "brejo"),
 fera("glop_b1", "Gosma do Brejo", "glop", "gosmas_brejo", 170, 5, "brejo"),
 fera("glop_b2", "Gosma do Brejo", "glop", "gosmas_brejo", 174, 7, "brejo"),
 fera("glop_b3", "Gosma do Brejo", "glop", "gosmas_brejo", 172, 3, "brejo"),
 fera("nagah_1", "Nagah Guardião", "nagah_guardiao", "culto_serpente", 187, 5, "brejo", signal="Sibilos ritmados vêm da ilha ao norte."),
 fera("nagah_2", "Nagah Guardião", "nagah_guardiao", "culto_serpente", 192, 9, "brejo"),
 fera("cultista_1", "Voz de Sszzaas", "cultista_de_sszzaas", "culto_serpente", 190, 9, "brejo", important=True),
 # Terras Áridas
 fera("cascavel_d1", "Cascavel do Deserto", "cascavel", "fauna", 207, 33, "deserto", signal="O guizo de uma cascavel corta o silêncio."),
 fera("cascavel_d2", "Cascavel do Deserto", "cascavel", "fauna", 238, 31, "deserto"),
 fera("gnoll_1", "Gnoll Saqueador", "gnoll_saqueador", "gnolls_deserto", 208, 8, "deserto", signal="Latidos que parecem riso vêm das dunas ao norte."),
 fera("gnoll_2", "Gnoll Saqueador", "gnoll_saqueador", "gnolls_deserto", 211, 10, "deserto"),
 fera("gnoll_3", "Gnoll Saqueador", "gnoll_saqueador", "gnolls_deserto", 206, 11, "deserto"),
 fera("gnoll_chefe", "Dente-Torto, gnoll filibusteiro", "gnoll_filibusteiro", "gnolls_deserto", 209, 9, "deserto", important=True),
 fera("grifo_1", "Grifo Faminto", "grifo", "fauna", 216, 4, "deserto", active_hours=[5, 20], signal="Um grito de ave de rapina ecoa nas rochas."),
 fera("basilisco_1", "Basilisco das Pedras", "basilisco", "fauna", 205, 44, "deserto", signal="Estátuas de viajantes cercam um poço de pedra ao sul."),
 fera("manticora_1", "Mantícora do Sul", "manticora", "fauna", 233, 45, "deserto", signal="Espinhos longos se cravam nas rochas ao sul."),
 # Forte Caído: mortos sob um necromante
 fera("esq_f1", "Esqueleto do Forte", "esqueleto", "mortos_forte", 226, 8, "forte"),
 fera("esq_f2", "Esqueleto do Forte", "esqueleto", "mortos_forte", 232, 6, "forte"),
 fera("esq_f3", "Esqueleto do Forte", "esqueleto", "mortos_forte", 231, 12, "forte"),
 fera("zumbi_f1", "Zumbi do Forte", "zumbi", "mortos_forte", 229, 9, "forte"),
 fera("zumbi_f2", "Zumbi do Forte", "zumbi", "mortos_forte", 224, 12, "forte"),
 fera("necro_1", "Mestre Corvino, o necromante", "necromante", "mortos_forte", 235, 6, "forte", important=True, signal="Um frio estranho sai do forte em ruínas."),
 # Rocha Negra
 fera("lobo_r1", "Lobo da Montanha", "lobo", "fauna", 256, 40, "rocha", active_hours=[17, 7]),
 fera("lobo_r2", "Lobo da Montanha", "lobo", "fauna", 259, 42, "rocha", active_hours=[17, 7]),
 fera("urso_r1", "Urso-coruja", "urso_coruja", "fauna", 246, 10, "rocha", signal="Garras enormes arranharam os troncos ao norte."),
 fera("orc_r1", "Orc Batedor", "orc_combatente", "orcs_rocha", 272, 41, "rocha", signal="Fumaça de fogueira orc sobe ao sul da vila."),
 fera("orc_r2", "Orc Batedor", "orc_combatente", "orcs_rocha", 275, 43, "rocha"),
 fera("orc_r3", "Orc Batedor", "orc_combatente", "orcs_rocha", 270, 44, "rocha"),
 fera("orc_chefe_r", "Skarg, chefe orc", "orc_chefe", "orcs_rocha", 273, 42, "rocha", important=True),
 fera("ogro_r1", "Ogro da Encosta", "ogro", "fauna", 282, 36, "rocha", signal="Passos pesados fazem a terra tremer a leste."),
 # Minas de Rocha Negra (subsolo)
 fera("aranha_m1", "Aranha-das-minas", "aranha_gigante", "aranhas_mina", 263, 53, "cripta", signal="Teias grossas cobrem a passagem."),
 fera("aranha_m2", "Aranha-das-minas", "aranha_gigante", "aranhas_mina", 268, 52, "cripta"),
 fera("glop_m1", "Gosma da Mina", "glop", "gosmas_mina", 263, 59, "cripta"),
 fera("glop_m2", "Gosma da Mina", "glop", "gosmas_mina", 267, 60, "cripta"),
 fera("glop_m3", "Gosma da Mina", "glop", "gosmas_mina", 269, 58, "cripta"),
 fera("feitor_1", "Grubnak, feitor finntroll", "finntroll_feitor", "feitor_mina", 278, 56, "cripta", important=True, signal="Ecos de correntes e uma risada grave vêm do fundo."),
 fera("orc_m1", "Capanga orc do feitor", "orc_combatente", "feitor_mina", 276, 54, "cripta"),
 fera("orc_m2", "Capanga orc do feitor", "orc_combatente", "feitor_mina", 276, 58, "cripta"),
 # Horizonte: estrada do leste
 fera("lobo_h1", "Lobo do Horizonte", "lobo", "fauna", 300, 36, "horizonte", active_hours=[18, 6]),
 fera("lobo_h2", "Lobo do Horizonte", "lobo", "fauna", 304, 38, "horizonte", active_hours=[18, 6]),
 fera("salteador_h1", "Salteador da estrada", "bandido_comum", "salteadores_h", 320, 27, "horizonte", start_present=False),
 fera("salteador_h2", "Salteador da estrada", "bandido_comum", "salteadores_h", 325, 29, "horizonte", start_present=False),
 fera("ogro_h1", "Ogro do Horizonte", "ogro", "fauna", 330, 40, "horizonte", signal="Uma pedra rola na encosta a leste."),
 # Vale do Sul: mata e minas que descem
 fera("aranha_v1", "Aranha do Vale", "aranha_gigante", "fauna", 206, 84, "vale_sul", signal="Teias brilham entre as árvores do vale."),
 fera("hiena_v1", "Hiena do Vale", "hiena", "fauna", 225, 88, "vale_sul", active_hours=[18, 6]),
 fera("hiena_v2", "Hiena do Vale", "hiena", "fauna", 229, 90, "vale_sul", active_hours=[18, 6]),
 fera("orc_v1", "Orc do Vale", "orc_combatente", "orcs_vale", 236, 62, "vale_sul", signal="Vozes guturais vêm das sombras do vale."),
 fera("orc_v2", "Orc do Vale", "orc_combatente", "orcs_vale", 238, 66, "vale_sul"),
 fera("orc_chefe_v", "Garrok, chefe orc do vale", "orc_chefe", "orcs_vale", 237, 70, "vale_sul", important=True),
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
 "ferramenta_oficio": {"name": "Ferramenta de ofício", "price": 8, "good": "ferramentas"},
 "tabua": {"name": "Tábua de madeira", "price": 2, "good": "madeira"},
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
           "berta": ["pao", "cerveja"], "marta": ["corda", "tocha", "pao", "saco_de_dormir", "pocao_cura"],
           "valkaria_mercado": ["pocao_cura", "saco_de_dormir", "arco_curto", "cota_malha", "espada_longa", "tocha", "corda"],
           "zeca": ["pao", "cerveja", "ensopado_junco"], "juta": ["pao", "ensopado_junco"],
           "mirta": ["pocao_cura", "frasco_agua"], "brutus": ["gibao_peles", "couro_batido", "arco_curto", "machadinha", "adaga"],
           "haziz": ["pao", "cerveja", "vinho_de_cacto"], "nadia": ["pao", "vinho_de_cacto"],
           "kharim": ["corda", "tocha", "pao", "saco_de_dormir", "pocao_cura", "agua_benta", "arco_longo", "besta_leve", "armadura_couro", "armadura_acolchoada", "escudo_leve", "frasco_agua"],
           "sulema": ["espada_curta", "espada_longa", "cimitarra", "florete", "machado_batalha", "martelo_guerra", "tridente", "mangual", "brunea", "escudo_leve", "escudo_pesado", "couro_batido"],
           "dara": ["pocao_cura", "frasco_agua"],
           "durin": ["picareta", "marreta", "machado_guerra", "alabarda", "montante", "martelo_guerra", "cota_malha", "loriga_segmentada", "meia_armadura", "escudo_pesado"],
           "brenna": ["pao", "cerveja_ana", "ensopado_junco"], "hakon": ["pao", "cerveja_ana", "cerveja"],
           "gorm": ["picareta", "tocha", "corda"], "thyra": ["pocao_cura", "agua_benta"],
           "lotte": ["pao", "cerveja", "corda", "tocha"], "gorvo": ["pao", "cerveja", "ensopado_junco"],
           "hogan": ["adaga", "machadinha", "espada_curta", "cimitarra", "escudo_leve", "couro_batido", "armadura_couro"],
           "ilka": ["corda", "tocha", "saco_de_dormir", "pao", "ferramenta_oficio"],
           "teo": ["picareta", "tridente", "escudo_pesado", "armadura_acolchoada"],
           "garrick": ["adaga", "espada_curta", "espada_longa", "machado_batalha", "arco_curto", "couro_batido", "cota_malha"]},
}
# Fronteira do Leste: estoque próprio (as lojas das três regiões não esvaziam a vila) e ligação por zona do mapa.
economy["regions"]["fronteira"] = {
 "stock": {"comida": 300, "bebida": 200, "ferramentas": 120, "remedio": 20, "madeira": 40},
 "production": {"comida": 25, "bebida": 15, "ferramentas": 8, "remedio": 1, "madeira": 0},
 "consumption": {"comida": 24, "bebida": 15, "ferramentas": 6, "remedio": 0, "madeira": 0},
 "target": {"comida": 300, "bebida": 200, "ferramentas": 120, "remedio": 20, "madeira": 40}}
economy["regioes_por_zona"] = {"brejo": "fronteira", "deserto": "fronteira", "rocha": "fronteira", "horizonte": "fronteira", "vale_sul": "fronteira"}
# Arton Viva, Fase 1: bem que cada profissão produz ao completar um turno de trabalho.
economy["producao_trabalho"] = {
 "_nota": "Arton Viva, Fase 1: bem que cada profissão produz ao completar um turno de trabalho (ORIGINAL_DO_JOGO).",
 "lavrador": "comida", "lavradora": "comida", "pastora": "comida", "moleiro": "comida", "cozinheiro": "comida",
 "caçador": "comida", "taverneira": "bebida", "ferreiro": "ferramentas", "clériga de Lena": "remedio"}
# Arton Viva, Fase 1: quem começou o ofício há 2 anos ou mais já tem a ferramenta; os outros compram no tempo livre.
economy["ferramenta_de_oficio"] = {
 "_nota": "Arton Viva, Fase 1: quem exerce o ofício precisa de ferramenta própria. Quem começou há 2 anos ou mais (a partir de idade_inicio_oficio) já tem; os outros compram do vendedor no tempo livre.",
 "item": "ferramenta_oficio", "vendedor": "mara", "idade_inicio_oficio": 16, "anos_para_ter": 2,
 "profissoes": ["ferreiro", "aprendiz", "lavrador", "lavradora", "moleiro", "ajudante de moleiro", "caçador", "pastora"]}
economy["shops"]["mara"].append("ferramenta_oficio")
economy["shops"]["mara"].append("tabua")
# Arton Viva, Fase 4: segunda região, com remédio em excesso (o bem mais escasso da vila).
economy["regions"]["samburdia"] = {
 "stock": {"comida": 800, "bebida": 300, "ferramentas": 300, "remedio": 400},
 "production": {"comida": 60, "bebida": 30, "ferramentas": 25, "remedio": 30},
 "consumption": {"comida": 40, "bebida": 20, "ferramentas": 20, "remedio": 10},
 "target": {"comida": 800, "bebida": 300, "ferramentas": 300, "remedio": 400}}
# Rotas comerciais entre regiões (cada uma com a região de origem, destino e se está aberta).
economy["routes"] = {
 "valkaria_vila": {"nome": "estrada de Valkaria", "from": "valkaria", "to": "vila", "open": True},
 "samburdia_vila": {"nome": "estrada de Sambúrdia", "from": "samburdia", "to": "vila", "open": True}}
# Arton Viva, Fase 4: madeira só existe em Sambúrdia. A vila consome e não produz; sem a estrada, a falta vem.
economy["goods"]["madeira"] = {"base": 1.0}
for _reg, _vals in {"vila": (40, 0, 2, 40), "valkaria": (3000, 200, 190, 3000), "samburdia": (600, 15, 15, 600)}.items():
    _est, _prod, _cons, _alvo = _vals
    economy["regions"][_reg]["stock"]["madeira"] = _est
    economy["regions"][_reg]["production"]["madeira"] = _prod
    economy["regions"][_reg]["consumption"]["madeira"] = _cons
    economy["regions"][_reg]["target"]["madeira"] = _alvo
# Arton Viva, Fase 5: construções que a vila faz com o próprio tesouro (comando Build).
economy["construcoes"] = {
 "celeiro": {"nome": "Celeiro", "custo": 120, "efeito": {"producao": {"regiao": "vila", "bem": "comida", "delta": 6}},
             "descricao": "guarda grãos: a vila produz mais comida todo dia"},
 "casa": {"nome": "Casa nova", "custo": 150, "efeito": {"vagas": 2},
          "descricao": "abre duas vagas para famílias apertadas"},
 "guarita": {"nome": "Guarita", "custo": 100, "efeito": {"guardas": 1},
             "descricao": "posto de vigia: conta como mais um guarda"}}
# Arton Viva, Fase 6: contratos que a guilda aceita para os membros; o pagamento vai ao caixa da guilda.
economy["contratos_guilda"] = {
 "escolta_mercado": {"nome": "Escolta de carroça até Valkaria", "pagamento": 40, "dias": 2, "membros_min": 2, "destino": "estrada_leste"},
 "patrulha_estrada": {"nome": "Patrulha da estrada leste", "pagamento": 25, "dias": 1, "membros_min": 1, "destino": "estrada_leste"}}
laws = {"vila": {"furto": {"multa": 10, "severidade": 1}, "invasao": {"multa": 3, "severidade": 0}, "dano_propriedade": {"multa": 5, "severidade": 1},
                 "agressao": {"multa": 20, "severidade": 2}}, "status": "ORIGINAL_DO_JOGO"}
distant = {"regions": [{"id": "valkaria", "name": "Valkaria", "lod": "L3", "events": [
   {"id": "caravana_chega", "chance": 0.3, "effect": {"economy": {"region": "valkaria", "good": "ferramentas", "delta": 150}}, "news": "Uma grande caravana chegou a Valkaria."},
   {"id": "colheita_ruim", "chance": 0.08, "effect": {"economy": {"region": "valkaria", "good": "comida", "delta": -800}}, "news": "Dizem que a colheita foi ruim nas fazendas ao redor de Valkaria."},
   {"id": "festival", "chance": 0.05, "effect": {"economy": {"region": "valkaria", "good": "bebida", "delta": -400}}, "news": "Houve um festival na capital; o vinho acabou em dois dias."},
   {"id": "patrulha", "chance": 0.1, "effect": {}, "news": "Patrulhas da capital foram vistas nas estradas do sul."}],
  "courier": "saria", "courier_cycle_days": 5, "courier_present_days": 2, "status": "ORIGINAL_DO_JOGO"},
  {"id": "samburdia", "name": "Sambúrdia", "lod": "L3", "events": [
   {"id": "estrada_bloqueada", "chance": 0.03, "effect": {"route": {"id": "samburdia_vila", "open": False}}, "news": "Bandidos bloquearam a estrada de Sambúrdia; nenhum carro passa por ali."},
   {"id": "estrada_reaberta", "chance": 0.03, "effect": {"route": {"id": "samburdia_vila", "open": True}}, "news": "A estrada de Sambúrdia foi reaberta depois da escolta da cidade."},
   {"id": "epidemia_leve", "chance": 0.05, "effect": {"economy": {"region": "samburdia", "good": "remedio", "delta": -60}}, "news": "Uma tosse se espalhou pelos becos de Sambúrdia; as boticas gastam remédio."}],
  "courier": "tarso", "courier_cycle_days": 6, "courier_present_days": 2, "status": "ORIGINAL_DO_JOGO"}]}

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
# Arton Viva, Fase 6: ficha de combate de cada profissão (montada pelo construtor de personagens, como a do jogador).
FICHA_POR_PROFISSAO = {
 "guarda": {"raca": "humano", "classe": "guerreiro", "preset": 0},
 "capitã da guarda": {"raca": "humano", "classe": "guerreiro", "preset": 0},
 "ferreiro": {"raca": "anao", "classe": "guerreiro", "preset": 0},
 "caçador": {"raca": "humano", "classe": "ladino", "preset": 0},
 "mensageiro": {"raca": "humano", "classe": "ladino", "preset": 1},
}
for _n in npcs:
    _f = FICHA_POR_PROFISSAO.get(_n["profession"], {"raca": "humano", "classe": "guerreiro", "preset": 1})
    _n["combate"] = _f
files = {"mysteries_extra": mysteries_extra, "map": world, "npcs": {"npcs": npcs, "schedule_templates": SCHED, "families": families, "factions": factions, "creatures": creatures},
         "mystery": mystery, "items": items, "economy": economy, "laws": laws, "distant": distant}
MANTIDOS_A_MAO = {"map", "items"}
for k, v in files.items():
    if k in MANTIDOS_A_MAO and "--forcar" not in sys.argv:
        continue
    (OUT / f"{k}.json").write_text(json.dumps(v, ensure_ascii=False, indent=1), encoding="utf-8")
print("ok", len(npcs), "npcs", len(locations), "locais", len(objects), "objetos", len(targets), "alvos")
print("\n".join(grid))
