import 'package:flutter/material.dart';

class PerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> desempenho;

  const PerformanceChart({super.key, required this.desempenho});

  @override
  Widget build(BuildContext context) {
    if (desempenho.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD0D0D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📈', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Desempenho por Módulo / Capítulo',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
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

            Color barColor = const Color(0xFF0E5D4E);
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
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
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
                        backgroundColor: const Color(0xFFEAE7DC),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$licoesConcluidas de $totalLicoes lições concluídas',
                    style: const TextStyle(
                      color: Color(0xFF565D6D),
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
