import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/world_engine/villages/village_node.dart';

/// Glassmorphic territory card displayed when a village node is selected.
class VillageExpressiveCard extends StatelessWidget {
  final VillageNode village;
  final double mastery; // 0.0 to 1.0
  final VoidCallback onClose;
  final VoidCallback onPracticePressed;

  const VillageExpressiveCard({
    super.key,
    required this.village,
    this.mastery = 0.65,
    required this.onClose,
    required this.onPracticePressed,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = switch (village.stage) {
      VillageEvolutionStage.descoberta => const Color(0xFF8D6E63),
      VillageEvolutionStage.explorada => const Color(0xFF4CAF50),
      VillageEvolutionStage.dominada => const Color(0xFFFFB300),
      VillageEvolutionStage.historica => const Color(0xFFAB47BC),
      VillageEvolutionStage.oculta => Colors.grey,
    };

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
          decoration: BoxDecoration(
            color: const Color(0xE6101B20),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28.0)),
            border: Border.all(
              color: const Color(0x55E5A93C),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: stageColor, width: 2.0),
                    ),
                    child: Icon(
                      switch (village.stage) {
                        VillageEvolutionStage.historica => Icons.auto_awesome,
                        VillageEvolutionStage.dominada => Icons.military_tech,
                        VillageEvolutionStage.explorada => Icons.explore,
                        _ => Icons.place,
                      },
                      color: stageColor,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          village.name,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: stageColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                village.stage.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: stageColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'Dialeto: ${village.dialectVariant}',
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Color(0xFFB0BEC5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 12.0),

              // Territory Context / Lore
              Text(
                'Liderança histórica: ${village.leaderName}. ${village.historicalContext}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFCFD8DC),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 16.0),

              // BKT Mastery Level Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Domínio Ancestral do Território (BKT)',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFD54F),
                    ),
                  ),
                  Text(
                    '${(mastery * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD54F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: LinearProgressIndicator(
                  value: mastery,
                  minHeight: 8.0,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(stageColor),
                ),
              ),

              const SizedBox(height: 18.0),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPracticePressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: const Color(0xFF0F1B22),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  icon: const Icon(Icons.bolt, size: 20.0),
                  label: const Text(
                    'Explorar Trilha Regional',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
