# Roadmap: próximos passos, correções e revisões

Atualizado em 23/10/2026 para a versão 0.2.0. Estado atual: 88 testes passando, 0 violações de arquitetura, 12 assets validados.

As seções estão em ordem de prioridade. Cada item aponta para o arquivo onde a mudança deve ser feita.

---

## A. Correções (bugs e limitações conhecidas)

| # | Problema | Impacto | Onde | Correção sugerida |
|---|---|---|---|---|
| C1 | **Bloco da Hiena provavelmente errado** (Mordida +9, 1d6+7, ×3 num ND 1): mata personagem de 1º nível em 2 golpes | alto: o protótipo de magia teve de ir para a cripta | `tools/build_rules.py` (`criatura.hiena`) | conferir no Bestiário p.120 (PDF 122); o layout em colunas pode ter misturado Hiena e Hienodonte |
| C2 | Alcance curto/médio/longo (9/30/90 m) veio de memória; a Seta usa 20 quadrados fixos | médio | `alcance.metros`, `GhostPlanner` (cast) | ler a tabela de alcances no LB; ligar o `cast` a `alcance.metros` |
| C3 | Poderes de classe ao subir de nível são só um contador (`pending_powers`) | alto para a progressão | `ProgressionModule._level_up` | catálogo de poderes do Guerreiro e do Ladino (LB p.65 e 73) e comando `ChoosePower` |
| C4 | Arcanista só conhece 1 das 3 magias iniciais; sem Caminho (mago/feiticeiro/bruxo); atributo-chave fixo em Int | médio | `CharacterBuilder`, `data/rules` | extrair 2 magias de 1º círculo; implementar o Caminho (LB p.37–39) |
| C5 | Teste de concentração ao lançar magia em situação difícil (LB p.170) não implementado | baixo | `CombatModule._cast` | Vontade CD conforme o livro ao lançar com dano recebido no turno |
| C6 | Emboscada de viagem é abstrata (perde PV/ouro) | médio | `TravelModule.execute` | abrir um combate tático num mapa de estrada (reusar `CombatSim`) |
| C7 | Bebês nascem só como registro; não viram NPCs no mapa | baixo | `LineageModule` | registro de NPCs dinâmicos em `NpcModule` (definição criada no estado, não no catálogo) |
| C8 | Nascimentos usam casais fixos, sem gênero nem casamento | baixo | `LineageModule.COUPLES` | campo de cônjuge nos NPCs; idade fértil por indivíduo |
| C9 | O herdeiro não tem laço familiar real nem passa pela criação de personagem | médio | `LineageModule.execute`, tela de fim de jogo | abrir a criação de personagem; registrar o herdeiro como parente do falecido |
| C10 | Matilha: a "toca nova" não move as hienas no mapa; máximo de 4 vagas | baixo | `FaunaModule`, `build_content.py` | posição por toca; vagas dinâmicas |
| C11 | A capitã investiga com +4 fixo (sem ficha) | baixo | `CrimeModule._investigate` | fichas de NPC (ND/tabela 7-2 do LB p.322) |
| C12 | Domínio com números arbitrários; produção não alimenta o estoque da economia | médio | `DomainModule.on_tick` | ligar produção/consumo a `EconomyModule.regions.vila` |
| C13 | Valkaria é só um painel (sem compras nem NPCs) | médio | `ui_root.gd` (`refresh_hub`) | lojas com os preços regionais; NPCs fixos da capital |
| C14 | O jogador não tem modo próprio de ataque à distância (arco): clicar no inimigo leva a se aproximar | médio | `combat_view.gd` (`candidate_actions`) | modo "atirar" que não gera movimento |
| C15 | `AdvanceTime` de 7 dias leva cerca de 300 ms (NPCs e rumores por hora) | baixo | `MemoryModule.on_tick`, `NpcModule.on_tick` | processar em lotes por região (LOD L2) quando o jogador está longe |
| C16 | Vazamento de 8 recursos ao sair nos testes | baixo | lambdas do `CombatSim`, caches estáticos de `WorldHelpers` | trocar lambdas por `Callable` de método; limpar caches no fim da suíte |
| C17 | Perícias da classe são escolhidas por padrão; Versátil e Int não são escolhas do jogador | médio | `CharacterBuilder.DEFAULT_CHOICES`, UI de criação | tela de seleção de perícias |
| C18 | Penalidade de armadura só é aplicada na Furtividade do encontro | baixo | `CharacterSheet.skill_value` | aplicar a todas as perícias marcadas com "armadura" (LB p.115) |
| C19 | NPCs não lembram de crimes ao longo de muitos anos (sem esquecimento nem revisão) | baixo | `MemoryModule._trim` | prazo de revisão por memória (§8) |
| C20 | Algumas mensagens do registro são genéricas ou ausentes | baixo | `narrator.gd` | completar textos dos eventos novos |

## B. Revisões humanas (decisões que o jogo não pode tomar sozinho)

| # | O que revisar | Como |
|---|---|---|
| R1 | **8 regras PENDENTE_REVISAO**: Hiena, Defesa base, duração do descanso, alcances, panteão (obrigações), poção, CD da jornada, funda | abrir `docs/REGRAS.md`, conferir a página e mudar o status para VERIFICADA em `tools/build_rules.py` |
| R2 | Balanceamento do combate: 4 em 6 vitórias contra 3 bandidos com Guerreiro de 1º nível | playtest; ajustar o conteúdo (número de bandidos), não as regras |
| R3 | Ritmo do relógio (2 s = 10 min) e prazo do bando (12 dias) | playtest de 30 min com anotações |
| R4 | Clareza das pistas: o jogador entende o que fazer sem marcadores? | playtest com alguém que não conhece o mistério |
| R5 | Direção visual: aprovar ou trocar a Art Bible (32 px, 640×360) | `docs/ART_BIBLE.md` + capturas em `docs/` |
| R6 | Textos de diálogo e tom dos NPCs | `tools/build_dialogue.py` |
| R7 | Mecânicas ORIGINAL e ADAPTADA (tabela em `docs/REGRAS.md`): manter, mudar ou tornar opcional | marcar a decisão na própria tabela |
| R8 | Exceções de arquitetura aceitas (ADR-0002; `Prototypes` escreve estado inicial direto) | confirmar ou exigir comandos |
| R9 | Quais conteúdos do Heróis de Arton entram primeiro (classes, raças, poderes, itens) | lista curta priorizada |

## C. Próximos passos (ordem recomendada)

1. **R1 + C1:** revisar as 8 regras pendentes, começando pela Hiena. Destrava o balanceamento.
2. **Playtest** (R2–R4) usando o laboratório para isolar cada mecânica.
3. **C3 + C4 + C17:** poderes ao subir de nível, Arcanista completo e escolha de perícias. Fecha a ficha de personagem.
4. **Heróis de Arton (R9):** primeiras raças e classes nas categorias acordadas, cada uma com cenário no laboratório.
5. **C6 + C13:** viagem com combate tático e Valkaria com lojas. Primeiro passo da Fase 7 (viagens e biomas).
6. **C12:** domínio integrado à economia; conselheiros com memória (reaproveitar `MemoryModule`).
7. **C7–C9:** gerações completas (NPCs dinâmicos, casamentos, herdeiro na criação).
8. **R5:** cena piloto com arte final da vila; depois, os primeiros assets da Tormenta.
9. **Segundo mistério completo** (o das ovelhas já tem base) e uma segunda vila.
10. **Exportar builds** (Windows/Linux) com templates da Godot 4.3 e medir em hardware real (§15).

## D. Como trabalhar em cada item (protocolo §19)

1. Abra o cenário do laboratório da mecânica.
2. Rode `godot --headless --path . -s res://tests/run_tests.gd`.
3. Faça a mudança mínima no arquivo indicado.
4. Escreva ou ajuste o teste do protótipo em `tests/unit/test_prototypes.gd`.
5. Rode `python3 tools/check_architecture.py` e `python3 tools/validate_assets.py`.
6. Atualize `CHANGELOG.md`, `docs/PROTOTIPOS.md` e este roadmap.
