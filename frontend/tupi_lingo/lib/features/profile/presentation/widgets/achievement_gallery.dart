import 'package:flutter/material.dart';

class AchievementGallery extends StatelessWidget {
  final List<Map<String, dynamic>> unlockedAchievements;
  final List<Map<String, dynamic>> lockedAchievements;

  const AchievementGallery({
    super.key,
    required this.unlockedAchievements,
    required this.lockedAchievements,
  });

  void _showAchievementModal(BuildContext context, Map<String, dynamic> ach, bool isUnlocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final nome = ach['nome'] ?? 'Conquista';
        final desc = ach['descricao'] ?? '';
        final icone = ach['icone'] ?? '🏅';
        final xpNecessario = ach['xp_necessario'] ?? 0;
        final conquistadaEm = ach['conquistada_em'];

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? const Color(0xFFD08A45).withValues(alpha: 0.15)
                      : const Color(0xFFEAE7DC),
                  border: Border.all(
                    color: isUnlocked ? const Color(0xFFD08A45) : const Color(0xFFC7C3B6),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    icone,
                    style: TextStyle(
                      fontSize: 38,
                      color: isUnlocked ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nome,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF0E5D4E).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isUnlocked ? '✓ DESBLOQUEADA' : '🔒 BLOQUEADA',
                  style: TextStyle(
                    color: isUnlocked ? const Color(0xFF0E5D4E) : const Color(0xFF565D6D),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF565D6D),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              if (isUnlocked && conquistadaEm != null)
                Text(
                  'Desbloqueada em: ${_formatDate(conquistadaEm.toString())}',
                  style: const TextStyle(color: Color(0xFF0E5D4E), fontSize: 12, fontWeight: FontWeight.w600),
                )
              else if (!isUnlocked && xpNecessario > 0)
                Text(
                  'Requisito: $xpNecessario XP acumulados',
                  style: const TextStyle(color: Color(0xFFD08A45), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5D4E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Fechar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalConquistadas = unlockedAchievements.length;
    final total = totalConquistadas + lockedAchievements.length;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🏅', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Galeria de Medalhas',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$totalConquistadas de $total',
                style: const TextStyle(
                  color: Color(0xFFD08A45),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grade 3 colunas com Conquistas Desbloqueadas e Bloqueadas
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final isUnlocked = index < totalConquistadas;
              final ach = isUnlocked
                  ? unlockedAchievements[index]
                  : lockedAchievements[index - totalConquistadas];

              final icone = ach['icone'] ?? (isUnlocked ? '🌱' : '🔒');
              final nome = ach['nome'] ?? 'Conquista';

              return GestureDetector(
                onTap: () => _showAchievementModal(context, ach, isUnlocked),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUnlocked ? const Color(0xFFFAF9F5) : const Color(0xFFF3F2E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked
                          ? const Color(0xFFD08A45).withValues(alpha: 0.5)
                          : const Color(0xFFD0D0D0),
                      width: isUnlocked ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked
                              ? const Color(0xFFD08A45).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                        child: Center(
                          child: Text(
                            icone,
                            style: TextStyle(
                              fontSize: 22,
                              color: isUnlocked ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nome,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked ? const Color(0xFF1F2937) : const Color(0xFF565D6D),
                          fontSize: 11,
                          fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
