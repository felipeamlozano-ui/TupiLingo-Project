import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Balão de fala estilo quadrinhos/Duolingo para os diálogos do Mascote Tupi.
class SpeechBubble extends StatefulWidget {
  final String text;
  final String? title;
  final bool typewriterEffect;
  final VoidCallback? onTypingFinished;
  final Widget? trailing;

  const SpeechBubble({
    super.key,
    required this.text,
    this.title,
    this.typewriterEffect = false,
    this.onTypingFinished,
    this.trailing,
  });

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> {
  String _displayedText = '';
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    if (widget.typewriterEffect) {
      _startTypewriter();
    } else {
      _displayedText = widget.text;
    }
  }

  @override
  void didUpdateWidget(covariant SpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (widget.typewriterEffect) {
        _startTypewriter();
      } else {
        _displayedText = widget.text;
      }
    }
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _displayedText = '';
    int charIndex = 0;

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < widget.text.length) {
        setState(() {
          charIndex++;
          _displayedText = widget.text.substring(0, charIndex);
        });
      } else {
        timer.cancel();
        widget.onTypingFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return CustomPaint(
      painter: _BubblePainter(
        color: AppTheme.surface(context),
        borderColor: isDark ? const Color(0xFF263833) : const Color(0xFFE2DDD1),
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD08A45),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              _displayedText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
                height: 1.45,
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(height: 10),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  const _BubblePainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    // Bico do balão (apontando para baixo à esquerda)
    final path = Path()
      ..addRRect(r)
      ..moveTo(28, size.height)
      ..lineTo(22, size.height + 12)
      ..lineTo(40, size.height)
      ..close();

    // Sombra
    canvas.drawPath(
      path,
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Preenchimento
    canvas.drawPath(
      path,
      Paint()..color = color,
    );

    // Borda
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
