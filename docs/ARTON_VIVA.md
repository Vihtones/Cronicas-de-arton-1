# Arton Viva — auditoria (Fase 0) e andamento

Documento-base: `CDA-WORLD-001` v1.0 (25/10/2026). Este arquivo registra o que o repositório realmente tem, o que falta e o andamento de cada fase. Estado verificado em 25/10/2026: 199 testes, 0 violações de arquitetura, 0 apontamentos de estilo.

## Matriz de requisitos

Legenda: **Validado** (implementado e testado), **Parcial**, **Existe sem integração**, **Ausente**, **Adiado** (decisão de escopo).

| Área (spec) | Situação | Onde está / o que falta |
|---|---|---|
| Agentes (WorldAgent, dados principais) | Parcial | Cada morador é um registro em `data/world/npcs.json` + estado em `NpcModule`. Não há um modelo comum `WorldAgent` |
| Personalidade | Parcial | `traits` (10 traços, ex.: teimoso, curioso, mentiroso). Sem as 10 dimensões numéricas da spec |
| Necessidades (fome, cansaço, dinheiro) | **Validado (Fase 1)** | `NpcNeedsModule`: fome, cansaço e ouro; comer na taverna e descansar em casa mudam o caminho |
| Objetivos curto/médio/longo prazo | Parcial | Curto prazo ("comer", "descansar"), médio prazo ("juntar_ouro", meta de 15 de ouro, trabalho rende ouro) e longo prazo ("abrir_negocio", meta de 40 de ouro). Sem agir sobre a economia |
| Decisão autônoma (utilidade) | Parcial | Decisão por utilidade entre necessidades acima do limite (a de maior valor vence). Sem utilidade para ações da agenda |
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
- **Fase 1 (agentes e objetivos):** em andamento. Feito: necessidades (fome, cansaço, ouro), objetivo urgente por utilidade, objetivo de médio prazo (juntar ouro), trabalho que rende ouro, ação de comer e descansar, persistência. Feito também: objetivo de longo prazo (abrir negócio, meta de 40 de ouro); refeição paga na taverna consome comida da vila e leva o ouro ao tesouro (`MEAL_SERVED`). Falta: o trabalho dos moradores ainda não produz mercadoria na economia da vila.
- **Fase 2 (memória e sociedade):** relações multidimensionais feitas (`RelationsModule`, com traços: teimoso, memória longa, exige provas) e reações por rótulo (confia, amigável, indiferente, teme, guarda rancor). Diálogos ligados à reação na primeira conversa do dia (`reacao` em `voices.json`). Falta: família com objetivos próprios.
- **Fases 3 a 9:** não iniciadas.

## Regras de execução (da spec) aplicadas

- Nenhum executável novo até juntar mudanças relevantes (Regra 10, e a diretriz D2).
- Nada de IA generativa na simulação (Regra 6).
- Vilas, mistério 2 e viagem entre mapas seguem adiados (Regra 9).
