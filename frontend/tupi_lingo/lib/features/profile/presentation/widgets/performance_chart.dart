import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> desempenho;

  const PerformanceChart({super.key, required this.desempenho});

  @override
  Widget build(BuildContext context) {
    if (desempenho.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Desempenho por Módulo / Capítulo',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...desempenho.map((item) {
            final numero = item['numero'] ?? 1;
            final titulo = item['titulo'] ?? 'Capítulo $numero';
            final accuracyPercent = (item['accuracy_percent'] as num?)?.toInt() ?? 0;
            final licoesConcluidas = (item['licoes_concluidas'] as num?)?.toInt() ?? 0;
            final totalLicoes = (item['total_licoes'] as num?)?.toInt() ?? 0;

            Color barColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
            if (accuracyPercent < 60) {
              barColor = const Color(0xFFE05638);
            } else if (accuracyPercent < 80) {
              barColor = const Color(0xFFD08A45);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Cap. $numero • $titulo',
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$accuracyPercent% de acerto',
                        style: TextStyle(
                          color: barColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: (accuracyPercent / 100.0).clamp(0.0, 1.0),
                        backgroundColor: isDark ? const Color(0xFF1E2A25) : const Color(0xFFEAE7DC),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$licoesConcluidas de $totalLicoes lições concluídas',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
