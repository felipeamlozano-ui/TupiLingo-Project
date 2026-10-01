/// Repositório dinâmico de vocabulário atrelado estritamente à progressão real da trilha.
class VocabularyBankItem {
  final String tupi;
  final String pt;
  final String pronuncia;
  final String cat;
  final int capituloNumero;
  final int licaoNumero;

  const VocabularyBankItem({
    required this.tupi,
    required this.pt,
    required this.pronuncia,
    required this.cat,
    required this.capituloNumero,
    this.licaoNumero = 1,
  });

  Map<String, String> toMap() => {
        'tupi': tupi,
        'pt': pt,
        'pronuncia': pronuncia,
        'cat': cat,
      };
}

class TrailVocabularyRepository {
  static final List<VocabularyBankItem> allTrailVocabulary = [
    // Capítulo 1: Saudações e Encontros
    const VocabularyBankItem(
      tupi: 'Kauê',
      pt: 'Olá / Salve',
      pronuncia: 'ka-u-Ê',
      cat: 'Saudações',
      capituloNumero: 1,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Ereîur-pe',
      pt: 'Vieste? (Como vai?)',
      pronuncia: 'e-re-i-UR-pe',
      cat: 'Saudações',
      capituloNumero: 1,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Pa\'ĩ',
      pt: 'Senhor / Tratamento respeitoso',
      pronuncia: 'pa-IN',
      cat: 'Saudações',
      capituloNumero: 1,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Aîeté',
      pt: 'Verdadeiro / Sim',
      pronuncia: 'a-ye-TÉ',
      cat: 'Geral',
      capituloNumero: 1,
      licaoNumero: 2,
    ),
    const VocabularyBankItem(
      tupi: 'Neĩ',
      pt: 'Vamos / Sim',
      pronuncia: 'NE-in',
      cat: 'Saudações',
      capituloNumero: 1,
      licaoNumero: 2,
    ),

    // Capítulo 2: A Taba e a Comunidade
    const VocabularyBankItem(
      tupi: 'Taba',
      pt: 'Aldeia / Povoado',
      pronuncia: 'TA-ba',
      cat: 'Comunidade',
      capituloNumero: 2,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Oka',
      pt: 'Casa / Habitação',
      pronuncia: 'O-ka',
      cat: 'Comunidade',
      capituloNumero: 2,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Abá',
      pt: 'Homem / Pessoa',
      pronuncia: 'a-BÁ',
      cat: 'Pessoas',
      capituloNumero: 2,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Kunhã',
      pt: 'Mulher',
      pronuncia: 'ku-NHÃ',
      cat: 'Pessoas',
      capituloNumero: 2,
      licaoNumero: 2,
    ),
    const VocabularyBankItem(
      tupi: 'Pitanga',
      pt: 'Criança / Bebê',
      pronuncia: 'pi-TAN-ga',
      cat: 'Pessoas',
      capituloNumero: 2,
      licaoNumero: 2,
    ),

    // Capítulo 3: Rios e Navegação
    const VocabularyBankItem(
      tupi: 'Y',
      pt: 'Água / Rio',
      pronuncia: 'Y (gutural [ɨ])',
      cat: 'Natureza',
      capituloNumero: 3,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Paraná',
      pt: 'Mar / Grande Rio',
      pronuncia: 'pa-ra-NÁ',
      cat: 'Natureza',
      capituloNumero: 3,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Pirá',
      pt: 'Peixe',
      pronuncia: 'pi-RÁ',
      cat: 'Fauna',
      capituloNumero: 3,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Ygarata',
      pt: 'Canoa / Embarcação',
      pronuncia: 'y-ga-RA-ta',
      cat: 'Ferramentas',
      capituloNumero: 3,
      licaoNumero: 2,
    ),

    // Capítulo 4: Mata Atlântica e Botânica
    const VocabularyBankItem(
      tupi: 'Ka\'a',
      pt: 'Mata / Floresta',
      pronuncia: 'ka-\'A',
      cat: 'Natureza',
      capituloNumero: 4,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Ybyrá',
      pt: 'Árvore / Madeira',
      pronuncia: 'y-by-RÁ',
      cat: 'Natureza',
      capituloNumero: 4,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Potyba',
      pt: 'Flor',
      pronuncia: 'po-TY-ba',
      cat: 'Natureza',
      capituloNumero: 4,
      licaoNumero: 2,
    ),
    const VocabularyBankItem(
      tupi: 'Ybyraîba',
      pt: 'Fruta / Fruto da árvore',
      pronuncia: 'y-by-ra-I-ba',
      cat: 'Alimentos',
      capituloNumero: 4,
      licaoNumero: 2,
    ),

    // Capítulo 5: Fauna e Animais Sagrados
    const VocabularyBankItem(
      tupi: 'Jagûara',
      pt: 'Onça / Fera',
      pronuncia: 'ja-gwa-RA',
      cat: 'Fauna',
      capituloNumero: 5,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Gûyrá',
      pt: 'Pássaro / Ave',
      pronuncia: 'gwi-RÁ',
      cat: 'Fauna',
      capituloNumero: 5,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Tatu',
      pt: 'Tatu (armadura dura)',
      pronuncia: 'ta-TU',
      cat: 'Fauna',
      capituloNumero: 5,
      licaoNumero: 2,
    ),
    const VocabularyBankItem(
      tupi: 'Tapira',
      pt: 'Anta',
      pronuncia: 'ta-PI-ra',
      cat: 'Fauna',
      capituloNumero: 5,
      licaoNumero: 2,
    ),

    // Capítulo 6: Fogo e Culinária
    const VocabularyBankItem(
      tupi: 'Tata',
      pt: 'Fogo / Chama',
      pronuncia: 'ta-TA',
      cat: 'Natureza',
      capituloNumero: 6,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Tatagûasu',
      pt: 'Fogueira grande',
      pronuncia: 'ta-ta-gwa-SU',
      cat: 'Natureza',
      capituloNumero: 6,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Mani\'oka',
      pt: 'Mandioca',
      pronuncia: 'ma-ni-\'O-ka',
      cat: 'Alimentos',
      capituloNumero: 6,
      licaoNumero: 2,
    ),
    const VocabularyBankItem(
      tupi: 'U\'i',
      pt: 'Farinha',
      pronuncia: 'u-\'I',
      cat: 'Alimentos',
      capituloNumero: 6,
      licaoNumero: 2,
    ),

    // Capítulo 7 em diante: Cosmologia e Rituais
    const VocabularyBankItem(
      tupi: 'Kûarasy',
      pt: 'Sol',
      pronuncia: 'kwa-ra-SY',
      cat: 'Natureza',
      capituloNumero: 7,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Jasy',
      pt: 'Lua',
      pronuncia: 'ja-SY',
      cat: 'Natureza',
      capituloNumero: 7,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Tupã',
      pt: 'Trovão / O som sagrado',
      pronuncia: 'tu-PAN',
      cat: 'Espiritualidade',
      capituloNumero: 8,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Paîé',
      pt: 'Pajé / Curador tradicional',
      pronuncia: 'pa-i-É',
      cat: 'Espiritualidade',
      capituloNumero: 9,
      licaoNumero: 1,
    ),
    const VocabularyBankItem(
      tupi: 'Morubixaba',
      pt: 'Líder da aldeia / Cacique',
      pronuncia: 'mo-ru-bi-XA-ba',
      cat: 'Comunidade',
      capituloNumero: 10,
      licaoNumero: 1,
    ),
  ];

  /// Retorna os itens de vocabulário desbloqueados pelo usuário com base no maior capítulo alcançado na trilha.
  /// O Capítulo 1 está sempre desbloqueado como ponto de partida canônico.
  static List<VocabularyBankItem> getUnlockedVocabulary(int highestChapterReached) {
    final maxCap = highestChapterReached < 1 ? 1 : highestChapterReached;
    return allTrailVocabulary.where((item) => item.capituloNumero <= maxCap).toList();
  }
}
