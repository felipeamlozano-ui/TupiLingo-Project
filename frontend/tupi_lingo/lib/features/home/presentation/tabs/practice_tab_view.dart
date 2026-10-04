import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Modelo de tema para a prática contextualizada.
class PracticeThemeItem {
  final String id;
  final String titulo;
  final IconData icone;
  final String desc;
  final int xp;
  final int conchas;

  const PracticeThemeItem({
    required this.id,
    required this.titulo,
    required this.icone,
    required this.desc,
    required this.xp,
    required this.conchas,
  });
}

/// Aba de prática contextualizada, revisão espaçada e banco de vocabulário da trilha.
class PracticeTabView extends StatelessWidget {
  final int highestChapterReached;
  final List<Map<String, String>> vocabularyBank;
  final String vocabCategoryFilter;
  final ValueChanged<String> onVocabCategoryChanged;
  final VoidCallback onStartFlashcardSession;
  final void Function(String tema, {String? temaId}) onOpenThematicPractice;
  final VoidCallback onShowCustomThemeDialog;

  static const List<PracticeThemeItem> predefinedThemes = [
    PracticeThemeItem(
      id: 'natureza',
      titulo: 'Natureza e Rios',
      icone: Icons.forest_rounded,
      desc: 'Águas, matas e cosmos',
      xp: 20,
      conchas: 3,
    ),
    PracticeThemeItem(
      id: 'animais',
      titulo: 'Animais e Caça',
      icone: Icons.pets_rounded,
      desc: 'Onças, aves e fauna',
      xp: 20,
      conchas: 3,
    ),
    PracticeThemeItem(
      id: 'mitologia',
      titulo: 'Mitologia e Tupã',
      icone: Icons.auto_awesome_rounded,
      desc: 'Entidades e cosmologia',
      xp: 25,
      conchas: 4,
    ),
    PracticeThemeItem(
      id: 'aldeia',
      titulo: 'Aldeia e Cotidiano',
      icone: Icons.cottage_rounded,
      desc: 'Oka, taba e comunidade',
      xp: 20,
      conchas: 3,
    ),
    PracticeThemeItem(
      id: 'guerra',
      titulo: 'Guerra e Rituais',
      icone: Icons.shield_rounded,
      desc: 'Armas, lideranças e cantos',
      xp: 25,
      conchas: 4,
    ),
    PracticeThemeItem(
      id: 'culinaria',
      titulo: 'Culinária e Roça',
      icone: Icons.restaurant_rounded,
      desc: 'Mandioca, cauim e peixes',
      xp: 20,
      conchas: 3,
    ),
  ];

  const PracticeTabView({
    super.key,
    required this.highestChapterReached,
    required this.vocabularyBank,
    required this.vocabCategoryFilter,
    required this.onVocabCategoryChanged,
    required this.onStartFlashcardSession,
    required this.onOpenThematicPractice,
    required this.onShowCustomThemeDialog,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD08A45);
    const accentColor = Color(0xFF0E5D4E);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text(
              'Centro de Prática Ancestral',
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fortaleça sua memória com treinos rápidos e revisão espaçada.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Card Destaque: Revisão Diária
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E5D4E), Color(0xFF094338)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revisão Espaçada',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '4 palavras prontas para fixação hoje',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStartFlashcardSession,
                      icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                      label: const Text('PRATICAR AGORA (+15 XP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Treino Temático Contextual',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Prática Dinâmica',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pratique com questões contextualizadas usando o acervo histórico primário.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Carrossel/Cards de Temas Interativos
            _buildThematicPracticeSection(context),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Banco de Vocabulário da Trilha',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Palavras ensinadas até o Capítulo $highestChapterReached',
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '${vocabularyBank.length} termos',
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filtro por categoria gramatical / semântica
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  'Todas',
                  'Saudações',
                  'Comunidade',
                  'Pessoas',
                  'Natureza',
                  'Fauna',
                  'Alimentos',
                  'Espiritualidade',
                ].map((cat) {
                  final isSelected = vocabCategoryFilter == cat;
                  return GestureDetector(
                    onTap: () => onVocabCategoryChanged(cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : accentColor)
                            : AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : AppTheme.border(context),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary(context),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            if (vocabularyBank.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Center(
                  child: Text(
                    'Nenhum termo nesta categoria ainda. Continue avançando na trilha!',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              // Lista de Vocabulário Interativa
              ...vocabularyBank.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.translate_rounded, color: primaryColor, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['tupi'] ?? '',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary(context),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '[${item['pronuncia'] ?? ''}]',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary(context).withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['pt'] ?? '',
                              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['cat'] ?? '',
                          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildThematicPracticeSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: predefinedThemes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final t = predefinedThemes[idx];
              return InkWell(
                onTap: () => onOpenThematicPractice(t.titulo, temaId: t.id),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 165,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(t.icone, size: 20, color: const Color(0xFF0E5D4E)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${t.xp} XP',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.titulo,
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.desc,
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onShowCustomThemeDialog,
            icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0E5D4E)),
            label: const Text(
              'DIGITAR TEMA PERSONALIZADO...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0E5D4E), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
