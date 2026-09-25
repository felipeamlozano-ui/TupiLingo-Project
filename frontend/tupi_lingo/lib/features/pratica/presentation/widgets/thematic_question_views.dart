import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// Alternativas de múltipla escolha com destaque na opção clicada
class ThematicMultipleChoiceView extends StatelessWidget {
  final Map<String, dynamic> question;
  final String? selectedOption;
  final ValueChanged<String> onSelect;

  const ThematicMultipleChoiceView({
    super.key,
    required this.question,
    required this.selectedOption,
    required this.onSelect,
  });

  // Renderiza a lista de alternativas com letras A, B, C, D em cards interativos
  @override
  Widget build(BuildContext context) {
    final alts = (question['alternativas'] as List?) ?? [];
    return Column(
      children: alts.map((alt) {
        final letra = alt['letra'] ?? '';
        final texto = alt['texto'] ?? '';
        final isSelected = selectedOption == letra;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onSelect(letra),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0E5D4E).withValues(alpha: 0.12)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0E5D4E) : AppTheme.border(context),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0E5D4E) : Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letra,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary(context),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Campo de texto para preenchimento de termo gramatical ou lacuna de frase
class ThematicFillBlankView extends StatelessWidget {
  final TextEditingController controller;

  const ThematicFillBlankView({
    super.key,
    required this.controller,
  });

  // Constrói o campo de digitação com indicação de suporte a variações ortográficas
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preencha o termo correto em Tupi que completa a frase:',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 16, color: AppTheme.textPrimary(context), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Digite o termo...',
            filled: true,
            fillColor: AppTheme.surface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0E5D4E), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.spellcheck_rounded, size: 16, color: Color(0xFF0E5D4E)),
            const SizedBox(width: 6),
            Text(
              'Compreensão de variações ortográficas ativada',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
            ),
          ],
        ),
      ],
    );
  }
}

// Campo de tradução livre avaliada contextualmente pela inteligência pedagógica
class ThematicFreeTextView extends StatelessWidget {
  final TextEditingController controller;

  const ThematicFreeTextView({
    super.key,
    required this.controller,
  });

  // Renderiza a caixa de texto para tradução espontânea
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Digite livremente a tradução solicitada:',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 16, color: AppTheme.textPrimary(context), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Sua tradução...',
            filled: true,
            fillColor: AppTheme.surface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0E5D4E), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFFD08A45)),
            const SizedBox(width: 6),
            Text(
              'Avaliação inteligente de tradução contextual',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
            ),
          ],
        ),
      ],
    );
  }
}

// Duas colunas lado a lado para ligar termos ancestrais às suas traduções em português
class ThematicMatchingView extends StatelessWidget {
  final Map<String, dynamic> question;
  final Map<String, String> userAssociations;
  final String? selectedTerm;
  final ValueChanged<String> onSelectTerm;
  final void Function(String term, String translation) onLinkPair;

  const ThematicMatchingView({
    super.key,
    required this.question,
    required this.userAssociations,
    required this.selectedTerm,
    required this.onSelectTerm,
    required this.onLinkPair,
  });

  // Monta as duas colunas verticais com animação de conexão quando o par é associado
  @override
  Widget build(BuildContext context) {
    final pares = (question['pares_associacao'] as List?) ?? [];
    final termos = pares.map((p) => p['termo'].toString()).toList();
    final traducoes = pares.map((p) => p['traducao'].toString()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toque em um termo em Tupi e em seguida na sua respectiva tradução:',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna Tupi
            Expanded(
              child: Column(
                children: termos.map((t) {
                  final isLinked = userAssociations.containsKey(t);
                  final isSelected = selectedTerm == t;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => onSelectTerm(t),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD08A45).withValues(alpha: 0.2)
                              : (isLinked ? const Color(0xFF0E5D4E).withValues(alpha: 0.12) : AppTheme.surface(context)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD08A45)
                                : (isLinked ? const Color(0xFF0E5D4E) : AppTheme.border(context)),
                            width: (isSelected || isLinked) ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            t,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isLinked ? const Color(0xFF0E5D4E) : AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 14),
            // Coluna Tradução
            Expanded(
              child: Column(
                children: traducoes.map((trad) {
                  final isLinked = userAssociations.containsValue(trad);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        if (selectedTerm != null) {
                          onLinkPair(selectedTerm!, trad);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLinked ? const Color(0xFF0E5D4E).withValues(alpha: 0.12) : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLinked ? const Color(0xFF0E5D4E) : AppTheme.border(context),
                            width: isLinked ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            trad,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isLinked ? FontWeight.bold : FontWeight.normal,
                              color: isLinked ? const Color(0xFF0E5D4E) : AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
