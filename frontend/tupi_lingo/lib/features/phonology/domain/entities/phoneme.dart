import 'package:flutter/foundation.dart';

/// Class of phoneme in Tupi phonology.
enum PhonemeClass { vowel, consonant, semivowel, nasal }

/// Canonical representation of a Tupi phoneme in the International Phonetic Alphabet (IPA).
@immutable
class Phoneme {
  final String ipaSymbol;
  final PhonemeClass phonemeClass;
  final bool isNasal;
  final String? placeOfArticulation;
  final String? mannerOfArticulation;

  const Phoneme({
    required this.ipaSymbol,
    required this.phonemeClass,
    this.isNasal = false,
    this.placeOfArticulation,
    this.mannerOfArticulation,
  });

  @override
  String toString() => '/$ipaSymbol/';
}
