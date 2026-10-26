# XP dinâmica (ORIGINAL_DO_JOGO)

O padrão do jogo é a XP dinâmica. O modo do livro (LB p.326) pode ser ligado a qualquer momento no diário (J), com o botão "XP: dinâmica → livro". Código: `src/domain/modules/progression_module.gd`.

## Princípio
A **base é sempre a do livro**: ND × 1.000 por inimigo, **0 na fuga e 0 na captura** (decisão do usuário: fugir não é recompensado, e isso fecha o exploit de entrar e sair da visão) e 0 para ameaças com ND 5 ou mais abaixo do nível. Sobre essa base entram **multiplicadores de desempenho e circunstância**, e cada um aparece na mensagem do jogo. A XP nunca é inventada do nada nem escondida.

## Combate
`XP = Σ(base_por_inimigo × novidade) × clamp(1 + bônus, 0,5, 2,0)`

| Fator | Valor | Fonte do dado |
|---|---|---|
| Desvantagem numérica | +10% por inimigo além do primeiro (máx. +30%) | inimigos do combate |
| Desafio acima do nível | +15% por ponto de ND total acima do nível (máx. +45%) | ND do Bestiário |
| Circunstância adversa | +10% cada: visibilidade (escuridão/neblina), surpreendido | ambiente e iniciativa |
| Virou o jogo | +15% se caiu a 0 PV e ainda venceu | PV no combate |
| Táticas | +5% por tática distinta (máx. +20%): flanco, investida, Ataque Especial, magia, ataque furtivo, surpresa | modificadores reais aplicados |
| Quase ileso | +10% se o dano sofrido foi até ¼ dos PV | estatística do combate |
| Por um fio | +10% se terminou com até ¼ dos PV (exclusivo com "quase ileso") | idem |
| Vitória rápida | +10% se durou até (inimigos + 1) rodadas | rodadas |
| **Novidade** | ×(1 − 0,25 por vitória anterior sobre o mesmo tipo), mínimo ×0,4 | histórico de vitórias |

Exemplo (testado): 2 bandidos e Kael à noite, com flanco e Ataque Especial, quase sem dano, em 3 rodadas.
Base 1.000 × (1 + 0,2 + 0,1 + 0,1 + 0,1 + 0,1) = **1.600 XP**.

## Fora do combate
| Fonte | XP |
|---|---|
| Teste difícil bem-sucedido (CD ≥ 15), uma vez por alvo e abordagem | (CD − 10) × 20 |
| Passar despercebido por um grupo (Furtividade), uma vez por grupo | 25% da XP do grupo |
| Mistério resolvido pelo jogador | 1.000 × (1 + 15% por hipótese certa marcada − 10% por errada) |

## Por que assim
- **Jogo solo:** o ND do T20 pressupõe 4 heróis. Sem escalonar inimigos (proibido pelo Mestre, §2), os bônus por desvantagem e risco recompensam encarar ameaças acima do grupo esperado.
- **Contra "farm":** a novidade decrescente e a regra de irrelevância do livro impedem repetir lutas fáceis para subir de nível.
- **Recompensa o planejamento:** as táticas e a vitória rápida conversam com a projeção fantasma.
- **Recompensa evitar lutas:** furtividade e investigação também ensinam.

## Pontos a validar em playtest
O ritmo de subida (hoje, o vertical slice inteiro rende cerca de 1 a 2 níveis), os pesos de cada fator e o teto de ×2.
