import 'dart:math' as math;

/// Utilitários de embaralhamento seguro e estável para exercícios didáticos.
class StableShuffle {
  /// Gera uma permutação garantida como desarrajo (derangement, sem pontos fixos)
  /// para listas com 2 ou mais elementos. Garante que nenhum item permaneça no mesmo índice original.
  static List<T> derangedShuffle<T>(List<T> list, {math.Random? random}) {
    if (list.length <= 1) return List<T>.from(list);
    final rng = random ?? math.Random();
    final n = list.length;

    // Tenta gerar por Fisher-Yates com verificação estrita de desarrajo
    for (int tentativa = 0; tentativa < 100; tentativa++) {
      final copy = List<T>.from(list);
      for (int i = n - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final temp = copy[i];
        copy[i] = copy[j];
        copy[j] = temp;
      }

      bool hasFixedPoint = false;
      for (int i = 0; i < n; i++) {
        if (copy[i] == list[i]) {
          hasFixedPoint = true;
          break;
        }
      }

      if (!hasFixedPoint) {
        return copy;
      }
    }

    // Fallback determinístico garantido de deslocamento circular (derangement garantido)
    final shift = 1 + rng.nextInt(n - 1);
    final fallback = List<T>.generate(n, (i) => list[(i + shift) % n]);
    return fallback;
  }

  /// Gera uma lista de índices de 0 a length-1 garantindo que nenhum índice fique na mesma posição.
  static List<int> derangedIndices(int length, {math.Random? random}) {
    final original = List<int>.generate(length, (i) => i);
    return derangedShuffle(original, random: random);
  }
}
