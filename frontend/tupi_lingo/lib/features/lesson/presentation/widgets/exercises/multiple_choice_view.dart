import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class MultipleChoiceView extends StatelessWidget {
  final List<dynamic> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const MultipleChoiceView({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const Color _primary = Color(0xFFD08A45);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _subtitle = Color(0xFF565D6D);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(options.length, (index) {
        final text = options[index].toString();
        final isSelected = selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primary.withValues(alpha: 0.1)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primary : _border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primary : _subtitle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
