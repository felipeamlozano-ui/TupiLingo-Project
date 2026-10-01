import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/audio/audio_manager.dart';

// Barra de navegação inferior com ícones estilizados para Trilha, Prática, Perfil, Ajustes e Admin
class HomeBottomBar extends StatelessWidget {
  final int currentTabIndex;
  final bool isAdmin;
  final ValueChanged<int> onTabSelected;

  const HomeBottomBar({
    super.key,
    required this.currentTabIndex,
    required this.isAdmin,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final maxTabs = isAdmin ? 5 : 4;
    final safeIndex = currentTabIndex < maxTabs ? currentTabIndex : 0;
    final isDark = AppTheme.isDark(context);
    final accentGold = isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45);
    final primaryEmerald = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (idx) {
          AudioManager.instance.playTap();
          onTabSelected(idx);
        },
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        selectedItemColor: accentGold,
        unselectedItemColor: AppTheme.textSecondary(context),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_rounded),
            activeIcon: Icon(Icons.explore_rounded, color: accentGold),
            label: 'Trilha',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center_rounded),
            activeIcon: Icon(Icons.fitness_center_rounded, color: primaryEmerald),
            label: 'Prática',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded, color: accentGold),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            activeIcon: Icon(Icons.settings_rounded, color: primaryEmerald),
            label: 'Ajustes',
          ),
          if (isAdmin)
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              activeIcon: Icon(Icons.admin_panel_settings_rounded, color: primaryEmerald),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
