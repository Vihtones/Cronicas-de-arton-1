"""Extração do Crônicas de Arton para o Graphify (https://github.com/Graphify-Labs/graphify).

O Graphify não tem gramática de GDScript. Este script faz, de forma determinística, a parte
"semântica" que o agente faria: lê os .gd, os documentos e as regras e escreve
graphify-out/.graphify_semantic.json no esquema do Graphify (references/extraction-spec.md).
O que vira nó:
  - cada script .gd (rótulo = class_name ou nome do arquivo), agrupado por camada;
  - comandos (GameCommand), eventos/fatos (GameEvent) e regras do T20 (data/rules);
  - documentos (docs/*.md, README, CHANGELOG) e suas seções de 2º nível.
O que vira aresta (todas EXTRACTED, 1.0 — vêm do texto do código):
  - inherits (extends), references (usa outra classe do projeto, cita um arquivo/regra),
  - handles (módulo trata comando), sends (quem envia o comando),
  - emits / subscribes (fatos e eventos), uses_rule (consulta world.rules / rules.value),
  - tests (suíte de teste cita a classe), contains (documento -> seção).
Uso: python3 tools/graphify_gdscript.py   (depois rode o passo de build do Graphify)."""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out" / ".graphify_semantic.json"


def nid(path: str, entity: str = "") -> str:
    stem = re.sub(r"\.[^./]+$", "", path)
    parts = [re.sub(r"[^a-z0-9]", "_", p.lower()) for p in stem.split("/")]
    base = "_".join(parts)
    return base + ("_" + re.sub(r"[^a-z0-9]", "_", entity.lower()) if entity else "")


nodes, edges = {}, []


def node(i, label, ftype, src, **extra):
    if i not in nodes:
        nodes[i] = {"id": i, "label": label, "file_type": ftype, "source_file": src, "source_location": None,
                    "source_url": None, "captured_at": None, "author": None, "contributor": None, "_origin": "semantic", **extra}
    return i


def edge(a, b, rel, src, loc=None):
    if a != b:
        edges.append({"source": a, "target": b, "relation": rel, "confidence": "EXTRACTED", "confidence_score": 1.0,
                      "source_file": src, "source_location": loc, "weight": 1.0, "_origin": "semantic"})


def layer(rel: str) -> str:
    for k in ["src/core", "src/domain/modules", "src/domain/combat", "src/domain/rules", "src/domain", "src/application",
              "src/infrastructure", "src/presentation/ui", "src/presentation/fx", "src/presentation/art", "src/presentation", "tests", "tools"]:
        if rel.startswith(k):
            return k
    return "outro"


gd_files = sorted(p for p in ROOT.rglob("*.gd") if ".godot" not in p.parts and not p.name.startswith("_"))
classes = {}       # class_name -> node id
texts = {}
for p in gd_files:
    rel = p.relative_to(ROOT).as_posix()
    t = p.read_text(encoding="utf-8")
    texts[rel] = t
    m = re.search(r"^class_name\s+(\w+)", t, re.M)
    label = m.group(1) if m else p.stem
    i = node(nid(rel), label, "code", rel, layer=layer(rel))
    doc = " ".join(l.strip("# ").strip() for l in t.split("\n") if l.startswith("##"))[:400]
    if doc:
        nodes[i]["rationale"] = doc
    if m:
        classes[m.group(1)] = i

# comandos tratados por módulo
cmd_owner = {}
for rel, t in texts.items():
    m = re.search(r"func handled_commands\(\)(.*?)(?=\nfunc |\Z)", t, re.S)
    if m:
        for c in re.findall(r'"(\w+)"', m.group(1)):
            ci = node("cmd_" + c.lower(), "Comando " + c, "concept", rel, kind="comando")
            edge(nid(rel), ci, "handles", rel)
            cmd_owner[c] = rel
    m = re.search(r"func subscribed_events\(\)(.*?)(?=\nfunc |\Z)", t, re.S)
    if m:
        for ev in re.findall(r'"(\w+)"', m.group(1)):
            ei = node("ev_" + ev.lower(), "Evento " + ev, "concept", rel, kind="evento")
            edge(nid(rel), ei, "subscribes", rel)

for rel, t in texts.items():
    me = nid(rel)
    lines = t.split("\n")
    for ln, line in enumerate(lines, 1):
        code = line.split("#")[0]
        m = re.match(r"^extends\s+(\w+)", code)
        if m and m.group(1) in classes:
            edge(me, classes[m.group(1)], "inherits", rel, f"L{ln}")
        for ev in re.findall(r'\bfact\("([A-Z_]*[A-Z])"', code):
            edge(me, node("ev_" + ev.lower(), "Evento " + ev, "concept", rel, kind="evento"), "emits", rel, f"L{ln}")
        for c in re.findall(r'(?:Game\.send|\.send|GameCommand\.create\([^,]*,[^,]*,|WorldHelpers\.cmd\(\w+,|_cmd_log|_cmd\(\w+,|"cmd":)\s*\(?\s*"([A-Z]\w+)"', code):
            if c in cmd_owner:
                edge(me, "cmd_" + c.lower(), "sends", rel, f"L{ln}")
        # quem reage a um evento sem assinar (match "EVENTO": na apresentação, testes etc.)
        for ev in re.findall(r'"([A-Z][A-Z0-9_]{3,}[A-Z0-9])"', code):
            if not re.search(r'fact\("' + ev, code):
                edge(me, node("ev_" + ev.lower(), "Evento " + ev, "concept", rel, kind="evento"), "listens", rel, f"L{ln}")
        for r in re.findall(r'rules\.(?:value|entry|has)\("([a-z_]+(?:\.[a-z0-9_]+)*\.?)', code):
            if r.endswith("."):   # id montado em tempo de execução ("poder." + p): liga à família
                fam = r.rstrip(".").split(".")[0]
                edge(me, node("regras_" + fam, "Regras: " + fam, "concept", "tools/build_rules.py", kind="familia"), "uses_rule", rel, f"L{ln}")
            else:
                edge(me, node("regra_" + re.sub(r"[^a-z0-9]", "_", r), "Regra " + r, "concept", "tools/build_rules.py", kind="regra"), "uses_rule", rel, f"L{ln}")
        for r in re.findall(r'world\.module\("(\w+)"\)', code):
            pass  # resolvido abaixo pelo module_id
    # referências a outras classes do projeto (uma aresta por par)
    used = set(re.findall(r"\b([A-Z][A-Za-z0-9]+)\b", "\n".join(l.split("#")[0] for l in lines)))
    for c in used:
        if c in classes and classes[c] != me:
            edge(me, classes[c], "tests" if rel.startswith("tests/") else "references", rel)

# world.module("x") -> módulo com module_id x
mod_ids = {}
for rel, t in texts.items():
    m = re.search(r'func module_id\(\) -> String: return "(\w+)"', t)
    if m:
        mod_ids[m.group(1)] = nid(rel)
for rel, t in texts.items():
    for x in set(re.findall(r'world\.module\("(\w+)"\)|modules\.(\w+)\b', t)):
        k = x[0] or x[1]
        if k in mod_ids and mod_ids[k] != nid(rel):
            edge(nid(rel), mod_ids[k], "shares_data_with", rel)

# regras: rótulo com status/página
node(nid("tools/build_rules.py"), "build_rules.py", "code", "tools/build_rules.py", layer="tools")
rules_dir = ROOT / "data" / "rules"
for f in sorted(rules_dir.glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    for r in d.get("rules", []):
        i = "regra_" + re.sub(r"[^a-z0-9]", "_", r["id"])
        node(i, "Regra " + r["id"], "concept", "tools/build_rules.py", kind="regra", status=r.get("status"), pagina=r.get("pagina"))
        nodes[i]["rationale"] = "%s, p.%s (%s)" % (r.get("fonte", ""), r.get("pagina", ""), r.get("status", ""))
        fam = r["id"].split(".")[0]
        edge(node("regras_" + fam, "Regras: " + fam, "concept", "tools/build_rules.py", kind="familia"), i, "contains", "tools/build_rules.py")
        edge(nid("tools/build_rules.py"), "regras_" + fam, "defines", "tools/build_rules.py")

# dados do mundo que apontam para regras ("rule": "criatura.hiena", ...)
for f in sorted((ROOT / "data" / "world").glob("*.json")):
    rel = f.relative_to(ROOT).as_posix()
    t = f.read_text(encoding="utf-8")
    di = node(nid(rel), f.name, "document", rel, layer="data/world")
    for r in set(re.findall(r'"rule"\s*:\s*"([a-z_]+\.[a-z0-9_.]+)"', t)):
        i = "regra_" + re.sub(r"[^a-z0-9]", "_", r)
        if i in nodes:
            edge(di, i, "uses_rule", rel)
    for rel2, t2 in texts.items():
        if f.name in t2 or ("world/" + f.stem) in t2:
            edge(nid(rel2), di, "references", rel2)

# documentos
docs = sorted(p for p in list((ROOT / "docs").rglob("*.md")) + [ROOT / "README.md", ROOT / "CHANGELOG.md"]
              if p.name != "MAPA_DO_PROJETO.md")   # o mapa é gerado a partir do grafo: não entra nele
for p in docs:
    if not p.exists():
        continue
    rel = p.relative_to(ROOT).as_posix()
    t = p.read_text(encoding="utf-8")
    title = re.search(r"^#\s+(.+)", t, re.M)
    di = node(nid(rel), title.group(1).strip() if title else p.stem, "document", rel)
    for ln, line in enumerate(t.split("\n"), 1):
        h = re.match(r"^##\s+(.+)", line)
        if h:
            hi = node(nid(rel, h.group(1)[:40]), h.group(1).strip()[:80], "rationale", rel)
            nodes[hi]["source_location"] = f"S{ln}"
            edge(di, hi, "contains", rel, f"S{ln}")
    for c in set(re.findall(r"\b([A-Z][A-Za-z0-9]+)\b", t)):
        if c in classes:
            edge(di, classes[c], "references", rel)
    for path in set(re.findall(r"`?((?:src|tools|tests|data)/[\w/.-]+\.(?:gd|py|json))`?", t)):
        target = nid(path)
        if target in nodes:
            edge(di, target, "references", rel)
    for r in set(re.findall(r"\b((?:poder|classe|raca|regra|magia|condicao|acao|situacao)\.[a-z0-9_.]+)", t)):
        i = "regra_" + re.sub(r"[^a-z0-9]", "_", r.rstrip("."))
        if i in nodes:
            edge(di, i, "cites", rel)

# evento só existe se alguém o emite ou assina (literais em MAIÚSCULAS que não são eventos saem)
real_ev = {e["target"] for e in edges if e["relation"] in ("emits", "subscribes")}
for k in [k for k in nodes if k.startswith("ev_") and k not in real_ev]:
    del nodes[k]
valid = set(nodes)
edges = [e for e in edges if e["source"] in valid and e["target"] in valid]
# remove arestas duplicadas
seen, uniq = set(), []
for e in edges:
    k = (e["source"], e["target"], e["relation"])
    if k not in seen:
        seen.add(k); uniq.append(e)
OUT.parent.mkdir(exist_ok=True)
OUT.write_text(json.dumps({"nodes": list(nodes.values()), "edges": uniq, "hyperedges": [], "input_tokens": 0, "output_tokens": 0},
                          ensure_ascii=False, indent=1), encoding="utf-8")
print(f"graphify-gdscript: {len(nodes)} nós, {len(uniq)} arestas, {len(gd_files)} scripts .gd")
