# Sistemas para magias complexas

Base para as magias de área, terreno, maldição e invocação. Cada sistema é independente e
testado em `tests/unit/test_magia_complexa.gd`. Medidas em quadrados de 1,5m (`Area.quadrados`).

## O que existe

| Sistema | Onde | O que faz |
|---|---|---|
| Geometria de área | `src/domain/combat/area.gd` | `esfera` (também cilindro e cubo), `cone` (90 graus), `linha`, `quadrados(metros)`. Funções puras. |
| Zonas | `CombatSim.zonas`, `add_zona`, `zona_em` | Área persistente no terreno (muralha, névoa, terreno difícil). Terreno difícil já dobra o custo do passo. Expira em N rodadas, ou nunca (`rodadas = -1`). |
| Marcas | `CombatSim.marcas`, `add_marca`, `tem_marca` | Efeito preso a uma criatura (maldição, vínculo, invocação). Expira em N rodadas. |
| Invocação | `CombatModule.invocar` | Cria uma criatura do bestiário (`criatura.*`) do lado do conjurador, logo depois dele na ordem. Com marca `invocacao`, sai da simulação ao expirar. |
| PV temporários | `CharacterSheet.pv_temp`, `CombatSim.apply_damage` | Absorvem dano antes dos PV. Zeram ao fim do combate. |
| Ids em área | `CombatSim.ids_em(tiles)` | Criaturas conscientes cujo quadrado está na área. |
| Remover criatura | `CombatSim.remove_combatant` | Tira uma criatura da ordem sem quebrar a vez atual. |

Tudo isso é salvo com o combate (zonas e marcas em `CombatModule.to_dict`).

## Como usar em uma magia nova

- **Área**: `var alvos := Area.esfera(centro, Area.quadrados(6.0))` e depois `sim.ids_em(alvos)`.
- **Terreno persistente**: `sim.add_zona("muralha_x", tiles, "terreno_dificil", 3, "magia.muralha_de_ossos")`.
  Para outro tipo de zona, use um tipo novo e trate-o onde ele tem efeito.
- **Maldição ou vínculo**: `sim.add_marca(id, alvo, "magia.ligacao_sombria", "maldicao", rodadas)`.
- **Invocação**: `c.invocar(conjurador, "criatura.hiena", rodadas, "servo_divino")`.
- **PV temporários**: `sheet.pv_temp += 40` (Heroísmo).

## O que ainda não existe

Estes sistemas guardam o estado, mas ainda não produzem efeito por si. Cada magia que precisar deles
deve implementar o efeito, e os próximos passos são:

1. **Efeito no início do turno e na entrada da zona**: nada ainda causa dano ou cura por zona ou por marca.
   Falta um gancho em `_begin_turn` (o Manto do Cruzado já tem um caso específico que serve de modelo).
2. **Movimento bloqueado por zona** (Cúpula de Repulsão, Muralha): hoje a zona só dobra o custo.
3. **Expiração com aviso**: `expiradas` guarda os ids, mas nenhum fato de jogo é emitido ainda.
4. **Invocações com habilidades próprias** (Guardião Divino, Montaria): a criatura usa o bestiário, sem
   ações especiais além dele. Servos com ações próprias precisam de ficha própria.
5. **Aprendizado de magias pelo clérigo**: ver `CHANGELOG.md` (0.7.1).

## Magias de referência por sistema

- Área esférica: Anular a Luz (6m), Círculo da Restauração (3m), Tempestade Divina (cilindro).
- Cone: Sopro da Salvação (9m).
- Linha: Raio Solar (30m).
- Zona: Muralha de Ossos, Névoa, Controlar Água e Controlar Terra (terreno).
- Marca: Ligação Sombria, Rogar Maldição, Condição.
- Invocação: Servo Divino, Guardião Divino.
- PV temporários: Heroísmo (40 PV).
