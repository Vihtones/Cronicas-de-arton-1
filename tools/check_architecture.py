"""Checagem estática de dependências entre camadas (§5, risco R3).
- Domínio (src/domain, src/core) não usa Node, cenas, câmera, HTTP, Input nem o autoload Game.
- Infraestrutura não depende de Apresentação.
- Módulos não escrevem no estado interno de outro módulo (padrão `.modules.X.state =`).
Uso: python3 tools/check_architecture.py  (saída 1 se houver violação)"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FORBIDDEN_DOMAIN = [r"\bextends\s+Node", r"\bNode2D\b", r"\bCamera2D\b", r"\bHTTPRequest\b", r"\bInput\.", r"\bGame\.", r"get_tree\(",
                    r"\bAnimationPlayer\b", r"res://scenes", r"\bPresentation\b", r"\bActorView\b", r"\bUiRoot\b"]
CROSS_WRITE = re.compile(r"world\.module\(\"(\w+)\"\)\.(\w+)\s*\[?.*\]?\s*=(?!=)")
errors = []
for p in (ROOT / "src").rglob("*.gd"):
    rel = p.relative_to(ROOT).as_posix()
    text = p.read_text(encoding="utf-8")
    code = "\n".join(l.split("#")[0] for l in text.split("\n"))
    if rel.startswith("src/domain") or rel.startswith("src/core"):
        for pat in FORBIDDEN_DOMAIN:
            for m in re.finditer(pat, code):
                line = code[:m.start()].count("\n") + 1
                errors.append(f"{rel}:{line}: domínio referencia '{m.group(0)}'")
        for m in CROSS_WRITE.finditer(code):
            line = code[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{line}: escrita direta no estado do módulo '{m.group(1)}'")
    if rel.startswith("src/infrastructure"):
        for pat in [r"\bActorView\b", r"\bUiRoot\b", r"res://scenes", r"\bWorldView\b"]:
            if re.search(pat, code):
                errors.append(f"{rel}: infraestrutura depende da apresentação ({pat})")
# variáveis que guardam outro módulo: proíbe atribuir atributos nelas (só métodos/consulta)
ALIAS = re.compile(r"var\s+(\w+)(?::\s*\w+)?\s*=\s*world\.module\(\"(\w+)\"\)")
for p in (ROOT / "src" / "domain").rglob("*.gd"):
    rel = p.relative_to(ROOT).as_posix()
    lines = p.read_text(encoding="utf-8").split("\n")
    aliases = {}
    for i, l in enumerate(lines, 1):
        m = ALIAS.search(l)
        if m:
            aliases[m.group(1)] = m.group(2)
        for a, mod in aliases.items():
            if re.search(rf"\b{a}\.\w+(\.\w+|\[[^\]]*\])*\s*(=|\+=|-=)(?!=)", l.split("#")[0]):
                errors.append(f"{rel}:{i}: escreve no estado do módulo '{mod}' via '{a}'")
for e in errors:
    print("VIOLAÇÃO", e)
print(f"arquitetura: {len(errors)} violações")
sys.exit(1 if errors else 0)
