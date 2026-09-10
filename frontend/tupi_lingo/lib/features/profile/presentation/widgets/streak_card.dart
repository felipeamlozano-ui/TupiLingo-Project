import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;
  final int maiorStreak;

  const StreakCard({
    super.key,
    required this.streakDays,
    this.maiorStreak = 0,
  });

  String get motivationalMessage {
    if (streakDays <= 0) return 'Conclua uma lição hoje para acender a fogueira!';
    if (streakDays == 1) return 'A centelha ancestral foi acesa. Volte amanhã!';
    if (streakDays < 7) return 'O fogo sagrado está ardendo com força!';
    if (streakDays < 30) return 'Guerreiro de ferro! Constância digna dos ancestrais.';
    return 'Lenda viva de Pindorama! Seu hábito é inabalável.';
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = streakDays > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? const [Color(0xFFE05638), Color(0xFFC0392B)]
              : const [Color(0xFF7F8C8D), Color(0xFF565D6D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isActive ? const Color(0xFFE05638) : Colors.black)
                .withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // RepaintBoundary para isolar a renderização do ícone e animações
          RepaintBoundary(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isActive ? '🔥' : '🪵',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$streakDays ${streakDays == 1 ? "Dia" : "Dias"} de Ofensiva',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (maiorStreak > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Recorde: $maiorStreak d',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  motivationalMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
