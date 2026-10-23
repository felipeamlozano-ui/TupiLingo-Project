import 'package:flutter/material.dart';
import '../../../../core/audio/audio_manager.dart';
import '../widgets/mascot_avatar.dart';
import '../widgets/speech_bubble.dart';

/// Alvo de destaque para o Tour Guiado do TupiLingo.
class TourStepTarget {
  final GlobalKey key;
  final String title;
  final String description;
  final MascotMood mascotMood;
  final bool requiresTap; // Se true, o usuário precisa tocar no próprio alvo para prosseguir
  final ShapeBorder shape;
  final bool autoScroll;

  const TourStepTarget({
    required this.key,
    required this.title,
    required this.description,
    this.mascotMood = MascotMood.talking,
    this.requiresTap = false,
    this.autoScroll = false,
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  });
}

/// Overlay de spotlight/foco com efeito "buraco de fechadura" e balão de fala do Mascote Tupi.
class CoachMarkOverlay {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required TourStepTarget target,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    int? currentStep,
    int? totalSteps,
  }) {
    hide();

    final overlay = Overlay.of(context);
    final renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) {
      // Se o elemento ainda não foi renderizado, avança graciosamente
      onNext();
      return;
    }

    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    _currentEntry = OverlayEntry(
      builder: (ctx) {
        // Decide se o balão de fala fica acima ou abaixo do alvo
        final bool placeAbove = targetOffset.dy > (screenSize.height * 0.55);

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Fundo escurecido com recorte vazado no alvo
              Positioned.fill(
                child: GestureDetector(
                  onTap: target.requiresTap ? null : onNext,
                  behavior: HitTestBehavior.opaque,
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      targetRect: targetOffset & targetSize,
                      shape: target.shape,
                      scrimColor: Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),

              // Área interativa direta no alvo quando `requiresTap` estiver ativo
              if (target.requiresTap)
                Positioned(
                  left: targetOffset.dx,
                  top: targetOffset.dy,
                  width: targetSize.width,
                  height: targetSize.height,
                  child: GestureDetector(
                    onTap: () {
                      hide();
                      onNext();
                    },
                    behavior: HitTestBehavior.translucent,
                  ),
                ),

              // Balão explicativo e Mascote Tupi
              Positioned(
                left: 20,
                right: 20,
                top: placeAbove ? null : (targetOffset.dy + targetSize.height + 16),
                bottom: placeAbove ? (screenSize.height - targetOffset.dy + 16) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MascotAvatar(
                          size: 70,
                          mood: target.mascotMood,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SpeechBubble(
                            title: target.title,
                            text: target.description,
                            trailing: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (currentStep != null && totalSteps != null)
                                  Text(
                                    '$currentStep de $totalSteps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                else
                                  const SizedBox(),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        AudioManager.instance.playTap();
                                        hide();
                                        onSkip();
                                      },
                                      child: const Text(
                                        'Pular tour',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: () {
                                        AudioManager.instance.playTap();
                                        hide();
                                        onNext();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD08A45),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        target.requiresTap
                                            ? 'TOQUE NO NÓ'
                                            : (currentStep != null && totalSteps != null && currentStep == totalSteps
                                                ? 'COMEÇAR JORNADA!'
                                                : 'PRÓXIMO'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final ShapeBorder shape;
  final Color scrimColor;

  const _SpotlightPainter({
    required this.targetRect,
    required this.shape,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final inflated = targetRect.inflate(6.0);

    final path = Path()
      ..addRect(screenRect)
      ..addRRect(RRect.fromRectAndRadius(inflated, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = scrimColor);

    // Borda brilhante ao redor do spotlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflated, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.scrimColor != scrimColor;
  }
}
