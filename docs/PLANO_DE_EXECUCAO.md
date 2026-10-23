# Crônicas de Arton — Plano de Execução

Derivado do Documento Mestre v1.2 (23/10/2026). Este plano organiza **o que fazer, em que ordem, e como saber que terminou**. Não substitui o Documento Mestre: em conflito, o Mestre vence.

---

## 0. Diagnóstico (23/10/2026)

| Item | Estado |
|---|---|
| Repositório | Não existia. Criado `cronicas-de-arton/` com a Fase 0. |
| Engine | Godot 4.3 escolhida (ADR-0001). **Não foi possível executar a Godot no ambiente de criação** — testes escritos, não rodados. |
| Fontes de regras | Recebidas: Livro Básico T20, Heróis de Arton v1.1, Bestiário. Ameaças de Arton: não recebido (usar Bestiário como substituto provisório, marcado). |
| Arte | Nenhuma. Placeholders (retângulos coloridos) marcados com `metadata/placeholder`. |
| Licença T20 | **Não verificada.** Bloqueia qualquer distribuição pública (R10). |

---

## 1. Visão em uma frase

Uma vila viva, um mistério bem construído e um combate tático correto — funcionando juntos, salváveis e reproduzíveis — antes de qualquer expansão.

## 2. Estrutura de trabalho

**Ritmo:** cada fase é dividida em tarefas pequenas (≤ 1 dia de trabalho de agente), cada uma seguindo o protocolo §19: inspecionar → contrato → mudança mínima → implementar → testar → perfilar → revisar → documentar → commit.

**Regra de ouro:** nenhuma fase começa antes do gate da anterior estar verde. Gate falho = corrigir, não pular.

**Definição de pronto:** checklist §21 em toda tarefa.

---

## 3. Mapa de módulos por fase

| Módulo | Fase de entrada | Desligável? | Substituto quando desligado |
|---|---|---|---|
| Core/EventBus, Logger | 0 | Não | — |
| WorldClock | 0 | Não (essencial) | — |
| Persistence | 0 | Não (essencial) | — |
| Rules (provenance) | 1 | Não | — |
| Presentation/Camera | 0 | — | — |
| NPC (rotinas) | 1 | Sim | NPCs estáticos |
| Exploration, Mysteries, Dialogue (estruturado) | 2 | Mysteries sim | Sem mistérios ativos |
| Combat, GhostPlanner, DiceResolver | 3 | Não após F3 | — |
| Memory, Relationships, Factions, Reputation | 4 | Sim | Reputação neutra |
| WorldSimulation (LOD L0–L3) | 4 | Não após F4 | — |
| Weather | 5 | Sim | Condição neutra |
| AssetRegistry | 5 | Não | — |
| DialogueProvider (IA) | 6 | Sim | Diálogo estruturado |
| LawCrime, Economy, Religion, PoliticsDomains | 7 | Sim | Não emitem eventos |
| DebugTelemetry | 0→contínuo | Sim | Sem métricas |

---

## 4. Fases

### FASE 0 — Fundação ✅ código escrito · ⏳ verificação pendente
**Objetivo:** esqueleto executável com contratos corretos.

Entregue:
- `project.godot` (640×360, nearest, GL Compatibility, input WASD/F5/F9)
- `src/core/` GameCommand, GameEvent, EventBus (dedup), GameLogger
- `src/domain/` WorldClock, RngStreams, WorldState
- `src/infrastructure/` JsonSaveRepository (atômico + checksum + backup + migração)
- `src/application/game.gd` (autoload de composição)
- `src/presentation/` player, hud; `scenes/main.tscn`
- `tests/` executor headless + 18 testes de invariantes
- README, CHANGELOG, ADR-0001

**Gate F0:** projeto abre sem erros · jogador move e câmera segue · 18/18 testes verdes · F5→fechar→abrir→F9 restaura posição e hora.

**Tarefas restantes da F0:**
1. Rodar `godot --headless --import` e o executor de testes; corrigir o que falhar.
2. Teste manual de save/load.
3. Configurar Git + CI (GitHub Actions com imagem Godot headless rodando os testes e um export Linux).
4. Script `tools/check_imports.py`: falha se `src/domain` referenciar Node/Camera/HTTP (R3).

---

### FASE 1 — Vila
**Objetivo:** 15 minutos jogáveis num lugar que parece vivo.

| # | Tarefa | Arquivos principais | Teste/aceite |
|---|---|---|---|
| 1.1 | Registro de regras com proveniência | `data/rules/*.json`, `src/domain/rules/rule_registry.gd` | Cada regra tem `fonte`, `página`, `edição`, `status: VERIFICADA/ADAPTADA/ORIGINAL_DO_JOGO`; validador rejeita regra sem fonte |
| 1.2 | Verificar calendário de Arton no Livro Básico | `data/catalogs/calendar.json` | Substitui placeholder 30×12; ADR atualizado |
| 1.3 | Tilemap da vila (placeholder 32×32) | `scenes/regions/vila_inicial.tscn` | Colisão, 3 prédios, estrada, área para floresta |
| 1.4 | Interação genérica (`InspectTarget`, `UseObject`) | `src/application/interaction.gd` | Porta abre/fecha via comando; estado persiste |
| 1.5 | Iluminação 2D por hora | `src/presentation/lighting/` | Luz segue `day_fraction`; perfil “baixo” desliga sombras |
| 1.6 | NPCState mínimo + agenda | `src/domain/npc/` | 5 NPCs com rotina (casa→trabalho→taverna); NPC não está em dois lugares |
| 1.7 | Materialização L1→L0 | `src/application/npc_presence.gd` | Entrar num prédio mostra quem a agenda diz estar lá |
| 1.8 | Diálogo estruturado offline | `data/dialogue/*.json`, `src/domain/dialogue/` | Árvore com condições de estado; sem IA |

**Gate F1:** 15 min jogáveis · reinício preserva portas, hora, posição de NPCs · ≥ 60 FPS no PC de referência.

---

### FASE 2 — Exploração e mistério
| # | Tarefa | Aceite |
|---|---|---|
| 2.1 | Ações ativas: examinar, escutar, rastrear, manipular | Nenhuma rolagem automática de Percepção ao entrar em área |
| 2.2 | Testes de perícia T20 (d20 + bônus vs CD), fonte registrada | Usa fluxo RNG `world`; regra com página do Livro Básico |
| 2.3 | `MysteryDefinition` + `ClueGraph` | Verdade fixa; pistas acessíveis por ≥ 2 caminhos |
| 2.4 | `HypothesisJournal` (diário) | Registra só o que o jogador sabe; não é barra de % |
| 2.5 | Anti-loop de falha | Repetir mesmo teste sem mudar abordagem não é permitido |
| 2.6 | 1 floresta + 1 ruína pequena | Perigos com sinais perceptíveis e rota de fuga |
| 2.7 | 1 mistério completo original (marcado ORIGINAL_DO_JOGO) | Resolvível fora de ordem; possível nunca descobrir |

**Gate F2:** três testadores resolvem por caminhos diferentes; nenhum recebe a solução sem ação.

---

### FASE 3 — Combate tático híbrido
| # | Tarefa | Aceite |
|---|---|---|
| 3.1 | Ficha mínima T20 (atributos, PV, PM, Defesa, perícias) a partir do Livro Básico | Valores com fonte; nenhum inventado |
| 3.2 | Grade de combate + iniciativa T20 | Ordem reproduzível com mesma seed |
| 3.3 | `GhostPlanner` sobre snapshot somente-leitura | **Teste: fantasma não muda estado** |
| 3.4 | `ActionValidator` (ação padrão/movimento/completa/livre, alcance, recursos) | **Ação inválida não consome recurso** |
| 3.5 | `DiceResolver` no fluxo `combat` + EventLog | **Replay de seed = mesmos resultados** |
| 3.6 | Contingências quando ação dependente falha | Nunca gera ação gratuita |
| 3.7 | 2 inimigos do Bestiário (estatísticas com página) | Status VERIFICADA após revisão humana |
| 3.8 | `CinematicDirector` com tags de evento + opções de acessibilidade | Animação nunca altera dano; opção de velocidade/reduzir tremor |

**Gate F3:** encontro completo jogável; testes de invariante verdes; replay idêntico.

---

### FASE 4 — Simulação social
20–30 NPCs, 5 famílias, 3 facções; Memory (recente + duráveis + resumos), Relationships, Reputation por testemunha; rumores com latência e erro; LOD L2/L3 por lotes; biografia gerada como histórico resumido.
**Gate F4:** ficar fora 7 dias de jogo → mundo mudou e cada mudança tem causa rastreável no journal; rumores não teletransportam.

### FASE 5 — Clima e arte
Art Bible (protótipo 32×32 vs alternativa; aprovação em cena real); pipeline de 10 passos do §13 com `tools/validate_assets.py` (dimensões, alpha, nomes, pivôs, hash) e manifesto; WeatherRegion com chuva; perfis gráficos.
**Gate F5:** benchmark p50/p95 registrado; cena piloto aprovada visualmente.

### FASE 6 — IA opcional
`DialogueProvider` com implementação estruturada (padrão) e LLM (opcional) com timeout, limite de custo, contexto mínimo e auditoria; IA só verbaliza ou sugere comandos validados.
**Gate F6:** desligar IA não impede nada; IA nunca altera resultado mecânico.

### FASE 7 — Expansão
Crime, economia agregada, fé (panteão verificado), domínios, viagens, novos biomas — cada um como módulo isolado com gate próprio.

---

## 5. Conteúdo oficial T20 — processo

1. **Extrair** regra do PDF com página → `data/rules/<area>.json`.
2. **Marcar** `status: PENDENTE_REVISAO`.
3. **Revisão humana** compara com o livro → `VERIFICADA`.
4. Qualquer desvio → `ADAPTADA` (com justificativa) ou `ORIGINAL_DO_JOGO`.
5. Heróis de Arton: apenas classes novas, raças, poderes, itens.
6. Texto oficial não é copiado para a UI final sem verificação de licença.

## 6. Questões em aberto (atualizado)

| # | Questão | Quando resolver | Estado |
|---|---|---|---|
| 1 | Versão Godot / plataforma | F0 | Godot 4.3; plataforma: PC (Windows/Linux) proposta |
| 2 | Escala de sprites / resolução | F5 (protótipo já na F1) | 640×360 provisório |
| 3 | SQLite | quando saves > ~5 MB ou consultas complexas | JSON basta |
| 4 | Licença T20 | antes de qualquer distribuição | **aberta — alto risco** |
| 5 | Integração Oráculo T20 | ao receber o projeto | aguardando acesso |
| 6 | Modelo/custo de IA | F6 | — |
| 7 | Proporção tempo real/jogo | playtest F1 | 1 s = 10 min (placeholder) |
| 8 | Morte permanente / gerações | após F4 | — |
| 9 | Direção visual final | gate F5 | — |
| 10 | Ameaças de Arton disponível? | F3 | usar Bestiário provisoriamente |

## 7. Próxima tarefa recomendada

**F0.1 — rodar os testes na Godot 4.3 e corrigir falhas.** Depois F0.3 (Git + CI) e então F1.1 (registro de regras com proveniência), que destrava todo o resto que usa regras oficiais.
