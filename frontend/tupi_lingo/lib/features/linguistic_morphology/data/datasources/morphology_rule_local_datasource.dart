import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_family.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morphological_function.dart';

/// Local datasource storing morphology rules and analysis cache.
class MorphologyRuleLocalDataSource {
  final List<MorphologicalRule> _rulesCache = [];
  final Map<String, MorphologicalAnalysis> _analysisCache = {};
  final Map<String, MorphologicalFamily> _familyCache = {};

  MorphologyRuleLocalDataSource() {
    _initAcademicCorpus();
  }

  void _initAcademicCorpus() {
    _rulesCache.addAll(_canonicalOldTupiRules);
    _initPrecomputedFamilies();
  }

  List<MorphologicalRule> getRules({int? variantId}) {
    if (variantId == null) return List.unmodifiable(_rulesCache);
    return _rulesCache.where((r) => r.variantId == null || r.variantId == variantId).toList();
  }

  MorphologicalAnalysis? getAnalysis(String wordLabel, {int? variantId}) {
    final key = '${wordLabel.trim().toLowerCase()}_${variantId ?? 0}';
    return _analysisCache[key];
  }

  Future<void> saveAnalysis(MorphologicalAnalysis analysis) async {
    final key = '${analysis.wordLabel.trim().toLowerCase()}_${analysis.variantId ?? 0}';
    _analysisCache[key] = analysis;
  }

  MorphologicalFamily? getFamily(String rootSurface, {int? variantId}) {
    final key = rootSurface.trim().toLowerCase();
    return _familyCache[key];
  }

  Future<void> saveRules(List<MorphologicalRule> rules) async {
    for (final rule in rules) {
      final index = _rulesCache.indexWhere((r) => r.id == rule.id);
      if (index >= 0) {
        _rulesCache[index] = rule;
      } else {
        _rulesCache.add(rule);
      }
    }
  }

  void _initPrecomputedFamilies() {
    _familyCache['y'] = const MorphologicalFamily(
      rootSurface: 'y',
      sharedMeaningPt: 'água / rio',
      memberWords: ['ygara', 'paranã', 'igarapé', 'y-kûab', 'y-membyra'],
    );
    _familyCache['oka'] = const MorphologicalFamily(
      rootSurface: 'oka',
      sharedMeaningPt: 'casa / habitação',
      memberWords: ['oka', 'ok-eté', 'ok-i', 'oga-gûasu'],
    );
    _familyCache['abá'] = const MorphologicalFamily(
      rootSurface: 'abá',
      sharedMeaningPt: 'ser humano / homem',
      memberWords: ['abá', 'aba-eté', 'morubixaba', 'abá-mirĩ'],
    );
  }

  static final List<MorphologicalRule> _canonicalOldTupiRules = [
    const MorphologicalRule(
      id: 'rule_dim_i',
      morphemeSurface: "'ĩ",
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.diminutive,
      meaningPt: 'pequeno / diminutivo',
      allomorphs: ['-i', "'i", 'mirĩ'],
      sourceReference: 'Navarro 1998, p. 52',
    ),
    const MorphologicalRule(
      id: 'rule_aug_wasu',
      morphemeSurface: 'gûasu',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.augmentative,
      meaningPt: 'grande / aumentativo',
      allomorphs: ['usu', 'gûasú', 'wasu'],
      sourceReference: 'Navarro 1998, p. 53',
    ),
    const MorphologicalRule(
      id: 'rule_caus_mo',
      morphemeSurface: 'mo-',
      morphemeType: MorphemeType.prefix,
      morphologicalFunction: MorphologicalFunction.causativizer,
      meaningPt: 'fazer com que seja (causativo)',
      allomorphs: ['mbo-', 'mo', 'mbo'],
      sourceReference: 'Navarro 1998, p. 84',
    ),
    const MorphologicalRule(
      id: 'rule_ag_sara',
      morphemeSurface: 'sara',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.agentive,
      meaningPt: 'aquele que faz (agente)',
      allomorphs: ['hara', 'zara', 'tara'],
      sourceReference: 'Navarro 1998, p. 67',
    ),
    const MorphologicalRule(
      id: 'rule_loc_aba',
      morphemeSurface: 'aba',
      morphemeType: MorphemeType.suffix,
      morphologicalFunction: MorphologicalFunction.locative,
      meaningPt: 'lugar de / instrumento de',
      allomorphs: ['haba', 'saba'],
      sourceReference: 'Navarro 1998, p. 70',
    ),
    const MorphologicalRule(
      id: 'rule_rel_r',
      morphemeSurface: 'r-',
      morphemeType: MorphemeType.prefix,
      morphologicalFunction: MorphologicalFunction.relational,
      meaningPt: 'prefixo relacional de posse contígua',
      allomorphs: ['r'],
      sourceReference: 'Navarro 1998, p. 44',
    ),
    const MorphologicalRule(
      id: 'rule_rel_s',
      morphemeSurface: 's-',
      morphemeType: MorphemeType.prefix,
      morphologicalFunction: MorphologicalFunction.relational,
      meaningPt: 'prefixo relacional de 3ª pessoa não-contígua',
      allomorphs: ['s', 't-'],
      sourceReference: 'Navarro 1998, p. 45',
    ),
  ];
}
