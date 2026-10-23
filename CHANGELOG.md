# Changelog

## [0.0.1] — 2026-10-23 — Fase 0 (não verificada em engine)
### Adicionado
- Projeto Godot 4.3 mínimo, resolução interna 640×360, filtro nearest.
- Contratos `GameCommand`/`GameEvent` conforme §6; `EventBus` com deduplicação por `event_id`.
- `WorldClock` com ticks inteiros, calendário configurável e agendamentos.
- `RngStreams`: fluxos combat/weather/world/visual com estado salvável.
- `WorldState` com comandos `MovePlayer` e `AdvanceTime`, revisão e snapshot.
- `JsonSaveRepository`: escrita atômica, checksum SHA-256, backup e recuperação, ganchos de migração.
- Cena `main.tscn` com jogador placeholder, colisão, câmera suave, dia/noite simples e HUD.
- 18 testes de invariantes (fantasma ainda não existe; ver Fase 3).
