import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Barra lateral em Glassmorphism responsiva para navegação entre os 3 consoles do TupiLingo Platform Suite.
class GlassSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onBackToApp;
  final double? width;

  const GlassSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onBackToApp,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          right: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Suite Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accent(context), AppTheme.accentDark(context)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent(context).withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TupiLingo',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'PLATFORM SUITE',
                        style: TextStyle(
                          color: AppTheme.accent(context),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.border(context), height: 1),
          const SizedBox(height: 16),

          // Menu de Navegação dos 3 Consoles
          _buildNavItem(
            context: context,
            index: 0,
            icon: Icons.map_outlined,
            activeIcon: Icons.map,
            title: 'World Builder CMS',
            subtitle: 'Canvas, Territórios & Snapshots',
          ),
          _buildNavItem(
            context: context,
            index: 1,
            icon: Icons.developer_board_outlined,
            activeIcon: Icons.developer_board,
            title: 'Developer Console',
            subtitle: 'Live Ops, Performance & AI',
          ),
          _buildNavItem(
            context: context,
            index: 2,
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield,
            title: 'Security & Observability',
            subtitle: 'Zero-PII, SOC & Merkle Audit',
          ),

          const Spacer(),
          Divider(color: AppTheme.border(context), height: 1),

          // Rodapé com Voltar ao App e Status de Rede
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.accent(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SRE Cluster Online',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '99.9%',
                        style: TextStyle(
                          color: AppTheme.accent(context),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onBackToApp,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border(context)),
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.surface(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, color: AppTheme.textSecondary(context), size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Retornar ao App',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent(context).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent(context).withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? AppTheme.accent(context)
                      : AppTheme.textSecondary(context),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.accent(context)
                              : AppTheme.textPrimary(context),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
