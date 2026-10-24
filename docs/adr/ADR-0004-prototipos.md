# ADR-0004: Laboratório de protótipos

**Status:** aceito (2026-10-23)

## Decisão
- Toda mecânica nova entra como **módulo** (`WorldModule`) com a versão mais simples que funciona de ponta a ponta. Ela precisa de:
  - um cenário em `Prototypes.LIST`;
  - um teste em `tests/unit/test_prototypes.gd`;
  - uma linha em `docs/PROTOTIPOS.md`.
- Os cenários **só configuram o estado inicial** (hora, posição, ficha, flags) do mesmo mundo do jogo. As regras continuam nos módulos.
- Mecânica nova que precisa de número ausente do livro usa constante nomeada, marcada como ORIGINAL ou PLACEHOLDER e listada em `docs/REGRAS.md`.
- Módulos de protótipo são **opcionais** (`WorldFactory.OPTIONAL`) e podem ser desligados sem impedir o boot.

## Consequências
- Cada mecânica pode ser experimentada e testada isoladamente antes de entrar no fluxo principal.
- `Prototypes` escreve no estado dos módulos diretamente (camada de aplicação, só na montagem). Essa é uma exceção documentada à regra "mudança só por comando".
