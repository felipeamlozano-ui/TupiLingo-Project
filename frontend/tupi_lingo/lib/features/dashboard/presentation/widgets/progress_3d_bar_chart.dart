import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_progress_stats.dart';

/// Widget de gráfico de barras com perspectiva 3D simulada e gradientes dinâmicos.
/// Utiliza fl_chart e micro-animações escalonadas do flutter_animate.
class Progress3DBarChart extends StatefulWidget {
  final List<DailyXpData> weeklyActivity;

  const Progress3DBarChart({
    super.key,
    required this.weeklyActivity,
  });

  @override
  State<Progress3DBarChart> createState() => _Progress3DBarChartState();
}

class _Progress3DBarChartState extends State<Progress3DBarChart> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.weeklyActivity.fold<double>(
      100.0,
      (max, d) => d.xp.toDouble() > max ? d.xp.toDouble() : max,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5D4E).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ritmo de Aprendizado Semanal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'XP e Lições Ancestrais concluídas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5D4E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),        
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.65,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1F2937),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = widget.weeklyActivity[group.x.toInt()];
                      return BarTooltipItem(
                        '${item.dayName}\n',
                        const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '${item.xp} XP\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '${item.lessonsCompleted} lições',
                            style: const TextStyle(
                              color: Color(0xFFC7C3B6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (response?.spot != null && event is FlTapUpEvent) {
                      setState(() {
                        _touchedGroupIndex = response!.spot!.touchedBarGroupIndex;
                      });
                    } else if (event is FlPanEndEvent || event is FlLongPressEnd) {
                      setState(() {
                        _touchedGroupIndex = null;
                      });
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (maxVal / 3).clamp(20, 100).toDouble(),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF565D6D),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= widget.weeklyActivity.length) {
                          return const SizedBox.shrink();
                        }
                        final day = widget.weeklyActivity[idx].dayName;
                        final isTouched = _touchedGroupIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            day,
                            style: TextStyle(
                              color: isTouched
                                  ? const Color(0xFF0E5D4E)
                                  : const Color(0xFF565D6D),
                              fontSize: 11,
                              fontWeight:
                                  isTouched ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 3).clamp(20, 100).toDouble(),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF3F2E8),
                    strokeWidth: 1.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarGroups(maxVal),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .shimmer(delay: 600.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.4));
  }

  List<BarChartGroupData> _buildBarGroups(double maxVal) {
    return List.generate(widget.weeklyActivity.length, (i) {
      final data = widget.weeklyActivity[i];
      final isTouched = _touchedGroupIndex == i;

      // Gradiente Dinâmico 3D (Simula face iluminada e profundidade angular)
      final activeGradient = LinearGradient(
        colors: isTouched
            ? [const Color(0xFF0E5D4E), const Color(0xFF1EC9A5)]
            : [const Color(0xFFD08A45), const Color(0xFFF3B362)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: data.xp.toDouble(),
            gradient: activeGradient,
            width: isTouched ? 20 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            // Barra de sombra ao fundo (Efeito de extrusão 3D)
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal * 1.15,
              color: const Color(0xFFF3F2E8).withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    });
  }
}
