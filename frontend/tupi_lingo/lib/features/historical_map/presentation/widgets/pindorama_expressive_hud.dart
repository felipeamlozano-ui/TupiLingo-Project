import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/territory_node.dart';
import '../../domain/entities/quest_node.dart';
import 'historical_timeline_slider.dart';

/// Material 3 Expressive HUD for Pindorama Historical World (RFC-012C Patch 1 Chapter 10 & 11).
class PindoramaExpressiveHud extends StatelessWidget {
  final TerritoryNode? currentTerritory;
  final HistoricalEpoch currentEpoch;
  final QuestNode? activeQuest;
  final int totalXp;
  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final VoidCallback onToggleQuests;
  final VoidCallback onOpenNarrative;

  const PindoramaExpressiveHud({
    super.key,
    this.currentTerritory,
    required this.currentEpoch,
    this.activeQuest,
    this.totalXp = 420,
    required this.onBack,
    required this.onRecenter,
    required this.onToggleQuests,
    required this.onOpenNarrative,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 1. Top Glass Navigation Bar
        Positioned(
          top: topPadding + 10.0,
          left: 16.0,
          right: 16.0,
          child: Row(
            children: [
              // Back Button
              _buildRoundButton(
                icon: Icons.arrow_back,
                tooltip: 'Voltar',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onBack();
                },
              ),
              const SizedBox(width: 10.0),

              // Territory & Epoch Pill
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.0),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0E171C),
                        borderRadius: BorderRadius.circular(22.0),
                        border: Border.all(color: const Color(0x55E5A93C), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 16.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                currentTerritory?.name ?? 'Pindorama Histórico',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.0,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 14.0),
                              const SizedBox(width: 4.0),
                              Text(
                                '$totalXp XP',
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0x3300897B),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  currentTerritory?.primaryDialect ?? 'Tupi Clássico',
                                  style: const TextStyle(
                                    color: Color(0xFF80CBC4),
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                '• ${currentEpoch.label}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),

              // Re-center Action Button
              _buildRoundButton(
                icon: Icons.my_location,
                tooltip: 'Centralizar Pindorama',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRecenter();
                },
              ),
            ],
          ),
        ),

        // 2. Floating Action FABs (Right Side)
        Positioned(
          right: 16.0,
          bottom: 120.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingAction(
                icon: Icons.flag,
                tooltip: 'Missão Territorial',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onToggleQuests();
                },
                accentColor: const Color(0xFFFFD54F),
              ),
              const SizedBox(height: 10.0),
              _buildFloatingAction(
                icon: Icons.menu_book,
                tooltip: 'Narrativa Ancestral',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onOpenNarrative();
                },
                accentColor: const Color(0xFF81C784),
              ),
            ],
          ),
        ),

        // 3. Active Quest Mini-Banner (Top Left beneath top bar)
        if (activeQuest != null)
          Positioned(
            top: topPadding + 74.0,
            left: 16.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0D1C24),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: const Color(0x66FFD54F)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore, color: Color(0xFFFFD54F), size: 16.0),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'MISSÃO ATIVA',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: 9.0,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              activeQuest!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xDD0E171C),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x55E5A93C), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20.0),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color accentColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xDD0E171C),
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: accentColor, size: 22.0),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
