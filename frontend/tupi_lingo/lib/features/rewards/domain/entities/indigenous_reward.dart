import 'package:flutter/foundation.dart';

enum RewardRarity {
  comum,
  raro,
  sagrado,
  mitico;

  String get label {
    switch (this) {
      case RewardRarity.comum: return 'Comum';
      case RewardRarity.raro: return 'Raro';
      case RewardRarity.sagrado: return 'Sagrado';
      case RewardRarity.mitico: return 'Mítico Ancestral';
    }
  }
}

@immutable
class IndigenousReward {
  final String id;
  final String name;
  final String emojiIcon;
  final RewardRarity rarity;
  final int xpBonus;
  final int conchasBonus;
  final String culturalLore;

  const IndigenousReward({
    required this.id,
    required this.name,
    required this.emojiIcon,
    required this.rarity,
    required this.xpBonus,
    required this.conchasBonus,
    required this.culturalLore,
  });

  static IndigenousReward sampleMuiraquita() {
    return const IndigenousReward(
      id: 'reward_muiraquita',
      name: 'Muiraquitã Sagrado de Jade',
      emojiIcon: '🐸',
      rarity: RewardRarity.sagrado,
      xpBonus: 75,
      conchasBonus: 50,
      culturalLore:
          'Amuleto esculpido em nefrita verde pelas lendárias Icamiabas (guerreiras do Nhamundá). '
          'Simboliza cura, coragem e proteção ancestral dos espíritos da floresta.',
    );
  }

  static IndigenousReward sampleAcangatar() {
    return const IndigenousReward(
      id: 'reward_acangatar',
      name: 'Acangatar de Penas de Arara',
      emojiIcon: '👑',
      rarity: RewardRarity.mitico,
      xpBonus: 120,
      conchasBonus: 80,
      culturalLore:
          'Diadema cerimonial de plumas de Arara Vermelha e Papagaio, usado por grandes Karai '
          '(líderes espirituais) para se conectar às forças solares de Kûarasy.',
    );
  }
}
