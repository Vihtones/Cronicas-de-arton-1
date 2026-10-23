# Crônicas de Arton

RPG single-player 2D top-down em pixel art, inspirado em Tormenta20.
**Estado: Fase 0 (Fundação) — código escrito, aguardando verificação na Godot.**

Fonte de verdade: `docs/PLANO_MESTRE.md` (v1.2). Plano de execução: `docs/PLANO_DE_EXECUCAO.md`.

## Requisitos
- Godot **4.3 stable** (ou 4.x compatível), renderizador GL Compatibility.

## Rodar
1. Abra a pasta na Godot (Importar → `project.godot`) e aperte F5.
2. WASD move · F5 salva · F9 carrega. O HUD mostra data/hora e eventos.

## Testes (headless)
```bash
godot --headless --path . --import          # 1ª vez: registra class_names
godot --headless --path . -s res://tests/run_tests.gd
```
Saída 0 = tudo aprovado.

## Arquitetura (camadas)
| Pasta | Camada | Pode depender de |
|---|---|---|
| `src/core` | Contratos (Command, Event, EventBus, Logger) | nada |
| `src/domain` | Regras e estado puros (WorldClock, RNG, WorldState) | core |
| `src/infrastructure` | Persistência JSON atômica | core |
| `src/application` | Composição (`Game` autoload) | todas acima |
| `src/presentation` | Cenas, câmera, HUD | application (lê projeções, envia comandos) |

Domínio nunca importa Node, câmera, HTTP ou banco.
