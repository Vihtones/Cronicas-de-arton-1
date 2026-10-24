"""Executa a suíte headless e reprova testes com erro de script em tempo de execução (C23).

O executor GDScript não consegue saber se um método de teste foi abortado por erro do motor
(o chamador continua normalmente). Este wrapper lê a saída: qualquer "SCRIPT ERROR" entre
"RUN x" e o resultado de x reprova x, mesmo que ele tenha impresso OK.
Uso: python3 tools/run_tests.py [caminho_do_godot]"""
import os, re, subprocess, sys

godot = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GODOT", "godot")
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = subprocess.run([godot, "--headless", "--path", root, "-s", "res://tests/run_tests.gd"],
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=900)
current, errored, ok, fail, compile_fail = None, {}, [], [], []
for line in p.stdout.splitlines():
    m = re.match(r"\s+RUN\s+(\S+)", line)
    if m:
        current = m.group(1); continue
    if "SCRIPT ERROR" in line and current:
        errored.setdefault(current, line.strip())
    m = re.match(r"\s+OK\s+(\S+)", line)
    if m: ok.append(m.group(1)); current = None; continue
    m = re.match(r"\s+FAIL\s+(\S+)", line)
    if m:
        (fail if "::" in m.group(1) else compile_fail).append(line.strip()); current = None
# Boot real do jogo (com autoloads): pega erros de parse na apresentação, que a suíte não carrega.
boot = subprocess.run([godot, "--headless", "--path", root, "--quit-after", "120"],
                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
boot_errs = [l.strip() for l in boot.stdout.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
bad = [t for t in ok if t in errored]
for t in bad: print(f"  FAIL {t} -> erro de script: {errored[t]}")
for f in fail + compile_fail: print("  " + f)
total_ok = len(ok) - len(bad)
for e in boot_errs[:10]: print("  FAIL boot do jogo -> " + e)
total_fail = len(fail) + len(compile_fail) + len(bad) + (1 if boot_errs else 0)
print(f"Resultado: {total_ok} aprovados, {total_fail} falhos ({len(bad)} por erro de script)")
sys.exit(1 if total_fail else 0)
