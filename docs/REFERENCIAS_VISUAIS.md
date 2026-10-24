# Referências visuais e de sensação de jogo (pesquisa de 24/10/2026)

Este documento traduz referências em decisões para o motor. Ele não é arte aprovada: o governador de arte (`docs/GOVERNADOR_DE_ARTE.md`) continua decidindo quais assets entram. Os pilares vêm da Bíblia de Arte do usuário: Stoneshard (acabamento e legibilidade), Octopath Traveler II (luz), Sea of Stars (ciclos) e Children of Morta (profundidade, névoa, luz localizada). As animações seguem Dead Cells (CUR-011, aprovada: antecipação, impacto, recuperação e peso).

## O que aprendemos e onde aplicamos

| Fonte | Aprendizado | Aplicação no jogo |
|---|---|---|
| Graveyard Keeper: como os efeitos gráficos são feitos (Game Developer) | Ciclo de luz ambiente com gradiente e tom azul à noite. *Color grading* por LUT, trocado por hora do dia. Luzes pontuais para tochas e fornos. Sombras projetadas como sprites girados em direção a cada luz próxima, até 4 por objeto. Névoa em camadas horizontais. | `LightingDirector`: gradiente de 6 horários com tom de cor, luzes quentes com cintilação, sombras de contato e sombras direcionais a partir do sol e das luzes próximas, névoa em camadas |
| Dead Cells: entrevista com os desenvolvedores (80.lv) | O peso vem da **soma** de efeitos (partículas, *hit stop*, câmera lenta), não de um efeito isolado. O crítico congela 1 quadro e depois desacelera alguns décimos de segundo. | `ImpactDirector`: *hit stop* curto, câmera lenta no crítico, partículas por tipo de golpe, tremor proporcional ao dano |
| Mega Cat Studios: guia de "juice" | O inimigo pisca e treme ao ser atingido. O recuo é pequeno, mas sempre presente. O tremor de tela é maior no acerto que no erro. Um flash de luz acompanha explosões. | Reação do alvo: flash branco, recuo, tremor. Flash de luz em magias. Erro com efeito mais discreto que o acerto |
| Stoneshard, atualização #39 (nova interface) | Interface escura e "monumental", molduras sólidas, informação vital sempre à vista e fonte legível acima da fonte pixelada. | Tema da UI: painéis escuros com moldura de bronze gasto, títulos dourados, texto claro e legível, barras de PV e PM com moldura |
| Normal maps para pixel art (arXiv, Defold) | O volume com luz dinâmica exige *normal maps* pintados. | **Pendente.** Exige arte aprovada. Por enquanto, a luz atua por cor e cintilação, sem normal maps. O sistema fica pronto para recebê-los |

## Princípios adotados
1. **Legibilidade primeiro** (Bíblia de Arte e CUR-004): blur, névoa e sombras nunca escondem personagens, o chão andável ou os alvos. O desfoque só atinge as bordas e os planos decorativos, e tem opção de desligar.
2. **Efeito com motivo:** a intensidade cresce com a importância do momento (crítico > acerto > erro). A câmera cinematográfica só aparece em momentos marcantes, para não cansar.
3. **Acessibilidade:** "reduzir movimento" desliga o zoom cinematográfico e o tremor. "Reduzir flashes" desliga os flashes. O modo seguro desliga partículas, desfoque e luz dinâmica.
4. **Combate tático por turnos** (ressalva da CUR-011): a ação é rápida e o planejamento fica legível. A câmera lenta dura frações de segundo e pode ser pulada com um clique.

## Fontes
- [Graveyard Keeper: how the graphics effects are made](https://gamedeveloper.com/programming/graveyard-keeper-how-the-graphics-effects-are-made)
- [Interview with the developers of Dead Cells (80.lv)](https://80.lv/articles/interview-with-the-developers-of-dead-cells)
- [Exploring next-gen pixel art with real-time dynamic lighting (80.lv)](https://80.lv/articles/exploring-next-gen-pixel-art-with-real-time-dynamic-lighting)
- [Stoneshard Update #39: New Interface (GameBanshee)](https://www.gamebanshee.com/k4rp9)
- [Mega Cat Developer Juice Guide](https://megacatstudios.com/blogs/game-development/mega-cat-developer-juice-guide-v1-0-08-23-17)
- [Analysis of normal map generation techniques for pixel art (arXiv)](https://ar5iv.labs.arxiv.org/html/2212.09692)
