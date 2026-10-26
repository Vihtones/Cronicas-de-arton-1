# Mapa do projeto (gerado pelo Graphify)

Gerado por `tools/graphify_build.py` + `tools/graphify_mapa.py` a partir do commit `5ab4cce`. **Não edite à mão**: rode os dois scripts.
Grafo: 611 nós, 1708 arestas. Abra `graphify-out/graph.html` para navegar. Achados com decisão humana ficam em `docs/ORGANIZACAO.md`.

## Documentos

| Documento | Assunto | Seções | Cita código/regras |
|---|---|---|---|
| `CHANGELOG.md` | Changelog | 10 | 24 |
| `README.md` | Crônicas de Arton | 6 | 7 |
| `docs/ART_BIBLE.md` | Art Bible (provisória) | 1 | 1 |
| `docs/GOVERNADOR_DE_ARTE.md` | Governador de Direção de Arte | 7 | 3 |
| `docs/ORGANIZACAO.md` | Organização do projeto a partir do grafo (Graphify) | 3 | 13 |
| `docs/ORIENTACOES_GODOT.md` | Orientações do pacote godot-claude-skills aplicadas | 2 | 0 |
| `docs/PLANO_DE_EXECUCAO.md` | Crônicas de Arton: Plano de Execução e Status | 6 | 2 |
| `docs/PLANO_MESTRE.md` | PLANO_MESTRE | 0 | 5 |
| `docs/PROTOTIPOS.md` | Protótipos por mecânica (v0.3.0) | 0 | 6 |
| `docs/REFERENCIAS_VISUAIS.md` | Referências visuais e de sensação de jogo (pesquisa de 24/10/2026) | 3 | 0 |
| `docs/REGRAS.md` | Regras usadas pelo jogo e sua proveniência | 1 | 91 |
| `docs/ROADMAP.md` | Roadmap: próximos passos, correções e revisões | 5 | 11 |
| `docs/XP_DINAMICA.md` | XP dinâmica (ORIGINAL_DO_JOGO) | 5 | 1 |
| `docs/adr/ADR-0001-fundacao.md` | ADR-0001 — Decisões de fundação | 0 | 0 |
| `docs/adr/ADR-0002-modulos-eventos.md` | ADR-0002: Módulos do mundo, comandos e eventos | 2 | 4 |
| `docs/adr/ADR-0003-combate.md` | ADR-0003: Combate híbrido e projeção fantasma | 0 | 2 |
| `docs/adr/ADR-0004-prototipos.md` | ADR-0004: Laboratório de protótipos | 2 | 4 |

## Camadas e scripts

### `src/application`

- **DialogueProvider** (`src/application/dialogue_provider.gd`, 4 ligações) — Porta de verbalização (§4, §6 Fase 6).
- **Prototypes** (`src/application/prototypes.gd`, 22 ligações) — Laboratório de protótipos: um cenário pequeno e jogável por mecânica, montado sobre o MESMO mundo do jogo (sem atalhos de regra).
- **Telemetry** (`src/application/telemetry.gd`, 1 ligações) — Métricas de desempenho (§15): p50/p95 de frame, tempo de comando/tick, save/load.
- **WorldFactory** (`src/application/world_factory.gd`, 32 ligações) — Monta o mundo com todos os módulos.
- **game** (`src/application/game.gd`, 23 ligações) — Autoload "Game": composição da aplicação.

### `src/core`

- **EventBus** (`src/core/event_bus.gd`, 6 ligações) — Barramento de eventos sem dependência de Node.
- **GameCommand** (`src/core/game_command.gd`, 26 ligações) — Pedido de mudança de estado (Plano Mestre §6).
- **GameEvent** (`src/core/game_event.gd`, 32 ligações) — Fato consumado e imutável (Plano Mestre §6).
- **GameLogger** (`src/core/game_logger.gd`, 1 ligações) — Logger estruturado com níveis e buffer em memória (para telemetria/depuração).

### `src/domain`

- **AmbientTalk** (`src/domain/ambient_talk.gd`, 7 ligações) — Escolha das falas de ambiente (balões dos figurantes e latidos dos moradores) a partir do CONTEXTO da vila.
- **Biography** (`src/domain/biography.gd`, 3 ligações) — Biografia prévia gerada como HISTÓRICO RESUMIDO consistente (§8), nunca simulada dia a dia.
- **ContentDB** (`src/domain/content_db.gd`, 22 ligações) — Catálogos estáticos (definições) separados do estado mutável (§14).
- **DialogueVoice** (`src/domain/dialogue_voice.gd`, 12 ligações) — Voz dos moradores: monta falas a partir do ESTADO do mundo (hora, clima, evento da vila, reputação do jogador, mistério, quantas vezes já conversaram) e dos tex
- **RngStreams** (`src/domain/rng_streams.gd`, 5 ligações) — Fluxos de RNG separados e rastreáveis (§7): combate, clima, mundo, visual.
- **WorldClock** (`src/domain/world_clock.gd`, 4 ligações) — Relógio canônico do mundo (Plano Mestre §7).
- **WorldModule** (`src/domain/world_module.gd`, 31 ligações) — Contrato de módulo (§5): interface, eventos, versão de esquema, desativação.
- **WorldState** (`src/domain/world_state.gd`, 38 ligações) — Estado mutável do mundo.

### `src/domain/combat`

- **CombatSim** (`src/domain/combat/combat_sim.gd`, 29 ligações) — Estado e regras de combate puros (LB cap.
- **GhostPlanner** (`src/domain/combat/ghost_planner.gd`, 23 ligações) — Projeção fantasma (§9): recebe o estado (somente leitura), clona e simula o plano sem dados.

### `src/domain/modules`

- **AdventurersModule** (`src/domain/modules/adventurers_module.gd`, 8 ligações) — Aventureiros NPC em LOD L3 (§8): progridem por atividades plausíveis, usando a MESMA regra de XP do jogador (ND × 1000 / grupo, LB p.326).
- **CombatModule** (`src/domain/modules/combat_module.gd`, 103 ligações) — Combate tático híbrido (§9).
- **CrimeModule** (`src/domain/modules/crime_module.gd`, 23 ligações) — Crime (§11): ato real, evidência, testemunhas, conhecimento das autoridades, lei local, mandado, multa e resolução.
- **DialogueModule** (`src/domain/modules/dialogue_module.gd`, 35 ligações) — Diálogo estruturado (§6, §8).
- **DomainModule** (`src/domain/modules/domain_module.gd`, 18 ligações) — Administração de domínio (§11): decisões de alto nível, conselheiros e delegação.
- **EconomyModule** (`src/domain/modules/economy_module.gd`, 26 ligações) — Economia agregada por região (§11): produção/consumo diários e preços com limites.
- **ExplorationModule** (`src/domain/modules/exploration_module.gd`, 40 ligações) — Exploração ativa e mistérios (§10).
- **FactionModule** (`src/domain/modules/faction_module.gd`, 20 ligações) — Facções com objetivos, recursos e reações causais (§11).
- **FaunaModule** (`src/domain/modules/fauna_module.gd`, 14 ligações) — Criaturas com território e recursos, custo limitado (§11).
- **ItemsModule** (`src/domain/modules/items_module.gd`, 21 ligações) — Equipamento e consumíveis (protótipo).
- **LineageModule** (`src/domain/modules/lineage_module.gd`, 22 ligações) — Gerações (§8, §20.8): longevidade 70+2d20 rolada uma vez (LB p.108), morte por velhice, herança para o parente mais velho, nascimentos em casais e sucessão do h
- **MemoryModule** (`src/domain/modules/memory_module.gd`, 35 ligações) — Memória estruturada, rumores e reputação (§8, §11).
- **NpcLifeModule** (`src/domain/modules/npc_life_module.gd`, 14 ligações) — Vida dos moradores: o que cada um ESTÁ FAZENDO agora e COMO se sente.
- **NpcModule** (`src/domain/modules/npc_module.gd`, 42 ligações) — NPCs com agenda (LOD L1): local muda por hora segundo rotina, clima e estado.
- **ObjectsModule** (`src/domain/modules/objects_module.gd`, 28 ligações) — Portas, baús, escadas e barracas.
- **PacingModule** (`src/domain/modules/pacing_module.gd`, 9 ligações) — WorldPacingDirector (§7): decide QUANDO apresentar conteúdo opcional que JÁ é verdadeiro no estado (vinhetas).
- **ProgressionModule** (`src/domain/modules/progression_module.gd`, 31 ligações) — Progressão.
- **RegionSimModule** (`src/domain/modules/region_sim_module.gd`, 5 ligações) — Regiões distantes em LOD L3 (§7): um sorteio agregado por dia, nunca simulação passo a passo.
- **ReligionModule** (`src/domain/modules/religion_module.gd`, 15 ligações) — Fé (§11): devoção segue o panteão e as obrigações verificadas no LB.
- **StateModule** (`src/domain/modules/state_module.gd`, 32 ligações) — Flags do mundo e inventário do jogador.
- **TownEventsModule** (`src/domain/modules/town_events_module.gd`, 14 ligações) — Eventos da vila (mundo vivo): feira semanal e festa da vila.
- **TravelModule** (`src/domain/modules/travel_module.gd`, 26 ligações) — Viagens entre regiões (LB p.270, Tabela 6-4): km/dia pelo deslocamento, metade em terreno difícil ou clima ruim.
- **WeatherModule** (`src/domain/modules/weather_module.gd`, 29 ligações) — WeatherRegion (§12): muda em passos espaçados (de hora em hora) por cadeia de Markov no fluxo RNG "weather".

### `src/domain/rules`

- **CharacterBuilder** (`src/domain/rules/character_builder.gd`, 27 ligações) — Criação de personagem (protótipo).
- **CharacterSheet** (`src/domain/rules/character_sheet.gd`, 29 ligações) — Ficha mínima T20.
- **Checks** (`src/domain/rules/checks.gd`, 12 ligações) — Testes T20: 1d20 + modificador >= CD (LB p.220).
- **Dice** (`src/domain/rules/dice.gd`, 10 ligações) — Expressões de dados "XdY+Z" com rolagem rastreável num fluxo RNG.
- **NpcStats** (`src/domain/rules/npc_stats.gd`, 5 ligações) — Fichas de ameaça de NPC (LB p.322, Tabela 7-2): valores finais pelo ND, sem calcular atributos.
- **RuleRegistry** (`src/domain/rules/rule_registry.gd`, 17 ligações) — Catálogo de regras com proveniência (§2).

### `src/infrastructure`

- **JsonSaveRepository** (`src/infrastructure/json_save_repository.gd`, 4 ligações) — Persistência JSON atômica (§14): cabeçalho, checksum SHA-256, arquivo temporário, backup do save anterior e recuperação automática se o principal estiver corrom
- **LlmDialogueProvider** (`src/infrastructure/llm_dialogue_provider.gd`, 4 ligações) — Provedor de IA OPCIONAL (Fase 6).
- **LocalEchoProvider** (`src/infrastructure/local_echo_provider.gd`, 4 ligações) — Provedor "IA" local e determinístico para demonstrar o pipeline da Fase 6 SEM rede: reescreve o tom por profissão, nunca muda fatos, opções ou resultados.

### `src/presentation`

- **ActorView** (`src/presentation/actor_view.gd`, 8 ligações) — Figura animada (spritesheet 3x4: parado/passo1/passo2 x baixo/esq/dir/cima).
- **AmbientLife** (`src/presentation/ambient_life.gd`, 10 ligações) — Figurantes da vila (L0, só apresentação): gente andando, correndo da chuva, trabalhando, conversando, vendendo, crianças brincando de pega-pega, carroças na est
- **CameraDirector** (`src/presentation/camera_director.gd`, 3 ligações) — Câmera cinematográfica (§9): responde a tags de eventos (ataque, impacto, crítico, queda, morte...).
- **CombatView** (`src/presentation/combat_view.gd`, 34 ligações) — Combate na tela: grade, planejamento com projeção fantasma, confirmação e reprodução cinematográfica dos eventos.
- **GhostActor** (`src/presentation/ghost_actor.gd`, 2 ligações) — Fantasma do jogador no combate: um sprite translúcido que ENSAIA o plano em laço — anda o caminho, investe contra o alvo, dispara ou conjura — para o jogador ve
- **Narrator** (`src/presentation/narrator.gd`, 78 ligações) — Converte eventos em texto para o registro.
- **NpcLayer** (`src/presentation/npc_layer.gd`, 17 ligações) — Materializa (L0) NPCs e criaturas da zona do jogador a partir do estado L1.
- **PlayerView** (`src/presentation/player.gd`, 6 ligações) — Jogador: input -> movimento físico -> comando MovePlayer quando muda de tile.
- **SpeechBubble** (`src/presentation/speech_bubble.gd`, 3 ligações) — Balão de fala sobre um ator (apresentação).
- **WorldView** (`src/presentation/world_view.gd`, 5 ligações) — Desenha o mapa a partir do catálogo (TileMapLayer) com colisão para tiles bloqueados e portas fechadas.
- **main** (`src/presentation/main.gd`, 39 ligações) — Cena principal: monta mapa, atores, câmera, efeitos, combate e interface.

### `src/presentation/art`

- **ArtGovernor** (`src/presentation/art/art_governor.gd`, 7 ligações) — Governador de Direção de Arte (Beleza Marcada).
- **BuildingLayer** (`src/presentation/art/building_layer.gd`, 4 ligações) — Casas com volume (apresentação, PROVISÓRIO procedural até haver arte aprovada pelo governador): telhado de quatro águas por cima dos atores, fachada em enxaimel
- **PathDressing** (`src/presentation/art/path_dressing.gd`, 4 ligações) — Caminhos orgânicos (apresentação; o mapa de regras não muda).
- **RaceLook** (`src/presentation/art/race_look.gd`, 4 ligações) — Visual PROVISÓRIO por raça (o usuário pediu modelos simples até a arte final passar pelo governador): só tinta e escala sobre o sprite-base.
- **VegetationLayer** (`src/presentation/art/vegetation_layer.gd`, 5 ligações) — Vegetação aprovada pelo Governador de Arte, posicionada sobre o mapa (só apresentação).

### `src/presentation/fx`

- **CinematicDirector** (`src/presentation/fx/cinematic_director.gd`, 8 ligações) — Momentos cinematográficos do combate (pedido do usuário; Bíblia: combate tático legível, luz emocional).
- **FxLayer** (`src/presentation/fx_layer.gd`, 7 ligações) — Luz e atmosfera (Bíblia de Arte: luz natural orgânica de Octopath, luz localizada e névoa de Children of Morta, credibilidade de Stoneshard).
- **ImpactFx** (`src/presentation/fx/impact_fx.gd`, 3 ligações) — Efeitos de combate procedurais (sistema de teste: as texturas finais entram depois, pelo governador).
- **Portrait** (`src/presentation/fx/portrait.gd`, 6 ligações) — Retrato com expressão (sistema pronto; a arte é PROVISÓRIA e procedural).
- **PostProcess** (`src/presentation/fx/post_process.gd`, 4 ligações) — Pós-processamento de tela (Bíblia de Arte: luz emocional, blur sutil e SELETIVO, Children of Morta).

### `src/presentation/ui`

- **HotSlot** (`src/presentation/ui/hot_slot.gd`, 1 ligações) — Espaço do cinto de atalhos (estilo Stoneshard): quadrado com moldura de bronze, ícone desenhado, tecla no canto e custo em PM.
- **Minimap** (`src/presentation/ui/minimap.gd`, 4 ligações) — Minimapa (canto superior direito, estilo Stoneshard): recorte da região em volta do jogador, com prédios, estradas, água, NPCs conhecidos por perto, o evento da
- **PowerTreePanel** (`src/presentation/ui/power_tree_panel.gd`, 4 ligações) — Árvore de poderes (tecla K).
- **UiRoot** (`src/presentation/ui/ui_root.gd`, 57 ligações) — Toda a interface em código (sem cenas), legível a 640x360.

### `tests`

- **TestCase** (`tests/unit/test_case.gd`, 23 ligações) — 
- **WorldHelpers** (`tests/unit/world_helpers.gd`, 21 ligações) — Utilidades de teste: cria mundo e posiciona o jogador.
- **run_tests** (`tests/run_tests.gd`, 0 ligações) — Executor de testes headless, sem dependências externas.
- **test_arcanista** (`tests/unit/test_arcanista.gd`, 13 ligações) — C17 (perícias), C4 (Arcanista: caminhos e 3 magias) e C5 (concentração e armadura ao lançar).
- **test_art_governor** (`tests/unit/test_art_governor.gd`, 4 ligações) — Governador de Direção de Arte: só assets aprovados entram, nas zonas certas, sem mexer na colisão.
- **test_arvore_poderes** (`tests/unit/test_arvore_poderes.gd`, 11 ligações) — Árvore de poderes: poderes gerais do LB (p.124-131) com pré-requisitos encadeados e efeitos.
- **test_combat** (`tests/unit/test_combat.gd`, 16 ligações) — 
- **test_dialogo_voz** (`tests/unit/test_dialogo_voz.gd`, 12 ligações) — Voz dos moradores: saudação por registro/hora/reputação, memória da conversa, papo e opiniões.
- **test_event_bus** (`tests/unit/test_event_bus.gd`, 3 ligações) — 
- **test_exploration** (`tests/unit/test_exploration.gd`, 11 ligações) — 
- **test_falas_ambiente** (`tests/unit/test_falas_ambiente.gd`, 4 ligações) — Falas de ambiente: escolha por contexto (hora, clima, evento, mistério), conversas de verdade e latidos.
- **test_interactions** (`tests/unit/test_interactions.gd`, 48 ligações) — XP dinâmica, poderes e interações entre sistemas (quando a ligação é óbvia).
- **test_mundo_vivo** (`tests/unit/test_mundo_vivo.gd`, 10 ligações) — Mundo vivo: feira semanal, festa da vila, agendas redirecionadas, economia e clima gradual.
- **test_powers** (`tests/unit/test_powers.gd`, 13 ligações) — C21: poderes de classe do LB (guerreiro p.65-66, ladino p.73-74, arcanista p.38-39) e reações.
- **test_prototypes** (`tests/unit/test_prototypes.gd`, 48 ligações) — Uma "build" funcional por mecânica: cada protótipo sobe e demonstra a mecânica.
- **test_racas** (`tests/unit/test_racas.gd`, 7 ligações) — Todas as raças jogáveis do Livro Básico (p.18-31): atributos, deslocamento, tamanho, sentidos e traços com sistema.
- **test_rng** (`tests/unit/test_rng.gd`, 2 ligações) — 
- **test_rules** (`tests/unit/test_rules.gd`, 7 ligações) — 
- **test_save_repository** (`tests/unit/test_save_repository.gd`, 2 ligações) — 
- **test_smoke_world** (`tests/unit/test_smoke_world.gd`, 3 ligações) — 
- **test_social** (`tests/unit/test_social.gd`, 18 ligações) — 
- **test_systems** (`tests/unit/test_systems.gd`, 31 ligações) — Crime, economia, clima, fé, diálogo, persistência e módulos opcionais.
- **test_vertical_slice** (`tests/unit/test_vertical_slice.gd`, 21 ligações) — Gates do vertical slice jogados só por comandos (sem atalhos internos).
- **test_vida_moradores** (`tests/unit/test_vida_moradores.gd`, 7 ligações) — Vida dos moradores: atividade, humor (medo/alegria), recolhimento e persistência.
- **test_world_clock** (`tests/unit/test_world_clock.gd`, 2 ligações) — 
- **test_world_state** (`tests/unit/test_world_state.gd`, 6 ligações) — 

### `tools`

- **art_test_runner** (`tools/art_test_runner.gd`, 2 ligações) — Teste visual do acervo Tormenta20 (NÃO aprovado) dentro do cenário real do jogo.
- **benchmark** (`tools/benchmark.gd`, 4 ligações) — Benchmark da cena típica (§15): anda pela vila em cada perfil gráfico e mede p50/p95 de frame, tempo de comando, save e load.
- **combat_fx_check** (`tools/combat_fx_check.gd`, 3 ligações) — Verificação ponta a ponta da encenação de combate: um golpe que derruba o alvo (momento "ABATIDO!") pelo caminho real (ExecutePlan → eventos → reprodução).
- **falas_check** (`tools/falas_check.gd`, 2 ligações) — Capturas do mundo vivo: casas com telhado, caminhos, figurantes, feira, festa, chuva chegando, telhado abrindo ao entrar, HUD e árvore de poderes.
- **fx_runner** (`tools/fx_runner.gd`, 6 ligações) — Capturas dos sistemas visuais (luz, sombras, desfoque, cinematográfico, retratos, rastros e impacto).
- **ghost_check** (`tools/ghost_check.gd`, 3 ligações) — Verificação ponta a ponta da encenação de combate: um golpe que derruba o alvo (momento "ABATIDO!") pelo caminho real (ExecutePlan → eventos → reprodução).
- **lab_runner** (`tools/lab_runner.gd`, 4 ligações) — Capturas dos protótipos do laboratório.
- **life_runner** (`tools/life_runner.gd`, 1 ligações) — Capturas do mundo vivo: casas com telhado, caminhos, figurantes, feira, festa, chuva chegando, telhado abrindo ao entrar, HUD e árvore de poderes.
- **screenshot_runner** (`tools/screenshot_runner.gd`, 9 ligações) — Roteiro automático de capturas (verificação visual).

## Comandos (GameCommand)

| Comando | Tratado por | Enviado por (jogo) | Testado por |
|---|---|---|---|
| Buy | EconomyModule | UiRoot | test_interactions, test_prototypes |
| CastSpell | ItemsModule | UiRoot | **sem teste** |
| ChooseOption | DialogueModule | UiRoot, screenshot_runner | test_dialogo_voz, test_systems, test_vertical_slice |
| ChoosePower | ProgressionModule | UiRoot | test_arvore_poderes, test_interactions, test_powers |
| ContinueAsHeir | LineageModule | UiRoot | test_prototypes |
| Delegate | DomainModule | UiRoot | test_prototypes |
| EndDialogue | DialogueModule | screenshot_runner | test_dialogo_voz, test_vertical_slice |
| EndTurn | CombatModule | CombatView | test_combat, test_interactions, test_prototypes, test_vertical_slice |
| Equip | ItemsModule | UiRoot | test_interactions, test_prototypes |
| ExecutePlan | CombatModule | CombatView | test_combat, test_interactions, test_prototypes, test_vertical_slice |
| GrantDomain | DomainModule | Prototypes | **sem teste** |
| InspectTarget | ExplorationModule | main | test_exploration, test_prototypes, test_systems, test_vertical_slice |
| MarkHypothesis | ExplorationModule | UiRoot | **sem teste** |
| PayFine | CrimeModule | DialogueModule | test_systems |
| RescueNPC | NpcModule | DialogueModule, Prototypes | test_exploration, test_social, test_vertical_slice |
| Rest | StateModule | UiRoot, main | test_systems |
| SetPolicy | DomainModule | UiRoot | test_interactions, test_prototypes |
| SetPowerPolicy | CombatModule | CombatView, UiRoot | test_interactions |
| SetStance | CombatModule | UiRoot, main | test_combat |
| SetXpMode | ProgressionModule | UiRoot | test_interactions |
| StartCombat | CombatModule | main | test_prototypes |
| StartDialogue | DialogueModule | main, screenshot_runner | test_dialogo_voz, test_social, test_systems, test_vertical_slice |
| StealFromStall | CrimeModule | Prototypes, main | test_systems |
| Travel | TravelModule | UiRoot, lab_runner, main | test_interactions, test_prototypes |
| UseItem | ItemsModule | UiRoot | **sem teste** |
| UseObject | ObjectsModule | main | test_combat, test_exploration, test_vertical_slice |

## Eventos e fatos (GameEvent)

| Evento | Emitido por | Assinado por (domínio) | Escutado por (apresentação/testes) |
|---|---|---|---|
| AMBIENT_VIGNETTE | PacingModule | — | Narrator |
| AMBUSH_PERCEPTION | CombatModule | — | Narrator, test_interactions |
| ATTACK_RESOLVED | — | — | CombatModule, CombatView, Narrator, test_arcanista, test_arvore_poderes, test_interactions … |
| BANDITS_RELOCATED | FactionModule | CombatModule, ExplorationModule, NpcModule | NpcLayer |
| BECOME_DEVOTEE | — | ReligionModule | Narrator, test_interactions, test_prototypes, test_systems |
| BLEED_CHECK | CombatModule | — | CombatView, Narrator, test_combat |
| BUFF_APPLIED | CombatModule | — | CombatView, Narrator, test_arcanista |
| CHECK_FAILED | ObjectsModule | — | Narrator |
| COMBAT_ENDED | CombatModule | FactionModule, ProgressionModule | CombatView, Narrator, NpcLayer, game, main, test_interactions … |
| COMBAT_MOVED | CombatModule | — | CombatView |
| COMBAT_STARTED | CombatModule | NpcLifeModule | CombatView, Narrator, game |
| COUP_DE_GRACE | CombatModule | — | CombatView, Narrator |
| CREATURES_MOVED | CombatModule | — | main, test_interactions |
| CREATURE_DEFEATED | — | CombatModule, ExplorationModule, FactionModule, FaunaModule, ProgressionModule | MemoryModule, Narrator, NpcLayer, test_combat, test_interactions, test_prototypes |
| CRIME_COMMITTED | CrimeModule | — | MemoryModule, Narrator |
| CRIME_INVESTIGATED | CrimeModule | — | Narrator, test_prototypes |
| DIALOGUE_CHOICE | DialogueModule | — | main |
| DIALOGUE_ENDED | CombatModule | DialogueModule | game |
| DIALOGUE_STARTED | DialogueModule | MemoryModule | game, main |
| DIALOGUE_TEST | DialogueModule | ProgressionModule | Narrator |
| DISTANT_EVENT | AdventurersModule, RegionSimModule | EconomyModule, MemoryModule | test_social |
| DIZIMO_RETURNED | FactionModule | — | MemoryModule, Narrator |
| DOMAIN_DELEGATED | DomainModule | — | — |
| DOMAIN_UNREST | DomainModule | — | MemoryModule, Narrator, test_interactions |
| DOMAIN_WEEK | DomainModule | EconomyModule | Narrator |
| ECONOMY_DAY | EconomyModule | — | — |
| EQUIPPED | ItemsModule | ReligionModule | Narrator |
| FACTION_ALERTED | FactionModule | — | — |
| FACT_REVEALED | DialogueModule | ExplorationModule | Narrator, UiRoot |
| FINE_PAID | CrimeModule | — | MemoryModule, Narrator |
| FLAG_SET | DialogueModule, ExplorationModule | StateModule | — |
| GOLD_CHANGED | CombatModule, CrimeModule, DialogueModule, EconomyModule, TravelModule | StateModule | Narrator |
| GRANT_DOMAIN | — | DomainModule | Narrator |
| GUARD_RAID_PLANNED | FactionModule | — | test_social |
| GUARD_RAID_RESOLVED | FactionModule | — | test_social, test_vertical_slice |
| HEALED | CombatModule, ItemsModule | — | CombatView, Narrator |
| HERO_SUCCEEDED | LineageModule | MemoryModule | Narrator |
| HYPOTHESIS_MARKED | ExplorationModule | — | UiRoot |
| INHERITANCE | LineageModule | — | Narrator |
| ITEM_BOUGHT | EconomyModule | — | Narrator |
| ITEM_GAINED | CombatModule, CrimeModule, DialogueModule, EconomyModule, ItemsModule, ObjectsModule | ExplorationModule, StateModule | Narrator, test_combat |
| ITEM_LOST | CombatModule, DialogueModule, ItemsModule | StateModule | Narrator |
| JOURNEY_CHALLENGE | TravelModule | — | Narrator |
| LETHAL_DAMAGE_DEALT | CombatModule | ReligionModule | test_systems |
| LEVEL_UP | ProgressionModule | — | Narrator, UiRoot, test_interactions, test_prototypes |
| MANEUVER_RESOLVED | CombatModule | — | Narrator |
| MYSTERY_LOST | ExplorationModule | — | — |
| MYSTERY_RESOLVED | ExplorationModule | MemoryModule, ProgressionModule | Narrator, test_interactions |
| NOISE_HEARD | CombatModule | — | Narrator |
| NOISE_UNHEARD | CombatModule | — | Narrator |
| NPC_BORN | LineageModule | NpcModule | MemoryModule, Narrator, main, test_systems |
| NPC_CAME_OF_AGE | LineageModule | — | Narrator, test_systems |
| NPC_CAPTURED | — | NpcLifeModule, NpcModule | — |
| NPC_DIED | LineageModule | NpcLifeModule, NpcModule | MemoryModule, Narrator, test_prototypes, test_vida_moradores |
| NPC_MARRIED | LineageModule | — | MemoryModule, Narrator |
| NPC_MOVED | NpcModule | EconomyModule | NpcLayer, WorldState |
| NPC_RESCUED | FactionModule | ExplorationModule, NpcLifeModule, NpcModule | MemoryModule, Narrator, NpcLayer |
| NPC_RESCUED_BY_OTHER | — | MemoryModule | — |
| NPC_WOUNDED | FactionModule | NpcLifeModule, NpcModule | — |
| OBJECT_BROKEN | ObjectsModule | CrimeModule | Narrator, main |
| OBJECT_CLOSED | ObjectsModule | — | Narrator, main |
| OBJECT_DAMAGED | ObjectsModule | CombatModule | Narrator |
| OBJECT_OPENED | ObjectsModule | — | Narrator, main |
| OBJECT_UNLOCKED | ObjectsModule | — | Narrator |
| OBLIGATION_VIOLATED | ReligionModule | — | MemoryModule, Narrator, test_prototypes, test_systems |
| PACK_GREW | FaunaModule | CombatModule | — |
| PACK_RELOCATED | FaunaModule | CombatModule | Narrator, test_interactions |
| PLAN_INTERRUPTED | CombatModule | — | Narrator |
| PLAYER_CAPTURED | CombatModule | ObjectsModule | MemoryModule, Narrator, NpcLayer, main, test_combat |
| PLAYER_DIED | CombatModule | — | Narrator, game, test_combat |
| PLAYER_MOVED | — | CombatModule, ExplorationModule | WorldState, test_world_state |
| PLAYER_ROBBED | CombatModule | — | Narrator, test_interactions |
| PLAYER_TELEPORTED | ObjectsModule | CombatModule, ExplorationModule | Narrator, NpcLayer, main |
| POLICY_SET | DomainModule | — | — |
| POWER_CHOSEN | ProgressionModule | — | Narrator |
| POWER_POLICY_SET | CombatModule | — | — |
| POWER_USED | CombatModule | — | CombatView, Narrator, test_arvore_poderes |
| REACTION | CombatModule | — | CombatView, Narrator, test_powers |
| REFUSED_HELP | — | ReligionModule | test_prototypes |
| RENOUNCE_DEVOTION | — | ReligionModule | — |
| REPORT_TO_GUARD | — | FactionModule | test_social |
| RESTED | StateModule | — | Narrator |
| RUMOR_SPREAD | MemoryModule | — | test_social |
| SCHEDULED_BANDITS_RELOCATE | — | FactionModule | — |
| SCHEDULED_GUARD_RAID | — | FactionModule | — |
| SHEEP_KILLED | FaunaModule | EconomyModule, ExplorationModule, MemoryModule | Narrator, test_prototypes |
| SPELL_CAST | CombatModule, ItemsModule | — | Narrator |
| SPELL_FAILED | CombatModule | — | CombatView, Narrator, test_arcanista |
| STANCE_CHANGED | CombatModule | — | Narrator |
| STEALTH_CHECK | CombatModule | ProgressionModule | Narrator, test_combat, test_interactions |
| STOLEN_GOODS_RECOVERED | ObjectsModule | — | — |
| STOOD_UP | CombatModule | — | CombatView, Narrator |
| TARGET_INSPECTED | ExplorationModule | ProgressionModule | Narrator, test_interactions |
| TIME_ADVANCED | — | FactionModule | WorldState |
| TOWN_EVENT_ENDED | TownEventsModule | NpcLifeModule | Narrator, test_mundo_vivo |
| TOWN_EVENT_STARTED | TownEventsModule | EconomyModule, NpcLifeModule | Narrator, UiRoot, test_mundo_vivo, test_vida_moradores |
| TRADE_DELIVERED | EconomyModule | — | Narrator, test_prototypes |
| TRAVEL_AMBUSH | TravelModule | CombatModule | Narrator |
| TRAVEL_ARRIVED | TravelModule | — | Narrator, main |
| TRAVEL_STARTED | TravelModule | — | Narrator |
| TURN_ENDED | CombatModule | — | — |
| TURN_SKIPPED | CombatModule | — | Narrator |
| TURN_STARTED | CombatModule | — | CombatView |
| WARRANT_ISSUED | CrimeModule | — | Narrator, test_systems |
| WEATHER_CHANGED | WeatherModule | — | Narrator, UiRoot |
| XP_GAINED | ProgressionModule | — | Narrator, UiRoot, test_interactions |
| XP_MODE_SET | ProgressionModule | — | — |

## Regras de Tormenta20 por família

| Família | Regras | Lidas pelo código | Usada por |
|---|---|---|---|
| acao | 3 | 2 | CombatModule, CombatSim |
| alcance | 2 | 1 | CharacterBuilder, GhostPlanner |
| arma | 8 | 8 | CharacterBuilder, CharacterSheet, items.json |
| armadura | 3 | 3 | CharacterBuilder, CharacterSheet, CombatModule, ReligionModule, items.json |
| ataque | 1 | 0 | — |
| atributos | 1 | 1 | CharacterBuilder |
| cd | 2 | 0 | — |
| classe | 8 | 8 | CharacterBuilder, CharacterSheet, CombatModule, CombatSim, GhostPlanner … |
| condicoes | 1 | 1 | CharacterSheet |
| criatura | 3 | 3 | npcs.json |
| critico | 1 | 0 | — |
| dano | 2 | 0 | — |
| defesa | 1 | 0 | — |
| descanso | 4 | 3 | StateModule |
| deslocamento | 1 | 1 | CharacterBuilder, CharacterSheet |
| deus | 3 | 0 | — |
| distancia | 2 | 0 | — |
| envelhecimento | 1 | 1 | LineageModule |
| escudo | 1 | 0 | — |
| ferimentos | 2 | 0 | — |
| iniciativa | 1 | 0 | — |
| item | 2 | 1 | items.json |
| magia | 8 | 8 | CombatModule, GhostPlanner, ItemsModule, UiRoot, test_arcanista |
| manobra | 1 | 0 | — |
| mapa | 4 | 1 | CombatSim |
| npc | 1 | 1 | NpcStats |
| panteao | 1 | 1 | ReligionModule |
| pericia | 3 | 1 | CharacterBuilder, CharacterSheet, UiRoot |
| pericias | 1 | 1 | CharacterBuilder |
| perigo | 2 | 2 | TravelModule |
| poder | 29 | 29 | CombatModule, CombatSim, GhostPlanner, ProgressionModule |
| progressao | 2 | 2 | AdventurersModule, ProgressionModule |
| raca | 18 | 18 | CharacterBuilder, CharacterSheet, ProgressionModule, UiRoot |
| racas | 1 | 0 | — |
| rodada | 1 | 0 | — |
| situacao | 4 | 2 | CombatSim |
| surpresa | 1 | 0 | — |
| tamanho | 1 | 1 | CharacterBuilder |
| teste | 2 | 0 | — |
| turno | 1 | 0 | — |
| viagem | 2 | 1 | TravelModule |

## Achados automáticos

- **Regras conferidas que o código não lê** (35): o valor está escrito à mão no código, e as duas fontes podem divergir — `acao.usar_item_pocao`, `alcance.metros`, `ataque.teste`, `cd.resistencia`, `cd.tabela`, `critico`, `dano.forca`, `dano.nao_letal`, `defesa.base`, `descanso.ruim_relento`, `deus.allihanna.obrigacao`, `deus.khalmyr.obrigacao`, `deus.lena.obrigacao`, `distancia.dobro_alcance`, `distancia.em_corpo_a_corpo`, `escudo.leve`, `ferimentos.morte`, `ferimentos.zero_pv`, `iniciativa`, `item.pocao_curar_ferimentos`, `manobra.derrubar`, `mapa.diagonal`, `mapa.espaco_inimigo`, `mapa.terreno_dificil`, `pericia.bonus_treino`, `pericia.valor`, `racas.tabela`, `rodada.segundos`, `situacao.atacante_caido`, `situacao.cobertura_leve`, `surpresa`, `teste.basico`, `teste.oposto.empate`, `turno.acoes`, `viagem.marcha_forcada`.
- **Eventos que ninguém assina nem escuta** (9): `DOMAIN_DELEGATED`, `ECONOMY_DAY`, `FACTION_ALERTED`, `MYSTERY_LOST`, `POLICY_SET`, `POWER_POLICY_SET`, `STOLEN_GOODS_RECOVERED`, `TURN_ENDED`, `XP_MODE_SET`.
- **Comandos que o jogo nunca envia**: nenhum.
- **Comandos sem teste que os envie**: `CastSpell`, `GrantDomain`, `MarkHypothesis`, `UseItem`.
- **Classes de domínio sem teste que as cite**: `FaunaModule`, `ItemsModule`, `ObjectsModule`, `RegionSimModule`, `StateModule`.

