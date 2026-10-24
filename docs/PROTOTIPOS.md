# Protótipos por mecânica (v0.3.0)

Cada mecânica do Plano Mestre tem uma versão básica funcional, um cenário no **Laboratório de protótipos** (tela de título) e um teste automático. Os cenários montam o estado inicial no mesmo mundo do jogo, sem regras paralelas (`src/application/prototypes.gd`).

**Legenda de maturidade:**
- **■■■■** completo para o vertical slice
- **■■■□** funcional, falta conteúdo ou UI
- **■■□□** protótipo básico
- **■□□□** só a estrutura

| Mecânica | Maturidade | Código principal | Cenário no lab | Teste | O que falta (detalhe no ROADMAP) |
|---|---|---|---|---|---|
| Regras T20 com proveniência | ■■■■ | `src/domain/rules/`, `data/rules/` | todos | `test_rules` | — (106 regras, 0 pendentes) |
| Exploração e mistério | ■■■■ | `exploration_module.gd` | Mistério e exploração | `test_exploration`, `test_vertical_slice` | mais mistérios (o sistema já aceita vários) |
| 2º mistério e fauna | ■■■□ | `fauna_module.gd`, `mysteries_extra.json` | Fauna e 2º mistério | `test_fauna_faminta_...` | novas tocas além das duas |
| Combate tático e fantasma | ■■■■ | `combat_sim.gd`, `ghost_planner.gd`, `combat_module.gd` | Combate tático; Poderes de classe | `test_combat`, `test_powers` | inimigos com poderes |
| Furtividade e surpresa | ■■■□ | `CombatModule._check_encounter` | Furtividade | `test_encontro_...` | cobertura e luz influenciando a furtividade |
| Magia | ■■■□ | `ghost_planner.gd` (cast), `items_module.gd` | Magia (Arcanista anã) | `test_magia_...` | 4ª magia do Mago, linhagem, memorização, ferido durante a execução |
| Ataque furtivo (Ladino) | ■■■□ | `CombatModule._resolve_attack` | Ataque furtivo | `test_ladino_...` | Especialista e Evasão |
| Criação de personagem | ■■■□ | `character_builder.gd`, UI de criação | Criação de personagem | `test_criacao_...` | outras raças/classes, origens |
| Progressão e XP dinâmica | ■■■□ | `progression_module.gd`, `docs/XP_DINAMICA.md` | Progressão e XP dinâmica | `test_interactions` (xp_*) | poderes de 5º nível ou mais (C27) |
| Equipamento e loja | ■■■□ | `items_module.gd`, `economy_module.gd` | Equipamento e loja | `test_equipamento_...`, `test_mercado_...` | carga e escudos |
| NPCs com agenda (L1) | ■■■■ | `npc_module.gd` | (qualquer) | `test_social` | — |
| Memória, rumores e reputação | ■■■■ | `memory_module.gd` | Memória e rumores | `test_social` | esquecimento por tempo (revisão de memória) |
| Preconceito individual | ■■□□ | `MemoryModule.bias` | Equipamento e loja | `test_reputacao_...` | preconceitos institucionais |
| Facções e incursão da Guarda | ■■■□ | `faction_module.gd` | (vertical slice) | `test_rota_investigativa_...` | objetivos de longo prazo, recursos consumidos |
| Crime com testemunhas | ■■■□ | `crime_module.gd` | Crime com testemunhas | `test_furto_...` | agressão e invasão como crimes ativos |
| Investigação da Guarda | ■■■□ | `CrimeModule._investigate` | Investigação da Guarda | `test_investigacao_...` | pistas físicas |
| Economia e mensageira | ■■■□ | `economy_module.gd` | Economia e mensageira | `test_economia_...` | vender itens, safras ligadas ao clima |
| Região distante (L3) | ■■□□ | `region_sim_module.gd` | Viagem a Valkaria | `test_mensageiro_...` | mais regiões e eventos |
| Viagem e emboscada | ■■■□ | `travel_module.gd`, `CombatModule` (TRAVEL_AMBUSH) | Viagem a Valkaria; Emboscada na estrada | `test_viagem_...`, `test_emboscada_...` | encontros no meio da rota; Valkaria com mapa |
| Clima e visibilidade | ■■■□ | `weather_module.gd`, `fx_layer.gd` | Clima e visibilidade | `test_clima_...`, `test_noite_...` | calendário oficial; efeitos de lama/neve |
| Domínio | ■■■□ | `domain_module.gd`, diário | Administração de domínio | `test_dominio_...` | conselheiros com memória e opinião; produção real no estoque |
| Gerações e herança | ■■■□ | `lineage_module.gd` | Gerações e herança | `test_geracoes_...` | crianças crescerem para adultas; gênero no catálogo |
| Morte e sucessão do herói | ■■□□ | `LineageModule` (ContinueAsHeir) | Morte e sucessão | `test_herdeiro_...` | herdeiro com laço familiar real; criação de personagem na sucessão |
| Aventureiros NPC | ■■□□ | `adventurers_module.gd` | Aventureiros NPC e ritmo | `test_aventureiros_...` | visitar a vila; rivalidade ou cooperação com o jogador |
| Diretor de ritmo | ■■□□ | `pacing_module.gd` | Aventureiros NPC e ritmo | idem | mais vinhetas; regras de densidade por região |
| Biografias geradas | ■■□□ | `biography.gd` (diálogo: "Fale um pouco de você") | (qualquer NPC) | `test_biografia_...` | coerência com memórias e família |
| Fé e obrigações | ■■□□ | `religion_module.gd` | Fé e obrigações | `test_fe_...`, `test_lena_...` | os outros 17 deuses; poderes concedidos |
| IA de diálogo opcional | ■■■□ | `llm_dialogue_provider.gd`, `local_echo_provider.gd` | IA de diálogo (local) | `test_llm_...`, `test_ia_local_...` | testar com um modelo real (`user://ai.json`) |
| Persistência e migração | ■■■■ | `json_save_repository.gd` | F5/F9 | `test_save_repository`, `test_migracao_...` | migração v2→v3 quando o esquema mudar |
| Desempenho e telemetria | ■■■□ | `telemetry.gd`, `tools/benchmark.gd`, F3 | F3 em qualquer cenário | benchmark | medir em hardware real |
| Pipeline de arte | ■■□□ | `tools/gen_placeholder_art.py`, `validate_assets.py` | — | validador | arte final; aprovar a Art Bible |
