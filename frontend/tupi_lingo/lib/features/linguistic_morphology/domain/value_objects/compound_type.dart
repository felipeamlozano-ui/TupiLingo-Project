/// Types of lexical composition in Tupi compound words.
enum CompoundType {
  additive,     // e.g. tatá (fogo) + endy (chama)
  subordinate,  // e.g. y (água) + gara (recipiente) -> canoa (recipiente de água)
  coordinative; // e.g. mba'e (coisa) + poru (usar)

  static CompoundType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'additive':
      case 'aditivo':
        return CompoundType.additive;
      case 'subordinate':
      case 'subordinativo':
        return CompoundType.subordinate;
      case 'coordinative':
      case 'coordenativo':
      default:
        return CompoundType.coordinative;
    }
  }
}
