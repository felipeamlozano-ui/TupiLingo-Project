import 'dart:convert';

/// Representa o rascunho de progresso do usuário no onboarding pré-cadastro.
/// Permite recuperar as respostas caso o usuário atualize o app ou feche a aba na Web.
class OnboardingDraft {
  final String? motivation;
  final String? source;
  final String? tupiLevel;
  final int? dailyGoalMinutes;
  final bool demoCompleted;
  final int stepIndex;
  final String? name;

  const OnboardingDraft({
    this.motivation,
    this.source,
    this.tupiLevel,
    this.dailyGoalMinutes,
    this.demoCompleted = false,
    this.stepIndex = 0,
    this.name,
  });

  OnboardingDraft copyWith({
    String? motivation,
    String? source,
    String? tupiLevel,
    int? dailyGoalMinutes,
    bool? demoCompleted,
    int? stepIndex,
    String? name,
  }) {
    return OnboardingDraft(
      motivation: motivation ?? this.motivation,
      source: source ?? this.source,
      tupiLevel: tupiLevel ?? this.tupiLevel,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      demoCompleted: demoCompleted ?? this.demoCompleted,
      stepIndex: stepIndex ?? this.stepIndex,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'motivation': motivation,
      'source': source,
      'tupiLevel': tupiLevel,
      'dailyGoalMinutes': dailyGoalMinutes,
      'demoCompleted': demoCompleted,
      'stepIndex': stepIndex,
      'name': name,
    };
  }

  factory OnboardingDraft.fromMap(Map<String, dynamic> map) {
    return OnboardingDraft(
      motivation: map['motivation']?.toString(),
      source: map['source']?.toString(),
      tupiLevel: map['tupiLevel']?.toString(),
      dailyGoalMinutes: (map['dailyGoalMinutes'] as num?)?.toInt(),
      demoCompleted: map['demoCompleted'] == true,
      stepIndex: (map['stepIndex'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OnboardingDraft.fromJson(String source) =>
      OnboardingDraft.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
