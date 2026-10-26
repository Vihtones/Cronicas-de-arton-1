# CRÔNICAS DE ARTON
## DOCUMENTO MESTRE DE ENGENHARIA DE JOGO
### Projeto de Expansão: ARTON VIVA

**Identificador:** CDA-WORLD-001  
**Versão da especificação:** 1.0  
**Data:** 25/10/2026  
**Projeto:** Crônicas de Arton  
**Sistema-base:** Tormenta20  
**Estado de referência:** Desenvolvimento 0.7.1  
**Destinatário:** Claude, responsável pelo desenvolvimento do projeto existente  
**Natureza:** Especificação técnica, arquitetura, game design e plano de implementação

---

# 0. INSTRUÇÃO PRINCIPAL AO DESENVOLVEDOR

Você está recebendo uma especificação consolidada para expandir o jogo **Crônicas de Arton**.

O objetivo NÃO é reconstruir o jogo, criar um projeto paralelo ou implementar todos os recursos simultaneamente.

Sua responsabilidade é:

1. Inspecionar a arquitetura e os arquivos reais do projeto.
2. Identificar os sistemas já implementados e preservá-los.
3. Comparar o código com esta especificação.
4. Criar um plano incremental baseado em dependências.
5. Implementar os sistemas necessários por meio de módulos reutilizáveis.
6. Integrá-los à jogabilidade real.
7. Testar, corrigir, documentar e continuar o desenvolvimento.
8. Evitar trabalhos repetitivos e expansão prematura.
9. Não solicitar feedback intermediário para decisões técnicas rotineiras.
10. Não declarar funcionalidades concluídas apenas porque sua estrutura ou seus testes unitários existem.

O projeto deve tornar-se um RPG de mundo aberto, orgânico e persistente, em que o jogador possui liberdade para construir sua própria história e o mundo continua evoluindo independentemente dele.

**Princípio central: o jogador faz parte do mundo, mas não é o centro obrigatório de todos os acontecimentos.**

---

# 1. ESTADO ATUAL DO PROJETO

## 1.1 Informações recebidas

O relatório de desenvolvimento informa:

- Versão em desenvolvimento: 0.7.1.
- Última versão montada internamente: 0.7.0.
- Último executável Windows informado: 0.6.0.
- 191 testes automatizados aprovados.
- Zero violações de arquitetura reportadas.
- Zero apontamentos de estilo reportados.

Esses números são referências fornecidas anteriormente, não evidências verificadas neste documento.

Antes de qualquer alteração, verificar o estado real do repositório, da suíte de testes, dos builds e das funcionalidades.

## 1.2 Sistemas existentes a preservar

Conforme o relatório anterior:

**Combate**
- Correção de exploração de XP por fuga.
- Fantasma do jogador para prévia de ações.
- Implementação de diversos poderes gerais de T20.

**Diálogos**
- Sete registros de voz textual.
- Variação de falas conforme contexto.
- Memória de conversas.
- Conversas sobre rumores, trabalho, clima, eventos e biografias.

**NPCs**
- Humor com medo e alegria.
- Reações à violência.
- Rotinas e atividades.
- Reações a eventos locais.

**Mundo**
- Clima.
- Feira.
- Festas.
- Carroças.
- Estoques.
- Casas.
- Caminhos.
- Figurantes.
- Salvamento persistente.

**Interface**
- HUD.
- Minimapa.
- Atalhos.
- Árvore de poderes.

Esses sistemas deverão ser integrados ao novo núcleo de simulação, evitando duplicações.

## 1.3 Pendências anteriores

Considerar no planejamento:

- Objetivos autônomos dos NPCs.
- Diálogos individuais.
- Consequências sociais.
- Passageiros e assaltos de caravanas.
- Poderes raciais ativos.
- Natação e voo.
- Regras de gênero e casamento.
- Problemas de arte.
- Comandos sem testes.
- Módulos sem suíte própria.
- Regras T20 duplicadas no código.
- Eventos sem consumidores.

**A segunda vila, o segundo mistério e o sistema de viagem entre mapas permanecem pausados como expansão de conteúdo.**

Isso não impede desenvolver desde já um modelo abstrato de regiões conectadas para a economia e a política.

---

# 2. VISÃO DE PRODUTO

## 2.1 Conceito

Crônicas de Arton será um RPG de fantasia baseado em Tormenta20 com:

- Liberdade de trajetória.
- Múltiplos começos.
- Mundo persistente.
- Personagens com objetivos próprios.
- Reputação contextual.
- Relações sociais profundas.
- Economia regional.
- Política e diplomacia.
- Guerras e conflitos.
- Guildas e facções.
- Carreiras alternativas.
- Transformação urbana.
- Magia com consequências no mundo.
- Ameaça progressiva da Tormenta.
- Combate tático e homebrews opcionais.

O jogador poderá ser aventureiro, mercador, artesão, explorador, criminoso, líder de guilda, político, governante ou simplesmente um cidadão comum.

Nenhuma dessas trajetórias será obrigatória.

## 2.2 Pilares de design

### Liberdade com consequências

O jogador pode tentar muitas ações, mas sucesso, dificuldade e consequências dependem do contexto.

### Moralidade não binária

Nenhuma barra universal determina automaticamente se alguém é herói ou vilão.

### Mundo autônomo

NPCs, instituições e cidades agem mesmo sem o jogador.

### Persistência histórica

Acontecimentos importantes deixam vestígios, registros e consequências.

### Coerência sistêmica

Mudanças econômicas, sociais, políticas e sobrenaturais devem compartilhar causas.

### Regras transparentes

Separar mecânicas oficiais de Tormenta20 de expansões homebrew.

### Desempenho

Priorizar simulação estruturada e eficiente, sem depender de IA generativa para cada NPC.

### Rejogabilidade

Históricos diferentes devem produzir experiências iniciais e trajetórias distintas.

---

# 3. ARQUITETURA CENTRAL: ARTON VIVA

## 3.1 Novo núcleo

Criar um módulo de domínio chamado:

**World Simulation Core — Arton Viva**

Esse módulo será o responsável por processar os estados e eventos do mundo.

Não criar um simulador completamente separado para cada sistema.

## 3.2 Domínios integrados

Os domínios previstos são:

1. Identidade e histórico.
2. NPCs e decisões.
3. Necessidades e objetivos.
4. Relacionamentos.
5. Moralidade e reputação.
6. Economia.
7. Cidades e infraestrutura.
8. Facções e política.
9. Guildas e companheiros.
10. Magia e religião.
11. Corrupção da Tormenta.
12. Missões e oportunidades.
13. História e notícias.
14. Criação de personagem e prólogo.
15. Combate e progressão.

Cada domínio terá interfaces e responsabilidades claras.

## 3.3 Fluxo lógico

Estado do mundo  
→ acontecimentos  
→ percepção dos agentes  
→ decisões  
→ ações  
→ consequências  
→ atualização econômica, social e política  
→ persistência  
→ novos acontecimentos.

A simulação não poderá depender da interface gráfica para tomar decisões.

## 3.4 Regras obrigatórias

- Toda alteração persistente deve possuir origem identificável.
- Eventos devem ter identificadores únicos.
- Sistemas consumidores devem receber somente eventos relevantes.
- Alterações devem ser reproduzíveis a partir dos dados e sementes utilizados.
- Processamento de um evento não deve produzir duplicações acidentais.
- Salvamento e carregamento devem conservar resultados.
- Falhas não podem corromper estados anteriores.
- O sistema deve suportar migração de dados entre versões.

---

# 4. SISTEMA DE AGENTES DO MUNDO

## 4.1 Entidade comum

Criar ou adaptar um modelo compartilhado chamado `WorldAgent`.

Aplicável a:

- Jogador.
- Moradores.
- Comerciantes.
- Guardas.
- Aventureiros.
- Mercenários.
- Nobres.
- Criminosos.
- Líderes.
- Companheiros.

Não assumir que todos necessitam do mesmo nível de simulação.

## 4.2 Dados principais

Cada agente poderá armazenar:

- ID persistente.
- Nome.
- Raça.
- Classe.
- Nível.
- Idade e estágio de vida, quando aplicável.
- Profissão.
- Localização.
- Residência.
- Família.
- Organizações.
- Recursos.
- Inventário.
- Necessidades.
- Estado emocional.
- Personalidade.
- Valores.
- Objetivos.
- Habilidades.
- Memórias.
- Relações.
- Reputações conhecidas.
- Condição legal.
- Estado de saúde.
- Eventos relevantes de vida.

Nem todos os campos precisarão ser preenchidos para figurantes simples.

## 4.3 Personalidade

Utilizar dimensões como:

- Coragem.
- Ambição.
- Empatia.
- Disciplina.
- Sociabilidade.
- Prudência.
- Ganância.
- Lealdade.
- Curiosidade.
- Tolerância ao risco.

Essas dimensões influenciam decisões, mas não determinam comportamentos de forma absoluta.

## 4.4 Necessidades

Exemplos:

- Alimentação.
- Descanso.
- Segurança.
- Dinheiro.
- Pertencimento.
- Saúde.
- Reconhecimento.
- Estabilidade.
- Propósito.

As necessidades devem ser atualizadas conforme atividades e acontecimentos.

## 4.5 Objetivos

Separar:

**Curto prazo:** comprar alimentos, procurar emprego, descansar.

**Médio prazo:** quitar dívida, aprender ofício, melhorar residência.

**Longo prazo:** fundar negócio, tornar-se capitão, viajar, formar família, conquistar poder.

Um NPC pode abandonar, substituir ou adiar seus objetivos.

## 4.6 Decisão autônoma

Implementar uma abordagem de utilidade, regras contextuais ou arquitetura equivalente.

A decisão deve considerar:

- O que o agente deseja.
- O que ele sabe.
- O que consegue fazer.
- O que acredita ser perigoso.
- Seus vínculos.
- Suas oportunidades.
- Seus recursos.
- Leis e restrições.
- Consequências prováveis.

Evitar IA generativa contínua.

## 4.7 Evolução de NPCs

Personagens podem:

- Ganhar experiência.
- Aprender profissões.
- Treinar habilidades.
- Mudar de classe quando permitido.
- Melhorar equipamentos.
- Prosperar economicamente.
- Falir.
- Formar organizações.
- Migrar.
- Envelhecer.
- Abandonar objetivos.
- Estagnar.
- Sofrer mudanças de personalidade.

A progressão deve estar relacionada a atividades, oportunidades e regras válidas.

Evitar crescimento automático ilimitado.

---

# 5. MEMÓRIA E RELACIONAMENTOS

## 5.1 Memória social

NPCs devem lembrar acontecimentos relevantes, incluindo:

- Ajuda.
- Traição.
- Resgate.
- Violência.
- Dívidas.
- Promessas.
- Contratos.
- Conflitos.
- Afeto.
- Rivalidade.
- Favores.
- Abandono.
- Perdas familiares.

Memórias podem perder importância, mas fatos históricos relevantes não devem desaparecer arbitrariamente.

## 5.2 Relações multidimensionais

Evitar uma única barra de relacionamento.

Utilizar dimensões como:

- Confiança.
- Afeto.
- Respeito.
- Medo.
- Ressentimento.
- Admiração.
- Lealdade.
- Interesse.
- Familiaridade.

Exemplo: um guarda pode respeitar o jogador, mas não confiar nele.

## 5.3 Relações possíveis

- Conhecido.
- Amigo.
- Rival.
- Mentor.
- Aprendiz.
- Empregador.
- Funcionário.
- Companheiro.
- Familiar.
- Interesse romântico.
- Parceiro.
- Inimigo.

Relações não são necessariamente exclusivas.

## 5.4 Interação universal

Qualquer NPC com capacidade social adequada poderá participar dos sistemas gerais de interação.

Porém, isso não significa que todo NPC aceitará:

- Romance.
- Recrutamento.
- Casamento.
- Moradia conjunta.
- Emprego.
- Convites.
- Ordens.

Essas possibilidades dependerão de idade, consentimento, personalidade, interesses, situação e relações existentes.

Romances e casamentos devem envolver apenas personagens adultos e consentimento mútuo.

## 5.5 Família

Familiares serão agentes reais.

Devem possuir:

- Residência.
- Relações.
- Atividades.
- Necessidades.
- Memórias.
- Objetivos.
- Possibilidade de mudança de vida.

Evitar família criada apenas como texto decorativo.

---

# 6. MORALIDADE, KARMA E REPUTAÇÃO

## 6.1 Modelo não binário

Não criar uma única escala universal de bem versus mal.

Separar três conceitos:

**Moralidade contextual:** natureza e consequências das ações.

**Reputação:** crenças que grupos e indivíduos possuem sobre o jogador.

**Karma e espiritualidade:** consequências ligadas a crenças, divindades, juramentos e fenômenos pertinentes ao cenário.

## 6.2 Registro de ações

Uma ação importante poderá possuir:

- Autor.
- Alvo.
- Local.
- Data.
- Testemunhas.
- Consequências.
- Justificativa declarada.
- Contexto.
- Conhecimento público.
- Legalidade local.
- Avaliações por facção.

O sistema não deve presumir conhecer intenções ocultas sem fundamento.

## 6.3 Reputação localizada

Reputação por:

- NPC.
- Família.
- Comunidade.
- Cidade.
- Guilda.
- Facção.
- Reino.
- Instituição religiosa.

Ser reconhecido como herói em uma cidade não obriga outra cidade a concordar.

## 6.4 Rumores

Informações devem se espalhar por relações sociais, comerciantes, viajantes, cartas e organizações.

Rumores podem ser:

- Verdadeiros.
- Incompletos.
- Exagerados.
- Falsos.
- Desatualizados.

O jogador pode contestar rumores ou produzir novas evidências.

## 6.5 Crimes e violência

O jogador pode atacar, matar ou capturar NPCs dentro das regras do jogo.

As consequências incluem:

- Investigações.
- Testemunhas.
- Luto.
- Vingança.
- Recompensas.
- Mudança de liderança.
- Medo.
- Fuga.
- Resistência.
- Efeitos econômicos e políticos.

Personagens importantes não serão automaticamente imortais.

Quando uma função institucional for indispensável ao funcionamento do mundo, deve existir mecanismo de sucessão.

---

# 7. SISTEMA ECONÔMICO REGIONAL

## 7.1 Objetivo

Criar uma economia interligada, em que decisões e acontecimentos de uma região afetem outras.

## 7.2 Entidades

- Reino.
- Região.
- Cidade.
- Mercado.
- Estabelecimento.
- Produtor.
- Consumidor.
- Caravana.
- Rota comercial.
- Contrato.
- Mercadoria.

## 7.3 Variáveis principais

- Produção.
- Consumo.
- Estoque.
- Capacidade produtiva.
- Salários.
- Desemprego.
- Demanda.
- Oferta.
- Custos logísticos.
- Risco comercial.
- Impostos.
- Renda.
- Poupança.
- Tesouro.
- Circulação monetária.

## 7.4 Preços

Os preços deverão variar por:

- Produto.
- Cidade.
- Disponibilidade.
- Demanda.
- Transporte.
- Impostos.
- Segurança.
- Situação política.
- Acontecimentos extraordinários.

Estabelecer limites graduais, amortecimento e mecanismos de recuperação para evitar oscilações absurdas.

## 7.5 Inflação

Distinguir:

- Escassez localizada.
- Inflação geral.
- Choque de custos.
- Crise de abastecimento.
- Desvalorização monetária, quando aplicável.

Não tratar toda alta de preço como inflação monetária.

## 7.6 Interdependência regional

Exemplo de teste obrigatório:

Uma guerra bloqueia uma estrada.

Consequências esperadas:

1. Menos entregas.
2. Estoques reduzidos.
3. Preços ajustados.
4. Mudanças nos hábitos de compra.
5. Alterações de humor e necessidades.
6. Novos contratos de escolta.
7. Mudanças nas decisões de comerciantes.
8. Possíveis rotas alternativas.
9. Recuperação quando o comércio for restabelecido.

## 7.7 Economia sem jogador

Comerciantes, produtores e instituições devem atuar autonomamente.

O jogador pode participar da economia, mas não ser responsável pela existência dela.

---

# 8. CIDADES DINÂMICAS

## 8.1 Estado urbano

Cada cidade possuirá indicadores como:

- População.
- Prosperidade.
- Segurança.
- Abastecimento.
- Saúde.
- Moradia.
- Infraestrutura.
- Comércio.
- Influência política.
- Estabilidade.
- Satisfação social.
- Ameaças externas.

## 8.2 Desenvolvimento

Permitir:

- Construção de novas casas.
- Reformas.
- Expansão de mercados.
- Oficinas.
- Fortificações.
- Estradas.
- Armazéns.
- Templos.
- Edifícios administrativos.

## 8.3 Decadência

Permitir:

- Abandono.
- Incêndios.
- Falências.
- Destruição.
- Insegurança.
- Migração.
- Ruínas.
- Redução de serviços.
- Mudanças no poder local.

## 8.4 Consequências visuais

O estado urbano deve alterar o cenário quando existir suporte gráfico.

Não considerar o sistema completo se apenas números mudarem.

Permitir representações temporárias de desenvolvimento, desde que claramente identificadas como provisórias.

## 8.5 Recuperação

Cidades devem poder se recuperar sem participação obrigatória do jogador.

Exemplos:

- Reconstrução.
- Novos contratos.
- Investimento.
- Auxílio religioso.
- Novas rotas.
- Migração.
- Negociações.

Evitar decadência irreversível causada apenas pelo avanço do tempo.

---

# 9. POLÍTICA E FACÇÕES

## 9.1 Entidades políticas

- Família real.
- Casas nobres.
- Governos locais.
- Organizações militares.
- Guildas.
- Instituições religiosas.
- Movimentos populares.
- Facções criminosas.
- Grupos culturais e regionais.

## 9.2 Propriedades das facções

- Objetivos.
- Ideologia.
- Recursos.
- Liderança.
- Membros.
- Patrimônio.
- Território.
- Influência.
- Alianças.
- Rivalidades.
- Conduta.
- Relação com leis e instituições.

## 9.3 Comportamentos

Facções podem:

- Negociar.
- Financiar projetos.
- Recrutar.
- Investigar.
- Contratar.
- Proteger.
- Atacar.
- Formar alianças.
- Romper alianças.
- Declarar guerra.
- Controlar propriedades.
- Buscar influência política.

## 9.4 Conquista de cidades

O jogador poderá tentar conquistar ou assumir uma cidade através de:

- Força militar.
- Golpe político.
- Apoio popular.
- Acordo diplomático.
- Sucessão.
- Compra ou concessão de direitos, quando plausível.

A conquista não deverá garantir automaticamente governabilidade.

## 9.5 Administração

Controlar uma cidade poderá exigir:

- Segurança.
- Abastecimento.
- Impostos.
- Infraestrutura.
- Relações diplomáticas.
- Controle institucional.
- Gestão de crises.
- Legitimidade.
- Defesa territorial.

## 9.6 Sucessão

Se um líder morrer, fugir ou perder poder, a organização deverá buscar sucessão conforme suas regras.

Evitar facções incapazes de funcionar porque um único NPC desapareceu.

---

# 10. IDENTIDADE RACIAL, CULTURA E PRECONCEITO

## 10.1 Separação de conceitos

Distinguir:

- Raça e características mecânicas.
- Cultura.
- Religião.
- Cidadania.
- Condição social.
- Leis regionais.
- Preconceitos individuais.
- Discriminação institucional.

Não inferir a moralidade ou personalidade de alguém exclusivamente pela raça.

## 10.2 Contexto de Hudra

Preservar o cenário já estabelecido:

- Conflitos entre humanos e elfos.
- Proibições e perseguições regionais.
- Tensões envolvendo goblinoides e orcs.
- Disputas entre família real e nobreza.
- Diferenças culturais e religiosas entre regiões.

## 10.3 Consequências possíveis

- Restrições de entrada.
- Desconfiança.
- Fiscalização.
- Dificuldade de trabalho.
- Apoio comunitário.
- Solidariedade.
- Alianças.
- Movimentos políticos.
- Mudança de leis.
- Conflitos sociais.

## 10.4 Transformação histórica

Preconceitos e leis poderão mudar conforme acontecimentos, lideranças, relações e conflitos.

Evitar que sociedades sejam completamente estáticas.

---

# 11. SISTEMA DE PARTY, GUILDAS E FACÇÕES DO JOGADOR

## 11.1 Party

Permitir formar um grupo de aventura com personagens recrutados.

Os integrantes devem possuir:

- Objetivos pessoais.
- Personalidade.
- Relações.
- Inventário.
- Função em combate.
- Lealdade.
- Necessidades.
- Capacidade de discordar.

## 11.2 Recrutamento

Recrutamento dependerá de:

- Confiança.
- Interesses.
- Pagamento.
- Disponibilidade.
- Obrigações.
- Segurança.
- Afinidade.
- Histórico.

Não permitir controle mental implícito sobre NPCs apenas por reputação alta.

## 11.3 Combate em equipe

Prever dois modos:

**Modo Parceiro T20:** suporte segundo as mecânicas oficiais pertinentes.

**Modo Party Tática:** expansão homebrew com posicionamento, ações, ordens e combate coordenado.

Não misturar os dois modelos de forma a conceder benefícios duplicados.

## 11.4 Ordens possíveis

- Seguir.
- Proteger.
- Atacar alvo.
- Manter posição.
- Recuar.
- Curar.
- Apoiar.
- Defender área.

## 11.5 Guilda

Uma party poderá criar uma guilda quando cumprir requisitos plausíveis.

A guilda deverá possuir:

- Nome.
- Sede.
- Liderança.
- Membros.
- Recursos.
- Salários.
- Contratos.
- Reputação.
- Patrimônio.
- Regras internas.

## 11.6 Facção

Guildas e outros grupos poderão evoluir para organizações políticas ou militares.

A evolução não será obrigatória nem necessariamente linear.

Também permitir:

- Dissolução.
- Expulsões.
- Cisões.
- Fusões.
- Lideranças rivais.
- Mudanças de finalidade.

---

# 12. CARREIRAS E PROFISSÕES

## 12.1 Liberdade de profissão

O jogador poderá seguir atividades como:

- Aventureiro.
- Mineiro.
- Ferreiro.
- Mercador.
- Guarda.
- Caçador.
- Artesão.
- Agricultor.
- Explorador.
- Mercenário.
- Pesquisador.
- Criminoso.
- Líder de guilda.
- Governante.

Outras profissões poderão ser adicionadas por dados.

## 12.2 Progressão profissional

Profissões poderão possuir:

- Ferramentas.
- Conhecimentos.
- Clientes.
- Contratos.
- Reputação.
- Rotinas.
- Materiais.
- Técnicas.
- Oportunidades.

Evitar tarefas repetitivas infinitas como única forma de evolução.

## 12.3 Integração com T20

A progressão por nível e os poderes oficiais continuarão separados da familiaridade profissional homebrew.

Profissões não devem oferecer crescimento irrestrito de poder de combate.

---

# 13. MAGIA E RELIGIÃO

## 13.1 Integração oficial

Implementar regras autorizadas e aplicáveis de:

- Magias.
- Poderes.
- Condições.
- Resistências.
- Aprimoramentos.
- Escolas ou classificações pertinentes.
- Interações divinas.
- Recursos mágicos.

As regras oficiais deverão possuir fonte, versão e dados centralizados.

## 13.2 Consequências sistêmicas

A magia poderá afetar:

- Saúde.
- Economia.
- Agricultura.
- Infraestrutura.
- Defesa.
- Política.
- Religião.
- Investigação.
- Crimes.
- Exploração.

## 13.3 Ganchos narrativos

Exemplos:

- Desaparecimento de conjuradores.
- Maldição numa colheita.
- Artefato perigoso.
- Disputa entre templos.
- Serviço mágico fraudulento.
- Pesquisa proibida.
- Fenômeno sobrenatural regional.

As oportunidades devem derivar do estado do mundo sempre que possível.

---

# 14. CORRUPÇÃO PERSISTENTE DA TORMENTA

## 14.1 Papel no jogo

A Tormenta será uma ameaça real, progressiva e regional.

Não será necessariamente o objetivo principal da campanha.

O jogador poderá ignorá-la por algum tempo, combatê-la, investigá-la ou contribuir indiretamente para crises.

## 14.2 Três variáveis distintas

**Pressão sobrenatural:** atividade da ameaça numa região.

**Vulnerabilidade:** capacidade reduzida de responder a incursões, cultos e crises.

**Corrupção efetiva:** transformação real do ambiente e de criaturas.

Pobreza, guerra e instabilidade não geram Tormenta automaticamente.

O avanço exige causas sobrenaturais coerentes com Arton.

## 14.3 Estágios conceituais

0. Estabilidade.
1. Presságios.
2. Infiltração.
3. Crise sobrenatural.
4. Devastação regional.

Esses estágios são abstrações homebrew e não substituem regras oficiais de áreas de Tormenta.

## 14.4 Consequências

- Desaparecimentos.
- Cultos.
- Criaturas aberrantes.
- Alterações ambientais.
- Refugiados.
- Interrupção comercial.
- Crises políticas.
- Contratos extraordinários.
- Transformações de mapas.
- Destruição localizada.

## 14.5 Contenção

Permitir:

- Investigações.
- Defesas.
- Resgates.
- Proteção de rotas.
- Intervenções mágicas pertinentes.
- Enfrentamento de cultos.
- Recuperação parcial de regiões, quando narrativamente plausível.

Cidades e facções podem atuar sem o jogador.

## 14.6 Balanceamento

Evitar expansão automática inevitável que destrua todas as cidades.

A ameaça deverá produzir tensão, não tornar todas as outras carreiras irrelevantes.

---

# 15. PRÓLOGO VIVO: ORIGENS E DESTINOS

## 15.1 Objetivo

Permitir que o jogador comece em situações sociais, econômicas, geográficas e pessoais muito diferentes.

O começo não será idêntico em todas as partidas.

## 15.2 Separação obrigatória

**Origem oficial T20:** elemento mecânico da ficha.

**Histórico do Prólogo Vivo:** elemento narrativo e sistêmico adicional.

Não substituir benefícios oficiais nem conceder bônus mecânicos incompatíveis sem regra homebrew explícita.

## 15.3 Questionário inicial

Criar um questionário curto e opcional, com temas:

### Pergunta A — Onde você cresceu?

- Grande cidade.
- Vila rural.
- Região selvagem.
- Estradas.
- Comunidade isolada.
- Outra região permitida.

### Pergunta B — Qual era sua condição econômica?

- Pobreza.
- Trabalhador comum.
- Família estável.
- Família próspera.
- Ligação com nobreza.
- Sem residência ou recursos permanentes.

### Pergunta C — Quais são seus vínculos?

- Família próxima.
- Mentor.
- Comunidade.
- Amigos.
- Grupo de trabalho.
- Nenhum vínculo conhecido.

### Pergunta D — Como você vivia?

- Mineiro.
- Artesão.
- Mercador.
- Trabalhador rural.
- Viajante.
- Nômade.
- Cativo.
- Herdeiro.
- Aprendiz.
- Outra profissão válida.

### Pergunta E — O que aconteceu recentemente?

- Nada extraordinário.
- Perda importante.
- Nova oportunidade.
- Perseguição.
- Dívida.
- Mudança de residência.
- Conflito familiar.
- Descoberta inesperada.

### Pergunta F — Como você quer começar?

- Em casa.
- No trabalho.
- Numa estrada.
- Em viagem.
- Num acampamento.
- Sob custódia.
- Procurando emprego.
- Em outro contexto coerente.

Evitar perguntas redundantes ou combinações impossíveis.

## 15.4 Gerador de estado inicial

As respostas devem gerar:

- Região inicial.
- Posição válida no mapa.
- Moradia.
- Inventário.
- Dinheiro.
- Equipamentos.
- Obrigações.
- Possíveis dívidas.
- Contatos pessoais.
- Vínculos familiares.
- Reputação inicial.
- Profissão.
- Objetivos opcionais.
- Oportunidades locais.
- Memórias compartilhadas.

## 15.5 Inícios exemplares

**Mineiro:** local de trabalho, ferramentas, colegas, pagamento e possíveis dívidas.

**Herdeiro:** residência, familiares, obrigações, recursos e relações políticas.

**Cativo:** condições de restrição, pessoas envolvidas e caminhos jogáveis de mudança de situação.

**Nômade:** acampamento, suprimentos, contatos de estrada e liberdade de deslocamento.

**Morador comum:** casa, familiares, emprego e nenhuma missão épica obrigatória.

## 15.6 Persistência

Família, mentor, rival, antigos empregadores e contatos devem ser NPCs reais.

A residência e o trabalho anterior devem existir no mundo.

Esses vínculos devem continuar evoluindo após o jogador partir.

## 15.7 Liberdade

O passado define condições iniciais, não um destino obrigatório.

Um mineiro pode permanecer mineiro.

Um nobre pode abandonar a própria família.

Um nômade pode fundar uma cidade.

Um cativo pode construir uma guilda.

Um aventureiro pode se aposentar.

---

# 16. DEIXAR O DESTINO DECIDIR

## 16.1 Conceito

Adicionar ao criador de personagens a opção:

**“Deixar o Destino Decidir”**

Ela gera automaticamente um histórico de vida coerente e uma situação inicial jogável.

## 16.2 Funcionamento

O gerador deverá:

1. Ler raça, classe e demais opções mecânicas.
2. Consultar regiões e locais disponíveis.
3. Avaliar combinações válidas.
4. Selecionar uma condição social.
5. Selecionar profissão ou situação anterior.
6. Gerar vínculos coerentes.
7. Definir recursos e obrigações.
8. Escolher um ponto inicial válido.
9. Criar ou associar NPCs existentes.
10. Registrar as relações e memórias.
11. Validar jogabilidade.
12. Apresentar um breve resumo do passado.

## 16.3 Semente reproduzível

Permitir geração por semente.

A mesma semente, com os mesmos dados e versões de conteúdo, deverá produzir um resultado equivalente.

Registrar a versão do gerador.

## 16.4 Aleatoriedade ponderada

Não usar combinações completamente uniformes.

A probabilidade de cada situação deverá considerar:

- Região.
- Cultura.
- Condição econômica.
- Disponibilidade de profissões.
- Leis.
- Compatibilidade com a ficha.
- Locais disponíveis.
- Requisitos mínimos de jogabilidade.

## 16.5 Controles opcionais

Oferecer:

- Sorteio completo.
- Sortear apenas histórico.
- Sortear apenas região.
- Preservar algumas escolhas.
- Gerar novamente.
- Aceitar resultado.

## 16.6 Garantias

Nunca gerar:

- Posição inexistente.
- Família referenciada sem NPC.
- Item essencial ausente.
- Condição impossível de resolver.
- Região não jogável apresentada como disponível.
- Situação incompatível com as restrições da ficha.
- Combinação que torne a partida impossível sem aviso.

## 16.7 Prova de conceito

Criar pelo menos três históricos válidos e distintos numa região já jogável.

Verificar diferenças em:

- Local inicial.
- Inventário.
- Relações.
- Residência.
- Trabalho.
- Diálogos.
- Oportunidades.

---

# 17. MISSÕES EMERGENTES

## 17.1 Origem das missões

Missões devem poder surgir de:

- Necessidades.
- Dívidas.
- Perdas.
- Crises.
- Rivalidades.
- Escassez.
- Acidentes.
- Crimes.
- Conflitos políticos.
- Oportunidades comerciais.
- Eventos mágicos.
- Ameaças da Tormenta.

## 17.2 Estrutura

Cada oportunidade deve possuir:

- Causa.
- Contratante.
- Objetivo.
- Contexto.
- Recompensa.
- Restrições.
- Prazo, quando pertinente.
- Soluções possíveis.
- Consequências.

## 17.3 Múltiplas soluções

Uma missão poderá permitir:

- Combate.
- Negociação.
- Investigação.
- Pagamento.
- Furtividade.
- Ajuda de terceiros.
- Abandono.
- Traição.
- Soluções criativas previstas por regras gerais.

Nem toda missão precisa oferecer todas essas soluções.

## 17.4 Consequências

O resultado deve retornar à simulação.

Exemplo: uma missão de escolta bem-sucedida restabelece abastecimento e afeta preços.

---

# 18. HOME BREWS DE JOGABILIDADE

## 18.1 Política

Criar módulos opcionais de regras próprias.

Toda regra deverá possuir:

- Identificador.
- Nome.
- Versão.
- Descrição.
- Justificativa.
- Dependências.
- Impacto esperado.
- Configuração.
- Testes de balanceamento.

## 18.2 Homebrew A — Interação contextual em combate

Permitir, com regras controladas:

- Empurrões.
- Desarmes.
- Cobertura.
- Proteção de aliados.
- Ações ambientais.
- Posicionamento.
- Preparação de ataques.

Preservar testes, ações, limites e condições pertinentes de T20.

## 18.3 Homebrew B — Familiaridade prática

Permitir experiência limitada em atividades profissionais e sociais.

Não substituir progressão oficial de nível.

## 18.4 Homebrew C — Companheiros táticos

Permitir ordens e coordenação em combate, sem duplicar benefícios de parceiros T20.

## 18.5 Homebrew D — Ferimentos narrativos

Ferimentos graves podem produzir efeitos temporários e recuperáveis.

Evitar penalidades permanentes frequentes que destruam o ritmo do jogo.

## 18.6 Homebrew E — Vida social e instituições

Ampliar contratos, negociações, favores, vínculos e administração.

## 18.7 Balanceamento

Criar testes que comparem:

- Regras oficiais.
- Regras homebrew habilitadas.
- Dificuldade de combate.
- Economia.
- Recompensas.
- Progressão.
- Eficiência de habilidades.

Não modificar silenciosamente dados oficiais.

---

# 19. DIÁRIO VIVO DO MUNDO

## 19.1 Objetivo

Criar um registro histórico dos acontecimentos importantes.

## 19.2 Categorias

- Política.
- Economia.
- Guerras.
- Construções.
- Desastres.
- Magia.
- Tormenta.
- Guildas.
- Vida de NPCs.
- Feitos do jogador.

## 19.3 Informação conhecida

Separar:

**Verdade da simulação:** o que aconteceu.

**Conhecimento do jogador:** o que ele descobriu.

**Rumor:** o que circula socialmente.

Não revelar todos os segredos por uma interface onisciente.

## 19.4 Apresentação

Notícias podem chegar por:

- Taverneiros.
- Mercadores.
- Cartas.
- Mensageiros.
- Boatos.
- Editais.
- Guildas.
- Registros oficiais.

## 19.5 Memória histórica

Eventos importantes devem permanecer rastreáveis e influenciar acontecimentos futuros.

---

# 20. MODELO DE DADOS E CONTRATOS

## 20.1 Entidades iniciais

Planejar contratos para:

- `WorldState`
- `WorldAgent`
- `PersonalityProfile`
- `AgentGoal`
- `AgentNeed`
- `AgentMemory`
- `Relationship`
- `ReputationRecord`
- `WorldEvent`
- `RegionState`
- `CityState`
- `MarketState`
- `TradeRoute`
- `FactionState`
- `OrganizationMembership`
- `GuildState`
- `PartyState`
- `MagicIncident`
- `TormentaRegionState`
- `OriginBackground`
- `PrologueTemplate`
- `StartState`
- `HistoricalRecord`

Os nomes são propostas conceituais.

Adaptar à linguagem e às convenções efetivamente existentes no repositório.

## 20.2 Identificadores

Usar IDs persistentes e estáveis.

Evitar identificar personagens apenas pelo nome.

## 20.3 Eventos

Todo evento relevante deve incluir, conforme aplicável:

- ID.
- Tipo.
- Instante de simulação.
- Região.
- Participantes.
- Causa.
- Consequências.
- Fonte.
- Visibilidade.
- Estado de processamento.

## 20.4 Persistência

A migração para novos formatos deve preservar salvamentos existentes sempre que tecnicamente possível.

Realizar backup antes de migrações arriscadas.

## 20.5 Grafo de dependências

Manter relações como:

- Família.
- Amizade.
- Dívida.
- Emprego.
- Facção.
- Território.
- Comércio.
- Contrato.
- Aliança.
- Rivalidade.

Isso permitirá calcular efeitos em cadeia sem duplicar dados.

---

# 21. SIMULAÇÃO EFICIENTE

## 21.1 Níveis de detalhe

**Alta frequência:** NPCs próximos, interação direta e combate.

**Média frequência:** atividades locais, comércio e rotinas.

**Baixa frequência:** cidades distantes, facções, economias regionais e acontecimentos de longo prazo.

## 21.2 Simulação em intervalos

Não simular cada passo de um NPC distante.

Calcular atividades agregadas quando suficiente.

## 21.3 Tempo

Criar calendário e relógio de simulação compartilhados.

Evitar que subsistemas possuam contadores temporais incompatíveis.

## 21.4 Aleatoriedade

Usar geradores de números aleatórios controlados por sementes, com persistência adequada.

## 21.5 Processamento

Evitar:

- Varreduras completas desnecessárias.
- Criação repetida de objetos.
- Eventos sem consumidores.
- Processamento gráfico para entidades invisíveis.
- IA generativa por atualização.
- Reprocessamento integral de regiões inalteradas.

## 21.6 Estabilidade

Implementar limites de:

- Variação econômica.
- Crescimento populacional.
- Recrutamento.
- Expansão territorial.
- Proliferação de eventos.
- Ameaças sobrenaturais.

Os limites não devem impedir consequências graves, mas devem evitar instabilidade numérica.

---

# 22. PLANO DE IMPLEMENTAÇÃO

## Fase 0 — Auditoria e estabilização

Antes de desenvolver novos recursos:

1. Inspecionar o projeto.
2. Executar a suíte de testes.
3. Validar o salvamento atual.
4. Identificar regras duplicadas.
5. Identificar eventos sem consumidores.
6. Identificar módulos sem testes.
7. Documentar dependências.
8. Produzir uma matriz de funcionalidades reais.

**Entrega:** relatório curto de arquitetura, riscos e sequência de implementação.

## Fase 1 — Agentes e objetivos

Implementar:

- Necessidades.
- Objetivos.
- Decisões.
- Mudanças de prioridade.
- Atividades com consequências.
- Persistência.

**Teste de aceitação:** um morador identifica uma necessidade, escolhe uma ação, executa e modifica seu estado.

## Fase 2 — Memória e sociedade

Implementar:

- Relações.
- Reputação.
- Rumores.
- Consequências sociais.
- Reações por personalidade.
- Diálogos conectados ao estado real.

**Teste de aceitação:** duas pessoas com informações e relações diferentes reagem de maneiras distintas ao mesmo acontecimento.

## Fase 3 — Prólogo Vivo

Implementar:

- Questionário.
- Históricos.
- Estado inicial.
- NPCs relacionados.
- Residências.
- Profissões.
- Destino aleatório por semente.
- Persistência.

**Teste de aceitação:** três começos diferentes produzem experiências distintas e válidas.

## Fase 4 — Economia regional

Implementar:

- Mercadorias.
- Estoques.
- Mercados.
- Produção.
- Consumo.
- Comércio entre regiões.
- Preços.
- Crises.
- Recuperação.

**Teste de aceitação:** interromper uma rota produz mudanças rastreáveis e reversíveis.

## Fase 5 — Cidades e organizações

Implementar:

- Desenvolvimento urbano.
- Investimento.
- Decadência.
- Facções.
- Lideranças.
- Relações políticas.
- Consequências sociais.

**Teste de aceitação:** uma crise altera a cidade e influencia decisões de NPCs.

## Fase 6 — Party e guildas

Implementar:

- Recrutamento.
- Vínculos de grupo.
- Ordens básicas.
- Lealdade.
- Contratos.
- Administração de guildas.

**Teste de aceitação:** um NPC recrutado participa de atividades e preserva personalidade e relações.

## Fase 7 — Magia e Tormenta

Implementar:

- Integração sistêmica da magia.
- Incidentes sobrenaturais.
- Pressão regional.
- Corrupção.
- Contenção.
- Consequências econômicas e políticas.

**Teste de aceitação:** uma ameaça sobrenatural produz efeitos regionais coerentes e pode sofrer intervenção.

## Fase 8 — Homebrews e combate em equipe

Implementar:

- Interações contextuais.
- Coordenação de party.
- Profissões aprimoradas.
- Regras próprias configuráveis.
- Balanceamento.

**Teste de aceitação:** opções adicionais enriquecem o combate sem invalidar o conjunto básico de T20.

## Fase 9 — História e integração total

Implementar:

- Crônicas do Reino.
- Rumores históricos.
- Notícias.
- Auditoria de eventos.
- Testes integrados.
- Testes de desempenho.
- Build de avaliação.

**Teste de aceitação:** o jogador consegue entender como suas ações e os acontecimentos externos transformaram o mundo.

---

# 23. VERTICAL SLICE OBRIGATÓRIO

Antes de expandir para múltiplas regiões ou dezenas de profissões, demonstrar um ciclo sistêmico completo na vila existente.

## Cenário de teste: O futuro do aprendiz

1. Um aprendiz deseja abrir uma oficina.
2. Precisa economizar dinheiro.
3. Começa a trabalhar e negociar.
4. Uma caravana é atacada.
5. O material necessário fica caro.
6. O aprendiz muda seu objetivo temporariamente.
7. O jogador pode proteger a rota, ajudar financeiramente, roubar recursos ou ignorar a situação.
8. O aprendiz reage conforme sua personalidade e relação com o jogador.
9. A economia local muda.
10. A história é registrada.
11. O sistema persiste após salvar e carregar.
12. O aprendiz pode prosperar, mudar de profissão ou continuar estagnado.

**Esse teste é prioritário porque comprova a integração real dos sistemas.**

---

# 24. CENÁRIOS COMPLEMENTARES DE ACEITAÇÃO

## Cenário A — Dois passados

Dois personagens com mesma raça e classe, mas históricos diferentes, começam com vínculos e condições diferentes.

As diferenças devem permanecer relevantes após várias sessões.

## Cenário B — Guerra e escassez

Uma guerra interrompe comércio, altera preços e provoca decisões de NPCs e facções.

## Cenário C — Reputação contraditória

Uma ação aumenta a reputação em determinada comunidade e diminui em outra.

## Cenário D — Mudança de liderança

Um líder morre ou é removido. A organização continua por meio de sucessão ou disputa.

## Cenário E — Guilda

O jogador recruta companheiros, cria uma guilda e assume contratos.

## Cenário F — Tormenta

Uma ameaça sobrenatural surge, avança sob condições plausíveis e encontra respostas de NPCs e organizações.

## Cenário G — Recuperação

Uma cidade em crise consegue melhorar sem intervenção obrigatória do jogador.

## Cenário H — Destino aleatório

O gerador cria múltiplos passados válidos e reproduz um deles com semente conhecida.

---

# 25. CRITÉRIOS DE QUALIDADE

## 25.1 Correção

Testes automatizados devem verificar regras e integração.

## 25.2 Observabilidade

Eventos importantes devem produzir evidências acessíveis em logs ou ferramentas de depuração.

## 25.3 Experiência do jogador

As consequências devem aparecer em:

- Diálogos.
- Preços.
- Relações.
- Inventário.
- Comportamento.
- Cenário.
- Missões.
- Notícias.
- Organizações.

## 25.4 Desempenho

Testar múltiplos NPCs, avanço prolongado do tempo e processamento de regiões.

## 25.5 Robustez

Verificar:

- Salvamento.
- Carregamento.
- Migrações.
- Eventos duplicados.
- Referências inválidas.
- NPCs removidos.
- Mudanças de liderança.
- Falhas durante simulação.

## 25.6 Balanceamento

O mundo não deve caminhar automaticamente para prosperidade infinita ou colapso inevitável.

## 25.7 Não regressão

Preservar as funcionalidades já existentes de combate, diálogos, caravanas, clima e UI.

---

# 26. REGRAS DE EXECUÇÃO PARA CLAUDE

## Regra 1 — Não reescrever sem necessidade

Integrar à arquitetura real e preservar código funcional.

## Regra 2 — Priorizar dependências

Implementar fundamentos antes de sistemas que dependam deles.

## Regra 3 — Evitar ciclos repetitivos

Se uma pendência depende de recurso externo indisponível, registrar o bloqueio e avançar.

Não criar várias versões apenas para repetir o mesmo diagnóstico.

## Regra 4 — Funcionalidade real antes de números

Não medir progresso pelo total de testes ou pela quantidade de arquivos.

Priorizar comportamentos utilizáveis.

## Regra 5 — Dados antes de casos especiais

Criar regras e modelos reutilizáveis.

Não escrever uma implementação exclusiva para cada NPC ou origem.

## Regra 6 — Sem IA desnecessária

A simulação deve funcionar sem modelos generativos.

## Regra 7 — Regras oficiais separadas

Preservar Tormenta20 e manter homebrews identificáveis e configuráveis.

## Regra 8 — Testar a integração

Testes unitários não substituem verificação de jogabilidade.

## Regra 9 — Não ampliar conteúdo prematuramente

Não priorizar novas vilas, grandes campanhas ou bibliotecas artísticas enquanto a base sistêmica estiver incompleta.

## Regra 10 — Builds com significado

Agrupar melhorias relevantes antes de gerar uma nova versão distribuível.

## Regra 11 — Autonomia técnica

Tomar decisões razoáveis de implementação sem pedir autorização rotineira.

Não executar operações pagas sem autorização específica.

## Regra 12 — Transparência

Indicar funcionalidades completas, parciais, simuladas ou bloqueadas.

Nunca afirmar que algo está pronto apenas porque uma interface foi criada.

---

# 27. DEFINIÇÃO DE PRONTO

Um módulo estará concluído quando:

1. Estiver implementado no projeto real.
2. Possuir contratos definidos.
3. Produzir comportamento funcional.
4. Interagir corretamente com sistemas dependentes.
5. Persistir seu estado.
6. Passar nos testes relevantes.
7. Não causar regressões críticas.
8. Ser observável dentro do jogo ou da ferramenta de depuração.
9. Possuir documentação mínima.
10. Atender ao cenário de aceitação correspondente.

---

# 28. RESULTADO FINAL ESPERADO

O jogador deve conseguir:

- Criar personagens de diferentes raças e classes.
- Escolher sua origem T20.
- Definir ou sortear seu passado.
- Começar em condições sociais e econômicas diferentes.
- Possuir família, conhecidos, mentores ou rivais.
- Viver em uma casa, trabalhar ou viajar como nômade.
- Ser aventureiro, comerciante, artesão, criminoso ou governante.
- Desenvolver relacionamentos.
- Recrutar companheiros.
- Formar uma party.
- Criar uma guilda.
- Participar de facções.
- Interferir na política.
- Cometer crimes e enfrentar consequências.
- Conquistar propriedades e cidades.
- Participar de guerras.
- Alterar a economia regional.
- Presenciar NPCs evoluindo independentemente dele.
- Encontrar cidades que prosperam ou entram em decadência.
- Usar magia e enfrentar ameaças sobrenaturais.
- Vivenciar consequências graduais da Tormenta.
- Ignorar determinadas histórias e descobrir depois seus resultados.
- Construir uma trajetória própria, sem destino obrigatório.

O mundo deverá preservar a memória de suas transformações.

---

# 29. PRIMEIRA AÇÃO SOLICITADA

Antes de começar novas funcionalidades, execute o seguinte:

**ETAPA 1 — AUDITORIA**

Inspecione o repositório real de Crônicas de Arton e classifique os requisitos deste documento em:

- Implementado e validado.
- Parcialmente implementado.
- Existente, mas sem integração.
- Ausente.
- Bloqueado por dependência.
- Adiado por decisão de escopo.

**ETAPA 2 — ARQUITETURA**

Defina como integrar Arton Viva ao projeto atual, preservando os módulos existentes.

**ETAPA 3 — IMPLEMENTAÇÃO**

Inicie pelo sistema de objetivos e necessidades dos NPCs, seguido das memórias, relações e consequências sociais.

**ETAPA 4 — PROVA**

Demonstre o ciclo completo do aprendiz descrito no Vertical Slice.

**ETAPA 5 — CONTINUIDADE**

Prossiga pelos marcos definidos, sem pedir feedback técnico rotineiro e sem desviar para funcionalidades periféricas.

---

# DIRETRIZ FINAL

Crônicas de Arton não deve ser apenas um RPG com muitas missões.

Deve ser um mundo de fantasia onde cada pessoa possui uma vida possível, cada cidade uma história, cada organização interesses próprios e cada decisão consequências.

O jogador pode tornar-se herói, criminoso, mercador, aventureiro, líder de guilda, conquistador ou alguém que simplesmente deseja viver em paz.

Seu passado influencia o começo, mas não determina seu destino.

O mundo não deve parar para esperá-lo.

**Crônicas de Arton: um mundo que vive, com ou sem você.**

**Fim da especificação CDA-WORLD-001 v1.0.**