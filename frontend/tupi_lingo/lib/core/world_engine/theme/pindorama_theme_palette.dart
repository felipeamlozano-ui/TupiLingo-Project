import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Paleta cromática adaptativa para o Pindorama 3D World Engine.
/// Sincroniza dinamicamente o terreno, os rios, a névoa de guerra e o HUD
/// com o tema cosmético equipado pelo usuário na Loja Ancestral.
class PindoramaThemePalette {
  final String themeId;
  final Color terrainBackground;
  final Color terrainPatchMata;
  final Color terrainPatchLitoral;
  final Color terrainPatchCerrado;
  final Color oceanStart;
  final Color oceanEnd;
  final Color riverDefault;
  final Color accent;
  final Color hudSurface;
  final Color hudBorder;
  final Color fogColor;
  final Color activeAura;

  const PindoramaThemePalette({
    required this.themeId,
    required this.terrainBackground,
    required this.terrainPatchMata,
    required this.terrainPatchLitoral,
    required this.terrainPatchCerrado,
    required this.oceanStart,
    required this.oceanEnd,
    required this.riverDefault,
    required this.accent,
    required this.hudSurface,
    required this.hudBorder,
    required this.fogColor,
    required this.activeAura,
  });

  /// Resolve a paleta a partir do tema cosmético atualmente equipado no app.
  factory PindoramaThemePalette.current() {
    final themeId = ThemeNotifier.instance.equippedTheme;
    return PindoramaThemePalette.fromId(themeId);
  }

  factory PindoramaThemePalette.fromId(String themeId) {
    switch (themeId) {
      case 'theme_noite_tupa':
        return const PindoramaThemePalette(
          themeId: 'theme_noite_tupa',
          terrainBackground: Color(0xFF18241C), // Solo noturno verde-musgo profundo
          terrainPatchMata: Color(0xFF1E3024),  // Dossel noturno de mata
          terrainPatchLitoral: Color(0xFF24382A), // Restinga noturna
          terrainPatchCerrado: Color(0xFF2B3E2F), // Campos sob luar
          oceanStart: Color(0xFF122C42),
          oceanEnd: Color(0xFF081422),
          riverDefault: Color(0xFF2DD4BF),
          accent: Color(0xFF818CF8),
          hudSurface: Color(0xEE0B1418),
          hudBorder: Color(0x6638BDF8),
          fogColor: Color(0x450C1720),
          activeAura: Color(0xFF38BDF8),
        );

      case 'theme_areia_sagrada':
        return const PindoramaThemePalette(
          themeId: 'theme_areia_sagrada',
          terrainBackground: Color(0xFF2A2015),
          terrainPatchMata: Color(0xFF3B2E1E),
          terrainPatchLitoral: Color(0xFF4C3C28),
          terrainPatchCerrado: Color(0xFF5A4832),
          oceanStart: Color(0xFF18444A),
          oceanEnd: Color(0xFF0E272C),
          riverDefault: Color(0xFF0D9488),
          accent: Color(0xFFD08A45),
          hudSurface: Color(0xEE1E170F),
          hudBorder: Color(0x66D08A45),
          fogColor: Color(0x40251B12),
          activeAura: Color(0xFFF59E0B),
        );

      case 'theme_fogo_caapora':
        return const PindoramaThemePalette(
          themeId: 'theme_fogo_caapora',
          terrainBackground: Color(0xFF221212),
          terrainPatchMata: Color(0xFF351C1C),
          terrainPatchLitoral: Color(0xFF452424),
          terrainPatchCerrado: Color(0xFF542D2D),
          oceanStart: Color(0xFF381515),
          oceanEnd: Color(0xFF1C0808),
          riverDefault: Color(0xFFF97316),
          accent: Color(0xFFEF4444),
          hudSurface: Color(0xEE1C0B0B),
          hudBorder: Color(0x66EF4444),
          fogColor: Color(0x40220F0F),
          activeAura: Color(0xFFF97316),
        );

      case 'theme_floresta_jade':
      default:
        return const PindoramaThemePalette(
          themeId: 'theme_floresta_jade',
          terrainBackground: Color(0xFF3B5E2E), // Solo continental verde floresta natural
          terrainPatchMata: Color(0xFF2C5532),  // Copa exuberante da mata
          terrainPatchLitoral: Color(0xFF527045),
          terrainPatchCerrado: Color(0xFF4A7238),
          oceanStart: Color(0xFF1B6B70),       // Águas costeiras rasas
          oceanEnd: Color(0xFF0F3245),         // Oceano Atlântico profundo
          riverDefault: Color(0xFF10B981),
          accent: Color(0xFFF59E0B),
          hudSurface: Color(0xEE0E1813),
          hudBorder: Color(0x6610B981),
          fogColor: Color(0x35142820),         // Brumas da mata em vez de vácuo preto
          activeAura: Color(0xFFFFD54F),
        );
    }
  }
}
