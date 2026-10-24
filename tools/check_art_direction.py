"""Checagem do Governador de Direção de Arte (regras AD-01..AD-07) para a CI.
Uso: python3 tools/check_art_direction.py   (código de saída 1 se houver violação)

Espelha ArtGovernor._refusal e acrescenta o que só dá para checar fora do jogo:
existência do arquivo de créditos, SHA-256 contra a origem e papéis coerentes com as zonas."""
import hashlib, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILDABLE = {"approved_artistic", "approved"}


def res(p: str) -> pathlib.Path:
    return ROOT / p.replace("res://", "")


def main() -> int:
    d = json.loads((ROOT / "data/art/direcao_de_arte.json").read_text(encoding="utf-8"))
    m = json.loads((ROOT / "assets/manifest.json").read_text(encoding="utf-8"))
    apr = {a["id"]: a for a in d["aprovacoes"]}
    assets = {a["asset_id"]: a for a in m["assets"]}
    errs = []
    governed = [a for a in m["assets"] if a["estado"] in BUILDABLE]
    for a in governed:
        aid = a["asset_id"]
        ap = apr.get(a.get("aprovacao", ""))
        if ap is None: errs.append(f"AD-01 {aid}: sem aprovação registrada"); continue
        if aid not in ap.get("assets", []): errs.append(f"AD-01 {aid}: aprovação {ap['id']} não cobre o asset")
        if not ap.get("liberacao_uso") or not a.get("licenca"): errs.append(f"AD-02 {aid}: sem liberação de uso/licença")
        if a["licenca"].startswith("CC-BY"):
            c = a.get("creditos", "")
            if not c or not res(c).exists() or res(c).stat().st_size == 0: errs.append(f"AD-03 {aid}: arquivo de créditos ausente")
        f = res(a["caminho"])
        if not f.exists(): errs.append(f"{aid}: arquivo ausente"); continue
        h = hashlib.sha256(f.read_bytes()).hexdigest()
        if h != a.get("hash_origem"): errs.append(f"AD-04 {aid}: SHA-256 difere da origem na pasta de arte (alteração exige nova versão)")
        for fp in d["fontes_proibidas_no_build"]:
            if fp in a.get("origem", ""): errs.append(f"AD-05/06 {aid}: origem proibida {fp}")
    for role, r in d["papeis"].items():
        if role.startswith("_"): continue
        for aid in r["assets"]:
            a = assets.get(aid)
            if a is None: errs.append(f"{role}: asset {aid} não está no manifesto"); continue
            if a["estado"] not in BUILDABLE: errs.append(f"AD-01 {role}: {aid} não aprovado")
            if not set(r["zonas"]) <= set(a.get("zonas_permitidas", [])): errs.append(f"AD-07 {role}: {aid} fora das zonas permitidas")
    # placeholders continuam permitidos, mas não podem ocupar papéis governados
    for e in errs: print("ERRO", e)
    print(f"Governador de arte: {len(governed)} assets governados, {len(d['regras'])} regras, {len(errs)} violações")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
