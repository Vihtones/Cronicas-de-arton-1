"""Gera data/dialogue/voices.json (ORIGINAL_DO_JOGO): a VOZ dos moradores da vila.
Cada morador pertence a um registro (como fala) por profissão; os textos mudam com hora, clima,
evento da vila, reputação do jogador, se já se conheceram e quantas vezes falaram.
Textos editáveis aqui. Nada neste arquivo altera fatos, testes ou efeitos: só o texto exibido."""
import json, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "data" / "dialogue" / "voices.json"

# profissão -> registro
registro = {
    "guarda": "seco", "guarda aposentado": "idoso", "capitã da guarda": "seco", "alcaide": "seco", "ferreiro": "seco", "caçador": "seco",
    "taverneira": "caloroso", "cozinheiro": "caloroso", "clériga de Lena": "sereno", "mercadora": "caloroso", "mercadora viajante": "caloroso", "mensageiro": "seco",
    "fiandeira": "caloroso", "estalajadeira": "caloroso", "barqueiro": "seco", "vigia": "seco", "pastora": "simples", "lavrador": "simples", "lavradora": "simples", "moleiro": "simples", "ajudante de moleiro": "jovem",
    "criança": "jovem", "aprendiz": "jovem", "acólito": "jovem", "bêbado": "bebado",
}

periodos = ["manha", "tarde", "noite"]

primeiro = {   # primeiro encontro, por registro e período
    "seco": {"manha": ["Forasteiro. Bom dia. Mantenha as mãos à vista e vai dar tudo certo.", "Bom dia. Não o conheço. Isso é bom ou ruim, ainda vamos ver."],
             "tarde": ["Boa tarde. Novo por aqui, pelo jeito.", "Forasteiro. O que deseja?"],
             "noite": ["Boa noite. Hora estranha para andar por aí, forasteiro.", "Já escureceu. Diga logo o que quer."]},
    "caloroso": {"manha": ["Bom dia, viajante! Não lembro de você. Seja bem-vindo à Vila Alvorada.", "Ora, um rosto novo! Bom dia, e que Lena abençoe seu caminho."],
                 "tarde": ["Boa tarde! Primeira vez por aqui? Fique à vontade.", "Um forasteiro! Chegue mais, não mordo."],
                 "noite": ["Boa noite! Que horas de chegar... Venha, o dia foi longo para todos.", "Boa noite, viajante. Cansado da estrada, imagino."]},
    "sereno": {"manha": ["Que a manhã lhe seja leve, viajante. Sou nova para o seu nome, mas não para a sua necessidade.", "Bom dia. Lena recebe todos, e eu também."],
               "tarde": ["Boa tarde. Seja quem for, esta paz também é sua.", "A tarde é boa para recomeços. Em que posso ajudar?"],
               "noite": ["A noite acolhe os cansados. Fale, sem pressa.", "Boa noite, viajante. A luz do templo ainda está acesa."]},
    "simples": {"manha": ["Bom dia. Não é daqui, né?", "Dia. O senhor tá de passagem?"],
                "tarde": ["Boa tarde. Forasteiro, é? Aqui a gente trabalha de sol a sol.", "Tarde. Precisa de alguma coisa?"],
                "noite": ["Boa noite. Já tá tarde pra ficar na rua.", "Noite. A gente já se recolhe cedo por aqui."]},
    "jovem": {"manha": ["Oi! Você é novo? Nunca te vi!", "Bom dia! Você veio de longe?"],
              "tarde": ["Eita, gente nova! Oi!", "Oi! Quer saber de alguma coisa? Eu sei de tudo por aqui."],
              "noite": ["Boa noite... já devia estar em casa, mas oi.", "Você anda muito tarde por aí, hein?"]},
    "idoso": {"manha": ["Ah, um rosto novo. Bom dia, jovem. A vila muda, mas as perguntas são as mesmas.", "Bom dia. Sente-se um pouco, se quiser. Eu já vi muita coisa por aqui."],
              "tarde": ["Boa tarde. Os velhos gostam de gente nova: traz notícias.", "Forasteiro... faz tempo que não chega ninguém."],
              "noite": ["Boa noite. Não durmo mais como antes. E você?", "A noite é minha hora. Fale."]},
    "bebado": {"manha": ["Bom... bom dia? Ainda é de manhã? Hic. Quem é você?", "Um forasteiro! Chegue, chegue. Não tenho nada, mas conto histórias."],
               "tarde": ["Ei! Hic. Você me paga uma? Brinco, brinco.", "Quem é você? Não importa. Senta aí."],
               "noite": ["A noite... a noite é boa. Hic. A noite não pergunta nada.", "Ah, um amigo novo! Todos são amigos à noite."]},
}

conhecido = {   # já se conhecem; por registro e relação (amigo / neutro / frio)
    "seco": {"amigo": ["Você de novo. Bom ver um rosto de confiança.", "Ah, é você. Pode falar."],
             "neutro": ["Voltou. O que precisa?", "Sim?"],
             "frio": ["...Você. O que quer agora?", "Fale rápido. Estou de olho em você."]},
    "caloroso": {"amigo": ["Ah, é você! Sempre bem-vindo, de verdade!", "Que bom te ver! Entre, entre."],
                 "neutro": ["Olá de novo! Em que posso ajudar?", "Voltou! Como vai a vida?"],
                 "frio": ["...Olá. Seja breve, por favor.", "Ah. É você."]},
    "sereno": {"amigo": ["Sua presença é uma alegria. Lena lhe sorri.", "Meu amigo. Sente-se. O que lhe pesa hoje?"],
               "neutro": ["Que Lena o guarde. Em que posso servir?", "Bem-vindo de volta."],
               "frio": ["Ainda o recebo. Mas a paz exige respeito.", "Fale. E escolha as palavras."]},
    "simples": {"amigo": ["Ei, é o amigo! Chega aí, tá tudo bem?", "Olha só quem apareceu! Boa gente."],
                "neutro": ["Ah, o senhor de novo. Diga.", "Dia. Precisa de algo?"],
                "frio": ["Hum. É o senhor.", "Eu já não tenho muito o que dizer pra você."]},
    "jovem": {"amigo": ["Você voltou! Eba!", "Oi, oi, oi! Tenho tanta coisa pra contar!"],
              "neutro": ["Oi de novo!", "Ah, é você. O que foi?"],
              "frio": ["Minha mãe disse pra não falar com você.", "Hmpf. O que você quer?"]},
    "idoso": {"amigo": ["Meu bom amigo. Ainda bem que apareceu antes que eu esquecesse o que ia contar.", "Ah, você. Esse eu reconheço de longe."],
              "neutro": ["Ah, o forasteiro. Lembro de você. Sou velho, não esclerosado.", "Voltou. Diga lá."],
              "frio": ["Já vi gente como você. Nem sempre termina bem.", "Hmm. É você."]},
    "bebado": {"amigo": ["Meu amigo! Hic! Senta, senta.", "Ah, o melhor forasteiro de Arton!"],
               "neutro": ["Ei... você de novo. Hic.", "O que foi desta vez?"],
               "frio": ["Não... não quero problema. Hic.", "Vai embora. Hic. Por favor."]},
}

mesmo_dia = {   # já conversaram hoje
    "seco": ["De novo? Fale direto.", "Já falamos hoje. Algo novo?"],
    "caloroso": ["Já de volta? Que bom, ainda tenho tempo para você.", "Olha só, conversamos faz pouco! Esqueceu algo?"],
    "sereno": ["Voltou tão cedo. Algo ficou por dizer?", "A conversa não terminou, vejo."],
    "simples": ["Já de volta? Esqueceu alguma coisa?", "Mais alguma coisa?"],
    "jovem": ["Você de novo! Eu ainda tava lembrando do que a gente falou.", "Voltou rápido!"],
    "idoso": ["Eu ainda estava pensando no que dissemos. Fale.", "Já? A memória de um velho ainda alcança a manhã."],
    "bebado": ["Hic. A gente... a gente não acabou de falar?", "Ué... você já esteve aqui, né?"],
}

retorno = {   # voltou depois de dias
    "caloroso": "Faz uns {dias} dias que não aparece. Sentimos falta!",
    "seco": "Sumido há {dias} dias. Alguma novidade?",
    "sereno": "Passaram-se {dias} dias. Que bom que voltou.",
    "simples": "Faz {dias} dias que não via o senhor.",
    "jovem": "Faz {dias} dias! Você demorou!",
    "idoso": "{dias} dias. Para mim, o tempo tem outra medida, mas contei.",
    "bebado": "Faz... hic... uns dias que você sumiu.",
}

preocupado = {   # misterioso desaparecimento em aberto (mistério ativo)
    "seco": "Tempos estranhos. A capitã não dorme, e a gente também não.",
    "caloroso": "Ai, e esse desaparecimento do filho do Otto... A vila anda inquieta.",
    "sereno": "Rezo pelo rapaz desaparecido. A vila inteira carrega esse peso.",
    "simples": "Anda uma tensão por aqui desde que o filho do moleiro sumiu.",
    "jovem": "Dizem que o Tomas sumiu... a gente tem medo de sair à noite.",
    "idoso": "Já vi vilas inteiras mudarem por menos que isso. O rapaz sumiu e o ar mudou.",
    "bebado": "Hic. As pessoas desaparecem... Eu não vi nada. Nada!",
}

clima = {   # comentário do tempo
    "limpo": {"seco": "Céu limpo. Bom para patrulha.", "caloroso": "Que dia lindo! Dá vontade de sair cantando.", "sereno": "O céu está generoso. Lena sorri para nós.",
              "simples": "Tempo bom pra lida. Não reclamo.", "jovem": "Hoje dá pra brincar lá fora!", "idoso": "Dia limpo. Meus ossos agradecem.", "bebado": "O sol, hic, tá forte demais."},
    "chuva": {"seco": "Chuva. A lama complica tudo.", "caloroso": "Chuva... boa hora pra um caldo quente, não acha?", "sereno": "A chuva lava o mundo. Há bênção nisso.",
              "simples": "Essa chuva é boa pra plantação, mas custa a gente.", "jovem": "Eu gosto de pular nas poças! Mamãe não deixa.", "idoso": "Chuva fina. Meus joelhos já sabiam desde ontem.", "bebado": "Chove, hic... até o céu bebe."},
    "tempestade": {"seco": "Tempestade. Recolha-se se puder.", "caloroso": "Que tempestade! Entre, pelo amor de Lena.", "sereno": "A tempestade passa. Sempre passa.",
                   "simples": "Com esse temporal ninguém trabalha.", "jovem": "Os trovões me dão medo...", "idoso": "Há tempestades que trazem coisas. Fique atento.", "bebado": "A tempestade... hic... fala comigo."},
    "neblina": {"seco": "Neblina. Visibilidade ruim. Olho aberto.", "caloroso": "Essa neblina deixa tudo tão quieto...", "sereno": "A névoa pede silêncio. Ouça.",
                "simples": "Neblina assim, melhor não sair da estrada.", "jovem": "Parece que tem coisa escondida na névoa!", "idoso": "Neblina boa pra segredos. E pra gente que não quer ser vista.", "bebado": "Tudo tão... hic... enevoado. Igual eu."},
}

evento = {   # opinião sobre feira e festa
    "feira": {"seco": "Feira cheia dá trabalho: ladrões de bolsa. Mas é bom pro povo.", "caloroso": "Adoro a feira! Cheiro de pão, gente rindo... compre alguma coisa!",
              "sereno": "A feira reúne a vila. É também uma forma de oração.", "simples": "Dia de feira é o dia de vender o que a gente plantou.",
              "jovem": "A feira! Tem doce, tem tudo! Você vai?", "idoso": "A feira já foi bem menor. Antes, a gente conhecia cada barraca.", "bebado": "Feira... hic... tem cerveja na feira?"},
    "festa": {"seco": "Festa à noite: mais brigas, menos sono. Mas a vila merece.", "caloroso": "A festa! Vai ter música, dança e bebida até o dia clarear!",
              "sereno": "Nas festas, a vila lembra por que vive junta.", "simples": "Depois de tanta lida, uma festa faz bem.",
              "jovem": "Vou ficar acordado até tarde! Será?", "idoso": "As festas de hoje têm menos música. Mas ainda me divirto.", "bebado": "Festa! Hic! Finalmente um motivo."},
}

trabalho = {   # como vai o trabalho, por profissão
    "guarda": "Turno é turno. Quem faz bem não é notado. Quem faz mal vira lenda.",
    "guarda aposentado": "Aposentado, mas meus olhos ainda vigiam. Antigos hábitos.",
    "capitã da guarda": "Vigiar uma vila inteira com poucos homens. Nada simples. Mas é o meu dever.",
    "alcaide": "Cuido das leis e das multas. Pouca gente me agradece.",
    "ferreiro": "O ferro não mente. Se está mole, é culpa do ferreiro; se está duro, também.",
    "caçador": "A mata ensina mais que qualquer livro. Quem escuta, aprende. Quem não, vira jantar.",
    "taverneira": "A taverna é meu mundo. Sei de tudo o que se fala aqui, mas guardo o que me convém.",
    "cozinheiro": "Panela cheia, vila contente. É o que penso desde que comecei.",
    "clériga de Lena": "Cuidar de corpos e almas é um ofício sem fim. Mas é o meu chamado.",
    "mercadora": "Negócio é paciência: comprar barato, vender honesto, e nunca confiar em quem jura demais.",
    "mercadora viajante": "A estrada paga e cobra. Eu levo notícias junto com mercadorias.",
    "mensageiro": "Estrada longa, pouca conversa. Levo recado e volto antes que esfrie a notícia.",
    "fiandeira": "Fio a fio, o dia passa. Tecer acalma a cabeça, ainda que o coração não aquiete.",
    "pastora": "Cuido do rebanho. Ovelhas são mais sinceras que gente.",
    "lavrador": "Plantar é fé. A gente joga a semente e reza.",
    "estalajadeira": "Quem passa por Pedra Branca dorme aqui. E quem dorme aqui conta o que viu na estrada.",
    "barqueiro": "O lago não tem pressa, e eu aprendi com ele.",
    "vigia": "Da torre se vê a estrada inteira. O que se faz com isso é outra conversa.",
    "lavradora": "A terra dá quando a gente respeita. E cobra quando a gente esquece.",
    "moleiro": "O moinho gira e a vila come. Não me peça mais do que isso.",
    "ajudante de moleiro": "Ajudo no moinho. Meu pai diz que um dia vai ser meu. Eu ainda não sei.",
    "criança": "Meu trabalho é brincar! E fugir quando mandam eu fazer tarefa.",
    "aprendiz": "Aprendiz é quem apanha primeiro e acerta depois. Mas estou gostando!",
    "acólito": "Estudo as rezas e ajudo a clériga. Tem muito pra aprender.",
    "bêbado": "Trabalho? Hic. Ah, eu já trabalhei. Já faz tempo...",
}

nota_profissao = {   # como os outros veem alguém por profissão
    "guarda": "faz a ronda", "guarda aposentado": "já foi guarda", "capitã da guarda": "comanda a guarda", "alcaide": "cuida das leis",
    "ferreiro": "trabalha o ferro", "caçador": "vive na mata", "taverneira": "toca a taverna", "cozinheiro": "cuida da cozinha",
    "clériga de Lena": "cuida dos fiéis e dos doentes", "mercadora": "negocia na vila", "mercadora viajante": "traz notícias de longe", "mensageiro": "leva recados entre as cidades",
    "fiandeira": "trabalha com fios e tecidos", "estalajadeira": "hospeda quem vem da estrada", "barqueiro": "conhece o lago palmo a palmo", "vigia": "vigia a estrada do alto da torre", "pastora": "cuida do rebanho", "lavrador": "trabalha a terra", "lavradora": "trabalha a terra",
    "moleiro": "toca o moinho", "ajudante de moleiro": "ajuda no moinho", "criança": "ainda é criança", "aprendiz": "está aprendendo o ofício",
    "acólito": "serve no templo", "bêbado": "bebe mais do que deveria",
}

nota_traco = {
    "teimoso": "teimoso como mula", "aflita": "anda aflita nesses dias", "curioso": "curioso demais para o próprio bem",
    "desconfia_de_estrangeiros": "não gosta de forasteiros, mas é justo", "observadora": "vê mais do que diz", "exige_provas": "só acredita com provas",
    "memoria_longa": "tem memória de elefante", "recluso": "gosta de ficar sozinho", "fofoqueira": "adora uma novidade, e a espalha", "calado": "fala pouco e escuta muito", "traz_noticias": "sempre sabe das novidades", "mentiroso": "cuidado: nem tudo o que diz é verdade",
}

relacao = {
    "familia": "É da minha família. {nota}",
    "faccao": "Trabalhamos juntos. {nota}",
    "vila": "Conheço, claro. Todo mundo se conhece aqui. {nota}",
}

# reação do morador ao jogador (RelationsModule.reaction): a mesma pessoa fala de outro jeito conforme a relação
reacao = {
    "guarda_rancor": "Ainda não esqueci o que você fez.",
    "teme": "Fique longe de mim, por favor.",
    "respeita_mas_nao_confia": "Respeito o que você faz, mas não confio em você.",
    "amigavel": "Sempre bom te ver por aqui.",
    "confia": "Pode contar comigo para o que precisar.",
}

# Fronteira do Leste (Junco Alto, Areia Dourada, Rocha Negra): registro, trabalho e nota por profissão.
registro.update({"guia": "seco", "anciã": "idoso", "carroceira": "caloroso", "taverneiro": "caloroso", "cozinheira": "caloroso", "pescador": "simples", "curandeira": "sereno", "ancião": "idoso",
    "estalajadeiro": "caloroso", "mercador": "caloroso", "armeira": "seco", "atendente da guilda": "seco", "capitão de caravana": "seco",
    "erudito": "sereno", "capataz": "seco", "minerador": "simples", "mineradora": "simples", "sacerdotisa de Khalmyr": "sereno",
    "capitão da guarda": "seco"})
trabalho.update({
    "guia": "Conheço cada atalho entre aqui e o deserto. Quem ignora meu conselho se perde.",
    "anciã": "Cuido das ervas e das lembranças. As duas murcham se ninguém cuida.",
    "carroceira": "Carroça boa aguenta estrada ruim. Estrada ruim não aguenta carroça mal feita.",
    "taverneiro": "Cerveja de junco, peixe frito e fofoca de graça. A taberna do Sapo não fecha.",
    "cozinheira": "Ensopado de peixe todo dia. Quem reclama, pesca a própria janta.",
    "pescador": "A água do brejo dá peixe, mas a névoa leva um homem de vez em quando.",
    "curandeira": "Ervas do brejo curam quase tudo, se a pessoa souber onde colher.",
    "ancião": "Eu vi o altar afundar, e ainda ouço as serpentes à noite.",
    "estalajadeiro": "Quarto limpo, água quente e dois dias de caravana por conta da casa, se o cliente pagar.",
    "mercador": "Trago de tudo, do fio à espada. Desde que tenha ouro e não tenha pressa.",
    "armeira": "Aço bom não se faz com pressa, nem se vende sem prova de uso.",
    "atendente da guilda": "Contratos, taxas, ranks... Quem lê o quadro com cuidado não morre à toa.",
    "capitão de caravana": "Três caravanas por semana, se os gnolls me deixarem em paz.",
    "erudito": "Escrevo o que vejo. Os deuses antigos deixaram muito escrito e pouco explicado.",
    "capataz": "Minério não sai sozinho. Cada pá conta, e cada atraso desconta.",
    "minerador": "Picareta na mão, lanterna no pescoço. A mina dá e a mina cobra.",
    "mineradora": "A rocha negra brilha de noite. Não é coisa boa, mas paga.",
    "sacerdotisa de Khalmyr": "Justiça não é vingança. Eu sigo a balança, mesmo quando dói.",
    "capitão da guarda": "A fronteira é grande e a guarda é pequena. Então cada soldado conta.",
})
nota_profissao.update({
    "guia": "conhece as estradas do leste como ninguém",
    "anciã": "a mais velha do vale, guarda as histórias da aldeia",
    "carroceira": "leva carga para qualquer lugar e cobra pelo caminho",
    "cozinheira": "cozinha para a taberna e sabe o que cada um come",
    "pescador": "vive do peixe e da névoa, e fala pouco",
    "ancião": "viu a vila mudar mais de uma vez",
    "estalajadeiro": "dono de pousada, conhece caravaneiros e segredos de hóspedes",
    "mercador": "negocia com todo mundo e confia em poucos",
    "armeira": "faz armas e não vende a quem não sabe usá-las",
    "atendente da guilda": "lê os contratos e anota quem cumpre",
    "minerador": "trabalha na rocha e volta com as mãos marcadas",
    "mineradora": "trabalha na rocha e volta com as mãos marcadas",
    "sacerdotisa de Khalmyr": "fala de justiça como quem fala de tempo",
    "capitão da guarda": "comanda a guarda da fronteira com mão firme",
    "taverneiro": "dono de taverna, sabe de tudo que se passa no brejo",
    "curandeira": "conhece as ervas e quase todos os doentes do brejo",
    "capataz": "manda nos mineiros e não tem paciência com ninguém",
    "erudito": "passa o dia lendo e esquece de comer",
    "capitão de caravana": "cruza o deserto com as caravanas e conhece cada gnoll da região",
})
data = {"schema_version": 1, "status": "ORIGINAL_DO_JOGO", "registro": registro, "periodos": periodos, "primeiro": primeiro, "conhecido": conhecido,
        "mesmo_dia": mesmo_dia, "retorno": retorno, "preocupado": preocupado, "clima": clima, "evento": evento, "trabalho": trabalho,
        "nota_profissao": nota_profissao, "nota_traco": nota_traco, "relacao": relacao, "reacao": reacao}

OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
n = sum(len(v) for g in (primeiro, conhecido) for r in g.values() for v in r.values())
print("voices.json:", len(registro), "profissões,", n, "saudações de apresentação/relação,", len(trabalho), "falas de trabalho")


# ---------------------------------------------------------------------------------------------
# Falas ambiente (balões dos figurantes e latidos dos moradores): data/dialogue/ambient.json
AMB = OUT.parent / "ambient.json"

conversas = [
    {"quando": {"clima": ["chuva", "tempestade"]}, "falas": [
        ["Que chuvarada, hein?", "Pelo menos o poço enche.", "E o telhado do Joran?", "Já pingava antes de chover."],
        ["Essa lama vai até o joelho.", "Mande as galochas que eu compro.", "Você não tem galochas!", "Por isso mesmo."]]},
    {"quando": {"clima": ["limpo"], "periodo": ["manha", "tarde"]}, "falas": [
        ["Dia bonito pra colheita.", "Deus queira que o trigo aguente.", "Lena há de proteger.", "E o moinho gira, e a gente come."],
        ["O preço da lã subiu.", "De novo? Sempre sobe, nunca desce.", "Culpa dos mercadores de fora.", "Culpa de quem compra, isso sim."]]},
    {"quando": {"misterio": True}, "prioridade": 3, "falas": [
        ["Soube do filho do moleiro?", "Sumiu, dizem. Desde a madrugada.", "A capitã está de olho, mas não acha nada.", "Tem gente que não dorme mais."],
        ["Luzes na Torre Partida, de novo.", "Não devia dizer isso alto.", "Mas foi o que o Tomas dizia...", "Pois olha onde foi parar."],
        ["Fecharam a porta mais cedo hoje.", "Eu também. Não custa.", "Algo está errado nessa vila.", "Arton é grande. Mas nada some do nada."]]},
    {"quando": {"evento": ["feira"]}, "prioridade": 3, "falas": [
        ["Viu as barracas? Tem pano novo.", "E os preços, viu os preços?", "Tudo pela hora da morte.", "Mas a gente compra mesmo assim."],
        ["Vou levar mel pra casa.", "Só se for pelo dobro.", "Eita feira cara!", "É feira, é pra gastar."]]},
    {"quando": {"evento": ["festa"], "periodo": ["tarde", "noite"]}, "prioridade": 3, "falas": [
        ["Hoje tem dança até o amanhecer!", "Se a bebida durar.", "Rosana prometeu barris.", "Então dura!"],
        ["Quem vai tocar?", "O pessoal de sempre.", "Ainda bem, não há melhor.", "Nem pior."]]},
    {"quando": {"periodo": ["noite"]}, "falas": [
        ["Já é tarde pra estar na rua.", "A taverna ainda está aberta.", "Pois então...", "Uma só, prometo."],
        ["Ouviu aquele barulho?", "É só o vento.", "O vento não anda de botas.", "Pare com isso."]]},
    {"quando": {}, "falas": [
        ["E a família, como vai?", "Todos bem, graças aos deuses.", "E o filho mais velho?", "Aprendendo o ofício, devagar."],
        ["Viu a capitã Elsa passar?", "Passou rápida, como sempre.", "Nunca sorri aquela mulher.", "Também, com esse trabalho..."],
        ["O ferreiro não gosta de forasteiro.", "O ferreiro não gosta de ninguém.", "Mas faz ferradura boa.", "Isso faz."]]},
]

vendedor = {
    "comida": ["Pão fresco, saindo do forno!", "Maçãs doces, doces!", "Peixe do rio, fresquinho!", "Queijo curado da Fenna!", "Mel puro, prova só!"],
    "ferramenta": ["Facas afiadas!", "Foices e enxadas, preço justo!", "Ferradura nova, garantida!", "Machado bom não quebra!"],
    "remedio": ["Ervas para a tosse!", "Unguento de Lena, cura tudo!", "Chá de camomila, alivia a alma!"],
    "madeira": ["Tábuas frescas, direto da serraria!", "Madeira de lei, não racha!"],
    "tecido": ["Panos de Valkaria!", "Lã macia, linho fino!", "Fio de Hilda, o melhor da vila!"],
}
vendedor_noite = ["Última chamada! Leve tudo!", "Hoje faço preço de custo!"]

crianca = {
    "geral": ["Pega!", "Tá com você!", "Corre!", "Não vale!", "Hihi!", "Me pega se for capaz!"],
    "chuva": ["Olha a poça!", "Eba, lama!", "Mamãe vai brigar!"],
    "noite": ["Só mais um pouquinho!", "Não tô com sono!", "Eu vi um vulto!"],
    "feira": ["Quero doce!", "Compra pra mim!", "Olha o malabarista!"],
    "festa": ["Vai ter fogos?", "Eu dançei três vezes!", "Quero ficar até tarde!"],
}

danca = ["♪", "♪♪", "Saúde!", "Hurra!", "Mais uma!", "Dança comigo!", "Toca de novo!", "Que noite!"]

ocupado = {
    "saco": ["Pesado, ai, ai.", "Mais um e acabo.", "Quem enche esses sacos?"],
    "vassoura": ["Essa poeira não acaba.", "Varrer, varrer...", "Já limpei isso ontem."],
    "cesto": ["Ovos frescos!", "Cuidado com o cesto!", "Hoje a galinha botou três."],
    "lenha": ["Racha, racha.", "Lenha pro inverno.", "Esse machado já viu dias melhores."],
    "": ["Tanta coisa pra fazer.", "Não paro um minuto.", "Daqui a pouco eu descanso."],
}

passante = {
    "manha": ["Bom dia, vizinho!", "Já de pé, hein?", "O dia promete."],
    "tarde": ["Boa tarde!", "Calorzão, né?", "Bora que ainda tem serviço."],
    "noite": ["Já vou me recolher.", "Boa noite!", "Noite fria."],
    "chuva": ["Que chuvarada!", "Corre, corre!", "Vou me molhar todo!"],
    "tempestade": ["Pra dentro, pra dentro!", "Isso é castigo!", "Tem raio caindo!"],
    "neblina": ["Não enxergo dois passos...", "Cuidado com a ponte!", "Névoa de arrepiar."],
    "misterio": ["Cuidado na estrada à noite.", "Soube do filho do moleiro?", "Tempos estranhos..."],
    "feira": ["Vai à feira?", "Tá cheia a feira!", "Vou ver os preços."],
    "festa": ["Te vejo na festa!", "Vai ter música!", "Hoje é dia de dançar!"],
}

# latidos: o morador reconhece o jogador que passa (registro x relação)
latido = {
    "seco": {"amigo": ["Forasteiro. Bom te ver.", "Ei. Tudo em ordem?"], "neutro": ["Hm.", "Siga seu caminho."], "frio": ["Estou de olho.", "..."]},
    "caloroso": {"amigo": ["Olá, amigo!", "Passe lá depois!"], "neutro": ["Bom dia!", "Olá!"], "frio": ["...", "Hmpf."]},
    "sereno": {"amigo": ["Que Lena o guarde.", "A paz esteja contigo."], "neutro": ["Seja bem-vindo.", "Boa jornada."], "frio": ["Tenha cuidado.", "..."]},
    "simples": {"amigo": ["Ô, amigo!", "Passa por aqui!"], "neutro": ["Dia.", "Opa."], "frio": ["Hum.", "..."]},
    "jovem": {"amigo": ["Oi, oi!", "Você voltou!"], "neutro": ["Oi!", "Olha ele!"], "frio": ["Hmpf.", "Mãe, olha ele."]},
    "idoso": {"amigo": ["Ah, o forasteiro.", "Venha, venha."], "neutro": ["Eh.", "Cuide-se."], "frio": ["Hm.", "Já vi tipos assim."]},
    "bebado": {"amigo": ["Amigo! Hic!", "Senta aqui!"], "neutro": ["Hic.", "Ei, você."], "frio": ["Não... não quero briga.", "..."]},
}

amb = {"schema_version": 1, "status": "ORIGINAL_DO_JOGO", "conversas": conversas, "vendedor": vendedor, "vendedor_noite": vendedor_noite,
       "crianca": crianca, "danca": danca, "ocupado": ocupado, "passante": passante, "latido": latido}
AMB.write_text(json.dumps(amb, ensure_ascii=False, indent=1), encoding="utf-8")
print("ambient.json:", len(conversas), "temas de conversa,", sum(len(c["falas"]) for c in conversas), "diálogos,",
      sum(len(v) for v in vendedor.values()), "pregões")
