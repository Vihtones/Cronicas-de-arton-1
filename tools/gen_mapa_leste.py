#!/usr/bin/env python3
"""Estende data/world/map.json para leste (x 96..159): serra, lago, rio com ponte e o povoado de Pedra Branca.
Uso: python3 tools/gen_mapa_leste.py [--aplicar]   (sem a flag, só mostra a prévia em ASCII). Idempotente: só roda se o mapa ainda tem 96 colunas."""
import json, random, sys, copy

MAPA = "data/world/map.json"
X0, W, H = 96, 160, 49   # linhas 0..48 são a área aberta; 49 e adiante são a cripta (X de borda)
rng = random.Random(20261027)
m = json.load(open(MAPA, encoding="utf-8"))
if len(m["grid"][0]) != 96:
    sys.exit("o mapa já foi estendido")

novo = [[" "] * (W - X0) for _ in range(H)]


def put(x, y, ch):
    if X0 <= x < W and 0 <= y < H:
        novo[y][x - X0] = ch


def get(x, y):
    return novo[y][x - X0]


def rect_fill(x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(xx, yy, ch)


# 1) base: floresta que vira serra de grama e árvores esparsas
for y in range(H):
    for x in range(X0, W):
        c = x - X0
        r = rng.random()
        if c < 14:   # continuação do Bosque Sombrio
            put(x, y, "T" if r < 0.24 else ("," if r < 0.92 else "."))
        elif c < 40:   # serra: campo aberto
            put(x, y, "T" if r < 0.07 else (":" if r < 0.09 else "."))
        else:   # povoado: grama e pomar ralo
            put(x, y, "T" if r < 0.03 else ".")

# 2) cumes (barranco): duas cristas com uma passagem na estrada
for x in range(112, 134):
    for y in range(0, 6):
        put(x, y, "B" if rng.random() < 0.85 else "T")
    for y in range(41, 50):
        put(x, y, "B" if rng.random() < 0.85 else "T")

# 3) lago ao norte da estrada e rio que desce até a borda sul
cx, cy, rx, ry = 122, 12, 9, 5
for y in range(H):
    for x in range(X0, W):
        if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
            put(x, y, "~")
for y in range(cy, H):
    wob = 1 if (y // 5) % 2 else 0
    put(130 + wob, y, "~")
    put(131 + wob, y, "~")
# 4) estrada leste (2 de largura, linhas 24-25) e ponte sobre o rio
for x in range(X0, 148):
    put(x, 24, "=")
    put(x, 25, "=")
for y in (24, 25):
    for x in range(129, 134):
        if get(x, y) == "~":
            put(x, y, "p")
# 5) trilha da estrada ao cais, cais sobre o lago
for y in range(17, 24):
    put(123, y, ":")
for y in range(14, 19):
    put(123, y, "p")
# 6) praça de Pedra Branca
rect_fill(144, 22, 14, 5, "=")
put(150, 27, "o")   # poço


def predio(x, y, w, h, porta_x, porta_y):
    rect_fill(x, y, w, h, "#")
    rect_fill(x + 1, y + 1, w - 2, h - 2, "_")
    put(porta_x, porta_y, "D")


predio(138, 17, 9, 6, 142, 22)   # estalagem
predio(149, 17, 7, 6, 152, 22)   # entreposto
predio(138, 28, 6, 4, 140, 28)   # casa do barqueiro
predio(148, 29, 5, 6, 150, 29)   # torre de vigia (porta voltada para a praça)
# 7) campos ao sul e limite do mapa
rect_fill(137, 37, 20, 9, "c")
for y in range(H):
    put(W - 1, y, "T")
for x in range(X0, W):
    put(x, 0, "T" if get(x, 0) != "B" else "B")
    put(x, H - 1, "T")
# livrar o entorno das portas
for (x, y) in ((142, 23), (152, 23), (140, 27), (150, 28)):
    put(x, y, "=" if get(x, y) not in "p" else get(x, y))

# 8) montar linhas novas
grid = [list(r) for r in m["grid"]]
for y in range(H):
    grid[y] += novo[y]
for y in range(H, len(grid)):
    grid[y] += ["X"] * (W - X0)
# 8b) bolsões fechados pela mata (4 vizinhos) viram árvore: toda a superfície tem de ser alcançável a pé
from collections import deque
andavel = lambda c: m["legend"].get(c, {}).get("walk", False)
ini = tuple(m["player_start"])
vistos = {ini}
fila = deque([ini])
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
        print(r[88:])
    sys.exit(0)

m["grid"] = prev
m["size"] = [W, len(prev)]


def porta(id_, nome, x, y, extra=None):
    return {"id": id_, "type": "door", "tile": [x, y], "open": False, "locked": False, "name": nome,
            "break": {"defesa": 8, "rd": 5, "pv": 20, "rule": "LB p.239 Tabela 5-4 porta de madeira", "tamanho": "Grande"}}


m["zones"] = [z for z in m["zones"]]
for z in m["zones"]:
    if z["id"] == "estrada":
        z["rect"] = [44, 22, 104, 6]
m["zones"] += [{"id": "serra", "rect": [96, 0, 40, 49]}, {"id": "pedrabranca", "rect": [136, 0, 24, 49]}]
L = m["locations"]
L += [
    {"id": "ponte_pequena", "name": "Ponte do Riacho Frio", "zone": "serra", "rect": [128, 23, 6, 4], "spot": [131, 24]},
    {"id": "lago", "name": "Lago Espelho", "zone": "serra", "rect": [113, 7, 19, 11], "spot": [123, 19]},
    {"id": "cais", "name": "Cais do Lago", "zone": "serra", "rect": [122, 14, 3, 5], "spot": [123, 19]},
    {"id": "estalagem", "name": "Estalagem da Ponte Velha", "zone": "pedrabranca", "rect": [138, 17, 9, 6], "spot": [142, 20], "indoor": True, "parede_madeira": True},
    {"id": "entreposto", "name": "Entreposto de Pedra Branca", "zone": "pedrabranca", "rect": [149, 17, 7, 6], "spot": [152, 20], "indoor": True, "parede_madeira": True},
    {"id": "casa_barqueiro", "name": "Casa do Barqueiro", "zone": "pedrabranca", "rect": [138, 28, 6, 4], "spot": [140, 30], "indoor": True, "parede_madeira": True},
    {"id": "torre_vigia", "name": "Torre de Vigia", "zone": "pedrabranca", "rect": [148, 29, 5, 6], "spot": [150, 32], "indoor": True},
    {"id": "praca_pedrabranca", "name": "Praça de Pedra Branca", "zone": "pedrabranca", "rect": [144, 22, 14, 6], "spot": [150, 25]},
    {"id": "campos_pedrabranca", "name": "Campos de Pedra Branca", "zone": "pedrabranca", "rect": [137, 37, 20, 9], "spot": [146, 36]},
]
m["objects"] += [
    porta("porta_estalagem", "Porta (Estalagem da Ponte Velha)", 142, 22),
    porta("porta_entreposto", "Porta (Entreposto de Pedra Branca)", 152, 22),
    porta("porta_barqueiro", "Porta (Casa do Barqueiro)", 140, 28),
    porta("porta_torre", "Porta (Torre de Vigia)", 150, 29),
    {"id": "poco_pedrabranca", "type": "well", "tile": [150, 27], "name": "Poço de Pedra Branca"},
]
json.dump(m, open(MAPA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("mapa estendido para", m["size"])
