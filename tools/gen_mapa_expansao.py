#!/usr/bin/env python3
"""Acrescenta ao mapa, SEM deslocar nenhuma coordenada existente (ORIGINAL_DO_JOGO):
  - Horizonte (leste, x 288..335): a estrada da Fronteira continua até o Entreposto do Horizonte, com lago e colinas.
  - Vale do Sul (sul, linhas 64..95, x 200..240): entrada por uma trilha que desce do deserto (x 220, linhas 47..63),
    com a Aldeia do Vale e a mata em volta.
Uso: python3 tools/gen_mapa_expansao.py [--aplicar]   (sem a flag só mostra a prévia). Idempotente: só roda se o mapa tem 288 colunas.
"""
import json, random, sys
from collections import deque

MAPA = "data/world/map.json"
m = json.load(open(MAPA, encoding="utf-8"))
W0, H0 = len(m["grid"][0]), len(m["grid"])
if W0 != 288:
    sys.exit("o mapa já foi expandido (esperado 288 colunas, achei %d)" % W0)
W1, H1 = 336, 96
rng = random.Random(20261028)
grid = [list(r) for r in m["grid"]]

# 1) Preencher o que é novo: colunas à direita e linhas abaixo, sempre 'X' (vazio) até ser desenhado.
for y in range(H0):
    grid[y] += ["X"] * (W1 - W0)
for y in range(H0, H1):
    grid.append(["X"] * W1)


# a borda antiga (x=287) bloqueava a ligação leste; abre-se a costura onde o terreno continua
for y in range(49):
    if grid[y][287] == "T":
        grid[y][287] = "."
grid[24][287] = "="
grid[25][287] = "="


def put(x, y, ch):
    if 0 <= x < W1 and 0 <= y < H1:
        grid[y][x] = ch


def get(x, y):
    return grid[y][x]


def rect(x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, ch)


def predio(x, y, w, h, px, py):
    rect(x, y, w, h, "#")
    rect(x + 1, y + 1, w - 2, h - 2, "_")
    put(px, py, "D")


# 2) HORIZONTE (leste): terreno aberto com colinas, lago e bosque.
for y in range(0, 49):
    for x in range(288, W1 - 1):
        r = rng.random()
        n = (x * 7 + y * 13) % 17
        if n < 3 and r < 0.4:
            put(x, y, "M")
        elif r < 0.12:
            put(x, y, "T")
        elif r < 0.2:
            put(x, y, ",")
        else:
            put(x, y, ".")
for x in range(288, W1 - 1):   # a estrada da Fronteira segue até o horizonte
    put(x, 24, "=")
    put(x, 25, "=")
rect(302, 8, 14, 7, "~")       # lago
rect(300, 4, 18, 3, "T")       # bosque ao norte do lago
rect(312, 30, 16, 9, "c")      # plantação ao sul da estrada
predio(296, 17, 9, 6, 300, 22)   # Estalagem do Horizonte
predio(309, 17, 9, 6, 313, 22)   # Armazém do Horizonte
predio(322, 17, 8, 6, 325, 22)   # Oficina de carroças
predio(296, 27, 7, 5, 298, 27)   # Casa do guia
predio(306, 27, 6, 5, 308, 27)   # Casa do ferreiro de estrada
rect(296, 22, 36, 5, "=")          # praça (sobrepõe a estrada)
put(316, 26, "o")                  # poço
for y in range(0, H1):
    put(W1 - 1, y, "T")

# 3) VALE DO SUL (sul): trilha do deserto e aldeia abaixo da linha 48.
for y in range(47, 64):        # trilha que desce do deserto
    put(220, y, ":")
    put(221, y, ":")
rect(200, 49, 41, 47, ".")     # terreno do vale
for y in range(49, 96):
    for x in range(200, 241):
        r = rng.random()
        if (x * 5 + y * 11) % 19 < 2 and r < 0.6:
            put(x, y, "M")
        elif r < 0.14:
            put(x, y, "T")
        elif r < 0.22:
            put(x, y, ",")
rect(212, 81, 16, 6, "~")       # riacho e poça do vale
rect(218, 66, 3, 3, "=")        # praça da aldeia
predio(204, 60, 9, 6, 208, 65)  # Taverna do Vale Fundo
predio(215, 58, 8, 6, 218, 63)  # Casa da anciã
predio(227, 60, 9, 6, 231, 65)  # Armazém da aldeia
predio(206, 72, 7, 5, 208, 72)  # Casa dos caçadores
predio(224, 72, 7, 5, 226, 72)  # Ferreiro do vale
put(219, 70, "o")               # poço
rect(200, 50, 1, 45, "T")       # borda oeste do vale
rect(240, 50, 1, 45, "T")       # borda leste do vale
rect(200, 95, 41, 1, "T")       # borda sul
for x in range(W1):
    put(x, 95, "T")

# 4) Caminho a pé: tudo que é andável e não é alcançável a partir do início vira mata (igual à Fronteira).
ANDAVEL = dict(m["legend"])
ANDAVEL.update({"w": {"walk": True}, "a": {"walk": True}, "g": {"walk": True}})
ANDAVEL.update({"M": {"walk": False}})
ini = tuple(m["player_start"])


def andavel(c):
    return bool(ANDAVEL.get(c, {}).get("walk", False))


# Escadas ligam a superfície à cripta e às minas: as duas pontas entram como ponto de partida.
SEMENTES = [ini] + [tuple(o["tile"]) for o in m.get("objects", []) if o.get("type") == "stairs"] + \
    [tuple(o["to"]) for o in m.get("objects", []) if o.get("type") == "stairs"]
vistos = set(SEMENTES)
fila = deque(SEMENTES)
while fila:
    x, y = fila.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (x + dx, y + dy)
        if 0 <= n[0] < W1 and 0 <= n[1] < H1 and n not in vistos and andavel(grid[n[1]][n[0]]):
            vistos.add(n)
            fila.append(n)
isolados = 0
for y in range(H1):
    for x in range(W1):
        if andavel(grid[y][x]) and (x, y) not in vistos:
            grid[y][x] = "T"
            isolados += 1
print("isolados virados em mata:", isolados, "| alcançáveis:", len(vistos))
prev = ["".join(r) for r in grid]

if "--aplicar" not in sys.argv:
    for r in prev[:H1:2]:
        print(r[190:])
    sys.exit(0)

m["grid"] = prev
m["size"] = [W1, H1]
m["zones"] += [
    {"id": "horizonte", "rect": [288, 0, 48, 49]},
    {"id": "vale_sul", "rect": [200, 49, 41, 47]},
]
m["locations"] += [
    {"id": "estalagem_horizonte", "name": "Estalagem do Horizonte", "zone": "horizonte", "rect": [297, 18, 7, 4], "spot": [300, 20], "indoor": True, "parede_madeira": True},
    {"id": "armazem_horizonte", "name": "Armazém do Horizonte", "zone": "horizonte", "rect": [310, 18, 7, 4], "spot": [313, 20], "indoor": True, "parede_madeira": True},
    {"id": "oficina_carrocas", "name": "Oficina de Carroças", "zone": "horizonte", "rect": [323, 18, 6, 4], "spot": [325, 20], "indoor": True},
    {"id": "casa_guia", "name": "Casa do Guia", "zone": "horizonte", "rect": [297, 28, 5, 3], "spot": [299, 29], "indoor": True, "parede_madeira": True},
    {"id": "casa_ferreiro_estrada", "name": "Casa do Ferreiro da Estrada", "zone": "horizonte", "rect": [307, 28, 4, 3], "spot": [308, 29], "indoor": True},
    {"id": "praca_horizonte", "name": "Praça do Horizonte", "zone": "horizonte", "rect": [296, 22, 36, 5], "spot": [314, 24]},
    {"id": "lago_horizonte", "name": "Lago do Horizonte", "zone": "horizonte", "rect": [302, 8, 14, 7], "spot": [309, 12]},
    {"id": "taverna_vale", "name": "Taverna do Vale Fundo", "zone": "vale_sul", "rect": [205, 61, 7, 4], "spot": [208, 63], "indoor": True, "parede_madeira": True},
    {"id": "casa_anciao", "name": "Casa da Anciã", "zone": "vale_sul", "rect": [216, 59, 6, 4], "spot": [218, 61], "indoor": True},
    {"id": "armazem_vale", "name": "Armazém da Aldeia", "zone": "vale_sul", "rect": [228, 61, 7, 4], "spot": [231, 63], "indoor": True, "parede_madeira": True},
    {"id": "casa_cacadores", "name": "Casa dos Caçadores", "zone": "vale_sul", "rect": [207, 73, 5, 3], "spot": [209, 74], "indoor": True},
    {"id": "ferreiro_vale", "name": "Ferreiro do Vale", "zone": "vale_sul", "rect": [225, 73, 5, 3], "spot": [227, 74], "indoor": True},
    {"id": "praca_vale", "name": "Praça da Aldeia do Vale", "zone": "vale_sul", "rect": [218, 66, 3, 3], "spot": [219, 67]},
]
for pid, nome, x, y in [("porta_estalagem_horizonte", "Porta (Estalagem do Horizonte)", 300, 22),
                        ("porta_armazem_horizonte", "Porta (Armazém do Horizonte)", 313, 22),
                        ("porta_oficina", "Porta (Oficina de Carroças)", 325, 22),
                        ("porta_casa_guia", "Porta (Casa do Guia)", 298, 27),
                        ("porta_ferreiro_estrada", "Porta (Ferreiro da Estrada)", 308, 27),
                        ("porta_taverna_vale", "Porta (Taverna do Vale Fundo)", 208, 65),
                        ("porta_casa_anciao", "Porta (Casa da Anciã)", 218, 63),
                        ("porta_armazem_vale", "Porta (Armazém da Aldeia)", 231, 65),
                        ("porta_casa_cacadores", "Porta (Casa dos Caçadores)", 208, 72),
                        ("porta_ferreiro_vale", "Porta (Ferreiro do Vale)", 226, 72)]:
    m["objects"].append({"id": pid, "type": "door", "tile": [x, y], "open": False, "locked": False, "name": nome,
                         "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239 Tabela 5-4 porta de madeira", "tamanho": "Grande"}})
m["objects"].append({"id": "poco_horizonte", "type": "well", "tile": [316, 26], "name": "Poço do Horizonte"})
m["objects"].append({"id": "poco_vale", "type": "well", "tile": [219, 70], "name": "Poço do Vale"})
json.dump(m, open(MAPA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("mapa expandido para", m["size"])
