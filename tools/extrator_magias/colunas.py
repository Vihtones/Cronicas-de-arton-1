import re,sys,json
pages=open('/home/claude/scratch_t20/lb.txt').read().split('\f')
def colunas(pg):
    lines=pg.split('\n')
    w=max((len(l) for l in lines),default=0)
    # coluna vazia = posição onde quase nenhuma linha tem caractere não-espaço (e vizinha à esquerda)
    occ=[0]*(w+1)
    for l in lines:
        for i,ch in enumerate(l):
            if ch!=' ': occ[i]+=1
    n=len([l for l in lines if l.strip()])
    gaps=[i for i in range(w) if occ[i]<=max(1,n*0.03)]
    # cortes: centros de corridas de gaps com largura >=2, longe das bordas
    cuts=[];run=[]
    for i in range(w+1):
        if i in gaps: run.append(i)
        else:
            if len(run)>=2 and run[0]>15 and run[-1]<w-15: cuts.append(run[len(run)//2])
            run=[]
    cols=[]; edges=[0]+cuts+[w+1]
    for a,b in zip(edges,edges[1:]):
        txt=[l[a:b].strip() for l in lines]
        cols.append('\n'.join(txt))
    return cols
out=[]
for i,pg in enumerate(pages):
    for c in colunas(pg): out.append(c)
open('lido.txt','w').write('\n'.join(out))
