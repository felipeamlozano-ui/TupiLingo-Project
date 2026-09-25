import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Desenha a divisória de seção com tipografia destacada e linha sutil.
Widget buildSectionDivider(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.accent(context),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppTheme.border(context), height: 1)),
      ],
    ),
  );
}

// Rótulo padrão de campo no painel com tipografia seminegrito.
Widget buildFieldLabel(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textSecondary(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// Seletor circular de paleta de cores para customização visual de entidades.
Widget buildColorPicker({
  required BuildContext context,
  required String currentHex,
  required List<Map<String, dynamic>> options,
  required ValueChanged<String> onSelect,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((opt) {
      final hex = opt['hex'] as String;
      final color = opt['color'] as Color;
      final name = opt['name'] as String;
      final isSelected = currentHex.toUpperCase() == hex.toUpperCase();

      return Tooltip(
        message: name,
        child: InkWell(
          onTap: () => onSelect(hex),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.black26,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
            child: isSelected
                ? const Center(child: Icon(Icons.check, size: 16, color: Colors.white))
                : null,
          ),
        ),
      );
    }).toList(),
  );
}

// Configura o estilo padrão dos inputs de texto do painel de propriedades.
InputDecoration entityInputDecoration(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
      fontSize: 12,
    ),
    filled: true,
    fillColor: AppTheme.surfaceSubtle(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.border(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.border(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.accent(context)),
    ),
  );
}
