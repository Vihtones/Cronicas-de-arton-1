#!/usr/bin/env python3
"""Monta os spritesheets de personagens (3 colunas x 4 linhas de 64 px: parado/passo/passo x baixo/esq/dir/cima) a partir das
camadas do Universal LPC Spritesheet Character Generator (https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).
Só entram camadas cuja licença permita atribuição simples (CC0, OGA-BY, CC-BY); os créditos saem em assets/CREDITOS_PERSONAGENS.txt.
Uso: python3 tools/gen_chars_lpc.py <pasta do repositório LPC clonado> [pasta de saída]"""
import csv, sys, pathlib
from PIL import Image

LPC = pathlib.Path(sys.argv[1]) / "spritesheets"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path(__file__).resolve().parent.parent / "assets" / "chars"
CRED = {}
for r in csv.DictReader(open(pathlib.Path(sys.argv[1]) / "CREDITS.csv", encoding="utf-8")):
    CRED[r["filename"]] = r
OK_LIC = ("CC0", "OGA-BY", "CC-BY 3", "CC-BY 4", "CC-BY 2")
usados = {}


def _variante(pasta):
    """Camadas com pasta walk/: uma imagem por cor; prefere as claras (a tinta é aplicada depois)."""
    if not pasta.is_dir():
        return None
    for nome in ("white", "light", "gray", "tan", "beige"):
        if (pasta / (nome + ".png")).exists():
            return pasta / (nome + ".png")
    achados = sorted(pasta.glob("*.png"))
    return achados[0] if achados else None


def achar(prefixo, corpo):
    """Procura o walk da camada: prefixo/<corpo>, prefixo/adult, prefixo ou o primeiro que existir.
    `prefixo` aceita alternativas separadas por '|' (a primeira com licença aceitável vale)."""
    for alt in prefixo.split("|"):
        base = LPC / alt
        for sub in (corpo, "adult", "", "male", "female"):
            d = base / sub if sub else base
            for cand in (d / "walk.png", _variante(d / "walk")):
                if cand is not None and cand.exists() and licenca_ok(cand)[0]:
                    return cand
        for cand in sorted(base.rglob("walk.png")) + [v for v in (_variante(q) for q in sorted(base.rglob("walk"))) if v]:
            if licenca_ok(cand)[0]:
                return cand
    return None


def licenca_ok(p):
    rel = str(p.relative_to(LPC))
    if p.parent.name == "walk":   # variante de cor: a licença vem do walk.png da pasta
        rel = str(p.parent.relative_to(LPC)) + ".png"
    r = CRED.get(rel)
    return r is not None and any(k in r["licenses"] for k in OK_LIC), r, rel


def tingir(img, rgb, modo):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            if modo == "mul":
                px[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, a)
            else:   # colorize: mantém o sombreado, troca a cor
                k = 0.35 + 0.9 * lum
                px[x, y] = (min(255, int(rgb[0] * k)), min(255, int(rgb[1] * k)), min(255, int(rgb[2] * k)), a)
    return img


def camadas(corpo, specs):
    sheet = Image.new("RGBA", (576, 256))
    for prefixo, cor, modo in specs:
        p = achar(prefixo, corpo)
        if p is None:
            print("  (sem camada)", prefixo)
            continue
        ok, r, rel = licenca_ok(p)
        if not ok:
            print("  (licença não aceita, pulei)", rel, r["licenses"] if r else "?")
            continue
        usados[rel] = r
        img = Image.open(p).convert("RGBA")
        if cor:
            tingir(img, cor, modo)
        sheet.alpha_composite(img)
    return sheet


LPC_ROW = [2, 1, 3, 0]   # linhas do jogo (baixo, esq, dir, cima) -> linhas do LPC (cima, esq, baixo, dir)
COLS = [0, 2, 6]         # parado e os dois passos


def para_jogo(sheet):
    out = Image.new("RGBA", (192, 256))
    for r in range(4):
        for c, col in enumerate(COLS):
            out.alpha_composite(sheet.crop((col * 64, LPC_ROW[r] * 64, col * 64 + 64, LPC_ROW[r] * 64 + 64)), (c * 64, r * 64))
    return out


def C(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# (nome do arquivo, tipo de corpo, camadas na ordem de desenho: (prefixo, cor, modo))
HOMEM = "male"
PERSONAGENS = {
    "player": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#6b5236"), "mul"),
        ("feet/boots/basic/male", C("#4a3624"), "mul"), ("torso/clothes/longsleeve/longsleeve2/male", C("#4a78b8"), "mul"),
        ("torso/armour/leather/male", C("#8a6a48"), "mul"), ("hair/page", C("#8b3a1e"), "colorize")]),
    "aldeao": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#7a6a4a"), "mul"),
        ("feet/shoes/basic/male", C("#5a4630"), "mul"), ("torso/clothes/shortsleeve/shortsleeve/male", C("#7da05a"), "mul"),
        ("hair/unkempt|hair/bedhead|hair/messy1|hair/page", C("#6a4a2a"), "colorize")]),
    "artesao": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#5a5048"), "mul"),
        ("feet/boots/basic/male", C("#3a2e24"), "mul"), ("torso/clothes/longsleeve/longsleeve2/male", C("#b8a888"), "mul"),
        ("torso/aprons/apron", C("#8a5a3a"), "mul"), ("hair/buzzcut", C("#3a2a1e"), "colorize")]),
    "guarda": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#4a4a58"), "mul"),
        ("feet/boots/basic/male", C("#2e2a28"), "mul"), ("torso/chainmail/male", C("#9aa0aa"), "mul"),
        ("hat/helmet/flattop", C("#aab0ba"), "mul")]),
    "sacerdote": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None),
        ("legs/skirts/plain|legs/skirts/straight", C("#e8e4d4"), "mul"), ("torso/clothes/longsleeve/longsleeve2/male", C("#e8e4d4"), "mul"), ("torso/clothes/vest/male", C("#c8a84a"), "mul"), ("feet/sandals/male", C("#8a6a48"), "mul"), ("hair/bob", C("#5a4a3a"), "colorize")]),
    "idoso": ("male", [("body/bodies/male", None, None), ("head/heads/human/male_elderly", None, None), ("legs/pants/male", C("#6a6258"), "mul"),
        ("feet/shoes/basic/male", C("#4a4034"), "mul"), ("torso/clothes/longsleeve/longsleeve2/male", C("#8a7a68"), "mul"),
        ("hair/balding", C("#c8c8c8"), "colorize")]),
    "crianca": ("child", [("body/bodies/child", None, None), ("head/heads/human/child", None, None), ("legs/pants/child", C("#6a5a46"), "mul"),
        ("feet/shoes/basic", C("#4a3a2a"), "mul"), ("torso/clothes/shortsleeve/shortsleeve", C("#d08a5a"), "mul"), ("hair/bangs|hair/bangsshort|hair/page", C("#9a6a3a"), "colorize")]),
    "bandido": ("male", [("body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#3a3236"), "mul"),
        ("feet/boots/basic/male", C("#2a2220"), "mul"), ("torso/clothes/longsleeve/longsleeve2/male", C("#5a4a44"), "mul"),
        ("torso/armour/leather/male", C("#4a3a30"), "mul"), ("hat/cloth/hood", C("#3a2e2e"), "mul")]),
    "kael": ("male", [("body/bodies/muscular|body/bodies/male", None, None), ("head/heads/human/male", None, None), ("legs/pants/male", C("#2e2a30"), "mul"),
        ("feet/boots/basic/male", C("#1e1a1c"), "mul"), ("torso/armour/leather/male", C("#6a6a72"), "mul"),
        ("hair/page", C("#b0b0b0"), "colorize"), ("hat/cloth/bandana", C("#7a2a2a"), "mul")]),
    "aldea": ("female", [("body/bodies/female", None, None), ("head/heads/human/female", None, None), ("legs/skirts/plain", C("#8a5a5a"), "mul"),
        ("feet/shoes/basic", C("#5a4630"), "mul"), ("torso/clothes/blouse", C("#e0d8c0"), "mul"), ("hair/bob", C("#7a4a2a"), "colorize")]),
    "mercadora": ("female", [("body/bodies/female", None, None), ("head/heads/human/female", None, None), ("legs/skirts/plain", C("#4a6a8a"), "mul"),
        ("feet/shoes/basic", C("#4a3a2a"), "mul"), ("torso/clothes/blouse", C("#d8b878"), "mul"), ("hair/bob", C("#3a2a1e"), "colorize")]),
}
OUT.mkdir(parents=True, exist_ok=True)
for nome, (corpo, specs) in PERSONAGENS.items():
    print(nome)
    img = para_jogo(camadas(corpo, specs))
    img.save(OUT / f"{nome}.png")

linhas = ["Personagens: camadas do Universal LPC Spritesheet Character Generator (Liberated Pixel Cup), usadas pela licença de atribuição",
          "(OGA-BY 3.0 / CC-BY / CC0). Recolorizadas e combinadas por tools/gen_chars_lpc.py.", "", "Camadas, autores e fontes:"]
for rel, r in sorted(usados.items()):
    linhas.append(f"- {rel} | {r['authors'].strip()} | {r['licenses'].strip()} | {r['urls'].strip().split(',')[0]}")
(OUT.parent / "CREDITOS_PERSONAGENS.txt").write_text("\n".join(linhas) + "\n", encoding="utf-8")
print(len(usados), "camadas creditadas")
