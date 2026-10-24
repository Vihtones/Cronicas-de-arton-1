> **Documento histórico** (até a 0.2.0). O estado atual está em `docs/ROADMAP.md` e o mapa do código em `docs/MAPA_DO_PROJETO.md`.

# Crônicas de Arton: Plano de Execução e Status

Derivado do Documento Mestre v1.2. Em caso de conflito, o Mestre vence. **Atualizado em 23/10/2026, versão 0.2.0.**

> **Novidade da 0.2.0:** todas as mecânicas do Mestre têm um protótipo jogável no Laboratório (ver `docs/PROTOTIPOS.md`). **Próximos passos, correções e revisões** estão em `docs/ROADMAP.md`, que substitui as seções 5 e 6 abaixo.

Escopo autorizado pelo dono do projeto: uso pessoal, sem redistribuição. Por isso o risco R10 (licenciamento) fica **aceito para uso privado**, e a distribuição continua bloqueada.

---

## 1. Status por fase e gates

| Fase | Status | Gate do Mestre | Evidência |
|---|---|---|---|
| 0 Fundação | ✅ | executar sem erros e salvar estado mínimo | suíte headless; cena principal sobe sem `SCRIPT ERROR` |
| 1 Vila | ✅ | 15 min jogáveis, e reiniciar preserva o estado | `test_sessao_longa_estavel_e_salvavel` (450 ticks ≈ 15 min, hash idêntico após load) |
| 2 Exploração | ✅ | múltiplas abordagens, sem revelação automática | `test_andar_nao_revela_nada_automaticamente`, `test_cada_fato_central_tem_ao_menos_dois_caminhos`, rota investigativa ponta a ponta |
| 3 Combate | ✅ | ação inválida não altera o estado; replay de seed reproduz | `test_fantasma_nao_muda_estado`, `test_acao_invalida_nao_consome_recursos`, `test_mesma_seed_reproduz_combate` |
| 4 Social | ✅ | o mundo muda na ausência e preserva causalidade | `test_rumor_espalha_com_o_tempo_e_preserva_causalidade`, `test_bando_parte_no_prazo...`, `test_mensageiro_traz_noticias_com_latencia` |
| 5 Clima/arte | 🟡 | benchmark e consistência visual | benchmark feito (ver §4); arte **provisória** validada por script; **falta aprovar a direção visual numa cena piloto (decisão humana)** |
| 6 IA opcional | ✅ (desligada) | desligar a IA não impede o jogo | `test_llm_fallback_e_validacao`; provedor real só com `user://ai.json` |
| 7 Expansão | 🟡 protótipos | gate por funcionalidade | crime, investigação, economia, fé (3 deuses), região distante, viagem, domínio, gerações, aventureiros NPC, fauna e 2º mistério: todos com protótipo e teste; novos biomas **não iniciados** |

## 2. O que foi construído (mapa rápido)

- **Regras:** `data/rules/*.json` (58 regras). Relatório em `docs/REGRAS.md`, com o que está verificado, pendente, adaptado ou original.
- **Domínio:** `src/domain/` com `WorldState`, 13 módulos (`src/domain/modules/`), combate (`src/domain/combat/`) e regras (`src/domain/rules/`).
- **Conteúdo original:** `tools/build_content.py` gera mapa, NPCs, facções, mistério, itens, economia e leis; `tools/build_dialogue.py` gera os diálogos.
- **Apresentação:** `src/presentation/`. Tudo construído em código, com uma única cena, `scenes/main.tscn`.
- **Arte:** `tools/gen_placeholder_art.py` gera a arte, `assets/manifest.json` registra, `tools/validate_assets.py` valida.

## 3. Invariantes do §16 e onde são testados

| Invariante | Teste |
|---|---|
| Fantasma não muda estado | `test_combat::test_fantasma_nao_muda_estado` |
| Ação inválida não consome recursos | `test_combat::test_acao_invalida_nao_consome_recursos` |
| Mesmo evento não se aplica duas vezes | `test_event_bus::test_mesmo_evento_nao_aplica_duas_vezes` |
| NPC morto não aparece vivo | `test_social::test_npc_nunca_em_dois_lugares_e_morto_nao_age` |
| Rumores não teleportam | `test_social::test_rumor_nao_teleporta` |
| Mistério mantém a verdade | as hipóteses só usam fatos conhecidos (`test_hipoteses_so_usam_o_que_o_jogador_sabe`) |
| Salvar e carregar preserva o estado | `test_systems::test_salvar_carregar_preserva_mundo_inteiro_e_continua_igual` |
| Atualização distante e próxima são compatíveis | L3 só via mensageira (`test_mensageiro_traz_noticias_com_latencia`) |
| Módulo opcional desligado não impede o boot | `test_systems::test_modulos_opcionais_desligados_nao_impedem_boot` |
| RNG reproduz a execução | `test_rng`, `test_mesma_seed_reproduz_combate` |
| Reputação não sobe se ninguém sabe | `test_social::test_reputacao_nao_sobe_se_ninguem_sabe` |

## 4. Desempenho (§15)

Medido com `tools/benchmark.gd` no **renderizador por software** (llvmpipe, sem GPU; pior caso), na vila com chuva e 24 NPCs em L0:

| Perfil | frame p50 | frame p95 |
|---|---|---|
| baixo | 8,6 ms | 15,6 ms |
| médio | 10,9 ms | 16,7 ms |
| alto | 10,6 ms | 15,0 ms |

Comando p95 de 1,1 ms · save de 8 ms · load de 31 ms · 450 ticks de simulação em cerca de 0,1 s. **O hardware mínimo ainda não foi escolhido:** é preciso medir numa máquina real com GPU (§15).

## 5. Próximas tarefas recomendadas, em ordem

1. **Revisão humana das 6 regras pendentes** (`docs/REGRAS.md`): alcance curto/médio/longo, Defesa, Humano (página), funda, duração do descanso e Hiena. Em seguida, mudar o status para VERIFICADA.
2. **Playtest humano de 30 min** com anotações sobre a clareza das pistas, a dificuldade do combate (hoje cerca de 66% de vitória contra 3 bandidos) e o ritmo do relógio (§20.7).
3. **Aprovar a Art Bible numa cena piloto** e começar a arte final da vila. Depois, primeiros assets da Tormenta, com contraste e sem dominar o vermelho.
4. Criação de personagem (raça, classe, origem) usando o Heróis de Arton nas categorias acordadas.
5. Segundo mistério e segunda região, como módulo de conteúdo. Expandir só depois que o núcleo estiver confiável (§22).

## 6. Questões em aberto

| # | Questão | Estado |
|---|---|---|
| 1 | Versão Godot e plataforma | Godot 4.3, desktop |
| 2 | Escala de sprites e resolução | 32 px / 640×360 provisórios; falta comparar com 480×270 |
| 3 | SQLite | adiado; JSON atômico atende (save de 8 ms) |
| 4 | Licença T20 | uso pessoal autorizado; distribuição bloqueada |
| 5 | Oráculo T20 | não recebido |
| 6 | Modelo e custo de IA | provedor pronto, desligado; configurar `user://ai.json` se quiser |
| 7 | Tempo real × tempo de jogo | 2 s = 10 min (placeholder) |
| 8 | Gerações e morte permanente | morte permanente ativa; o envelhecimento existe; nascimentos e herança ainda não |
| 9 | Direção visual final | pendente de aprovação humana |
| 10 | Calendário oficial de Arton | não encontrado no Livro Básico; placeholder de 30×12 |
