import 'package:flutter/material.dart';

class ConchasCounterBadge extends StatelessWidget {
  final int conchas;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ConchasCounterBadge({
    super.key,
    required this.conchas,
    this.onTap,
    this.fontSize = 13.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
    final Color bgColor = isDark
        ? const Color(0xFF1EC9A5).withValues(alpha: 0.15)
        : const Color(0xFF0E5D4E).withValues(alpha: 0.10);
    final Color borderColor = isDark
        ? const Color(0xFF1EC9A5).withValues(alpha: 0.35)
        : const Color(0xFF0E5D4E).withValues(alpha: 0.25);

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
            const Text('🐚', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              '$conchas',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
