# Roadmap: próximos passos, correções e revisões

Atualizado em 24/10/2026 para a versão 0.7.0 (Godot 4.7.2). Estado: 165 testes passando, mais a checagem de boot do jogo; 0 violações de arquitetura; 0 apontamentos de estilo; 136 regras (135 verificadas, 1 adaptada, 0 pendentes). Mapa gerado do código: `docs/MAPA_DO_PROJETO.md`.

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

### Feitas na 0.5.0
| # | Resultado |
|---|---|
| R1 | 6 regras conferidas com citação do livro (`docs/REGRAS.md`) |
| C21 | 11 poderes com pré-requisitos; Ataque Reflexo como reação |
| C7/C8 | NPCs nascidos no jogo (registro dinâmico no save) e casamentos |
| C11 | `NpcStats` pela Tabela 7-2; Guarda com ND 2 e 1/2 |
| C10 | Hienas acompanham a mudança de toca |
| C15 | 7 dias em cerca de 150 ms (teste: < 1 s) |
| C16 | Vazamentos zerados |

### Feitas na 0.6.0
| # | Resultado |
|---|---|
| C24 | Gatilho de desprevenido (`apply_condition`) e Kael com poderes |
| C25 | Crianças crescem (6 anos: criança; 16: aprendiz) |
| C27 | Ataque Especial escalonado e Ataque Extra |
| Build | Executável real com ANGLE, modo seguro e autoteste |

### Feitas na 0.7.0
| # | Resultado |
|---|---|
| Motor | Godot 4.7.2: fim da cintilação preta da 4.3; salvamentos comparados por valor |
| Mundo | Feira semanal, Festa de Alvorada, clima que muda aos poucos, figurantes, carroças |
| Visual | Casas com telhado e fachada, caminhos orgânicos, HUD com minimapa e cinto de atalhos |
| Poderes | Árvore de poderes com 8 poderes gerais do LB p.124-131 |
| A4 | Blur seletivo já existia desde a 0.6.0 (`PostProcess`); parallax segue pendente |

### Pendentes
| # | Problema | Onde | Sugestão |
|---|---|---|---|
| C28 | Habilidades ativas das raças ainda sem sistema (lista "pendente" em cada regra: Armadura de Allihanna, Sorte Salvadora, Olhar Atordoante, Mau Cheiro, Magia das Fadas, Canção dos Mares, Luz/Escuridão, ataques extras de chifres e mordida) | `data/rules`, `CombatModule` | lote por tipo: ações de movimento com PM, magias raciais |
| C29 | O deslocamento de natação e o voo (sereia, sílfide) não têm terreno de água ou altura no mapa | mapa, `CombatSim` | quando houver rios atravessáveis e desníveis |
| A5 | Retratos e visuais de raça são provisórios (procedurais) | `Portrait`, `RaceLook` | retratos aprovados pelo governador (papel "retrato") |
| A6 | Luz sem *normal maps* (exige arte aprovada) | `FxLayer` | após a prova de escala |
| A7 | Fontes: usa a fonte padrão da Godot (fonte externa exige aprovação de asset) | tema da UI | escolher uma fonte com licença aberta e aprová-la |
| C26 | NPCs sem gênero no catálogo; os casamentos ignoram gênero | `build_content.py` | adicionar o campo e decidir a regra (decisão de design) |
| A1 | Arte: prova de escala (personagem de cerca de 28 px diante das árvores LPC, que pressupõem cerca de 48 px) | `assets/chars`, governador | rua + árvore + 2 personagens, comparada com o piloto v04 |
| A2 | Arte: verdes tropicais do LPC Jungle ainda sem harmonização com o bioma | lote 02 | v02 recolorida, **com aprovação do usuário** |
| A3 | Arte: 3 plantas altas aprovadas sem papel | `direcao_de_arte.json` | decidir após A1 |
| A4 | Arte: parallax (AD-12) não implementado; o blur seletivo (AD-13) já existe | `fx_layer.gd` | depois de A1 |

### Organização (achados do Graphify, detalhes em `docs/ORGANIZACAO.md`)
| # | Problema | Onde | Sugestão |
|---|---|---|---|
| O1 | 35 regras conferidas que o código não lê (o valor está repetido à mão) | `CombatSim`, `CharacterSheet`, `StateModule`… | ler da regra, um lote por família, com teste de igualdade |
| O2 | 9 eventos sem ninguém que reaja (o jogador não fica sabendo de `MYSTERY_LOST`, `FACTION_ALERTED`, `STOLEN_GOODS_RECOVERED`) | `Narrator`, UI | narrar os que importam ao jogador; marcar os demais como só registro |
| O3 | 4 comandos sem teste (`CastSpell`, `UseItem`, `MarkHypothesis`, `GrantDomain`) | `tests/unit` | um teste por comando |
| O4 | 5 módulos de domínio sem teste próprio (Fauna, Items, Objects, RegionSim, State) | `tests/unit` | suítes curtas |

## B. Revisões humanas
| # | O que revisar |
|---|---|
| R1 | ~~6 regras pendentes~~: conferidas na 0.5.0. Revisar só as citações, se quiser |
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
2. **Revisão dos poderes novos** no laboratório ("Poderes de classe").
3. **Prova de escala de arte (A1)** quando você decidir aprovar sprites.
4. **C24–C27:** gatilhos de reação, crescimento das crianças, gênero e poderes de nível alto.
5. **Heróis de Arton (R9):** primeiras classes e raças.
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


## E. Feedback de jogo (0.7.0, jogador) — lotes propostos
Fato (relato do usuário) e proposta separados. Nada abaixo foi iniciado, exceto o item 0.

0. **FEITO:** exploit de XP por fuga (entrar/sair da visão). Fuga e captura = 0 XP; evasão furtiva rende uma vez por criatura. Testes novos.
1. **FEITO (0.7.1):** **Combate dinâmico:** pré-visualização "fantasma" do sprite do jogador andando até o alvo e executando a ação (atacar) antes de confirmar.
2. **Diálogos (parcial, 0.7.1):** FEITO: voz por registro (7 registros, 21 profissões) com hora, clima, feira/festa, reputação e mistério; memória de conversa (primeira vez, mesmo dia, retorno após dias, assunto repetido); submenu "Conversar sobre outra coisa" (rumores, trabalho, tempo, eventos, opinião sobre cada morador, biografia). **Falta:** árvores autorais para os 13 moradores que só têm a voz genérica; reação a feitos do jogador (resgate, crime, dívida); falas com consequência (favores, segredos).
3. **FEITO (0.7.1):** **Falas em balão:** conversas de 4 falas que alternam entre os dois figurantes e seguem o contexto (chuva, mistério, feira, festa, noite); pregões por mercadoria; crianças, ocupados e passantes por contexto; moradores reconhecem o jogador que passa (latido por registro e reputação, uma vez por dia).
4. **Comportamento dos NPCs:** simplório; rotinas com objetivos, necessidades e reações.
5. **Mapa e viagem:** mapa limitado; a viagem de Valkyria não troca de cenário (precisa de cenários/regiões reais).
6. **Carruagens:** hoje só cruzam a tela; dar origem, destino, passageiros e efeito no mundo.
7. **Casas e lugares:** design aprovado como "legalzinho"; refinar depois dos itens acima.
