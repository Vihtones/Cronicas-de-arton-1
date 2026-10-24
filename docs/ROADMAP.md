# Roadmap: próximos passos, correções e revisões

Atualizado em 24/10/2026 para a versão 0.4.0. Estado: 127 testes passando, com erros de script detectados (C23); 0 violações de arquitetura; 94 regras (87 verificadas, 6 pendentes de revisão).

## A. Correções

### Feitas na 0.3.0
| # | Item | Resultado |
|---|---|---|
| C1 | Hiena "errada" | **Não era erro de dado:** reconferida com layout, o livro diz Mordida +9 (1d6+7, ×3) e Derrubar. O perigo vem do ND pressupor grupo de 4. A resposta veio pela XP dinâmica (bônus por desafio) e pela escolha de conteúdo, sem escalonar inimigos |
| C2 | Alcances de memória | Verificados (LB p.143). Armas e magia usam a regra |
| C3 | Poderes ao subir de nível | 6 poderes e o Durão implementados, com escolha no diário |
| C6 | Emboscada abstrata | Emboscada tática na partida, com combate real |
| C9 | Herdeiro sem criação | O herdeiro passa pela tela de criação |
| C12 | Domínio fora da economia | Farinha entra no estoque; a patrulha reduz o risco da estrada |
| C13 | Valkaria sem compras | Mercado com preços regionais |
| C14 | Sem modo de tiro | Tecla 6 (Atirar) |
| C18 | Penalidade de armadura parcial | Aplicada em todas as perícias marcadas |
| C19 | Sem esquecimento | Memórias comuns somem em 30 dias, contando da data do fato |
| novo | Criaturas com +2 de dano indevido | Corrigido, com teste de regressão |
| novo | Rumores travados | Corrigido: o NPC conta o que alguém presente ainda não sabe |
| novo | Derrota para salteadores levava à cripta | Corrigido: roubo e despertar na estrada |

### Feitas na 0.4.0
| # | Resultado |
|---|---|
| C4 | Caminhos Bruxo, Feiticeiro e Mago; Armadura Arcana e Toque Chocante. Pendentes: a 4ª magia do Mago, a linhagem do Feiticeiro e a memorização (ADAPTADA em `docs/REGRAS.md`) |
| C5 | Vontade quando caído ou em tempestade; Misticismo de armadura. Pendente: ser ferido durante a execução (precisa de reações) |
| C17 | Escolha de perícias da classe e livres (Int/Versátil) |
| C20 | Políticas de Golpe de Raspão e Durão, mais a troca por turno (R) |
| C22 | Janela de resumo da XP |
| C23 | `tools/run_tests.py` reprova testes com erro de script |

### Pendentes
| # | Problema | Onde | Sugestão |
|---|---|---|---|
| C7/C8 | Bebês não viram NPCs; casais fixos | `LineageModule` | registro de NPCs dinâmicos |
| C10 | Toca nova não move hienas | `FaunaModule` | posição por toca |
| C11 | Capitã com +4 fixo | `CrimeModule` | fichas de NPC pela Tabela 7-2 (LB p.322) |
| C15 | `AdvanceTime` de 7 dias leva cerca de 300 ms | `MemoryModule`, `NpcModule` | lotes por região (LOD L2) |
| C16 | 8 recursos vazando ao sair dos testes | lambdas do `CombatSim` | `Callable` de método |
| C21 | Ímpeto, Ataque Reflexo e outros poderes do LB ainda não existem | `ProgressionModule.POWERS` | próximo lote de poderes |
| A1 | Arte: prova de escala (personagem de cerca de 28 px diante das árvores LPC, que pressupõem cerca de 48 px) | `assets/chars`, governador | rua + árvore + 2 personagens, comparada com o piloto v04 |
| A2 | Arte: verdes tropicais do LPC Jungle ainda sem harmonização com o bioma | lote 02 | v02 recolorida, **com aprovação do usuário** |
| A3 | Arte: 3 plantas altas aprovadas sem papel | `direcao_de_arte.json` | decidir após A1 |
| A4 | Arte: parallax e blur seletivo (AD-12 e AD-13) não implementados | `fx_layer.gd` | depois de A1 |

## B. Revisões humanas
| # | O que revisar |
|---|---|
| R1 | **6 regras PENDENTE_REVISAO** (`docs/REGRAS.md`): Defesa base, duração do descanso, panteão, poção, CD da jornada, funda |
| R2 | Balanceamento: 4 em 6 vitórias contra 3 bandidos (Guerreiro 1º nível); hienas à noite são letais para 1 personagem solo, como no livro |
| R3 | **Pesos da XP dinâmica** (`docs/XP_DINAMICA.md`): ritmo de subida, teto de ×2, valor de cada tática |
| R4 | Ritmo do relógio (2 s = 10 min) e prazo do bando (12 dias) |
| R5 | Clareza das pistas sem marcadores |
| R6 | Direção visual (Art Bible) |
| R7 | Tabela de mecânicas ORIGINAL e ADAPTADA em `docs/REGRAS.md` |
| R8 | Poderes automáticos (C20): o jogador quer decidir cada uso? |
| R9 | Prioridade dos conteúdos do Heróis de Arton |
| R10 | **Floresta com LPC Jungle** (capturas `06b`–`06d`): densidade, alfa das copas, uso na estrada |

## C. Próximos passos
1. **Playtest com o Laboratório** (R2–R5), anotando a XP dinâmica de cada luta.
2. **R1:** fechar as 6 regras pendentes.
3. **Prova de escala de arte (A1)** quando você decidir aprovar sprites.
4. **C21:** Ímpeto, Ataque Reflexo e reações (destrava o resto de C5).
5. **Heróis de Arton (R9):** primeiras classes e raças.
6. **C7/C8:** gerações completas.
7. **C15:** LOD L2 para avançar dias rapidamente.
8. **R6:** arte final da cena piloto.
9. Segundo mistério completo e segunda vila.
10. Builds exportadas e medição em hardware real.

## D. Interações já testadas (`tests/unit/test_interactions.gd`)
- Combate → XP dinâmica com conta detalhada → nível → poder → ficha usada no próximo combate.
- Hiena derruba → caído (1 quadrado de deslocamento) → precisa levantar.
- Domínio:
  - imposto alto → agitação → ressentimento dos Brandt (reputação);
  - produção → estoque da vila;
  - patrulha → estrada mais segura.
- Fauna faminta → ovelhas mortas → menos comida; Fenna culpa lobos → a crença errada se espalha pela família; matar a matilha resolve o 2º mistério.
- Morte de Teodoro → herança para Elsa → luto na memória → vinheta onde Elsa está.
- Aventureiros em Valkaria (L3) → notícias com Saria → a vila sabe (L1).
- Neblina → viagem pela metade da velocidade e camuflagem em combate.
- Allihanna impede equipar metal; Truque Mágico dá Seta Infalível ao Ladino.
- Emboscada tática → combate real; derrota para salteadores → roubo, não cela.
