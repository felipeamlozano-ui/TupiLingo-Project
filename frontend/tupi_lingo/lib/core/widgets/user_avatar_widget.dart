import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/store/services/store_service.dart';

/// Modelo descritivo dos avatares e molduras equipáveis
class AvatarCosmeticConfig {
  final String id;
  final String label;
  final String icon;
  final List<Color> gradientColors;
  final Color shadowColor;

  const AvatarCosmeticConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
  });

  static const Map<String, AvatarCosmeticConfig> catalog = {
    'avatar_arara': AvatarCosmeticConfig(
      id: 'avatar_arara',
      label: 'Arara Vermelha',
      icon: '🦜',
      gradientColors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B)],
      shadowColor: Color(0x66EF4444),
    ),
    'avatar_maraka': AvatarCosmeticConfig(
      id: 'avatar_maraka',
      label: 'Guerreiro Maracá',
      icon: '🏹',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
      shadowColor: Color(0x6610B981),
    ),
    'avatar_xama': AvatarCosmeticConfig(
      id: 'avatar_xama',
      label: 'Xamã das Matas',
      icon: '🧙‍♂️',
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF5B21B6)],
      shadowColor: Color(0x668B5CF6),
    ),
    'avatar_onca': AvatarCosmeticConfig(
      id: 'avatar_onca',
      label: 'Onça Pintada',
      icon: '🐆',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
      shadowColor: Color(0x66F59E0B),
    ),
    'avatar_tamandua': AvatarCosmeticConfig(
      id: 'avatar_tamandua',
      label: 'Tamanduá Guardião',
      icon: '🦔',
      gradientColors: [Color(0xFFA16207), Color(0xFF854D0E), Color(0xFF713F12)],
      shadowColor: Color(0x66854D0E),
    ),
  };
}

class FrameCosmeticConfig {
  final String id;
  final String label;
  final String icon;
  final Color primaryColor;
  final Color secondaryColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  const FrameCosmeticConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    this.borderWidth = 3.5,
    this.shadows = const [],
  });

  static const Map<String, FrameCosmeticConfig> catalog = {
    'frame_madeira': FrameCosmeticConfig(
      id: 'frame_madeira',
      label: 'Madeira Rústica',
      icon: '🪵',
      primaryColor: Color(0xFF854D0E),
      secondaryColor: Color(0xFF5A330A),
      borderWidth: 3.5,
      shadows: [
        BoxShadow(color: Color(0x555A330A), blurRadius: 6, offset: Offset(0, 3)),
      ],
    ),
    'frame_penas': FrameCosmeticConfig(
      id: 'frame_penas',
      label: 'Diadema de Penas Sagradas',
      icon: '🪶',
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFF87171),
      borderWidth: 3.5,
      shadows: [
        BoxShadow(color: Color(0x66EF4444), blurRadius: 8, spreadRadius: 1),
      ],
    ),
    'frame_ouro_sol': FrameCosmeticConfig(
      id: 'frame_ouro_sol',
      label: 'Aura Solar de Guaraci',
      icon: '☀️',
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFFBBF24),
      borderWidth: 4.0,
      shadows: [
        BoxShadow(color: Color(0x88F59E0B), blurRadius: 12, spreadRadius: 2),
      ],
    ),
    'frame_grafismo': FrameCosmeticConfig(
      id: 'frame_grafismo',
      label: 'Grafismo Kadiwéu',
      icon: '💠',
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF34D399),
      borderWidth: 3.5,
      shadows: [
        BoxShadow(color: Color(0x6610B981), blurRadius: 8, spreadRadius: 1),
      ],
    ),
  };
}

/// Widget reativo e imersivo para exibição do Avatar e Moldura do usuário
/// Conecta-se automaticamente com o StoreService e atualiza em tempo real.
class UserAvatarWidget extends StatelessWidget {
  final String userName;
  final double size;
  final String? overrideAvatarId;
  final String? overrideFrameId;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const UserAvatarWidget({
    super.key,
    required this.userName,
    this.size = 64.0,
    this.overrideAvatarId,
    this.overrideFrameId,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: StoreService.equippedCosmeticsNotifier,
      builder: (context, equippedMap, _) {
        final activeAvatarId = overrideAvatarId ?? equippedMap['avatar'] ?? 'avatar_arara';
        final activeFrameId = overrideFrameId ?? equippedMap['frame'] ?? 'frame_madeira';

        final avatarConfig = AvatarCosmeticConfig.catalog[activeAvatarId];
        final frameConfig = FrameCosmeticConfig.catalog[activeFrameId] ??
            FrameCosmeticConfig.catalog['frame_madeira']!;

        final isDark = AppTheme.isDark(context);

        Widget content = Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Efeito de halo/brilho no fundo da moldura (se houver sombra no frame)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: frameConfig.shadows,
              ),
            ),

            // Base do Avatar (Gradiente e Ícone/Letra)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: avatarConfig?.gradientColors ??
                      const [Color(0xFFD08A45), Color(0xFFA56627)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: frameConfig.primaryColor,
                  width: frameConfig.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: avatarConfig?.shadowColor ?? const Color(0x44D08A45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: avatarConfig != null
                    ? Text(
                        avatarConfig.icon,
                        style: TextStyle(
                          fontSize: size * 0.46,
                          height: 1.0,
                        ),
                      )
                    : Text(
                        userName.trim().isNotEmpty
                            ? userName.trim()[0].toUpperCase()
                            : 'G',
                        style: TextStyle(
                          fontSize: size * 0.44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            // Ornamento sutil do frame no topo (ex: penas ou sol)
            if (activeFrameId == 'frame_penas')
              Positioned(
                top: -size * 0.08,
                right: -size * 0.04,
                child: Container(
                  padding: EdgeInsets.all(size * 0.04),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    '🪶',
                    style: TextStyle(fontSize: size * 0.22, height: 1.0),
                  ),
                ),
              ),

            if (activeFrameId == 'frame_ouro_sol')
              Positioned(
                top: -size * 0.08,
                left: -size * 0.04,
                child: Container(
                  padding: EdgeInsets.all(size * 0.04),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    '☀️',
                    style: TextStyle(fontSize: size * 0.20, height: 1.0),
                  ),
                ),
              ),

            // Badge de troca/edição (abre a loja ao clicar)
            if (showEditBadge)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E5D4E) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surface(context),
                      width: 2.0,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );

        if (onTap != null) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size),
            child: content,
          );
        }

        return content;
      },
    );
  }
}
