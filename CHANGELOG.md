# Changelog

## 0.7.1 (em andamento)
- Magias divinas e universais do 1º círculo cadastradas com texto, execução, alcance, alvo, duração, resistência e aprimoramentos (29 novas, `data/rules/personagem.json`, extraídas do Livro Básico). Só ficam disponíveis no jogo as que estiverem completas em `SpellRules.COMPLETAS` (hoje: Perdição, com o aprimoramento de –1 extra). Perdição aceita vários inimigos marcados antes de confirmar (clique marca, Enter confirma) e o aprimoramento liga com a tecla B. Infligir Ferimentos e Resistência a Energia completas (todos os aprimoramentos, inclusive vários alvos, alcance curto, tipo de energia com tecla T, duração por um dia e imunidade). Tecla G escolhe o aprimoramento em foco e B liga/desliga. Efeitos de um dia acabam na virada do dia e condições de magia (fraco) acabam com a cena. O clérigo começa com Curar Ferimentos, Perdição e Infligir Ferimentos, as três completas. Efeitos temporários da ficha (`efeitos`: ataque, dano, defesa, resistência, redução de dano, imunidade) são gravados com o save e expiram por rodada, turno, cena ou próximo teste de resistência. Testes em `tests/unit/test_classes.gd`.
- Clérigo jogável (segunda leva): conjura com Sabedoria e começa com Curar Ferimentos, a única magia divina implementada. As demais magias do clérigo (3 iniciais no catálogo) continuam pendentes. Bardo, druida e treinador seguem fora da criação.
- Classes jogáveis (primeira leva): bárbaro, paladino, nobre, bucaneiro, cavaleiro, caçador e inventor entram na criação, com presets de atributos e perícias padrão. Bardo, druida, lutador e treinador ficam para depois (dependem de magia e mascotes). Kits de equipamento são provisórios. A Fúria do bárbaro (+2/+3/+4/+5 em ataque e dano corpo a corpo, nos níveis 1/6/11/16) é aplicada em combate como efeito permanente, sem o custo de ativar. Demais habilidades de classe continuam como texto no catálogo. Testes em `tests/unit/test_classes.gd`.
- Catálogo do Livro Básico (cadastro): as 14 classes (guerreiro, ladino, arcanista, bárbaro, bardo, bucaneiro, cavaleiro, caçador, clérigo, druida, inventor, lutador, nobre, paladino) com características e poderes de classe, página do livro e status; 35 origens com itens, perícias e poderes em `data/rules/personagem.json`. Jogáveis no jogo: guerreiro, ladino, arcanista e a primeira leva de classes (ver entrada acima). Testes em `tests/unit/test_poderes_livro.gd`.
- Catálogo de poderes do Livro Básico: 41 poderes de classe novos (guerreiro, ladino e arcanista) cadastrados com página do livro (`data/rules/personagem.json`). Os sem efeito no jogo ficam na árvore como "não implementado" (`CLASS_TREE_ONLY`) e fora das opções de subida. Pré-requisitos de nível e de caminho passam a ser checados e explicados na árvore (`prereq_texto`, `falta_texto`). Testes em `tests/unit/test_poderes_livro.gd`.
- Arton Viva, Fase 0 (auditoria em `docs/ARTON_VIVA.md`) e Fase 1 parcial: necessidades dos moradores (fome, cansaço, ouro) com objetivo urgente, comer na taverna e descansar em casa (`NpcNeedsModule`).
- Fuga e captura não rendem mais XP; evasão furtiva rende uma vez por criatura (fecha o exploit de entrar/sair da visão).
- Combate: fantasma do jogador (`GhostActor`) ensaia o plano em laço — anda o caminho, recua e investe, dispara ou conjura — antes de confirmar. Verificação: `tools/ghost_check.gd`.
- Diálogos: voz dos moradores (`DialogueVoice`, `data/dialogue/voices.json`, gerado por `tools/build_voices.py`) — saudação por registro, hora, clima, evento da vila, reputação e mistério; memória da conversa (primeira vez, mesmo dia, retorno, assunto repetido); novo submenu de papo com opinião sobre cada morador. Saves antigos carregam.
- Falas de ambiente: `AmbientTalk` + `data/dialogue/ambient.json`. Balões em conversas reais (turnos entre dois figurantes), pregões por mercadoria, falas por clima/hora/evento/mistério; moradores reconhecem o jogador que passa. Balão do tamanho do texto. Verificação: `tools/falas_check.gd`.
- Moradores: `NpcLifeModule` — humor (medo e alegria) e atividade (trabalho, descanso, festa, feira, ferido, preso). Violência na vila assusta família e vizinhos, que se recolhem até acalmar; guardas não saem do posto. Humor é salvo com o jogo; saves antigos carregam. O rótulo do morador mais próximo mostra a atividade.
- Trabalho produz mercadoria (Arton Viva, Fase 1): um turno cumprido (6 horas no posto, 8h às 18h) gera `WORK_DONE` com o bem da profissão (`producao_trabalho` em `economy.json`: lavrador, moleiro e cozinheiro produzem comida; taverneira, bebida; ferreiro, ferramentas; clériga de Lena, remédio). A economia soma uma unidade ao estoque da vila. Turno curto e profissão sem bem não produzem. Salva e carrega.
- Utilidade na agenda: no horário de trabalho, quem junta ouro fica no posto em vez do almoço ou da pausa previstos; fome e cansaço urgentes continuam vencendo.
- Visita por utilidade: no tempo livre, o morador vai à casa de quem gosta dele (afeto acima de 30) se essa pessoa estiver em casa.
- Ferramenta de ofício pela história: quem começou o ofício há 2 anos ou mais já tem a ferramenta; aprendizes e ajudantes recentes compram na Mara no tempo livre, quando têm ouro.
- Fase 2 (sociedade): família paga a refeição de criança sem ouro (`FAMILY_SUPPORT`). Consequência por grupo: a reputação da facção do vendedor muda o preço de todos os seus vendedores (templo hostil cobra 25% a mais; amigo, 10% de desconto).
- Prólogo (Fase 3): ao criar o personagem, abre-se o questionário do passado (seis perguntas); "Deixar o Destino Decidir" sorteia a semente. O começo move o jogador para o lugar do passado. Verificado por `tools/playtest_prologo.gd`.
- Fase 4 (economia): crise de escassez explícita por bem da vila, com histerese (`SHORTAGE_STARTED`, `SHORTAGE_ENDED`), recuperação pela produção e registro no diário. O diário (J) ganha a seção "Crônica da vila", que antes não aparecia na interface.
- Fase 4: na falta de comida, a refeição na taverna custa o dobro. Quem não pode pagar o novo preço continua com fome.
- Fase 4: segunda rota comercial, de Sambúrdia (remédio em excesso, mensageiro Tarso Pedrada). As rotas agora vêm de `economy.json`. Eventos de estrada podem fechá-la e reabri-la. Verificação: `tools/playtest_rota.gd`.
- Crônica da vila registra entregas de mercadoria de outras regiões (`TRADE_DELIVERED`) e mostra as rotas pelo nome ("estrada de Sambúrdia"), no lugar do id técnico.
- Progressão e ficha: XP sem teto (a curva 500 × n × (n−1) segue a tabela do LB depois do nível 10); subida de nível abre um painel com o ganho de PV/PM e cada opção com seu efeito; a árvore mostra o que falta nos poderes bloqueados; a criação lista os poderes da classe com o efeito. XP de debug (`DebugSet` com `xp`) passa pelo caminho normal. Verificação: `tests/unit/test_progressao_dinamica.gd`, `tools/playtest_subida.gd` e `tools/playtest_criacao.gd`.
- Fase 6 (correções): companheiros têm ficha completa (construtor de personagens, `combate` em `npcs.json`), o dano persiste entre lutas, um dia de descanso recupera PV, e o companheiro em contrato caminha até o destino (`estrada_leste`). Testes em `tests/unit/test_companheiros_persistencia.gd`.
- Fase 6: companheiros são IAs na luta, com ordens (seguir, proteger, manter posição, recuar); ordem trocada na luta vale já. Contratos da guilda com caixa, morte no serviço falha o contrato e administração distribui o caixa. Diário ganha "Grupo e guilda". Verificação: `tests/unit/test_companheiros_combate.gd`, `tests/unit/test_contratos_guilda.gd` e `tools/playtest_companheiros.gd`.
- Fase 5: segurança, moradia e influência da vila (indicadores em `CitiesModule`), e construções pagas com o tesouro (comando `Build`: celeiro, casa nova, guarita). Seção "Cidade da vila" no diário, com botões. Verificação: `tests/unit/test_cidade_fase5.gd` e `tools/playtest_cidade.gd`.
- Fase 4 concluída no escopo do plano: madeira (quinta mercadoria, só em Sambúrdia, com tábua na loja da Mara); diário ganha a seção "Rotas comerciais" com estado e chegada do mensageiro (`route_summary`). Verificação: `tools/playtest_rota.gd` (captura do diário) e `tests/unit/test_rota_samburdia.gd`.
- Geração de dados: `tools/build_content.py` agora gera também a produção do trabalho, a ferramenta de ofício (loja da Mara), o item `ferramenta_oficio` e Sambúrdia. Antes estavam só editados à mão e se perderiam ao regenerar. Voz do mensageiro em `tools/build_voices.py`.
- Menu de debug (F2): teleporte para qualquer local ou morador, e ajuste de hora, ouro, tesouro, estoque da vila, clima e de ouro, fome e cansaço de cada morador. Tudo passa por comandos validados (`DebugModule`). `DebugMenu.ENABLED` esconde o menu em builds de jogador.
- Carroças de entrega: `CartsModule` (domínio). Nascem de dia, levam a mercadoria que falta na vila, descarregam no mercado (estoque sobe) e voltam. A apresentação só desenha a posição. Salvam e carregam.

## [0.7.0] — 2026-10-24 — Mundo vivo, árvore de poderes, HUD Stoneshard e Godot 4.7.2
### Mudou
- **Motor: Godot 4.7.2** (a versão que o usuário enviou; conferida contra o SHA-512 oficial). Na 4.3, a tela
  piscava com blocos pretos sob carga de desenho no renderizador de compatibilidade; na 4.7.2 o mesmo teste fica limpo.
  - JSON da 4.7 escreve `19.0` onde a 4.3 escrevia `19`: os campos inteiros dos ataques voltam a int ao carregar e os
    testes comparam salvamentos por valor.
### Adicionado
- **Eventos da vila** (`TownEventsModule`, ORIGINAL_DO_JOGO): feira semanal (mascates enchem o estoque, artesãos vão ao
  mercado) e Festa de Alvorada a cada 14 dias (a vila vai à praça; guardas ficam no posto; tempestade suspende).
- **Clima que muda aos poucos:** a intensidade da chuva/neblina sobe e desce em ~40 min; vento com direção (leva a fumaça
  e inclina a chuva).
- **Árvore de poderes (tecla K):** ramo da classe e poderes gerais do LB p.124-131, conferidos no PDF: Ataque Poderoso,
  Trespassar, Combate Defensivo, Esquiva, Reflexos de Combate, Saque Rápido, Vitalidade e Vontade de Ferro.
  Quebrar, Derrubar e Desarmar Aprimorado aparecem marcados como "ainda não implementado".
- **Casas com volume:** telhado de quatro águas (telha, ardósia, palha) que some ao entrar, fachada em enxaimel com
  janelas que acendem à noite, placas de ofício, chaminés com fumaça, torre do templo e moinho girando.
- **Caminhos orgânicos:** bordas irregulares nas estradas, trilhas contínuas, trilhas de desejo das portas até a
  estrada, praça calçada em volta do poço, flores e seixos, poças quando o chão está molhado.
- **Gente nas ruas (figurantes, só apresentação):** passantes, gente trabalhando, conversas, vendedores gritando,
  crianças brincando de pega-pega, carroças, correria para casa na chuva; barracas na feira; bandeirolas, lanternas,
  fogueira, músico e dança na festa. NPCs parados em lugares abertos dão alguns passos.
- **HUD estilo Stoneshard:** minimapa com ícone do clima, faixa do evento da vila, avisos grandes (chuva, festa, nível),
  cinto de atalhos na exploração e cinto de ações com ícones no combate (Ataque Poderoso e Combate Defensivo nas teclas A e D).
- **Orientações do pacote godot-claude-skills** (`docs/ORIENTACOES_GODOT.md`): checagem de tipos
  (`tools/check_gdscript_style.py`), nomes e grupos de nós, capturas só com o quadro completo.
- Chão decorado e telhados são desenhados uma vez em textura (com a tela "Preparando a vila..." por alguns segundos).
### Corrigido
- Névoa escurecia a tela (o ruído era opaco); agora é branca e transparente.

## [0.6.0] — 2026-10-24 — Executável real, todas as raças, luz, cinema de combate e HUD
### Adicionado
- **Executável Windows de verdade:** template oficial da Godot 4.3, conferido por SHA-512, no lugar do editor renomeado que deu tela azul.
  - Desenho via ANGLE (Direct3D 11), vsync ligado e limite de 60 FPS.
  - Modo seguro (`--modo-seguro`): gráficos mínimos, 30 FPS e sem flashes.
  - Autoteste do executável (`--autoteste`).
  - `tools/build_windows.sh`: só empacota se o autoteste do build passar.
- **Todas as raças do Livro Básico:** são 17 raças, com o suraggel em duas variantes (aggelus e sulfure).
  - Cada raça tem atributos, deslocamento, tamanho (modificador de Furtividade), sentidos, RD por tipo, armas naturais, PM extra, bônus de perícia, Tatuagem Mística e Ossos Frágeis.
  - O visual de cada raça é provisório (tinta e escala).
  - O que ainda não tem sistema aparece como "pendente" na própria regra e na tela de criação.
- **Pendências pequenas:**
  - C24: o Ataque Reflexo dispara quando o alvo fica desprevenido, e o Kael usa Ataque Reflexo e Ímpeto.
  - C25: as crianças crescem e viram aprendizes do ofício de um dos pais.
  - C27: o Ataque Especial escala com o nível e há Ataque Extra no 6º nível.
- **Luz e atmosfera**, com as fontes em `docs/REFERENCIAS_VISUAIS.md`:
  - quadros-chave de luz por hora do dia e gradação de cor;
  - tochas que cintilam e janelas que acendem à noite;
  - sombras de contato e sombras projetadas pelo sol ou pela luz mais próxima;
  - névoa em duas camadas e respingos de chuva;
  - relâmpago na tempestade;
  - desfoque seletivo nas bordas, que nunca atinge o centro;
  - vinheta.
- **Combate cinematográfico** (para o jogador e para os inimigos):
  - Gatilhos: crítico, abate, falha crítica, aposta arriscada que deu certo, plano "garantido" que falhou e "por um fio".
  - Encenação: barras de cinema, aproximação da câmera, retratos com expressão, câmera lenta, legenda e interface escondida.
  - Pode ser pulado com um clique e respeita "reduzir movimento".
- **Retratos com 8 expressões:** desenho provisório procedural, com o sistema pronto para receber retratos aprovados pelo governador.
- **Golpes e impacto** no estilo Dead Cells:
  - antecipação, avanço e recuperação;
  - rastro de "vento" no golpe (corte, estocada e impacto) e no erro;
  - *hit stop*, partículas por tipo de golpe, anel de choque, recuo, tremor e flash no alvo;
  - esquiva;
  - Seta Infalível como projétil, Toque Chocante como arco elétrico, aura na Armadura Arcana e na cura.
- **Movimento fluido:** aceleração e frenagem rápidas, poeira ao arrancar e virar, compressão e estiramento, balanço ao andar e respiração.
- **HUD e janelas** no estilo da interface de Stoneshard:
  - placa de estado com retrato, que muda de expressão conforme os PV, e barras de PV, PM e XP;
  - placa de hora e lugar;
  - tema novo;
  - janelas que entram com animação;
  - diálogo com retrato e texto progressivo;
  - criação com prévia ao vivo.
- `tools/fx_runner.gd` (capturas dos sistemas visuais) e `tools/combat_fx_check.gd` (verifica de ponta a ponta que a cena de abate termina, a escala de tempo volta a 1 e a interface reaparece).
### Corrigido durante a verificação
- Erros de parse que só apareciam no build: duas funções que não existem na Godot 4.3. O autoteste do executável os pegou.
- A cripta estava escura demais, com personagens ilegíveis. As tochas apareciam de dia. O entardecer estava vermelho demais (a pasta de arte pede "não tornar Arton toda rubra"). Os efeitos sumiam na escuridão: agora ficam numa camada própria.
- A barra de estado quebrava o texto em colunas.

## [0.5.0] — 2026-10-24 — Poderes, reações, gerações vivas e regras 100% conferidas
### Adicionado
- **C21, 11 poderes do Livro Básico,** com pré-requisitos checados na escolha:
  - **Guerreiro:**
    - **Ataque Reflexo**, uma reação: ataca quem sai do seu alcance.
    - **Ímpeto** (tecla I): +6m na rodada.
    - **Arqueiro:** Sabedoria no dano à distância.
  - **Ladino:**
    - **Emboscar** (tecla M): ação padrão extra na 1ª rodada.
    - **Velocidade Ladina** (tecla V): ação de movimento extra.
    - **Rolamento Defensivo:** metade do dano, mas fica caído.
    - **Sombra:** +2 em Furtividade.
  - **Arcanista:**
    - **Arcano de Batalha:** atributo-chave no dano das magias.
    - **Magia Pungente** (tecla P): +1 PM, CD +2.
    - **Poder Mágico:** +1 PM por nível.
    - **Raio Arcano:** 1d8, alcance curto, Reflexos reduz à metade.
  - O Rolamento Defensivo e o Ataque Reflexo têm política no diário, como o Durão.
- **C7, nascimentos viram NPCs reais,** com nome, gênero, família, agenda, memória dos pais e save. Crianças pequenas ficam em casa.
- **C8, casamentos durante o jogo:** adultos solteiros de famílias diferentes se casam, e o casal muda de casa. Novos casais também podem ter filhos.
- **C11, fichas de NPC pela Tabela 7-2** (LB p.322-323). A capitã Elsa (ND 2) investiga com +8 em vez do +4 provisório.
- **C10, a matilha muda de toca de verdade:** as hienas vão para a toca funda.
- Cenário de laboratório **"Poderes de classe"**. O cenário de magia agora tem Raio Arcano e Magia Pungente.
### Corrigido / verificado
- **R1:** as 6 regras pendentes foram conferidas no livro. São 106 regras, 105 verificadas e 1 adaptada.
  - A funda soma Força no dano (LB p.148).
  - A CD da jornada depende do terreno: floresta 20 (LB p.320).
  - A poção custa T$ 30 (LB p.341).
- **C16:** nenhum vazamento de memória ao sair. Lambdas que criavam ciclos foram trocadas por métodos.
- **C15:** 7 dias de jogo levam cerca de 150 ms, com teste de desempenho.
- A checagem de testes agora também abre o jogo de verdade e reprova erros de parse nas telas.

## [0.4.0] — 2026-10-24 — Arcanista completo, perícias, poderes sob controle e resumo de XP
### Adicionado
- **C17, escolha de perícias** na criação (LB p.114): as da classe saem da lista da classe, e Int e Versátil liberam perícias livres. A escolha é validada.
- **C4, Caminho do Arcanista** (LB p.37): Bruxo (Int), Feiticeiro (Car) e Mago (Int, +1 magia). Duas magias novas:
  - **Armadura Arcana**: +5 de Defesa pela cena, sem acumular com armadura (LB p.183).
  - **Toque Chocante**: 2d8+2, Fortitude reduz à metade, −5 contra armadura de metal (LB p.209). A CD das magias segue LB p.173.
  - A tecla 4 alterna entre as magias conhecidas e avisa quando haverá teste.
- **C5, concentração ao lançar** (LB p.170): caído ou em tempestade, Vontade CD 15 + custo. Lançar magia arcana de armadura pede Misticismo CD 20 + custo com penalidade (LB p.171). Na falha, a magia se perde e os PM são gastos.
- **C20, controle dos poderes com custo:**
  - Golpe de Raspão: "usar ao errar" ou "nunca", e a tecla R troca só no turno.
  - Durão: "golpes fortes", "sempre" ou "nunca".
  - Ajustável no diário e salvo no save.
- **C22, janela de resumo pós-combate** com base, cada fator, multiplicador e progresso até o próximo nível.
- **C23, `tools/run_tests.py`:** um teste que dá erro de script em tempo de execução agora reprova (antes passava).
- 9 regras novas verificadas (94 no total: 87 verificadas). 7 testes novos (127 no total).

## [0.3.1] — 2026-10-24 — Governador de Direção de Arte
### Adicionado
- **Governador de Direção de Arte** (`docs/GOVERNADOR_DE_ARTE.md`):
  - O registro é gerado da pasta "arte do jogo" (`tools/build_art_direction.py` → `data/art/direcao_de_arte.json`).
  - Em tempo de execução, `ArtGovernor` aplica 16 regras AD.
  - Na CI, a checagem é `tools/check_art_direction.py`.
- **Vegetação aprovada na floresta:** os 20 componentes LPC Jungle do lote 02 (CC-BY 4.0), originais sem alteração e com SHA-256 conferido.
  - Pivô na base e Y-sort.
  - Copas translúcidas perto do jogador e no combate.
  - Trilhas e estradas livres.
  - A vila continua com o placeholder.
- **Tela "Créditos de arte"** com o arquivo de créditos integral.
- 8 testes do governador (`test_art_governor.gd`) e 3 capturas da floresta.
### Mudado
- `validate_assets.py` aceita `sprite_objeto` e o estado `approved_artistic`. O texto da tela de título não diz mais que toda a arte é original.

## [0.3.0] — 2026-10-23 — Protótipos evoluídos, XP dinâmica e interações
### Adicionado
- **XP dinâmica** (padrão; o modo do livro pode ser ligado no diário): base do LB × desempenho e circunstâncias, novidade decrescente, XP de aprendizado e de evasão, conta sempre visível. Ver `docs/XP_DINAMICA.md`.
- **Poderes de classe ao subir de nível** (`ChoosePower`):
  - Especialização em Arma, Valentão, Golpe de Raspão, Aumento de Atributo, Gatuno e Truque Mágico (LB p.65–66, 74).
  - Durão no 3º nível do guerreiro.
- **Derrubar da Hiena** como manobra livre (Bestiário p.120, LB p.234). Caído reduz o deslocamento e exige levantar.
- **Modo de tiro** no combate (tecla 6) e alcances de armas e magias pelo livro (LB p.143).
- **Penalidade de armadura** em todas as perícias marcadas (LB p.115).
- **Emboscada tática** ao partir em viagem: salteadores, teste de Percepção x Furtividade, risco causal (bando ativo; a patrulha do domínio reduz).
- **Mercado de Valkaria** com preços regionais. O herdeiro passa pela criação de personagem.
- **Interações:**
  - A farinha do domínio entra no estoque da vila.
  - Os ataques da matilha custam comida.
  - Memórias comuns são esquecidas em 30 dias, contando da data do fato original.
- **20 testes de interação** (`tests/unit/test_interactions.gd`) e um cenário novo, "Emboscada na estrada".
### Corrigido
- **Bug grave:** todas as criaturas ganhavam +2 de dano (checagem vazia da Especialização em Arma). Agora há teste de regressão.
- **Rumores travavam:** cada NPC repetia para sempre a mesma memória "principal", e notícias novas não circulavam. Agora conta o que algum presente ainda não sabe.
- **Derrubar não era aplicado:** o campo não era copiado do bloco da criatura.
- **Derrota para salteadores:** levava o jogador para a cela da cripta. Agora rouba e deixa o jogador na estrada.
- **Hiena reconferida:** os valores estão corretos no livro. O perigo vem do ND pressupor um grupo de 4 heróis.
- **Alcances** curto/médio/longo verificados (antes eram de memória).

## [0.2.0] — 2026-10-23 — Todas as mecânicas em protótipo
### Adicionado
- **Laboratório de protótipos:** 21 cenários jogáveis (`src/application/prototypes.gd`), cada um com teste (`tests/unit/test_prototypes.gd`).
- **Regras novas (18):** tabela de XP (LB p.35), XP por desafio (p.326), Anão (p.20), tabela de raças (p.18), Ladino (p.73), Arcanista (p.37), custo de magia (p.170), Seta Infalível (p.206), Curar Ferimentos (p.189), poção como ação padrão (p.234), saco de dormir (p.156), viagem (p.270), jornada pelos ermos (p.320), Khalmyr (p.99), Allihanna (p.97).
- **Módulos novos:** progression, items, travel, domain, lineage, adventurers, fauna, pacing.
- **Domínio:** `CharacterBuilder` (criação), `Biography` (histórico gerado), magia e poção no combate, Ataque Furtivo, investigação criminal sem testemunhas, preconceito individual, obrigações de Khalmyr e Allihanna, vários mistérios simultâneos ("As Ovelhas de Fenna").
- **Interface:** laboratório, criação de personagem, painel de Valkaria, seções do diário (XP, inventário com equipar/usar, domínio, gerações), sucessão na tela de morte, overlay F3, modos de magia e poção no combate.
- **Infraestrutura:** `LocalEchoProvider`, uma IA local de demonstração.
- **Documentação:** `docs/ROADMAP.md` (correções, revisões, próximos passos), `docs/PROTOTIPOS.md`, ADR-0004.
### Corrigido
- Tomas incluído entre as testemunhas do próprio resgate pela Guarda.
- Tempo de viagem passa a contar dias de calendário (marcha mais descanso).
- Descanso em Valkaria usa estalagem, não a regra da vila.

## [0.1.0] — 2026-10-23 — Vertical slice (Fases 1–7 no escopo do slice)
### Adicionado
- **Regras:** `RuleRegistry` com 58 regras extraídas do Livro Básico e do Bestiário, cada uma com fonte, página impressa, página do PDF e status. `CharacterSheet`, `Checks` e `Dice` seguem LB p.114, 220, 230–239 e 394.
- **Mundo modular:** `WorldModule` com validate/execute/on_tick/on_event, commit único por comando, journal compacto e preservação de dados de módulos ausentes.
- **Módulos:** state, objects, npcs, weather, exploration, memory, factions, combat, dialogue, crime, economy, region_sim, religion.
- **Conteúdo original:** mapa 96×64 (vila, estrada, rio, floresta, ruína, cripta), 25 NPCs com agendas, 5 famílias, 3 facções, o mistério "O Filho do Moleiro" e 10 árvores de diálogo.
- **Combate:** `CombatSim`, `GhostPlanner`, IA inimiga, captura e morte.
- **Apresentação:** tilemap com colisão, atores animados, câmera cinematográfica, dia/noite, luzes, chuva, neblina, combate visual com fantasma e UI completa (título, HUD, diálogo, diário, loja, pausa, opções, fim de jogo).
- **Arte provisória original** gerada por script, com manifesto e validador.
- **IA opcional** (`LlmDialogueProvider`) com limite de chamadas, timeout, cache, validação de saída e auditoria.
- **Ferramentas:** benchmark, capturas automáticas, checagem de arquitetura, CI e relatório de regras.
- **Testes:** 71 testes de invariantes, sistemas e ponta a ponta.
### Mudado
- Formato de save: schema v2, com migração automática de v1.
- `WorldState` passa a incluir o estado do barramento de eventos (determinismo após load).
### Corrigido durante a verificação
- Testemunhas registradas antes de o resgatado sair do local.
- Checksum estável com a conversão int/float do JSON.
- Referência fraca mundo↔módulo para evitar vazamento por ciclo.
- Combate encerra um diálogo aberto por evento, sem escrever no estado do módulo de diálogo.

## [0.0.1] — 2026-10-23 — Fase 0
- Projeto Godot mínimo, contratos, relógio, RNG, save atômico e 18 testes.
