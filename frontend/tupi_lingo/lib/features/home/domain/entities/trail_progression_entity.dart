import 'package:flutter/foundation.dart';

@immutable
class ChestRewardEntity {
  final int milestoneIndex;
  final String status; // 'bloqueado', 'disponivel', 'concluido'
  final bool unlocked;
  final bool collected;
  final int recompensaXp;
  final int recompensaConchas;
  final int afterLessonNumber;

  const ChestRewardEntity({
    required this.milestoneIndex,
    required this.status,
    required this.unlocked,
    required this.collected,
    required this.recompensaXp,
    required this.recompensaConchas,
    required this.afterLessonNumber,
  });
}
