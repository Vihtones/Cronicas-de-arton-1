# Regras usadas pelo jogo e sua proveniência

Gerado por `tools/build_rules_report.py` a partir de `data/rules/`. **Não edite à mão.**

Página = página impressa do livro; PDF = página do arquivo PDF, para conferência.

| Status | Quantidade |
|---|---|
| ADAPTADA | 1 |
| PENDENTE_REVISAO | 6 |
| VERIFICADA | 51 |

| Arquivo | Regra | Fonte | Pág. | PDF | Status | Nota |
|---|---|---|---|---|---|---|
| ameacas | `criatura.bandido_comum` | Bestiário Tormenta20 | 43 | 45 | VERIFICADA |  |
| ameacas | `criatura.bandido_ligeiro` | Bestiário Tormenta20 | 43 | 45 | VERIFICADA |  |
| ameacas | `criatura.hiena` | Bestiário Tormenta20 | 120 | 122 | PENDENTE_REVISAO | Bloco extraído de layout em colunas; conferir valores. |
| core | `teste.basico` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `teste.oposto.empate` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `pericia.valor` | T20 Livro Básico | 114 | 120 | VERIFICADA |  |
| core | `pericia.bonus_treino` | T20 Livro Básico | 114 | 120 | VERIFICADA |  |
| core | `pericia.tabela` | T20 Livro Básico | 115 | 121 | VERIFICADA |  |
| core | `cd.tabela` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `cd.resistencia` | T20 Livro Básico | 227 | 233 | VERIFICADA |  |
| core | `atributos.compra_pontos` | T20 Livro Básico | 17 | 23 | VERIFICADA |  |
| core | `defesa.base` | T20 Livro Básico | 106 | 112 | PENDENTE_REVISAO | Linha encontrada por busca; conferir parágrafo completo. |
| core | `ataque.teste` | T20 Livro Básico | 230 | 236 | VERIFICADA |  |
| core | `dano.forca` | T20 Livro Básico | 230 | 236 | VERIFICADA |  |
| core | `critico` | T20 Livro Básico | 230 | 237 | VERIFICADA |  |
| core | `iniciativa` | T20 Livro Básico | 231 | 237 | VERIFICADA |  |
| core | `surpresa` | T20 Livro Básico | 231 | 237 | VERIFICADA |  |
| core | `turno.acoes` | T20 Livro Básico | 233 | 239 | VERIFICADA |  |
| core | `rodada.segundos` | T20 Livro Básico | 233 | 239 | VERIFICADA |  |
| core | `deslocamento.padrao_m` | T20 Livro Básico | 238 | 244 | VERIFICADA |  |
| core | `mapa.quadrado_m` | T20 Livro Básico | 236 | 242 | VERIFICADA |  |
| core | `mapa.diagonal` | T20 Livro Básico | 238 | 244 | VERIFICADA | Diagonal custa o dobro. |
| core | `mapa.terreno_dificil` | T20 Livro Básico | 238 | 244 | VERIFICADA |  |
| core | `mapa.espaco_inimigo` | T20 Livro Básico | 238 | 244 | VERIFICADA |  |
| core | `situacao.flanquear` | T20 Livro Básico | 239 | 245 | VERIFICADA |  |
| core | `situacao.cobertura_leve` | T20 Livro Básico | 239 | 245 | VERIFICADA |  |
| core | `situacao.camuflagem_leve` | T20 Livro Básico | 238 | 244 | VERIFICADA |  |
| core | `situacao.atacante_caido` | T20 Livro Básico | 239 | 245 | VERIFICADA |  |
| core | `distancia.em_corpo_a_corpo` | T20 Livro Básico | 233 | 239 | VERIFICADA |  |
| core | `distancia.dobro_alcance` | T20 Livro Básico | 233 | 239 | VERIFICADA |  |
| core | `acao.investida` | T20 Livro Básico | 235 | 241 | VERIFICADA |  |
| core | `acao.golpe_misericordia` | T20 Livro Básico | 235 | 241 | VERIFICADA |  |
| core | `ferimentos.zero_pv` | T20 Livro Básico | 236 | 242 | VERIFICADA |  |
| core | `ferimentos.morte` | T20 Livro Básico | 236 | 242 | VERIFICADA | Morre em -10 ou metade negativa dos PV totais, o que for mais baixo. |
| core | `descanso.recuperacao` | T20 Livro Básico | 106 | 112 | VERIFICADA |  |
| core | `descanso.ruim_relento` | T20 Livro Básico | 106 | 112 | VERIFICADA |  |
| core | `descanso.duracao_horas` | T20 Livro Básico | 106 | 112 | PENDENTE_REVISAO | Duração de 'uma noite de sono' assumida como 8h; conferir texto. |
| core | `descanso.minimo` | T20 Livro Básico | 106 | 112 | ADAPTADA | Metade do nível 1 arredonda para 0; o jogo usa mínimo 1. |
| core | `dano.nao_letal` | T20 Livro Básico | 236 | 242 | VERIFICADA |  |
| core | `condicoes` | T20 Livro Básico | 394 | 400 | VERIFICADA |  |
| equipamento | `arma.adaga` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.espada_curta` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.clava` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.lanca` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.funda` | T20 Livro Básico | 144 | 150 | VERIFICADA | Funda soma For no dano (regra específica da arma, p.148) — PENDENTE_REVISAO |
| equipamento | `arma.arco_curto` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.espada_longa` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.machado_batalha` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `armadura.couro_batido` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `armadura.gibao_peles` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `armadura.cota_malha` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `escudo.leve` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `alcance.metros` | T20 Livro Básico | 0 | 0 | PENDENTE_REVISAO | Valores de memória; conferir no livro antes de marcar VERIFICADA. |
| fe | `panteao.nomes` | T20 Livro Básico | 96 | 102 | PENDENTE_REVISAO | Nomes conferidos por contagem no texto; obrigações individuais a extrair. |
| fe | `deus.lena.obrigacao` | T20 Livro Básico | 100 | 106 | VERIFICADA |  |
| personagem | `classe.guerreiro` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `raca.humano` | T20 Livro Básico | 0 | 0 | PENDENTE_REVISAO | Versátil confirmado no texto; página exata a anotar. |
| personagem | `envelhecimento` | T20 Livro Básico | 108 | 114 | VERIFICADA |  |

## Mecânicas ORIGINAL_DO_JOGO e ADAPTADA (fora do catálogo de regras)

| Mecânica | Onde | Classificação | Configurável |
|---|---|---|---|
| Ficha pronta: Guerreiro humano nível 1 (atributos por compra de pontos) | `CharacterSheet.premade_warrior` | ORIGINAL (montada com regras do LB) | — |
| Anti-loop: repetir a mesma abordagem exige outra perícia, valor diferente ou 1 dia | `ExplorationModule.RETRY_TICKS` | ORIGINAL | sim (constante) |
| Dormindo: −10 em Percepção para notar furtividade/barulho | `CombatModule` | ADAPTADA | — |
| Bandidos capturam quem cai em vez de executar; hienas não | `CombatModule._ai_turn/_check_end` | ORIGINAL | — |
| Neblina/tempestade: +5 na CD de percepção ao ar livre | `WeatherModule.perception_cd_mod` | ADAPTADA | `weather_affects_tests` |
| Chuva leva NPCs para dentro | `NpcModule.desired_location` | ORIGINAL | desligar módulo clima |
| Cripta iluminada por tochas (sem escuridão) | `WeatherModule.env_at` | ORIGINAL | — |
| Fuga: 10 quadrados longe de todos os inimigos conscientes | `CombatModule.FLEE_DISTANCE` | ORIGINAL | constante |
| Rumores: 35% por hora entre NPCs no mesmo local, confiabilidade ×0,8 | `MemoryModule` | ORIGINAL | constantes |
| Incursão da Guarda resolvida em L2 por força relativa | `FactionModule._resolve_raid` | ORIGINAL | — |
| Economia agregada com preços limitados a 0,5×–3× | `EconomyModule` | ORIGINAL | `data/world/economy.json` |
| Calendário 30 dias × 12 meses, estações por trimestre | `WorldClock`, `WeatherModule.season` | PLACEHOLDER | sim |
| 1 tick = 10 min; 2 s reais por tick | `WorldClock`, `Game.settings` | PLACEHOLDER (§20.7) | sim |
| Mistério 'O Filho do Moleiro', vila, NPCs, facções, diálogos | `data/world`, `data/dialogue` | ORIGINAL_DO_JOGO | — |
