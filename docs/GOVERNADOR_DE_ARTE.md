# Governador de Direção de Arte

Fonte da verdade: a pasta do usuário `C:/Users/Vitor/Documents/arte do jogo` (lida em 24/10/2026). O jogo não decide estética sozinho: **toda arte de produção passa pelo governador**. Sem aprovação registrada, ele recusa o asset e a cena usa o placeholder.

## Peças
| Peça | Papel |
|---|---|
| `tools/build_art_direction.py "<pasta>"` | Lê a pasta de arte, copia **só** os assets aprovados (conferindo o SHA-256 contra o manifesto da pasta) e gera o registro. Não escreve nada na pasta do usuário. |
| `data/art/direcao_de_arte.json` | Registro gerado: identidade *Beleza Marcada*, hierarquia de decisões, 4 pilares, curadoria CUR-001..025 (6 aprovadas, 17 parciais, 2 rejeitadas; CUR-026 não avaliada), 16 regras AD, fontes proibidas, decisões abertas, aprovações, papéis e políticas. Cada documento lido tem o hash registrado. |
| `src/presentation/art/art_governor.gd` | `ArtGovernor` em tempo de execução: `is_buildable`, `assets_for(papel, zona)`, `policy`, `credits_paths`, `report`. |
| `src/presentation/art/vegetation_layer.gd` | Primeiro consumidor: veste a floresta com a vegetação aprovada. |
| `tools/check_art_direction.py` | Checagem para a CI (AD-01 a AD-07). |
| Tela de título → **Créditos de arte** | Mostra o arquivo de créditos integral exigido pela CC-BY (AD-03). |

## O que está aprovado e em uso
Somente o **LPC Jungle, lote 02**: 20 componentes. A aprovação é artística ("Lpc jungle muito bom aprovadissimo", 23/10/2026), e a licença é CC-BY 4.0 com `CREDITS-jungle.txt` integral. Os arquivos são **os originais, sem recoloração nem redimensionamento**, em `assets/approved/vegetacao/lpc_jungle/`.

| Papel | Zonas | Assets |
|---|---|---|
| `floresta.arvore` | floresta, estrada que a cruza | 10 árvores |
| `floresta.sub_bosque` | idem | 7 plantas de até 112 px |
| `floresta.chao_decorativo` | idem | 4 plantas de até 80 px |

As 3 plantas mais altas (samambaia alta A e plantas de caule alto A/B) estão aprovadas, mas **ficam sem papel até a prova de escala**, para evitar "planta gigante".

## O que não entra no build (e por quê)
- **Vila:** continua com o placeholder. A vegetação de selva não substitui o vilarejo temperado (AD-07).
- **Cena-piloto v04:** é a referência de aceite, não um asset. Por ser concept art, não é recortada para o jogo.
- **02_referencias e 00_fontes:** são referências e histórico.
- **Acervo Tormenta20 (09):** ainda não tem aprovação própria. Há pendências (Trobo cortado, texturas 49–54). Não é promovido automaticamente.
- **Immunity:** a direção foi aprovada, mas o download nunca foi confirmado e não existe nenhum arquivo.

## Regras aplicadas automaticamente
- **AD-08:** filtro nearest e escala 1:1.
- **AD-09:** pivô na base e Y-sort com os atores. A colisão continua sendo a dos tiles `T`, e a imagem nunca muda o acesso.
- **AD-10:** copas e sub-bosque nunca cobrem trilhas ou estradas. A copa fica translúcida (25%) quando o jogador passa atrás dela, e fica a 35% durante o combate.
- **AD-11:** árvores ficam a mais de 2 tiles umas das outras (3 tiles para as grandes). O restante dos tiles bloqueados vira sub-bosque.

Os valores numéricos acima são **recomendação do assistente**, não decisão do usuário. Estão marcados assim em `politicas_runtime` e devem ser revistos na prova de escala.

## Separação de fatos (CLAUDE.md da pasta de arte)
- **Fatos recuperados:**
  - Aprovação do LPC Jungle lote 02.
  - CC-BY 4.0 e lista de autores.
  - Hashes conferidos.
  - Nenhum asset de produção aprovado tecnicamente.
- **Decisões do usuário:**
  - Beleza Marcada.
  - Quatro pilares.
  - Curadoria.
  - Piloto v04.
  - Blur sutil e seletivo.
  - Não misturar Hudra.
- **Recomendações do assistente:**
  - Uso também na estrada da floresta.
  - Alfa das copas.
  - Espaçamentos.
  - Limites de altura por papel.
- **Hipóteses técnicas:**
  - Escala do personagem (o placeholder tem cerca de 28 px; as árvores LPC pressupõem personagem de cerca de 48 px).
  - Paleta tropical precisando de harmonização com o bioma.

## Pendências (do lote 02, não executadas)
1. **Prova de escala** com personagem real: o personagem atual parece pequeno diante das árvores.
2. **Harmonizar os verdes** com o bioma temperado e reduzir os realces amarelos. Pede aprovação antes, porque altera o asset (vira v02, com novo hash).
3. Separar a sombra pintada se ela conflitar com a luz dinâmica.
4. Parallax e blur continuam **não implementados** (AD-12 e AD-13).

## Teste do acervo Tormenta20 no cenário (24/10/2026) — não é aprovação
`tools/art_test_runner.gd` lê os PNGs direto da pasta de arte, em tempo de execução, e não copia nada para o projeto nem para o manifesto. Foram testados:
- **7 pessoas e 4 criaturas** do bestiário v3, nas vistas 1/3/5/7. As escalas testadas foram 1/2, 1/3, 1/4 e 1/5, com filtro nearest e com filtro suave.
- **8 materiais**, repetidos a 1/2: calçamento, terra, madeira envelhecida, tijolo, musgo, lama, pedra e grama.

Observações (recomendações do assistente, a revisar):
- **Escala:** 1/4 (cerca de 55 px) combina com as árvores LPC, e 1/5 (cerca de 44 px) fica na faixa de 36–44 px da Bíblia. Nas duas, o personagem provisório (cerca de 28 px) fica pequeno demais. O nearest em 1/4 ficou legível, e o filtro suave borra. Reduzir não substitui a pixelização manual (ANALISE §4).
- **Materiais:** o calçamento e a terra encaixam. O tijolo está saturado, e a madeira, clara demais em 1/2. A lama mostra uma emenda visível na repetição.
- **Criaturas:** a Alma Acorrentada é vermelho intenso, adequado só como marca da Tormenta. A asa-assassina some entre as copas. Na floresta, o sub-bosque esconde parte dos materiais testados.
- **Direções:** as quatro vistas do Bandido Ligeiro mantêm a identidade. As oito vistas não são animação de caminhada.
