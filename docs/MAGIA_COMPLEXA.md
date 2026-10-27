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
- Divinas de 2º círculo feitas: Enxame de Pestes (zonas "enxame" de 1 quadrado; dano no fim do turno do conjurador), Miasma Mefítico (efeito cd_magias soma na CD), Controlar Fogo (CombatSim.chama_em: zonas de fogo, tochas, criaturas em chamas; bestiário "composicao" para criaturas de fogo), Augúrio (assunto = um lugar do mapa; miséria = criatura hostil ou armadilha, felicidade = baú ou pista), Círculo da Justiça (SpellsModule.justicas; NPCs no lugar não distorcem boatos), Condição (status_conhecidos), Físico Divino, Mente Divina (atributo muda de verdade e reverte), Oração,
  Purificação, Raio Solar, Soco de Arsenal (empurrão e alcance natural), Voz Divina (Mudar Atitude com não humanoides exige comunicação), Silêncio (alcance "médio" do catálogo normalizado para "medio").
- Divinas de 2º círculo restantes (4): aliado_animal,
  controlar_madeira, rogar_maldicao, tempestade_divina.
- Divinas de 3º círculo (12): anular_a_luz, comunhao_com_a_natureza, controlar_agua, controlar_terra,
  despertar_consciencia, dispersar_as_trevas, heroismo, missao_divina, potencia_divina, protecao_contra_magia,
  servo_divino, viagem_arborea.
- Divinas de 4º círculo (4): conceder_milagre, controlar_o_clima, cupula_de_repulsao, terremoto.
- Divinas de 5º círculo (4): furia_do_panteao, intervencao_divina, reanimacao_impura, segunda_chance.
- Universais de 1º círculo: todas feitas.
- Universais de 2º círculo (4): conjurar_mortos_vivos, dissipar_magia, marca_da_obediencia, runa_de_protecao.
- Universais de 3º círculo (7): imobilizar, lendas_e_historias, manto_de_sombras, pele_de_pedra, selo_de_mana,
  servo_morto_vivo, videncia.
- Universais de 4º círculo (4): libertacao, muralha_de_ossos, viagem_planar, visao_da_verdade.
- Universais de 5º círculo (5): buraco_negro, palavra_primordial, projetar_consciencia, roubar_a_alma, toque_da_morte.
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
