import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/world_engine/villages/village_node.dart';
import '../../domain/entities/lesson_node.dart';
import '../../domain/entities/chest_node.dart';

/// Expandable Journey Sheet representing an authentic curriculum territory journey (RFC-012C Patch 1 Chapter 2 & 10).
class JourneySheetWidget extends StatelessWidget {
  final VillageNode village;
  final double mastery;
  final ValueChanged<LessonNode> onLessonTapped;
  final VoidCallback onClose;

  const JourneySheetWidget({
    super.key,
    required this.village,
    required this.mastery,
    required this.onLessonTapped,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.28,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.28, 0.46, 0.88],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEE0B1519),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                border: Border.all(
                  color: const Color(0x66E5A93C),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 28.0,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
                  // 1. Drag Handle
                  Center(
                    child: Container(
                      width: 44.0,
                      height: 5.0,
                      decoration: BoxDecoration(
                        color: const Color(0x77FFFFFF),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14.0),

                  // 2. Village & Territory Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Village Stage Emblem
                      Container(
                        width: 56.0,
                        height: 56.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF0E3D2A)],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFD54F),
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44FFD54F),
                              blurRadius: 10.0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _getStageIcon(village.stage),
                            color: const Color(0xFFFFD54F),
                            size: 28.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14.0),

                      // Village Title & Dialect
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              village.tupiName,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              village.name,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Row(
                              children: [
                                _buildBadge(
                                  label: village.dialectVariant,
                                  color: const Color(0xFF00897B),
                                ),
                                const SizedBox(width: 6.0),
                                _buildBadge(
                                  label: village.biome.title,
                                  color: const Color(0xFFE65100),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Close Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // 3. Progress Bar & Mastery Stats
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: const Color(0x44102127),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Domínio da Aldeia (BKT): ${(mastery * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 16.0),
                                const SizedBox(width: 4.0),
                                Text(
                                  '${village.lessons.fold<int>(0, (sum, l) => sum + (l.status == LessonStatus.completed ? l.xpReward : 0))} XP',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: LinearProgressIndicator(
                            value: mastery.clamp(0.0, 1.0),
                            minHeight: 7.0,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFE5A93C)),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Líder: ${village.leaderName} • ${village.residentCount} habitantes',
                          style: const TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14.0),

                  // 4. Historical Context & Lore
                  Text(
                    village.historicalContext,
                    style: const TextStyle(
                      color: Color(0xFFCFD8DC),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // 5. Vertical Lesson Journey (Ocas)
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFFFFD54F), size: 18.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'Jornada de Aprendizado (${village.lessons.length} Ocas)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),

                  if (village.lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'Aldeia ainda não explorada. Avance nas trilhas vizinhas para desbloquear capítulos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    )
                  else
                    ...village.lessons.map((lesson) {
                      return _buildLessonCard(context, lesson);
                    }),

                  const SizedBox(height: 16.0),

                  // 6. Cultural Relics / Chests
                  if (village.chests.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Color(0xFFFFB300), size: 18.0),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Baús Culturais Ancestrais',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    ...village.chests.map((chest) => _buildChestCard(chest)),
                    const SizedBox(height: 16.0),
                  ],

                  // 7. Boss Challenge Banner
                  if (village.hasBossChallenge)
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0x55B71C1C), Color(0x334A148C)],
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: const Color(0x88FF5252)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield, color: Color(0xFFFF5252), size: 28.0),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Confronto de Mestria do Pajé',
                                  style: TextStyle(
                                    color: Color(0xFFFF8A80),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.0,
                                  ),
                                ),
                                Text(
                                  'Conclua todas as lições de ${village.tupiName} para desafiar a sabedoria ancestral do líder.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonCard(BuildContext context, LessonNode lesson) {
    final isActionable = lesson.status.isActionable;
    final isCompleted = lesson.status == LessonStatus.completed || lesson.status == LessonStatus.mastered;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: isActionable ? const Color(0x66182B32) : const Color(0x330B1417),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isActionable
              ? const Color(0x88E5A93C)
              : isCompleted
                  ? const Color(0x664CAF50)
                  : const Color(0x22FFFFFF),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: isActionable || isCompleted ? () => onLessonTapped(lesson) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(lesson.status),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _getStatusIcon(lesson.status),
                      color: _getStatusFgColor(lesson.status),
                      size: 20.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: TextStyle(
                                color: isCompleted
                                    ? const Color(0xFFA5D6A7)
                                    : isActionable
                                        ? Colors.white
                                        : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            '+${lesson.xpReward} XP',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        lesson.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 11.0,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: [
                          _buildMiniChip(lesson.difficulty.label),
                          const SizedBox(width: 6.0),
                          _buildMiniChip('${lesson.durationMinutes} min'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10.0),

                // Action Button
                if (isActionable)
                  ElevatedButton(
                    onPressed: () => onLessonTapped(lesson),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      foregroundColor: const Color(0xFF10191F),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 3.0,
                    ),
                    child: Text(
                      lesson.status == LessonStatus.inProgress ? 'Continuar' : 'Iniciar',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                else if (isCompleted)
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22.0)
                else
                  const Icon(Icons.lock, color: Colors.white24, size: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChestCard(ChestNode chest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0x33101E24),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0x44FFB300)),
      ),
      child: Row(
        children: [
          Icon(
            chest.isUnlocked ? Icons.lock_open : Icons.lock,
            color: chest.isUnlocked ? const Color(0xFFFFD54F) : Colors.white38,
            size: 20.0,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.0,
                  ),
                ),
                Text(
                  chest.tupiLore,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${chest.xpBonus} XP',
            style: const TextStyle(
              color: Color(0xFFFFB300),
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 9.5),
      ),
    );
  }

  IconData _getStageIcon(VillageEvolutionStage stage) {
    switch (stage) {
      case VillageEvolutionStage.oculta:
        return Icons.cloud;
      case VillageEvolutionStage.descoberta:
        return Icons.nature;
      case VillageEvolutionStage.explorada:
        return Icons.home;
      case VillageEvolutionStage.dominada:
        return Icons.fort;
      case VillageEvolutionStage.historica:
        return Icons.auto_awesome;
    }
  }

  IconData _getStatusIcon(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return Icons.lock;
      case LessonStatus.available:
        return Icons.play_arrow;
      case LessonStatus.inProgress:
        return Icons.timelapse;
      case LessonStatus.completed:
        return Icons.check;
      case LessonStatus.mastered:
        return Icons.star;
    }
  }

  Color _getStatusBgColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return const Color(0x22FFFFFF);
      case LessonStatus.available:
        return const Color(0x33E5A93C);
      case LessonStatus.inProgress:
        return const Color(0x3329B6F6);
      case LessonStatus.completed:
        return const Color(0x334CAF50);
      case LessonStatus.mastered:
        return const Color(0x33FFD54F);
    }
  }

  Color _getStatusFgColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return Colors.white38;
      case LessonStatus.available:
        return const Color(0xFFFFD54F);
      case LessonStatus.inProgress:
        return const Color(0xFF29B6F6);
      case LessonStatus.completed:
        return const Color(0xFF81C784);
      case LessonStatus.mastered:
        return const Color(0xFFFFD54F);
    }
  }
}
