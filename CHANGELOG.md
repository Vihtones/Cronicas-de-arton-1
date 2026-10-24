# Changelog

## [0.3.0] — 2026-10-23 — Protótipos evoluídos, XP dinâmica e interações
### Adicionado
- **XP dinâmica** (padrão; o modo do livro pode ser ligado no diário): base do LB × desempenho e circunstâncias, novidade decrescente, XP de aprendizado e de evasão, conta sempre visível. Ver `docs/XP_DINAMICA.md`.
- **Poderes de classe ao subir de nível** (`ChoosePower`):
  - Especialização em Arma, Valentão, Golpe de Raspão, Aumento de Atributo, Gatuno e Truque Mágico (LB p.65–66, 74).
  - Durão no 3º nível do guerreiro.
- **Derrubar da Hiena** como manobra livre (Bestiário p.120, LB p.234). Caído reduz o deslocamento e exige levantar.
- **Modo de tiro** no combate (tecla 6) e alcances de armas e magias pelo livro (LB p.143).
- **Penalidade de armadura** em todas as perícias marcadas (LB p.115).
- **Emboscada tática** ao partir em viagem: salteadores, teste de Percepção x Furtividade, risco causal (bando ativo; a patrulha do domínio reduz).
- **Mercado de Valkaria** com preços regionais. O herdeiro passa pela criação de personagem.
- **Interações:**
  - A farinha do domínio entra no estoque da vila.
  - Os ataques da matilha custam comida.
  - Memórias comuns são esquecidas em 30 dias, contando da data do fato original.
- **20 testes de interação** (`tests/unit/test_interactions.gd`) e um cenário novo, "Emboscada na estrada".
### Corrigido
- **Bug grave:** todas as criaturas ganhavam +2 de dano (checagem vazia da Especialização em Arma). Agora há teste de regressão.
- **Rumores travavam:** cada NPC repetia para sempre a mesma memória "principal", e notícias novas não circulavam. Agora conta o que algum presente ainda não sabe.
- **Derrubar não era aplicado:** o campo não era copiado do bloco da criatura.
- **Derrota para salteadores:** levava o jogador para a cela da cripta. Agora rouba e deixa o jogador na estrada.
- **Hiena reconferida:** os valores estão corretos no livro. O perigo vem do ND pressupor um grupo de 4 heróis.
- **Alcances** curto/médio/longo verificados (antes eram de memória).

## [0.2.0] — 2026-10-23 — Todas as mecânicas em protótipo
### Adicionado
- **Laboratório de protótipos:** 21 cenários jogáveis (`src/application/prototypes.gd`), cada um com teste (`tests/unit/test_prototypes.gd`).
- **Regras novas (18):** tabela de XP (LB p.35), XP por desafio (p.326), Anão (p.20), tabela de raças (p.18), Ladino (p.73), Arcanista (p.37), custo de magia (p.170), Seta Infalível (p.206), Curar Ferimentos (p.189), poção como ação padrão (p.234), saco de dormir (p.156), viagem (p.270), jornada pelos ermos (p.320), Khalmyr (p.99), Allihanna (p.97).
- **Módulos novos:** progression, items, travel, domain, lineage, adventurers, fauna, pacing.
- **Domínio:** `CharacterBuilder` (criação), `Biography` (histórico gerado), magia e poção no combate, Ataque Furtivo, investigação criminal sem testemunhas, preconceito individual, obrigações de Khalmyr e Allihanna, vários mistérios simultâneos ("As Ovelhas de Fenna").
- **Interface:** laboratório, criação de personagem, painel de Valkaria, seções do diário (XP, inventário com equipar/usar, domínio, gerações), sucessão na tela de morte, overlay F3, modos de magia e poção no combate.
- **Infraestrutura:** `LocalEchoProvider`, uma IA local de demonstração.
- **Documentação:** `docs/ROADMAP.md` (correções, revisões, próximos passos), `docs/PROTOTIPOS.md`, ADR-0004.
### Corrigido
- Tomas incluído entre as testemunhas do próprio resgate pela Guarda.
- Tempo de viagem passa a contar dias de calendário (marcha mais descanso).
- Descanso em Valkaria usa estalagem, não a regra da vila.

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
