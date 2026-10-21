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
  final String? targetWord;
  final List<String>? correctAnswers;
  final String? sentenceTranslation;
  final String? explanation;

  const FillInTheBlankView({
    super.key,
    required this.textoComLacunas,
    required this.textController,
    required this.onChanged,
    this.wordTranslations,
    this.targetWord,
    this.correctAnswers,
    this.sentenceTranslation,
    this.explanation,
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

  // Dicionário canônico de sentenças e locuções para exibição de contexto em Português
  static final Map<String, String> _knownSentencesPt = {
    'aba katu': 'Pessoa boa / Homem bom',
    'aba katu.': 'Pessoa boa / Homem bom',
    'xe aba katu': 'Eu sou uma pessoa boa',
    'xe aba katu.': 'Eu sou uma pessoa boa',
    'iande aba': 'Nós somos homens / pessoas',
    'iande aba.': 'Nós somos homens / pessoas',
    'iande aba katu': 'Nós somos pessoas boas',
    'iande aba katu.': 'Nós somos pessoas boas',
    'aba poranga': 'Pessoa bela / Homem bonito',
    'oka poranga': 'Casa formosa / Bela morada',
    'oka katu': 'Casa boa / Habitação agradável',
    'taba poranga': 'Aldeia formosa / Bela aldeia',
    'che taba poranga': 'Minha bela aldeia',
    'aue pai': 'Salve, meu senhor!',
    'aue pai.': 'Salve, meu senhor!',
    'kaue pai': 'Salve, meu senhor!',
    'ereiur pe': 'Vieste em paz? (Como vai?)',
    'ereiur pe?': 'Vieste em paz? (Como vai?)',
    'y poranga': 'Água pura e límpida',
    'kaa poranga': 'Mata formosa',
    'tupa katu': 'O divino é bom',
  };

  // Dicionário canônico de fallback para tradução instantânea em tempo real (0ms)
  static final Map<String, Map<String, String>> _fallbackDict = {
    'kaue': {'pt': 'Olá / Salve', 'pron': 'a-u-É'},
    'aué': {'pt': 'Olá / Salve', 'pron': 'a-u-É'},
    'ereiur': {'pt': 'Vieste?', 'pron': 'e-re-i-UR'},
    'ereîur': {'pt': 'Vieste?', 'pron': 'e-re-i-UR'},
    'ereiur-pe': {'pt': 'Vieste? (Como vai?)', 'pron': 'e-re-i-UR pe'},
    'ereîur pe?': {'pt': 'Vieste? (Como vai?)', 'pron': 'e-re-i-UR pe'},
    'pa\'i': {'pt': 'Senhor / Tratamento respeitoso', 'pron': 'pa-I'},
    'pa\'ĩ': {'pt': 'Senhor / Tratamento respeitoso', 'pron': 'pa-I'},
    'taba': {'pt': 'Aldeia / Povoado', 'pron': 'TA-ba'},
    'oka': {'pt': 'Casa / Habitação', 'pron': 'O-ka'},
    'aba': {'pt': 'Homem / Pessoa', 'pron': 'a-BÁ'},
    'kunhã': {'pt': 'Mulher', 'pron': 'ku-NHÃ'},
    'pitanga': {'pt': 'Criança / Bebê', 'pron': 'pi-TAN-ga'},
    'y': {'pt': 'Água / Rio', 'pron': 'Y (som gutural [ɨ])'},
    'parana': {'pt': 'Grande rio / Mar', 'pron': 'pa-ra-NÁ'},
    'pira': {'pt': 'Peixe', 'pron': 'pi-RÁ'},
    'ygarata': {'pt': 'Canoa / Embarcação', 'pron': 'y-ga-RA-ta'},
    'ka\'a': {'pt': 'Mata / Floresta', 'pron': 'ka-\'A'},
    'ybyra': {'pt': 'Árvore / Madeira', 'pron': 'y-by-RÁ'},
    'jagûara': {'pt': 'Onça / Fera', 'pron': 'ja-gwa-RA'},
    'gûyra': {'pt': 'Pássaro / Ave', 'pron': 'gwi-RÁ'},
    'tatu': {'pt': 'Tatu', 'pron': 'ta-TU'},
    'tata': {'pt': 'Fogo / Chama', 'pron': 'ta-TA'},
    'tatagûasu': {'pt': 'Fogueira grande', 'pron': 'ta-ta-gwa-SU'},
    'mani\'oká': {'pt': 'Mandioca', 'pron': 'ma-ni-\'O-ka'},
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

          // Contexto em Português da Frase (Subtítulo Pedagógico de Apoio)
          Builder(
            builder: (context) {
              final contextPt = _resolvePortugueseContext();
              if (contextPt == null || contextPt.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162520) : const Color(0xFFEAF3F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1EC9A5).withValues(alpha: 0.35) : const Color(0xFF0E5D4E).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.translate_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'Complete a frase para dizer: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                          children: [
                            TextSpan(
                              text: '"$contextPt"',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
            child: _buildInteractiveSentence(context),
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

  /// Oculta a palavra-alvo caso o texto do exercício venha completo sem o marcador de lacuna
  String _resolveEffectiveSentence() {
    var raw = widget.textoComLacunas.trim();
    if (raw.isEmpty) return raw;

    // Se já contém marcador de lacuna explícito (2 ou mais underscores consecutivos)
    if (RegExp(r'_{2,}').hasMatch(raw)) {
      return raw;
    }

    // Se a frase veio sem lacuna (ex: 'Abá katu.'), descobre a palavra-alvo para ocultar dinamicamente
    String? target = widget.targetWord;
    if (target == null || target.isEmpty) {
      if (widget.correctAnswers != null && widget.correctAnswers!.isNotEmpty) {
        target = widget.correctAnswers!.first;
      }
    }
    if ((target == null || target.isEmpty) && widget.explanation != null) {
      final match = RegExp(r"'([^']+)'").firstMatch(widget.explanation!);
      if (match != null) {
        target = match.group(1);
      }
    }

    if (target != null && target.trim().isNotEmpty) {
      final clean = _cleanToken(target);
      if (clean.isNotEmpty) {
        // Substitui a palavra-alvo com limites de palavra
        final boundaryRegex = RegExp(r'\b' + RegExp.escape(clean) + r'\b', caseSensitive: false);
        if (boundaryRegex.hasMatch(raw)) {
          return raw.replaceFirst(boundaryRegex, '______');
        }
        final relaxedRegex = RegExp(RegExp.escape(clean), caseSensitive: false);
        if (relaxedRegex.hasMatch(raw)) {
          return raw.replaceFirst(relaxedRegex, '______');
        }
      }
    }

    // Fallback: se tem 2+ palavras e nenhuma lacuna, oculta a última palavra
    final words = raw.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final lastWord = words.last;
      return raw.replaceFirst(lastWord, '______');
    }

    return '______';
  }

  /// Resolve o significado da frase em Português para dar suporte pedagógico ao aluno
  String? _resolvePortugueseContext() {
    if (widget.sentenceTranslation != null && widget.sentenceTranslation!.trim().isNotEmpty) {
      return widget.sentenceTranslation!.trim();
    }

    // Normaliza chave de busca (sem acentos e pontuações)
    final normalizedKey = _cleanToken(widget.textoComLacunas.toLowerCase())
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('î', 'i')
        .replaceAll('õ', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('û', 'u')
        .trim();

    if (_knownSentencesPt.containsKey(normalizedKey)) {
      return _knownSentencesPt[normalizedKey];
    }

    for (final e in _knownSentencesPt.entries) {
      if (e.key == normalizedKey || normalizedKey.contains(e.key)) {
        return e.value;
      }
    }

    // Extrai significado entre parênteses da explicação se houver (ex: "(Bom / Belo)")
    if (widget.explanation != null) {
      final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(widget.explanation!);
      if (parenMatch != null && parenMatch.group(1) != null) {
        return parenMatch.group(1)!.trim();
      }
    }

    return null;
  }

  /// Renderiza a sentença completa em um Wrap plano único:
  /// Preserva o widget visual da lacuna [ ______ ] e todos os tokens ao redor dela
  Widget _buildInteractiveSentence(BuildContext context) {
    final effectiveSentence = _resolveEffectiveSentence();
    final tokens = effectiveSentence.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final List<Widget> widgets = [];

    for (final token in tokens) {
      if (RegExp(r'_{2,}').hasMatch(token)) {
        // Extrai pontuação colada na lacuna (ex: "______.")
        final punctuation = token.replaceAll(RegExp(r'[_]'), '');

        widgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primary, width: 2.0),
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
              if (punctuation.isNotEmpty)
                Text(
                  punctuation,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
            ],
          ),
        );
      } else {
        widgets.add(_buildWordChip(token));
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }

  Widget _buildWordChip(String token) {
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
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

