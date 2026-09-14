/// Converts standard Tupi orthography into canonical IPA representations (ADR-007).
class IPAConverter {
  /// Converts [tupiText] into an International Phonetic Alphabet (IPA) transcript.
  String convertToIPA(String tupiText) {
    if (tupiText.trim().isEmpty) return '';

    String s = tupiText.toLowerCase().trim();

    // 1. Digraphs and complex phones
    s = s.replaceAll('gû', 'ɡʷ');
    s = s.replaceAll('gu', 'ɡʷ');
    s = s.replaceAll('nh', 'ɲ');
    s = s.replaceAll('mb', 'ᵐb');
    s = s.replaceAll('nd', 'ⁿd');
    s = s.replaceAll('ng', 'ᵑɡ');

    // 2. Glottal stop
    s = s.replaceAll("'", 'ʔ');

    // 3. Central vowel y / ɨ
    s = s.replaceAll('ỹ', 'ɨ̃');
    s = s.replaceAll('y', 'ɨ');

    // 4. Consonants
    s = s.replaceAll('g', 'ɡ');
    s = s.replaceAll('x', 'ʃ');
    s = s.replaceAll('b', 'β');
    s = s.replaceAll('r', 'ɾ');
    s = s.replaceAll('j', 'ʒ');

    // 5. Nasal vowels
    s = s.replaceAll('ã', 'ã');
    s = s.replaceAll('ẽ', 'ẽ');
    s = s.replaceAll('ĩ', 'ĩ');
    s = s.replaceAll('õ', 'õ');
    s = s.replaceAll('ũ', 'ũ');

    return '/$s/';
  }
}

/// Computes phonetic distance based on IPA string comparison.
class PhoneticSimilarityEngine {
  final IPAConverter converter;

  PhoneticSimilarityEngine({IPAConverter? converter})
      : converter = converter ?? IPAConverter();

  /// Computes phonetic similarity score in range [0.0, 1.0].
  double calculatePhoneticSimilarity(String wordA, String wordB) {
    final ipaA = converter.convertToIPA(wordA).replaceAll('/', '');
    final ipaB = converter.convertToIPA(wordB).replaceAll('/', '');

    if (ipaA == ipaB) return 1.0;

    final distance = _levenshtein(ipaA, ipaB);
    final maxLen = ipaA.length > ipaB.length ? ipaA.length : ipaB.length;
    if (maxLen == 0) return 0.0;

    final ratio = 1.0 - (distance / maxLen);
    return ratio.clamp(0.0, 1.0);
  }

  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = (v1[j] + 1 < v0[j + 1] + 1)
            ? (v1[j] + 1 < v0[j] + cost ? v1[j] + 1 : v0[j] + cost)
            : (v0[j + 1] + 1 < v0[j] + cost ? v0[j + 1] + 1 : v0[j] + cost);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }
}
