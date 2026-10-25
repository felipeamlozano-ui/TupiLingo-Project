import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/core/utils/stable_shuffle.dart';

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
  int? _selectedRightIndex;
  late Map<int, int> _associations;
  late List<int> _displayRightIndices;

  static const Color _primary = Color(0xFFD08A45);
  static const Color _accent = Color(0xFF0E5D4E);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _subtitle = Color(0xFF565D6D);

  static const List<Color> _pairPalette = [
    Color(0xFF0E5D4E),
    Color(0xFFD08A45),
    Color(0xFF2C5E8A),
    Color(0xFF8B4513),
    Color(0xFF6B4423),
    Color(0xFF386641),
  ];

  @override
  void initState() {
    super.initState();
    _associations = Map<int, int>.from(widget.initialAssociations);
    _initDisplayIndices();
  }

  void _initDisplayIndices() {
    _displayRightIndices = StableShuffle.derangedIndices(widget.rightItems.length);
  }

  @override
  void didUpdateWidget(covariant MatchingColumnsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rightItems.length != widget.rightItems.length ||
        oldWidget.leftItems.length != widget.leftItems.length) {
      _associations = Map<int, int>.from(widget.initialAssociations);
      _selectedLeftIndex = null;
      _selectedRightIndex = null;
      _initDisplayIndices();
    }
  }

  Color _getPairColor(int pairIndex) {
    return _pairPalette[pairIndex % _pairPalette.length];
  }

  void _linkPair(int leftOriginalIdx, int rightOriginalIdx) {
    setState(() {
      _associations.removeWhere((k, v) => k == leftOriginalIdx || v == rightOriginalIdx);
      _associations[leftOriginalIdx] = rightOriginalIdx;
      _selectedLeftIndex = null;
      _selectedRightIndex = null;
      widget.onAssociationsChanged(_associations);
    });
  }

  void _removeMatchForLeft(int leftIdx) {
    setState(() {
      _associations.remove(leftIdx);
      widget.onAssociationsChanged(_associations);
    });
  }

  void _removeMatchForRight(int rightIdx) {
    setState(() {
      _associations.removeWhere((_, v) => v == rightIdx);
      widget.onAssociationsChanged(_associations);
    });
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
                children: List.generate(widget.leftItems.length, (leftIdx) {
                  final text = widget.leftItems[leftIdx].toString();
                  final bool isSelected = _selectedLeftIndex == leftIdx;
                  final bool isMatched = _associations.containsKey(leftIdx);
                  final pairColor = isMatched ? _getPairColor(leftIdx) : _accent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        if (_selectedRightIndex != null) {
                          _linkPair(leftIdx, _selectedRightIndex!);
                        } else if (isMatched) {
                          _removeMatchForLeft(leftIdx);
                        } else {
                          setState(() {
                            _selectedLeftIndex = (_selectedLeftIndex == leftIdx) ? null : leftIdx;
                            _selectedRightIndex = null;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _primary.withValues(alpha: 0.15)
                              : isMatched
                                  ? pairColor.withValues(alpha: 0.10)
                                  : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? _primary
                                : isMatched
                                    ? pairColor
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
                                          ? pairColor
                                          : _subtitle,
                                ),
                              ),
                            ),
                            if (isMatched) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pairColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${leftIdx + 1}',
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
            // Coluna da Direita (Embaralhada com Derangement sem reembaralhar em cliques)
            Expanded(
              child: Column(
                children: List.generate(widget.rightItems.length, (slotIdx) {
                  final rightIdx = _displayRightIndices.length > slotIdx
                      ? _displayRightIndices[slotIdx]
                      : slotIdx;
                  final text = widget.rightItems[rightIdx].toString();

                  int? matchedLeft;
                  for (final entry in _associations.entries) {
                    if (entry.value == rightIdx) {
                      matchedLeft = entry.key;
                      break;
                    }
                  }
                  final bool isMatched = matchedLeft != null;
                  final bool isSelected = _selectedRightIndex == rightIdx;
                  final pairColor = isMatched ? _getPairColor(matchedLeft) : _accent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        if (_selectedLeftIndex != null) {
                          _linkPair(_selectedLeftIndex!, rightIdx);
                        } else if (isMatched) {
                          _removeMatchForRight(rightIdx);
                        } else {
                          setState(() {
                            _selectedRightIndex = (_selectedRightIndex == rightIdx) ? null : rightIdx;
                            _selectedLeftIndex = null;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _primary.withValues(alpha: 0.15)
                              : isMatched
                                  ? pairColor.withValues(alpha: 0.10)
                                  : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? _primary
                                : isMatched
                                    ? pairColor
                                    : _border,
                            width: isSelected || isMatched ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isMatched) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pairColor,
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
                                  color: isSelected
                                      ? _primary
                                      : isMatched
                                          ? pairColor
                                          : _subtitle,
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

