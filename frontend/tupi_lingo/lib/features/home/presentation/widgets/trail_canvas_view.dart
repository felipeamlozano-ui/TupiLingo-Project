import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/trail_map_models.dart';

// Visualizador do caminho sinuoso da trilha de lições com nós 3D e baú ancestral
class TrailCanvasView extends StatelessWidget {
  final CapituloMapData cap;
  final bool isCurrentActiveChapter;
  final AnimationController? pulseController;
  final AnimationController? floatController;
  final ValueChanged<LicaoMapData> onLessonTap;
  final void Function(CapituloMapData cap, ChestRewardMapData chest) onChestTap;
  final void Function(CapituloMapData cap, ChestRewardMapData? chest) onCollectedChestTap;

  const TrailCanvasView({
    super.key,
    required this.cap,
    required this.isCurrentActiveChapter,
    required this.pulseController,
    required this.floatController,
    required this.onLessonTap,
    required this.onChestTap,
    required this.onCollectedChestTap,
  });

  // Constrói a sequência ondulada vertical com conectores, nós interativos e baú de recompensas
  @override
  Widget build(BuildContext context) {
    final licoes = cap.licoes;
    if (licoes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Nenhuma lição neste capítulo.', style: TextStyle(color: Color(0xFF565D6D))),
        ),
      );
    }

    final offsets = [0.0, -0.45, 0.45, 0.0, -0.45, 0.45];
    final targetIndex = isCurrentActiveChapter
        ? licoes.indexWhere(
            (l) => l.status == LicaoStatus.disponivel || l.status == LicaoStatus.emAndamento,
          )
        : -1;

    return Column(
      children: [
        ...List.generate(licoes.length, (index) {
          final licao = licoes[index];
          final dx = offsets[index % offsets.length];
          final isTarget = (index == targetIndex);
          final isInProgress = licao.status == LicaoStatus.emAndamento;

          return Column(
            children: [
              if (index > 0) _buildTrailConnector(context),
              Align(
                alignment: Alignment(dx, 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (isTarget && pulseController != null)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: pulseController!,
                          builder: (ctx, _) {
                            final val = pulseController?.value ?? 0.0;
                            return Container(
                              width: 86 + (val * 18),
                              height: 86 + (val * 18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFB300).withValues(alpha: 0.32 - (val * 0.18)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.40 - (val * 0.20)),
                                    blurRadius: 18 + (val * 8),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (isTarget && floatController != null)
                      Positioned(
                        top: -36,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: floatController!,
                            builder: (ctx, _) {
                              final val = floatController?.value ?? 0.0;
                              final dy = math.sin(val * math.pi) * 3.5;
                              return Transform.translate(
                                offset: Offset(0, dy),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0E5D4E), Color(0xFF1B4332)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFFD166), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD166).withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isInProgress ? '🏹 CONTINUAR' : '⭐ SUA VEZ',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10.5,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    _build3DNodeButton(context, licao, isTarget: isTarget),
                  ],
                ),
              ),
            ],
          );
        }),
        _buildTrailConnector(context),
        _buildChestRewardNode(context, cap, cap.chestReward),
      ],
    );
  }

  // Segmento vertical que liga dois nós adjacentes na trilha
  Widget _buildTrailConnector(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: 6,
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF263833) : const Color(0xFFDCD8CB),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // Botão circular estilizado em 3D com relevo, cor de status e reflexo brilhante
  Widget _build3DNodeButton(BuildContext context, LicaoMapData licao, {bool isTarget = false}) {
    final isCompleted = licao.status == LicaoStatus.concluida;
    final isInProgress = licao.status == LicaoStatus.emAndamento;
    final isAvailable = licao.status == LicaoStatus.disponivel;
    final isPlayable = isAvailable || isInProgress;
    final isLocked = licao.status == LicaoStatus.bloqueada;
    final isDark = AppTheme.isDark(context);

    Widget iconWidget;
    Gradient? bgGradient;
    Color? solidColor;
    Color bottomColor;
    List<BoxShadow> shadows;

    if (isCompleted) {
      solidColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
      bottomColor = isDark ? const Color(0xFF0E6955) : const Color(0xFF083C32);
      iconWidget = const Text('👑', style: TextStyle(fontSize: 28));
      shadows = [
        BoxShadow(
          color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isTarget) {
      bgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFDF70),
          Color(0xFFFFB300),
          Color(0xFFF57C00),
        ],
      );
      bottomColor = const Color(0xFFC67D00);
      iconWidget = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: const [
          Text('⭐', style: TextStyle(fontSize: 32)),
          Positioned(
            right: -6,
            top: -4,
            child: Text('✨', style: TextStyle(fontSize: 14)),
          ),
        ],
      );
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFB300).withValues(alpha: 0.60),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.40),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (isPlayable) {
      solidColor = const Color(0xFFD08A45);
      bottomColor = const Color(0xFFA56627);
      iconWidget = Text(isInProgress ? '🏹' : '⭐', style: const TextStyle(fontSize: 28));
      shadows = [
        BoxShadow(
          color: const Color(0xFFD08A45).withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      solidColor = isDark ? const Color(0xFF19231F) : const Color(0xFFE2DFD4);
      bottomColor = isDark ? const Color(0xFF23322C) : const Color(0xFFC7C3B6);
      iconWidget = Icon(Icons.lock_rounded, color: AppTheme.textSecondary(context), size: 26);
      shadows = [
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFC7C3B6).withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    }

    return GestureDetector(
      onTap: () => onLessonTap(licao),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: solidColor,
              gradient: bgGradient,
              border: Border(
                bottom: BorderSide(color: bottomColor, width: 6),
              ),
              boxShadow: shadows,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isTarget || isPlayable)
                  Positioned(
                    top: 4,
                    left: 10,
                    right: 10,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: isTarget ? 0.70 : 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Center(child: iconWidget),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isTarget ? const Color(0xFFFFB300) : AppTheme.border(context),
                width: isTarget ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTarget
                      ? const Color(0xFFFFB300).withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              licao.titulo,
              style: TextStyle(
                color: isLocked
                    ? AppTheme.textSecondary(context)
                    : isTarget
                        ? const Color(0xFFFFB300)
                        : AppTheme.textPrimary(context),
                fontSize: 11,
                fontWeight: isTarget ? FontWeight.w900 : FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Nó final do capítulo que guarda o baú de artefato indígena e XP bônus
  Widget _buildChestRewardNode(BuildContext context, CapituloMapData cap, ChestRewardMapData? chest) {
    final status = chest?.status ?? 'bloqueado';
    final isUnlocked = status == 'disponivel';
    final isCollected = status == 'concluido';
    final isDark = AppTheme.isDark(context);

    Color bgColor;
    Border border;
    List<BoxShadow> shadows;
    Widget icon;
    String badgeText;

    if (isCollected) {
      bgColor = isDark ? const Color(0xFF172420) : const Color(0xFFFAF9F5);
      border = Border.all(color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E), width: 2.5);
      shadows = [
        BoxShadow(
          color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.2),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
      icon = const Text('✨', style: TextStyle(fontSize: 26));
      badgeText = 'COLETADO';
    } else if (isUnlocked) {
      bgColor = AppTheme.surface(context);
      border = Border.all(color: const Color(0xFFD08A45), width: 3);
      shadows = [
        BoxShadow(
          color: const Color(0xFFD08A45).withValues(alpha: 0.45),
          blurRadius: 14,
          spreadRadius: 3,
        ),
      ];
      icon = const Text('🏺', style: TextStyle(fontSize: 28));
      badgeText = 'ABRIR BAÚ';
    } else {
      bgColor = isDark ? const Color(0xFF19231F) : const Color(0xFFE2DFD4);
      border = Border.all(color: isDark ? const Color(0xFF23322C) : const Color(0xFFC7C3B6), width: 2);
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
      icon = const Text('🔒', style: TextStyle(fontSize: 22));
      badgeText = 'BLOQUEADO';
    }

    return GestureDetector(
      onTap: () {
        if (isCollected) {
          onCollectedChestTap(cap, chest);
        } else if (isUnlocked && chest != null) {
          onChestTap(cap, chest);
        }
      },
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: border,
              boxShadow: shadows,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFFD08A45) : (isDark ? const Color(0xFF1C2824) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnlocked ? const Color(0xFFA56627) : AppTheme.border(context),
              ),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
