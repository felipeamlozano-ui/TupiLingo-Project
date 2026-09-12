import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class FlashcardPracticeDialog extends StatefulWidget {
  final List<Map<String, String>> vocabulary;
  const FlashcardPracticeDialog({super.key, required this.vocabulary});

  @override
  State<FlashcardPracticeDialog> createState() => _FlashcardPracticeDialogState();
}

class _FlashcardPracticeDialogState extends State<FlashcardPracticeDialog> {
  int _currentIndex = 0;
  bool _revealed = false;
  int _reviewedCount = 0;

  static const Color _primary = Color(0xFF0E5D4E);
  static const Color _accent = Color(0xFFD08A45);

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.vocabulary.length) {
      return AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              'Revisão Concluída!',
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Você revisou $_reviewedCount palavras ancestrais com sucesso.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : _accent,
              ),
              child: const Text('Concluir (+15 XP)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final item = widget.vocabulary[_currentIndex];

    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Palavra ${_currentIndex + 1}/${widget.vocabulary.length}',
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.textSecondary(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _revealed = !_revealed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _revealed
                      ? (AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : _accent)
                      : _primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['tupi']!,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '[${item['pronuncia']!}]',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_revealed)
                    Text(
                      item['pt']!,
                      style: TextStyle(
                        color: AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : _accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Toque para ver a tradução',
                      style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex++;
                      _revealed = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary(context),
                    side: BorderSide(color: AppTheme.border(context)),
                  ),
                  child: const Text('Rever Depois'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _reviewedCount++;
                      _currentIndex++;
                      _revealed = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : _accent,
                  ),
                  child: const Text('Acertei!', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
