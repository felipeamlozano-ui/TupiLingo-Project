/// RFC-012B Chapter 26: Grammatical and semantic functions of Tupi affixes.
enum MorphologicalFunction {
  agentive,       // -sara / -hara (aquele que faz, agente)
  locative,       // -aba (lugar de, tempo de, instrumento)
  diminutive,     // -'i / -mirĩ (pequeno)
  augmentative,   // -gûasu / -usu (grande)
  nominalizer,    // -ba / -a (transforma verbo em substantivo)
  causativizer,   // mo- / mbo- (fazer com que seja, causar)
  tense,          // -ram / -pûer (futuro / passado)
  negation,       // n(a)-...-i (não)
  reciprocal,     // jo- / yo- (mútuo, uns aos outros)
  relational,     // r- / s- / t- (prefixos de classe relacional)
  aspect,         // completivo, durativo
  other;

  static MorphologicalFunction fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'agentive':
      case 'agente':
        return MorphologicalFunction.agentive;
      case 'locative':
      case 'locativo':
        return MorphologicalFunction.locative;
      case 'diminutive':
      case 'diminutivo':
        return MorphologicalFunction.diminutive;
      case 'augmentative':
      case 'aumentativo':
        return MorphologicalFunction.augmentative;
      case 'nominalizer':
      case 'nominalizador':
        return MorphologicalFunction.nominalizer;
      case 'causativizer':
      case 'causativo':
        return MorphologicalFunction.causativizer;
      case 'tense':
      case 'tempo':
        return MorphologicalFunction.tense;
      case 'negation':
      case 'negacao':
        return MorphologicalFunction.negation;
      case 'reciprocal':
      case 'reciproco':
        return MorphologicalFunction.reciprocal;
      case 'relational':
      case 'relacional':
        return MorphologicalFunction.relational;
      case 'aspect':
      case 'aspecto':
        return MorphologicalFunction.aspect;
      default:
        return MorphologicalFunction.other;
    }
  }
}
