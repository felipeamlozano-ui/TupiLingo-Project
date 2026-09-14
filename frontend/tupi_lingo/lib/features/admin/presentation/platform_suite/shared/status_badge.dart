import 'package:flutter/material.dart';

/// Badge de status operacional (HEALTHY, DEGRADED, OUTAGE, PUBLISHED, DRAFT)
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool hasDot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.hasDot = true,
  });

  factory StatusBadge.healthy({String label = 'HEALTHY'}) =>
      StatusBadge(label: label, color: const Color(0xFF10B981));

  factory StatusBadge.degraded({String label = 'DEGRADED'}) =>
      StatusBadge(label: label, color: const Color(0xFFF59E0B));

  factory StatusBadge.outage({String label = 'OUTAGE'}) =>
      StatusBadge(label: label, color: const Color(0xFFEF4444));

  factory StatusBadge.draft({String label = 'DRAFT'}) =>
      StatusBadge(label: label, color: const Color(0xFF64748B));

  factory StatusBadge.published({String label = 'PUBLISHED'}) =>
      StatusBadge(label: label, color: const Color(0xFF3B82F6));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
