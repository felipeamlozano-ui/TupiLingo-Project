import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morpheme.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morphological_function.dart';

/// Rule-based morphological parser for Tupi languages.
/// Breaks words down into prefixes, roots, and suffixes according to documented rules.
class MorphologyParser {
  final List<MorphologicalRule> _rules;

  MorphologyParser({List<MorphologicalRule>? rules})
      : _rules = rules ?? _defaultRules;

  /// Decomposes [word] into its constituent morphemes.
  MorphologicalAnalysis parse(String word, {int? variantId}) {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) {
      return MorphologicalAnalysis(
        wordLabel: word,
        rootSurface: '',
        morphemes: const [],
        explanationPt: 'Palavra vazia',
        variantId: variantId,
      );
    }

    String remaining = cleanWord;
    final List<Morpheme> prefixes = [];
    final List<Morpheme> suffixes = [];

    // 1. Match prefixes from left
    bool foundPrefix = true;
    while (foundPrefix && remaining.length > 2) {
      foundPrefix = false;
      for (final rule in _rules.where((r) => r.morphemeType == MorphemeType.prefix)) {
        final candidates = [rule.morphemeSurface, ...rule.allomorphs];
        for (final cand in candidates) {
          if (remaining.startsWith(cand) && remaining.length > cand.length) {
            prefixes.add(Morpheme(
              id: rule.id,
              surface: cand,
              type: MorphemeType.prefix,
              meaning: rule.meaningPt,
              function: rule.morphologicalFunction,
              variantId: variantId,
            ));
            remaining = remaining.substring(cand.length);
            foundPrefix = true;
            break;
          }
        }
        if (foundPrefix) break;
      }
    }

    // 2. Match suffixes from right
    bool foundSuffix = true;
    while (foundSuffix && remaining.length > 2) {
      foundSuffix = false;
      for (final rule in _rules.where((r) => r.morphemeType == MorphemeType.suffix)) {
        final candidates = [rule.morphemeSurface, ...rule.allomorphs];
        for (final cand in candidates) {
          if (remaining.endsWith(cand) && remaining.length > cand.length) {
            suffixes.insert(
              0,
              Morpheme(
                id: rule.id,
                surface: cand,
                type: MorphemeType.suffix,
                meaning: rule.meaningPt,
                function: rule.morphologicalFunction,
                variantId: variantId,
              ),
            );
            remaining = remaining.substring(0, remaining.length - cand.length);
            foundSuffix = true;
            break;
          }
        }
        if (foundSuffix) break;
      }
    }

    // 3. Clean leading and trailing hyphens from remaining root
    remaining = remaining.replaceAll(RegExp(r'^-+|-+$'), '').trim();

    // The remainder is treated as the root / lexical base
    final rootMorpheme = Morpheme(
      id: 'root_$remaining',
      surface: remaining,
      type: MorphemeType.root,
      meaning: _inferRootMeaning(remaining),
      function: MorphologicalFunction.other,
      variantId: variantId,
    );

    final allMorphemes = [...prefixes, rootMorpheme, ...suffixes];

    // Compute explanation
    final breakdown = allMorphemes.map((m) => '${m.surface} (${m.meaning})').join(' + ');
    final explanation = '$word = $breakdown';

    return MorphologicalAnalysis(
      wordLabel: word,
      rootSurface: remaining,
      morphemes: allMorphemes,
      confidence: (prefixes.isNotEmpty || suffixes.isNotEmpty) ? 0.92 : 0.80,
      explanationPt: explanation,
      variantId: variantId,
    );
  }

  String _inferRootMeaning(String root) {
    // Standard basic lexical roots lookup from Old Tupi academic vocabulary
    switch (root) {
      case 'y':
      case 'i':
        return 'água / rio';
      case 'gara':
      case 'gára':
        return 'recipiente / canoa';
      case 'paranã':
      case 'parana':
        return 'mar / grande rio';
      case 'oka':
      case 'oga':
        return 'casa / habitação';
      case 'abá':
      case 'aba':
        return 'homem / ser humano';
      case 'kunhã':
      case 'cunha':
        return 'mulher';
      case 'itá':
      case 'ita':
        return 'pedra / metal';
      case 'ka\'a':
      case 'kaa':
        return 'mata / floresta';
      case 'tatá':
      case 'tata':
        return 'fogo';
      case 'pira':
        return 'peixe';
      case 'so\'o':
      case 'soo':
        return 'caça / animal terrestre';
      case 'endy':
        return 'chama / luz';
      case 'puku':
        return 'comprido / longo';
      default:
        return 'radical base';
    }
  }

  static final List<MorphologicalRule> _defaultRules = [
    // Diminutive
    const MorphologicalRule(
      id: 'rule_dim_i',
      morphemeSurface: "'ĩ",
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.diminutive,
      meaningPt: 'pequeno(a)',
      allomorphs: ['-i', "'i", 'mirĩ'],
      sourceReference: 'Navarro 1998, p. 52',
    ),
    // Augmentative
    const MorphologicalRule(
      id: 'rule_aug_wasu',
      morphemeSurface: 'gûasu',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.augmentative,
      meaningPt: 'grande',
      allomorphs: ['usu', 'gûasú', 'wasu'],
      sourceReference: 'Navarro 1998, p. 53',
    ),
    // Causativizer prefix
    const MorphologicalRule(
      id: 'rule_caus_mo',
      morphemeSurface: 'mo-',
      morphemeType: MorphemeType.prefix,
      morphologicalFunction: MorphologicalFunction.causativizer,
      meaningPt: 'fazer com que seja (causativo)',
      allomorphs: ['mbo-', 'mo', 'mbo'],
      sourceReference: 'Navarro 1998, p. 84',
    ),
    // Agentive suffix
    const MorphologicalRule(
      id: 'rule_ag_sara',
      morphemeSurface: 'sara',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.agentive,
      meaningPt: 'aquele que faz (agente)',
      allomorphs: ['hara', 'zara', 'tara'],
      sourceReference: 'Navarro 1998, p. 67',
    ),
    // Locative / Instrumental suffix
    const MorphologicalRule(
      id: 'rule_loc_aba',
      morphemeSurface: 'aba',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.locative,
      meaningPt: 'lugar de / instrumento de',
      allomorphs: ['haba', 'saba'],
      sourceReference: 'Navarro 1998, p. 70',
    ),
    // Past tense suffix
    const MorphologicalRule(
      id: 'rule_past_puer',
      morphemeSurface: 'pûer',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.tense,
      meaningPt: 'ex- / que foi (pretérito)',
      allomorphs: ['pûera', 'kûera', 'uêra'],
      sourceReference: 'Navarro 1998, p. 95',
    ),
    // Future tense suffix
    const MorphologicalRule(
      id: 'rule_fut_ram',
      morphemeSurface: 'ram',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.tense,
      meaningPt: 'futuro / que será',
      allomorphs: ['rama', 'rá'],
      sourceReference: 'Navarro 1998, p. 96',
    ),
    // Relational class prefix r-
    const MorphologicalRule(
      id: 'rule_rel_r',
      morphemeSurface: 'r-',
      morphemeType: MorphemeType.prefix,
      morphologicalFunction: MorphologicalFunction.relational,
      meaningPt: 'prefixo relacional de posse contígua',
      allomorphs: ['r'],
      sourceReference: 'Navarro 1998, p. 44',
    ),
  ];
}
