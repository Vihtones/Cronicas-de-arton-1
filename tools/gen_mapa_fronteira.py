#!/usr/bin/env python3
"""Estende data/world/map.json para a FRONTEIRA DO LESTE (x 160..287): Brejo da Névoa com o povoado de palafitas Junco Alto,
Terras Áridas com o Posto Areia Dourada, o oásis e o Forte Caído, e as montanhas de Rocha Negra com a vila mineira e as Minas
(galerias subterrâneas, zona "cripta" = subterrâneo). ORIGINAL_DO_JOGO.
Uso: python3 tools/gen_mapa_fronteira.py [--aplicar]   (sem a flag, só mostra a prévia). Idempotente: só roda se o mapa tem 160 colunas."""
import json, random, sys
from collections import deque

MAPA = "data/world/map.json"
X0, W, H = 160, 288, 49          # linhas 0..48: superfície; 49+: subsolo (cripta e minas)
rng = random.Random(20261028)
m = json.load(open(MAPA, encoding="utf-8"))
if len(m["grid"][0]) != 160:
    sys.exit("o mapa já foi estendido")
ALTURA = len(m["grid"])

novo = [[" "] * (W - X0) for _ in range(ALTURA)]


def put(x, y, ch):
    if X0 <= x < W and 0 <= y < ALTURA:
        novo[y][x - X0] = ch


def get(x, y):
    return novo[y][x - X0]


def rect_fill(x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, ch)


# ---- ruído de valor (suave) -------------------------------------------------------------------------------
_lat = {}


def _v(ix, iy, seed):
    k = (ix, iy, seed)
    if k not in _lat:
        _lat[k] = random.Random(hash(k) & 0xFFFFFFF).random() if False else random.Random(ix * 73856093 ^ iy * 19349663 ^ seed * 83492791).random()
    return _lat[k]


def vn(x, y, esc, seed):
    fx, fy = x / esc, y / esc
    ix, iy = int(fx), int(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = _v(ix, iy, seed) * (1 - tx) + _v(ix + 1, iy, seed) * tx
    b = _v(ix, iy + 1, seed) * (1 - tx) + _v(ix + 1, iy + 1, seed) * tx
    return a * (1 - ty) + b * ty


# ---- 1) terreno base ---------------------------------------------------------------------------------------
for y in range(H):
    for x in range(X0, W):
        c = x - X0
        r = rng.random()
        if c < 40:        # Brejo da Névoa
            n = vn(x, y, 7, 1) * 0.7 + vn(x, y, 3, 2) * 0.3
            if n > 0.64:
                ch = "~"
            elif n > 0.46:
                ch = "w" if r < 0.9 else "T"
            else:
                ch = "T" if r < 0.2 else ("," if r < 0.5 else ".")
            put(x, y, ch)
        elif c < 80:      # Terras Áridas
            n = vn(x, y, 9, 3)
            ch = "a"
            if r < 0.05:
                ch = "."
            elif r < 0.07:
                ch = "T"
            if n > 0.72 and r < 0.8:
                ch = "M"
            elif n > 0.66 and r < 0.4:
                ch = "g"
            put(x, y, ch)
        else:             # Rocha Negra
            n = vn(x, y, 8, 4)
            ch = "g" if r < 0.7 else ("." if r < 0.88 else ("T" if r < 0.95 else ":"))
            if n > 0.62:
                ch = "M"
            put(x, y, ch)

# transição suave: Terras Áridas começam com grama rala; a estrada vem de Pedra Branca (praça até x 157)
for y in range(H):
    for x in range(X0, X0 + 3):
        if get(x, y) in "~wM":
            put(x, y, ".")

# ---- 2) estrada principal (2 de largura) -------------------------------------------------------------------
for x in range(X0, W - 6):
    for y in (24, 25):
        old = get(x, y)
        put(x, y, "p" if old == "~" else "=")
    # aproximação limpa nas bordas da estrada
    for y in (23, 26):
        if get(x, y) in "~M":
            put(x, y, "g" if x >= 200 else "w")
for x in range(X0, W - 6):
    for y in (24, 25):
        if get(x, y) == "p" and (get(x - 1, y) not in "~p" and get(x + 1, y) not in "~p"):
            put(x, y, "=")

PRED = []   # (id, x, y, w, h)


def predio(x, y, w, h, porta_x, porta_y):
    rect_fill(x, y, w, h, "#")
    rect_fill(x + 1, y + 1, w - 2, h - 2, "_")
    put(porta_x, porta_y, "D")


# ---- 3) Junco Alto (palafitas sobre a água) ---------------------------------------------------------------
rect_fill(168, 14, 30, 22, "~")
for x in range(168, 198):          # passarelas
    put(x, 23, "p")
    put(x, 26, "p")
    for y in (24, 25):
        put(x, y, "p")
predio(172, 17, 9, 6, 176, 22)      # taberna do Sapo Manco
predio(183, 17, 7, 6, 186, 22)      # cabana da curandeira
predio(172, 27, 6, 5, 174, 27)      # casa do pescador
predio(180, 27, 6, 5, 182, 27)      # casa do caçador de crocodilos
predio(188, 27, 8, 5, 191, 27)      # palanque do ancião
put(166, 24, "="); put(166, 25, "=")
# poço e lamparinas
put(198, 26, "o")
# passagem de terra dos dois lados da ilha de palafitas
for y in (24, 25):
    for x in (166, 167, 198, 199):
        put(x, y, "=")

# trilha até o Altar Submerso (norte do brejo)
for y in range(8, 24):
    put(163, y, ":")
for x in range(163, 190):
    put(x, 8, ":")
rect_fill(184, 3, 12, 9, "w")
for (x, y) in ((185, 4), (186, 4), (194, 4), (195, 4), (185, 10), (195, 10)):
    put(x, y, "%")
rect_fill(188, 6, 4, 3, "g")   # laje do altar
put(189, 7, "o")                # pedra do altar (bloqueia)

# ---- 4) Posto Areia Dourada --------------------------------------------------------------------------------
rect_fill(204, 22, 38, 5, "=")                         # praça comprida
predio(209, 17, 10, 6, 213, 22)    # pousada do Camelo
predio(222, 17, 10, 6, 226, 22)    # bazar das mil tendas
predio(209, 27, 8, 6, 212, 27)     # filial da guilda
predio(220, 27, 7, 6, 223, 27)     # armaria do deserto
predio(230, 27, 6, 5, 232, 27)     # casa da curandeira do deserto
put(218, 26, "o")                  # poço
# oásis
for y in range(34, 44):
    for x in range(222, 238):
        if ((x - 230) / 7.5) ** 2 + ((y - 39) / 4.5) ** 2 <= 1.0:
            put(x, y, "~")
for (x, y) in ((220, 38), (221, 41), (238, 37), (237, 42), (229, 33), (232, 45), (225, 45)):
    put(x, y, "T")

# ---- 5) Forte Caído ----------------------------------------------------------------------------------------
FX, FY, FW, FH = 222, 3, 16, 12
rect_fill(FX, FY, FW, FH, "#")
rect_fill(FX + 1, FY + 1, FW - 2, FH - 2, "_")
for (x, y, w, h) in ((FX + 5, FY + 1, 1, 5), (FX + 10, FY + 5, 1, 5), (FX + 1, FY + 6, 3, 1)):
    rect_fill(x, y, w, h, "#")
for (x, y) in ((FX + 3, FY + 3), (FX + 8, FY + 7), (FX + 12, FY + 3), (FX + 13, FY + 9), (FX + 2, FY + 9), (FX + 7, FY + 2)):
    put(x, y, "%")
# brechas nas muralhas (sul e oeste) e trilha até a estrada
for x in (FX + 4, FX + 5, FX + 6):
    put(x, FY + FH - 1, "%")
for y in (FY + 7, FY + 8):
    put(FX, y, "%")
for y in range(FY + FH, 22):
    put(FX + 5, y, ":")
# portão leste (tabuado)
put(FX + FW - 1, FY + 5, "D")
put(FX + FW - 1, FY + 6, "%")

# ---- 6) Rocha Negra -----------------------------------------------------------------------------------------
rect_fill(247, 22, 36, 5, "=")
predio(250, 17, 10, 6, 254, 22)    # alojamento dos mineiros
predio(262, 17, 9, 6, 266, 22)     # taverna da Picareta
predio(273, 17, 8, 6, 276, 22)     # forja anã
predio(250, 27, 7, 6, 253, 27)     # posto da guarda
predio(260, 27, 8, 6, 263, 27)     # casa da mina (escada)
predio(271, 27, 8, 6, 274, 27)     # capela de Khalmyr
put(259, 26, "o")                  # poço
put(264, 31, "S")                  # escada para as minas (dentro da casa)
# cumes ao norte com passagem e o Pico Rubro
for x in range(240, W):
    for y in range(0, 8):
        if vn(x, y, 5, 9) > 0.35:
            put(x, y, "M")
for y in range(6, 22):
    put(262, y, ":")
rect_fill(258, 2, 12, 5, "g")

# ---- 7) minas (subsolo) ------------------------------------------------------------------------------------
MX0, MX1 = 242, 284
rect_fill(MX0, 50, MX1 - MX0, 13, "#")
rect_fill(247, 52, 8, 9, "_")           # salão de entrada
rect_fill(255, 55, 6, 3, "_")           # galeria
rect_fill(261, 51, 10, 5, "_")          # ninho de aranhas
rect_fill(261, 57, 10, 5, "_")          # poço de gosmas
rect_fill(271, 55, 3, 3, "_")           # galeria
rect_fill(274, 52, 9, 9, "_")           # câmara do feitor
rect_fill(266, 55, 1, 3, "_")           # ligação entre os dois salões do meio
put(249, 56, "U")
for (x, y) in ((250, 54), (252, 59), (264, 53), (268, 60), (277, 55), (280, 58)):
    put(x, y, "%")
for y in range(49, ALTURA):
    for x in range(X0, W):
        if get(x, y) == " ":
            put(x, y, "X")

# ---- 8) limites do mapa e pontos livres ---------------------------------------------------------------------
for y in range(H):
    put(W - 1, y, "T")
for x in range(X0, W):
    put(x, 0, "T" if get(x, 0) != "M" else "M")
    put(x, H - 1, "T")
for (x, y) in ((176, 23), (186, 23), (174, 26), (182, 26), (191, 26), (213, 23), (226, 23), (212, 26), (223, 26), (232, 26),
               (254, 23), (266, 23), (276, 23), (253, 26), (263, 26), (274, 26)):
    if get(x, y) not in "p=":
        put(x, y, "=")

# ---- 9) juntar com o mapa e garantir alcance a pé --------------------------------------------------------
grid = [list(r) for r in m["grid"]]
for y in range(ALTURA):
    grid[y] += novo[y]
andavel = lambda c: m["legend"].get(c, {}).get("walk", False) or c in "wag"
for y in range(22, 27):      # abre o limite oeste (a mata fechava o mapa em x=159)
    grid[y][159] = "="
    grid[y][158] = "="
ini = tuple(m["player_start"])
# Escadas ligam a superfície à cripta e às minas: as duas pontas entram como ponto de partida (não são caminho a pé).
SEMENTES = [ini]
for _o in m.get("objects", []):
    if _o.get("type") == "stairs":
        SEMENTES.append(tuple(_o["tile"]))
        SEMENTES.append(tuple(_o["to"]))
vistos = set(SEMENTES)
fila = deque(SEMENTES)
while fila:
    x, y = fila.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (x + dx, y + dy)
        if 0 <= n[0] < W and 0 <= n[1] < H and n not in vistos and andavel(grid[n[1]][n[0]]):
            vistos.add(n)
            fila.append(n)
for y in range(H):
    for x in range(X0, W):
        if andavel(grid[y][x]) and (x, y) not in vistos:
            grid[y][x] = "T"
prev = ["".join(r) for r in grid]

if "--aplicar" not in sys.argv:
    for r in prev[:H]:
        print(r[150:])
    for r in prev[49:]:
        print(r[236:])
    sys.exit(0)

m["grid"] = prev
m["size"] = [W, len(prev)]
m["legend"].update({
    "w": {"name": "lama", "walk": True, "difficult": True, "natural": True, "solo": "macio"},
    "a": {"name": "areia", "walk": True, "natural": True, "solo": "macio"},
    "g": {"name": "cascalho", "walk": True, "natural": True, "solo": "comum"},
    "M": {"name": "rocha", "walk": False, "cover": True, "natural": True, "solo": "comum"},
})


def porta(id_, nome, x, y):
    return {"id": id_, "type": "door", "tile": [x, y], "open": False, "locked": False, "name": nome,
            "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239 Tabela 5-4 porta de madeira", "tamanho": "Grande"}}


for z in m["zones"]:
    if z["id"] == "pedrabranca":
        z["rect"] = [136, 0, 24, 49]
m["zones"] += [
    {"id": "brejo", "rect": [160, 0, 40, 49]},
    {"id": "deserto", "rect": [200, 0, 40, 49]},
    {"id": "forte", "rect": [FX, FY, FW, FH]},
    {"id": "rocha", "rect": [240, 0, 48, 49]},
    {"id": "pico", "rect": [256, 0, 30, 10]},
    {"id": "cripta", "rect": [MX0, 50, MX1 - MX0, 13]},     # as minas: subsolo (mesma regra da cripta)
]
L = m["locations"]


def edificio(id_, nome, zona, x, y, w, h, madeira=True, extra=None):
    d = {"id": id_, "name": nome, "zone": zona, "rect": [x + 1, y + 1, w - 2, h - 2], "spot": [x + w // 2, y + h // 2], "indoor": True}
    if madeira:
        d["parede_madeira"] = True
    if extra:
        d.update(extra)
    L.append(d)


edificio("taberna_sapo", "Taberna do Sapo Manco", "brejo", 172, 17, 9, 6)
edificio("cabana_curandeira", "Cabana da Curandeira", "brejo", 183, 17, 7, 6)
edificio("casa_pescador", "Casa do Pescador", "brejo", 172, 27, 6, 5)
edificio("casa_cacador_croc", "Casa do Caçador de Crocodilos", "brejo", 180, 27, 6, 5)
edificio("palanque_anciao", "Palanque do Ancião", "brejo", 188, 27, 8, 5)
L += [
    {"id": "passarela_junco", "name": "Passarelas de Junco Alto", "zone": "brejo", "rect": [168, 23, 30, 4], "spot": [182, 24]},
    {"id": "brejo_norte", "name": "Trilha do Altar", "zone": "brejo", "rect": [162, 8, 24, 16], "spot": [170, 8]},
    {"id": "altar_submerso", "name": "Altar Submerso", "zone": "brejo", "rect": [184, 3, 12, 9], "spot": [190, 8]},
    {"id": "pousada_camelo", "name": "Pousada do Camelo", "zone": "deserto", "rect": [210, 18, 8, 4], "spot": [214, 20], "indoor": True, "parede_madeira": True},
    {"id": "bazar_tendas", "name": "Bazar das Mil Tendas", "zone": "deserto", "rect": [223, 18, 8, 4], "spot": [227, 20], "indoor": True, "parede_madeira": True},
    {"id": "guilda_filial", "name": "Filial da Guilda de Areia Dourada", "zone": "deserto", "rect": [210, 28, 6, 4], "spot": [213, 30], "indoor": True},
    {"id": "armaria_deserto", "name": "Armaria do Deserto", "zone": "deserto", "rect": [221, 28, 5, 4], "spot": [223, 30], "indoor": True},
    {"id": "casa_curandeira_d", "name": "Tenda da Curandeira", "zone": "deserto", "rect": [231, 28, 4, 3], "spot": [233, 29], "indoor": True, "parede_madeira": True},
    {"id": "praca_areia", "name": "Posto Areia Dourada", "zone": "deserto", "rect": [204, 22, 38, 5], "spot": [222, 24]},
    {"id": "oasis", "name": "Oásis Miragem", "zone": "deserto", "rect": [222, 34, 16, 10], "spot": [230, 33]},
    {"id": "forte_caido", "name": "Forte Caído", "zone": "forte", "rect": [FX + 1, FY + 1, FW - 2, FH - 2], "spot": [FX + 8, FY + 5], "indoor": False},
    {"id": "alojamento_mineiros", "name": "Alojamento dos Mineiros", "zone": "rocha", "rect": [251, 18, 8, 4], "spot": [255, 20], "indoor": True, "parede_madeira": True},
    {"id": "taverna_picareta", "name": "Taverna da Picareta", "zone": "rocha", "rect": [263, 18, 7, 4], "spot": [266, 20], "indoor": True, "parede_madeira": True},
    {"id": "forja_ana", "name": "Forja Anã de Rocha Negra", "zone": "rocha", "rect": [274, 18, 6, 4], "spot": [277, 20], "indoor": True},
    {"id": "posto_guarda_rn", "name": "Posto da Guarda de Rocha Negra", "zone": "rocha", "rect": [251, 28, 5, 4], "spot": [253, 30], "indoor": True},
    {"id": "casa_mina", "name": "Casa da Mina", "zone": "rocha", "rect": [261, 28, 6, 4], "spot": [264, 30], "indoor": True},
    {"id": "capela_khalmyr", "name": "Capela de Khalmyr", "zone": "rocha", "rect": [272, 28, 6, 4], "spot": [275, 30], "indoor": True, "simbolo_divindade": "Khalmyr"},
    {"id": "praca_rocha", "name": "Praça de Rocha Negra", "zone": "rocha", "rect": [247, 22, 36, 5], "spot": [264, 24]},
    {"id": "pico_rubro", "name": "Pico Rubro", "zone": "pico", "rect": [258, 2, 12, 5], "spot": [264, 4]},
    {"id": "mina_salao", "name": "Salão de Entrada das Minas", "zone": "cripta", "rect": [247, 52, 8, 9], "spot": [250, 56], "indoor": True},
    {"id": "mina_ninho", "name": "Ninho das Minas", "zone": "cripta", "rect": [261, 51, 10, 5], "spot": [265, 53], "indoor": True},
    {"id": "mina_poco", "name": "Poço de Gosma", "zone": "cripta", "rect": [261, 57, 10, 5], "spot": [265, 59], "indoor": True},
    {"id": "mina_feitor", "name": "Câmara do Feitor", "zone": "cripta", "rect": [274, 52, 9, 9], "spot": [278, 56], "indoor": True},
]
m["objects"] += [
    porta("porta_taberna_sapo", "Porta (Taberna do Sapo Manco)", 176, 22),
    porta("porta_cabana_curandeira", "Porta (Cabana da Curandeira)", 186, 22),
    porta("porta_casa_pescador", "Porta (Casa do Pescador)", 174, 27),
    porta("porta_casa_cacador_croc", "Porta (Casa do Caçador de Crocodilos)", 182, 27),
    porta("porta_palanque", "Porta (Palanque do Ancião)", 191, 27),
    porta("porta_pousada_camelo", "Porta (Pousada do Camelo)", 213, 22),
    porta("porta_bazar", "Porta (Bazar das Mil Tendas)", 226, 22),
    porta("porta_guilda_filial", "Porta (Filial da Guilda)", 212, 27),
    porta("porta_armaria", "Porta (Armaria do Deserto)", 223, 27),
    porta("porta_curandeira_d", "Porta (Tenda da Curandeira)", 232, 27),
    porta("porta_alojamento", "Porta (Alojamento dos Mineiros)", 254, 22),
    porta("porta_picareta", "Porta (Taverna da Picareta)", 266, 22),
    porta("porta_forja_ana", "Porta (Forja Anã)", 276, 22),
    porta("porta_posto_rn", "Porta (Posto da Guarda)", 253, 27),
    porta("porta_casa_mina", "Porta (Casa da Mina)", 263, 27),
    porta("porta_capela", "Porta (Capela de Khalmyr)", 274, 27),
    {"id": "portao_forte", "type": "door", "tile": [FX + FW - 1, FY + 5], "open": False, "locked": True, "name": "Portão tabuado do Forte Caído",
     "break": {"defesa": 8, "rd": 5, "pv": 30, "rule": "LB p.239 Tabela 5-4 porta de madeira reforçada", "tamanho": "Grande"}},
    {"id": "poco_junco", "type": "well", "tile": [198, 26], "name": "Poço de Junco Alto"},
    {"id": "poco_areia", "type": "well", "tile": [218, 26], "name": "Poço do Posto"},
    {"id": "poco_rocha", "type": "well", "tile": [259, 26], "name": "Poço de Rocha Negra"},
    {"id": "escada_mina", "type": "stairs", "tile": [264, 31], "to": [250, 56], "name": "Escada para as Minas"},
    {"id": "escada_mina_sobe", "type": "stairs", "tile": [249, 56], "to": [264, 30], "name": "Escada para a superfície"},
    {"id": "bau_altar", "type": "chest", "tile": [190, 7], "open": False, "locked": False, "name": "Baú coberto de limo", "contents": ["amuleto_serpente", "pocao_cura"]},
    {"id": "bau_forte", "type": "chest", "tile": [FX + 12, FY + 9], "open": False, "locked": True, "name": "Baú do intendente", "contents": ["espada_longa", "pocao_cura", "pocao_cura"]},
    {"id": "bau_mina", "type": "chest", "tile": [281, 54], "open": False, "locked": False, "name": "Baú do feitor", "contents": ["cota_malha", "minerio_negro", "minerio_negro"]},
    {"id": "estatua_khalmyr", "type": "prop", "tile": [275, 29], "name": "Estátua de Khalmyr", "escultura": True},
]
json.dump(m, open(MAPA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("mapa estendido para", m["size"])
