import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/app_progression_notifier.dart';
import '../data/thematic_outbox_service.dart';
import 'widgets/thematic_feedback_sheet.dart';
import 'widgets/thematic_question_views.dart';
import 'widgets/thematic_summary_view.dart';

// Tela principal de prática temática com geração dinâmica de questões e telemetria psicométrica
class ThematicPracticeScreen extends StatefulWidget {
  final String tema;
  final String? temaId;
  final int varianteId;
  final String varianteNome;
  final int? initialConchas;
  final bool bypassCache;

  const ThematicPracticeScreen({
    super.key,
    required this.tema,
    this.temaId,
    required this.varianteId,
    required this.varianteNome,
    this.initialConchas,
    this.bypassCache = false,
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

  // Métricas psicométricas TRI em tempo real
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
  String? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  final Map<String, String> _userAssociations = {};
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

  // Consulta o backend pra buscar a bateria de questões geradas pro tema ou recupera erro
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
          if (widget.temaId != null) 'tema_id': widget.temaId,
          'variante_id': widget.varianteId,
          'dificuldade': 'media',
          'quantidade': 4,
          'bypass_cache': widget.bypassCache,
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

  // Submete a resposta da questão com fallback offline caso a conexão falhe
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

        AppProgressionNotifier.instance.notifyProgressUpdated(
          xpGained: earnedXp,
          conchasGained: earnedConchas,
        );

        if (mounted) {
          _showFeedback(
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
      setState(() {
        _isEvaluating = false;
        _isOfflineMode = true;
      });

      await ThematicOutboxService.instance.enqueueInteraction(interactionPayload);

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

        _showFeedback(
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

  // Aciona o modal inferior de feedback e avança a questão ou conclui a sessão
  void _showFeedback({
    required bool isCorrect,
    required String status,
    required String message,
    required String explicacao,
    required int earnedXp,
    required int earnedConchas,
    required bool isLastItem,
  }) {
    ThematicFeedbackSheet.show(
      context: context,
      isCorrect: isCorrect,
      status: status,
      message: message,
      explicacao: explicacao,
      earnedXp: earnedXp,
      earnedConchas: earnedConchas,
      isLastItem: isLastItem,
      onContinue: () {
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
    );
  }

  // Converte a chave interna do tipo de pergunta para nome legível na interface
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

  // Renderiza a estrutura da tela com barra de progresso, corpo da questão e botão de envio
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
                const Icon(Icons.cloud_off_rounded, size: 54, color: Color(0xFFD08A45)),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppTheme.textPrimary(context)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startThematicSession,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E5D4E)),
                  child: const Text('TENTAR NOVAMENTE', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isFinished) {
      return ThematicSummaryView(
        accumulatedXp: _accumulatedXp,
        accumulatedConchas: _accumulatedConchas,
        currentLevel: _currentLevel,
        onFinish: () => Navigator.pop(context, true),
      );
    }

    final currentQ = _questions[_currentIndex];
    final String tipo = currentQ['tipo'] ?? 'escolha_multipla';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tema, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        actions: [
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
                  if (tipo == 'escolha_multipla')
                    ThematicMultipleChoiceView(
                      question: currentQ,
                      selectedOption: _selectedOption,
                      onSelect: (letra) => setState(() => _selectedOption = letra),
                    )
                  else if (tipo == 'completar')
                    ThematicFillBlankView(
                      controller: _textController,
                    )
                  else if (tipo == 'associacao')
                    ThematicMatchingView(
                      question: currentQ,
                      userAssociations: _userAssociations,
                      selectedTerm: _selectedAssociationTerm,
                      onSelectTerm: (t) => setState(() => _selectedAssociationTerm = t),
                      onLinkPair: (term, trad) {
                        setState(() {
                          _userAssociations[term] = trad;
                          _selectedAssociationTerm = null;
                        });
                      },
                    )
                  else if (tipo == 'traducao_livre')
                    ThematicFreeTextView(
                      controller: _textController,
                    ),
                ],
              ),
            ),
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
}
