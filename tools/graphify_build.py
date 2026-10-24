"""Gera o grafo de conhecimento do projeto com o Graphify (pipeline da skill /graphify, passos 2-6).
1. detect + AST do Graphify (scripts Python das ferramentas);
2. tools/graphify_gdscript.py (GDScript, comandos, eventos, regras e documentos);
3. mescla, monta, agrupa em comunidades, nomeia as comunidades e gera GRAPH_REPORT.md e graph.html.
Nada vai para modelos de IA (GRAPHIFY_BACKEND=none). Uso: python3 tools/graphify_build.py"""
import collections, json, os, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
os.chdir(ROOT)
os.environ.setdefault("GRAPHIFY_BACKEND", "none")
os.environ.setdefault("GRAPHIFY_QUERY_LOG_DISABLE", "1")
OUT = pathlib.Path("graphify-out")
OUT.mkdir(exist_ok=True)
(OUT / ".graphify_python").write_text(sys.executable, encoding="utf-8")

from graphify.detect import detect
from graphify.paths import out_path
from graphify.watch import _read_build_excludes, _read_build_gitignore
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json

det = detect(pathlib.Path("."), extra_excludes=_read_build_excludes(out_path()), gitignore=_read_build_gitignore(out_path()))
(OUT / ".graphify_detect.json").write_text(json.dumps(det, ensure_ascii=False), encoding="utf-8")
code = []
for f in det.get("files", {}).get("code", []):
    code.extend(collect_files(pathlib.Path(f)) if pathlib.Path(f).is_dir() else [pathlib.Path(f)])
ast = extract(code, cache_root=pathlib.Path("."), root=pathlib.Path(".")) if code else {"nodes": [], "edges": []}
subprocess.run([sys.executable, "tools/graphify_gdscript.py"], check=True)
sem = json.loads((OUT / ".graphify_semantic.json").read_text(encoding="utf-8"))
seen = {n["id"] for n in ast["nodes"]}
nodes = list(ast["nodes"]) + [n for n in sem["nodes"] if n["id"] not in seen]
extraction = {"nodes": nodes, "edges": ast["edges"] + sem["edges"], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}
(OUT / ".graphify_extract.json").write_text(json.dumps(extraction, ensure_ascii=False), encoding="utf-8")

G = build_from_json(extraction, root=".", directed=True)
communities = cluster(G)
cohesion = score_all(G, communities)

# Nome de cada comunidade: o rótulo do membro mais conectado + o tipo dominante (camada/regra/doc).
KIND = {"comando": "comandos", "evento": "eventos", "regra": "regras", "familia": "regras"}
labels = {}
for cid, mem in communities.items():
    hub = max(mem, key=lambda n: G.degree(n))
    kinds = collections.Counter(G.nodes[n].get("layer") or KIND.get(G.nodes[n].get("kind", ""), G.nodes[n].get("file_type", "")) for n in mem)
    k, _ = kinds.most_common(1)[0]
    name = str(G.nodes[hub].get("label", hub)).replace("Regra ", "").replace("Evento ", "").replace("Comando ", "")
    labels[cid] = f"{name[:32]} ({k})" if len(mem) > 1 else name[:40]

gods = god_nodes(G)
surprises = surprising_connections(G, communities)
questions = suggest_questions(G, communities, labels)
(OUT / "graph.json").unlink(missing_ok=True)   # reconstrução completa: a guarda de encolhimento não se aplica
to_json(G, communities, str(OUT / "graph.json"), community_labels=labels)
report = generate(G, communities, cohesion, labels, gods, surprises, det, {"input": 0, "output": 0}, ".", suggested_questions=questions)
(OUT / "GRAPH_REPORT.md").write_text(report, encoding="utf-8")
(OUT / ".graphify_labels.json").write_text(json.dumps({str(k): v for k, v in labels.items()}, ensure_ascii=False), encoding="utf-8")
(OUT / ".graphify_analysis.json").write_text(json.dumps({"communities": {str(k): v for k, v in communities.items()},
    "cohesion": {str(k): v for k, v in cohesion.items()}, "gods": gods, "surprises": surprises, "questions": questions}, ensure_ascii=False), encoding="utf-8")
subprocess.run(["graphify", "export", "html"], check=False)
print(f"grafo: {G.number_of_nodes()} nós, {G.number_of_edges()} arestas, {len(communities)} comunidades")
