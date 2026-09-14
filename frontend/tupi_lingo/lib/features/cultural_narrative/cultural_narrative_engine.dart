import 'package:flutter/foundation.dart';

/// Trigger types that unlock cultural narrative episodes.
enum NarrativeTriggerType { territoryUnlock, lessonComplete, bossCleared }

/// A historical narrative episode (RFC-012B Chapter 38).
@immutable
class NarrativeNode {
  final String id;
  final String title;
  final String bodyPt;
  final int historicalYear;
  final String? characterName;
  final NarrativeTriggerType triggerType;
  final String triggerReferenceId; // territory_id, lesson_id, etc.

  const NarrativeNode({
    required this.id,
    required this.title,
    required this.bodyPt,
    required this.historicalYear,
    this.characterName,
    required this.triggerType,
    required this.triggerReferenceId,
  });
}

/// Cultural Narrative Engine triggering immersive storytelling on curriculum events.
class CulturalNarrativeEngine {
  final List<NarrativeNode> _episodes = [];

  CulturalNarrativeEngine() {
    _initEpisodes();
  }

  void _initEpisodes() {
    _episodes.add(const NarrativeNode(
      id: 'ep_tamoios',
      title: 'A Confederação dos Tamoios e Cunhambebe',
      bodyPt: 'Em 1554, as lideranças Tupinambá uniram suas aldeias ao longo da costa da Guanabara sob a liderança do cacique Cunhambebe, resistindo às forças de cerco e estabelecendo alianças estratégicas.',
      historicalYear: 1554,
      characterName: 'Cunhambebe',
      triggerType: NarrativeTriggerType.territoryUnlock,
      triggerReferenceId: 'terr_guanabara',
    ));
    _episodes.add(const NarrativeNode(
      id: 'ep_arariboia',
      title: 'A Fundação de Niterói por Araribóia',
      bodyPt: 'O líder Temiminó Araribóia liderou seu povo na defesa da baía e, pelo seu valor diplomático e militar, recebeu as terras de Niterói.',
      historicalYear: 1573,
      characterName: 'Araribóia',
      triggerType: NarrativeTriggerType.lessonComplete,
      triggerReferenceId: 'licao_historia_1',
    ));
  }

  /// Returns the narrative episode triggered by an event, if any.
  NarrativeNode? checkTrigger({
    required NarrativeTriggerType type,
    required String referenceId,
  }) {
    for (final ep in _episodes) {
      if (ep.triggerType == type && ep.triggerReferenceId == referenceId) {
        return ep;
      }
    }
    return null;
  }
}
