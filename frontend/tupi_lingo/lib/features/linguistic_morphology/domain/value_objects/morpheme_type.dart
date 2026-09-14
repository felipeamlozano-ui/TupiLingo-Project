/// RFC-012B Chapter 26: Types of morphemes in Tupi linguistic morphology.
enum MorphemeType {
  root,
  prefix,
  suffix,
  infix,
  particle;

  String get displayName {
    switch (this) {
      case MorphemeType.root:
        return 'Raiz / Radical';
      case MorphemeType.prefix:
        return 'Prefixo';
      case MorphemeType.suffix:
        return 'Sufixo';
      case MorphemeType.infix:
        return 'Infixo';
      case MorphemeType.particle:
        return 'Partícula';
    }
  }

  static MorphemeType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'root':
      case 'raiz':
        return MorphemeType.root;
      case 'prefix':
      case 'prefixo':
        return MorphemeType.prefix;
      case 'suffix':
      case 'sufixo':
        return MorphemeType.suffix;
      case 'infix':
      case 'infixo':
        return MorphemeType.infix;
      case 'particle':
      case 'particula':
      default:
        return MorphemeType.particle;
    }
  }
}
