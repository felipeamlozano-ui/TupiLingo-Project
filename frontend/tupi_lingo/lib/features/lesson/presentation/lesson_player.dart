import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/routing/predictive_preloading_engine.dart';
import 'package:tupi_lingo/core/memory/memory_residency_engine.dart';

/// Normaliza o status de validação retornado pelo backend.
/// Aceita tanto o formato canônico inglês ('correct', 'almost', 'wrong')
/// quanto o formato legado português ('CORRETO', 'QUASE_CERTO', 'ERRADO'),
/// garantindo retrocompatibilidade durante a migração da API.
String _normalizeValidationStatus(String raw) {
  switch (raw.toLowerCase()) {
    case 'correct':
    case 'correto':
      return 'correct';
    case 'almost':
    case 'quase_certo':
      return 'almost';
    case 'wrong':
    case 'errado':
    default:
      return 'wrong';
  }
}


class _TupiColors {
  static const background = Color(0xFFF3F2E8);
  static const primary = Color(0xFFD08A45); // Âmbar Tupi
  static const accent = Color(0xFF0E5D4E); // Verde escuro
  static const danger = Color(0xFFD32F2F);
  static const subtitle = Color(0xFF565D6D);
  static const border = Color(0xFFD0D0D0);
}

class LessonPlayerScreen extends StatefulWidget {
  final int licaoId;

  const LessonPlayerScreen({super.key, required this.licaoId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  
  Map<String, dynamic>? _licao;
  List<Map<String, dynamic>> _items = [];
  int _currentIndex = 0;

  int _acertos = 0;
  int _totalExercicios = 0;
  int _bonusXp = 0;
  bool _isVerifying = false;
  
  final Map<int, bool> _exercicioPrimeiraTentativa = {};

  // Controles de animação para transições (opcional, mas deixa bonito)
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_progressController);
    _fetchLesson();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _applyLessonData(Map<String, dynamic> data) {
    _licao = data['licao'];
    final List<dynamic> storyBlocks = data['story_blocks'] ?? [];
    final List<dynamic> exercicios = data['exercicios'] ?? [];

    _items = [];
    _totalExercicios = 0;
    _exercicioPrimeiraTentativa.clear();

    for (var sb in storyBlocks) {
      sb['is_story'] = true;
      _items.add(Map<String, dynamic>.from(sb));
    }
    for (var ex in exercicios) {
      ex['is_story'] = false;
      _items.add(Map<String, dynamic>.from(ex));
      _totalExercicios++;
      _exercicioPrimeiraTentativa[ex['id']] = true;
    }

    // Ordena tudo pela ordem definida no Django
    _items.sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));

    setState(() {
      _isLoading = false;
    });
    _updateProgress();
  }

  Future<void> _fetchLesson() async {
    // 1. Instant Loading: Checa se a lição já foi pré-aquecida pelo PredictivePreloadingEngine ou L1 Cache
    final cached = PredictivePreloadingEngine.instance.consumePreloadedData<Map<String, dynamic>>('licao_${widget.licaoId}') ??
        MemoryResidencyEngine.instance.getL1<Map<String, dynamic>>('licao_${widget.licaoId}');

    if (cached != null) {
      _applyLessonData(cached);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final response = await ApiClient.get('$baseUrl/api/v1/trilha/licao/${widget.licaoId}/');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          // Persiste no cache de memória L1 para acessos subsequentes instantâneos
          MemoryResidencyEngine.instance.putL1('licao_${widget.licaoId}', data);
          _applyLessonData(data);
        } else {
          throw Exception(data['error'] ?? 'Erro desconhecido');
        }
      } else {
        throw Exception('Erro ao buscar lição (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        final String userMessage;
        if (e is SessionExpiredException) {
          userMessage = 'Sua sessão expirou. Faça login novamente.';
          Navigator.pushReplacementNamed(context, '/welcome');
          return;
        } else if (e is http.ClientException ||
                   e.toString().toLowerCase().contains('timeout') ||
                   e.toString().toLowerCase().contains('socket')) {
          userMessage = 'Sem conexão com o servidor. Verifique sua internet.';
        } else {
          userMessage = 'Erro ao carregar lição. Tente novamente.';
          debugPrint('[LessonPlayer] Erro não tratado em _fetchLesson: $e');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = userMessage;
        });
      }
    }
  }

  void _updateProgress() {
    final target = _items.isEmpty ? 0.0 : (_currentIndex / _items.length);
    _progressAnimation = Tween<double>(begin: _progressAnimation.value, end: target).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward(from: 0.0);
  }

  void _nextItem() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _updateProgress();
    } else {
      _finishLesson();
    }
  }

  Future<void> _verifyAnswer(int exercicioId, String tipo, dynamic resposta) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    bool isFirstTry = _exercicioPrimeiraTentativa[exercicioId] ?? true;

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      
      final payload = {
        'exercicio_id': exercicioId,
        'tipo': tipo,
        'primeira_tentativa': isFirstTry,
      };

      if (tipo == 'escolha_multipla') {
        payload['resposta_indice'] = int.tryParse(resposta.toString()) ?? 0;
      } else if (tipo == 'completar') {
        payload['respostas'] = [resposta.toString()];
      } else if (tipo == 'associacao') {
        payload['associacoes'] = (resposta is Map) ? resposta : {};
      }

      final response = await ApiClient.post(
        '$baseUrl/api/v1/exercicios/verificar/',
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // Normaliza o status: aceita tanto o formato canônico EN (correct/almost/wrong)
        // quanto o legado PT (CORRETO/QUASE_CERTO/ERRADO) para retrocompatibilidade.
        final String rawStatus = data['status'] ?? '';
        final String statusNorm = _normalizeValidationStatus(rawStatus);
        final String? message = data['mensagem'] ?? data['message'];

        if (statusNorm == 'correct' || statusNorm == 'almost') {
          if (isFirstTry && statusNorm == 'correct') _acertos++;
          _showFeedbackSheet(
            isCorrect: true,
            isAlmost: statusNorm == 'almost',
            message: message ?? 'Mandou bem!',
          );
        } else {
          // wrong
          setState(() {
            _exercicioPrimeiraTentativa[exercicioId] = false;
          });
          _showFeedbackSheet(
            isCorrect: false,
            isAlmost: false,
            message: message ?? 'Ops! Resposta incorreta.',
          );
        }
      } else {
        throw Exception('Erro na validação (HTTP ${response.statusCode}).');
      }
    } catch (e) {
      if (mounted) {
        final String userMessage;
        if (e is SessionExpiredException) {
          userMessage = 'Sua sessão expirou. Faça login novamente.';
          Navigator.pushReplacementNamed(context, '/welcome');
          return;
        } else if (e is http.ClientException ||
                   e.toString().toLowerCase().contains('timeout') ||
                   e.toString().toLowerCase().contains('socket')) {
          userMessage = 'Sem conexão com o servidor. Verifique sua internet.';
        } else {
          userMessage = 'Erro ao verificar resposta. Tente novamente.';
          debugPrint('[LessonPlayer] Erro não tratado em _verifyAnswer: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            action: SnackBarAction(
              label: 'Tentar Novamente',
              onPressed: () => _verifyAnswer(exercicioId, tipo, resposta),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showFeedbackSheet({required bool isCorrect, required bool isAlmost, required String message}) {
    Color bgColor = isCorrect ? const Color(0xFFEAF3F1) : const Color(0xFFFDECEE);
    Color fgColor = isCorrect ? _TupiColors.accent : _TupiColors.danger;
    IconData icon = isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
    String title = isCorrect ? 'Excelente!' : 'Não foi dessa vez.';

    if (isAlmost) {
      bgColor = const Color(0xFFFFF9E6);
      fgColor = const Color(0xFFD08A45);
      icon = Icons.star_half_rounded;
      title = 'Quase lá!';
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 24.0 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: fgColor, size: 28),
                  const SizedBox(width: 12),
                  Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fgColor)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 16, color: _TupiColors.subtitle, height: 1.4)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Fechar bottom sheet
                    _nextItem(); // Avança para a próxima questão independente se acertou ou não
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fgColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('CONTINUAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishLesson() async {
    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      
      final payload = {
        'acertos': _acertos,
        'total_exercicios': _totalExercicios,
        'bonus_exploracao_xp': _bonusXp,
        'tempo_segundos': 60,
        'primeira_tentativa': _acertos == _totalExercicios && _totalExercicios > 0,
      };

      final response = await ApiClient.post(
        '$baseUrl/api/v1/trilha/licao/${widget.licaoId}/concluir/',
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          final List<dynamic> novasConquistas = data['novas_conquistas'] ?? [];
          final int? nivelAtual = data['nivel_atual'];
          _showVictoryDialog(
            data['earned_xp'] ?? 0,
            novasConquistas,
            nivelAtual,
            completionData: data is Map<String, dynamic> ? data : null,
          );
        }
      } else {
        throw Exception('Falha ao concluir lição (HTTP ${response.statusCode}).');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final String userMessage;
        if (e is SessionExpiredException) {
          userMessage = 'Sua sessão expirou. Faça login novamente.';
          Navigator.pushReplacementNamed(context, '/welcome');
          return;
        } else if (e is http.ClientException ||
                   e.toString().toLowerCase().contains('timeout') ||
                   e.toString().toLowerCase().contains('socket')) {
          userMessage = 'Sem conexão com o servidor. Verifique sua internet.';
        } else {
          userMessage = 'Falha ao concluir lição. Tente novamente.';
          debugPrint('[LessonPlayer] Erro não tratado em _finishLesson: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            action: SnackBarAction(
              label: 'Tentar Novamente',
              onPressed: _finishLesson,
            ),
          ),
        );
      }
    }
  }

  void _showVictoryDialog(
    int earnedXp,
    List<dynamic> novasConquistas,
    int? nivelAtual, {
    Map<String, dynamic>? completionData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _TupiColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lição Concluída!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _TupiColors.accent),
              ),
              const SizedBox(height: 12),
              Text(
                'Você ganhou +$earnedXp XP!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _TupiColors.primary),
              ),
              if (nivelAtual != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Nível Adaptativo: $nivelAtual 🏹',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _TupiColors.subtitle),
                ),
              ],
              if (novasConquistas.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD166)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(novasConquistas[0]['icone'] ?? '🏅', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NOVA CONQUISTA!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB78103))),
                            Text(novasConquistas[0]['nome'] ?? 'Medalha Desbloqueada', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _TupiColors.accent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // fecha dialog
                    Navigator.pop(context, completionData ?? true); // volta pro mapa indicando conclusão e repassando dados
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _TupiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('VOLTAR AO MAPA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _TupiColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: _TupiColors.primary),
              const SizedBox(height: 16),
              const Text("Preparando a jornada...", style: TextStyle(color: _TupiColors.subtitle)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: _TupiColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: _TupiColors.danger),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: _TupiColors.danger), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchLesson, child: const Text('Tentar Novamente'))
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lição Vazia')),
        body: const Center(child: Text("Esta lição não possui conteúdo.")),
      );
    }

    final currentItem = _items[_currentIndex];
    final isStory = currentItem['is_story'] == true;

    return Scaffold(
      backgroundColor: _TupiColors.background,
      appBar: AppBar(
        backgroundColor: _TupiColors.background,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(_licao?['titulo'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _TupiColors.accent)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(_TupiColors.primary),
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: isStory ? _buildStoryBlock(currentItem) : _buildExercicioBlock(currentItem),
        ),
      ),
    );
  }

  Widget _buildStoryBlock(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item['titulo'] != null && item['titulo'].toString().isNotEmpty) ...[
          Text(
            item['titulo'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _TupiColors.accent),
          ),
          const SizedBox(height: 24),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item['midia'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(item['midia'], fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 24),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(
                    item['conteudo'] ?? '',
                    style: const TextStyle(fontSize: 18, color: _TupiColors.subtitle, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              final xpBonus = item['xp_bonus'] ?? 0;
              if (xpBonus > 0) _bonusXp += (xpBonus as int);
              _nextItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _TupiColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('CONTINUAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildExercicioBlock(Map<String, dynamic> item) {
    final tipo = item['tipo'];
    return _ExercicioDispatcher(
      key: ValueKey('ex_${item['id']}_$_currentIndex'),
      item: item,
      onVerify: (dynamic resposta) {
        _verifyAnswer(item['id'], tipo, resposta);
      },
    );
  }
}

// WIDGETS DE EXERCÍCIO ESPECÍFICOS

class _ExercicioDispatcher extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(dynamic) onVerify;

  const _ExercicioDispatcher({super.key, required this.item, required this.onVerify});

  @override
  State<_ExercicioDispatcher> createState() => _ExercicioDispatcherState();
}

class _ExercicioDispatcherState extends State<_ExercicioDispatcher> {
  int? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  int? _selectedLeftIndex;
  final Map<int, int> _associations = {}; // leftIndex -> rightIndex

  @override
  void didUpdateWidget(covariant _ExercicioDispatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['id'] != widget.item['id']) {
      _selectedOption = null;
      _textController.clear();
      _selectedLeftIndex = null;
      _associations.clear();
    }
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.item['tipo'];
    final enunciado = widget.item['enunciado'] ?? '';
    final leftCount = (widget.item['coluna_esquerda'] as List<dynamic>?)?.length ?? 0;

    final bool canVerify = tipo == 'escolha_multipla'
        ? _selectedOption != null
        : tipo == 'completar'
            ? _textController.text.trim().isNotEmpty
            : tipo == 'associacao'
                ? (_associations.isNotEmpty && _associations.length == leftCount)
                : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          enunciado,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _TupiColors.accent, height: 1.4),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: tipo == 'escolha_multipla'
                ? _buildEscolhaMultipla()
                : tipo == 'completar'
                    ? _buildCompletar()
                    : tipo == 'associacao'
                        ? _buildAssociacao()
                        : Center(child: Text('Tipo de exercício não suportado: $tipo')),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canVerify
                ? () {
                    if (tipo == 'escolha_multipla') {
                      widget.onVerify(_selectedOption);
                    } else if (tipo == 'completar') {
                      widget.onVerify(_textController.text.trim());
                    } else if (tipo == 'associacao') {
                      final mapPayload = _associations.map((k, v) => MapEntry(k.toString(), v.toString()));
                      widget.onVerify(mapPayload);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _TupiColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _TupiColors.border,
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('VERIFICAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildEscolhaMultipla() {
    final opcoes = widget.item['opcoes'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(opcoes.length, (index) {
        final text = opcoes[index].toString();
        final isSelected = _selectedOption == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => setState(() => _selectedOption = index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected ? _TupiColors.primary.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _TupiColors.primary : _TupiColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _TupiColors.primary : _TupiColors.subtitle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCompletar() {
    final String textoComLacunas = widget.item['texto_com_lacunas']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (textoComLacunas.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _TupiColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildFormattedLacuna(textoComLacunas),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          "Digite a palavra que completa a lacuna:",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _TupiColors.subtitle),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          onChanged: (v) => setState(() {}),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _TupiColors.accent),
          decoration: InputDecoration(
            hintText: 'Sua resposta...',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _TupiColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _TupiColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormattedLacuna(String texto) {
    if (!texto.contains('___')) {
      return Text(
        texto,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _TupiColors.accent,
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
          color: _TupiColors.subtitle,
          height: 1.6,
        ),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _TupiColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _TupiColors.primary, width: 1.5),
              ),
              child: Text(
                _textController.text.trim().isNotEmpty
                    ? _textController.text.trim()
                    : ' ______ ',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _TupiColors.primary,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }

  Widget _buildAssociacao() {
    final leftItems = (widget.item['coluna_esquerda'] as List<dynamic>?) ?? [];
    final rightItems = (widget.item['coluna_direita'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Toque em uma palavra à esquerda e depois na sua tradução correspondente à direita:",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _TupiColors.subtitle),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna da Esquerda
            Expanded(
              child: Column(
                children: List.generate(leftItems.length, (i) {
                  final text = leftItems[i].toString();
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
                              ? _TupiColors.primary.withValues(alpha: 0.15)
                              : isMatched
                                  ? _TupiColors.accent.withValues(alpha: 0.08)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? _TupiColors.primary
                                : isMatched
                                    ? _TupiColors.accent
                                    : _TupiColors.border,
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
                                      ? _TupiColors.primary
                                      : isMatched
                                          ? _TupiColors.accent
                                          : _TupiColors.subtitle,
                                ),
                              ),
                            ),
                            if (isMatched) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _TupiColors.accent,
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
                children: List.generate(rightItems.length, (j) {
                  final text = rightItems[j].toString();
                  // Acha se algum item da esquerda está associado a este j
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
                            // Associa o selecionado da esquerda com este j
                            _associations.removeWhere((k, v) => v == j);
                            _associations[_selectedLeftIndex!] = j;
                            _selectedLeftIndex = null;
                          } else if (isMatched) {
                            // Se já estava associado e clica nele sem esquerda selecionada, desassocia
                            _associations.remove(matchedLeft);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? _TupiColors.accent.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMatched ? _TupiColors.accent : _TupiColors.border,
                            width: isMatched ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isMatched) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _TupiColors.accent,
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
                                  color: isMatched ? _TupiColors.accent : _TupiColors.subtitle,
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
