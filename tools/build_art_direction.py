"""Gera o registro do Governador de Direção de Arte a partir da pasta "arte do jogo".

Uso:
    python3 tools/build_art_direction.py "<pasta arte do jogo>"

A pasta do usuário é a fonte da verdade. Este script lê os documentos e catálogos,
copia SOMENTE os assets com aprovação registrada pelo usuário (com verificação de SHA-256
contra o manifesto da pasta) e gera:
    data/art/direcao_de_arte.json   regras, pilares, curadoria, aprovações, papéis e políticas
    assets/manifest.json            entradas dos assets aprovados (mescladas às existentes)

Nada é escrito na pasta do usuário. Os valores de política (alfa da copa, espaçamento)
são recomendações técnicas do assistente, marcadas como tal, até a prova de escala.
"""
import hashlib
import json
import pathlib
import re
import shutil
import statistics
import sys
import unicodedata

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_JSON = ROOT / "data" / "art" / "direcao_de_arte.json"
OUT_ASSETS = ROOT / "assets" / "approved" / "vegetacao" / "lpc_jungle"
LOTE = "08_assets_gratuitos/lote_02"

DOCS = [
    "README.md", "CLAUDE.md", "MANIFESTO.md", "01_direcao/BIBLIA_DE_ARTE_v1.0.md",
    "01_direcao/DECISOES_E_CULTURAS.md", "02_referencias/curadoria.json", "02_referencias/NAO_AVALIADAS.md",
    "03_cena_piloto/EVOLUCAO.md", "04_godot/ESPECIFICACAO.md", "05_producao/ASSETS.md",
    "08_assets_gratuitos/APROVACOES.json", LOTE + "/catalogo.json", LOTE + "/REVISAO.md",
    "09_sprites_tormenta20/LEIA-PRIMEIRO.md", "09_sprites_tormenta20/ANALISE_DIRECAO_2026-10-24.md",
]

# Uso por papel. Alturas em px. Recomendação do assistente (não decisão do usuário).
UNDERGROWTH_MAX_H = 112      # sub-bosque que fecha um tile bloqueado
GROUND_MAX_H = 80            # planta decorativa em chão andável


def sha(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def pivot_of(img: Image.Image, tree: bool) -> list:
    """Pivô na base: mediana x dos pixels de tronco (marrons) perto da base; plantas usam a base opaca."""
    w, h = img.size
    px = img.convert("RGBA").load()
    if tree:
        brown = [(x, y) for y in range(int(h * 0.55), h) for x in range(w)
                 if px[x, y][3] == 255 and px[x, y][0] > px[x, y][1] + 25]
        if brown:
            yb = max(y for _, y in brown)
            xs = [x for x, y in brown if yb - 25 <= y <= yb - 6] or [x for x, _ in brown]
            x0, y0 = int(statistics.median(xs)), yb - 4
            # sobe até achar tronco sob o pivô (raízes curvas deixam a mediana fora do tronco)
            for y in range(y0, int(h * 0.5), -1):
                if any(0 <= x0 + dx < w and px[x0 + dx, y][3] == 255 and px[x0 + dx, y][0] > px[x0 + dx, y][1] + 25
                       for dx in (-1, 0, 1)):
                    return [x0, y]
            return [x0, y0]
    op = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 255]
    yb = max(y for _, y in op)
    xs = [x for x, y in op if y >= yb - 6]
    x0 = int(statistics.median(xs))
    for y in range(yb, 0, -1):
        if px[x0, y][3] == 255:
            return [x0, y]
    return [x0, yb - 2]


def main(src: pathlib.Path) -> None:
    lote = src / LOTE
    cat = json.loads((lote / "catalogo.json").read_text(encoding="utf-8"))
    man = {x["path"]: x["sha256"] for x in json.loads((lote / "manifesto.json").read_text(encoding="utf-8"))}
    aprov = json.loads((src / "08_assets_gratuitos/APROVACOES.json").read_text(encoding="utf-8"))
    cur = json.loads((src / "02_referencias/curadoria.json").read_text(encoding="utf-8"))

    if not any("LPC Jungle" in a["item"] for a in aprov):
        sys.exit("APROVACOES.json não contém a aprovação de LPC Jungle; nada a importar.")

    OUT_ASSETS.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(lote / "extraidos/lpc-jungle-v2/lpc-jungle-v2/CREDITS-jungle.txt", OUT_ASSETS / "CREDITS-jungle.txt")

    entries, trees, under, ground = [], [], [], []
    for c in cat:
        if not str(c.get("aprovacao_usuario", "")).startswith("aprovado"):
            continue  # sem aprovação registrada: não entra no build
        f = lote / c["arquivo"]
        h = sha(f)
        if h != man.get(c["arquivo"]):
            sys.exit(f"{c['id']}: SHA-256 diverge do manifesto da pasta de arte")
        n = int(c["id"].split("-")[-1])
        is_tree = n <= 10
        aid = f"veg_floresta_{slug(c['nome'])}_v01"
        dst = OUT_ASSETS / f"{aid}.png"
        shutil.copyfile(f, dst)
        img = Image.open(dst)
        piv = pivot_of(img, is_tree)
        entries.append({
            "asset_id": aid,
            "tipo": "sprite_objeto",
            "origem": f"pasta_arte:{LOTE}/{c['arquivo']} (recorte de {c['arquivo_original']} {c.get('retangulo_xyxy')})",
            "fonte_url": c["fonte"],
            "licenca": "CC-BY-4.0",
            "creditos": "res://assets/approved/vegetacao/lpc_jungle/CREDITS-jungle.txt",
            "versao": 1,
            "estado": "approved_artistic",
            "aprovacao": "APR-2026-10-23-LPC-JUNGLE",
            "id_curadoria": c["id"],
            "nome": c["nome"],
            "papel": "floresta.arvore" if is_tree else "floresta.planta",
            "zonas_permitidas": ["floresta", "estrada"],
            "validacao_tecnica": "pendente: escala, paleta do bioma e sombra pintada (REVISAO.md do lote 02)",
            "adaptacao_pendente": c["adaptacoes_ao_fechar_banco"],
            "tamanho": list(img.size),
            "pivot": piv,
            "animacoes": [],
            "dependencias": [],
            "hash": h,
            "hash_origem": man[c["arquivo"]],
            "caminho": f"res://assets/approved/vegetacao/lpc_jungle/{aid}.png",
        })
        if is_tree:
            trees.append(aid)
        else:
            if img.size[1] <= UNDERGROWTH_MAX_H:
                under.append(aid)
            if img.size[1] <= GROUND_MAX_H:
                ground.append(aid)

    docs = []
    for d in DOCS:
        p = src / d
        if p.exists():
            docs.append({"caminho": d, "sha256": sha(p)})

    gov = {
        "schema_version": 1,
        "gerado_por": "tools/build_art_direction.py",
        "fonte_pasta": "C:/Users/Vitor/Documents/arte do jogo",
        "data_leitura": "2026-10-24",
        "documentos_fonte": docs,
        "identidade": {
            "nome": "Beleza Marcada",
            "resumo": "Beleza, credibilidade e história. Aconchego medieval, fantasia extraordinária e inquietação rubra. "
                      "A Tormenta rompe a familiaridade com formas antinaturais e vermelho incisivo; Arton inteira não é vermelha.",
            "fonte": "01_direcao/BIBLIA_DE_ARTE_v1.0.md",
        },
        "hierarquia_decisoes": [
            "decisões explícitas mais recentes do usuário",
            "aprovação final da cena (piloto_v04_final_aprovada.png)",
            "curadoria individual (CUR-001..025)",
            "Bíblia consolidada",
            "propostas e biblioteca histórica",
        ],
        "pilares": [
            {"referencia": "Stoneshard", "funcao": "acabamento, proporções, materiais, equipamentos e legibilidade"},
            {"referencia": "Octopath Traveler II", "funcao": "luz natural orgânica, sombras e emoção"},
            {"referencia": "Sea of Stars", "funcao": "ecossistemas, crescimento, natureza/construção e ciclos"},
            {"referencia": "Children of Morta", "funcao": "profundidade, névoa, separação de planos e luz localizada"},
        ],
        "cena_referencia": {
            "arquivo": "03_cena_piloto/piloto_v04_final_aprovada.png",
            "status": "direção visual aprovada; concept art, não é cenário jogável, tileset ou spritesheet",
            "mensagem_usuario": "Pronto perfeito, isso aliado ao paralax vai ficar muito bom, pode aprovar",
            "no_build": False,
        },
        "curadoria": {
            "totais": {s: sum(1 for x in cur if x["status"] == s) for s in ("aprovada", "parcial", "rejeitada")},
            "nao_avaliada": ["CUR-026"],
            "itens": [{"id": x["id"], "nome": x["nome"], "status": x["status"], "aproveitar": x["aproveitar"],
                       "ressalvas": x["ressalvas"]} for x in cur],
        },
        "regras": [
            {"id": "AD-01", "texto": "Só entram no build assets com aprovação registrada pelo usuário e licença conhecida.", "verificacao": "governador+ci"},
            {"id": "AD-02", "texto": "Aprovação artística e liberação de uso são campos separados; ambas são exigidas.", "verificacao": "ci"},
            {"id": "AD-03", "texto": "Assets CC-BY exigem o arquivo de créditos integral junto ao asset e na tela de créditos.", "verificacao": "ci"},
            {"id": "AD-04", "texto": "O arquivo importado deve ter o mesmo SHA-256 do manifesto da pasta de arte; alterações viram nova versão.", "verificacao": "ci"},
            {"id": "AD-05", "texto": "Referências externas (02_referencias), biblioteca histórica (00_fontes) e concepts nunca entram no build.", "verificacao": "ci"},
            {"id": "AD-06", "texto": "O acervo Tormenta20 (09_sprites_tormenta20) não é promovido automaticamente; exige aprovação própria.", "verificacao": "ci"},
            {"id": "AD-07", "texto": "Assets regionais só aparecem nas zonas permitidas; vegetação de selva não substitui o vilarejo temperado.", "verificacao": "governador+teste"},
            {"id": "AD-08", "texto": "Filtro nearest e escala inteira (1:1) para sprites de mundo; sem reamostragem.", "verificacao": "governador"},
            {"id": "AD-09", "texto": "Pivô nos pés/raiz e Y-sort; colisão vem dos dados do mapa, não da imagem.", "verificacao": "teste"},
            {"id": "AD-10", "texto": "Chão navegável, personagens e interativos continuam legíveis: copas ficam translúcidas perto do jogador e no combate.", "verificacao": "governador+teste"},
            {"id": "AD-11", "texto": "Áreas de respiro: árvores grandes espaçadas; o restante dos tiles bloqueados vira sub-bosque baixo.", "verificacao": "teste"},
            {"id": "AD-12", "texto": "Parallax só em planos decorativos sem função espacial; troncos colidíveis nunca deslizam.", "verificacao": "revisao_humana"},
            {"id": "AD-13", "texto": "Blur sutil e seletivo aprovado; nunca sobre personagens, chão navegável ou interativos; com opção de desligar.", "verificacao": "revisao_humana"},
            {"id": "AD-14", "texto": "Evitar saturação generalizada, caricatura, ruído de detalhe e futurismo. Blasphemous 2 e Tails of Iron rejeitados.", "verificacao": "revisao_humana"},
            {"id": "AD-15", "texto": "Desgaste diferencia condição econômica; não aplicar desgaste de bairro pobre a todo o mundo.", "verificacao": "revisao_humana"},
            {"id": "AD-16", "texto": "Não misturar a campanha Hudra; não inventar descrições canônicas sem fonte.", "verificacao": "revisao_humana"},
        ],
        "fontes_proibidas_no_build": ["02_referencias/", "00_fontes/", "03_cena_piloto/", "06_assets/concepts/",
                                      "06_assets/rejected/", "09_sprites_tormenta20/"],
        "decisoes_abertas": ["reino da vila", "divindade da capela", "paleta final", "resolução-base",
                             "tiles, medidas e zoom numéricos", "hardware-alvo", "sistema definitivo de navegação",
                             "escala do personagem frente às árvores LPC (prova de escala)"],
        "aprovacoes": [
            {"id": "APR-2026-10-23-LPC-JUNGLE", "item": "LPC Jungle — lote 02 (20 componentes)",
             "tipo": "artistica", "mensagem_usuario": "Lpc jungle muito bom aprovadissimo",
             "liberacao_uso": "CC-BY 4.0 com CREDITS-jungle.txt integral", "assets": [e["asset_id"] for e in entries],
             "limites": "adaptações de paleta, escala e sombras planejadas; integração Godot ainda não validada pelo usuário"},
            {"id": "APR-2026-10-23-IMMUNITY", "item": "Immunity — Resurrected RPG 1.1", "tipo": "direcao",
             "mensagem_usuario": "Bom aprovo isso continue", "assets": [],
             "limites": "download não confirmado; nenhum arquivo disponível"},
            {"id": "APR-PILOTO-V04", "item": "Cena-piloto v04", "tipo": "direcao", "assets": [],
             "limites": "concept art; referência de aceite, não asset de jogo"},
        ],
        "papeis": {
            "_zonas": "floresta e o trecho da estrada que a atravessa (recomendação do assistente); nunca vila, ruína ou cripta",
            "floresta.arvore": {"zonas": ["floresta", "estrada"], "tile": "T", "assets": trees},
            "floresta.sub_bosque": {"zonas": ["floresta", "estrada"], "tile": "T", "assets": under},
            "floresta.chao_decorativo": {"zonas": ["floresta", "estrada"], "tile": ",", "assets": ground},
        },
        "politicas_runtime": {
            "_natureza": "recomendação técnica do assistente; ajustar na prova de escala",
            "filtro": "nearest",
            "escala": 1,
            "copa_alpha_perto_jogador": 0.25,
            "copa_raio_px": 56,
            "copa_alpha_combate": 0.35,
            "arvore_espacamento_tiles": 2,
            "arvore_grande_largura_px": 150,
            "arvore_grande_espacamento_tiles": 3,
            "chao_decorativo_chance": 0.05,
            "parallax": "não implementado",
            "blur": "não implementado",
        },
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(gov, ensure_ascii=False, indent=1), encoding="utf-8")

    mpath = ROOT / "assets" / "manifest.json"
    m = json.loads(mpath.read_text(encoding="utf-8"))
    keep = [a for a in m["assets"] if not a["asset_id"].startswith("veg_floresta_")]
    m["assets"] = keep + entries
    mpath.write_text(json.dumps(m, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(entries)} assets aprovados importados; árvores {len(trees)}, sub-bosque {len(under)}, chão {len(ground)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(pathlib.Path(sys.argv[1]))
