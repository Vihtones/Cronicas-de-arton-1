# Organização do projeto a partir do grafo (Graphify)

Grafo gerado em 24/10/2026 com o Graphify 0.9.95 (`tools/graphify_build.py`). Como o Graphify não lê
GDScript, os `.gd`, os comandos, os eventos, as regras e os documentos entram por uma extração
determinística própria (`tools/graphify_gdscript.py`); o AST do Graphify cobre as ferramentas em Python.
Nenhum conteúdo foi enviado a modelos de IA (`GRAPHIFY_BACKEND=none`). O mapa completo e atualizável
está em `docs/MAPA_DO_PROJETO.md`; aqui ficam as decisões.

## O que o grafo mostrou (fatos)
- **Núcleos:** `CombatModule` (o nó mais ligado do código), `Narrator` (traduz quase todo evento em texto),
  `UiRoot`, `ExplorationModule`, `NpcModule` e `WorldState`. As suítes `test_interactions` e
  `test_prototypes` são as que mais cobrem o domínio.
- **Arquitetura confirmada:** os módulos se comunicam por comandos e eventos; não há ciclo de importação.
  Cada comando tem exatamente um módulo que o trata.
- **Regras repetidas à mão (O1):** 35 regras conferidas no livro não são lidas pelo código; o valor está
  escrito de novo no script (ex.: `pericia.bonus_treino` em `CharacterSheet.training_bonus`,
  `distancia.dobro_alcance` e `distancia.em_corpo_a_corpo` em `CombatSim`, `mapa.diagonal` no custo de passo).
  Hoje os valores batem; o risco é divergirem numa correção futura.
- **Eventos mudos (O2):** 9 eventos são emitidos e registrados no diário interno, mas nenhuma parte do jogo
  reage. Três afetam o jogador e não aparecem na tela: `MYSTERY_LOST`, `FACTION_ALERTED`,
  `STOLEN_GOODS_RECOVERED`. Os outros seis são confirmações técnicas (`POLICY_SET`, `TURN_ENDED`…).
- **Cobertura (O3, O4):** `CastSpell`, `UseItem`, `MarkHypothesis` e `GrantDomain` não têm teste que os envie;
  `FaunaModule`, `ItemsModule`, `ObjectsModule`, `RegionSimModule` e `StateModule` não têm suíte própria
  (são exercitados só indiretamente).

## O que já foi reorganizado (feito)
- Índice de documentos no README, com o papel de cada um e qual é a fonte de verdade.
- `docs/PLANO_DE_EXECUCAO.md` marcado como histórico (o estado atual é o ROADMAP).
- ROADMAP atualizado para a 0.7.0, tabela de pendências consertada (cabeçalhos repetidos) e A4 corrigido
  (o blur seletivo já existe). Achados O1–O4 entraram como pendências.
- Capturas de tela movidas para `docs/capturas/`; `docs/.gdignore` impede a Godot de importar a pasta de
  documentação (antes gerava arquivos `.import` dentro de `docs/`).

## Recomendações (para decidir)
1. **O1 em lotes por família**, começando por `distancia`, `mapa` e `pericia` (as que mais pesam no combate):
   trocar o número escrito no código pela leitura da regra e manter um teste que compara os dois.
2. **O2:** narrar `MYSTERY_LOST`, `FACTION_ALERTED` e `STOLEN_GOODS_RECOVERED`; documentar os outros seis como
   eventos só de registro.
3. **O3/O4:** um teste por comando sem cobertura e uma suíte curta por módulo sem teste.
4. Rodar o grafo a cada versão (`python3 tools/graphify_build.py && python3 tools/graphify_mapa.py`) e revisar
   a seção "Achados automáticos" do mapa antes de fechar a versão.
