#!/usr/bin/env python3
"""Acrescenta a data/rules/equipamento.json mais armas e armaduras do Livro Básico (Tabelas 3-3 e 3-5, p.144-153).
Idempotente. (tools/build_rules.py regeneraria o arquivo inteiro e perderia ajustes manuais, por isso o acréscimo é separado.)"""
import json, pathlib
P = pathlib.Path(__file__).resolve().parent.parent / "data" / "rules" / "equipamento.json"
FONTE = "T20 Livro Básico (Jambô, edição Jogo do Ano)"
NOVAS = {
 "arma.machadinha": ({"dano": "1d6", "margem": 20, "mult": 3, "alcance": "curto", "tipo": "corte", "maos": 1, "leve": True}, 144),
 "arma.cimitarra": ({"dano": "1d6", "margem": 18, "mult": 2, "tipo": "corte", "maos": 1}, 144),
 "arma.florete": ({"dano": "1d6", "margem": 18, "mult": 2, "tipo": "perfuracao", "maos": 1}, 144),
 "arma.mangual": ({"dano": "1d8", "margem": 20, "mult": 2, "tipo": "impacto", "maos": 1}, 144),
 "arma.martelo_guerra": ({"dano": "1d8", "margem": 20, "mult": 3, "tipo": "impacto", "maos": 1}, 144),
 "arma.picareta": ({"dano": "1d6", "margem": 20, "mult": 4, "tipo": "perfuracao", "maos": 1}, 144),
 "arma.tridente": ({"dano": "1d8", "margem": 20, "mult": 2, "alcance": "curto", "tipo": "perfuracao", "maos": 1}, 144),
 "arma.alabarda": ({"dano": "1d10", "margem": 20, "mult": 3, "tipo": "corte", "maos": 2}, 145),
 "arma.machado_guerra": ({"dano": "1d12", "margem": 20, "mult": 3, "tipo": "corte", "maos": 2}, 145),
 "arma.marreta": ({"dano": "3d4", "margem": 20, "mult": 2, "tipo": "impacto", "maos": 2}, 145),
 "arma.montante": ({"dano": "2d6", "margem": 19, "mult": 2, "tipo": "corte", "maos": 2}, 145),
 "arma.besta_leve": ({"dano": "1d8", "margem": 19, "mult": 2, "alcance": "medio", "tipo": "perfuracao", "maos": 1, "disparo": True}, 144),
 "arma.arco_longo": ({"dano": "1d8", "margem": 20, "mult": 3, "alcance": "medio", "tipo": "perfuracao", "maos": 2, "disparo": True, "madeira": True}, 145),
 "armadura.acolchoada": ({"defesa": 1, "penalidade": 0, "metal": False}, 153),
 "armadura.couro": ({"defesa": 2, "penalidade": 0, "metal": False}, 153),
 "armadura.brunea": ({"defesa": 5, "penalidade": -2, "metal": True}, 153),
 "armadura.loriga_segmentada": ({"defesa": 7, "penalidade": -3, "metal": True}, 153),
 "armadura.meia_armadura": ({"defesa": 8, "penalidade": -4, "metal": True}, 153),
 "escudo.pesado": ({"defesa": 2, "penalidade": -2, "madeira": True}, 153),
}
d = json.loads(P.read_text(encoding="utf-8"))
ids = {x["id"] for x in d["rules"]}
for k, (v, pg) in NOVAS.items():
    if k not in ids:
        d["rules"].append({"id": k, "valor": v, "fonte": FONTE, "pagina": pg, "pdf_page": pg + 6, "status": "VERIFICADA"})
P.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
print("equipamento:", len(d["rules"]), "regras")
