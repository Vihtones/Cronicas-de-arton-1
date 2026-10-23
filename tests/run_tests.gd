extends SceneTree
## Executor de testes headless, sem dependências externas.
## Uso: godot --headless --path . -s res://tests/run_tests.gd
## Código de saída 0 = todos passaram; 1 = falhas.

const SUITES := [
	"res://tests/unit/test_event_bus.gd",
	"res://tests/unit/test_world_clock.gd",
	"res://tests/unit/test_rng.gd",
	"res://tests/unit/test_world_state.gd",
	"res://tests/unit/test_save_repository.gd",
]


func _init() -> void:
	var passed := 0
	var failed := 0
	for path in SUITES:
		var suite = load(path).new()
		for m in suite.get_method_list():
			var n: String = m.name
			if not n.begins_with("test_"):
				continue
			suite.failures.clear()
			suite.call(n)
			if suite.failures.is_empty():
				passed += 1
				print("  OK   %s::%s" % [path.get_file(), n])
			else:
				failed += 1
				print("  FAIL %s::%s -> %s" % [path.get_file(), n, "; ".join(suite.failures)])
	print("\nResultado: %d aprovados, %d falhos" % [passed, failed])
	quit(1 if failed > 0 else 0)
