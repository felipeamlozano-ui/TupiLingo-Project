import 'package:flutter/material.dart';

enum CosmeticType {
  theme,
  avatar,
  frame,
  specialLesson;

  static CosmeticType fromString(String raw) {
    switch (raw) {
      case 'theme':
        return CosmeticType.theme;
      case 'avatar':
        return CosmeticType.avatar;
      case 'frame':
        return CosmeticType.frame;
      case 'special_lesson':
        return CosmeticType.specialLesson;
      default:
        return CosmeticType.theme;
    }
  }

  String toServerString() {
    switch (this) {
      case CosmeticType.theme:
        return 'theme';
      case CosmeticType.avatar:
        return 'avatar';
      case CosmeticType.frame:
        return 'frame';
      case CosmeticType.specialLesson:
        return 'special_lesson';
    }
  }

  String get label {
    switch (this) {
      case CosmeticType.theme:
        return 'Tema';
      case CosmeticType.avatar:
        return 'Avatar';
      case CosmeticType.frame:
        return 'Moldura';
      case CosmeticType.specialLesson:
        return 'Lição Especial';
    }
  }
}

class StoreItem {
  final String id;
  final String name;
  final CosmeticType type;
  final String description;
  final int price;
  final String icon;
  final String lore;
  final Color previewColor;
  final bool isUnlocked;
  final bool isEquipped;

  const StoreItem({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.price,
    required this.icon,
    required this.lore,
    required this.previewColor,
    this.isUnlocked = false,
    this.isEquipped = false,
  });

  factory StoreItem.fromJson(
    Map<String, dynamic> json, {
    bool isUnlocked = false,
    bool isEquipped = false,
  }) {
    final hexColor = json['preview_color'] as String? ?? '#0E5D4E';
    final parsedColor = _parseColor(hexColor);

    return StoreItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: CosmeticType.fromString(json['type'] as String? ?? 'theme'),
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      icon: json['icon'] as String? ?? '🐚',
      lore: json['lore'] as String? ?? '',
      previewColor: parsedColor,
      isUnlocked: isUnlocked,
      isEquipped: isEquipped,
    );
  }

  StoreItem copyWith({
    bool? isUnlocked,
    bool? isEquipped,
  }) {
    return StoreItem(
      id: id,
      name: name,
      type: type,
      description: description,
      price: price,
      icon: icon,
      lore: lore,
      previewColor: previewColor,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }

  static Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF0E5D4E);
    }
  }
}
