# Regras usadas pelo jogo e sua proveniência

Gerado por `tools/build_rules_report.py` a partir de `data/rules/`. **Não edite à mão.**

Página = página impressa do livro; PDF = página do arquivo PDF, para conferência.

| Status | Quantidade |
|---|---|
| ADAPTADA | 1 |
| VERIFICADA | 135 |

| Arquivo | Regra | Fonte | Pág. | PDF | Status | Nota |
|---|---|---|---|---|---|---|
| ameacas | `criatura.bandido_comum` | Bestiário Tormenta20 | 43 | 45 | VERIFICADA |  |
| ameacas | `criatura.bandido_ligeiro` | Bestiário Tormenta20 | 43 | 45 | VERIFICADA |  |
| ameacas | `criatura.hiena` | Bestiário Tormenta20 | 120 | 122 | VERIFICADA | Reconferido com layout preservado (pdftotext -layout). ND pressupõe grupo de 4. |
| core | `teste.basico` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `teste.oposto.empate` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `pericia.valor` | T20 Livro Básico | 114 | 120 | VERIFICADA |  |
| core | `pericia.bonus_treino` | T20 Livro Básico | 114 | 120 | VERIFICADA |  |
| core | `pericia.tabela` | T20 Livro Básico | 115 | 121 | VERIFICADA |  |
| core | `cd.tabela` | T20 Livro Básico | 220 | 226 | VERIFICADA |  |
| core | `cd.resistencia` | T20 Livro Básico | 227 | 233 | VERIFICADA |  |
| core | `atributos.compra_pontos` | T20 Livro Básico | 17 | 23 | VERIFICADA |  |
| core | `defesa.base` | T20 Livro Básico | 106 | 112 | VERIFICADA | R1: 'Sua Defesa é 10 + sua Destreza + seu bônus de armadura e escudo' (conferido em 24/10/2026). |
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
| core | `descanso.duracao_horas` | T20 Livro Básico | 106 | 112 | VERIFICADA | R1: 'uma noite de descanso (pelo menos oito horas de sono)'. |
| core | `descanso.minimo` | T20 Livro Básico | 106 | 112 | ADAPTADA | Metade do nível 1 arredonda para 0; o jogo usa mínimo 1. |
| core | `dano.nao_letal` | T20 Livro Básico | 236 | 242 | VERIFICADA |  |
| core | `condicoes` | T20 Livro Básico | 394 | 400 | VERIFICADA |  |
| equipamento | `arma.adaga` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.espada_curta` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.clava` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.lanca` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.funda` | T20 Livro Básico | 148 | 154 | VERIFICADA | R1: tabela p.144; 'você aplica sua Força a rolagens de dano com uma funda'; recarregar é ação de movimento (p.148). |
| equipamento | `arma.arco_curto` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.espada_longa` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `arma.machado_batalha` | T20 Livro Básico | 144 | 150 | VERIFICADA |  |
| equipamento | `armadura.couro_batido` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `armadura.gibao_peles` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `armadura.cota_malha` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `escudo.leve` | T20 Livro Básico | 153 | 159 | VERIFICADA |  |
| equipamento | `alcance.metros` | T20 Livro Básico | 143 | 149 | VERIFICADA |  |
| equipamento | `alcance.quadrados` | T20 Livro Básico | 143 | 149 | VERIFICADA |  |
| fe | `panteao.nomes` | T20 Livro Básico | 96 | 102 | VERIFICADA | R1: 'Os vinte deuses do Panteão de Arton' (p.100); obrigações individuais só de Lena, Khalmyr e Allihanna. |
| fe | `deus.lena.obrigacao` | T20 Livro Básico | 100 | 106 | VERIFICADA |  |
| fe | `deus.khalmyr.obrigacao` | T20 Livro Básico | 99 | 105 | VERIFICADA |  |
| fe | `deus.allihanna.obrigacao` | T20 Livro Básico | 97 | 103 | VERIFICADA |  |
| personagem | `classe.guerreiro` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `classe.guerreiro.ataque_extra` | T20 Livro Básico | 66 | 72 | VERIFICADA |  |
| personagem | `raca.humano` | T20 Livro Básico | 19 | 25 | VERIFICADA |  |
| personagem | `envelhecimento` | T20 Livro Básico | 108 | 114 | VERIFICADA |  |
| personagem | `manobra.derrubar` | T20 Livro Básico | 234 | 240 | VERIFICADA |  |
| personagem | `poder.especializacao_arma` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `poder.valentao` | T20 Livro Básico | 66 | 72 | VERIFICADA |  |
| personagem | `poder.aumento_atributo` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `poder.golpe_raspao` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `poder.gatuno` | T20 Livro Básico | 74 | 80 | VERIFICADA |  |
| personagem | `poder.truque_magico` | T20 Livro Básico | 74 | 80 | VERIFICADA |  |
| personagem | `poder.ataque_reflexo` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `poder.impeto` | T20 Livro Básico | 66 | 72 | VERIFICADA |  |
| personagem | `poder.arqueiro` | T20 Livro Básico | 65 | 71 | VERIFICADA |  |
| personagem | `poder.emboscar` | T20 Livro Básico | 73 | 79 | VERIFICADA |  |
| personagem | `poder.velocidade_ladina` | T20 Livro Básico | 74 | 80 | VERIFICADA |  |
| personagem | `poder.rolamento_defensivo` | T20 Livro Básico | 74 | 80 | VERIFICADA |  |
| personagem | `poder.sombra` | T20 Livro Básico | 74 | 80 | VERIFICADA |  |
| personagem | `poder.arcano_de_batalha` | T20 Livro Básico | 38 | 44 | VERIFICADA |  |
| personagem | `poder.magia_pungente` | T20 Livro Básico | 38 | 44 | VERIFICADA |  |
| personagem | `poder.poder_magico` | T20 Livro Básico | 38 | 44 | VERIFICADA |  |
| personagem | `poder.raio_arcano` | T20 Livro Básico | 39 | 45 | VERIFICADA |  |
| personagem | `poder.geral.troca` | T20 Livro Básico | 124 | 130 | VERIFICADA |  |
| personagem | `poder.ataque_poderoso` | T20 Livro Básico | 124 | 130 | VERIFICADA |  |
| personagem | `poder.trespassar` | T20 Livro Básico | 129 | 135 | VERIFICADA |  |
| personagem | `poder.quebrar_aprimorado` | T20 Livro Básico | 129 | 135 | VERIFICADA |  |
| personagem | `poder.combate_defensivo` | T20 Livro Básico | 125 | 131 | VERIFICADA |  |
| personagem | `poder.derrubar_aprimorado` | T20 Livro Básico | 125 | 131 | VERIFICADA |  |
| personagem | `poder.desarmar_aprimorado` | T20 Livro Básico | 125 | 131 | VERIFICADA |  |
| personagem | `poder.esquiva` | T20 Livro Básico | 125 | 131 | VERIFICADA |  |
| personagem | `poder.reflexos_combate` | T20 Livro Básico | 129 | 135 | VERIFICADA |  |
| personagem | `poder.saque_rapido` | T20 Livro Básico | 129 | 135 | VERIFICADA |  |
| personagem | `poder.vitalidade` | T20 Livro Básico | 129 | 135 | VERIFICADA |  |
| personagem | `poder.vontade_de_ferro` | T20 Livro Básico | 131 | 137 | VERIFICADA |  |
| personagem | `npc.estatisticas` | T20 Livro Básico | 323 | 329 | VERIFICADA | Tabela 7-2: perícias = [focadas, demais] (p.322). |
| personagem | `classe.guerreiro.durao` | T20 Livro Básico | 66 | 72 | VERIFICADA |  |
| personagem | `progressao.xp_por_nivel` | T20 Livro Básico | 35 | 41 | VERIFICADA |  |
| personagem | `progressao.xp_desafio` | T20 Livro Básico | 326 | 332 | VERIFICADA |  |
| personagem | `raca.anao` | T20 Livro Básico | 20 | 26 | VERIFICADA |  |
| personagem | `tamanho.modificadores` | T20 Livro Básico | 107 | 113 | VERIFICADA |  |
| personagem | `raca.dahllan` | T20 Livro Básico | 21 | 27 | VERIFICADA |  |
| personagem | `raca.elfo` | T20 Livro Básico | 22 | 28 | VERIFICADA |  |
| personagem | `raca.goblin` | T20 Livro Básico | 23 | 29 | VERIFICADA |  |
| personagem | `raca.lefou` | T20 Livro Básico | 24 | 30 | VERIFICADA |  |
| personagem | `raca.minotauro` | T20 Livro Básico | 25 | 31 | VERIFICADA |  |
| personagem | `raca.qareen` | T20 Livro Básico | 26 | 32 | VERIFICADA |  |
| personagem | `raca.golem` | T20 Livro Básico | 27 | 33 | VERIFICADA |  |
| personagem | `raca.hynne` | T20 Livro Básico | 28 | 34 | VERIFICADA |  |
| personagem | `raca.kliren` | T20 Livro Básico | 28 | 34 | VERIFICADA |  |
| personagem | `raca.medusa` | T20 Livro Básico | 29 | 35 | VERIFICADA |  |
| personagem | `raca.osteon` | T20 Livro Básico | 29 | 35 | VERIFICADA |  |
| personagem | `raca.sereia` | T20 Livro Básico | 30 | 36 | VERIFICADA |  |
| personagem | `raca.silfide` | T20 Livro Básico | 30 | 36 | VERIFICADA |  |
| personagem | `raca.aggelus` | T20 Livro Básico | 31 | 37 | VERIFICADA |  |
| personagem | `raca.sulfure` | T20 Livro Básico | 31 | 37 | VERIFICADA |  |
| personagem | `raca.trog` | T20 Livro Básico | 31 | 37 | VERIFICADA |  |
| personagem | `racas.tabela` | T20 Livro Básico | 18 | 24 | VERIFICADA |  |
| personagem | `classe.ladino` | T20 Livro Básico | 73 | 79 | VERIFICADA |  |
| personagem | `classe.arcanista` | T20 Livro Básico | 37 | 43 | VERIFICADA |  |
| personagem | `magia.custo_por_circulo` | T20 Livro Básico | 170 | 176 | VERIFICADA |  |
| personagem | `classe.ladino.lista` | T20 Livro Básico | 73 | 79 | VERIFICADA |  |
| personagem | `classe.arcanista.lista` | T20 Livro Básico | 37 | 43 | VERIFICADA |  |
| personagem | `pericias.escolha` | T20 Livro Básico | 114 | 120 | VERIFICADA |  |
| personagem | `classe.arcanista.caminho` | T20 Livro Básico | 37 | 43 | VERIFICADA |  |
| personagem | `magia.cd_resistencia` | T20 Livro Básico | 173 | 179 | VERIFICADA |  |
| personagem | `magia.concentracao` | T20 Livro Básico | 170 | 176 | VERIFICADA |  |
| personagem | `magia.armadura_e_arcana` | T20 Livro Básico | 171 | 177 | VERIFICADA |  |
| personagem | `magia.armadura_arcana` | T20 Livro Básico | 183 | 189 | VERIFICADA |  |
| personagem | `magia.toque_chocante` | T20 Livro Básico | 209 | 215 | VERIFICADA |  |
| personagem | `magia.seta_infalivel` | T20 Livro Básico | 206 | 212 | VERIFICADA |  |
| personagem | `magia.curar_ferimentos` | T20 Livro Básico | 189 | 195 | VERIFICADA |  |
| personagem | `acao.usar_item_pocao` | T20 Livro Básico | 234 | 240 | VERIFICADA |  |
| personagem | `item.saco_de_dormir` | T20 Livro Básico | 156 | 162 | VERIFICADA |  |
| personagem | `item.pocao_curar_ferimentos` | T20 Livro Básico | 341 | 347 | VERIFICADA | R1: tabela de poções, Curar Ferimentos (2d8+2 PV) T$ 30. |
| personagem | `viagem.velocidade` | T20 Livro Básico | 270 | 276 | VERIFICADA |  |
| personagem | `viagem.marcha_forcada` | T20 Livro Básico | 270 | 276 | VERIFICADA |  |
| personagem | `perigo.jornada_ermos` | T20 Livro Básico | 320 | 326 | VERIFICADA |  |
| personagem | `perigo.jornada_ermos.cd` | T20 Livro Básico | 320 | 326 | VERIFICADA | R1: CD varia conforme o terreno. |

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
| XP de mistério resolvido = ND 1 ('XP alternativo', LB p.326) | `ProgressionModule.MYSTERY_ND` | ORIGINAL | constante |
| Fuga e captura não rendem XP (decisão do usuário: fugir não se recompensa; antes era ½ e ¼ do livro) | `ProgressionModule` | ADAPTADA | — |
| Presets de atributos e perícias padrão por classe | `CharacterBuilder` | ORIGINAL (dentro das regras) | — |
| Bruxo: o foco é considerado empunhado; sem PV/RD do foco | `CharacterBuilder`, `CombatModule._cast` | ADAPTADA (simplificação) | LB p.37 |
| Feiticeiro sem linhagem; Mago sem memorização e com 3 magias em vez de 4 | `CharacterBuilder` | ADAPTADA (pendente) | LB p.37 |
| Concentração: só condição ruim (caído, tempestade); ser ferido na execução não ocorre (não há reações) | `CombatModule.casting_cd` | ADAPTADA (parcial) | LB p.170 |
| Toque Chocante: −5 por armadura de metal só quando a ficha registra a armadura | `CombatModule._cast` | ADAPTADA | LB p.209 |
| Alcance médio de magia = 20 quadrados | `GhostPlanner` (cast) | PLACEHOLDER (alcance.metros pendente) | — |
| Relento com saco de dormir = condição normal | `StateModule.rest_quality` | ADAPTADA | — |
| Rotas, distâncias e risco de emboscada (5%/20% por dia) | `TravelModule` | ORIGINAL | constantes |
| Domínio: renda, moral, segurança, conselheiros | `DomainModule` | ORIGINAL | constantes |
| Casais, chance de nascimento 15%/ano; herança ao parente vivo mais velho; herdeiro com ½ do ouro | `LineageModule` | ORIGINAL | constantes |
| Aventureiros NPC: missões 25%/dia, ND sorteado, XP pela regra do LB | `AdventurersModule` | ORIGINAL (XP: LB) | constantes |
| Matilha: comida, caça por estação, ataques a ovelhas, crescimento até 4 | `FaunaModule` | ORIGINAL | constantes |
| Investigação criminal: Investigação +4 da capitã vs CD 20 − pistas | `CrimeModule._investigate` | PLACEHOLDER | — |
| Preconceito individual: −10 de reputação e +20% no preço até 3 memórias | `MemoryModule.bias`, `EconomyModule.price` | ORIGINAL | traço do NPC |
| Vinhetas do diretor de ritmo | `PacingModule` | ORIGINAL | — |
