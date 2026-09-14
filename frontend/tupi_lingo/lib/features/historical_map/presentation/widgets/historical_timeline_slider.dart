import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supported historical epochs for the Pindorama timeline filter (RFC-012C Patch 1 Chapter 3).
enum HistoricalEpoch {
  pre1500(
    id: 'pre1500',
    label: 'Pré-1500',
    title: 'Pindorama Ancestral',
    description: 'Soberania indígena, rede milenar do Peabiru e expansão Tupi.',
  ),
  epoch1554(
    id: 'epoch1554',
    label: '1554',
    title: 'Aldeamento & Piratininga',
    description: 'Aliança de Tibiriçá, confluência dos rios e fundação de São Paulo.',
  ),
  epoch1555(
    id: 'epoch1555',
    label: '1555',
    title: 'França Antártica',
    description: 'Baía de Guanabara, Forte Coligny e aliança franco-tupinambá.',
  ),
  epoch1567(
    id: 'epoch1567',
    label: '1567',
    title: 'Confederação dos Tamoios',
    description: 'Resistência armada dos Tupinambás liderada por Cunhambebe e Aimberê.',
  ),
  atual(
    id: 'atual',
    label: 'Atualidade',
    title: 'Revitalização Linguística',
    description: 'Retomada cultural, literatura viva e transmissão intergeracional.',
  );

  final String id;
  final String label;
  final String title;
  final String description;

  const HistoricalEpoch({
    required this.id,
    required this.label,
    required this.title,
    required this.description,
  });
}

/// Material 3 Expressive interactive timeline slider with animated marker and haptics.
class HistoricalTimelineSlider extends StatelessWidget {
  final HistoricalEpoch currentEpoch;
  final ValueChanged<HistoricalEpoch> onEpochChanged;

  const HistoricalTimelineSlider({
    super.key,
    required this.currentEpoch,
    required this.onEpochChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xDD0E171C),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: const Color(0x55E5A93C),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20.0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented Epoch Buttons
              Container(
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  color: const Color(0x55000000),
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Row(
                  children: HistoricalEpoch.values.map((epoch) {
                    final isSelected = epoch == currentEpoch;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.lightImpact();
                            onEpochChanged(epoch);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE5A93C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15.0),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x55E5A93C),
                                      blurRadius: 8.0,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              epoch.label,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF10191F)
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 11.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 6.0),

              // Active Epoch Lore & Description with Shared Axis transition
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  key: ValueKey(currentEpoch),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(
                          color: Color(0x33FFD54F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_edu,
                          size: 15.0,
                          color: Color(0xFFFFD54F),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${currentEpoch.title} — ',
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                              TextSpan(
                                text: currentEpoch.description,
                                style: const TextStyle(
                                  color: Color(0xFFE0E0E0),
                                  fontSize: 11.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
