import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class MatchingColumnsView extends StatefulWidget {
  final List<dynamic> leftItems;
  final List<dynamic> rightItems;
  final Map<int, int> initialAssociations;
  final ValueChanged<Map<int, int>> onAssociationsChanged;

  const MatchingColumnsView({
    super.key,
    required this.leftItems,
    required this.rightItems,
    required this.initialAssociations,
    required this.onAssociationsChanged,
  });

  @override
  State<MatchingColumnsView> createState() => _MatchingColumnsViewState();
}

class _MatchingColumnsViewState extends State<MatchingColumnsView> {
  int? _selectedLeftIndex;
  late Map<int, int> _associations;

  static const Color _primary = Color(0xFFD08A45);
  static const Color _accent = Color(0xFF0E5D4E);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _subtitle = Color(0xFF565D6D);

  @override
  void initState() {
    super.initState();
    _associations = Map<int, int>.from(widget.initialAssociations);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Toque em uma palavra à esquerda e depois na sua tradução correspondente à direita:",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _subtitle),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna da Esquerda
            Expanded(
              child: Column(
                children: List.generate(widget.leftItems.length, (i) {
                  final text = widget.leftItems[i].toString();
                  final bool isSelected = _selectedLeftIndex == i;
                  final bool isMatched = _associations.containsKey(i);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedLeftIndex == i) {
                            _selectedLeftIndex = null;
                          } else {
                            _selectedLeftIndex = i;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _primary.withValues(alpha: 0.15)
                              : isMatched
                                  ? _accent.withValues(alpha: 0.08)
                                  : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? _primary
                                : isMatched
                                    ? _accent
                                    : _border,
                            width: isSelected || isMatched ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? _primary
                                      : isMatched
                                          ? _accent
                                          : _subtitle,
                                ),
                              ),
                            ),
                            if (isMatched) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            // Coluna da Direita
            Expanded(
              child: Column(
                children: List.generate(widget.rightItems.length, (j) {
                  final text = widget.rightItems[j].toString();
                  int? matchedLeft;
                  for (final entry in _associations.entries) {
                    if (entry.value == j) {
                      matchedLeft = entry.key;
                      break;
                    }
                  }
                  final bool isMatched = matchedLeft != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedLeftIndex != null) {
                            _associations.removeWhere((k, v) => v == j);
                            _associations[_selectedLeftIndex!] = j;
                            _selectedLeftIndex = null;
                            widget.onAssociationsChanged(_associations);
                          } else if (isMatched) {
                            _associations.remove(matchedLeft);
                            widget.onAssociationsChanged(_associations);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? _accent.withValues(alpha: 0.08)
                              : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMatched ? _accent : _border,
                            width: isMatched ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isMatched) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${matchedLeft + 1}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isMatched ? _accent : _subtitle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
