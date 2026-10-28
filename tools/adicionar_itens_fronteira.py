#!/usr/bin/env python3
"""Acrescenta a data/world/items.json os itens da Fronteira do Leste (armas e armaduras do LB, troféus de contrato, entregas, comida).
Idempotente. items.json é mantido à mão (o gerador build_content.py não o sobrescreve)."""
import json, pathlib
P = pathlib.Path(__file__).resolve().parent.parent / "data" / "world" / "items.json"
d = json.loads(P.read_text(encoding="utf-8"))
F = "ferramentas"
NOVOS = {
 # armas (LB p.144-145)
 "machadinha": {"name": "Machadinha", "price": 6, "good": F, "rule": "arma.machadinha"},
 "cimitarra": {"name": "Cimitarra", "price": 15, "good": F, "rule": "arma.cimitarra"},
 "florete": {"name": "Florete", "price": 20, "good": F, "rule": "arma.florete"},
 "mangual": {"name": "Mangual", "price": 8, "good": F, "rule": "arma.mangual"},
 "martelo_guerra": {"name": "Martelo de guerra", "price": 12, "good": F, "rule": "arma.martelo_guerra"},
 "picareta": {"name": "Picareta", "price": 8, "good": F, "rule": "arma.picareta"},
 "tridente": {"name": "Tridente", "price": 15, "good": F, "rule": "arma.tridente"},
 "alabarda": {"name": "Alabarda", "price": 10, "good": F, "rule": "arma.alabarda"},
 "machado_guerra": {"name": "Machado de guerra", "price": 20, "good": F, "rule": "arma.machado_guerra"},
 "marreta": {"name": "Marreta", "price": 20, "good": F, "rule": "arma.marreta"},
 "montante": {"name": "Montante", "price": 50, "good": F, "rule": "arma.montante"},
 "besta_leve": {"name": "Besta leve", "price": 35, "good": F, "rule": "arma.besta_leve"},
 "arco_longo": {"name": "Arco longo", "price": 100, "good": F, "rule": "arma.arco_longo"},
 # armaduras e escudos (LB p.153)
 "gibao_peles": {"name": "Gibão de peles", "price": 25, "good": F, "rule": "armadura.gibao_peles"},
 "armadura_acolchoada": {"name": "Armadura acolchoada", "price": 5, "good": F, "rule": "armadura.acolchoada"},
 "armadura_couro": {"name": "Armadura de couro", "price": 20, "good": F, "rule": "armadura.couro"},
 "brunea": {"name": "Brunea", "price": 50, "good": F, "rule": "armadura.brunea"},
 "loriga_segmentada": {"name": "Loriga segmentada", "price": 250, "good": F, "rule": "armadura.loriga_segmentada"},
 "meia_armadura": {"name": "Meia armadura", "price": 600, "good": F, "rule": "armadura.meia_armadura"},
 "escudo_leve": {"name": "Escudo leve", "price": 5, "good": F, "rule": "escudo.leve"},
 "escudo_pesado": {"name": "Escudo pesado", "price": 15, "good": F, "rule": "escudo.pesado"},
 # comida e bebida regionais
 "ensopado_junco": {"name": "Ensopado de junco e peixe", "price": 2, "good": "comida", "alimento": True},
 "vinho_de_cacto": {"name": "Vinho de cacto", "price": 2, "good": "bebida", "alimento": True},
 "cerveja_ana": {"name": "Cerveja escura anã", "price": 2, "good": "bebida", "alimento": True},
 # troféus de contrato (vendem-se às lojas) e tesouros
 "presa_de_serpente": {"name": "Presa de serpente", "price": 6, "trofeu": True},
 "couro_de_sucuri": {"name": "Couro de sucuri", "price": 25, "trofeu": True},
 "escama_de_nagah": {"name": "Escama de nagah", "price": 18, "trofeu": True},
 "medalhao_do_culto": {"name": "Medalhão do Culto da Serpente", "price": 45, "trofeu": True},
 "dente_de_gnoll": {"name": "Colar de dentes de gnoll", "price": 5, "trofeu": True},
 "garra_de_grifo": {"name": "Garra de grifo", "price": 30, "trofeu": True},
 "ferrao_de_manticora": {"name": "Ferrão de mantícora", "price": 60, "trofeu": True},
 "olho_de_basilisco": {"name": "Olho de basilisco", "price": 80, "trofeu": True},
 "osso_antigo": {"name": "Osso antigo marcado de runas", "price": 8, "trofeu": True},
 "grimorio_rasgado": {"name": "Grimório rasgado", "price": 70, "trofeu": True},
 "presa_de_orc": {"name": "Presa de orc", "price": 8, "trofeu": True},
 "coracao_de_ogro": {"name": "Coração de ogro", "price": 40, "trofeu": True},
 "pelagem_de_urso_coruja": {"name": "Pelagem de urso-coruja", "price": 55, "trofeu": True},
 "gancho_de_ganchador": {"name": "Gancho de ganchador", "price": 35, "trofeu": True},
 "nucleo_de_golem": {"name": "Núcleo de golem de ferro", "price": 250, "trofeu": True},
 "escama_de_dragao": {"name": "Escama de dragão", "price": 400, "trofeu": True},
 "minerio_negro": {"name": "Minério negro", "price": 20, "trofeu": True},
 "amuleto_serpente": {"name": "Amuleto da Serpente", "price": 90, "trofeu": True},
 # entregas da guilda
 "caixa_suprimentos": {"name": "Caixa de suprimentos (entrega)", "price": 0, "owner": "guilda"},
 "ervas_curandeira": {"name": "Feixe de ervas secas (entrega)", "price": 0, "owner": "guilda"},
 "carta_areia": {"name": "Carta para Areia Dourada (entrega)", "price": 0, "owner": "guilda"},
 "encomenda_armeira": {"name": "Encomenda da armeira (entrega)", "price": 0, "owner": "guilda"},
 "ferramentas_mina": {"name": "Caixa de ferramentas de mina (entrega)", "price": 0, "owner": "guilda"},
 "ordem_do_capataz": {"name": "Ordem selada do capataz (entrega)", "price": 0, "owner": "guilda"},
}
for k, v in NOVOS.items():
    d.setdefault(k, v)
P.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
print("itens:", len(d))
