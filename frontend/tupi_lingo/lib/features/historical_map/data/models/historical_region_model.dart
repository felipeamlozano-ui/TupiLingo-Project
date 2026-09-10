import '../../domain/entities/historical_region.dart';

class HistoricalRegionModel extends HistoricalRegion {
  const HistoricalRegionModel({
    required super.id,
    required super.name,
    required super.indigenousNation,
    required super.historicalPeriod,
    required super.relativeX,
    required super.relativeY,
    super.radius = 24.0,
    required super.culturalSummary,
    required super.vocabularyHighlights,
    required super.isUnlocked,
    required super.requiredLevel,
    super.lessonsCount = 5,
    super.completedLessonsCount = 0,
  });

  factory HistoricalRegionModel.fromJson(Map<String, dynamic> json) {
    final vocabList = (json['vocabulary_highlights'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return HistoricalRegionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Região Ancestral',
      indigenousNation: json['indigenous_nation']?.toString() ?? 'Tupi',
      historicalPeriod: json['historical_period']?.toString() ?? 'Século XVI',
      relativeX: (json['relative_x'] as num?)?.toDouble() ?? 0.5,
      relativeY: (json['relative_y'] as num?)?.toDouble() ?? 0.5,
      radius: (json['radius'] as num?)?.toDouble() ?? 24.0,
      culturalSummary: json['cultural_summary']?.toString() ?? '',
      vocabularyHighlights: vocabList,
      isUnlocked: json['is_unlocked'] == true,
      requiredLevel: (json['required_level'] as num?)?.toInt() ?? 1,
      lessonsCount: (json['lessons_count'] as num?)?.toInt() ?? 5,
      completedLessonsCount: (json['completed_lessons_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'indigenous_nation': indigenousNation,
      'historical_period': historicalPeriod,
      'relative_x': relativeX,
      'relative_y': relativeY,
      'radius': radius,
      'cultural_summary': culturalSummary,
      'vocabulary_highlights': vocabularyHighlights,
      'is_unlocked': isUnlocked,
      'required_level': requiredLevel,
      'lessons_count': lessonsCount,
      'completed_lessons_count': completedLessonsCount,
    };
  }

  static List<HistoricalRegionModel> defaultHistoricalRegions({
    int totalCompleted = 0,
    int totalLessons = 6,
    int userLevel = 1,
  }) {
    final cap1Completed = totalCompleted.clamp(0, totalLessons);
    final cap2Unlocked = totalCompleted >= totalLessons || userLevel >= 2;
    final cap2Completed = cap2Unlocked ? (totalCompleted - totalLessons).clamp(0, 5) : 0;
    final cap3Unlocked = userLevel >= 3 || totalCompleted >= 11;
    final cap4Unlocked = userLevel >= 4 || totalCompleted >= 16;
    final cap5Unlocked = userLevel >= 5 || totalCompleted >= 22;

    return [
      HistoricalRegionModel(
        id: 1,
        name: 'Costa dos Tupinambás (Ubatuba / Guanabara)',
        indigenousNation: 'Tupinambá',
        historicalPeriod: 'Século XVI - Confederação dos Tamoios',
        relativeX: 0.72,
        relativeY: 0.68,
        radius: 26.0,
        culturalSummary:
            'Coração da Confederação dos Tamoios liderada por Cunhambebe. Famosos navegadores de canoas '
            'e guerreiros da floresta atlântica, falantes do Tupi clássico registrado por Jean de Léry e Hans Staden.',
        vocabularyHighlights: const ['Iperoig', 'Tamoio', 'Karai', 'Tupã', 'Maracá'],
        isUnlocked: true,
        requiredLevel: 1,
        lessonsCount: totalLessons,
        completedLessonsCount: cap1Completed,
      ),
      HistoricalRegionModel(
        id: 2,
        name: 'Território Carijó (Litoral Sul / Ilha de SC)',
        indigenousNation: 'Carijó (Guarani)',
        historicalPeriod: 'Século XVI - Trilha do Peabiru',
        relativeX: 0.60,
        relativeY: 0.84,
        radius: 24.0,
        culturalSummary:
            'Povo pacífico de navegadores e guardiões do mítico caminho sagrado do Peabiru, que ligava o Atlântico aos Andes. '
            'Grandes ceramistas e agricultores de mandioca e milho.',
        vocabularyHighlights: const ['Peabiru', 'Meiembipe', 'Mandi\'oka', 'Avaxi'],
        isUnlocked: cap2Unlocked,
        requiredLevel: 2,
        lessonsCount: 5,
        completedLessonsCount: cap2Completed,
      ),
      HistoricalRegionModel(
        id: 3,
        name: 'Alto Xingu & Florestas Centrais',
        indigenousNation: 'Kamaiurá / Aweti (Tupi)',
        historicalPeriod: 'Tradição Milenar das Aldeias Circulares',
        relativeX: 0.52,
        relativeY: 0.48,
        radius: 25.0,
        culturalSummary:
            'Complexo cultural do Xingu com aldeias circulares monumentais, rituais sagrados do Kuarup e luta Huka-Huka. '
            'Preservam a língua de tronco Tupi viva em sua forma mais rica e expressiva.',
        vocabularyHighlights: const ['Kuarup', 'Huka-huka', 'Jawari', 'Moitará'],
        isUnlocked: cap3Unlocked,
        requiredLevel: 3,
        lessonsCount: 8,
        completedLessonsCount: 0,
      ),
      HistoricalRegionModel(
        id: 4,
        name: 'Amazônia Nheengatu (Bacia do Rio Negro)',
        indigenousNation: 'Povos do Rio Negro (Nheengatu)',
        historicalPeriod: 'Século XVII aos dias atuais',
        relativeX: 0.32,
        relativeY: 0.22,
        radius: 26.0,
        culturalSummary:
            'Berço da Língua Geral Amazônica (Nheengatu), derivada do Tupinambá e reconhecida como patrimônio linguístico vivo. '
            'Riquíssima cosmologia sobre Jurupari e os rios de água preta.',
        vocabularyHighlights: const ['Yande', 'Paranã', 'Yara', 'Jurupari', 'Puraque'],
        isUnlocked: cap4Unlocked,
        requiredLevel: 4,
        lessonsCount: 10,
        completedLessonsCount: 0,
      ),
      HistoricalRegionModel(
        id: 5,
        name: 'Costa dos Tupiniquins (Porto Seguro)',
        indigenousNation: 'Tupiniquim',
        historicalPeriod: '1500 - Primeiro Contato',
        relativeX: 0.84,
        relativeY: 0.56,
        radius: 23.0,
        culturalSummary:
            'Habitantes da costa sul da Bahia, foram os primeiros anfitriões dos navegadores portugueses em 1500. '
            'Exímios coletores de moluscos e conhecedores dos segredos das marés.',
        vocabularyHighlights: const ['Pindorama', 'Mbya', 'Itaparica', 'Pirá'],
        isUnlocked: cap5Unlocked,
        requiredLevel: 5,
        lessonsCount: 6,
        completedLessonsCount: 0,
      ),
    ];
  }
}
