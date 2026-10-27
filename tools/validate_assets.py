"""Validação automática de assets (§13 passo 6): dimensões, alpha, nomes, pivôs, hash, licença.
Uso: python3 tools/validate_assets.py   (código de saída 1 se houver erro)"""
import hashlib, json, pathlib, re, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
REQ = ["asset_id", "tipo", "origem", "licenca", "versao", "estado", "tamanho", "pivot", "animacoes", "dependencias", "hash", "caminho"]
ESTADOS = {"concept", "prototype", "approved_artistic", "approved"}
NAME = re.compile(r"^[a-z0-9_]+$")

def main():
    m = json.loads((ROOT / "assets" / "manifest.json").read_text(encoding="utf-8"))
    tile = m["art_bible"]["tile_px"]
    errors, ids = [], set()
    for a in m["assets"]:
        aid = a.get("asset_id", "?")
        for k in REQ:
            if k not in a: errors.append(f"{aid}: falta '{k}'")
        if aid in ids: errors.append(f"{aid}: id duplicado")
        ids.add(aid)
        if not NAME.match(aid): errors.append(f"{aid}: nome fora do padrão snake_case")
        if a.get("estado") not in ESTADOS: errors.append(f"{aid}: estado inválido")
        if not a.get("licenca"): errors.append(f"{aid}: sem licença")
        p = ROOT / a["caminho"].replace("res://", "")
        if not p.exists():
            errors.append(f"{aid}: arquivo ausente {p}"); continue
        if hashlib.sha256(p.read_bytes()).hexdigest() != a["hash"]:
            errors.append(f"{aid}: hash diverge do manifesto (arquivo alterado sem registrar versão)")
        img = Image.open(p)
        if list(img.size) != list(a["tamanho"]): errors.append(f"{aid}: tamanho {img.size} != manifesto {a['tamanho']}")
        if a["tipo"] != "sprite_objeto" and (img.size[0] % tile or img.size[1] % tile):
            errors.append(f"{aid}: dimensões não múltiplas de {tile}")
        if a["tipo"] == "sprite_objeto":
            px, py = a["pivot"]
            if not (0 <= px < img.size[0] and 0 <= py < img.size[1]): errors.append(f"{aid}: pivô fora da imagem")
            elif img.getpixel((px, min(py + 2, img.size[1] - 1)))[3] == 0 and img.getpixel((px, py))[3] == 0:
                errors.append(f"{aid}: pivô em área transparente (base não encontrada)")
        if img.mode != "RGBA": errors.append(f"{aid}: sem canal alpha")
        if a["tipo"] == "spritesheet_personagem":
            px, py = a["pivot"]
            quadro = img.size[0] // 3   # largura do quadro (32 px nos sprites antigos, 64 px nos de LPC)
            if not (0 <= px < quadro and 0 <= py < quadro): errors.append(f"{aid}: pivô fora do quadro")
            # cada quadro precisa ter conteúdo e transparência (checagem quadro a quadro)
            for fy in range(img.size[1] // tile):
                for fx in range(img.size[0] // tile):
                    fr = img.crop((fx * tile, fy * tile, fx * tile + tile, fy * tile + tile))
                    alpha = fr.getchannel("A")
                    if alpha.getbbox() is None: errors.append(f"{aid}: quadro ({fx},{fy}) vazio")
                    if min(alpha.get_flattened_data() if hasattr(alpha, "get_flattened_data") else alpha.getdata()) > 0: errors.append(f"{aid}: quadro ({fx},{fy}) sem transparência")
    for e in errors: print("ERRO", e)
    print(f"{len(m['assets'])} assets verificados, {len(errors)} erros")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
