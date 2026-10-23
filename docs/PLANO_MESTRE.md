Documento Mestre de Direção, Arquitetura e Produção

Versão 1.2 | 23 de outubro de 2026 | Especificação proposta, ainda não
implementada

  FINALIDADE: fonte única de verdade para o Cláudio/Cloud planejar e
  executar o projeto por incrementos. Não interpretar este documento
  como declaração de que o jogo, o repositório ou os assets já existem.

1. RESUMO EXECUTIVO

Crônicas de Arton é um RPG single-player 2D top-down em pixel art
cinematográfica, ambientado no universo de Tormenta20, com exploração
ativa, combate tático híbrido, simulação social e histórica persistente,
mistérios causais e trajetórias pessoais singulares. A fantasia de
produto é habitar um mundo que não gira ao redor do protagonista. A
fantasia técnica é construir essa experiência em camadas verificáveis,
sem simular tudo a cada frame.

Decisão principal: implementar primeiro uma vila, uma estrada, uma
floresta, uma ruína, 20 a 30 NPCs e um encontro tático completo. A
expansão do mundo só será autorizada após o vertical slice passar nos
testes de jogabilidade, persistência e desempenho.

2. REGRAS DE PRODUTO E LIMITES

-   Tormenta20 é a referência mecânica e estética. Usar o Livro Básico
    como referência principal; Heróis de Arton somente para as
    categorias acordadas (classes novas, raças, poderes gerais e de
    classe, itens e equipamentos); Ameaças de Arton para criaturas
    quando disponível e autorizado. Registrar edição, fonte, página e
    status de verificação de cada regra. Não inventar estatísticas
    oficiais.

-   A campanha particular de Hudra não integra automaticamente o cenário
    do jogo.

-   O jogo deve funcionar em modo offline básico, sem IA generativa, com
    diálogos estruturados. IA opcional pode enriquecer conversas, nunca
    decidir resultados mecânicos.

-   O protagonista não recebe proteção narrativa, escalonamento
    automático de inimigos nem destino obrigatório.

-   Acontecimentos e mistérios têm causas persistentes. Ausência de
    eventos extraordinários é válida.

-   Qualquer mecânica além do livro deve ser classificada como ADAPTADA
    ou ORIGINAL_DO_JOGO, com opção de configuração quando apropriado.

-   Não incluir sistema de áudio no escopo herdado do Oráculo T20 sem
    nova autorização explícita; para este projeto, deixar áudio fora do
    plano inicial.

-   Direitos: verificar licença e permissões de uso da marca, textos,
    imagens e conteúdo de Tormenta20 antes de distribuição. Não copiar
    ilustrações oficiais como assets finais sem autorização.

3. CRITÉRIOS DE QUALIDADE E NÃO OBJETIVOS INICIAIS

Objetivos: mundo responsivo, consequências auditáveis, interface
legível, atmosfera visual forte, jogo recuperável após falha,
arquitetura substituível e operação em hardware modesto a ser medido.
Não objetivos do MVP: mapa integral de Arton, milhares de NPCs físicos
simultâneos, geração procedural irrestrita de lore canônico, dublagem,
multiplayer, política continental completa, simulador econômico
realista, sprites de todas as raças e classes.

Hipóteses a validar: (A) combate planejado é divertido; (B) investigação
ativa é compreensível sem marcadores excessivos; (C) NPCs dão sensação
de continuidade com simulação resumida; (D) pixel art e iluminação
mantêm FPS; (E) IA opcional melhora conversas sem causar
inconsistências.

4. PILHA TECNOLÓGICA E JUSTIFICATIVA

Cliente: Godot 4.x estável, GDScript tipado. Dados: Resources para
configuração fortemente integrada à Godot e JSON validado para catálogos
portáveis. Salvamentos: repositório de persistência com backend inicial
JSON atômico para protótipo; migrar para SQLite via extensão verificada
quando volume e consultas justificarem. Não prometer SQLite nativo sem
selecionar/testar extensão compatível com a versão da engine. IA:
interface opcional de provedor com limite de custo, timeout e fallback.
Git e CI com exportação headless e testes automatizados. Uma aplicação
monolítica modular é preferível a microsserviços nesta fase.

Questão: por que não simular todo o mundo detalhadamente? Porque o custo
cresce com agentes, caminhos, física e renderização; o jogador só
observa pequena parte. Solução: níveis de detalhe da simulação,
transições determinísticas e materialização sob demanda. Questão: por
que não gerar quests inteiras com LLM? Porque a IA pode contradizer
regras, estado e cânone. Solução: eventos e verdades estruturados; IA
apenas verbaliza ou sugere ações que passam por validação.

5. ARQUITETURA E DIREÇÃO DE DEPENDÊNCIAS

Camadas: Domínio (regras e estados puros), Aplicação (comandos e casos
de uso), Infraestrutura (salvamento, assets, adaptadores), Apresentação
(cenas, câmera, efeitos e UI). Domínio não importa Node,
AnimationPlayer, câmera, HTTP ou banco. Apresentação lê projeções do
estado, envia comandos e reage a eventos. Infraestrutura implementa
portas definidas pela aplicação/domínio. Evitar um singleton global que
concentre toda a lógica.

Módulos planejados: Core/EventBus, Rules, WorldClock, Weather,
WorldSimulation, NPC, Memory, Relationships, Factions, Reputation,
LawCrime, Economy, PoliticsDomains, Religion, Progression, Combat,
GhostPlanner, Exploration, Mysteries, Dialogue, Persistence,
Presentation, AssetRegistry, DebugTelemetry. Cada módulo publica
interface, eventos, versão de esquema, invariantes, dependências
permitidas, testes e estratégia de desativação.

Regras de modularidade: nunca acessar variáveis internas de outro
módulo; não gravar diretamente no save alheio; mudanças de estado
ocorrem por comandos validados; eventos informam fatos consumados, não
pedidos de ação; listeners idempotentes; consumidores desconhecidos não
impedem o emissor de operar. Para remover IA, DialogueProvider usa
implementação estruturada. Para remover clima, WeatherProvider retorna
condição neutra. Para remover política, eventos políticos não são
produzidos, sem afetar movimento ou combate. Desativar módulos
essenciais como Rules, Clock e Persistence requer implementação
substituta, não remoção cega.

6. CONTRATOS E FLUXO DE DADOS

Command: command_id, actor_id, type, payload, expected_world_revision.
Resultado: accepted, errors, emitted_events, new_revision. Event:
event_id, event_type, schema_version, world_tick, region_id,
source_command_id, actor_ids, payload. Eventos são imutáveis após
emissão; processadores usam event_id para deduplicação. WorldSnapshot
contém world_seed, world_tick, content_version, schema_version e estado
resumido por módulo.

Fluxo de resgate: jogador envia RescueNPC; Rules/World validam; um único
commit registra estado e evento NPC_RESCUED; Memory adiciona lembrança;
Reputation considera testemunhas e canais de notícia; Dialogue apresenta
reações; UI e câmera refletem o resultado. Reputação não pode aumentar
mundialmente se ninguém souber. Fatos, testemunhas, evidências e crenças
são entidades distintas.

Fluxo de combate: Planner recebe snapshot somente leitura; cria plano
fantasma; ActionValidator confere movimento, ações, recursos, condições
e alcance; confirmação cria comandos; DiceResolver usa RNG rastreável e
regras verificadas; estado é atualizado; EventLog registra resultados;
CinematicDirector anima os eventos. Nenhuma animação altera dano por
conta própria.

Fluxo de exploração: ambiente apresenta indícios visíveis; jogador
solicita InspectTarget; regras definem teste se pertinente; ClueGraph
revela evidência adequada; HypothesisJournal registra o conhecido;
interação física abre passagem somente se pré-condições forem
satisfeitas. Falha não vira loop infinito de testes sem mudança material
de abordagem.

7. TEMPO, DETERMINISMO E SIMULAÇÃO DO MUNDO

Relógio canônico usa ticks inteiros e calendário configurável. Não usar
relógio do sistema operacional para lógica do mundo. Render usa delta de
frame, mas simulação opera em passos fixos e eventos agendados. Salvar
seed e estado do RNG por fluxo (combate, clima, mundo) para reproduzir
bugs; RNG visual separado para não alterar resultados. Cada região
possui calendário de atividades, estado de economia, ameaças, facções e
eventos pendentes.

LOD de simulação: L0 entidades próximas com física/IA de movimento; L1
cidade atual com agenda e deslocamentos abstratos; L2 regiões próximas
com atualização por lotes; L3 regiões distantes com eventos agregados.
Promoção L2→L0 materializa apenas resultados plausíveis, não simula
retroativamente milhares de passos. Invariantes de conservação
simplificada: recursos não aparecem do nada salvo fontes explicitadas;
personagem morto não executa tarefas; NPC não está em duas regiões ao
mesmo tempo.

Eventos orgânicos exigem gatilhos causais (objetivo + recurso +
oportunidade + localização + risco), janelas temporais e consequências.
O jogador encontra eventos ao cruzar trajetórias, não por contador de
metros. WorldPacingDirector regula apresentação de conteúdo opcional,
jamais falsifica eventos ou atrasa resultados só para criar suspense.

8. NPCS, MEMÓRIA E RELAÇÕES

NPCState mínimo: id, nome, idade aproximada, origem, profissão, local,
rotina, necessidades, objetivos, inventário relevante, vínculos
familiares, afiliações, crenças, conhecimento e estado de saúde. Memória
estruturada: fato, envolvidos, local, tick, emoção, confiabilidade,
origem da informação, relevância e prazo de revisão. Usar memória
recente + fatos duráveis + resumos, sem armazenar diálogos infinitos.
Informação distante propaga por mensageiros, cartas, testemunhas,
viajantes ou outros canais, com latência e possibilidade de erro.

Progressão de NPCs aventureiros segue regras e atividades plausíveis,
sem ganhos arbitrários. Famílias podem crescer, morrer, herdar e mudar
de posição social. A biografia prévia é gerada como histórico resumido
consistente, não simulada dia a dia desde o nascimento. NPCs não são
oniscientes e podem mentir ou interpretar fatos incorretamente.

9. COMBATE HÍBRIDO E PROJEÇÃO FANTASMA

Iniciativa de T20, congelamento de planejamento no turno, fantasma sem
efeitos reais, fila de ações e visualização de alcance/custos. Ao
confirmar, resolver mecanicamente passo a passo, rolar dados no momento
de execução e mapear resultado para animação. Se uma ação depende de
outra que falhou, oferecer contingência autorizada, interromper para
decisão ou cancelar a parte inválida, sem criar ações gratuitas. Reações
e interrupções só se aplicam quando previstas nas regras.

Câmera cinematográfica responde a tags dos eventos: ataque, impacto,
esquiva, queda, morte, resgate, magia, falha. Zoom e tremor são
apresentação, com opções para reduzir movimento e flashes. Prioridade
técnica: primeiro combate funcional com sprites provisórios, depois
direção de câmera e animações.

10. EXPLORAÇÃO ATIVA, MISTÉRIOS E MASMORRAS

Exploração não rola Percepção automaticamente a cada área. Observação
natural apresenta sinais; ações do jogador solicitam exame, escuta,
rastreio, manipulação, conversa ou magia; perícia aplicável é escolhida
conforme regra e intenção. Intuição cobre interpretação social quando
pertinente, não substitui percepção sensorial. Investigação progressiva
não é barra de 100%; cada pista altera o que o jogador sabe e quais
hipóteses pode tentar.

MysteryDefinition: truth_id, historical_context, facts, clue_ids,
access_conditions, factions_interested, state_transitions, consequences.
Separar lore oficial confirmado de segredos originais e acontecimentos
emergentes. Descobertas podem ocorrer fora de ordem. Ruínas não escalam
automaticamente ao nível do jogador; perigos devem ter sinais
perceptíveis e rotas de fuga possíveis quando coerentes. O jogador pode
jamais descobrir o local. Não criar masmorras perto dele apenas por
falta de novidade.

11. FACÇÕES, CRIME, ECONOMIA, POLÍTICA E FÉ

Reputação multidimensional por pessoa, facção, cidade e jurisdição, com
informação incompleta. Crime registra ato real, evidência, testemunhas,
conhecimento das autoridades, leis locais, investigação, mandados,
recompensas e resolução. Ser ilegal não equivale a ser moralmente
condenado por todos. Facções possuem objetivos, recursos, alianças e
rivalidades. Economia inicial: produção/consumo agregado por região e
preços com limites, não simulação de cada moeda do mundo. Administração
de guilda ou domínio: decisões de alto nível, conselheiros e delegação,
não microgerenciamento obrigatório.

Religião segue panteão e obrigações oficiais de T20 quando verificados.
Não inventar intervenções divinas como mecânica canônica. Preconceitos
são propriedades individuais e institucionais contextualizadas, não
regras universais atribuídas a raças. Criaturas inteligentes podem
acumular recursos, organizar territórios e evoluir, mas sempre com custo
computacional limitado.

12. CLIMA, ESTAÇÕES E VISUAL

Direção: fantasia medieval colorida e monumental contrastando com horror
alienígena rubro da Tormenta. Biomas, cidades, florestas, templos,
ruínas, dragões, elementais e magia devem ter silhuetas claras e riqueza
controlada de detalhes. Pixel art com grade e escala consistentes,
iluminação 2D seletiva, paletas por bioma, reflexos estilizados,
partículas moderadas e câmera com zoom controlado. A Tormenta deve se
destacar pelo contraste, não tingir todo o jogo de vermelho.

WeatherRegion: temperatura aproximada, precipitação, nebulosidade,
vento, visibilidade, estado de superfície. Mudanças em passos espaçados;
transições visuais interpoladas. Clima modifica mundo e exploração
somente quando a mecânica foi definida e validada. Estações e calendário
afetam NPCs, rotas, cultivos e eventos. Reduzir efeitos visuais por
perfil sem desativar efeitos lógicos relevantes.

13. PIPELINE DE ASSETS GERADOS COM GPT

A Art Bible deve fixar: perspectiva top-down 3/4, proporção de
personagens, pixels por unidade, tamanho base de tiles, resolução
interna, paletas por bioma, limites de cores, outline, fontes de luz,
sombras, direção de animações, pivôs, nomenclatura, formato e regras de
transparência. Propor teste inicial com tiles de 32x32 e personagens em
canvas de 64x64; estes números são hipóteses, não especificação final, e
devem ser aprovados em uma cena real.

Pipeline: (1) pedido de asset com função no jogo; (2) referência e
concept art no GPT; (3) aprovação de silhueta/paleta; (4) sprite final
por direção/pose; (5) correção manual ou por ferramenta apropriada; (6)
validação automática de dimensões, alpha, nomes e pivôs; (7)
empacotamento de atlas; (8) importação Godot; (9) teste em jogo; (10)
registro de versão e licença. Imagens geradas não garantem spritesheets
consistentes: nunca assumir que animação está pronta sem checagem quadro
a quadro.

Manifesto de asset: asset_id, tipo, origem, licença, versão, estado
(concept/prototype/approved), tamanho, pivot, animações, dependências,
hash e caminho. Usar placeholders até os testes de mecânica passarem.
Não gerar centenas de variantes antes de estabilizar a escala visual.
Ferramentas úteis: geração de imagem GPT para conceitos e bases, editor
de pixel art para limpeza, script de validação PNG/atlas e editor Godot
para animações. Não é necessária uma skill adicional obrigatória no
início; avaliar ferramentas específicas apenas quando uma tarefa
concreta exigir.

Assets MVP: tiles de terreno/estrada/água, árvores/rochas, 3 prédios,
jogador 4 direções com idle/walk, 6 arquétipos de NPC reutilizáveis, 2
inimigos, portas/objetos interativos, 1 masmorra, ícones de ações, HUD,
partículas de chuva, efeitos simples de ataque/magia, retratos
essenciais. Não necessários inicialmente: dragões animados completos,
atlas de todo o continente, centenas de classes/raças, cinematics
pré-renderizadas, todos os deuses com menus exclusivos.

14. DADOS, PERSISTÊNCIA E MIGRAÇÕES

Separar definições estáticas (catálogos de conteúdo) de estado mutável
do mundo. Saves versionados com cabeçalho e checksum; escrita atômica em
arquivo temporário e substituição segura, backup anterior e recuperação
em caso de corrupção. Snapshot periódico + journal compacto de eventos
relevantes; não guardar cada movimento de frame. Compactar ou arquivar
eventos antigos após consolidar resumos, mantendo marcos necessários
para causalidade e depuração. IDs estáveis não dependem de nome visível.

Migrações incrementais: schema_version, função de migração N→N+1,
fixture de save antigo, teste de round-trip e rollback de backup. Nunca
renomear IDs ou campos sem migração. Desativar um módulo não pode apagar
silenciosamente dados de saves; usar armazenamento preservado até
migração explícita.

15. ORÇAMENTO DE PERFORMANCE E TELEMETRIA

Metas iniciais de engenharia, sujeitas a benchmark: 60 FPS em cena
típica no computador de referência, 30 FPS em perfil mínimo; simulação
não bloquear frame; carregamento regional progressivo; consumo de
memória monitorado; nenhuma chamada de IA no loop de frame. Registrar
p50/p95 de frame, tempo de pathfinding, agentes L0, tempo de save/load,
eventos por tick, memória e custo de contexto de IA. Escolher hardware
mínimo após medir o vertical slice, não por promessa de marketing.

Otimizações por ordem: perfilamento antes de otimizar; evitar alocação
por frame; atualização escalonada; caches com invalidação; pooling de
partículas; atlas; culling; navegação limitada; simulação agregada;
renderização de luzes com orçamento. Não usar multithreading sem
necessidade demonstrada, por risco de condições de corrida.

16. TESTES, AUDITORIA E PREVENÇÃO DE ERROS

Pirâmide: unitários de regras/estado; integração de eventos entre
módulos; cenas automatizadas Godot; testes manuais de UX; benchmarks e
testes de carga. Testes invariantes: fantasma não muda estado; ação
inválida não consome recursos; mesmo evento não aplica duas vezes; NPC
morto não aparece vivo sem regra; rumores não teleportam; mistério
mantém verdade; salvar/carregar preserva estado; atualização distante e
próxima produzem resultados compatíveis; módulo opcional desligado não
impede boot; RNG reproduz execução.

Antes de commit: formatar/lint, validar JSON e assets, executar testes,
iniciar cena headless quando possível, comparar performance com
baseline, atualizar CHANGELOG e ADR. Todo bug reproduzível recebe teste
de regressão. O Cloud deve relatar verificações não executadas, sem
afirmar sucesso. Revisões arquiteturais periódicas procuram acoplamento,
classes excessivas, duplicação de regras, consultas repetidas e esquemas
sem migração.

17. ROADMAP E GATES DE ENTREGA

Fase 0 Fundação: Godot abre, jogador move, câmera segue, EventBus,
Clock, logger, README e testes. Gate: executar sem erros e salvar estado
mínimo.

Fase 1 Vila: mapa pequeno, interações, relógio, iluminação, 5 NPCs com
rotinas. Gate: 15 minutos jogáveis, reinício preserva estado.

Fase 2 Exploração: 1 mistério, pistas, testes, diário, 1 masmorra. Gate:
múltiplas abordagens, sem revelação automática.

Fase 3 Combate: 1 encontro com iniciativa, ghost, validação, rolagens,
interrupções e log. Gate: ações inválidas não alteram estado; replay de
seed reproduz resultados.

Fase 4 Simulação social: 20–30 NPCs, 5 famílias, 3 facções, memória e
rumores. Gate: mundo muda após ausência e preserva causalidade.

Fase 5 Clima/arte: transições de dia/noite, chuva, pipeline de sprites
aprovado, perfis gráficos. Gate: benchmark e consistência visual.

Fase 6 IA opcional: provedor substituível, contexto mínimo, fallback,
limites e auditoria. Gate: desligar IA não impede jogo.

Fase 7 Expansão: crime, economia, fé, domínios, viagens, biomas e
conteúdos em módulos isolados. Gate por funcionalidade, não por volume.

18. REGISTRO DE RISCOS E RESPOSTAS

R1 Escopo infinito: limitar por vertical slice e critérios de corte. R2
Conteúdo oficial incorreto: proveniência por regra, revisão humana e
testes. R3 Dependências cíclicas: contratos e checagem estática de
imports. R4 IA contradiz mundo: ferramentas de leitura controladas e
comandos validados. R5 Save corrompido: escrita atômica, backup,
migração. R6 Sprites inconsistentes: Art Bible, validação de atlas e
aprovação em cena. R7 Simulação lenta: LOD, profiling e eventos
agregados. R8 Exploração frustrante: múltiplas pistas, feedback
sensorial, UX test. R9 Combate cinematográfico lento: animações
interrompíveis e opções de velocidade. R10 Licenciamento: avaliação
antes de publicação e uso de arte original licenciada.

19. PROTOCOLO DE EXECUÇÃO PARA CLÁUDIO/CLOUD

A cada tarefa: INSPECIONAR repositório e documentação → IDENTIFICAR
contrato e arquivos → PROPOR alteração mínima → IMPLEMENTAR → TESTAR →
PERFILAR quando relevante → REVISAR regressões → DOCUMENTAR → COMMIT.
Não modificar módulos fora do escopo sem necessidade comprovada. Nunca
apagar dados de usuário. Se faltar regra, arte, licença ou decisão, usar
placeholder claramente marcado e registrar questão aberta. Resposta
final de cada tarefa deve listar arquivos alterados, comandos
executados, testes aprovados/falhos, riscos, decisões e próxima tarefa
recomendada.

Primeiro comando para Cloud: 'Leia este Documento Mestre. Inspecione o
repositório. Não implemente o jogo completo. Produza diagnóstico do
estado atual e plano da Fase 0, com lista de arquivos, testes e
critérios de aceite. Se o repositório estiver vazio, crie apenas projeto
Godot mínimo com movimento, câmera, EventBus, WorldClock, logger, save
mínimo e documentação. Execute as verificações possíveis e reporte
limitações.'

20. DECISÕES EM ABERTO E CRITÉRIOS DE RESOLUÇÃO

(1) Versão exata da Godot e plataforma de distribuição: definir ao
iniciar o repositório. (2) Escala dos sprites e resolução interna:
prototipar 2 alternativas e comparar legibilidade. (3) SQLite:
selecionar extensão somente após teste de compatibilidade; JSON atômico
basta para Fase 0. (4) Fonte e licenciamento de conteúdo T20: revisão
antes de importar material protegido. (5) Formato de integração com
Oráculo T20: inspecionar projeto real e definir adaptador. (6) Modelo de
IA e custos: testar apenas após diálogos offline. (7) Tempo do
calendário e proporção dia real/dia do jogo: definir com playtest. (8)
Regras de progressão geracional e morte permanente: prototipar após
sistemas básicos. (9) Direção visual final: aprovar cena piloto antes de
produção em escala.

21. CHECKLIST DE DEFINIÇÃO DE PRONTO

[ ] Requisito e dependências documentados.

[ ] Contratos e dados versionados.

[ ] Implementação executável e demonstrável.

[ ] Testes unitários e integração relevantes aprovados.

[ ] Save/load e migrações verificados quando aplicável.

[ ] Módulos opcionais podem ser desligados sem falha.

[ ] Performance medida no cenário de referência.

[ ] Assets seguem Art Bible e têm licença/proveniência.

[ ] Nenhuma regra oficial não verificada apresentada como oficial.

[ ] Logs, CHANGELOG e decisões atualizados.

22. PRINCÍPIO FINAL

O projeto não será medido pela quantidade de sistemas prometidos, mas
pela quantidade de experiências consistentes que realmente funcionam
juntas. Uma vila viva, um mistério bem construído e um combate tático
correto valem mais do que um continente inteiro de módulos incompletos.
Expandir somente quando o núcleo for confiável.
