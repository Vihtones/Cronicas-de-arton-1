# Plano: mundo vivo, construção de NPCs e IA

Meta pedida pelo dono do projeto. Ordem sugerida; cada item vira uma etapa com commit e push.
O player não recebe o sistema de sobrevivência nesta fase: ele vale para NPCs.

## 1. Mapa e cidades (tarefa #54)
- Geração de mapa mais natural: relevo, rios, florestas e costas com ruído em camadas.
- Casas com formas variadas (planta, telhado, número de cômodos) geradas por tipo de bairro e cultura.
- Cidade com área construída que cresce ao longo do tempo: a área de expansão é escolhida pelos NPCs.
- Muros, portões e torres como construções próprias, erguidos conforme a cidade cresce.

## 2. Sobrevivência e construção para NPCs (tarefa #55)
- Recursos: madeira, pedra, ferro, comida, água, tecido, carvão. Cada um com origem (floresta, mina, fazenda, rio) e consumo.
- Construções com lista de materiais, mão de obra e tempo: casa, fornalha, ferraria, muralha, poço, armazém.
- Necessidades dos NPCs: comer, dormir, abrigo, aquecimento no frio. Falta de recurso muda o comportamento.
- Progressão civilizacional visível: população, edifícios, estradas e muros aumentam com o tempo de jogo.

## 3. Clima, luz e sombra (tarefa #56)
- Ciclo de dia e noite com posição do sol e duração coerente com a latitude.
- Estações e clima (chuva, neve, tempestade) afetando visibilidade, deslocamento, fogueiras e NPCs.
- Sombras que respeitam a fonte de luz (sol, tocha, lanterna, magia) e obstruções reais.

## 4. Movimentação e animações (tarefa #57)
- Movimento com aceleração, inércia, curvas e terreno (subida, lama, água).
- Biblioteca de animações já anotada: andar, correr, parar, cair, ataque por arma, esquiva, bloqueio, cura, magia, trabalho (martelar, cortar, colher, cozinhar), interações e emoções.
- Cada animação com nome, duração, quadros-chave e eventos (ex.: "impacto" no frame 4).

## 5. Combate e IA de NPC (tarefa #58)
- Combate mais dinâmico: posicionamento, flanco, cobertura, pressão de grupo, fuga e reagrupamento.
- Inteligência do NPC lida como raciocínio: quanto mais INT, mais planos, memória e antecipação.
- Aliados e inimigos cooperam: funções (líder, tanque, suporte), comunicação e ordens.
- Memória de eventos e reputação para que o NPC lembre quem o ajudou ou feriu.

## Regras de trabalho
- Commit e push a cada etapa, com os trailers de atribuição.
- PDFs enviados são somente leitura.
- Testes e verificações de estilo/arquitetura continuam obrigatórios em cada etapa.
