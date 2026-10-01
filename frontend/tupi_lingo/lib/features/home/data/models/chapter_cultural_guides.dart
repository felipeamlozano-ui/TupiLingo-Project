/// Model e repositório com os Guias Culturais autênticos e individualizados para cada capítulo da trilha TupiLingo.
class ChapterCulturalGuide {
  final int numero;
  final String titulo;
  final String subtitulo;
  final String icone;
  final String saberesAncestrais;
  final String curiosidadeLinguistica;
  final String expressaoDestaque;
  final String expressaoTraducao;

  const ChapterCulturalGuide({
    required this.numero,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.saberesAncestrais,
    required this.curiosidadeLinguistica,
    required this.expressaoDestaque,
    required this.expressaoTraducao,
  });

  static ChapterCulturalGuide getForChapter(int numero, {String? defaultTitulo}) {
    return _guias[numero] ??
        ChapterCulturalGuide(
          numero: numero,
          titulo: defaultTitulo ?? 'Capítulo $numero: Tradição e Sabedoria',
          subtitulo: 'Saberes Tradicionais de Pindorama',
          icone: '🏛️',
          saberesAncestrais:
              'A memória ancestral dos povos originários de Pindorama é transmitida através da oralidade, das narrativas em torno do fogo sagrado e do respeito profundo aos ciclos da floresta e das águas.',
          curiosidadeLinguistica:
              'No Tupi Antigo, os conceitos de tempo e espaço entrelaçam-se: as raízes morfológicas expressam não apenas a ação, mas a relação do falante com a terra.',
          expressaoDestaque: 'Aîeté katu!',
          expressaoTraducao: 'É a mais pura verdade! / Muito bem!',
        );
  }

  static final Map<int, ChapterCulturalGuide> _guias = {
    1: const ChapterCulturalGuide(
      numero: 1,
      titulo: 'Saudações, Encontros e Boas-Vindas',
      subtitulo: 'A Etiqueta Social e a Hospitalidade Tupi',
      icone: '🤝',
      saberesAncestrais:
          'Para os povos Tupi, o acolhimento ao visitante era sagrado. Ao chegar a uma aldeia, o recém-chegado '
          'era recebido nas redes com o "choro de saudação" (tataîpy) pelas mulheres mais velhas, expressando '
          'alegria e honra por sua presença. Não havia pressa: a partilha de alimentos e água fresca acontecia '
          'antes de qualquer deliberação formal.',
      curiosidadeLinguistica:
          'A saudação "Ereîur-pe?" significa literalmente "Vieste?". O sufixo interrogativo "-pe" transforma a '
          'constatação de chegada em um gesto fraterno de reconhecimento da presença do outro.',
      expressaoDestaque: 'Kauê, pa\'ĩ! Ereîur-pe?',
      expressaoTraducao: 'Salve, meu senhor! Vieste em paz?',
    ),
    2: const ChapterCulturalGuide(
      numero: 2,
      titulo: 'A Taba e a Vida Comunitária na Maloca',
      subtitulo: 'Arquitetura Ancestral e a Grande Ocara',
      icone: '🛖',
      saberesAncestrais:
          'A taba era circular e fortificada por paliçadas de madeira (caiçaras). No centro situava-se a ocara, '
          'o pátio comum onde se realizavam as festas, danças e assembleias de guerreiros. Cada maloca (oca) '
          'abrigava uma família estendida inteira de até duzentas pessoas, dormindo em redes de algodão ou tucum, '
          'com fogueiras acesas ao pé da rede para aquecer a noite e afastar insetos.',
      curiosidadeLinguistica:
          'A palavra "Taba" designa a aldeia inteira, enquanto "Oka" (ou "Oca") é a casa individual. '
          'O termo moderno "Carioca" deriva de "Kari\'oka" — a "casa do homem branco".',
      expressaoDestaque: 'Che taba porangeté!',
      expressaoTraducao: 'Minha aldeia é formosa e próspera!',
    ),
    3: const ChapterCulturalGuide(
      numero: 3,
      titulo: 'Os Rios Sagrados e a Pesca Ancestral',
      subtitulo: 'Paraná-Mirim e as Canoas Monóxilas',
      icone: '🛶',
      saberesAncestrais:
          'Os rios (Y ou Paraná) eram as verdadeiras rodovias de Pindorama. Os navegadores Tupi esculpiam canoas '
          'em tronco único de árvores gigantescas (como a peroba e o jatobá), capazes de transportar até 30 remadores. '
          'Pescavam com flechas de ponta de osso, arpões e armadilhas trançadas chamadas pari, conhecendo cada maré '
          'e correnteza costeira com precisão astronômica.',
      curiosidadeLinguistica:
          'A vogal "Y" é pronunciada como uma vogal alta central não arredondada [ɨ], um som profundo no fundo da '
          'garganta. É a palavra raiz para água, rio e líquidos vitais.',
      expressaoDestaque: 'Y poranga sykyîe\'yma!',
      expressaoTraducao: 'Água pura e límpida que sacia a sede!',
    ),
    4: const ChapterCulturalGuide(
      numero: 4,
      titulo: 'A Mata Atlântica e a Botânica Nativa',
      subtitulo: 'Ka\'a: Farmácia Sagrada e Sustento',
      icone: '🌿',
      saberesAncestrais:
          'A floresta (Ka\'a) não era vista como um recurso a explorar, mas como um corpo vivo sagrado mantido por '
          'espíritos guardiões como Curupira e Caipora. As mulheres dominavam a taxonomia botânica de centenas de '
          'plantas: a copaíba para cicatrização, o jaborandi para olhos e febres, e o timbó usado com sabedoria '
          'sustentável para atordoar peixes sem contaminar o lençol d\'água.',
      curiosidadeLinguistica:
          'Muitas plantas brasileiras guardam seu nome em Tupi original: Maracujá ("fruto que se come na cuia"), '
          'Abacaxi ("fruto cheiroso") e Mandioca ("casa de Mani").',
      expressaoDestaque: 'Ka\'ape jasy tatagûasu oîapirõ.',
      expressaoTraducao: 'Na mata cerrada, a luz da lua clareia o caminho.',
    ),
    5: const ChapterCulturalGuide(
      numero: 5,
      titulo: 'Animais Sagrados e Cosmologia da Fauna',
      subtitulo: 'Jagûara, o Senhor das Sombras',
      icone: '🐆',
      saberesAncestrais:
          'Na cosmovisão Tupi, os animais eram dotados de espírito e intenção. A onça-pintada (Jagûara) era o '
          'arquétipo da força, silêncio e majestade. Antes de qualquer caçada, os caçadores realizavam cânticos '
          'de reverência para pedir permissão aos espíritos da floresta, assegurando que jamais abateriam mais '
          'do que o necessário para alimentar as famílias da taba.',
      curiosidadeLinguistica:
          'O termo "Jagûara" originou nossa palavra "Jaguara" e "Jaguar". Ao contrário do português europeu que '
          'importava nomes latinos, o Tupi nomeava os bichos pelo comportamento: "Tatu" (casca grossa).',
      expressaoDestaque: 'Jagûara morubixaba ka\'arusupe.',
      expressaoTraducao: 'A grande onça é soberana nas matas densas.',
    ),
    6: const ChapterCulturalGuide(
      numero: 6,
      titulo: 'O Fogo Sagrado e a Culinária de Pindorama',
      subtitulo: 'Tatagûasu, Cauim e a Moqueca Ancestral',
      icone: '🔥',
      saberesAncestrais:
          'O fogo (Tata) jamais se apagava inteiramente na aldeia: suas brasas eram preservadas com cascas duras. '
          'A alimentação baseava-se na mandioca brava desintoxicada no tipiti, na farinha tostada (u\'i) e nos '
          'peixes moqueados sobre grelhas de varas verdes (mokaém). O cauim, bebida fermentada de mandioca cozida, '
          'era o elo de celebração política, união e honra.',
      curiosidadeLinguistica:
          'O verbo "Moquear" e o prato "Moqueca" vêm de "Mokaém" — o ato de defumar lentamente peixes e caças '
          'sobre a fumaça perfumada de lenhas nobres para conservação prolongada.',
      expressaoDestaque: 'Mokaém pyra pirá katu!',
      expressaoTraducao: 'O peixe moqueado na brasa está excelente!',
    ),
    7: const ChapterCulturalGuide(
      numero: 7,
      titulo: 'Família, Infância e Sociedade',
      subtitulo: 'O Cuidado Coletivo e a Transmissão dos Saberes',
      icone: '👨‍👩‍👧‍👦',
      saberesAncestrais:
          'As crianças Tupi cresciam livres, aprendendo por imitação direta dos mais velhos. Não existiam castigos '
          'físicos: as crianças acompanhavam os pais na roça, no rio e nas expedições, recebendo pequenos arcos '
          'e cestos para exercitar a autonomia desde os primeiros anos de vida com imenso carinho comunitário.',
      curiosidadeLinguistica:
          'O parentesco Tupi é altamente estruturado: distingue irmão mais velho (tyke\'yra) de irmão mais novo '
          '(tybyra) para homens, reforçando o respeito e a responsabilidade intergeracional.',
      expressaoDestaque: 'Che sy, che ruba, che ta\'yra.',
      expressaoTraducao: 'Minha mãe, meu pai e meu amado filho.',
    ),
    8: const ChapterCulturalGuide(
      numero: 8,
      titulo: 'Grafismos Corporais e Ritos de Passagem',
      subtitulo: 'A Geometria Sagrada de Urucum e Genipapo',
      icone: '🎨',
      saberesAncestrais:
          'O corpo Tupi era uma tela de linguagem visual. O vermelho do urucum (uruku) e o preto azulado do '
          'genipapo (îandypaba) não eram mero adorno: eram armaduras espirituais contra energias nocivas e picadas '
          'de insetos, demarcando a linhagem, a maturação social e as conquistas corajosas de cada guerreiro.',
      curiosidadeLinguistica:
          'O termo "Pintar" ou "Escrever" em Tupi é o mesmo verbo: "Kûabara" ou "Kûatiara", revelando que a '
          'escrita e o grafismo corporal eram compreendidos como a mesmíssima arte de registrar significados.',
      expressaoDestaque: 'Uruku t-eté pe omoatyrõ.',
      expressaoTraducao: 'O urucum escarlate orna e protege o corpo.',
    ),
    9: const ChapterCulturalGuide(
      numero: 9,
      titulo: 'O Pajé e a Medicina Espiritual',
      subtitulo: 'A Sabedoria dos Sonhos e o Maracá Sagrado',
      icone: '🦅',
      saberesAncestrais:
          'O Pajé (Paîé) era o curador, filósofo e diplomata espiritual da aldeia. Com seu maracá repleto de sementes '
          'sagradas e a fumaça de tabaco ancestral (petym), ele viajava em sonhos e cantos rituais para diagnosticar '
          'desequilíbrios na saúde física e espiritual da comunidade, mantendo a harmonia entre o visível e o invisível.',
      curiosidadeLinguistica:
          'A palavra "Pajé" veio diretamente do Tupi "Paîé". Seu instrumento, "Maracá", deu origem ao nome do '
          'famoso estádio do Maracanã ("semelhante ao maracá" ou "rio das maracanãs").',
      expressaoDestaque: 'Paîé maracá omonhyrõ tekó.',
      expressaoTraducao: 'O som do maracá do pajé harmoniza a existência.',
    ),
    10: const ChapterCulturalGuide(
      numero: 10,
      titulo: 'A Honra Guerreira e a Defesa da Terra',
      subtitulo: 'O Arco (Ybyrapára) e a Coragem Indômita',
      icone: '🏹',
      saberesAncestrais:
          'Para o guerreiro Tupi (Marombyra), a coragem não se media pelo rancor, mas pela defesa leal de sua gente '
          'e de seu território ancestral. Seus arcos de pau-brasil, altos como o próprio guerreiro, disparavam flechas '
          'emplumadas com precisão em meio à folhagem fechada. A glória estava na bravura demonstrada e na lealdade.',
      curiosidadeLinguistica:
          '"Ybyrapára" (arco) é formado por "Ybyrá" (madeira, vara) + "Pára" (curvada, arqueada). '
          'A linguagem Tupi descreve os objetos com admirável precisão estrutural e poética.',
      expressaoDestaque: 'Marombyra py\'aguasu n\'osyny.',
      expressaoTraducao: 'O guerreiro de coração valente nunca recua.',
    ),
    11: const ChapterCulturalGuide(
      numero: 11,
      titulo: 'Astronomias Indígenas e Constelações de Pindorama',
      subtitulo: 'O Homem Velho, a Ema e o Caminho da Anta',
      icone: '🌌',
      saberesAncestrais:
          'Muito antes dos telescópios europeus, os sábios Tupi olhavam para o céu noturno e viam gigantescas '
          'figuras desenhadas não pelas estrelas isoladas, mas pelas nuvens escuras de poeira da Via Láctea (Tupĩ). '
          'A Constelação da Ema (Guyra-Gûasu) anunciava a chegada da estação chuvosa no Sul, e o Homem Velho '
          '(Tuîbabi) orientava os plantios com exatidão milimétrica.',
      curiosidadeLinguistica:
          '"Jasy" é a Lua e "Kûarasy" é o Sol. As marés eram compreendidas perfeitamente como filhas da atração de Jasy, '
          'um conhecimento astronômico e ecológico refinadíssimo.',
      expressaoDestaque: 'Jasy ohesapé pyhare pyahu.',
      expressaoTraducao: 'A lua cheia ilumina a noite límpida.',
    ),
    12: const ChapterCulturalGuide(
      numero: 12,
      titulo: 'Canto, Dança e Festividades Ancestrais',
      subtitulo: 'Poracé: O Ritual que Une os Corações',
      icone: '🪘',
      saberesAncestrais:
          'A dança e o canto Tupi (Poracé) eram celebrações da vida, da colheita e das vitórias. Homens, mulheres '
          'e jovens uniam-se em círculos compassados na ocara ao som de flautas de taquara (mimbira) e chocalhos '
          'de tornozelo feitos de cascas de sementes, entoando estrofes poéticas que contavam a história das origens.',
      curiosidadeLinguistica:
          'O Tupi Antigo era uma língua naturalmente musical e rítmica, rica em aliterações e assonâncias, onde o '
          'ritmo vocal acompanhava o compasso dos passos no chão batido da terra.',
      expressaoDestaque: 'Îandé poracé tororype taba py!',
      expressaoTraducao: 'Dancemos todos com imensa alegria na aldeia!',
    ),
    13: const ChapterCulturalGuide(
      numero: 13,
      titulo: 'As Estações, o Clima e a Roça Tradicional',
      subtitulo: 'O Cultivo Regenerativo da Mandioca',
      icone: '🌱',
      saberesAncestrais:
          'A agricultura itinerante (coivara tradicional de baixo impacto) respeitava o descanso do solo por anos. '
          'As roças combinavam mandioca, milho (abati), abóbora (îerimum) e feijão (kumandá) em consórcio biológico '
          'perfeito, mantendo a umidade da terra e dispensando fertilizantes químicos.',
      curiosidadeLinguistica:
          'Mandioca em Tupi é "Mani\'oka", nome nascido da lenda da menina Mani, que faleceu e de cuja sepultura '
          'brotou a raiz que salvou toda a nação da fome.',
      expressaoDestaque: 'Abati katu oîemombuku.',
      expressaoTraducao: 'O milho dourado cresce forte e farto.',
    ),
    14: const ChapterCulturalGuide(
      numero: 14,
      titulo: 'Artesanato, Trançados e Cerâmicas',
      subtitulo: 'A Maestria das Mãos e o Barro Ancestral',
      icone: '🏺',
      saberesAncestrais:
          'As ceramistas Tupi dominavam a técnica dos roletes de argila (sem torno mecânico), moldando igaçabas '
          'gigantes para fermentação de bebidas e urnas funerárias decoradas com engobes vermelhos e brancos. '
          'O trançado de taquara e palha gerava balaios, urupemas e redes tão resistentes que duravam décadas.',
      curiosidadeLinguistica:
          'O termo "Igaçaba" (recipiente de barro) deu origem a muitas palavras do vocabulário regional brasileiro, '
          'assim como "Cuia" (Kuîa) e "Cesto" (Panakũ).',
      expressaoDestaque: 'Kuîa py y poranga tekokatu.',
      expressaoTraducao: 'Na cuia pura, a água traz saúde e bem-estar.',
    ),
    15: const ChapterCulturalGuide(
      numero: 15,
      titulo: 'O Oceano, as Ilhas e o Mar Infinito',
      subtitulo: 'Paranaguasu: O Grande Espelho de Águas',
      icone: '🌊',
      saberesAncestrais:
          'Os povos litorâneos (Tupinambás, Tupiniquins e Carijós) tinham intimidade total com o oceano atlântico '
          '(Paranaguasu). Coletavam mariscos formando os monumentais sambaquis, viajavam entre arquipélagos costeiros '
          'e conheciam o comportamento dos ventos alísios com precisão náutica invejável.',
      curiosidadeLinguistica:
          '"Paranaguá" significa "Grande enseada de mar" (Paraná + Kûá), e "Ipanema" significa "Água ruim para pescar" '
          '(Y + Panema). A toponímia brasileira é um museu a céu aberto da língua Tupi.',
      expressaoDestaque: 'Paranaguasu piranga jasy oîatá.',
      expressaoTraducao: 'Sobre o mar imenso, a lua caminha gloriosa.',
    ),
    16: const ChapterCulturalGuide(
      numero: 16,
      titulo: 'Narrativas e o Princípio Criador',
      subtitulo: 'Monã, Maire-Monã e a Criação do Mundo',
      icone: '✨',
      saberesAncestrais:
          'Nas grandes narrativas míticas, o demiurgo Monã criou o mundo com beleza e pureza. Quando os seres humanos '
          'desrespeitaram as leis sagradas da terra e tornaram-se arrogantes, as águas de Somondabu lavaram a terra, '
          'renovando o ciclo vital e ensinando a humanidade sobre a humildade perante o cosmos.',
      curiosidadeLinguistica:
          'Narrar histórias em Tupi envolve marcadores de evidencialidade que indicam se o narrador presenciou o '
          'fato ou se o recebeu dos seus bisavós, valorizando a fidelidade da tradição oral.',
      expressaoDestaque: 'Monã yby porang omoeté.',
      expressaoTraducao: 'O criador venerou a terra com bondade e beleza.',
    ),
    17: const ChapterCulturalGuide(
      numero: 17,
      titulo: 'Diplomacia, Alianças e a Palavra Sagrada',
      subtitulo: 'O Cunhadio e os Pactos de Fraternidade',
      icone: '🕊️',
      saberesAncestrais:
          'A diplomacia entre aldeias era selada por meio do parentesco e do compadrio tradicional (o cunhadio). '
          'A palavra de um ancião ou morubixaba tinha força de lei absoluta: o descumprimento de um acordo era a maior '
          'desonra social possível, pois a verdade (Aîeté) era o alicerce de sustentação de toda a taba.',
      curiosidadeLinguistica:
          'A palavra "Aîeté" expressa verdade absoluta, autenticidade e retidão moral. Não é apenas "verdadeiro", '
          'mas aquilo que se harmoniza perfeitamente com a realidade das coisas.',
      expressaoDestaque: 'Che ñe\'ẽ aîeté, n\'aîapu\'i.',
      expressaoTraducao: 'Minha palavra é reta e verdadeira, jamais minto.',
    ),
    18: const ChapterCulturalGuide(
      numero: 18,
      titulo: 'Liderança Tradicional e os Morubixabas',
      subtitulo: 'A Autoridade que Nasce da Sabedoria e da Generosidade',
      icone: '👑',
      saberesAncestrais:
          'O cacique ou chefe de guerra (Morubixaba) não acumulava bens materiais. Ao contrário dos monarcas europeus, '
          'sua liderança apoiava-se na eloquência, na coragem e na generosidade de doar tudo o que possuía aos mais '
          'necessitados. Quem não sabia ouvir os conselhos dos anciãos não podia guiar seu povo.',
      curiosidadeLinguistica:
          '"Morubixaba" deriva do verbo que expressa "fazer-se ver pela excelência e bondade", retratando a '
          'liderança como um serviço devotado à coletividade e não como um privilégio de dominação.',
      expressaoDestaque: 'Morubixaba oîukyrã oipota taba supé.',
      expressaoTraducao: 'O sábio líder busca sempre a prosperidade de sua gente.',
    ),
    19: const ChapterCulturalGuide(
      numero: 19,
      titulo: 'A Terra Sem Mal (Yvy Marã\'ey)',
      subtitulo: 'A Busca Espiritual e a Transcendência',
      icone: '🕊️',
      saberesAncestrais:
          'O horizonte espiritual Tupi-Guarani culmina na crença da "Terra Sem Mal" (Yvy Marã\'ey): um lugar sagrado '
          'onde não há dor, velhice, fome ou discórdia. Lideradas por pajés inspirados, aldeias inteiras realizavam '
          'peregrinações pacíficas dançando e cantando rumo ao oriente, em busca de comunhão com a divindade.',
      curiosidadeLinguistica:
          '"Yvy" (terra) + "Marã" (mal, discórdia, corrupção) + "-\'ey" (ausência, sem). A morfologia Tupi expressa '
          'filosofias profundas com admirável síntese poética.',
      expressaoDestaque: 'Îasó Yvy Marã\'ey katy!',
      expressaoTraducao: 'Caminhemos rumo à Terra Sagrada Sem Males!',
    ),
    20: const ChapterCulturalGuide(
      numero: 20,
      titulo: 'O Legado Eterno e o Tupi no Século XXI',
      subtitulo: 'A Presença Viva dos Povos Originários no Brasil',
      icone: '🌳',
      saberesAncestrais:
          'O Tupi Antigo não desapareceu: ele vive em nossa boca todos os dias. Dos nomes de cidades (Ibirapuera, '
          'Piracicaba, Niterói, Taubaté) aos animais, plantas e rios do Brasil, as palavras indígenas moldaram a '
          'alma, a fonética e o imaginário nacional. Honrar essa língua é reconhecer e respeitar os povos originários '
          'que continuam zelando pelas florestas e por nosso futuro comum.',
      curiosidadeLinguistica:
          'Milhares de vocábulos do português do Brasil são Tupi puro: Pipoca, Caipira, Guanabara, Curitiba, Jacaré, '
          'Tamanduá, Capivara e Poti. O Brasil fala Tupi sem perceber.',
      expressaoDestaque: 'Tupi ñe\'ẽ nomanói, oikové tekobe katúpe!',
      expressaoTraducao: 'A língua Tupi não morreu: ela vive com força e dignidade!',
    ),
  };
}
