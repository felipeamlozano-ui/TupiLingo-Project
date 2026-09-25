import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// Barra de navegação inferior com ícones estilizados para Trilha, Prática, Perfil e Admin
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

  // Renderiza a barra de abas fixada no rodapé respeitando se o usuário é administrador
  @override
  Widget build(BuildContext context) {
    final maxTabs = isAdmin ? 4 : 3;
    final safeIndex = currentTabIndex < maxTabs ? currentTabIndex : 0;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: onTabSelected,
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        selectedItemColor: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45),
        unselectedItemColor: AppTheme.textSecondary(context),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_rounded),
            activeIcon: Icon(Icons.explore_rounded, color: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45)),
            label: 'Trilha',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center_rounded),
            activeIcon: Icon(Icons.fitness_center_rounded, color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)),
            label: 'Prática',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded, color: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45)),
            label: 'Perfil',
          ),
          if (isAdmin)
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              activeIcon: Icon(Icons.admin_panel_settings_rounded, color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
