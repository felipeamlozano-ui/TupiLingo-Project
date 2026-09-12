import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class FillInTheBlankView extends StatelessWidget {
  final String textoComLacunas;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;

  const FillInTheBlankView({
    super.key,
    required this.textoComLacunas,
    required this.textController,
    required this.onChanged,
  });

  static const Color _primary = Color(0xFFD08A45);
  static const Color _accent = Color(0xFF0E5D4E);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _subtitle = Color(0xFF565D6D);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (textoComLacunas.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildFormattedLacuna(context, textoComLacunas),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          "Digite a palavra que completa a lacuna:",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _subtitle),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textController,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accent),
          decoration: InputDecoration(
            hintText: 'Sua resposta...',
            filled: true,
            fillColor: AppTheme.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormattedLacuna(BuildContext context, String texto) {
    if (!texto.contains('___')) {
      return Text(
        texto,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _accent,
          height: 1.5,
        ),
      );
    }

    final parts = texto.split('___');
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w500,
          color: _accent,
          height: 1.5,
        ),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primary, width: 1.5),
              ),
              child: Text(
                textController.text.trim().isNotEmpty
                    ? textController.text.trim()
                    : ' ______ ',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}
