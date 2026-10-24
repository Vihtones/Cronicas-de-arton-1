"""Gera docs/MAPA_DO_PROJETO.md a partir do grafo do Graphify (graphify-out/graph.json).
Rode depois de tools/graphify_build.py. O arquivo é GERADO: não edite à mão.
Conteúdo: documentos, camadas e scripts, comandos (quem trata/quem envia), eventos
(quem emite/quem escuta), famílias de regras e os achados de organização."""
import collections, json, pathlib, re, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
g = json.loads((ROOT / "graphify-out" / "graph.json").read_text(encoding="utf-8"))
N = {n["id"]: n for n in g["nodes"]}
L = g["links"]
inc, out = collections.defaultdict(list), collections.defaultdict(list)
for e in L:
    out[e["source"]].append(e); inc[e["target"]].append(e)
lab = lambda i: str(N[i].get("label", i))
src = lambda i: str(N[i].get("source_file", ""))
is_test = lambda i: src(i).startswith("tests/")
first = lambda s: (re.split(r"(?<=[.!?])\s", s.strip())[0] if s else "")[:160]
commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()

md = ["# Mapa do projeto (gerado pelo Graphify)", "",
      f"Gerado por `tools/graphify_build.py` + `tools/graphify_mapa.py` a partir do commit `{commit}`. **Não edite à mão**: rode os dois scripts.",
      f"Grafo: {len(N)} nós, {len(L)} arestas. Abra `graphify-out/graph.html` para navegar. Achados com decisão humana ficam em `docs/ORGANIZACAO.md`.", ""]

# documentos
md += ["## Documentos", "", "| Documento | Assunto | Seções | Cita código/regras |", "|---|---|---|---|"]
for i, n in sorted(N.items(), key=lambda x: src(x[0])):
    if n.get("file_type") == "document" and src(i).endswith(".md"):
        secs = [e for e in out[i] if e["relation"] == "contains"]
        refs = [e for e in out[i] if e["relation"] in ("references", "cites")]
        md.append(f"| `{src(i)}` | {lab(i)} | {len(secs)} | {len(refs)} |")
md.append("")

# camadas
md += ["## Camadas e scripts", ""]
by_layer = collections.defaultdict(list)
for i, n in N.items():
    if n.get("layer") and src(i).endswith(".gd"):
        by_layer[n["layer"]].append(i)
for layer in sorted(by_layer):
    md += [f"### `{layer}`", ""]
    for i in sorted(by_layer[layer], key=lab):
        deg = len(inc[i]) + len(out[i])
        md.append(f"- **{lab(i)}** (`{src(i)}`, {deg} ligações) — {first(N[i].get('rationale', ''))}")
    md.append("")

# comandos
md += ["## Comandos (GameCommand)", "", "| Comando | Tratado por | Enviado por (jogo) | Testado por |", "|---|---|---|---|"]
for i in sorted([i for i, n in N.items() if n.get("kind") == "comando"], key=lab):
    h = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "handles"})
    s = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "sends" and not is_test(e["source"])})
    t = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "sends" and is_test(e["source"])})
    md.append(f"| {lab(i).replace('Comando ', '')} | {', '.join(h) or '—'} | {', '.join(s) or '**ninguém**'} | {', '.join(t) or '**sem teste**'} |")
md.append("")

# eventos
md += ["## Eventos e fatos (GameEvent)", "", "| Evento | Emitido por | Assinado por (domínio) | Escutado por (apresentação/testes) |", "|---|---|---|---|"]
for i in sorted([i for i, n in N.items() if n.get("kind") == "evento"], key=lab):
    em = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "emits"})
    sb = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "subscribes"})
    ls = sorted({lab(e["source"]) for e in inc[i] if e["relation"] == "listens"})
    md.append(f"| {lab(i).replace('Evento ', '')} | {', '.join(em) or '—'} | {', '.join(sb) or '—'} | {', '.join(ls[:6]) + (' …' if len(ls) > 6 else '') or '—'} |")
md.append("")

# regras por família
md += ["## Regras de Tormenta20 por família", "", "| Família | Regras | Lidas pelo código | Usada por |", "|---|---|---|---|"]
fam_users = collections.defaultdict(set)
for i, n in N.items():
    if n.get("kind") == "familia":
        for e in inc[i]:
            if e["relation"] == "uses_rule": fam_users[i].add(lab(e["source"]))
unread = []
for f in sorted([i for i, n in N.items() if n.get("kind") == "familia"], key=lab):
    members = [e["target"] for e in out[f] if e["relation"] == "contains"]
    read = [m for m in members if any(e["relation"] == "uses_rule" for e in inc[m]) or fam_users[f]]
    users = set(fam_users[f])
    for m in members:
        users |= {lab(e["source"]) for e in inc[m] if e["relation"] == "uses_rule"}
        if not any(e["relation"] == "uses_rule" for e in inc[m]) and not fam_users[f]:
            unread.append(m)
    md.append(f"| {lab(f).replace('Regras: ', '')} | {len(members)} | {len(read)} | {', '.join(sorted(users)[:5]) + (' …' if len(users) > 5 else '') or '—'} |")
md.append("")

# achados
dead_cmd = [lab(i) for i, n in N.items() if n.get("kind") == "comando" and not any(e["relation"] == "sends" and not is_test(e["source"]) for e in inc[i])]
untested = [lab(i) for i, n in N.items() if n.get("kind") == "comando" and not any(e["relation"] == "sends" and is_test(e["source"]) for e in inc[i])]
deaf = [lab(i) for i, n in N.items() if n.get("kind") == "evento" and not any(e["relation"] in ("subscribes", "listens") for e in inc[i])]
dom_nt = [lab(i) for i in by_layer.get("src/domain/modules", []) + by_layer.get("src/domain/rules", []) + by_layer.get("src/domain/combat", [])
          if not any(e["relation"] == "tests" for e in inc[i])]
md += ["## Achados automáticos", "",
       f"- **Regras conferidas que o código não lê** ({len(unread)}): o valor está escrito à mão no código, e as duas fontes podem divergir — "
       + ", ".join(f"`{lab(m).replace('Regra ', '')}`" for m in sorted(unread, key=lab)) + ".",
       f"- **Eventos que ninguém assina nem escuta** ({len(deaf)}): " + ", ".join(f"`{d.replace('Evento ', '')}`" for d in sorted(deaf)) + ".",
       f"- **Comandos que o jogo nunca envia**: " + (", ".join(f"`{d.replace('Comando ', '')}`" for d in sorted(dead_cmd)) or "nenhum") + ".",
       f"- **Comandos sem teste que os envie**: " + (", ".join(f"`{d.replace('Comando ', '')}`" for d in sorted(untested)) or "nenhum") + ".",
       f"- **Classes de domínio sem teste que as cite**: " + (", ".join(f"`{d}`" for d in sorted(dom_nt)) or "nenhuma") + ".", ""]

(ROOT / "docs" / "MAPA_DO_PROJETO.md").write_text("\n".join(md) + "\n", encoding="utf-8")
print(f"MAPA_DO_PROJETO.md: {len(md)} linhas; regras não lidas={len(unread)}, eventos sem ouvinte={len(deaf)}")
