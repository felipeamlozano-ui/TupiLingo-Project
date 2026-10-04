import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/territory_node.dart';
import '../../domain/entities/quest_node.dart';
import '../../../../core/world_engine/theme/pindorama_theme_palette.dart';
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
  final VoidCallback? onToggleMiniMap;
  final bool isMiniMapVisible;
  final PindoramaThemePalette? palette;

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
    this.onToggleMiniMap,
    this.isMiniMapVisible = false,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final activePalette = palette ?? PindoramaThemePalette.current();

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
                palette: activePalette,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onBack();
                },
              ),
              const SizedBox(width: 8.0),

              // Territory & Epoch Pill
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.0),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: activePalette.hudSurface,
                        borderRadius: BorderRadius.circular(22.0),
                        border: Border.all(color: activePalette.hudBorder, width: 1.5),
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
                              Expanded(
                                child: Text(
                                  currentTerritory?.name ?? 'Pindorama Histórico',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: activePalette.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Icon(Icons.stars, color: activePalette.accent, size: 14.0),
                              const SizedBox(width: 4.0),
                              Text(
                                '$totalXp XP',
                                style: TextStyle(
                                  color: activePalette.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: activePalette.hudBorder.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    currentTerritory?.primaryDialect ?? 'Tupi Clássico',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: activePalette.accent.withValues(alpha: 0.9),
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Flexible(
                                child: Text(
                                  '• ${currentEpoch.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                  ),
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
              const SizedBox(width: 8.0),

              // Re-center Action Button
              _buildRoundButton(
                icon: Icons.my_location,
                tooltip: 'Centralizar Aldeia Ativa',
                palette: activePalette,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRecenter();
                },
              ),

              // MiniMap Radar Toggle Button (Compass)
              if (onToggleMiniMap != null) ...[
                const SizedBox(width: 8.0),
                _buildRoundButton(
                  icon: Icons.explore,
                  tooltip: isMiniMapVisible ? 'Ocultar Radar' : 'Expandir Radar',
                  palette: activePalette,
                  isActive: isMiniMapVisible,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onToggleMiniMap!();
                  },
                ),
              ],
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
                palette: activePalette,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onToggleQuests();
                },
                accentColor: activePalette.accent,
              ),
              const SizedBox(height: 10.0),
              _buildFloatingAction(
                icon: Icons.menu_book,
                tooltip: 'Narrativa Ancestral',
                palette: activePalette,
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
                    color: activePalette.hudSurface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: activePalette.hudBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore, color: activePalette.accent, size: 16.0),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'MISSÃO ATIVA',
                              style: TextStyle(
                                color: activePalette.accent,
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
    required PindoramaThemePalette palette,
    bool isActive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          decoration: BoxDecoration(
            color: isActive
                ? palette.accent.withValues(alpha: 0.25)
                : palette.hudSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? palette.accent : palette.hudBorder,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? palette.accent : Colors.white,
              size: 20.0,
            ),
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
    required PindoramaThemePalette palette,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          decoration: BoxDecoration(
            color: palette.hudSurface,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(color: palette.hudBorder, width: 1.5),
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
