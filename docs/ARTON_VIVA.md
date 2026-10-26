# Arton Viva — auditoria (Fase 0) e andamento

Documento-base: `CDA-WORLD-001` v2.0 (26/10/2026, em `docs/especificacao/CDA_WORLD_001_v2.0.md`; a v1.0 segue em `docs/especificacao/CDA_WORLD_001.md` para histórico). O CDA-GAME-002 citado pela v2.0 não foi recebido. Este arquivo registra o que o repositório realmente tem, o que falta e o andamento de cada fase. Estado verificado em 26/10/2026: 273 testes, 0 violações de arquitetura, 0 apontamentos de estilo.

## Matriz de requisitos

Legenda: **Validado** (implementado e testado), **Parcial**, **Existe sem integração**, **Ausente**, **Adiado** (decisão de escopo).

| Área (spec) | Situação | Onde está / o que falta |
|---|---|---|
| Agentes (WorldAgent, dados principais) | Parcial | Cada morador é um registro em `data/world/npcs.json` + estado em `NpcModule`. Não há um modelo comum `WorldAgent` |
| Personalidade | Parcial | `traits` (10 traços, ex.: teimoso, curioso, mentiroso). Sem as 10 dimensões numéricas da spec |
| Necessidades (fome, cansaço, dinheiro) | **Validado (Fase 1)** | `NpcNeedsModule`: fome, cansaço e ouro; comer na taverna e descansar em casa mudam o caminho |
| Objetivos curto/médio/longo prazo | Parcial | Curto prazo ("comer", "descansar"), médio prazo ("juntar_ouro", meta de 15 de ouro, trabalho rende ouro) e longo prazo ("abrir_negocio", meta de 40 de ouro). Trabalho produz o bem da profissão na economia da vila (`WORK_DONE`) |
| Decisão autônoma (utilidade) | Parcial | Decisão por utilidade entre necessidades acima do limite e, na agenda, quem junta ouro fica no posto no horário de trabalho. Compra de ferramenta pela história feita; outras compras faltam |
| Atividades e humor | **Validado (0.7.1)** | `NpcLifeModule`: medo, alegria e atividade no rótulo |
| Memória social | **Validado** | `MemoryModule`: testemunhas, rumores no mesmo local, reputação, esquecimento |
| Relações multidimensionais | **Validado (Fase 2)** | `RelationsModule`: confiança, afeto, respeito, medo, ressentimento, admiração, lealdade, interesse e familiaridade por par; alimentadas por `MEMORY_FORMED` e convivência |
| Família como agentes reais | Parcial | Família existe (`family`), com residência e atividades. Sem objetivos próprios |
| Moralidade e reputação localizada | Parcial | Reputação por morador, família e facção. Sem reputação por cidade ou reino |
| Rumores | **Validado** | `MemoryModule`, com perda de confiabilidade |
| Crimes e violência | Parcial | `CrimeModule`, `NpcLifeModule`. Sem sucessão de liderança |
| Economia regional (estoques, preços, rotas) | Parcial | `EconomyModule`: estoques da vila e de Valkaria, preços. Sem rede de rotas nem contratos |
| Carroças e entregas | **Validado (0.7.1)** | `CartsModule`: carga, entrega, retorno. Sem passageiros nem assalto |
| Cidades dinâmicas (indicadores, desenvolvimento, decadência) | Ausente | Só existe o estado da vila |
| Política e facções | Parcial | `FactionModule`: bandidos, guarda. Sem negociação, alianças ou sucessão |
| Identidade racial e preconceito | Parcial | `bias` por traço (`desconfia_de_estrangeiros`). Sem leis regionais |
| Party e recrutamento | Ausente | Não há |
| Guildas | Ausente | Não há (nenhuma menção no código) |
| Magia com consequências no mundo | Ausente | Magias existem em combate; não afetam economia ou política |
| Corrupção da Tormenta | Ausente | Não há |
| Prólogo Vivo (questionário, origens) | Ausente | Há origem T20 na criação; não há histórico narrativo |
| Deixar o Destino Decidir | Ausente | Não há |
| Missões emergentes | Ausente | Há mistérios e pistas; não são geradas por necessidade |
| Homebrews de combate/party | Ausente | Não há |
| Diário vivo do mundo | Parcial | `journal` existe; sem categorias nem notícias por canal |
| Simulação eficiente (níveis de detalhe) | Parcial | Há LOD (`RegionSimModule`, `FaunaModule`); não há política formal por frequência |
| Vertical Slice (aprendiz e a oficina) | Ausente | Ainda não existe o ciclo |
| Cidade 2, mistério 2, viagem entre mapas | **Adiado** | Decisão de escopo |

## Andamento por fase

- **Fase 0 (auditoria):** feita — esta matriz. Riscos: o `NpcModule` concentra localização e agenda, e já recebe várias influências (eventos da vila, medo, necessidades, chuva). Novas camadas devem entrar por um ponto único de decisão (`desired_location`) e não por cópias.
- **Fase 1 (agentes e objetivos):** em andamento. Feito: necessidades (fome, cansaço, ouro), objetivo urgente por utilidade, objetivo de médio prazo (juntar ouro), trabalho que rende ouro, ação de comer e descansar, persistência. Feito também: objetivo de longo prazo (abrir negócio, meta de 40 de ouro); refeição paga na taverna consome comida da vila e leva o ouro ao tesouro (`MEAL_SERVED`). Feito também: um turno cumprido (6 horas no posto) produz o bem da profissão (`WORK_DONE`), somado ao estoque da vila (`producao_trabalho` em `economy.json`). Feito também: utilidade para a agenda. No horário de trabalho, quem junta ouro e não tem urgência fica no posto em vez do lazer previsto (almoço, pausa). Urgências de comer e descansar continuam vencendo. Feito também: visita por utilidade. No tempo livre, o morador de outra casa com afeto acima de 30 (de 100) vai à casa dele, se ele estiver em casa; o de maior afeto vence. Feito também: compra de ferramenta de ofício pela história. Quem começou o ofício há 2 anos ou mais (a partir de 16 anos) já tem a sua; quem não tem e junta o preço (8 de ouro) compra com a Mara no tempo livre (`TOOL_BOUGHT`, o ouro vai ao tesouro e sai uma ferramenta do estoque). Falta: outras compras de moradores (comida para casa, materiais).
- **Fase 2 (memória e sociedade):** relações multidimensionais feitas (`RelationsModule`, com traços: teimoso, memória longa, exige provas) e reações por rótulo (confia, amigável, indiferente, teme, guarda rancor). Diálogos ligados à reação na primeira conversa do dia (`reacao` em `voices.json`). Feito também: família sustenta criança (quando uma criança tem fome e não tem ouro, um adulto da família paga a refeição, se tiver duas refeições de reserva; `FAMILY_SUPPORT`) e consequência por grupo (a reputação da facção do vendedor muda o preço de todos os seus vendedores: +25% com facção hostil, -10% com facção amiga; `FACTION_HOSTILE_AT` e `FACTION_FRIENDLY_AT` em `economy_module.gd`). Falta: família com objetivo de médio prazo próprio (ex.: poupar para a casa) e desgaste de ferramentas (ver `docs/REFERENCIAS_SIMULACAO.md`).
- **Fase 3 (Prólogo Vivo):** parcial. Feito: perguntas A a F, gerador de começo (`Prologue`), destino por semente reproduzível, validação contra o mundo, comando `StartPrologue` (uma vez), ouro e vínculos iniciais. Feito também: o começo move o jogador para o lugar do passado (`StartPrologue` → posição do jogador); `Game.start_prologue` e `Game.start_prologue_from_seed` ("Deixar o Destino Decidir" pela semente) recarregam a cena. **Importante: nenhuma tela chama esses comandos ainda, então o prólogo ainda não é alcançável pelo jogador.** Falta: a tela do questionário (seis perguntas) e o botão "Deixar o Destino Decidir" na criação.
- **Fase 4 (economia regional):** parcial. Feito: rota comercial (`valkaria_vila`) que pode ser fechada e reaberta por DISTANT_EVENT, com fato `ROUTE_CHANGED`; com a rota fechada o mensageiro não entrega; reaberta, a entrega volta sem perda. Falta: crises de preço e recuperação explícitas, mais rotas e mercadorias de outras regiões.
- **Fase 5 (cidades e organizações):** parcial. Feito: abastecimento da vila (média de estoque sobre meta); decadência após dias seguidos de escassez e recuperação sem o jogador (`CITY_STATUS_CHANGED`); sucessão de líder por morte, com o membro vivo mais velho, ou organização fragmentada (`LEADERSHIP_CHANGED`). Indicadores urbanos (`indicators`: abastecimento, saúde, prosperidade, estabilidade). Falta: segurança e moradia, desenvolvimento por construção e influência política.
- **Fase 6 (party e guildas):** parcial. Feito: recrutamento com consentimento (confiança e familiaridade, ou pagamento que cubra o risco; reputação sozinha não recruta), ordens guardadas, lealdade diária, perda por morte (`PARTY_LOST`) e guilda (dois membros e 50 de ouro, criada uma vez). Falta: ordens no combate, contratos da guilda e administração.
- **Fase 7 (magia e Tormenta):** parcial. Feito: três variáveis separadas (pressão, corrupção, contenção); pressão só vem de incidente sobrenatural (`MAGIC_INCIDENT`); corrupção acumula e não some; estágios 0 a 4 com fato `TORMENTA_STAGE_CHANGED`; contenção pela Guarda gasta soldados (`ContainTormenta`); crise tira comida da vila. Falta: magia integrada ao combate e à economia além da comida, e ganchos narrativos (desaparecimentos, cultos).
- **Fase 8 (homebrews e combate em equipe):** parcial. Feito: sete regras homebrew opcionais com id, versão, justificativa, dependências e conflitos (`HomebrewModule`, comando `SetHomebrew`); Party Tática e Parceiro T20 não se somam. Padrão: tudo desligado. Falta: efeito das regras no combate (ações de empurrar, desarmar, ordens) e balanceamento (decisão humana).
- **Fase 9 (história e integração):** parcial. Feito: diário vivo por categoria (`ChronicleModule`), que consome fatos antes sem consumidor (liderança, cidade, Tormenta, rota, guilda, perdas); salvo com o jogo. Vertical slice "O futuro do aprendiz" coberto em `tests/unit/test_aprendiz.gd`: junta ouro, rota cortada encarece ferramentas, jogador protege a rota, ajuda muda a reação, e o ciclo sobrevive a salvar e carregar. Notícias por canal (`news_via`: mercador, mensageiro, taverneiro). Falta: rumores históricos que se espalham entre moradores, a Crônica do Reino na interface e a build de avaliação.

## Regras de execução (da spec) aplicadas

- Nenhum executável novo até juntar mudanças relevantes (Regra 10, e a diretriz D2).
- Nada de IA generativa na simulação (Regra 6).
- Vilas, mistério 2 e viagem entre mapas seguem adiados (Regra 9).

## Desempenho medido (26/10/2026, contêiner sem GPU)

`tools/benchmark.gd` headless, 24 moradores em L0, após os módulos de Arton Viva:

| Medida | Antes (0.7.0) | Agora |
|---|---|---|
| Comando p95 | 1,1 ms | 3,4 ms |
| Save (medido) | 8 ms | 24 ms (save p95 56 ms antes do ajuste de relações) |
| Load | 31 ms | 151 ms no benchmark (p95 17 ms na telemetria) |

O quadro aparece em 16,7 ms porque o modo headless fica preso a 60 quadros por segundo; ele não mede GPU. O maior peso do save eram as relações entre todos os pares de moradores: 78 KB. Agora só grava pares com alguma dimensão sensível, e o bloco caiu para 15 KB. O load do benchmark ainda inclui a primeira carga, por isso o p95 da telemetria é o número a acompanhar. A medição em hardware real continua pendente (§15).
