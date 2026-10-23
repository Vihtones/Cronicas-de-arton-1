# ADR-0002: Módulos do mundo, comandos e eventos

**Status:** aceito (2026-10-23)

## Decisão
- `WorldState` roteia cada comando a **um** módulo (`handled_commands`). O módulo valida **sem alterar nada**. Se houver erro, nada muda: nem estado, nem revisão, nem RNG.
- `execute` devolve **fatos**. O mundo faz **um commit** por comando: incrementa a revisão, transforma os fatos em `GameEvent` imutáveis e entrega cada um aos módulos inscritos, cujos fatos derivados entram na fila do mesmo commit (limite de 4096).
- Mudanças em outro módulo acontecem **por evento**. O checador `tools/check_architecture.py` proíbe atribuir atributos em um módulo obtido por `world.module()`.
- Exceções aceitas e documentadas:
  - `ExplorationModule.record_attempt`, a porta do anti-loop usada por objetos e diálogo.
  - O diálogo invoca `execute` de crime (pagar multa) e de NPCs (resgate), que só **produzem fatos**.
  - `world.player_sheet` e `world.player` são estado compartilhado do mundo.
- Testemunhas são capturadas **no instante** do fato (`payload.witnesses`). Sem esse campo, a memória usa quem está no local.
- O tempo avança só por `AdvanceTime` (ticks inteiros) ou por módulos que consomem tempo (`advance_ticks`, como no descanso).
- Módulos opcionais podem ser desligados. Os essenciais (state, objects) recusam desligamento.
- Snapshot: cada módulo serializa o próprio estado. Dados de módulo ausente ficam preservados.

## Consequências
- O replay com a mesma seed reproduz o jogo, e salvar e carregar continuam idênticos (há teste).
- A ordem de registro dos módulos importa para os listeners e está fixada em `WorldFactory`.
