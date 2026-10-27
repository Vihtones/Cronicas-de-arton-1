"""Gera arte PROVISÓRIA original (pixel art 32x32) + manifesto (§13).
Estado: prototype. Licença: original do projeto. Substituir após aprovar a Art Bible em cena.
Uso: python3 tools/gen_placeholder_art.py"""
import hashlib, json, pathlib, random
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
A = ROOT / "assets"
T = 32
rnd = random.Random(7)

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

PAL = {  # paletas por bioma (Art Bible provisória)
 "grama": ["#4f8a3c", "#5e9b45", "#467d35", "#6fae52"], "estrada": ["#a58a5e", "#b39a6c", "#94784f", "#c2a97b"],
 "trilha": ["#8c7a4e", "#9b8858", "#7a6943"], "floresta": ["#2f5a2e", "#36673a", "#284f28", "#3f7442"],
 "agua": ["#2f6fa8", "#3a80bd", "#285f93", "#5c9fd6"], "pedra": ["#6d6a70", "#7d7a80", "#5c5a60", "#8e8b91"],
 "piso": ["#8a6a48", "#977452", "#7b5d3f"], "cripta": ["#4a4552", "#544e5d", "#403b47"], "plant": ["#8aa63c", "#9cb84a", "#6f8a2e", "#c8b050"],
}

def noise(img, x0, y0, cols, density=1.0, seed=0):
    r = random.Random(seed)
    for y in range(T):
        for x in range(T):
            c = cols[0] if r.random() > 0.35 * density else r.choice(cols[1:])
            img.putpixel((x0 + x, y0 + y), hexc(c))

def tile_grass(img, x0, s):
    noise(img, x0, 0, PAL["grama"], 1.0, s)
    r = random.Random(s + 99)
    for _ in range(6):
        x, y = r.randrange(2, 30), r.randrange(3, 30)
        img.putpixel((x0 + x, y), hexc("#7fc060")); img.putpixel((x0 + x, y - 1), hexc("#8fd070"))

def tile_road(img, x0, s): noise(img, x0, 0, PAL["estrada"], 1.2, s)
def tile_path(img, x0, s):
    tile_grass(img, x0, s)
    d = ImageDraw.Draw(img)
    r = random.Random(s)
    for y in range(T):
        w = 10 + r.randrange(-2, 3)
        for x in range(16 - w // 2, 16 + w // 2):
            img.putpixel((x0 + x, y), hexc(r.choice(PAL["trilha"])))
def tile_forest(img, x0, s): noise(img, x0, 0, PAL["floresta"], 1.0, s)
def tile_crop(img, x0, s):
    noise(img, x0, 0, ["#6b5435", "#5d4a2e", "#7a6040"], 1.0, s)
    for row in (4, 12, 20, 28):
        for x in range(2, 30, 3):
            img.putpixel((x0 + x, row), hexc(PAL["plant"][(x + row) % 3])); img.putpixel((x0 + x, row - 1), hexc(PAL["plant"][1]))
            if (x + row) % 7 == 0: img.putpixel((x0 + x, row - 2), hexc(PAL["plant"][3]))
def tile_tree(img, x0, s):
    tile_forest(img, x0, s)
    d = ImageDraw.Draw(img)
    d.rectangle([x0 + 14, 20, x0 + 18, 30], fill=hexc("#5a3b22")); d.point([(x0 + 15, 22), (x0 + 16, 26)], fill=hexc("#6e4a2c"))
    d.ellipse([x0 + 3, 1, x0 + 29, 24], fill=hexc("#1f4520"), outline=hexc("#123015"))
    d.ellipse([x0 + 6, 3, x0 + 24, 18], fill=hexc("#2d6330"))
    d.ellipse([x0 + 9, 5, x0 + 17, 12], fill=hexc("#3f8243"))
def tile_water(img, x0, s):
    noise(img, x0, 0, PAL["agua"], 0.8, s)
    for y in (6, 17, 27):
        for x in range(4 + s % 5, 28, 9):
            for k in range(4): img.putpixel((x0 + x + k, y), hexc("#8cc4ee"))
def tile_wall(img, x0, s):
    d = ImageDraw.Draw(img)
    d.rectangle([x0, 0, x0 + 31, 31], fill=hexc("#6a5a4e"))
    for row in range(0, 32, 8):
        off = 0 if (row // 8) % 2 == 0 else 8
        for x in range(-8 + off, 32, 16):
            d.rectangle([x0 + max(0, x), row, x0 + min(31, x + 14), row + 6], fill=hexc("#8a7564"), outline=hexc("#4a3e35"))
    d.rectangle([x0, 0, x0 + 31, 3], fill=hexc("#9b4a3a"))  # telhado/beirada
def tile_floor(img, x0, s):
    d = ImageDraw.Draw(img)
    for i in range(4):
        d.rectangle([x0, i * 8, x0 + 31, i * 8 + 7], fill=hexc(PAL["piso"][i % 3]), outline=hexc("#5e4430"))
def tile_crypt_floor(img, x0, s): noise(img, x0, 0, PAL["cripta"], 1.0, s)
def tile_rubble(img, x0, s):
    tile_crypt_floor(img, x0, s)
    d = ImageDraw.Draw(img); r = random.Random(s)
    for _ in range(7):
        x, y = r.randrange(2, 26), r.randrange(4, 26)
        d.polygon([(x0 + x, y + 5), (x0 + x + 3, y), (x0 + x + 7, y + 4), (x0 + x + 5, y + 7)], fill=hexc(r.choice(PAL["pedra"])), outline=hexc("#35323a"))
def tile_door(img, x0, s, open_=False):
    tile_floor(img, x0, s)
    d = ImageDraw.Draw(img)
    if open_:
        d.rectangle([x0 + 2, 2, x0 + 6, 30], fill=hexc("#6e4524"), outline=hexc("#3a2412"))
    else:
        d.rectangle([x0 + 3, 2, x0 + 28, 30], fill=hexc("#7a4e28"), outline=hexc("#3a2412"))
        for x in (9, 15, 21): d.line([x0 + x, 3, x0 + x, 29], fill=hexc("#5e3a1c"))
        d.rectangle([x0 + 22, 15, x0 + 24, 17], fill=hexc("#d8c060"))
def tile_stairs(img, x0, s, up=False):
    tile_crypt_floor(img, x0, s)
    d = ImageDraw.Draw(img)
    for i in range(5):
        c = 40 + i * 18 if not up else 130 - i * 18
        d.rectangle([x0 + 4, 4 + i * 5, x0 + 27, 8 + i * 5], fill=(c, c, c + 8, 255), outline=(25, 25, 30, 255))
def tile_well(img, x0, s):
    tile_road(img, x0, s)
    d = ImageDraw.Draw(img)
    d.ellipse([x0 + 4, 6, x0 + 28, 28], fill=hexc("#7d7a80"), outline=hexc("#3c3a40"))
    d.ellipse([x0 + 9, 11, x0 + 23, 23], fill=hexc("#1c2c4a"))
    d.line([x0 + 6, 4, x0 + 26, 4], fill=hexc("#5a3b22"), width=2)
def tile_void(img, x0, s): ImageDraw.Draw(img).rectangle([x0, 0, x0 + 31, 31], fill=(8, 6, 12, 255))
def tile_ruin_floor(img, x0, s):
    noise(img, x0, 0, ["#77736a", "#6a665e", "#827e74", "#5f6b4a"], 1.0, s)

def tile_ponte(img, x0, s):
    r = random.Random(s); d = ImageDraw.Draw(img)
    for i in range(4):   # tábuas horizontais
        y0 = i * 8
        d.rectangle([x0, y0, x0 + T - 1, y0 + 6], fill=hexc(r.choice(["#8a6a40", "#7d5f38", "#947348"])), outline=hexc("#4e3a22"))
        for _ in range(3): img.putpixel((x0 + r.randrange(1, T - 2), y0 + r.randrange(1, 6)), hexc("#6a5030"))
    d.rectangle([x0, 0, x0 + T - 1, 1], fill=hexc("#5a4328")); d.rectangle([x0, T - 2, x0 + T - 1, T - 1], fill=hexc("#5a4328"))
def tile_abismo(img, x0, s):
    r = random.Random(s)
    for y in range(T):
        for x in range(T): img.putpixel((x0 + x, y), hexc(r.choice(["#2b2420", "#241e1b", "#332a25", "#1d1816"])))
    for _ in range(3):
        x, y = r.randrange(2, 28), r.randrange(2, 28)
        for k in range(r.randrange(4, 9)): img.putpixel((x0 + x + k // 2, y + k), hexc("#4a3d34"))

TILES = [(".", "grama", tile_grass), ("=", "estrada", tile_road), (":", "trilha", tile_path), (",", "chao_floresta", tile_forest),
 ("c", "plantacao", tile_crop), ("T", "arvore", tile_tree), ("~", "rio", tile_water), ("#", "parede", tile_wall), ("_", "piso", tile_floor),
 ("%", "entulho", tile_rubble), ("D", "porta_fechada", lambda i, x, s: tile_door(i, x, s, False)), ("d", "porta_aberta", lambda i, x, s: tile_door(i, x, s, True)),
 ("S", "escada_desce", lambda i, x, s: tile_stairs(i, x, s, False)), ("U", "escada_sobe", lambda i, x, s: tile_stairs(i, x, s, True)),
 ("o", "poco", tile_well), ("X", "vazio", tile_void), ("k", "piso_cripta", tile_crypt_floor), ("r", "piso_ruina", tile_ruin_floor), ("p", "ponte", tile_ponte), ("B", "barranco", tile_abismo)]
VARIANTS = 3

def build_tileset():
    img = Image.new("RGBA", (T * len(TILES), T * VARIANTS), (0, 0, 0, 0))
    index = {}
    for i, (ch, name, fn) in enumerate(TILES):
        for v in range(VARIANTS):
            sub = Image.new("RGBA", (T * len(TILES), T), (0, 0, 0, 0))
            fn(sub, i * T, i * 31 + v * 7)
            img.paste(sub.crop((i * T, 0, i * T + T, T)), (i * T, v * T))
        index[ch] = {"col": i, "name": name}
    p = A / "tiles" / "tileset.png"; p.parent.mkdir(parents=True, exist_ok=True); img.save(p)
    return p, index

# ---------------- Personagens: 4 direções (linhas: baixo, esquerda, direita, cima) x 3 quadros ----------
def draw_human(d, ox, oy, direction, frame, c):
    skin, hair, shirt, pants, boots, accent = (hexc(c[k]) for k in ("skin", "hair", "shirt", "pants", "boots", "accent"))
    out = hexc("#1a1418")
    leg = [0, 2, -2][frame]
    bob = 1 if frame else 0
    # sombra
    d.ellipse([ox + 9, oy + 27, ox + 23, oy + 31], fill=(0, 0, 0, 70))
    # pernas
    d.rectangle([ox + 12, oy + 21 - bob, ox + 15, oy + 27 + (leg if leg > 0 else 0)], fill=pants, outline=out)
    d.rectangle([ox + 17, oy + 21 - bob, ox + 20, oy + 27 + (-leg if leg < 0 else 0)], fill=pants, outline=out)
    d.rectangle([ox + 12, oy + 26 + max(0, leg), ox + 15, oy + 28 + max(0, leg)], fill=boots)
    d.rectangle([ox + 17, oy + 26 + max(0, -leg), ox + 20, oy + 28 + max(0, -leg)], fill=boots)
    # tronco
    d.rectangle([ox + 10, oy + 13 - bob, ox + 22, oy + 22 - bob], fill=shirt, outline=out)
    d.rectangle([ox + 10, oy + 19 - bob, ox + 22, oy + 20 - bob], fill=accent)
    # braços
    arm = [0, -1, 1][frame]
    d.rectangle([ox + 7, oy + 14 - bob + arm, ox + 9, oy + 21 - bob + arm], fill=shirt, outline=out)
    d.rectangle([ox + 23, oy + 14 - bob - arm, ox + 25, oy + 21 - bob - arm], fill=shirt, outline=out)
    # cabeça
    d.rectangle([ox + 11, oy + 4 - bob, ox + 21, oy + 13 - bob], fill=skin, outline=out)
    if direction == 3:
        d.rectangle([ox + 11, oy + 3 - bob, ox + 21, oy + 11 - bob], fill=hair, outline=out)
    else:
        d.rectangle([ox + 11, oy + 3 - bob, ox + 21, oy + 6 - bob], fill=hair, outline=out)
        if direction == 0:
            d.point([(ox + 14, oy + 9 - bob), (ox + 18, oy + 9 - bob)], fill=out)
        elif direction == 1:
            d.point([(ox + 13, oy + 9 - bob)], fill=out); d.rectangle([ox + 19, oy + 4 - bob, ox + 21, oy + 10 - bob], fill=hair)
        else:
            d.point([(ox + 19, oy + 9 - bob)], fill=out); d.rectangle([ox + 11, oy + 4 - bob, ox + 13, oy + 10 - bob], fill=hair)

def draw_weapon(d, ox, oy, direction, frame):
    blade, hilt = hexc("#cfd6dc"), hexc("#6a4a2a")
    if direction in (0, 2):
        d.line([ox + 25, oy + 20, ox + 28, oy + 8], fill=blade, width=2); d.line([ox + 23, oy + 20, ox + 27, oy + 20], fill=hilt, width=1)
    elif direction == 1:
        d.line([ox + 7, oy + 20, ox + 4, oy + 8], fill=blade, width=2)

def draw_hyena(d, ox, oy, direction, frame, c):
    fur, spot, out = hexc("#a68b5b"), hexc("#5e4a2f"), hexc("#1a1418")
    leg = [0, 2, -2][frame]
    d.ellipse([ox + 5, oy + 26, ox + 27, oy + 31], fill=(0, 0, 0, 70))
    if direction in (1, 2):
        flip = direction == 1
        def X(x): return ox + (31 - x if flip else x)
        d.polygon([(X(6), oy + 14), (X(24), oy + 12), (X(26), oy + 20), (X(8), oy + 22)], fill=fur, outline=out)
        for lx, sh in ((9, leg), (13, -leg), (20, leg), (23, -leg)):
            d.line([X(lx), oy + 21, X(lx), oy + 28 + sh // 2], fill=spot, width=2)
        d.polygon([(X(23), oy + 9), (X(30), oy + 12), (X(28), oy + 17), (X(22), oy + 16)], fill=fur, outline=out)
        d.point([(X(27), oy + 12)], fill=hexc("#e8d040"))
        for sx in (11, 15, 19): d.point([(X(sx), oy + 16), (X(sx + 1), oy + 18)], fill=spot)
    else:
        d.ellipse([ox + 9, oy + 10, ox + 23, oy + 26], fill=fur, outline=out)
        d.rectangle([ox + 11, oy + 24, ox + 13, oy + 29 + leg // 2], fill=spot); d.rectangle([ox + 19, oy + 24, ox + 21, oy + 29 - leg // 2], fill=spot)
        if direction == 0:
            d.ellipse([ox + 11, oy + 5, ox + 21, oy + 15], fill=fur, outline=out)
            d.point([(ox + 14, oy + 9), (ox + 18, oy + 9)], fill=hexc("#e8d040"))

CHARS = {
 "player":    {"skin": "#e0b48c", "hair": "#4a2e1a", "shirt": "#3c5a8c", "pants": "#4a3a2a", "boots": "#2a1e14", "accent": "#c8a040", "weapon": True},
 "aldeao":    {"skin": "#d8a880", "hair": "#6a4a2a", "shirt": "#8a7a50", "pants": "#5a4a3a", "boots": "#3a2a1a", "accent": "#6a5a3a"},
 "artesao":   {"skin": "#c89870", "hair": "#2a1a10", "shirt": "#7a3a2a", "pants": "#3a3a3a", "boots": "#222222", "accent": "#a08050"},
 "guarda":    {"skin": "#e0b48c", "hair": "#8a6a3a", "shirt": "#5a6a7a", "pants": "#3a4050", "boots": "#202020", "accent": "#b0b8c0", "weapon": True},
 "sacerdote": {"skin": "#f0c8a0", "hair": "#d8d0c0", "shirt": "#e8e8f0", "pants": "#c8c8d8", "boots": "#8a8aa0", "accent": "#b0c8e8"},
 "crianca":   {"skin": "#f0c09a", "hair": "#a05a2a", "shirt": "#6aa05a", "pants": "#5a6a8a", "boots": "#3a2a1a", "accent": "#e0d080"},
 "idoso":     {"skin": "#d0a888", "hair": "#c8c8c8", "shirt": "#6a5a7a", "pants": "#4a4a4a", "boots": "#2a2a2a", "accent": "#8a7a9a"},
 "bandido":   {"skin": "#c8a080", "hair": "#2a2a2a", "shirt": "#5a5a5a", "pants": "#3a3030", "boots": "#1a1a1a", "accent": "#8a2a2a", "weapon": True},
 "kael":      {"skin": "#b89070", "hair": "#1a1a1a", "shirt": "#4a4a50", "pants": "#2a2a30", "boots": "#101010", "accent": "#c03030", "weapon": True},
 "hiena":     {"hyena": True},
}

def build_chars():
    out = {}
    for name, c in CHARS.items():
        img = Image.new("RGBA", (T * 3, T * 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for direction in range(4):
            for frame in range(3):
                ox, oy = frame * T, direction * T
                if c.get("hyena"):
                    draw_hyena(d, ox, oy, direction, frame, c)
                else:
                    draw_human(d, ox, oy, direction, frame, c)
                    if c.get("weapon"): draw_weapon(d, ox, oy, direction, frame)
        p = A / "chars" / f"{name}.png"; p.parent.mkdir(parents=True, exist_ok=True); img.save(p)
        out[name] = p
    return out

ICONS = ["mover", "atacar", "investida", "especial", "fim_turno", "levantar", "misericordia", "furtivo"]
def build_icons():
    img = Image.new("RGBA", (T * len(ICONS), T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    gold, dark, red = hexc("#e8c860"), hexc("#20180c"), hexc("#c04030")
    for i, n in enumerate(ICONS):
        x = i * T
        d.rounded_rectangle([x + 1, 1, x + 30, 30], radius=5, fill=hexc("#2a2230"), outline=gold)
        if n == "mover":
            d.polygon([(x + 8, 22), (x + 16, 8), (x + 24, 22), (x + 16, 18)], fill=gold)
        elif n == "atacar":
            d.line([x + 8, 24, x + 24, 8], fill=hexc("#d0d8e0"), width=3); d.line([x + 8, 18, x + 14, 24], fill=gold, width=2)
        elif n == "investida":
            for k in range(3): d.polygon([(x + 6 + k * 7, 9), (x + 12 + k * 7, 16), (x + 6 + k * 7, 23)], fill=gold)
        elif n == "especial":
            d.polygon([(x + 16, 5), (x + 19, 13), (x + 27, 13), (x + 21, 18), (x + 23, 26), (x + 16, 21), (x + 9, 26), (x + 11, 18), (x + 5, 13), (x + 13, 13)], fill=gold)
        elif n == "fim_turno":
            d.ellipse([x + 7, 7, x + 25, 25], outline=gold, width=2); d.line([x + 16, 16, x + 16, 9], fill=gold, width=2); d.line([x + 16, 16, x + 21, 18], fill=gold, width=2)
        elif n == "levantar":
            d.line([x + 16, 25, x + 16, 8], fill=gold, width=3); d.polygon([(x + 10, 13), (x + 16, 6), (x + 22, 13)], fill=gold)
        elif n == "misericordia":
            d.line([x + 16, 6, x + 16, 26], fill=red, width=3); d.line([x + 10, 12, x + 22, 12], fill=red, width=2)
        elif n == "furtivo":
            d.ellipse([x + 6, 11, x + 26, 21], outline=gold, width=2); d.line([x + 6, 24, x + 26, 8], fill=gold, width=2)
    p = A / "ui" / "icons.png"; p.parent.mkdir(parents=True, exist_ok=True); img.save(p)
    return p

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    tp, index = build_tileset()
    chars = build_chars()
    ip = build_icons()
    manifest = {"schema_version": 1, "art_bible": {"perspectiva": "top-down 3/4", "tile_px": 32, "char_canvas": [32, 32], "resolucao_interna": [640, 360],
        "pivot_personagem": [16, 28], "outline": "#1a1418", "status": "HIPOTESE — aprovar em cena real (§13, §20.2)"}, "assets": []}
    manifest["assets"].append({"asset_id": "tileset_base", "tipo": "tileset", "origem": "gerado_por_script:tools/gen_placeholder_art.py", "licenca": "original_do_projeto",
        "versao": 1, "estado": "prototype", "tamanho": [T * len(TILES), T * VARIANTS], "pivot": [0, 0], "animacoes": [], "dependencias": [],
        "hash": sha(tp), "caminho": "res://" + str(tp.relative_to(ROOT)), "indice": index, "variantes": VARIANTS})
    for name, p in chars.items():
        manifest["assets"].append({"asset_id": "char_" + name, "tipo": "spritesheet_personagem", "origem": "gerado_por_script:tools/gen_placeholder_art.py",
            "licenca": "original_do_projeto", "versao": 1, "estado": "prototype", "tamanho": [T * 3, T * 4], "pivot": [16, 28],
            "animacoes": {"linhas": ["baixo", "esquerda", "direita", "cima"], "quadros": ["parado", "passo_1", "passo_2"]}, "dependencias": [],
            "hash": sha(p), "caminho": "res://" + str(p.relative_to(ROOT))})
    manifest["assets"].append({"asset_id": "ui_icons", "tipo": "icones", "origem": "gerado_por_script:tools/gen_placeholder_art.py", "licenca": "original_do_projeto",
        "versao": 1, "estado": "prototype", "tamanho": [T * len(ICONS), T], "pivot": [0, 0], "animacoes": [], "dependencias": [], "hash": sha(ip),
        "caminho": "res://" + str(ip.relative_to(ROOT)), "indice": ICONS})
    (A / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print("ok", len(manifest["assets"]), "assets")

if __name__ == "__main__":
    main()
