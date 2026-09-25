import 'package:flutter/material.dart';
import '../../data/models/trail_map_models.dart';

// Card em destaque no topo da trilha com resumo do capítulo, progresso e acesso ao guia cultural
class ChapterBannerCard extends StatelessWidget {
  final CapituloMapData cap;
  final VoidCallback onCulturalGuideTap;

  const ChapterBannerCard({
    super.key,
    required this.cap,
    required this.onCulturalGuideTap,
  });

  // Renderiza o gradiente verde floresta com título, descrição e barra percentual de conclusão
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5D4E), Color(0xFF134E41)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5D4E).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAPÍTULO ${cap.numero} • UNIDADE BÁSICA',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: onCulturalGuideTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏛️', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Guia Cultural',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cap.titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cap.descricao,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (cap.moduleProgressPercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD166)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${cap.moduleProgressPercentage.toInt()}%',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
