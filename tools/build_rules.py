"""Gera data/rules/*.json a partir de valores conferidos manualmente nos PDFs.
Página = página impressa do livro. pdf_page = página do arquivo PDF (para conferência).
Status: VERIFICADA (lida no livro nesta sessão), PENDENTE_REVISAO (extraída, aguarda humano),
ADAPTADA (mudança consciente), ORIGINAL_DO_JOGO."""
import json, pathlib
LB = "T20 Livro Básico (Jambô, edição Jogo do Ano)"
BE = "Bestiário Tormenta20 (Ameaças de Arton — arquivo 'Bestiario_tormenta.pdf')"
def r(id, valor, fonte, pagina, pdf_page, status="VERIFICADA", nota=""):
    d = {"id": id, "valor": valor, "fonte": fonte, "pagina": pagina, "pdf_page": pdf_page, "status": status}
    if nota: d["nota"] = nota
    return d

PERICIAS = [("acrobacia","Des",False,True),("adestramento","Car",True,False),("atletismo","For",False,False),
 ("atuacao","Car",True,False),("cavalgar","Des",False,False),("conhecimento","Int",True,False),("cura","Sab",False,False),
 ("diplomacia","Car",False,False),("enganacao","Car",False,False),("fortitude","Con",False,False),("furtividade","Des",False,True),
 ("guerra","Int",True,False),("iniciativa","Des",False,False),("intimidacao","Car",False,False),("intuicao","Sab",False,False),
 ("investigacao","Int",False,False),("jogatina","Car",True,False),("ladinagem","Des",True,True),("luta","For",False,False),
 ("misticismo","Int",True,False),("nobreza","Int",True,False),("oficio","Int",True,False),("percepcao","Sab",False,False),
 ("pilotagem","Des",True,False),("pontaria","Des",False,False),("reflexos","Des",False,False),("religiao","Sab",True,False),
 ("sobrevivencia","Sab",False,False),("vontade","Sab",False,False)]

core = [
 r("teste.basico", {"formula": "1d20 + modificador >= CD"}, LB, 220, 226),
 r("teste.oposto.empate", {"regra": "maior valor vence; se igual, rolar de novo"}, LB, 220, 226),
 r("pericia.valor", {"formula": "floor(nivel/2) + atributo + treino"}, LB, 114, 120),
 r("pericia.bonus_treino", {"1-6": 2, "7-14": 4, "15+": 6}, LB, 114, 120),
 r("pericia.tabela", {p: {"atributo": a, "somente_treinada": t, "armadura": ar} for p,a,t,ar in PERICIAS}, LB, 115, 121),
 r("cd.tabela", {"facil": 5, "media": 10, "dificil": 15, "desafiadora": 20, "formidavel": 25, "heroica": 30, "quase_impossivel": 40}, LB, 220, 226),
 r("cd.resistencia", {"formula": "10 + floor(nivel/2) + atributo"}, LB, 227, 233),
 r("atributos.compra_pontos", {"pontos": 10, "custo": {"-1": -1, "0": 0, "1": 1, "2": 2, "3": 4, "4": 7}}, LB, 17, 23),
 r("defesa.base", {"formula": "10 + Des + armadura + escudo"}, LB, 106, 112, "PENDENTE_REVISAO", "Linha encontrada por busca; conferir parágrafo completo."),
 r("ataque.teste", {"corpo_a_corpo": "luta", "distancia": "pontaria", "dificuldade": "Defesa do alvo", "acerta_se": ">="}, LB, 230, 236),
 r("dano.forca", {"corpo_a_corpo_e_arremesso": "dado + For", "disparo": "dado"}, LB, 230, 236),
 r("critico", {"margem_padrao": 20, "multiplicador_padrao": 2, "multiplica": "apenas dados da arma", "nao_multiplica": "bonus numericos e dados extras"}, LB, 230, 237),
 r("iniciativa", {"teste": "iniciativa", "inimigos": "um teste único com o menor valor", "empate": "maior valor de perícia; depois nova rolagem", "fixa_no_combate": True}, LB, 231, 237),
 r("surpresa", {"efeito": "desprevenido e não age na 1ª rodada"}, LB, 231, 237),
 r("turno.acoes", {"opcoes": [["padrao","movimento"],["movimento","movimento"],["completa"]], "livres": "ilimitadas", "reacoes": "ilimitadas"}, LB, 233, 239),
 r("rodada.segundos", 6, LB, 233, 239),
 r("deslocamento.padrao_m", 9, LB, 238, 244),
 r("mapa.quadrado_m", 1.5, LB, 236, 242),
 r("mapa.diagonal", {"custo_quadrados": 2}, LB, 238, 244, nota="Diagonal custa o dobro."),
 r("mapa.terreno_dificil", {"custo_multiplicador": 2}, LB, 238, 244),
 r("mapa.espaco_inimigo", {"atravessar": False, "excecoes": ["caido","indefeso","3 categorias de tamanho"], "conta_como": "terreno_dificil"}, LB, 238, 244),
 r("situacao.flanquear", {"bonus_ataque": 2, "apenas": "corpo a corpo"}, LB, 239, 245),
 r("situacao.cobertura_leve", {"bonus_defesa": 5}, LB, 239, 245),
 r("situacao.camuflagem_leve", {"falha_pct": 20, "rolagem": "1d10: 1-2 erra"}, LB, 238, 244),
 r("situacao.atacante_caido", {"penalidade_corpo_a_corpo": -5}, LB, 239, 245),
 r("distancia.em_corpo_a_corpo", {"penalidade": -5}, LB, 233, 239),
 r("distancia.dobro_alcance", {"penalidade": -5}, LB, 233, 239),
 r("acao.investida", {"distancia": "até 2x deslocamento (mín 3m) em linha reta", "bonus_ataque": 2, "penalidade_defesa": -2, "proibida_em": "terreno_dificil"}, LB, 235, 241),
 r("acao.golpe_misericordia", {"alvo": "adjacente e indefeso", "critico_automatico": True, "morte_pct_importante": 25, "morte_pct_secundario": 75}, LB, 235, 241),
 r("ferimentos.zero_pv", {"efeito": "inconsciente e sangrando", "teste": "Con CD 15 no início do turno", "falha": "perde 1d6 PV", "estabilizar_cura_cd": 15}, LB, 236, 242),
 r("ferimentos.morte", {"limite": "min(-10, -floor(PV_max/2))"}, LB, 236, 242, nota="Morre em -10 ou metade negativa dos PV totais, o que for mais baixo."),
 r("descanso.recuperacao", {"ruim": 0.5, "normal": 1, "confortavel": 2, "luxuosa": 3, "base": "nivel", "recupera": ["PV", "PM"]}, LB, 106, 112),
 r("descanso.ruim_relento", {"condicao": "dormir ao relento sem saco de dormir e acampamento"}, LB, 106, 112),
 r("descanso.duracao_horas", 8, LB, 106, 112, "PENDENTE_REVISAO", "Duração de 'uma noite de sono' assumida como 8h; conferir texto."),
 r("descanso.minimo", {"minimo": 1}, LB, 106, 112, "ADAPTADA", "Metade do nível 1 arredonda para 0; o jogo usa mínimo 1."),
 r("dano.nao_letal", {"penalidade_ataque_para_trocar": -5}, LB, 236, 242),
]
condicoes = r("condicoes", {
  "abalado": {"pericias": -2, "acumula_em": "apavorado", "tipo": "medo"},
  "apavorado": {"pericias": -5, "tipo": "medo"},
  "atordoado": {"implica": ["desprevenido"], "sem_acoes": True},
  "caido": {"defesa_cac": -5, "defesa_distancia": 5, "ataque_cac": -5, "deslocamento_m": 1.5},
  "cego": {"implica": ["desprevenido","lento"]},
  "desprevenido": {"defesa": -5, "reflexos": -5},
  "enredado": {"implica": ["lento","vulneravel"], "ataque": -2},
  "fraco": {"for_des_con": -2},
  "imovel": {"deslocamento_m": 0},
  "inconsciente": {"implica": ["indefeso"], "sem_acoes": True, "sem_reacoes": True},
  "indefeso": {"implica": ["desprevenido"], "defesa": -10, "falha_reflexos": True},
  "lento": {"deslocamento_mult": 0.5, "sem_investida": True},
  "ofuscado": {"ataque": -2, "percepcao": -2},
  "sangrando": {"teste": "Con CD 15", "falha": "perde 1d6 PV"},
  "surpreendido": {"implica": ["desprevenido"], "sem_acoes": True},
  "vulneravel": {"defesa": -2},
  "_regra": "condições iguais não se acumulam; aplicar a mais severa; terminam no fim da cena salvo indicação"
}, LB, 394, 400)
core.append(condicoes)

equip = [
 r("arma.adaga", {"dano": "1d4", "margem": 19, "mult": 2, "alcance": "curto", "tipo": "perfuracao", "maos": 1, "leve": True}, LB, 144, 150),
 r("arma.espada_curta", {"dano": "1d6", "margem": 19, "mult": 2, "tipo": "perfuracao", "maos": 1, "leve": True}, LB, 144, 150),
 r("arma.clava", {"dano": "1d6", "margem": 20, "mult": 2, "tipo": "impacto", "maos": 1}, LB, 144, 150),
 r("arma.lanca", {"dano": "1d6", "margem": 20, "mult": 2, "alcance": "curto", "tipo": "perfuracao", "maos": 1}, LB, 144, 150),
 r("arma.funda", {"dano": "1d4", "margem": 20, "mult": 2, "alcance": "medio", "tipo": "impacto", "disparo": True}, LB, 144, 150, "PENDENTE_REVISAO", "Funda soma For no dano (regra específica da arma, p.148) — conferir."),
 r("arma.arco_curto", {"dano": "1d6", "margem": 20, "mult": 3, "alcance": "medio", "tipo": "perfuracao", "maos": 2, "disparo": True}, LB, 144, 150),
 r("arma.espada_longa", {"dano": "1d8", "margem": 19, "mult": 2, "tipo": "corte", "maos": 1}, LB, 144, 150),
 r("arma.machado_batalha", {"dano": "1d8", "margem": 20, "mult": 3, "tipo": "corte", "maos": 1}, LB, 144, 150),
 r("armadura.couro_batido", {"defesa": 3, "penalidade": -1, "metal": False}, LB, 153, 159),
 r("armadura.gibao_peles", {"defesa": 4, "penalidade": -3, "metal": False}, LB, 153, 159),
 r("armadura.cota_malha", {"defesa": 6, "penalidade": -2, "metal": True}, LB, 153, 159),
 r("escudo.leve", {"defesa": 1, "penalidade": -1}, LB, 153, 159),
 r("alcance.metros", {"curto": 9, "medio": 30, "longo": 90}, LB, 0, 0, "PENDENTE_REVISAO", "Valores de memória; conferir no livro antes de marcar VERIFICADA."),
]
personagem = [
 r("classe.guerreiro", {"pv_inicial": 20, "pv_nivel": 5, "soma_con": True, "pm_nivel": 3, "pericias_fixas": ["luta|pontaria", "fortitude"], "pericias_escolha": 2,
    "lista": ["adestramento","atletismo","cavalgar","guerra","iniciativa","intimidacao","luta","oficio","percepcao","pontaria","reflexos"],
    "ataque_especial": {"custo_pm": 1, "bonus": 4}}, LB, 65, 71),
 r("raca.humano", {"atributos": "+1 em três atributos diferentes", "versatil": "treinado em duas perícias"}, LB, 19, 25),
 r("envelhecimento", {"maduro": 45, "velho": 70, "longevidade": "70 + 2d20"}, LB, 108, 114),
]
personagem += [
 r("progressao.xp_por_nivel", {"1": 0, "2": 1000, "3": 3000, "4": 6000, "5": 10000, "6": 15000, "7": 21000, "8": 28000, "9": 36000, "10": 45000}, LB, 35, 41),
 r("progressao.xp_desafio", {"formula": "ND x 1000 / personagens", "empate": 0.5, "derrota": 0.25, "irrelevante_se_nd_menor_que_nivel_menos": 5}, LB, 326, 332),
 r("raca.anao", {"atributos": {"con": 2, "sab": 1, "des": -1}, "deslocamento_m": 6, "pv_nivel1": 3, "pv_por_nivel": 1, "sentidos": ["visao_escuro"],
   "bonus_subterraneo": {"percepcao": 2, "sobrevivencia": 2}, "sem_reducao_deslocamento_armadura": True}, LB, 20, 26),
 r("racas.tabela", {"humano": "+1 em três", "anao": "Con+2 Sab+1 Des-1", "elfo": "Int+2 Des+1 Con-1", "goblin": "Des+2 Int+1 Car-1", "minotauro": "For+2 Con+1 Sab-1"}, LB, 18, 24),
 r("classe.ladino", {"pv_inicial": 12, "pv_nivel": 3, "soma_con": True, "pm_nivel": 4, "pericias_fixas": ["ladinagem", "reflexos"], "pericias_escolha": 8,
   "ataque_furtivo": {"dados": "1d6", "condicao": "alvo desprevenido (cac ou alcance curto) ou flanqueado", "por_rodada": 1, "imunes": "imunes a crítico"}}, LB, 73, 79),
 r("classe.arcanista", {"pv_inicial": 8, "pv_nivel": 2, "soma_con": True, "pm_nivel": 6, "soma_atributo_chave_pm": True, "pericias_fixas": ["misticismo", "vontade"],
   "pericias_escolha": 2, "magias_iniciais": 3, "circulo_inicial": 1}, LB, 37, 43),
 r("magia.custo_por_circulo", {"1": 1, "2": 3, "3": 6, "4": 10, "5": 15}, LB, 170, 176),
 r("magia.seta_infalivel", {"tipo": "arcana", "circulo": 1, "escola": "evocacao", "execucao": "padrao", "alcance": "medio", "setas": 2, "dano_por_seta": "1d4+1",
   "dano_tipo": "essencia", "acerta_automaticamente": True}, LB, 206, 212),
 r("magia.curar_ferimentos", {"tipo": "divina", "circulo": 1, "escola": "evocacao", "execucao": "padrao", "alcance": "toque", "cura": "2d8+2"}, LB, 189, 195),
 r("acao.usar_item_pocao", {"acao": "padrao"}, LB, 234, 240),
 r("item.saco_de_dormir", {"preco": 1, "espacos": 1}, LB, 156, 162),
 r("item.pocao_curar_ferimentos", {"efeito": "magia.curar_ferimentos", "preco": 30}, LB, 0, 0, "PENDENTE_REVISAO", "Preço e regra de poções a conferir no cap. de itens mágicos."),
 r("viagem.velocidade", {"9": {"km_hora": 4.5, "km_dia": 36}, "6": {"km_hora": 3, "km_dia": 24}, "terreno_dificil_ou_clima_ruim": 0.5}, LB, 270, 276),
 r("viagem.marcha_forcada", {"dobra_por_hora": True, "teste": "Fortitude CD 15 +1 por teste", "falha": "perde 1d6 PV"}, LB, 270, 276),
 r("perigo.jornada_ermos", {"nd": 2, "curta": 3, "media": 5, "longa": 7, "falha": "perde 2d6 PV", "limite_falhas": 3, "pericia": "sobrevivencia"}, LB, 320, 326),
 r("perigo.jornada_ermos.cd", 15, LB, 320, 326, "PENDENTE_REVISAO", "CD da jornada não lida no trecho extraído."),
]
deuses = r("panteao.nomes", ["Aharadak","Allihanna","Arsenal","Azgher","Hyninn","Kallyadranoch","Khalmyr","Lena","Lin-Wu","Marah","Megalokk","Nimb","Oceano","Sszzaas","Tanna-Toh","Tenebra","Thwor","Thyatis","Valkaria","Wynna"], LB, 96, 102, "PENDENTE_REVISAO", "Nomes conferidos por contagem no texto; obrigações individuais a extrair.")
lena = r("deus.lena.obrigacao", {"proibido": ["dano_letal_a_vivos", "perda_pv_a_vivos"]}, LB, 100, 106)
fe = [deuses, lena,
 r("deus.khalmyr.obrigacao", {"proibido": ["recusar_ajuda_a_inocentes"], "arma_preferida": "espada longa"}, LB, 99, 105),
 r("deus.allihanna.obrigacao", {"proibido": ["armadura_ou_escudo_de_metal", "descansar_em_comunidade_maior_que_aldeia"]}, LB, 97, 103)]

ameacas = [
 r("criatura.bandido_comum", {"nome": "Bandido", "nd": "1/4", "tipo": "humanoide", "tamanho": "medio", "iniciativa": 4, "percepcao": 1, "defesa": 13,
   "fort": 1, "ref": 3, "von": -1, "pv": 6, "deslocamento_m": 9, "ataques": [{"nome": "Clava", "bonus": 7, "dano": "1d6+3", "margem": 20, "mult": 2, "alcance_q": 1}],
   "atributos": {"for": 1, "des": 2, "con": 1, "int": 0, "sab": -1, "car": 0}, "pericias": {"furtividade": 5}}, BE, 43, 45),
 r("criatura.bandido_ligeiro", {"nome": "Bandido Ligeiro", "nd": "1/2", "tipo": "humanoide", "tamanho": "medio", "iniciativa": 4, "percepcao": 1, "defesa": 15,
   "fort": 3, "ref": 5, "von": 0, "pv": 9, "deslocamento_m": 9, "ataques": [{"nome": "Clava", "bonus": 9, "dano": "1d6+5", "margem": 20, "mult": 2, "alcance_q": 1},
   {"nome": "Funda", "bonus": 9, "dano": "1d6+1", "margem": 20, "mult": 2, "alcance_q": 20, "distancia": True}],
   "atributos": {"for": 1, "des": 2, "con": 1, "int": 0, "sab": -1, "car": 0}, "pericias": {"furtividade": 6}}, BE, 43, 45),
 r("criatura.hiena", {"nome": "Hiena", "nd": "1", "tipo": "animal", "tamanho": "medio", "iniciativa": 5, "percepcao": 6, "defesa": 14,
   "fort": 9, "ref": 6, "von": 1, "pv": 17, "deslocamento_m": 15, "ataques": [{"nome": "Mordida", "bonus": 9, "dano": "1d6+7", "margem": 20, "mult": 3, "alcance_q": 1}],
   "atributos": {"for": 3, "des": 3, "con": 3, "int": -4, "sab": 2, "car": -2}, "pericias": {"furtividade": 5, "sobrevivencia": 6}, "sentidos": ["faro", "visao_penumbra"],
   "habilidades": ["oportunista: +2 dano contra quem sofreu dano nesta rodada"]}, BE, 120, 122, "PENDENTE_REVISAO", "Bloco extraído de layout em colunas; conferir valores."),
]
out = pathlib.Path(__file__).resolve().parent.parent / "data" / "rules"
for name, data in [("core", core), ("equipamento", equip), ("personagem", personagem), ("fe", fe), ("ameacas", ameacas)]:
    (out / f"{name}.json").write_text(json.dumps({"schema_version": 1, "rules": data}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(name, len(data))
