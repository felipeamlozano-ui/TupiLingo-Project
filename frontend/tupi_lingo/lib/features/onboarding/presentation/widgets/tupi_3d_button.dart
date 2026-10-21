import 'package:flutter/material.dart';
import '../../../../core/audio/audio_manager.dart';

/// Botão com efeito 3D e resposta tátil de profundidade (estilo Duolingo).
class Tupi3DButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color shadowColor;
  final Color textColor;
  final double height;
  final bool isLoading;

  const Tupi3DButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor = const Color(0xFFD08A45),
    this.shadowColor = const Color(0xFFA56627),
    this.textColor = Colors.white,
    this.height = 56,
    this.isLoading = false,
  });

  factory Tupi3DButton.forest({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double height = 56,
  }) {
    return Tupi3DButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      backgroundColor: const Color(0xFF0E5D4E),
      shadowColor: const Color(0xFF073C32),
      textColor: Colors.white,
      isLoading: isLoading,
      height: height,
    );
  }

  @override
  State<Tupi3DButton> createState() => _Tupi3DButtonState();
}

class _Tupi3DButtonState extends State<Tupi3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;

    final Color effectiveBg = enabled
        ? widget.backgroundColor
        : Colors.grey.shade400;
    final Color effectiveShadow = enabled
        ? widget.shadowColor
        : Colors.grey.shade600;

    const double depth = 4.0;
    final double topMargin = _isPressed ? depth : 0.0;
    final double bottomMargin = _isPressed ? 0.0 : depth;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              AudioManager.instance.playTap();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: effectiveShadow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          margin: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (!_isPressed && enabled)
                BoxShadow(
                  color: widget.backgroundColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: widget.textColor, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
