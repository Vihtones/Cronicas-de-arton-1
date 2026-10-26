CRÔNICAS DE ARTON
CDA-WORLD-001 — ARTON VIVA
Documento Mestre de Engenharia de Mundo, Simulação e Liberdade do Jogador
Versão: 2.0
Data: 26/10/2026
Projeto: Crônicas de Arton
Mundo: Arton, cenário de Tormenta20
Destinatário: Claude, responsável pelo desenvolvimento do jogo
Tipo: Especificação de engenharia de software, arquitetura de sistemas e game design
Documento complementar: CDA-GAME-002 — Completude e Qualidade
0. DIRETRIZ PRINCIPAL
Desenvolver Crônicas de Arton como um RPG de mundo aberto, persistente e sistêmico, ambientado em Arton.
O jogador deverá criar sua própria trajetória em um mundo que continua funcionando independentemente dele.
O objetivo não é criar uma campanha linear com muitas escolhas aparentes. É construir um conjunto de sistemas integrados que permita o surgimento de histórias através da interação entre personagens, comunidades, economia, política, magia, conflitos e decisões.
Princípio fundamental: o jogador pertence ao mundo, mas o mundo não existe exclusivamente para ele.
Instruções obrigatórias

1. Preservar o projeto existente.
2. Inspecionar o código antes de modificar a arquitetura.
3. Reutilizar sistemas já funcionais.
4. Implementar por dependências, não por quantidade de funcionalidades.
5. Priorizar sistemas que gerem comportamentos jogáveis.
6. Não criar mapas e conteúdo em massa prematuramente.
7. Não depender de modelos generativos para executar a simulação cotidiana.
8. Separar regras oficiais de Tormenta20 de sistemas homebrew.
9. Validar persistência, desempenho e consequências.
10. Continuar o desenvolvimento com autonomia técnica, solicitando decisões apenas quando realmente necessário.

1. VISÃO GERAL
1.1 Objetivo do produto
Criar um RPG no qual o jogador possa:

* Escolher sua raça, classe, origem e histórico.
* Começar em diferentes regiões de Arton.
* Possuir família, conhecidos, rivais ou nenhum vínculo.
* Viver em uma casa, estabelecimento ou acampamento.
* Trabalhar, negociar, explorar e lutar.
* Desenvolver relacionamentos.
* Formar uma equipe de aventureiros.
* Criar uma guilda.
* Participar de organizações.
* Influenciar governos e facções.
* Adquirir propriedades.
* Conquistar poder político.
* Cometer crimes e sofrer consequências.
* Transformar cidades e comunidades.
* Investigar mistérios.
* Utilizar magia.
* Enfrentar a Tormenta.
* Construir uma história sem destino obrigatório.

O jogador poderá escolher uma trajetória pacífica, aventureira, criminosa, comercial, política ou militar.
Essas possibilidades não precisam estar disponíveis integralmente na primeira versão, mas a arquitetura deverá permitir sua expansão.
1.2 Filosofia de desenvolvimento
Profundidade antes de escala.
Uma região com personagens interessantes, sistemas funcionais e consequências reais é mais valiosa do que dezenas de regiões vazias.
Integração antes de quantidade.
Uma economia que altera o comportamento dos NPCs é mais importante do que uma economia que apenas modifica números.
Liberdade antes de roteiro obrigatório.
O jogo deve oferecer oportunidades sem forçar uma missão principal.
Consequências antes de moralidade simplificada.
As ações precisam afetar pessoas e instituições, não apenas uma barra de karma.
2. ESCOPO DO MUNDO: ARTON
2.1 Mundo principal
Arton será o mundo central do jogo.
A arquitetura deverá representar:

* Continentes.
* Reinos.
* Regiões.
* Cidades.
* Vilas.
* Territórios selvagens.
* Rotas comerciais.
* Organizações.
* Culturas.
* Religiões.
* Conflitos.
* Ameaças sobrenaturais.

2.2 Fidelidade ao cenário
Utilizar o cenário oficial de Tormenta20 como referência principal.
Distinguir:
Conteúdo oficial: elementos estabelecidos nos materiais de referência autorizados.
Expansão sistêmica: regras de simulação criadas para permitir funcionamento autônomo do mundo.
Conteúdo homebrew: mecânicas e interpretações novas que não devem ser apresentadas como oficiais.
2.3 Escala de implementação
A arquitetura será global, mas a produção será incremental.
Dividir o mundo em:

1. Regiões plenamente jogáveis.
2. Regiões parcialmente representadas.
3. Regiões simuladas abstratamente.
4. Regiões ainda não implementadas.

Nunca apresentar uma região não jogável como se estivesse concluída.
2.4 Identidade regional
Cada região poderá possuir:

* Cultura.
* Leis.
* Religiões.
* Economia.
* Recursos.
* Criaturas.
* Clima.
* Segurança.
* Organizações.
* Preconceitos sociais.
* Arquitetura.
* História.
* Oportunidades.

Esses atributos devem ser definidos por dados e referências coerentes com o cenário.
3. ARQUITETURA CENTRAL: WORLD SIMULATION CORE
3.1 Objetivo
Criar ou consolidar um núcleo responsável por coordenar a simulação persistente do mundo.
Nome conceitual:
Arton Viva — World Simulation Core
3.2 Responsabilidades
O núcleo deverá coordenar:

* Tempo.
* Eventos.
* Agentes.
* Objetivos.
* Necessidades.
* Relações.
* Reputação.
* Economia.
* Política.
* Organizações.
* Cidades.
* Magia.
* Tormenta.
* História.
* Persistência.

3.3 Arquitetura modular
Cada domínio terá responsabilidades específicas.
Os módulos devem comunicar-se por contratos estáveis e eventos, evitando dependências circulares.
3.4 Fluxo principal
Estado do mundo
→ atualização temporal
→ eventos
→ percepção dos agentes
→ avaliação de objetivos
→ decisões
→ ações
→ consequências
→ persistência
→ novos estados.
3.5 Requisitos técnicos

* IDs persistentes.
* Estados serializáveis.
* Eventos identificáveis.
* Sementes controladas.
* Validação de dados.
* Migrações de salvamento.
* Processamento idempotente quando necessário.
* Logs de depuração.
* Testes automatizados.
* Simulação independente da interface gráfica.

4. NPCs AUTÔNOMOS
4.1 Objetivo
Os NPCs não devem existir apenas para fornecer missões, vender produtos ou repetir falas.
Devem possuir atividades, necessidades, interesses e capacidade limitada de tomar decisões.
4.2 Modelo de agente
Criar ou adaptar um modelo de agente contendo, conforme necessário:

* Identidade.
* Raça.
* Classe.
* Nível.
* Profissão.
* Residência.
* Recursos.
* Inventário.
* Personalidade.
* Humor.
* Necessidades.
* Objetivos.
* Memórias.
* Relacionamentos.
* Organizações.
* Localização.
* Conhecimentos.
* Estado de saúde.
* Condição social.
* Situação legal.

Nem todos os NPCs precisam da mesma complexidade.
4.3 Personalidade
Utilizar dimensões como:

* Ambição.
* Coragem.
* Prudência.
* Empatia.
* Ganância.
* Disciplina.
* Curiosidade.
* Sociabilidade.
* Lealdade.
* Tolerância ao risco.

A personalidade influencia decisões, mas não determina absolutamente o comportamento.
4.4 Necessidades
Exemplos:

* Alimentação.
* Descanso.
* Segurança.
* Saúde.
* Dinheiro.
* Moradia.
* Pertencimento.
* Reconhecimento.
* Estabilidade.

4.5 Objetivos
Separar objetivos por horizonte temporal.
Curto prazo: comprar comida, trabalhar, descansar.
Médio prazo: quitar dívidas, adquirir ferramentas, conseguir emprego.
Longo prazo: abrir estabelecimento, formar família, entrar numa organização, conquistar prestígio.
4.6 Decisão
Utilizar um modelo de decisão baseado em utilidade, prioridades, restrições e contexto.
Considerar:

* Objetivos.
* Necessidades.
* Personalidade.
* Recursos.
* Oportunidades.
* Riscos.
* Conhecimento disponível.
* Relações.
* Leis.
* Obrigações.

4.7 Evolução
NPCs podem:

* Aprender.
* Treinar.
* Trabalhar.
* Prosperar.
* Falir.
* Mudar de profissão.
* Viajar.
* Formar vínculos.
* Entrar em organizações.
* Abandonar objetivos.
* Envelhecer.
* Estagnar.
* Morrer.

A evolução não deve ser automática nem ilimitada.
5. MEMÓRIAS E RELACIONAMENTOS
5.1 Memórias
Registrar acontecimentos relevantes:

* Favores.
* Promessas.
* Dívidas.
* Ajuda.
* Traição.
* Violência.
* Resgate.
* Amizade.
* Rivalidade.
* Perdas.
* Conquistas.
* Conflitos.

5.2 Conhecimento individual
Cada NPC deverá possuir apenas as informações que poderia razoavelmente conhecer.
Distinguir:

* Acontecimento real.
* Informação testemunhada.
* Informação recebida.
* Rumor.
* Interpretação pessoal.

5.3 Relacionamentos multidimensionais
Representar:

* Confiança.
* Afeto.
* Respeito.
* Medo.
* Ressentimento.
* Lealdade.
* Admiração.
* Familiaridade.

Não utilizar uma única barra universal de amizade.
5.4 Relações possíveis

* Conhecido.
* Amigo.
* Rival.
* Mentor.
* Aprendiz.
* Empregador.
* Funcionário.
* Familiar.
* Companheiro.
* Parceiro.
* Inimigo.

5.5 Relacionamentos afetivos
Permitir relacionamentos românticos e familiares quando apropriado.
Exigir personagens adultos, consentimento e compatibilidade contextual.
Relacionamentos não devem ser garantidos por repetição de presentes ou por uma pontuação isolada.
5.6 Persistência
NPCs relacionados ao jogador continuam existindo e evoluindo mesmo quando estão distantes.
6. REPUTAÇÃO, MORALIDADE E CONSEQUÊNCIAS
6.1 Modelo contextual
Não criar uma escala única de herói e vilão.
A mesma ação poderá ser interpretada de maneiras diferentes por pessoas e organizações.
6.2 Registro de acontecimentos
Ações importantes devem registrar:

* Autor.
* Alvo.
* Local.
* Momento.
* Testemunhas.
* Consequências.
* Contexto.
* Conhecimento público.
* Legalidade.
* Interpretações sociais.

6.3 Reputação
Calcular reputação por:

* NPC.
* Comunidade.
* Cidade.
* Organização.
* Facção.
* Reino.
* Instituição religiosa.

6.4 Rumores
Rumores podem ser verdadeiros, falsos, exagerados ou incompletos.
Sua circulação depende de contato social, viagens e meios de comunicação disponíveis.
6.5 Crimes
Permitir ações criminosas dentro das possibilidades do jogo.
Consequências podem incluir:

* Investigação.
* Perseguição.
* Prisão.
* Multas.
* Recompensas.
* Vingança.
* Perda de confiança.
* Mudanças políticas.
* Reações familiares.

6.6 Ausência de imunidade narrativa
NPCs importantes não devem ser automaticamente invulneráveis.
Instituições devem possuir mecanismos de sucessão, substituição ou dissolução.
7. PRÓLOGO VIVO: ORIGENS E DESTINOS
7.1 Objetivo
Permitir diferentes condições iniciais de jogo conforme as escolhas do jogador.
7.2 Separação de sistemas
Origem T20: elemento mecânico oficial da ficha.
Histórico social: conjunto adicional de escolhas que define o passado e as condições iniciais.
Não confundir os dois.
7.3 Questionário
O jogador poderá responder a perguntas curtas sobre:

1. Região onde cresceu.
2. Condição econômica.
3. Família e vínculos.
4. Profissão anterior.
5. Estilo de moradia.
6. Acontecimento recente.
7. Situação em que deseja começar.

7.4 Possíveis condições

* Mineiro.
* Artesão.
* Trabalhador rural.
* Comerciante.
* Aprendiz.
* Viajante.
* Nômade.
* Herdeiro.
* Cativo.
* Aventureiro iniciante.
* Morador comum.
* Pessoa sem residência permanente.

Essas condições são exemplos, não classes mecânicas adicionais.
7.5 Estado inicial
Gerar:

* Região.
* Localização.
* Residência.
* Recursos.
* Equipamentos.
* Dinheiro.
* Dívidas.
* Contatos.
* Familiares.
* Conhecidos.
* Rivais.
* Empregadores.
* Reputação.
* Oportunidades.

7.6 NPCs reais
Familiares, amigos, mentores e rivais devem existir na simulação.
Não criar personagens que aparecem somente no texto introdutório.
7.7 Liberdade de trajetória
O jogador pode continuar sua profissão inicial ou abandoná-la.
O histórico influencia oportunidades, mas não impõe uma campanha.
8. DEIXAR O DESTINO DECIDIR
8.1 Recurso
Adicionar a opção:
Deixar o Destino Decidir
O sistema gera automaticamente um passado e uma situação inicial coerentes.
8.2 Modos

* Sorteio completo.
* Sorteio apenas do histórico.
* Sorteio apenas da região.
* Sorteio preservando escolhas selecionadas.
* Gerar novamente.
* Aceitar resultado.

8.3 Regras
O sorteio deve considerar:

* Raça.
* Classe.
* Origem oficial.
* Região.
* Cultura.
* Condição econômica.
* Profissões disponíveis.
* Leis.
* Locais jogáveis.
* Requisitos mínimos de sobrevivência.

8.4 Reprodutibilidade
Utilizar sementes e registrar a versão do gerador.
8.5 Validação
Nunca gerar:

* Localização inexistente.
* Situação impossível de iniciar.
* Relações com NPCs ausentes.
* Itens essenciais inválidos.
* Região não jogável apresentada como disponível.
* Condições incompatíveis com a ficha.

8.6 Rejogabilidade
Diferentes sementes devem produzir combinações variadas, mas plausíveis.
Evitar sorteios que gerem apenas mudanças cosméticas.
9. ECONOMIA REGIONAL
9.1 Objetivo
Construir uma economia que funcione independentemente do jogador.
9.2 Entidades

* Produtores.
* Consumidores.
* Mercados.
* Estabelecimentos.
* Caravanas.
* Rotas comerciais.
* Cidades.
* Regiões.
* Contratos.

9.3 Variáveis

* Produção.
* Consumo.
* Estoque.
* Oferta.
* Demanda.
* Preços.
* Salários.
* Impostos.
* Transporte.
* Segurança.
* Capacidade produtiva.
* Recursos monetários.

9.4 Preços
Variar preços conforme:

* Disponibilidade.
* Procura.
* Transporte.
* Impostos.
* Risco.
* Acontecimentos.
* Condições regionais.

9.5 Inflação
Distinguir inflação geral de escassez localizada.
Não utilizar uma fórmula única para representar todos os fenômenos econômicos.
9.6 Comércio
Caravanas e comerciantes devem transportar mercadorias reais ou cargas representadas abstratamente de forma consistente.
9.7 Crises
Permitir:

* Escassez.
* Interrupção comercial.
* Desemprego.
* Falência.
* Aumento de preços.
* Recuperação econômica.

9.8 Estabilidade
Implementar amortecimento, limites e mecanismos de recuperação.
Evitar colapso inevitável causado apenas pela passagem do tempo.
10. CIDADES E COMUNIDADES DINÂMICAS
10.1 Indicadores
Cada comunidade poderá possuir:

* População.
* Abastecimento.
* Segurança.
* Prosperidade.
* Saúde.
* Moradia.
* Infraestrutura.
* Comércio.
* Estabilidade.
* Influência política.
* Ameaças.

10.2 Crescimento
Permitir:

* Construções.
* Reformas.
* Novos estabelecimentos.
* Melhorias de estradas.
* Expansão de mercados.
* Investimentos.
* Migração.

10.3 Declínio
Permitir:

* Abandono.
* Destruição.
* Falência.
* Insegurança.
* Fuga de moradores.
* Perda de serviços.
* Crises políticas.

10.4 Representação visual
Mudanças relevantes devem aparecer no cenário quando houver suporte gráfico.
10.5 Recuperação
Cidades podem melhorar por decisões de NPCs, organizações e governos.
Não exigir intervenção do jogador.
11. POLÍTICA E FACÇÕES
11.1 Organizações
Representar:

* Governos.
* Casas nobres.
* Guildas.
* Instituições religiosas.
* Organizações militares.
* Movimentos sociais.
* Facções criminosas.
* Organizações comerciais.

11.2 Dados
Cada facção poderá possuir:

* Objetivos.
* Liderança.
* Membros.
* Recursos.
* Patrimônio.
* Influência.
* Território.
* Alianças.
* Rivalidades.
* Regras internas.

11.3 Ações
Facções podem:

* Negociar.
* Recrutar.
* Investir.
* Financiar.
* Investigar.
* Defender.
* Atacar.
* Formar alianças.
* Romper acordos.
* Disputar território.
* Influenciar governos.

11.4 Conquista e administração
O jogador poderá tentar conquistar influência ou controle político por meios coerentes com o mundo.
Governar deverá exigir recursos, legitimidade, segurança e administração.
11.5 Sucessão
Organizações precisam reagir à perda de lideranças.
12. CULTURA, IDENTIDADE E DISCRIMINAÇÃO
12.1 Separação conceitual
Distinguir:

* Raça.
* Cultura.
* Nacionalidade.
* Religião.
* Condição econômica.
* Cidadania.
* Leis.
* Preconceitos individuais.

12.2 Comportamento social
Diferenças culturais e tensões podem afetar:

* Confiança.
* Emprego.
* Comércio.
* Acesso a locais.
* Fiscalização.
* Relações.
* Diplomacia.
* Conflitos.

12.3 Regras
Não determinar automaticamente a moralidade de um personagem pela raça.
12.4 Mudanças históricas
Leis e relações entre povos podem evoluir conforme acontecimentos e decisões políticas.
13. PARTY E COMPANHEIROS
13.1 Formação
Permitir recrutar NPCs para viajar e atuar com o jogador.
13.2 Requisitos
Recrutamento depende de:

* Relações.
* Objetivos.
* Recursos.
* Confiança.
* Pagamento.
* Disponibilidade.
* Compatibilidade.

13.3 Autonomia
Companheiros devem possuir personalidade, necessidades e capacidade de discordar.
13.4 Modos mecânicos
Separar:
Parceiros oficiais T20: mecânicas correspondentes ao sistema-base.
Party tática homebrew: controle e coordenação ampliados.
Evitar duplicação de benefícios.
13.5 Ordens
Prever:

* Seguir.
* Defender.
* Atacar.
* Recuar.
* Proteger.
* Apoiar.
* Manter posição.

14. GUILDAS E ORGANIZAÇÕES DO JOGADOR
14.1 Criação
Permitir criar organizações mediante requisitos coerentes.
14.2 Estrutura
Uma guilda poderá possuir:

* Nome.
* Sede.
* Liderança.
* Membros.
* Recursos.
* Contratos.
* Reputação.
* Salários.
* Patrimônio.
* Regras internas.

14.3 Desenvolvimento
Guildas poderão:

* Crescer.
* Especializar-se.
* Competir.
* Formar alianças.
* Dividir-se.
* Falir.
* Dissolver-se.
* Influenciar a política.

14.4 Progressão organizacional
Uma guilda pode adquirir influência regional ou política, mas isso não deve ser uma evolução automática ou obrigatória.
15. PROFISSÕES E CARREIRAS
15.1 Objetivo
Permitir formas de vida que não dependam exclusivamente de combate.
15.2 Exemplos

* Mineiro.
* Ferreiro.
* Agricultor.
* Mercador.
* Artesão.
* Guarda.
* Caçador.
* Explorador.
* Pesquisador.
* Mercenário.
* Aventureiro.
* Administrador.

15.3 Mecânicas
Profissões podem envolver:

* Ferramentas.
* Materiais.
* Conhecimentos.
* Contratos.
* Clientes.
* Salários.
* Produtos.
* Reputação profissional.

15.4 Progressão
Distinguir familiaridade profissional homebrew da progressão oficial por nível.
16. MAGIA E RELIGIÃO
16.1 Fundamento
Magia e religião devem influenciar tanto a jogabilidade quanto a sociedade.
16.2 Integrações
Permitir efeitos sobre:

* Combate.
* Cura.
* Agricultura.
* Economia.
* Política.
* Investigação.
* Defesa.
* Exploração.
* Relações sociais.

16.3 Instituições religiosas
Templos e organizações religiosas podem possuir:

* Recursos.
* Lideranças.
* Objetivos.
* Seguidores.
* Influência.
* Conflitos.
* Serviços.

16.4 Fidelidade
Utilizar divindades e conceitos oficiais de Arton.
Não criar regras religiosas novas apresentando-as como conteúdo oficial.
17. A TORMENTA
17.1 Papel
A Tormenta será uma ameaça sobrenatural real e relevante, mas não uma missão principal obrigatória.
17.2 Variáveis
Separar:

* Pressão sobrenatural.
* Vulnerabilidade regional.
* Corrupção efetiva.

17.3 Causalidade
Crises econômicas ou políticas não geram Tormenta automaticamente.
O avanço depende de causas sobrenaturais plausíveis.
17.4 Evolução conceitual
Estados possíveis:

1. Estabilidade.
2. Presságios.
3. Infiltração.
4. Crise.
5. Devastação.

Esses estados são abstrações de simulação, não regras oficiais de áreas de Tormenta.
17.5 Consequências

* Criaturas.
* Cultos.
* Desaparecimentos.
* Alterações ambientais.
* Refugiados.
* Interrupção comercial.
* Conflitos políticos.
* Devastação.

17.6 Reação do mundo
NPCs, aventureiros, templos, governos e organizações podem reagir independentemente do jogador.
17.7 Contenção
Permitir enfrentamento, prevenção e recuperação quando coerentes.
Não criar um sistema de destruição global inevitável.
18. MISSÕES EMERGENTES
18.1 Origem
Missões poderão surgir de:

* Necessidades.
* Crises.
* Dívidas.
* Crimes.
* Rivalidades.
* Escassez.
* Oportunidades.
* Política.
* Magia.
* Tormenta.

18.2 Dados
Cada missão deverá possuir:

* Causa.
* Objetivo.
* Participantes.
* Contexto.
* Recompensa.
* Restrições.
* Possíveis resultados.
* Consequências.

18.3 Soluções
Permitir diferentes abordagens quando apropriado:

* Combate.
* Negociação.
* Investigação.
* Furtividade.
* Pagamento.
* Ajuda de terceiros.
* Abandono.

18.4 Integração
A conclusão ou falha deve modificar o mundo quando houver consequências relevantes.
19. HOME BREWS
19.1 Política
Homebrews serão módulos identificados e documentados.
19.2 Categorias

* Ações contextuais em combate.
* Progressão profissional limitada.
* Party tática.
* Ferimentos narrativos.
* Relações sociais ampliadas.
* Administração de propriedades.
* Gestão de organizações.

19.3 Validação
Cada homebrew deverá possuir:

* Descrição.
* Objetivo.
* Dependências.
* Regras.
* Limites.
* Testes.
* Impacto no balanceamento.

19.4 Compatibilidade
Não modificar silenciosamente regras oficiais.
20. CRÔNICAS DO MUNDO
20.1 Objetivo
Registrar a história emergente da partida.
20.2 Eventos

* Guerras.
* Crises.
* Construções.
* Mortes importantes.
* Mudanças políticas.
* Descobertas.
* Atividades de guildas.
* Acontecimentos mágicos.
* Ameaças sobrenaturais.
* Feitos do jogador.

20.3 Conhecimento
Distinguir:

* Verdade do mundo.
* Conhecimento do jogador.
* Rumores.
* Notícias.
* Registros históricos.

20.4 Divulgação
Informações podem circular por:

* Mensageiros.
* Comerciantes.
* Viajantes.
* Taverneiros.
* Editais.
* Cartas.
* Organizações.

Não revelar informações secretas automaticamente.
21. MODELO DE DADOS
21.1 Entidades conceituais

* WorldState
* WorldAgent
* AgentNeed
* AgentGoal
* AgentMemory
* Relationship
* ReputationRecord
* WorldEvent
* RegionState
* CityState
* MarketState
* TradeRoute
* FactionState
* GuildState
* PartyState
* OriginBackground
* PrologueTemplate
* StartState
* TormentaRegionState
* HistoricalRecord

Esses nomes são referências conceituais.
Adaptar à arquitetura e às convenções do projeto existente.
21.2 Requisitos

* IDs estáveis.
* Dados serializáveis.
* Versionamento.
* Validação.
* Integridade referencial.
* Migração.
* Separação entre estado e apresentação.

21.3 Eventos
Registrar:

* Identificador.
* Tipo.
* Momento.
* Região.
* Participantes.
* Causa.
* Efeitos.
* Visibilidade.
* Estado de processamento.

22. DESEMPENHO E SIMULAÇÃO ESCALÁVEL
22.1 Frequências
Alta frequência: agentes próximos, interações e combate.
Média frequência: atividades locais, trabalho e comércio.
Baixa frequência: regiões distantes, facções, economia e mudanças históricas.
22.2 Simulação abstrata
Não executar movimentação detalhada de NPCs em regiões distantes quando resultados agregados forem suficientes.
22.3 Processamento
Evitar:

* Varreduras globais constantes.
* Eventos duplicados.
* Sistemas sem consumidores.
* Atualizações gráficas de entidades invisíveis.
* IA generativa por NPC.
* Cálculos redundantes.

22.4 Estabilidade
Testar simulações prolongadas.
O mundo deve poder prosperar, entrar em crise e se recuperar.
23. ROADMAP DE IMPLEMENTAÇÃO
Fase 0 — Auditoria

* Inspecionar repositório.
* Executar testes.
* Verificar persistência.
* Identificar módulos existentes.
* Identificar duplicações.
* Mapear dependências.
* Definir prioridades.

Fase 1 — Objetivos dos NPCs

* Necessidades.
* Objetivos.
* Decisões.
* Mudanças de comportamento.
* Persistência.

Fase 2 — Sociedade

* Memórias.
* Relações.
* Reputação.
* Rumores.
* Consequências sociais.

Fase 3 — Prólogo Vivo

* Questionário.
* Históricos.
* Estado inicial.
* Vínculos.
* Profissões.
* Destino aleatório.

Fase 4 — Economia

* Mercadorias.
* Produção.
* Consumo.
* Comércio.
* Preços.
* Crises.
* Recuperação.

Fase 5 — Cidades e facções

* Desenvolvimento.
* Decadência.
* Organizações.
* Política.
* Liderança.
* Sucessão.

Fase 6 — Party e guildas

* Recrutamento.
* Companheiros.
* Ordens.
* Contratos.
* Administração.

Fase 7 — Magia e Tormenta

* Efeitos sistêmicos.
* Incidentes.
* Ameaças.
* Contenção.
* Consequências regionais.

Fase 8 — Homebrews

* Combate contextual.
* Party tática.
* Profissões ampliadas.
* Regras opcionais.

Fase 9 — História e integração

* Diário do mundo.
* Notícias.
* Eventos históricos.
* Testes integrados.
* Balanceamento.
* Otimização.

As fases deverão ser reconciliadas com o estado real do código e com CDA-GAME-002.
24. VERTICAL SLICE PRINCIPAL
Cenário: A oficina do aprendiz

1. Um aprendiz deseja abrir sua oficina.
2. Trabalha para reunir dinheiro.
3. Precisa comprar materiais.
4. Uma caravana deixa de entregar recursos.
5. Os preços aumentam.
6. O aprendiz reconsidera suas prioridades.
7. O jogador pode ajudá-lo, negociar, investigar, roubar ou ignorar.
8. NPCs reagem conforme suas relações e conhecimentos.
9. O comércio local sofre consequências.
10. A situação pode melhorar ou piorar.
11. O acontecimento é registrado.
12. O estado persiste após salvar e carregar.

Critério de sucesso
A demonstração deve provar que objetivos pessoais, economia, relações, decisões e persistência funcionam juntos.
25. TESTES DE ACEITAÇÃO
A — Históricos diferentes
Personagens mecanicamente semelhantes começam em condições sociais distintas.
B — Destino aleatório
Sementes produzem inícios válidos e reproduzíveis.
C — NPC autônomo
Um NPC identifica uma necessidade, toma uma decisão e executa uma ação.
D — Reputação contextual
Uma ação produz interpretações diferentes entre comunidades.
E — Escassez
Uma interrupção comercial altera estoques, preços e decisões.
F — Recuperação
Uma comunidade pode recuperar-se de uma crise sem intervenção obrigatória do jogador.
G — Organização
Uma guilda continua funcionando quando um membro importante sai.
H — Tormenta
Uma ameaça sobrenatural provoca efeitos coerentes e pode encontrar resistência.
I — Persistência
Salvar e carregar preserva relações, economia, eventos e objetivos.
J — Simulação prolongada
O mundo permanece funcional após longos períodos de simulação.
26. CRITÉRIOS DE QUALIDADE
Cada sistema deverá:

1. Funcionar no jogo real.
2. Possuir dados válidos.
3. Integrar-se aos sistemas dependentes.
4. Persistir corretamente.
5. Passar em testes relevantes.
6. Não produzir regressões críticas.
7. Possuir ferramentas mínimas de depuração.
8. Apresentar consequências observáveis.
9. Respeitar o desempenho disponível.
10. Possuir documentação técnica suficiente.

Não considerar uma funcionalidade concluída apenas porque existem classes, interfaces ou testes isolados.
27. REGRAS DE DESENVOLVIMENTO PARA CLAUDE

1. Não reconstruir o jogo sem necessidade.
2. Não criar módulos duplicados.
3. Não ampliar mapas antes de consolidar sistemas fundamentais.
4. Não criar NPCs em massa sem comportamento significativo.
5. Não depender de IA generativa para simulação básica.
6. Não confundir regras oficiais com homebrews.
7. Não implementar todos os sistemas simultaneamente.
8. Não criar versões distribuíveis para cada pequena alteração.
9. Não repetir diagnósticos indefinidamente.
10. Não declarar funcionalidades completas sem validação.
11. Não realizar gastos externos sem autorização.
12. Não interromper o trabalho por decisões técnicas rotineiras.
13. Registrar bloqueios reais e continuar em tarefas independentes.
14. Preservar a compatibilidade de salvamentos sempre que possível.
15. Priorizar experiências jogáveis e consequências perceptíveis.

28. PRIMEIRA AÇÃO OBRIGATÓRIA
Claude deverá executar:
ETAPA 1 — Auditoria real
Comparar este documento com o repositório existente.
Classificar os requisitos em:

* Implementado e validado.
* Parcial.
* Implementado sem integração.
* Ausente.
* Bloqueado.
* Adiado.

ETAPA 2 — Plano técnico
Definir módulos, contratos, dependências, migrações e critérios de aceitação.
ETAPA 3 — Implementação inicial
Priorizar objetivos e necessidades dos NPCs.
ETAPA 4 — Integração
Conectar objetivos, memórias, relações e acontecimentos.
ETAPA 5 — Prova jogável
Demonstrar o vertical slice da oficina do aprendiz.
ETAPA 6 — Continuidade
Prosseguir pelo roadmap, conciliando este documento com CDA-GAME-002.
29. DEFINIÇÃO DE SUCESSO
Crônicas de Arton será bem-sucedido quando o jogador puder criar um personagem com passado próprio e encontrar um mundo que:

* Possui pessoas com objetivos.
* Guarda memórias.
* Reage às decisões.
* Apresenta oportunidades variadas.
* Permite diferentes carreiras.
* Possui economia e política próprias.
* Evolui independentemente do jogador.
* Produz histórias emergentes.
* Oferece ameaças e conflitos coerentes.
* Permite trajetórias pacíficas ou violentas.
* Continua funcionando após acontecimentos importantes.

A complexidade deve produzir possibilidades, não confusão.
A liberdade deve produzir consequências, não ausência de direção.
A simulação deve servir à experiência do jogador.
CRÔNICAS DE ARTON: UM MUNDO QUE VIVE, COM OU SEM VOCÊ.
Fim do documento CDA-WORLD-001 v2.0.

esse é para complementar a meta de goal