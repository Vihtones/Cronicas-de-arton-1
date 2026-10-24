# Crônicas de Arton

RPG single-player 2D top-down em pixel art, inspirado em Tormenta20. Projeto pessoal de fã, sem distribuição.
**Versão 0.3.0: vertical slice jogável + Laboratório (22 cenários) + XP dinâmica (`docs/XP_DINAMICA.md`).** É uma vila viva, uma estrada, uma floresta, uma ruína com cripta, 25 NPCs em 5 famílias, 3 facções, um mistério e combate tático completo.

Fontes de verdade: `docs/PLANO_MESTRE.md` (v1.2) · Plano e status: `docs/PLANO_DE_EXECUCAO.md` · Regras e páginas: `docs/REGRAS.md`
**Próximos passos, correções e revisões: `docs/ROADMAP.md`** · Mapa das mecânicas: `docs/PROTOTIPOS.md` · **Arte: `docs/GOVERNADOR_DE_ARTE.md`** (só assets aprovados na pasta de arte entram no jogo).

## Como jogar
1. Instale a **Godot 4.3 stable** (godotengine.org, versão padrão, não a .NET).
2. Abra a Godot → *Importar* → escolha `project.godot` desta pasta → *Importar e editar*.
3. Aperte **F5** (ou o botão ▶).

| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| E | interagir (conversar, examinar, rastrear, abrir, atacar…) |
| 1–9 | escolher opção (menu, diálogo) |
| J | diário: pistas, hipóteses, ficha, reputação |
| C | andar furtivo (metade da velocidade; teste de Furtividade ao se aproximar) |
| R | descansar 8h (recupera PV/PM conforme o local, LB p.106) |
| F5 / F9 | salvar / carregar · Esc: menu e opções · F3: depuração |
| **Combate** | clique: planejar mover/atacar · botão direito/⌫: desfazer · Enter: confirmar · Espaço: fim do turno · 2: investida · 3: misericórdia · 4: magia · 5: poção · 6: atirar · Q: Ataque Especial · L: levantar |

O tempo passa sozinho (2 s reais = 10 min de jogo). Os NPCs seguem suas rotinas, conversam entre si e espalham o que viram. Se você esperar demais, o bando parte no 12º dia e leva o rapaz.

## Laboratório de protótipos
Na tela de título, abra **Laboratório de protótipos…** para jogar um cenário curto por mecânica: mistério, combate, furtividade, magia, ataque furtivo, criação de personagem, progressão, equipamento, rumores, crime, investigação, economia, clima, viagem a Valkaria, domínio, gerações, sucessão do herói, fauna e 2º mistério, fé, IA de diálogo local, aventureiros NPC e ritmo.
**Criar personagem…** monta Humano ou Anão como Guerreiro, Ladino ou Arcanista pela compra de pontos do livro.

## O que está implementado
- **Regras T20 com proveniência:** 58 regras com fonte, página e status. 51 verificadas no livro, 6 pendentes de revisão humana e 1 adaptada.
- **Combate híbrido:** iniciativa T20, ações padrão/movimento/completa, projeção fantasma sem efeitos reais, investida, flanco, camuflagem, crítico, sangramento, morte e golpe de misericórdia. As rolagens usam um fluxo de RNG rastreável. Câmera cinematográfica com opções de acessibilidade.
- **Exploração ativa:** sem Percepção automática. Sinais naturais aparecem sem rolagem, e os testes acontecem só quando você age. Há regra anti-loop, e o diário de hipóteses é marcado por você.
- **Simulação social:** memória por NPC, testemunhas, rumores que só se espalham entre quem está no mesmo lugar, reputação por quem sabe, agendas por hora, mensageira entre regiões (LOD L3) e facções com reações causais.
- **Clima, crime, economia e fé:** clima por Markov, crime com testemunhas e mandado, preços por região, obrigações de Lena.
- **IA opcional:** desligada por padrão. Só reescreve o texto da fala e nunca decide resultados (`user://ai.json`).
- **Persistência:** saves atômicos com checksum, backup automático, migração v1→v2 e autosave a cada 6h de jogo.

## Testes e ferramentas
```bash
godot --headless --path . --import                          # 1ª vez
python3 tools/run_tests.py godot                            # testes (reprova erro de script, C23)
python3 tools/validate_assets.py                            # pipeline de assets (§13)
python3 tools/check_art_direction.py                        # governador de arte (AD-01..07)
python3 tools/check_architecture.py                         # dependências entre camadas (R3)
xvfb-run godot --path . -s res://tools/benchmark.gd         # desempenho por perfil gráfico
xvfb-run godot --path . -s res://tools/screenshot_runner.gd -- <pasta>   # capturas do slice
xvfb-run godot --path . -s res://tools/lab_runner.gd -- <pasta>          # capturas dos protótipos
```
Os geradores de conteúdo ficam em `tools/build_*.py`. Edite os geradores, não os JSON gerados.

## Arquitetura
| Pasta | Camada | Pode depender de |
|---|---|---|
| `src/core` | Contratos (Command, Event, EventBus, Logger) | nada |
| `src/domain` | Regras e estado puros: WorldState, 21 módulos, combate, regras, criação de personagem | core |
| `src/infrastructure` | Save JSON atômico, provedor de IA | core, domain |
| `src/application` | Composição (`Game`), fábrica do mundo, telemetria | todas acima |
| `src/presentation` | Mapa, atores, câmera, efeitos, combate visual, UI | application (lê projeções, envia comandos) |

Os módulos opcionais (clima, memória, facções, crime, economia, região distante, fé) podem ser desligados sem impedir o jogo. Um teste prova isso.
