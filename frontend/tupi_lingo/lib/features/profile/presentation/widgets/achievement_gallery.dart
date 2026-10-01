import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/audio/audio_manager.dart';

/// Galeria de Medalhas e Conquistas Ancestrais do TupiLingo.
/// Apresenta medalhas categorizadas com tiers metálicos (Bronze, Prata, Ouro, Diamante),
/// filtros rápidos e modal com detalhes de lore e requisitos.
class AchievementGallery extends StatefulWidget {
  final List<Map<String, dynamic>> unlockedAchievements;
  final List<Map<String, dynamic>> lockedAchievements;

  const AchievementGallery({
    super.key,
    required this.unlockedAchievements,
    required this.lockedAchievements,
  });

  @override
  State<AchievementGallery> createState() => _AchievementGalleryState();
}

class _AchievementGalleryState extends State<AchievementGallery> {
  String _selectedCategory = 'Todas';

  Color _getTierColor(String? tier, bool isDark) {
    switch (tier?.toLowerCase()) {
      case 'diamante':
        return isDark ? const Color(0xFF00E5FF) : const Color(0xFF00B4D8);
      case 'ouro':
        return isDark ? const Color(0xFFFFD700) : const Color(0xFFD4AF37);
      case 'prata':
        return isDark ? const Color(0xFFC0C0C0) : const Color(0xFFA8A9AD);
      case 'bronze':
      default:
        return const Color(0xFFCD7F32);
    }
  }

  String _getCategoryName(String? tipo) {
    switch (tipo) {
      case 'xp_tier':
        return 'Sabedoria (XP)';
      case 'streak':
        return 'Ofensiva';
      case 'bau':
        return 'Baús';
      case 'vocabulario':
        return 'Vocabulário';
      case 'cultural':
      default:
        return 'Capítulos';
    }
  }

  void _showAchievementModal(BuildContext context, Map<String, dynamic> ach, bool isUnlocked) {
    AudioManager.instance.playTap();
    final isDark = AppTheme.isDark(context);
    final tier = ach['tier']?.toString() ?? 'bronze';
    final tierColor = _getTierColor(tier, isDark);
    final nome = ach['nome'] ?? 'Conquista';
    final desc = ach['descricao'] ?? '';
    final icone = ach['icone'] ?? '🏅';
    final xpNecessario = ach['xp_necessario'] ?? 0;
    final conquistadaEm = ach['conquistada_em'];
    final tipo = ach['tipo']?.toString() ?? 'cultural';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? tierColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isUnlocked ? tierColor : Colors.grey.withValues(alpha: 0.4),
                      width: 3,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      icone,
                      style: TextStyle(
                        fontSize: 40,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tier.toUpperCase(),
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getCategoryName(tipo),
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  nome,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (isUnlocked && conquistadaEm != null)
                  Text(
                    'Desbloqueada em ${_formatDate(conquistadaEm.toString())}',
                    style: TextStyle(
                      color: AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (!isUnlocked && xpNecessario > 0)
                  Text(
                    'Requisito: $xpNecessario XP na jornada',
                    style: const TextStyle(color: Color(0xFFD08A45), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? tierColor : AppTheme.border(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
    final isDark = AppTheme.isDark(context);
    final totalConquistadas = widget.unlockedAchievements.length;
    final total = totalConquistadas + widget.lockedAchievements.length;

    // Combina todas as conquistas marcando o status
    final allList = <Map<String, dynamic>>[];
    for (final a in widget.unlockedAchievements) {
      allList.add({...a, 'is_unlocked': true});
    }
    for (final a in widget.lockedAchievements) {
      allList.add({...a, 'is_unlocked': false});
    }

    // Filtra pela categoria selecionada
    final filtered = allList.where((ach) {
      if (_selectedCategory == 'Todas') return true;
      if (_selectedCategory == 'Sabedoria' && ach['tipo'] == 'xp_tier') return true;
      if (_selectedCategory == 'Ofensiva' && ach['tipo'] == 'streak') return true;
      if (_selectedCategory == 'Baús' && ach['tipo'] == 'bau') return true;
      if (_selectedCategory == 'Léxico' && ach['tipo'] == 'vocabulario') return true;
      if (_selectedCategory == 'Capítulos' && ach['tipo'] == 'cultural') return true;
      return false;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
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
              Expanded(
                child: Row(
                  children: [
                    const Text('🏅', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Medalhas & Conquistas',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD08A45).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$totalConquistadas / $total',
                  style: const TextStyle(
                    color: Color(0xFFD08A45),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pílulas de filtro por categoria
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Todas', 'Sabedoria', 'Ofensiva', 'Baús', 'Capítulos', 'Léxico'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    AudioManager.instance.playTap();
                    setState(() => _selectedCategory = cat);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E))
                          : AppTheme.surfaceSubtle(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppTheme.border(context),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Nenhuma medalha nesta categoria.',
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final ach = filtered[index];
                final isUnlocked = ach['is_unlocked'] == true;
                final tier = ach['tier']?.toString() ?? 'bronze';
                final tierColor = _getTierColor(tier, isDark);
                final icone = ach['icone'] ?? (isUnlocked ? '🌱' : '🔒');
                final nome = ach['nome'] ?? 'Conquista';

                return GestureDetector(
                  onTap: () => _showAchievementModal(context, ach, isUnlocked),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? AppTheme.surfaceSubtle(context)
                          : (isDark ? const Color(0xFF131B18) : const Color(0xFFF3F2E8)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnlocked ? tierColor.withValues(alpha: 0.6) : AppTheme.border(context),
                        width: isUnlocked ? 1.8 : 1,
                      ),
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color: tierColor.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
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
                                ? tierColor.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF1E2A25) : const Color(0xFFEAE7DC)),
                            border: Border.all(
                              color: isUnlocked ? tierColor : Colors.grey.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isUnlocked ? icone : '🔒',
                              style: TextStyle(
                                fontSize: isUnlocked ? 20 : 16,
                                color: isUnlocked ? null : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            nome,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnlocked ? AppTheme.textPrimary(context) : AppTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                            ),
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
