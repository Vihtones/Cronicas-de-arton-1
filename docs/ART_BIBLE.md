# Art Bible (provisória)

**Status:** hipótese de trabalho (§13, §20.2). Aprovar numa cena real antes de produzir em escala.

| Item | Valor atual |
|---|---|
| Perspectiva | top-down 3/4 |
| Tile | 32×32 px (1 quadrado = 1,5 m, LB p.236) |
| Personagem | canvas 32×32, pivô (16,28) nos pés, outline `#1a1418` |
| Resolução interna | 640×360, escala inteira, filtro nearest |
| Spritesheet | 3 colunas (parado, passo 1, passo 2) × 4 linhas (baixo, esquerda, direita, cima) |
| Paletas | grama, estrada, trilha, floresta, água, pedra, piso, cripta, plantação (`tools/gen_placeholder_art.py`) |
| Luz | CanvasModulate dia/noite (noite azulada, crepúsculo quente); PointLight2D só em tochas e janelas |
| Tormenta | **ainda sem asset.** Vermelho reservado para ela; o resto do jogo é colorido e não usa vermelho dominante |

## Pipeline
1. Pedido com função no jogo.
2. Conceito (GPT ou outro).
3. Aprovação de silhueta e paleta.
4. Sprite por direção e pose.
5. Limpeza manual.
6. `python3 tools/validate_assets.py`: dimensões, alpha, nome, pivô, hash, transparência quadro a quadro.
7. Atlas.
8. Importação na Godot.
9. Teste em cena (`tools/screenshot_runner.gd`).
10. Atualizar `assets/manifest.json`: versão, licença, estado.

Toda a arte atual é **original e provisória** (`estado: prototype`), gerada por script. Nenhuma ilustração oficial é usada.
