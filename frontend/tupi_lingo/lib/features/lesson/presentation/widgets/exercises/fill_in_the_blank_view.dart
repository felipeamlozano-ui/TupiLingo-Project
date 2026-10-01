import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Widget de exercício de preenchimento de lacunas com sistema de tradução instantânea
/// estilo Duolingo: ao tocar em qualquer palavra da sentença, um balão de tradução direta
/// surge instantaneamente sobre ela.
class FillInTheBlankView extends StatefulWidget {
  final String textoComLacunas;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final Map<String, String>? wordTranslations;

  const FillInTheBlankView({
    super.key,
    required this.textoComLacunas,
    required this.textController,
    required this.onChanged,
    this.wordTranslations,
  });

  @override
  State<FillInTheBlankView> createState() => _FillInTheBlankViewState();
}

class _FillInTheBlankViewState extends State<FillInTheBlankView> {
  static const Color _primary = Color(0xFFD08A45);
  static const Color _accent = Color(0xFF0E5D4E);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _subtitle = Color(0xFF565D6D);

  // Palavra atualmente inspecionada pelo usuário
  String? _selectedWord;
  String? _selectedTranslation;
  String? _selectedPhonetic;

  // Dicionário canônico de fallback para tradução instantânea em tempo real (0ms)
  static final Map<String, Map<String, String>> _fallbackDict = {
    'kaue': {'pt': 'Olá / Salve', 'pron': 'ka-u-Ê'},
    'kauê': {'pt': 'Olá / Salve', 'pron': 'ka-u-Ê'},
    'ereiur': {'pt': 'Vieste?', 'pron': 'e-re-i-UR'},
    'ereîur': {'pt': 'Vieste?', 'pron': 'e-re-i-UR'},
    'ereiur-pe': {'pt': 'Vieste? (Como vai?)', 'pron': 'e-re-i-UR-pe'},
    'ereîur-pe': {'pt': 'Vieste? (Como vai?)', 'pron': 'e-re-i-UR-pe'},
    'pa\'i': {'pt': 'Senhor / Tratamento respeitoso', 'pron': 'pa-IN'},
    'pa\'ĩ': {'pt': 'Senhor / Tratamento respeitoso', 'pron': 'pa-IN'},
    'taba': {'pt': 'Aldeia / Povoado', 'pron': 'TA-ba'},
    'oka': {'pt': 'Casa / Habitação', 'pron': 'O-ka'},
    'aba': {'pt': 'Homem / Pessoa', 'pron': 'a-BÁ'},
    'abá': {'pt': 'Homem / Pessoa', 'pron': 'a-BÁ'},
    'kunha': {'pt': 'Mulher', 'pron': 'ku-NHÃ'},
    'kunhã': {'pt': 'Mulher', 'pron': 'ku-NHÃ'},
    'pitanga': {'pt': 'Criança / Bebê', 'pron': 'pi-TAN-ga'},
    'y': {'pt': 'Água / Rio', 'pron': 'Y (som gutural [ɨ])'},
    'parana': {'pt': 'Grande rio / Mar', 'pron': 'pa-ra-NÁ'},
    'paraná': {'pt': 'Grande rio / Mar', 'pron': 'pa-ra-NÁ'},
    'pira': {'pt': 'Peixe', 'pron': 'pi-RÁ'},
    'pirá': {'pt': 'Peixe', 'pron': 'pi-RÁ'},
    'ygarata': {'pt': 'Canoa / Embarcação', 'pron': 'y-ga-RA-ta'},
    'ka\'a': {'pt': 'Mata / Floresta', 'pron': 'ka-\'A'},
    'ybyra': {'pt': 'Árvore / Madeira', 'pron': 'y-by-RÁ'},
    'ybyrá': {'pt': 'Árvore / Madeira', 'pron': 'y-by-RÁ'},
    'jaguara': {'pt': 'Onça / Fera', 'pron': 'ja-gwa-RA'},
    'jagûara': {'pt': 'Onça / Fera', 'pron': 'ja-gwa-RA'},
    'guyra': {'pt': 'Pássaro / Ave', 'pron': 'gwi-RÁ'},
    'gûyrá': {'pt': 'Pássaro / Ave', 'pron': 'gwi-RÁ'},
    'tatu': {'pt': 'Tatu', 'pron': 'ta-TU'},
    'tata': {'pt': 'Fogo / Chama', 'pron': 'ta-TA'},
    'tataguasu': {'pt': 'Fogueira grande', 'pron': 'ta-ta-gwa-SU'},
    'tatagûasu': {'pt': 'Fogueira grande', 'pron': 'ta-ta-gwa-SU'},
    'mani\'oka': {'pt': 'Mandioca', 'pron': 'ma-ni-\'O-ka'},
    'u\'i': {'pt': 'Farinha', 'pron': 'u-\'I'},
    'kuarasy': {'pt': 'Sol', 'pron': 'kwa-ra-SY'},
    'kûarasy': {'pt': 'Sol', 'pron': 'kwa-ra-SY'},
    'jasy': {'pt': 'Lua', 'pron': 'ja-SY'},
    'tupa': {'pt': 'Trovão / O sagrado', 'pron': 'tu-PAN'},
    'tupã': {'pt': 'Trovão / O sagrado', 'pron': 'tu-PAN'},
    'paie': {'pt': 'Pajé / Curador', 'pron': 'pa-i-É'},
    'paîé': {'pt': 'Pajé / Curador', 'pron': 'pa-i-É'},
    'morubixaba': {'pt': 'Cacique / Líder', 'pron': 'mo-ru-bi-XA-ba'},
    'che': {'pt': 'Meu / Minha / Eu', 'pron': 'XÉ'},
    'nde': {'pt': 'Teu / Tua / Você', 'pron': 'NDÉ'},
    'i': {'pt': 'Dele / Dela', 'pron': 'I'},
    'katu': {'pt': 'Bom / Bem / Belo', 'pron': 'ka-TU'},
    'poranga': {'pt': 'Belo / Bonito', 'pron': 'po-RAN-ga'},
    'aiete': {'pt': 'Verdadeiro / Sim', 'pron': 'a-ye-TÉ'},
    'aîeté': {'pt': 'Verdadeiro / Sim', 'pron': 'a-ye-TÉ'},
    'nei': {'pt': 'Vamos / Sim', 'pron': 'NE-in'},
    'neĩ': {'pt': 'Vamos / Sim', 'pron': 'NE-in'},
    'pe': {'pt': 'Em / Na / No (ou interrogação)', 'pron': 'PÉ'},
  };

  String _cleanToken(String token) {
    return token
        .replaceAll(RegExp(r'[.,!?:;()\[\]""]'), '')
        .trim();
  }

  void _onWordTapped(String rawWord) {
    final clean = _cleanToken(rawWord);
    if (clean.isEmpty || clean == '___') return;

    // 1. Procura primeiro no mapa injetado da lição ativa
    String? translation;
    String? phonetics;

    if (widget.wordTranslations != null) {
      final key = clean.toLowerCase();
      for (final entry in widget.wordTranslations!.entries) {
        if (entry.key.toLowerCase() == key ||
            _cleanToken(entry.key).toLowerCase() == key) {
          translation = entry.value;
          break;
        }
      }
    }

    // 2. Se não encontrar, busca no dicionário canônico local de alta precisão
    if (translation == null) {
      final key = clean.toLowerCase();
      final match = _fallbackDict[key] ??
          _fallbackDict[key.replaceAll(RegExp(r'[^\w\s]'), '')];
      if (match != null) {
        translation = match['pt'];
        phonetics = match['pron'];
      }
    }

    // 3. Fallback inteligente
    translation ??= 'Tradução do contexto: "$clean"';

    setState(() {
      if (_selectedWord == clean) {
        // Alterna fechamento ao tocar na mesma palavra
        _selectedWord = null;
        _selectedTranslation = null;
        _selectedPhonetic = null;
      } else {
        _selectedWord = clean;
        _selectedTranslation = translation;
        _selectedPhonetic = phonetics;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.textoComLacunas.isNotEmpty) ...[
          // Balão de Tradução Instantânea Estilo Duolingo
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: _selectedWord != null
                ? Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2A25) : const Color(0xFF0E5D4E),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFFD08A45),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.translate_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _selectedWord!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_selectedPhonetic != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '[${_selectedPhonetic!}]',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedTranslation!,
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedWord = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Card com a frase e palavras clicáveis com dica estilo Duolingo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildInteractiveSentence(context, widget.textoComLacunas),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 14, color: AppTheme.textSecondary(context).withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                'Toque em qualquer palavra para ver a tradução instantânea.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary(context).withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          "Digite a palavra que completa a lacuna:",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _subtitle),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.textController,
          onChanged: widget.onChanged,
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

  Widget _buildInteractiveSentence(BuildContext context, String texto) {
    if (!texto.contains('___')) {
      return _buildClickableWordsRow(texto);
    }

    final parts = texto.split('___');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildClickableWordsRow(parts[0]),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _primary, width: 1.8),
          ),
          child: Text(
            widget.textController.text.trim().isNotEmpty
                ? widget.textController.text.trim()
                : ' ______ ',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
        if (parts.length > 1) _buildClickableWordsRow(parts[1]),
      ],
    );
  }

  Widget _buildClickableWordsRow(String segment) {
    final tokens = segment.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: tokens.map((token) {
        final clean = _cleanToken(token);
        final isSelected = _selectedWord != null && _selectedWord == clean;

        return GestureDetector(
          onTap: () => _onWordTapped(token),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? _primary.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: _primary, width: 1.5)
                  : const Border(
                      bottom: BorderSide(
                        color: Color(0xFFD08A45),
                        width: 1.2,
                        style: BorderStyle.solid,
                      ),
                    ),
            ),
            child: Text(
              token,
              style: TextStyle(
                fontSize: 19,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? _primary : _accent,
                height: 1.4,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
