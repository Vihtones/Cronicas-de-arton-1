"""Extrai fichas de criaturas do capítulo 7 do Livro Básico (texto em colunas de lb.txt).
Uso: python3 extrair.py > criaturas.json   (só leitura do livro; o JSON vai para revisão)"""
import re, json, sys
sys.path.insert(0, '../extrator_magias')
LB = '/home/claude/scratch_t20/lb.txt'
pages = open(LB).read().split('\f')

def colunas(pg):
    lines = pg.split('\n')
    w = max((len(l) for l in lines), default=0)
    occ = [0] * (w + 1)
    for l in lines:
        for i, ch in enumerate(l):
            if ch != ' ': occ[i] += 1
    n = len([l for l in lines if l.strip()])
    gaps = set(i for i in range(w) if occ[i] <= max(1, n * 0.03))
    cuts = []; run = []
    for i in range(w + 1):
        if i in gaps: run.append(i)
        else:
            if len(run) >= 2 and run[0] > 15 and run[-1] < w - 15: cuts.append(run[len(run) // 2])
            run = []
    edges = [0] + cuts + [w + 1]
    return ['\n'.join(l[a:b].rstrip() for l in lines) for a, b in zip(edges, edges[1:])]

TAM = {'Minúsculo': 'minusculo', 'Pequeno': 'pequeno', 'Médio': 'medio', 'Grande': 'grande', 'Enorme': 'enorme', 'Colossal': 'colossal'}
TIPOS = {'Animal': 'animal', 'Humanoide': 'humanoide', 'Monstro': 'monstro', 'Morto-vivo': 'morto-vivo', 'Espírito': 'espirito', 'Construto': 'construto'}
num = lambda s: int(s.replace('–', '-').replace('—', '0').replace('+', ''))

def ataques(txt, distancia):
    out = []
    for m in re.finditer(r'([A-Za-zÀ-ÿ\' -]+?) \+(\d+) \(([^)]*)\)', txt):
        nome = m.group(1).strip().replace('e ', '', 1) if m.group(1).strip().startswith('e ') else m.group(1).strip()
        partes = m.group(3).split(',')
        dano = partes[0].strip()
        dm = re.match(r'(\d+d\d+(?:[+–-]\d+)?)', dano)
        if not dm: continue
        margem, mult = 20, 2
        for p in partes[1:]:
            p = p.strip()
            mm = re.match(r'(\d+)(?:/x(\d))?', p)
            if p.startswith('x'): mult = int(p[1:2])
            elif mm: margem = int(mm.group(1)); mult = int(mm.group(2) or 2)
        extra = dano[dm.end():].strip()
        out.append({'nome': nome.capitalize(), 'bonus': int(m.group(2)), 'dano': dm.group(1).replace('–', '-'), 'margem': margem, 'mult': mult,
                    'alcance_q': 20 if distancia else 1, 'distancia': distancia, **({'extra_texto': extra} if extra else {})})
    return out

def ficha(bloco, nome, nd, pagina):
    t = ' '.join(l.strip() for l in bloco)
    t = re.sub(r'-\s+', '-', t)
    f = {'nome': nome, 'nd': nd}
    m = re.search(r'(Animal|Humanoide|Monstro|Morto-vivo|Espírito|Construto)(?: \([^)]*\))? (Minúsculo|Pequeno|Médio|Grande|Enorme|Colossal)', t)
    if not m: return None
    f['tipo'] = TIPOS[m.group(1)]; f['tamanho'] = TAM[m.group(2)]
    m = re.search(r'Iniciativa ([+–-]\d+), Percepção ([+–-]\d+)([^D]*)', t)
    if not m: return None
    f['iniciativa'] = num(m.group(1)); f['percepcao'] = num(m.group(2))
    sent = [s.strip() for s in m.group(3).split(',') if s.strip()]
    if sent: f['sentidos'] = [s.replace(' ', '_') for s in sent]
    m = re.search(r'Defesa (\d+), Fort ([+–-]\d+), Ref ([+–-]\d+), Von ([+–-]\d+)', t)
    if not m: return None
    f['defesa'] = int(m.group(1)); f['fort'] = num(m.group(2)); f['ref'] = num(m.group(3)); f['von'] = num(m.group(4))
    m = re.search(r'Pontos de Vida (\d+)', t); f['pv'] = int(m.group(1)) if m else None
    m = re.search(r'Deslocamento (\d+)m', t); f['deslocamento_m'] = int(m.group(1)) if m else 9
    cc = re.search(r'Corpo a Corpo (.*?)(?:\.|À Distância)', t)
    ad = re.search(r'À Distância (.*?)\.', t)
    f['ataques'] = (ataques(cc.group(1), False) if cc else []) + (ataques(ad.group(1), True) if ad else [])
    m = re.search(r'For ([–\-+]?\d+|—), Des ([–\-+]?\d+|—), Con ([–\-+]?\d+|—), Int ([–\-+]?\d+|—), Sab ([–\-+]?\d+|—), Car ([–\-+]?\d+|—)', t)
    if not m: return None
    f['atributos'] = dict(zip(['for', 'des', 'con', 'int', 'sab', 'car'], [num(x) for x in m.groups()]))
    pm = re.search(r'Perícias (.*?)\.', t)
    if pm:
        per = {}
        for x in re.finditer(r'([A-Za-zÀ-ÿ]+) ([+–-]\d+)', pm.group(1)):
            k = x.group(1).lower().translate(str.maketrans('áéíóúâêôãõç', 'aeiouaeoaoc'))
            per[k] = num(x.group(2))
        f['pericias'] = per
    # habilidades: trechos "Nome (Ação) texto" ou "Nome texto" entre ataques e atributos
    corpo = t[t.find('Deslocamento'):m.start()]
    hab = re.findall(r'\.\s([A-ZÀ-Ú][a-zà-ÿ]+(?: [a-zà-ÿ]+)?(?: [A-ZÀ-Ú][a-zà-ÿ]+)?)(?: \((?:Livre|Movimento|Padrão|Completa|Reação)\))? [A-Z]', corpo)
    if hab: f['habilidades_texto'] = hab
    f['_texto'] = t[:1200]
    f['_pagina'] = pagina
    if f['pv'] is None or not f['ataques']: return None
    return f

out = {}
for pi, pg in enumerate(pages):
    if 'Ameaças' not in pg and 'Capítulo Sete' not in pg: continue
    mp = re.search(r'^\s*(\d{3})\s*$', pg, re.M)
    pag = int(mp.group(1)) if mp else None
    if pag is None or not (284 <= pag <= 312): continue
    for col in colunas(pg):
        ls = col.split('\n')
        heads = [i for i, l in enumerate(ls) if re.match(r'^\s*([A-ZÀ-Ú][^\d]{2,40}?)\s{2,}ND (\d+/?\d*)\s*$', l) or re.match(r'^\s*([A-ZÀ-Ú][A-Za-zÀ-ÿ\- ]{2,40}) ND (\d+/?\d*)\s*$', l)]
        for k, i in enumerate(heads):
            mh = re.match(r'^\s*(.+?)\s+ND (\d+/?\d*)\s*$', ls[i])
            fim = heads[k + 1] if k + 1 < len(heads) else len(ls)
            f = ficha(ls[i + 1:fim], mh.group(1).strip(), mh.group(2), pag)
            if f:
                cid = 'criatura.' + re.sub(r'[^a-z0-9]+', '_', mh.group(1).strip().lower().translate(str.maketrans('áéíóúâêôãõç', 'aeiouaeoaoc'))).strip('_')
                out[cid] = f
json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
print(len(out), sorted(out), file=sys.stderr)
