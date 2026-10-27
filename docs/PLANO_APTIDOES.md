# Plano: aptidões no estilo Nen (sem classe fixa)

Inspiração: o Nen de Hunter x Hunter. Cada pessoa tem uma afinidade natural, cada
habilidade tem um domínio, e quanto mais longe o domínio está da afinidade natural,
mais difícil e mais lento é aprender.

## Princípios
- Nada de classe obrigatória. O player constrói a própria carreira: padeiro, guerreiro,
  pescador, ou qualquer mistura. Skills e aptidões nascem da prática, não de uma lista fechada.
- Porcentagem é a unidade: cada aptidão tem um valor de 0 a 100%, e o progresso é em %.
- O mesmo sistema vale para NPCs. A diferença é só o que eles escolhem praticar.

## Modelo
- Domínios: fazer, lutar, criar, cuidar, conhecer, comunicar, sobreviver, etc. Cada um
  com subdomínios (ex.: fazer → cozinhar, forjar, pescar, construir).
- Afinidade natural: distribuição de % por domínio, herdada de origem/raça e modificada
  por atributos. Ex.: alguém com afinidade alta em "fazer" aprende ofícios mais fácil.
- Distância: a dificuldade de uma aptidão = distância entre seu domínio e a afinidade
  principal, em passos. Cada passo aumenta o custo de XP e reduz o ganho por prática.
- Progresso: cada uso bem-sucedido gera ganho em %, com retornos decrescentes perto de 100%.
  Treino com mestre, ferramentas e livros aumenta o ganho.
- Teto: 100% é o domínio. Acima de certo limite, a aptidão exige "sacrifício" ou
  marco narrativo (equivalente ao salto de "Nen de nível alto").

## Aprender por prática
- Cada ação real (cozinhar, lutar, pescar) gera pontos em uma aptidão associada.
- Quando uma aptidão passa de um limiar, ela vira skill nomeada e aparece na ficha.
- Skills podem ser combinadas: "padeiro + organização" gera uma aptidão de gestão de padaria.

## Integração
- Substitui gradualmente a progressão por classe na criação de personagem.
- Testes de perícia usam a % da aptidão em vez de bônus fixos (dados continuam d20).
- A árvore de poderes (LB) continua existindo como uma das fontes de aptidões de combate,
  para não quebrar o que já foi feito.

## Riscos
- Muito aberto pode diluir o jogo. Por isso cada domínio tem limites de dificuldade
  e a progressão precisa ter custo visível.
- Testes existentes (343) devem continuar passando; mudanças em progressão exigem novos testes.

## Status: fase 1 (modelo e prática) implementada

Código: `src/domain/rules/aptitudes.gd` (funções puras) e `CharacterSheet.afinidade` /
`CharacterSheet.aptidoes`, salvos com a ficha. Testes: `tests/unit/test_aptitudes.gd`.

Números decididos (ajustáveis em `aptitudes.gd`):
- Domínios: fazer, lutar, criar, cuidar, conhecer, comunicar, sobreviver.
- Grafo de vizinhança: fazer–criar, fazer–lutar, fazer–sobreviver, criar–conhecer,
  conhecer–comunicar, comunicar–cuidar, cuidar–sobreviver, sobreviver–lutar. Distância = passos.
- Ganho por uso bem-sucedido: 2 pontos × 0,75^distância × (0,5 + afinidade no domínio / 100)
  × (1 − progresso/100), com piso de 5% do ganho. Falha não gera progresso.
- Nome na ficha a partir de 25%. Teto de 80% sem marco narrativo; 100% com `marco`.
- Bônus de teste: +1 a cada 10%.
- Custo para aprender uma aptidão nova: 5 XP × (distância do domínio principal + 1).

Fase 2 (testes de perícia): cada perícia do Livro Básico tem um domínio
(`DOMINIO_DE_PERICIA`). Quando a ficha tem afinidade definida, o teste soma o bônus da
aptidão "dominio.pericia" e cada sucesso gera progresso nela. Fichas sem afinidade seguem
iguais. Testes em `tests/unit/test_aptitudes.gd`.

Ainda não feito (próximas fases):
- Definir a afinidade na criação (origem/raça) ou em NPCs. Hoje nenhuma ficha a recebe no
  jogo, então o efeito só aparece quando a afinidade é definida (decisão de design pendente).
- Mais de uma aptidão por perícia (subdomínios, como cozinhar e forjar).
- Interface para ver e escolher aptidões; NPCs com afinidade.
- Integração com a árvore de poderes do Livro Básico (fonte de aptidões de combate).

Fase 3 (subdomínios e balanceamento): cada perícia tem um subdomínio (`SUBDOMINIO_DE_PERICIA`,
chave "dominio.subdominio"). Perícia Ofício usa o ofício escolhido (`CharacterSheet.oficio`).
O bônus de aptidão é limitado a metade do nível + 2 (`Apt.teto_balanceado`), o mesmo que a
T20 dá a um treinado. Divergências do Tormenta 20 e limites em `docs/BALANCEAMENTO_APTIDOES.md`.

Pendente: calibrar o ganho por uso com jogo real, ligar o marco (100%) a um evento de jogo e
escolher a afinidade natural de cada origem.
