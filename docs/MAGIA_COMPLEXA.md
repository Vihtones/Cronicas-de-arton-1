# Sistemas para magias complexas

Base para as magias de área, terreno, maldição e invocação. Cada sistema é independente e
testado em `tests/unit/test_magia_complexa.gd`. Medidas em quadrados de 1,5m (`Area.quadrados`).

## O que existe

| Sistema | Onde | O que faz |
|---|---|---|
| Geometria de área | `src/domain/combat/area.gd` | `esfera` (também cilindro e cubo), `cone` (90 graus), `linha`, `quadrados(metros)`. Funções puras. |
| Zonas | `CombatSim.zonas`, `add_zona`, `zona_em` | Área persistente no terreno (muralha, névoa, terreno difícil). Terreno difícil já dobra o custo do passo. Expira em N rodadas, ou nunca (`rodadas = -1`). Dados opcionais: dano ou cura por turno, quem é afetado. |
| Marcas | `CombatSim.marcas`, `add_marca`, `tem_marca` | Efeito preso a uma criatura (maldição, vínculo, invocação). Expira em N rodadas. Dados opcionais: dano ou cura por turno. |
| Invocação | `CombatModule.invocar` | Cria uma criatura do bestiário (`criatura.*`) do lado do conjurador, logo depois dele na ordem. Com marca `invocacao`, sai da simulação ao expirar. |
| PV temporários | `CharacterSheet.pv_temp`, `CombatSim.apply_damage` | Absorvem dano antes dos PV. Zeram ao fim do combate. |
| Ids em área | `CombatSim.ids_em(tiles)` | Criaturas conscientes cujo quadrado está na área. |
| Remover criatura | `CombatSim.remove_combatant` | Tira uma criatura da ordem sem quebrar a vez atual. |

Tudo isso é salvo com o combate (zonas e marcas em `CombatModule.to_dict`).

## Como usar em uma magia nova

- **Área**: `var alvos := Area.esfera(centro, Area.quadrados(6.0))` e depois `sim.ids_em(alvos)`.
- **Terreno persistente**: `sim.add_zona("muralha_x", tiles, "terreno_dificil", 3, "magia.muralha_de_ossos")`.
  Para outro tipo de zona, use um tipo novo e trate-o onde ele tem efeito.
- **Maldição ou vínculo**: `sim.add_marca(id, alvo, "magia.ligacao_sombria", "maldicao", rodadas, {"dano_inicio_turno": "1d6", "conjurador": conj})`.
- **Zona com efeito por turno**: `sim.add_zona(id, tiles, "fogo", rodadas, fonte, {"dano_inicio_turno": "2d6", "afeta": "inimigos", "lado": lado_do_conjurador, "conjurador": conj})`.
  Dano e cura são aplicados no início do turno de cada criatura afetada (`_zonas_e_marcas_inicio_de_turno`).
- **Invocação**: `c.invocar(conjurador, "criatura.hiena", rodadas, "servo_divino")`.
- **PV temporários**: `sheet.pv_temp += 40` (Heroísmo).

## O que ainda não existe

Estes sistemas guardam o estado, mas ainda não produzem efeito por si. Cada magia que precisar deles
deve implementar o efeito, e os próximos passos são:

1. **Entrada na zona**: o efeito acontece só no início do turno. Não há efeito ao entrar na zona no meio do turno
   (a Aura Divina já trata a entrada, mas só para o movimento de criaturas, não para a aura se mover).
2. **Movimento bloqueado por zona** (Cúpula de Repulsão, Muralha): hoje a zona só dobra o custo.
3. **Expiração com aviso**: `expiradas` guarda os ids, mas nenhum fato de jogo é emitido ainda.
4. **Servos com ação própria** (Montaria, Servo Divino, Servo Morto-vivo): o Guardião Divino já tem turno próprio
   (`CombatModule._turno_guardiao`, marcado com a flag `guardiao`); a generalização para outros servos ainda não existe.
5. **Escolha do jogador**: magia aprendida ao subir de nível e versão do Manto do Cruzado saem automáticos.

Magia fora de combate: o `SpellsModule` (módulo `magia`, comando `CastSpell`) lança a cura em si mesmo e as
versões de magia que agem no mundo (`FORA_DE_COMBATE`); guarda os cadáveres preservados pela Bênção
(`cadaver_preservado`, que as magias de morto-vivo devem consultar) e as áreas de Consagrar e Profanar
(`maximiza`, `mod_morto_vivo_em`; o combate passa os dados de luz e trevas por `CombatModule._dados_energia`).

Terreno: o mapa marca `natural` e `solo` por tipo de quadrado. Rastrear (LB p.123) é `Checks.cd_rastrear`; ao fugir de
um combate, inimigos treinados em Sobrevivência tentam seguir os rastros e alcançam o jogador (`_tentar_rastrear`).
Adivinhação: o que um NPC sabe são os fatos que o diálogo dele revela (`SpellsModule.fatos_que_sabe`); auras mágicas em
`CombatModule.auras_na_cena` e `SpellsModule.auras_no_mundo`; Misticismo (Detectar Magia) por `DetectMagic` e ação
`detectar_magia`. Execução das magias vem do catálogo (padrão, movimento, completa).
Escuridão mágica: `CombatSim.escuridao_em` (zona `escuridao` ou efeito `fonte_escuridao`), `falha_escuridao`; luz natural não
ilumina sombras; Luz e Escuridão se anulam (`_anular_oposta`). Aprimoramentos "Apenas Arcanos/Divinos" usam `apenas` no
catálogo e a tradição da classe. Pendente de interface: guardar o objeto (ação `guardar_fonte`) e mover globos (`mover_globos`).
Luz (LB p.158, p.318): `CombatSim.iluminado` (zona `luz` ou efeito `fonte_luz` de quem carrega); tocha acesa e chama
na palma ficam em `SpellsModule.luz_carregada` pela cena. A escuridão da noite não vale em quadrado iluminado.
Comida (LB p.161): itens com `alimento`; `UseItem` come (bônus de alimentação, um por dia); água benta é item e ação
`agua_benta` no combate (Shift+5). O diário mostra botões para as magias fora de combate.
Perigos (LB p.318): calor e frio no WeatherModule (`perigo_clima`; o dano só cura fora do clima, `dano_clima`); fumaça
densa (zona `fumaca`) e sufocamento (flag `submerso`) em `CombatModule._perigos_inicio_de_turno`. As fontes de
fumaça e de submersão virão das magias de fogo e água.
Armadilhas (LB p.316): `armadilha.*` em core.json; alvos do mapa com `armadilha` disparam ao pisar
(`ExplorationModule.disparar_armadilha`), salvo conhecidas, desarmadas (Ladinagem; falhar por 5 ativa) ou já disparadas.
Detectar Ameaças: `SpellsModule.detectar`, criaturas em `CombatModule._detectar_criaturas`.
Atitudes (LB p.259): `src/domain/rules/atitudes.gd`; na cena, `CombatModule.atitude_de` (marca `atitude` de magia vale
sobre a natural); só hostil ataca; sem hostis a luta acaba como `pacificado`; fora de combate, `atitude_fora` e
`atitude_temp` (dura `TICKS_CENA`). Mudar Atitude (Diplomacia) e Acalmar Animal (Adestramento): ações `diplomacia`
e `adestrar` (tecla K / Shift+K) e o comando `ChangeAttitude` fora de combate.
Ações hostis: `CombatModule._alvos_hostis` e `_area_hostil` (magias de área ofensivas; as novas entram ali); o Santuário
usa os dois em `_execute_action`. Toque inclui o próprio conjurador (LB p.225).
Presos: marca de tipo `preso` (Controlar Plantas) com a CD; ação `escapar` (Acrobacia ou Atletismo); a IA imóvel tenta.
Vegetação (`vegetacao` no mapa) e poda persistente (`SpellsModule.podas`, zona `poda` na cena).
Truque (LB p.171): `truque: true` no lançamento, 0 PM, sem aprimoramentos.

Duração sustentada (LB p.227): `CombatSim.sustentadas` e `CombatModule._sustentar` cobram 1 PM no início de cada
turno do conjurador; sem pagar, a magia termina (`_encerrar_sustentada`). Uma por vez. Usada por Manto do Cruzado e
Arma Espiritual; as próximas sustentadas devem entrar em `_encerrar_sustentada`.

Resolvido nesta fase: execução longa (`CombatSim.conjurando`, Banimento), concentração ao ser ferido na
execução, ritual de um dia (`CombatModule.processar_rituais_do_dia`, Lágrimas de Wynna), registro de magias
ativas por escola (dissipar), reação após teste (Premonição) e condições com efeito no combate.

Objetos: as portas têm tamanho (`break.tamanho`, Tabela 5-4) e `ObjectsModule.danificar` aplica dano de magia.
Transmutar Objetos (que Despedaçar anula) não está no catálogo.
Armas: Tabela 3-2 (passos de dano) em `arma.passos_de_dano` e `CombatSim.dano_em_passos`; os efeitos de magia na
arma entram em `CombatSim.ataque_efetivo`. Ataque desarmado ainda não existe como ataque da ficha (vem com o lutador);
o Armamento já o aceita (`desarmado: true`).

## Escopo decidido

O objetivo é implementar todas as magias do catálogo (divinas e universais de 1º ao 5º círculo, e as arcanas). A água entra no escopo: aprimoramentos 'sob a água' e similares devem ser implementados sobre o terreno aquático do combate, e nenhuma magia entra em `SpellRules.COMPLETAS` sem todos os aprimoramentos.

## Restante do catálogo (triagem)

Magias do catálogo (`data/rules/personagem.json`) que ainda não estão em `SpellRules.COMPLETAS`:
83 magias. Quatro entradas do filtro (custo, CD, concentração e armadura) são regras, não magias.

- Divinas de 1º círculo: todas feitas.
- Divinas de 2º círculo feitas (13 de 13): Aliado Animal (sistema de parceiros em src/domain/rules/parceiros.gd e PartyModule.parceiros; dados parceiro.* em core.json), Tempestade Divina (zona "tempestade"; CombatSim.ao_ar_livre), Rogar Maldição (sistema de doenças em src/domain/rules/doencas.gd, dados doenca.* em core.json; teste no início do dia pelo PartyModule), Enxame de Pestes (zonas "enxame" de 1 quadrado; dano no fim do turno do conjurador), Miasma Mefítico (efeito cd_magias soma na CD), Controlar Fogo (CombatSim.chama_em: zonas de fogo, tochas, criaturas em chamas; bestiário "composicao" para criaturas de fogo), Augúrio (assunto = um lugar do mapa; miséria = criatura hostil ou armadilha, felicidade = baú ou pista), Círculo da Justiça (SpellsModule.justicas; NPCs no lugar não distorcem boatos), Condição (status_conhecidos), Físico Divino, Mente Divina (atributo muda de verdade e reverte), Oração,
  Purificação, Raio Solar, Soco de Arsenal (empurrão e alcance natural), Voz Divina (Mudar Atitude com não humanoides exige comunicação), Silêncio (alcance "médio" do catálogo normalizado para "medio").
- Divinas de 2º círculo: todas feitas (Controlar Madeira: ObjectsModule fortalecer/retorcer/repelir/passagens; equipamento "madeira" em equipamento.json; "parede_madeira" nos lugares do mapa; forma de árvore = efeito "arvore" que bloqueia comandos).
- Divinas de 3º círculo (falta Controlar Água; Controlar Terra: 9 cubos (+2) em linha na direção dada; "amolecer" derruba o teto em cripta ou construção, senão terreno difícil; "parede" reaproveita a zona "muralha" com RD 8 contra tudo e 50 PV por trecho; "passagem" é a zona que torna paredes atravessáveis em passable; "solidificar" prende quem está em solo macio; fundir-se: flag "na_pedra" em combate (ação livre "sair_pedra"), efeito "mesclado" por um dia fora dele (WorldState bloqueia comandos, LeaveStone sai); objetos simples como armas não são criados; Viagem Arbórea: em combate, flag "na_arvore" (ninguém a alcança, `_pode_mirar`; só a ação "sair_arvore"), fora de combate vai até a árvore escolhida (o mapa todo está a menos de 1km) e, pela cena, comando TreeHop por 1 PM; com o aprimoramento o grupo acompanha o jogador; árvores do mapa não são destrutíveis; Missão Divina: fora de combate, em NPC; a tarefa é ir a um lugar (`missao_destino` entra em NpcModule.desired_location), cumprida ao chegar; quem tem reputação negativa com o jogador recusa e sofre –2 cumulativo por dia que falha na Vontade (`penalidade_missao`, na ficha via PartyModule.ficha_de); a marca soma –2 por crime do marcado (hoje só o jogador comete crimes); a supressão por um dia com magias de dissipar e a remoção por Purificação ainda não existem fora de combate; Servo Divino: tarefas que o jogo consegue cumprir, "lutar" em combate (invoca `criatura.espirito_servo`, valores do jogo) e "entregar" fora dele (usa a lista de mensageiros, recolhida com CollectMessenger no prazo de um dia ou uma semana); pagamento T$ 100/500/1.000; Comunhão com a Natureza: efeitos "auxilio_dados"/"auxilio_gasto", gastos automaticamente em Checks._auxilio_natural só quando o teste falharia e os dados podem salvá-lo; "area_natural" é marcada por `SpellsModule.ao_mover`, chamado a cada MovePlayer; o aprimoramento dá o fato NATURE_INFO com 1d4+1 temas da zona; Despertar Consciência: fora de combate; animal ou planta ao lado, escultura com "escultura" no mapa (Estátua de Lena, no templo) ou um parceiro seu que sobe um passo; permanente aplica efeito "pm_max" –3 na ficha): Heroísmo (imune a medo, 40 PV temporários, +4/+6 contra o maior ND na cena; `ataque_vs`/`dano_vs` por alvo), Proteção contra Magia (+5/+10 em resistências; imunidade a 1 ou 2 escolas, validada no planejador), Potência Divina (sustentada; Força +4/+1, RD 10/+5, tamanho sobe uma categoria e volta ao sair; sem lançar magias sob o efeito; toque com devoção), Dispersar as Trevas e Anular a Luz (dissipação com teste de Religião contra a CD de cada magia, `_dispersar_magias`; a CD usa quem lançou quando ainda está na cena, guardado em `efeitos[].conj`, zonas e marcas; cada uma se anula, sem teste). Ainda faltam: controlar_agua.
  Limites conhecidos: o tamanho é guardado na ficha, mas o jogo ainda não tem modificadores por tamanho, e o equipamento não muda com a Potência. A imunidade a escola é checada só nos alvos informados (não nas áreas). A Proteção aplica o bônus a todos os testes de resistência, como a Proteção Divina já faz.
- Divinas de 4º círculo: todas feitas. Feita: Conceder Milagre (em companheiro do grupo, em combate ou fora; efeito "milagre" na ficha dele, lançado pela IA no turno dele em `_milagre_do_companheiro`: cura ou magia sem resistência no aliado mais ferido, as outras no inimigo mais perto; penalidade "pm_max" –3/–6 no conjurador até lá). Feita: Cúpula de Repulsão (efeito "cupula" no portador com o grupo no tipo; `_cupula_corta` encurta o caminho de quem falha; `_cupula_barra` em `_resolve_attack`; Vontade uma vez por rodada por criatura; o portador que avança sobre elas rompe a magia; efeitos à distância que não são ataques de arma não são desviados). Feita: Terremoto (zona "terremoto" até o próximo turno do conjurador; terreno por quadrado: cripta ou construção desabam, barranco desmorona, água vira lamaçal, ar livre abre fendas com d6 ímpar; ações "soltar_terremoto" e "sair_da_fenda" ainda sem botão; estruturas do mapa não mudam). Feita: Controlar o Clima (fora de combate; `WeatherModule.forcado` fixa um dos 5 climas do jogo por 4d12 horas; o jogo não tem neve nem ventania, e a variante de druida (+1 PM, 3km, dias) não existe porque o druida ainda não é jogável).
- Divinas de 5º círculo: todas feitas. Feita: Intervenção Divina (opções `SpellRules.OPCOES_INTERVENCAO`; em combate curar/dissipar/duplicar/ressuscitar, fora curar/item/duplicar/proteger; duplicar usa `_cast` sem custo ou `SpellsModule._duplicando`; sacrifício = efeito "pm_max" –2 permanente; proteger = `cidade_protegida`, gasto pelo próximo Terremoto ou tempestade de Controlar o Clima na zona; "qualquer outra coisa que o mestre autorize" não tem como existir num jogo sem mestre). Feita: Reanimação Impura (só criatura com `morte_rodada` nesta cena; volta com PV cheios, valor adotado; troca de lado e age pela IA aliada; flag "reanimado_impuro" faz `_end_combat` devolvê-la morta; destruída, ganha "reanimacao_destruida"). Feita: Fúria do Panteão (zona "furia" de 90m: sem ataques à distância, concentração difícil, inimigos com visibilidade de Névoa; ordem `furia` de movimento com nevasca, raios, siroco ou trovões; ainda sem botão na tela). O catálogo de Fúria trazia o texto do Globo da Verdade de Gwen (divina 2), que agora tem entrada própria e está feito: fora de combate, cenas da crônica do jogador ou das memórias vistas do NPC tocado (Vontade anula), filtradas pela pergunta e pela janela de tempo; cadáver de NPC mostra a última cena; com 10 globos, os NPCs presentes ganham a lembrança.
- Universais de 1º círculo: todas feitas.
- Universais de 2º círculo: todas feitas. Feita: Runa de Proteção (`SpellsModule.runas`; dispara ao entrar na área, na exploração pelo gancho `ao_mover` e em combate em `_runa_no_combate`; comandos SearchRunes e DisarmRune; runa no corpo dispara `_runa_corporal` em `_resolve_attack` e no `_cast`, com a magia gravada como reação, sem as que exigem escolhas na hora, `SpellRules.RUNA_SEM`; criaturas do mundo só são feridas quando o jogador dispara a runa, pois elas não andam fora de combate). Feita: Marca da Obediência (ordens fixas `SpellRules.ORDENS_MARCA`: não ataque, siga, fique; a marca fica na ficha da criatura, por isso a versão de um dia passa de um combate a outro; o teste de hora em hora fora de combate não é simulado, pois a criatura não age fora do combate). Feita: Conjurar Mortos-Vivos (sustentada; criaturas `criatura.*_capanga` com a flag `capanga`, sem turno automático; ordens `mover_mortos` e `atacar_mortos`, ainda sem botão na tela; sombras usam a flag `incorporeo`, que hoje zera todo dano). Feita: Dissipar Magia (teste de Misticismo dissipa magias de CD até o resultado; área de 3m ou criatura; disjunção de 9m sem teste no 5º círculo; `_dissipar_magia`). O jogo ainda não tem itens mágicos permanentes, então a parte de "item mágico" do texto não tem alvo; os encantos de magia são efeitos e caem junto.
- Universais de 3º círculo: todas feitas. Feita: Servo Morto-Vivo (fora de combate; `SpellRules.SERVOS`; parceiro permanente com fonte "servo_morto_vivo"; o efeito `servo_sacrificio` faz `CombatSim.apply_damage` evitar um dano por rodada, automaticamente, e o servo sai do grupo no fim do combate; `CombatModule.marcar_reanimado`). Feita: Vidência (fora de combate; fato SCRYING e `SpellsModule.videncia_ver` pela cena; Vontade com +10/+0/–5 pela memória que o NPC tem do jogador; objetos de vínculo ainda não existem). Feita: Lendas e Histórias (fato LORE_REVEALED com `SpellRules.info_ficha`; em combate revela tudo de uma vez, por isso não é sustentada; fora de combate NPC, objeto ou lugar tocado, ou à distância por um dia e T$ 1.000). Feita: Manto de Sombras (efeito `manto_sombras`; CombatSim.incorporeo/na_sombra; só armas com encanto de magia ferem; atravessa obstáculos em passable; 1 de dano no início do turno fora da sombra; ação "salto_sombra" ainda sem botão; sombra = sem luz e escuro pelo ambiente, então de dia ao ar livre não há sombras). Feita: Selo de Mana (`_selo_impede` em `_execute_action`: magias, Ataque Especial, Golpe Divino e poderes com custo; reações fora da vez do selado não passam por lá). Feitas: Imobilizar (paralisado/lento; novo teste de Vontade no início do turno do alvo, que gasta a ação) e Pele de Pedra (RD 5/10; estátua = condição petrificado, 1d4 rodadas ou permanente).
- Universais de 4º círculo (1 de 4 falta): viagem_planar. Feita: Muralha de Ossos (zona "muralha" bloqueia passable; trechos de 3m com PV em `dados.pv`; ações "atacar_muralha" (só erra com 1 natural, contra Defesa 8), "soltar_muralha" e "escalar_muralha" (Atletismo CD 15, valor adotado), ainda sem botão; a muralha segue uma linha reta na direção escolhida; magias não danificam os trechos). Feita: Libertação (efeito `libertacao` em custo_meio e empurrar; imune a agarrado, enredado, imóvel, lento e paralisado; `anda_na_agua`; `escolher_20` em Checks.skill; `sem_treino` em can_use_skill). Limites: o jogo não tem Aprisionamento para dissipar, nem habilidades que exijam liberdade de movimentos com armadura. Feita: Visão da Verdade (efeito `visao_verdade` lido em falha_nevoa, falha_escuridao e camuflagem; +10 Percepção e Intuição). Limites: o jogo ainda não tem linha de visão por paredes (o aprimoramento grava `ve_paredes`, sem consumidor) nem disfarces ou formas alteradas para revelar.
  Feitas fora da ordem: Toque da Morte e Palavra Primordial (universais de 5º), Segunda Chance (divina de 5º; `morte_rodada` na simulação marca quem morreu para o aprimoramento de ressurreição; mortos-vivos sofrem a luz como dano). Libertação fica de fora: "efeitos de movimento" estão espalhados pelo código.
- Universais de 5º círculo (2 de 5 faltam): projetar_consciencia, roubar_a_alma. Feitas: Toque da Morte, Palavra Primordial e Buraco Negro (zona "buraco_negro"; CombatSim.puxar; ação "segurar" de movimento, +2 em resistências até o próximo turno, ainda sem botão; quem termina o turno no espaço é sugado: inimigo sai do combate, o jogador morre; objetos soltos não são simulados).
- Arcanas de 1º círculo do catálogo: feitas (Armadura Arcana, Toque Chocante, Seta Infalível).
- Já feitas nesta fase: Orientação, Bênção, Consagrar, Profanar, Despedaçar, Arma Espiritual, Armamento da Natureza, Caminhos da Natureza, Controlar Plantas, Santuário, Comando, Acalmar Animal, Tranquilidade, Detectar Ameaças, Suporte Ambiental, Abençoar Alimentos e Criar Elementos (1º divina), Arma Mágica e Névoa (1º universal).

Ordem sugerida: primeiro as que usam sistemas já prontos (área, marca, zona, invocação); depois as que pedem
servos com ação própria (generalizando o turno do Guardião); por último as que dependem de fora do combate
(viagem arbórea, viagem planar, projetar consciência, videncia, lendas e histórias).

## Magias de referência por sistema

- Área esférica: Anular a Luz (6m), Círculo da Restauração (3m), Tempestade Divina (cilindro).
- Cone: Sopro da Salvação (9m).
- Linha: Raio Solar (30m).
- Zona: Muralha de Ossos, Névoa, Controlar Água e Controlar Terra (terreno).
- Marca: Ligação Sombria, Rogar Maldição, Condição.
- Invocação: Servo Divino, Guardião Divino.
- PV temporários: Heroísmo (40 PV).

## Parceiros (LB p.261)

Todos os tipos de parceiro estão no jogo (`src/domain/rules/parceiros.gd`, dados em `parceiro.tipos` de core.json): ajudante,
combatente, fortão, guardião, montaria, perseguidor e, agora, adepto (–1 PM nas magias de 1º/2º círculo, `spell_cost` com a
ficha), assassino (Ataque Furtivo +1d6/+2d6 mesmo sem ser ladino; veterano: um inimigo por rodada conta como flanqueado),
atirador (+1d6/1d10/2d8 numa rolagem de dano à distância por rodada), destruidor (ação livre "parceiro_destruidor", 1/2/4 PM,
2d6/4d6/6d6 de energia; mestre em área de 6m), magivocador (+1/+2 dados no dano das magias que passam por `_dano_de_energia`;
+1/+2 na CD), médico (ação livre "parceiro_medico", 1/3/5 PM, cura 1d8+1/3d8+3/6d8+6 ou remove condição) e vigilante (+2 em
Percepção e Iniciativa; Esquiva Sobrenatural: não é surpreendido; Olhos nas Costas: não pode ser flanqueado).
Limites: as ações do destruidor e do médico ainda não têm botão na tela; o magivocador não soma em magias que rolam dano por
conta própria (como Toque da Morte).

