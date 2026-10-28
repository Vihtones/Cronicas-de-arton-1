import re,json,unicodedata
pages=open('/home/claude/scratch_t20/lb.txt').read().split('\f')
exec(open(__file__.replace('extrair.py','colunas.py')).read().split('out=[]')[0])
# texto em ordem de leitura, com a página (livro) de cada linha
linhas=[]
for i,pg in enumerate(pages):
    for c in colunas(pg):
        for l in c.split('\n'):
            linhas.append((i,l))
LIXO=re.compile(r'^(Capítulo Quatro|Magia|\d{1,3})$')
cab=re.compile(r'^(?:(.+?)\s+)?(Arcana|Universal|Divina) (\d) \(([^)]+)\)$', re.I)
idx=[k for k,(p,l) in enumerate(linhas) if cab.match(l.strip())]
def slug(s):
    s=unicodedata.normalize('NFKD',s.lower()); s=''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]+','_',s).strip('_')
def junta(ls):
    t=''
    for l in ls:
        l=l.strip()
        if not l or LIXO.match(l): continue
        if t.endswith('-') and not t.endswith(' -'): t=t[:-1]+l
        elif t.endswith('­'): t=t[:-1]+l
        else: t=(t+' '+l).strip()
    return t.replace('­','')
magias=[]
for n,k in enumerate(idx):
    # nome: linhas não vazias logo acima (até 2), sem lixo
    nome=[];j=k-1
    vazias=0
    while j>=0 and len(nome)<3 and vazias<3:
        l=linhas[j][1].strip()
        if l and not LIXO.match(l):
            if l.endswith('.') or l.endswith(',') or ':' in l or len(l)>34 or (nome and l[0].islower()) or cab.match(l): break
            nome.insert(0,l); vazias=0
        elif not l:
            vazias+=1
        j-=1
    fim=idx[n+1] if n+1<len(idx) else len(linhas)
    # o corpo vai até o nome da próxima (2 linhas antes do cabeçalho seguinte, aproximado)
    corpo=[l for _,l in linhas[k+1:fim]]
    m=cab.match(linhas[k][1].strip())
    if m.group(1):
        nome=[m.group(1)]
    magias.append({"nome":' '.join(nome),"tipo":m.group(2).lower(),"circulo":int(m.group(3)),"escola":m.group(4),"corpo":corpo,"pdf_page":linhas[k][0]+1})
# tira do fim do corpo o nome da próxima magia
for a,b in zip(magias,magias[1:]):
    nm=b['nome'].split(' ')
    c=a['corpo']
    while c and not c[-1].strip(): c.pop()
    tail=' '.join(x.strip() for x in c[-3:])
    for _ in range(3):
        if c and c[-1].strip() and c[-1].strip() in b['nome']: c.pop()
        while c and not c[-1].strip(): c.pop()
res=[]
for m in magias:
    t=junta(m['corpo'])
    h=re.match(r'Execução: (.*?); Alcance: (.*?); (Alvos?(?: ou Área)?|Área|Efeito): (.*?); Duração: (.*?)(?:; Resistência: (.*?))?\.\s(.*)$',t)
    if not h:
        res.append({"erro":True,"nome":m['nome'],"t":t[:200]}); continue
    exe,alc,at,alvo,dur,resis,rest=h.groups()
    partes=re.split(r'(\+\d+ PM:)',rest)
    texto=partes[0].strip()
    aprs=[]
    for i in range(1,len(partes),2):
        aprs.append({"pm":int(re.search(r'\d+',partes[i]).group()),"texto":partes[i+1].strip()})
    res.append({"id":"magia."+slug(m['nome']),"valor":{"nome":m['nome'],"tipo":m['tipo'],"escola":m['escola'],"circulo":m['circulo'],"execucao":exe,"alcance":alc,
        "alvo_tipo":"Alvo" if at.startswith('Alvo') else at,"alvo":alvo,"duracao":dur,"resistencia":resis or "nenhuma","texto":texto,"aprimoramentos":aprs},
        "fonte":"T20 Livro Básico (Jambô, edição Jogo do Ano)","pagina":m['pdf_page']-6,"pdf_page":m['pdf_page'],"status":"CADASTRADA"})
json.dump(res,open('magias_extraidas.json','w'),ensure_ascii=False,indent=1)
print(len(res),sum(1 for r in res if r.get('erro')))
from collections import Counter
print(Counter(r['valor']['tipo'] for r in res if not r.get('erro')))
for r in res:
    if r.get('erro'): print('ERRO',r['nome'],'|',r['t'][:120])
