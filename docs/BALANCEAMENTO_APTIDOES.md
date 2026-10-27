# Balanceamento das aptidões em relação ao Tormenta 20

O sistema de aptidões (`docs/PLANO_APTIDOES.md`) é uma criação própria, inspirada no Nen.
Este documento lista tudo o que diverge do Tormenta 20 (Livro Básico) e os limites adotados
para que a divergência não quebre o equilíbrio do jogo. Código: `src/domain/rules/aptitudes.gd`
(`teto_balanceado`, `chave_de_pericia`) e `CharacterSheet.bonus_aptidao`.

## Divergências

| Tema | Tormenta 20 | Sistema próprio | Limite adotado |
|---|---|---|---|
| Treinamento | 4 graus (destreinado, treinado, veterano, expert), +2/+4/+6 | Porcentagem 0–100% por aptidão | +1 no teste a cada 10%, limitado pelo teto abaixo |
| Teto do bônus | Limitado pelo nível e pelo grau de treino | 100% daria +10 | `teto_balanceado`: o bônus da aptidão não passa de metade do nível + 2 (o treinado de T20 com metade do nível) |
| Progresso | Não existe; treino é por poder ou compra | Ganha % em cada teste de perícia bem-sucedido | Falha não gera progresso; ganho cai com a % (retornos decrescentes) e com a distância do domínio |
| Teto sem marco | Não existe | 80% sem marco narrativo | 100% exige `marco` (salto narrativo) |
| Afinidade | Não existe | Distribuição de % por domínio | Só fichas com afinidade definida usam aptidões; sem afinidade, o jogo é o da T20 |
| Custo de aprendizado | Poderes custam uma escolha de nível | 5 XP × (distância do domínio + 1) | Custo visível e crescente com a distância |
| Nome na ficha | Perícias sempre têm nome | Aptidão recebe nome a partir de 25% | Nome é só informativo, não dá bônus extra |
| Subdomínios | Não existem; a perícia é a unidade | Cada perícia cai em um subdomínio (ex.: `lutar.combate_corpo`) | Perícia Ofício usa o ofício escolhido (`CharacterSheet.oficio`); sem ofício, `fazer.geral` |

## Invariantes testados

- O bônus de aptidão nunca passa de `nível / 2 + 2` (`teto_balanceado`, teste `test_teto_balanceado_segue_o_treinamento_da_t20`).
- A 100% no 1º nível, a aptidão dá no máximo +2, igual a um treinado.
- Toda perícia do Livro Básico tem subdomínio válido no seu domínio (`test_todo_pericia_tem_subdominio_valido`).
- Ofício escolhido vira o subdomínio; ofício inválido cai em `fazer.geral` (`test_oficio_usa_o_subdominio_escolhido`).
- Ofício sobrevive ao salvar e carregar a ficha.
- Falha não gera progresso; fichas sem afinidade não mudam nos testes de perícia.

## Pendências de balanceamento

- Calibrar o ganho por uso com jogo real (hoje, 2 pontos base por sucesso, ajustáveis em `aptitudes.gd`).
- Ligar o marco narrativo (100%) a um evento de jogo; por enquanto é só um campo de dados.
- Decidir se o teto por nível também vale para perícias sem afinidade (hoje não: a T20 segue como está).
