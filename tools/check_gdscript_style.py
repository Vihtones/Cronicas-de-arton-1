"""Checagem de estilo GDScript (orientações do pacote godot-claude-skills, skill godot-code-gen):
- toda função declara tipo de retorno (`-> T`);
- toda variável de membro declara tipo (`var x: T` ou `var x := valor`);
- parâmetros com tipo;
- `connect("sinal", self, "metodo")`, `yield`, `instance()` e `export var` (sintaxe da Godot 3) são proibidos.
Uso: python3 tools/check_gdscript_style.py [--strict]  (sem --strict só informa; com --strict sai 1 se houver problemas)"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FUNC = re.compile(r"^\s*(static\s+)?func\s+(\w+)\s*\(([^)]*)\)\s*(->\s*[\w\[\]\.]+)?\s*:")
MEMBER = re.compile(r"^(static\s+)?var\s+(\w+)\s*(:\s*[\w\[\]\.]+|:=)?")
GODOT3 = [(re.compile(r"\byield\s*\("), "yield (use await)"), (re.compile(r"\.instance\(\)"), "instance() (use instantiate())"),
          (re.compile(r"^\s*export\s+var"), "export var (use @export)"), (re.compile(r"connect\(\s*\"\w+\"\s*,\s*self"), "connect antigo")]
problems = []
files = list((ROOT / "src").rglob("*.gd")) + list((ROOT / "tools").glob("*.gd"))
for p in files:
    rel = p.relative_to(ROOT).as_posix()
    for i, line in enumerate(p.read_text(encoding="utf-8").split("\n"), 1):
        code = line.split("#")[0]
        m = FUNC.match(code)
        if m:
            if not m.group(4):
                problems.append(f"{rel}:{i}: função '{m.group(2)}' sem tipo de retorno")
            for prm in [x.strip() for x in m.group(3).split(",") if x.strip()]:
                name = prm.split("=")[0].strip()
                if ":" not in name and ":=" not in prm:
                    problems.append(f"{rel}:{i}: parâmetro '{name}' de '{m.group(2)}' sem tipo")
        mm = MEMBER.match(code)
        if mm and not mm.group(3):
            problems.append(f"{rel}:{i}: variável de membro '{mm.group(2)}' sem tipo")
        for rx, what in GODOT3:
            if rx.search(code):
                problems.append(f"{rel}:{i}: sintaxe da Godot 3: {what}")
for x in problems:
    print("ESTILO", x)
print(f"estilo GDScript: {len(problems)} apontamentos em {len(files)} arquivos")
sys.exit(1 if problems and "--strict" in sys.argv else 0)
