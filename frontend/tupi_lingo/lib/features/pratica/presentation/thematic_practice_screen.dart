import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/app_progression_notifier.dart';
import '../data/thematic_outbox_service.dart';

class ThematicPracticeScreen extends StatefulWidget {
  final String tema;
  final int varianteId;
  final String varianteNome;
  final int? initialConchas;

  const ThematicPracticeScreen({
    super.key,
    required this.tema,
    required this.varianteId,
    required this.varianteNome,
    this.initialConchas,
  });

  @override
  State<ThematicPracticeScreen> createState() => _ThematicPracticeScreenState();
}

class _ThematicPracticeScreenState extends State<ThematicPracticeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String? _sessionId;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;

  // Métricas psicométricas TRI em tempo real (< 50ms)
  double _currentTheta = 0.0;
  int _currentLevel = 1;
  int _accumulatedXp = 0;
  int _accumulatedConchas = 0;
  int _userTotalConchas = 0;

  // Estado da questão atual
  DateTime? _questionStartTime;
  int? _presentedAtMs;
  bool _isOfflineMode = false;
  bool _isEvaluating = false;
  List<dynamic> _srsTerms = [];

  // Controladores para formatos de resposta
  String? _selectedOption; // múltipla escolha
  final TextEditingController _textController = TextEditingController(); // completar & tradução livre
  final Map<String, String> _userAssociations = {}; // associação
  String? _selectedAssociationTerm;

  // Estado de finalização
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _userTotalConchas = widget.initialConchas ?? 0;
    _startThematicSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startThematicSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final response = await ApiClient.post(
        '$baseUrl/api/v1/pratica/gerar-tematico/',
        body: {
          'tema': widget.tema,
          'variante_id': widget.varianteId,
          'dificuldade': 'media',
          'quantidade': 4,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _sessionId = data['session_id'];
            _currentLevel = data['nivel_usuario'] ?? 1;
            if (data['conchas_usuario'] != null) {
              _userTotalConchas = (data['conchas_usuario'] as num).toInt();
            }
            _questions = List<Map<String, dynamic>>.from(data['questoes'] ?? []);
            _srsTerms = List<dynamic>.from(data['termos_srs'] ?? []);
            _isLoading = false;
            _currentIndex = 0;
            _questionStartTime = DateTime.now();
            _presentedAtMs = DateTime.now().millisecondsSinceEpoch;
          });
          return;
        }
      }
      throw Exception('Falha ao gerar treino temático.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Nossa aldeia está sem conexão com a floresta no momento. Tente novamente em instantes.';
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_isEvaluating || _questions.isEmpty || _currentIndex >= _questions.length) return;
    final currentQ = _questions[_currentIndex];
    final String tipo = currentQ['tipo'] ?? 'escolha_multipla';

    dynamic respostaPayload;
    if (tipo == 'escolha_multipla') {
      if (_selectedOption == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma alternativa antes de continuar.')),
        );
        return;
      }
      respostaPayload = _selectedOption;
    } else if (tipo == 'completar' || tipo == 'traducao_livre') {
      if (_textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite sua resposta antes de enviar.')),
        );
        return;
      }
      respostaPayload = _textController.text.trim();
    } else if (tipo == 'associacao') {
      final pares = (currentQ['pares_associacao'] as List?) ?? [];
      if (_userAssociations.length < pares.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ligue todos os pares antes de continuar.')),
        );
        return;
      }
      respostaPayload = _userAssociations;
    }

    setState(() => _isEvaluating = true);
    final int answeredAtMs = DateTime.now().millisecondsSinceEpoch;
    final double deltaSeconds = _presentedAtMs != null
        ? ((answeredAtMs - _presentedAtMs!) / 1000.0)
        : (_questionStartTime != null
            ? DateTime.now().difference(_questionStartTime!).inMilliseconds / 1000.0
            : 3.0);
    final double timeTaken = deltaSeconds < 0.1 ? 0.1 : deltaSeconds;
    final bool isLast = (_currentIndex == _questions.length - 1);

    final interactionPayload = {
      'session_id': _sessionId,
      'item_id': currentQ['id'] ?? (_currentIndex + 1),
      'tipo': tipo,
      'resposta': respostaPayload,
      'resposta_correta': currentQ['resposta_correta'] ?? '',
      'pares_associacao': currentQ['pares_associacao'] ?? [],
      'termo_alvo': currentQ['termo_alvo'] ?? currentQ['resposta_correta'] ?? '',
      'presented_at_ms': _presentedAtMs,
      'answered_at_ms': answeredAtMs,
      'time_taken_seconds': timeTaken,
      'param_a': currentQ['param_a'] ?? 1.2,
      'param_b': currentQ['param_b'] ?? 0.0,
      'param_c': currentQ['param_c'] ?? (tipo == 'escolha_multipla' ? 0.25 : 0.0),
      'is_last_item': isLast,
    };

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final response = await ApiClient.post(
        '$baseUrl/api/v1/pratica/responder-item/',
        body: interactionPayload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final tri = data['tri'] ?? {};
        final bool isCorrect = data['is_correct'] ?? false;
        final String status = data['status'] ?? 'wrong';
        final String message = data['message'] ?? (isCorrect ? 'Correto!' : 'Incorreto.');
        final int earnedXp = tri['earned_xp'] ?? 0;
        final int earnedConchas = tri['earned_conchas'] ?? 0;
        final int conchasUsuario = (data['conchas_usuario'] as num?)?.toInt() ?? (_userTotalConchas + earnedConchas);

        setState(() {
          _accumulatedXp = tri['total_xp_accumulated'] ?? (_accumulatedXp + earnedXp);
          _accumulatedConchas = tri['total_conchas_accumulated'] ?? (_accumulatedConchas + earnedConchas);
          _userTotalConchas = conchasUsuario;
          _currentTheta = (tri['current_theta'] as num?)?.toDouble() ?? _currentTheta;
          _currentLevel = tri['current_level'] ?? _currentLevel;
          _isEvaluating = false;
        });

        // Notifica dashboard global
        AppProgressionNotifier.instance.notifyProgressUpdated(
          xpGained: earnedXp,
          conchasGained: earnedConchas,
        );

        if (mounted) {
          _showFeedbackModal(
            isCorrect: isCorrect,
            status: status,
            message: message,
            explicacao: currentQ['explicacao'] ?? '',
            earnedXp: earnedXp,
            earnedConchas: earnedConchas,
            isLastItem: isLast,
          );
        }
      } else {
        throw Exception('Erro na validação.');
      }
    } catch (_) {
      // Fila Outbox Offline-First: salva localmente se a conexão oscilar
      setState(() {
        _isEvaluating = false;
        _isOfflineMode = true;
      });

      await ThematicOutboxService.instance.enqueueInteraction(interactionPayload);

      // Avaliação otimista local imediata
      bool isLocalCorrect = false;
      if (tipo == 'escolha_multipla') {
        isLocalCorrect = (respostaPayload.toString().trim().toUpperCase() ==
            (currentQ['resposta_correta'] ?? '').toString().trim().toUpperCase());
      } else if (tipo == 'completar' || tipo == 'traducao_livre') {
        isLocalCorrect = respostaPayload.toString().trim().toLowerCase() ==
            (currentQ['resposta_correta'] ?? '').toString().trim().toLowerCase();
      } else if (tipo == 'associacao') {
        isLocalCorrect = true;
      }

      final int earnedXp = isLocalCorrect ? 15 : 0;
      final int earnedConchas = isLocalCorrect ? 1 : 0;

      setState(() {
        _accumulatedXp += earnedXp;
        _accumulatedConchas += earnedConchas;
        _userTotalConchas += earnedConchas;
      });

      AppProgressionNotifier.instance.notifyProgressUpdated(
        xpGained: earnedXp,
        conchasGained: earnedConchas,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo Aldeia Offline — Resposta guardada com segurança para envio posterior.'),
            duration: Duration(seconds: 2),
          ),
        );

        _showFeedbackModal(
          isCorrect: isLocalCorrect,
          status: isLocalCorrect ? 'correct' : 'wrong',
          message: isLocalCorrect ? 'Correto! (Guardado na fila da aldeia)' : 'Incorreto. (Guardado na fila da aldeia)',
          explicacao: currentQ['explicacao'] ?? '',
          earnedXp: earnedXp,
          earnedConchas: earnedConchas,
          isLastItem: isLast,
        );
      }
    }
  }

  void _showFeedbackModal({
    required bool isCorrect,
    required String status,
    required String message,
    required String explicacao,
    required int earnedXp,
    required int earnedConchas,
    required bool isLastItem,
  }) {
    final bool isAlmost = status == 'almost';
    final Color bgColor = isCorrect
        ? const Color(0xFFEAF3F1)
        : (isAlmost ? const Color(0xFFFFF9E6) : const Color(0xFFFDECEE));
    final Color accentColor = isCorrect
        ? const Color(0xFF0E5D4E)
        : (isAlmost ? const Color(0xFFD08A45) : const Color(0xFFE05638));

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (isAlmost ? Icons.lightbulb_rounded : Icons.cancel_rounded),
                    color: accentColor,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCorrect ? 'Mandou bem!' : (isAlmost ? 'Quase lá!' : 'Ops!'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (earnedXp > 0 || earnedConchas > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (earnedXp > 0)
                            Text(
                              '+$earnedXp XP ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 13),
                            ),
                          if (earnedConchas > 0)
                            Text(
                              '+$earnedConchas 🐚',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E), fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(fontSize: 15, color: AppTheme.textPrimary(context), fontWeight: FontWeight.w600),
              ),
              if (explicacao.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  explicacao,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context), height: 1.4),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (isLastItem) {
                    if (_sessionId != null) {
                      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
                      ThematicOutboxService.instance.syncBatch(
                        sessionId: _sessionId!,
                        baseUrl: baseUrl,
                      );
                    }
                    setState(() => _isFinished = true);
                  } else {
                    setState(() {
                      _currentIndex++;
                      _selectedOption = null;
                      _textController.clear();
                      _userAssociations.clear();
                      _selectedAssociationTerm = null;
                      _questionStartTime = DateTime.now();
                      _presentedAtMs = DateTime.now().millisecondsSinceEpoch;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isLastItem ? 'VER RESULTADO CONSOLIDADO' : 'CONTINUAR',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tema), elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0E5D4E)),
              const SizedBox(height: 20),
              Text(
                'Consultando os saberes ancestrais da aldeia...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
              ),
              const SizedBox(height: 6),
              Text(
                'Preparando seu treino temático personalizado',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tema)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startThematicSession,
                  child: const Text('TENTAR NOVAMENTE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isFinished) {
      return _buildFinishedScreen();
    }

    final currentQ = _questions[_currentIndex];
    final String tipo = currentQ['tipo'] ?? 'escolha_multipla';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tema, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        actions: [
          // HUD de Progresso e Moedas em Tempo Real
          Center(
            child: Builder(
              builder: (ctx) {
                final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
                final Color accent = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
                final Color borderCol = isDark ? const Color(0xFF1EC9A5).withValues(alpha: 0.3) : const Color(0xFF0E5D4E).withValues(alpha: 0.3);
                final Color bgCol = isDark ? const Color(0xFF1EC9A5).withValues(alpha: 0.15) : const Color(0xFF0E5D4E).withValues(alpha: 0.12);

                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bgCol,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🏹 Nível $_currentLevel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0E5D4E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$_accumulatedXp XP',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userTotalConchas > 0
                            ? '$_userTotalConchas 🐚'
                            : '+$_accumulatedConchas 🐚',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Progresso Superior
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0E5D4E)),
              minHeight: 5,
            ),
            if (_isOfflineMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD08A45).withValues(alpha: 0.18),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFD08A45).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 15, color: Color(0xFFD08A45)),
                    SizedBox(width: 8),
                    Text(
                      'Modo Aldeia Offline — Resposta guardada na fila local',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  // Header da Questão
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getTipoLabel(tipo),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                        ),
                      ),
                      if (_srsTerms.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.psychology_rounded, size: 13, color: Color(0xFF0E5D4E)),
                              SizedBox(width: 4),
                              Text(
                                'Reforço Inteligente',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        'Questão ${_currentIndex + 1} de ${_questions.length}',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Enunciado
                  Text(
                    currentQ['enunciado'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Corpo Interativo da Questão dependente do Tipo
                  if (tipo == 'escolha_multipla')
                    _buildMultipleChoice(currentQ)
                  else if (tipo == 'completar')
                    _buildFillInTheBlank(currentQ)
                  else if (tipo == 'associacao')
                    _buildMatchingColumns(currentQ)
                  else if (tipo == 'traducao_livre')
                    _buildFreeText(currentQ),
                ],
              ),
            ),
            // Botão Inferior de Verificação
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isEvaluating ? null : _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5D4E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isEvaluating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'VERIFICAR RESPOSTA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'escolha_multipla':
        return 'Múltipla Escolha';
      case 'completar':
        return 'Completar Lacuna';
      case 'associacao':
        return 'Ligar Colunas';
      case 'traducao_livre':
        return 'Digitação Livre';
      default:
        return 'Prática Temática';
    }
  }

  Widget _buildMultipleChoice(Map<String, dynamic> q) {
    final alts = (q['alternativas'] as List?) ?? [];
    return Column(
      children: alts.map((alt) {
        final letra = alt['letra'] ?? '';
        final texto = alt['texto'] ?? '';
        final isSelected = _selectedOption == letra;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedOption = letra),
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

  Widget _buildFillInTheBlank(Map<String, dynamic> q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preencha o termo correto em Tupi que completa a frase:',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _textController,
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

  Widget _buildFreeText(Map<String, dynamic> q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Digite livremente a tradução solicitada:',
          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _textController,
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

  Widget _buildMatchingColumns(Map<String, dynamic> q) {
    final pares = (q['pares_associacao'] as List?) ?? [];
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
                  final isLinked = _userAssociations.containsKey(t);
                  final isSelected = _selectedAssociationTerm == t;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedAssociationTerm = t),
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
                  final isLinked = _userAssociations.containsValue(trad);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        if (_selectedAssociationTerm != null) {
                          setState(() {
                            _userAssociations[_selectedAssociationTerm!] = trad;
                            _selectedAssociationTerm = null;
                          });
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

  Widget _buildFinishedScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('🏆', style: TextStyle(fontSize: 46))),
                ),
                const SizedBox(height: 20),
                Text(
                  'Treino Temático Concluído!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seus ganhos e aprendizados foram consolidados com sucesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatCard('Experiência', '+$_accumulatedXp XP', const Color(0xFFD08A45)),
                    const SizedBox(width: 14),
                    _buildStatCard('Conchas', '+$_accumulatedConchas 🐚', const Color(0xFF0E5D4E)),
                    const SizedBox(width: 14),
                    _buildStatCard('Seu Nível', 'Nível $_currentLevel', const Color(0xFF1EC9A5)),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E5D4E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('VOLTAR AO CENTRO DE PRÁTICA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }
}
