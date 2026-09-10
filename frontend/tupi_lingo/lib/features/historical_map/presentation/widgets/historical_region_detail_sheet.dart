import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/historical_region.dart';

class HistoricalRegionDetailSheet extends StatelessWidget {
  final HistoricalRegion region;
  final VoidCallback? onExplore;

  const HistoricalRegionDetailSheet({
    super.key,
    required this.region,
    this.onExplore,
  });

  static void show(BuildContext context, HistoricalRegion region, {VoidCallback? onExplore}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => HistoricalRegionDetailSheet(
        region: region,
        onExplore: onExplore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puxador de arrasto
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Cabeçalho: Status + Nação Indígena
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏹', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      region.indigenousNation,
                      style: const TextStyle(
                        color: Color(0xFF0E5D4E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: region.isUnlocked
                      ? const Color(0xFFD08A45).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      region.isUnlocked ? '✨ Território Aberto' : '🔒 Nível ${region.requiredLevel}',
                      style: TextStyle(
                        color: region.isUnlocked ? const Color(0xFFD08A45) : const Color(0xFF565D6D),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título da Região
          Text(
            region.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            region.historicalPeriod,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD08A45),
            ),
          ),
          const SizedBox(height: 14),

          // Resumo Histórico & Cultural
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F2E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              region.culturalSummary,
              style: const TextStyle(
                color: Color(0xFF565D6D),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vocabulário em Destaque
          if (region.vocabularyHighlights.isNotEmpty) ...[
            const Text(
              'Vocabulário Sagrado Desta Região:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: region.vocabularyHighlights.map((term) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0E5D4E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        term,
                        style: const TextStyle(
                          color: Color(0xFF0E5D4E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Botão de Ação
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: region.isUnlocked ? onExplore : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                region.isUnlocked
                    ? 'Explorar Lições Deste Território'
                    : 'Território Bloqueado (Alcance o Nível ${region.requiredLevel})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0, duration: 350.ms);
  }
}
