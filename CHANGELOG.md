# Changelog

## [0.1.0] — 2026-10-23 — Vertical slice (Fases 1–7 no escopo do slice)
### Adicionado
- **Regras:** `RuleRegistry` com 58 regras extraídas do Livro Básico e do Bestiário, cada uma com fonte, página impressa, página do PDF e status. `CharacterSheet`, `Checks` e `Dice` seguem LB p.114, 220, 230–239 e 394.
- **Mundo modular:** `WorldModule` com validate/execute/on_tick/on_event, commit único por comando, journal compacto e preservação de dados de módulos ausentes.
- **Módulos:** state, objects, npcs, weather, exploration, memory, factions, combat, dialogue, crime, economy, region_sim, religion.
- **Conteúdo original:** mapa 96×64 (vila, estrada, rio, floresta, ruína, cripta), 25 NPCs com agendas, 5 famílias, 3 facções, o mistério "O Filho do Moleiro" e 10 árvores de diálogo.
- **Combate:** `CombatSim`, `GhostPlanner`, IA inimiga, captura e morte.
- **Apresentação:** tilemap com colisão, atores animados, câmera cinematográfica, dia/noite, luzes, chuva, neblina, combate visual com fantasma e UI completa (título, HUD, diálogo, diário, loja, pausa, opções, fim de jogo).
- **Arte provisória original** gerada por script, com manifesto e validador.
- **IA opcional** (`LlmDialogueProvider`) com limite de chamadas, timeout, cache, validação de saída e auditoria.
- **Ferramentas:** benchmark, capturas automáticas, checagem de arquitetura, CI e relatório de regras.
- **Testes:** 71 testes de invariantes, sistemas e ponta a ponta.
### Mudado
- Formato de save: schema v2, com migração automática de v1.
- `WorldState` passa a incluir o estado do barramento de eventos (determinismo após load).
### Corrigido durante a verificação
- Testemunhas registradas antes de o resgatado sair do local.
- Checksum estável com a conversão int/float do JSON.
- Referência fraca mundo↔módulo para evitar vazamento por ciclo.
- Combate encerra um diálogo aberto por evento, sem escrever no estado do módulo de diálogo.

## [0.0.1] — 2026-10-23 — Fase 0
- Projeto Godot mínimo, contratos, relógio, RNG, save atômico e 18 testes.
