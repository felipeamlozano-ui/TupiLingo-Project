import 'package:flutter/material.dart';

/// 8 Canonical Historical Biomes of Pindorama (RFC-012C Chapter 6).
enum BiomeType {
  mataAtlantica,
  litoral,
  amazonia,
  cerrado,
  caatinga,
  pantanal,
  manguezais,
  camposSulinos;

  String get title => BiomeStyle.registry[this]?.name ?? name;
}

/// Visual style, color palette, and audio atmosphere for a historical biome.
@immutable
class BiomeStyle {
  final BiomeType type;
  final String name;
  final String description;
  final Color primaryColor;
  final Color reliefColor;
  final Color waterColor;
  final Color foliageColor;
  final Color accentGlow;
  final String ambientSound;

  const BiomeStyle({
    required this.type,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.reliefColor,
    required this.waterColor,
    required this.foliageColor,
    required this.accentGlow,
    required this.ambientSound,
  });

  /// Master biome registry with authentic historical palettes
  static const Map<BiomeType, BiomeStyle> registry = {
    BiomeType.mataAtlantica: BiomeStyle(
      type: BiomeType.mataAtlantica,
      name: 'Mata Atlântica',
      description: 'Florestas costeiras densas, terras sagradas de Tupinambá e Tupiniquim.',
      primaryColor: Color(0xFF0E3D32),
      reliefColor: Color(0xFF145949),
      waterColor: Color(0xFF2E9383),
      foliageColor: Color(0xFF1EC9A5),
      accentGlow: Color(0xFF2BF2C7),
      ambientSound: 'audio/ambience_mata_atlantica.ogg',
    ),
    BiomeType.litoral: BiomeStyle(
      type: BiomeType.litoral,
      name: 'Litoral e Restingas',
      description: 'Falésias, praias e águas azuis percorridas por canoas de guerra.',
      primaryColor: Color(0xFFE8DFCE),
      reliefColor: Color(0xFFC67D3B),
      waterColor: Color(0xFF1A8077),
      foliageColor: Color(0xFF2EBFA5),
      accentGlow: Color(0xFF64DFDF),
      ambientSound: 'audio/ambience_litoral.ogg',
    ),
    BiomeType.amazonia: BiomeStyle(
      type: BiomeType.amazonia,
      name: 'Amazônia Ancestral',
      description: 'Vastidão verde e rios caudalosos, berço da cerâmica marajoara.',
      primaryColor: Color(0xFF07261F),
      reliefColor: Color(0xFF0B483B),
      waterColor: Color(0xFF7D5C3A), // Águas barrentas do Solimões
      foliageColor: Color(0xFF126351),
      accentGlow: Color(0xFF22C55E),
      ambientSound: 'audio/ambience_amazonia.ogg',
    ),
    BiomeType.cerrado: BiomeStyle(
      type: BiomeType.cerrado,
      name: 'Cerrado e Planalto',
      description: 'Solo terracota e árvores retorcidas, berço das águas continentais.',
      primaryColor: Color(0xFFA25A2B),
      reliefColor: Color(0xFF82451E),
      waterColor: Color(0xFF38908F),
      foliageColor: Color(0xFFD8A55B),
      accentGlow: Color(0xFFF59E0B),
      ambientSound: 'audio/ambience_cerrado.ogg',
    ),
    BiomeType.caatinga: BiomeStyle(
      type: BiomeType.caatinga,
      name: 'Caatinga',
      description: 'Solo argiloso resistente com mandacarus e sabedorias do sertão.',
      primaryColor: Color(0xFFB8734A),
      reliefColor: Color(0xFF8A512F),
      waterColor: Color(0xFF5C9EAD),
      foliageColor: Color(0xFF3D5A45),
      accentGlow: Color(0xFFEF4444),
      ambientSound: 'audio/ambience_caatinga.ogg',
    ),
    BiomeType.pantanal: BiomeStyle(
      type: BiomeType.pantanal,
      name: 'Pantanal e Várzeas',
      description: 'Planícies alagadas e espelhos d\'água habitados por aves sagradas.',
      primaryColor: Color(0xFF184D43),
      reliefColor: Color(0xFF236B5E),
      waterColor: Color(0xFF4FA497),
      foliageColor: Color(0xFF2A7356),
      accentGlow: Color(0xFF10B981),
      ambientSound: 'audio/ambience_pantanal.ogg',
    ),
    BiomeType.manguezais: BiomeStyle(
      type: BiomeType.manguezais,
      name: 'Manguezais e Estuários',
      description: 'Berçário da vida marinha com raízes aéreas entre o rio e o mar.',
      primaryColor: Color(0xFF3A2F28),
      reliefColor: Color(0xFF211E1C),
      waterColor: Color(0xFF1B3F38),
      foliageColor: Color(0xFF1D5A4A),
      accentGlow: Color(0xFF14B8A6),
      ambientSound: 'audio/ambience_mangue.ogg',
    ),
    BiomeType.camposSulinos: BiomeStyle(
      type: BiomeType.camposSulinos,
      name: 'Campos Sulinos',
      description: 'Coxilhas suaves e horizontes abertos dos povos Carijó e Guarani.',
      primaryColor: Color(0xFF4F7846),
      reliefColor: Color(0xFF3D5E37),
      waterColor: Color(0xFF4A8CA6),
      foliageColor: Color(0xFF8BA888),
      accentGlow: Color(0xFF84CC16),
      ambientSound: 'audio/ambience_pampas.ogg',
    ),
  };

  static BiomeStyle get(BiomeType type) => registry[type] ?? registry[BiomeType.mataAtlantica]!;
}
