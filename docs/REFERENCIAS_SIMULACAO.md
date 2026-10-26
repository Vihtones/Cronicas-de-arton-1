# Referências de simulação: o que aprendemos de WorldBox e Songs of Syx

Pesquisa feita em 26/10/2026, para orientar o desenho da Arton Viva (CDA-WORLD-001 v2.0). Fontes são
páginas de loja, wikis de fãs e discussões do Steam. Não há documentação técnica pública dos dois jogos, então
os números abaixo são **observações de terceiros** e podem estar desatualizados ou contraditórios (a wiki da
WorldBox, por exemplo, dá lealdade 1000 em um trecho e 10000 em outro). **Não copiar valores**: usar só como
padrão de desenho.

## Songs of Syx (cidadãos, trabalho, moradia, manutenção)

Fontes: [página Steam](https://store.steampowered.com/app/1162750/),
[relato de bug sobre trabalho e moradia (2023)](https://steamcommunity.com/app/1162750/discussions/1/3800525036428241032/).

- **Cada cidadão é simulado individualmente**, com necessidades próprias. Tudo que se constrói tem custo de
  manutenção, que reduz a produção. Estabilidade baixa escala depressa.
- **A atribuição de trabalho vem antes da moradia.** O desenvolvedor confirmou que o trabalho é atribuído
  primeiro, pelas prioridades, e a moradia depois. Isso gera conflito: trabalhadores moram longe do posto,
  outros ficam sem casa, e cidadãos desalojados em outro grupo tomam o emprego. O jogador reclamou do
  problema, e a correção proposta foi uma verificação periódica de desempregados sem casa.
- **Ociosos procuram casa perto do trabalho**, e os que trabalham podem deslocar os ociosos.
- **Nobres** podem usurpar o poder ou se aliar ao inimigo se não forem recompensados.

Lição para nós: a agenda (trabalho, lazer, visita) e a moradia precisam ser decididas juntas ou com regra clara
de prioridade. Hoje o morador tem casa fixa e a agenda vem da casa. Um morador que muda de casa (ou fica sem
casa) quebraria a agenda sem aviso, então isso precisa de um teste.

## WorldBox (vilas, lealdade, rebelião, guerras, persistência)

Fonte: [NamuWiki](https://en.namu.wiki/w/WorldBox%20-%20God%20Simulator), trecho lido (a página é longa e
parte está truncada). Outras fontes: [página Steam](https://store.steampowered.com/app/1206560/WorldBox__God_Simulator/).

- **Lealdade da vila soma fatores**: estar na capital, adjacência e conexão com a capital, mesma cultura,
  distância e diferença de população, e território conquistado recentemente (que se desfaz com o tempo).
- **Rebelião**: lealdade baixa + regra ativa = plano de rebelião. Ao chegar a 100%, a vila e vizinhos viram
  independentes. A maioria perde, mas rebeliões grandes podem vencer.
- **Teto de cidades**: o líder governa um número limitado de vilas; passar do teto baixa a lealdade de todas.
  Sucessor fraco aumenta a chance de rebelião.
- **Planos automáticos**: líderes acumulam influência; ao passar do limite, ela é gasta e um plano começa
  sozinho (guerra, paz, aliança). O jogador não inicia planos diretamente.
- **Persistência**: o histórico do mundo é zerado ao carregar. Nosso caso é o oposto: a spec exige que
  relações, economia e eventos sobrevivam a salvar e carregar, então não devemos copiar esse comportamento.

Lição para nós: a lealdade como soma de fatores explicáveis (capital, conexão, cultura, distância) é um bom
modelo para a reputação de cidades (Fase 5), porque cada fator pode aparecer para o jogador como causa. O
"teto de administração" é um padrão útil para a política de Fase 5 e 6. Os planos automáticos reforçam a regra
da spec de que o mundo age sem o jogador.

## O que não aproveitamos

- Os poderes de deus e desastres da WorldBox (outro estilo de jogo).
- A criação de cidades pelo jogo com comando direto (aqui a cidade surge do estado do mundo).
- Números de lealdade e de custo de manutenção: não há fonte confiável para eles.

## Próximos passos sugeridos

1. Modelar a **manutenção** de ferramentas: elas se desgastam com os anos e pedem troca. Isso combina com a
   regra de ferramenta por história já implementada.
2. Modelar a **lealdade de cidade** como soma de fatores explicáveis, para a Fase 5.
3. Testar a **agenda com moradia**: um morador sem casa, ou que muda de casa, deve manter uma agenda coerente.
4. Na Fase 2, usar a ideia de **consequência por grupo**: uma ação do jogador muda a reputação de uma facção,
   e isso muda comércio e fala, sem tocar no resto.
