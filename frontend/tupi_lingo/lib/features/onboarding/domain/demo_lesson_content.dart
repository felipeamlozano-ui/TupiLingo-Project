/// Representa os tipos de passos da lição demonstrativa inicial.
enum DemoStepType {
  vocabCard,
  multipleChoice,
  matching,
  fillInTheBlank,
}

/// Item de exercício da lição demo local de 90 segundos.
class DemoStepItem {
  final DemoStepType type;
  final String title;
  final String? subtitle;
  final String? tupiWord;
  final String? portugueseWord;
  final String? pronunciation;
  final String? explanation;
  final List<String>? options;
  final int? correctOptionIndex;
  final Map<String, String>? matchingPairs;
  final String? sentenceWithBlank;
  final String? correctBlankAnswer;
  final List<String>? wordBank;

  const DemoStepItem({
    required this.type,
    required this.title,
    this.subtitle,
    this.tupiWord,
    this.portugueseWord,
    this.pronunciation,
    this.explanation,
    this.options,
    this.correctOptionIndex,
    this.matchingPairs,
    this.sentenceWithBlank,
    this.correctBlankAnswer,
    this.wordBank,
  });
}

/// Conteúdo estático e autêntico da lição demo de 90 segundos do TupiLingo.
/// Baseado no acervo e vocabulário do Capítulo 1 (Saudações e Encontros).
class DemoLessonContent {
  static const List<DemoStepItem> steps = [
    // 1. Apresentação da primeira palavra sagrada
    DemoStepItem(
      type: DemoStepType.vocabCard,
      title: 'Sua primeira palavra em Tupi!',
      subtitle: 'Toque para ouvir como se pronuncia.',
      tupiWord: 'Aué',
      portugueseWord: 'Olá / Salve',
      pronunciation: 'a-u-É',
      explanation: 'É a saudação de acolhimento e respeito do povo Tupi ao encontrar alguém.',
    ),

    // 2. Reconhecimento Imediato (Múltipla Escolha)
    DemoStepItem(
      type: DemoStepType.multipleChoice,
      title: 'O que significa "Aué"?',
      options: [
        'Adeus / Até logo',
        'Olá / Salve',
        'Água fresca',
        'Muito obrigado',
      ],
      correctOptionIndex: 1,
      explanation: 'Excelente! "Aué" é a forma clássica de dizer "Olá" ou "Salve" em Tupi Antigo.',
    ),

    // 3. Novo termo: "Ereîur pe?"
    DemoStepItem(
      type: DemoStepType.vocabCard,
      title: 'Como perguntar como a pessoa está?',
      subtitle: 'Uma expressão muito calorosa.',
      tupiWord: 'Ereîur pe?',
      portugueseWord: 'Você veio? (Como vai?)',
      pronunciation: 'e-re-i-UR pe',
      explanation: 'Literalmente significa "Você veio?", usado afetuosamente como "Como vai você?".',
    ),

    // 4. Associação de Conceitos (Matching)
    DemoStepItem(
      type: DemoStepType.matching,
      title: 'Conecte os pares correspondentes',
      subtitle: 'Toque em uma palavra em Tupi e depois na sua tradução.',
      matchingPairs: {
        'Aué': 'Olá / Salve',
        'Ereîur pe?': 'Como vai?',
        'Pa\'ĩ': 'Senhor (respeito)',
      },
      explanation: 'Perfeito! Você já memorizou três das saudações mais importantes.',
    ),

    // 5. Produção ativa: Completar a frase
    DemoStepItem(
      type: DemoStepType.fillInTheBlank,
      title: 'Complete a saudação',
      subtitle: 'Cumprimente o ancião com respeito:',
      sentenceWithBlank: '____, pa\'ĩ!',
      correctBlankAnswer: 'Aué',
      wordBank: ['Aué', 'Taba', 'Oka', 'Y'],
      explanation: '"Aué, pa\'ĩ!" significa "Salve, meu senhor!" ou "Olá, sábio!".',
    ),
  ];
}
