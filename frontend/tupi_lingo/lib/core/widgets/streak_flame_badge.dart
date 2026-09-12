import 'package:flutter/material.dart';

class StreakFlameBadge extends StatelessWidget {
  final int streak;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StreakFlameBadge({
    super.key,
    required this.streak,
    this.onTap,
    this.fontSize = 13.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    const Color fireColor = Color(0xFFE05638);
    final Color bgColor = fireColor.withValues(alpha: 0.12);
    final Color borderColor = fireColor.withValues(alpha: 0.30);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              '$streak',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: fireColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
