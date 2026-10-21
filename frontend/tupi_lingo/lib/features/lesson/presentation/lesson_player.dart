import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/network/api_cache_manager.dart';
import 'package:tupi_lingo/core/network/lesson_outbox_service.dart';
import '../../dashboard/data/repositories/dashboard_repository_impl.dart';
import 'widgets/exercises/multiple_choice_view.dart';
import 'widgets/exercises/fill_in_the_blank_view.dart';
import 'widgets/exercises/matching_columns_view.dart';
import '../../../../core/audio/audio_manager.dart';

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
  Map<String, String> _lessonVocabulary = {};

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
    final List<dynamic> exerciciosRaw = List<dynamic>.from(data['exercicios'] ?? []);
    final List<dynamic> vocab = data['vocabulario'] ?? [];

    _items = [];
    _totalExercicios = 0;
    _exercicioPrimeiraTentativa.clear();

    _lessonVocabulary = {};
    for (var v in vocab) {
      final tupi = v['palavra_tupi']?.toString();
      final pt = v['traducao_pt']?.toString();
      if (tupi != null && pt != null) {
        _lessonVocabulary[tupi] = pt;
      }
    }

    // 1. Contexto narrativo e saberes culturais (Story blocks)
    final List<Map<String, dynamic>> stories = [];
    for (var sb in storyBlocks) {
      final item = Map<String, dynamic>.from(sb);
      item['is_story'] = true;
      item['is_vocab'] = false;
      stories.add(item);
    }
    stories.sort((a, b) => ((a['ordem'] as num?)?.toInt() ?? 0).compareTo((b['ordem'] as num?)?.toInt() ?? 0));
    _items.addAll(stories);

    // 2. Apresentação do Vocabulário (Flashcards de Onboarding - Tarefa 3)
    // Apresenta palavras novas antes dos exercícios avaliativos
    final List<Map<String, dynamic>> vocabIntroCards = [];
    if (vocab.isNotEmpty) {
      for (var v in vocab) {
        vocabIntroCards.add({
          'id': 'vocab_${v['id'] ?? v['palavra_tupi']}',
          'is_story': false,
          'is_vocab': true,
          'palavra_tupi': v['palavra_tupi']?.toString() ?? '',
          'traducao_pt': v['traducao_pt']?.toString() ?? '',
          'transliteracao': v['transliteracao']?.toString() ?? '',
          'exemplo_tupi': v['exemplo_tupi']?.toString() ?? '',
          'exemplo_pt': v['exemplo_pt']?.toString() ?? '',
          'audio': v['audio']?.toString(),
        });
      }
    } else {
      // Fallback inteligente: se o payload não trouxe vocabulário explícito,
      // extrai os termos-alvo dos exercícios para não deixar o aluno sem introdução
      for (var ex in exerciciosRaw) {
        final target = ex['palavra_alvo'] ??
            (ex['respostas_lacunas'] is List && (ex['respostas_lacunas'] as List).isNotEmpty
                ? ex['respostas_lacunas'][0]
                : (ex['itens_alvo'] is List && (ex['itens_alvo'] as List).isNotEmpty ? ex['itens_alvo'][0] : null));
        if (target != null && target.toString().trim().isNotEmpty) {
          final targetStr = target.toString().trim();
          if (!vocabIntroCards.any((c) => c['palavra_tupi']?.toString().toLowerCase() == targetStr.toLowerCase())) {
            final pt = _lessonVocabulary[targetStr] ?? (ex['traducao_pt']?.toString() ?? '');
            vocabIntroCards.add({
              'id': 'vocab_inferred_$targetStr',
              'is_story': false,
              'is_vocab': true,
              'palavra_tupi': targetStr,
              'traducao_pt': pt,
              'transliteracao': '',
              'exemplo_tupi': ex['texto_com_lacunas']?.toString() ?? '',
              'exemplo_pt': ex['explicacao']?.toString() ?? '',
              'audio': null,
            });
          }
        }
      }
    }
    _items.addAll(vocabIntroCards);

    // 3. Escalonamento Pedagógico (Scaffolding - Tarefa 3):
    // Reconhecimento Passivo (Múltipla Escolha) -> Associação -> Produção Ativa (Completar com Digitação)
    int getScaffoldingWeight(String? tipo) {
      switch (tipo) {
        case 'escolha_multipla':
          return 1;
        case 'associacao':
          return 2;
        case 'completar':
          return 3;
        default:
          return 4;
      }
    }

    exerciciosRaw.sort((a, b) {
      final wA = getScaffoldingWeight(a['tipo']?.toString());
      final wB = getScaffoldingWeight(b['tipo']?.toString());
      if (wA != wB) return wA.compareTo(wB);
      final ordA = (a['ordem'] as num?)?.toInt() ?? 0;
      final ordB = (b['ordem'] as num?)?.toInt() ?? 0;
      return ordA.compareTo(ordB);
    });

    for (var ex in exerciciosRaw) {
      final item = Map<String, dynamic>.from(ex);
      item['is_story'] = false;
      item['is_vocab'] = false;
      _items.add(item);
      _totalExercicios++;
      _exercicioPrimeiraTentativa[item['id']] = true;
    }

    setState(() {
      _isLoading = false;
    });
    _updateProgress();
  }

  Future<void> _fetchLesson() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _errorMessage = null;
    });

    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final url = '$baseUrl/api/v1/trilha/licao/${widget.licaoId}/';

    // 1. Tenta carregar imediatamente do cache local criptografado (0ms)
    try {
      final cachedJson = await ApiCacheManager.instance.getCachedResponse(url);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final cachedData = jsonDecode(cachedJson);
        if (cachedData is Map<String, dynamic> && cachedData['success'] == true) {
          _applyLessonData(cachedData);
        }
      }
    } catch (_) {}

    // 2. Revalidação de rede em background
    try {
      final response = await ApiClient.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final bodyStr = utf8.decode(response.bodyBytes);
        final data = jsonDecode(bodyStr);
        if (data['success'] == true) {
          await ApiCacheManager.instance.saveResponse(url, bodyStr);
          if (_items.isEmpty) {
            _applyLessonData(data);
          }
        } else if (_items.isEmpty) {
          throw Exception(data['error'] ?? 'Erro desconhecido');
        }
      } else if (_items.isEmpty) {
        String msg = 'Erro ao buscar lição (HTTP ${response.statusCode})';
        try {
          final errData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errData is Map && errData['error'] != null) {
            msg = errData['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      // Se já tínhamos os itens do cache, o aluno pode prosseguir 100% offline!
      if (_items.isNotEmpty) {
        return;
      }

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
    if (isCorrect || isAlmost) {
      AudioManager.instance.playCorrect();
    } else {
      AudioManager.instance.playIncorrect();
    }

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
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    Navigator.pop(context);
                    _nextItem();
                  },
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                    Navigator.pop(context);
                    _nextItem();
                  },
                },
                child: Focus(
                  autofocus: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: fgColor, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fgColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishLesson() async {
    setState(() => _isLoading = true);

    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final int baseXp = (_licao?['xp_base'] as num?)?.toInt() ?? 20;
    final int estimatedXp = baseXp + _bonusXp;

    try {
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
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        DashboardRepositoryImpl.invalidateCache();

        if (mounted) {
          final List<dynamic> novasConquistas = data['novas_conquistas'] ?? [];
          final int? nivelAtual = data['nivel_atual'];
          _showVictoryDialog(
            data['earned_xp'] ?? estimatedXp,
            novasConquistas,
            nivelAtual,
            completionData: data is Map<String, dynamic> ? data : null,
            isOffline: false,
          );
        }
        return;
      } else {
        throw Exception('Servidor retornou HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e is SessionExpiredException && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sua sessão expirou. Faça login novamente.')),
        );
        Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      // OFFLINE-FIRST: Salva lição no Outbox assinado com HMAC-SHA256 e exibe vitória imediatamente
      debugPrint('[LessonPlayer] Conexão indisponível. Salvando lição ${widget.licaoId} no Outbox offline: $e');

      await LessonOutboxService.instance.enqueueCompletedLesson(
        licaoId: widget.licaoId,
        acertos: _acertos,
        totalExercicios: _totalExercicios,
        tempoSegundos: 60,
        bonusExploracaoXp: _bonusXp,
        xpGanho: estimatedXp,
      );

      DashboardRepositoryImpl.invalidateCache();

      if (mounted) {
        _showVictoryDialog(
          estimatedXp,
          [],
          null,
          isOffline: true,
        );
      }
    }
  }

  void _showVictoryDialog(
    int earnedXp,
    List<dynamic> novasConquistas,
    int? nivelAtual, {
    Map<String, dynamic>? completionData,
    bool isOffline = false,
  }) {
    AudioManager.instance.playChestReward();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
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
              if (isOffline) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.offline_pin_rounded, size: 18, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lição salva com segurança offline. Sincronização automática quando a rede voltar!',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
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
    final isVocab = currentItem['is_vocab'] == true;

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: isStory
                  ? _buildStoryBlock(currentItem)
                  : isVocab
                      ? _buildVocabIntroBlock(currentItem)
                      : _buildExercicioBlock(currentItem),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryBlock(Map<String, dynamic> item) {
    void handleContinue() {
      final xpBonus = item['xp_bonus'] ?? 0;
      if (xpBonus > 0) _bonusXp += (xpBonus as int);
      _nextItem();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): handleContinue,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): handleContinue,
      },
      child: Focus(
        autofocus: true,
        child: Column(
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
                onPressed: handleContinue,
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
        ),
      ),
    );
  }

  // Flashcard Introdutório de Vocabulário (Tarefa 3)
  Widget _buildVocabIntroBlock(Map<String, dynamic> item) {
    void handleContinue() {
      _nextItem();
    }

    final palavraTupi = item['palavra_tupi']?.toString() ?? '';
    final traducaoPt = item['traducao_pt']?.toString() ?? '';
    final transliteracao = item['transliteracao']?.toString() ?? '';
    final exemploTupi = item['exemplo_tupi']?.toString() ?? '';
    final exemploPt = item['exemplo_pt']?.toString() ?? '';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): handleContinue,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): handleContinue,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _TupiColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _TupiColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        'APRESENTAÇÃO DO VOCABULÁRIO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _TupiColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Aprenda este termo antes de iniciar os exercícios:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _TupiColors.subtitle,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5DFD3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        palavraTupi,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: _TupiColors.accent,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (transliteracao.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '/$transliteracao/',
                          style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: _TupiColors.subtitle.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        height: 2,
                        width: 70,
                        color: _TupiColors.border,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.translate_rounded, size: 22, color: _TupiColors.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              traducaoPt.isNotEmpty ? traducaoPt : 'Significado contextual',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _TupiColors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (exemploTupi.isNotEmpty || exemploPt.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEADECA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.format_quote_rounded, size: 18, color: _TupiColors.accent),
                                  SizedBox(width: 6),
                                  Text(
                                    'Exemplo de Uso:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _TupiColors.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (exemploTupi.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  exemploTupi,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _TupiColors.accent,
                                  ),
                                ),
                              ],
                              if (exemploPt.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  exemploPt,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: _TupiColors.subtitle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _TupiColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VAMOS PRATICAR 🏹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercicioBlock(Map<String, dynamic> item) {
    final tipo = item['tipo'];
    return _ExercicioDispatcher(
      key: ValueKey('ex_${item['id']}_$_currentIndex'),
      item: item,
      wordTranslations: _lessonVocabulary,
      onVerify: (dynamic resposta) {
        _verifyAnswer(item['id'], tipo, resposta);
      },
    );
  }
}

// WIDGETS DE EXERCÍCIO ESPECÍFICOS

class _ExercicioDispatcher extends StatefulWidget {
  final Map<String, dynamic> item;
  final Map<String, String> wordTranslations;
  final Function(dynamic) onVerify;

  const _ExercicioDispatcher({
    super.key,
    required this.item,
    required this.wordTranslations,
    required this.onVerify,
  });

  @override
  State<_ExercicioDispatcher> createState() => _ExercicioDispatcherState();
}

class _ExercicioDispatcherState extends State<_ExercicioDispatcher> {
  int? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  final Map<int, int> _associations = {}; // leftIndex -> rightIndex
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode.requestFocus();
  }

  @override
  void didUpdateWidget(covariant _ExercicioDispatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['id'] != widget.item['id']) {
      _selectedOption = null;
      _textController.clear();
      _associations.clear();
      _keyboardFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _triggerVerification(String tipo) {
    if (tipo == 'escolha_multipla') {
      widget.onVerify(_selectedOption);
    } else if (tipo == 'completar') {
      widget.onVerify(_textController.text.trim());
    } else if (tipo == 'associacao') {
      final mapPayload = _associations.map((k, v) => MapEntry(k.toString(), v.toString()));
      widget.onVerify(mapPayload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.item['tipo'];
    final leftCount = (widget.item['coluna_esquerda'] as List<dynamic>?)?.length ?? 0;

    // Mascara a resposta correta caso tenha sido revelada no enunciado entre aspas (ex: 'Abá katu.')
    String enunciado = widget.item['enunciado'] ?? '';
    final correctAnswers = (widget.item['respostas_lacunas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (widget.item['respostas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
    final target = widget.item['palavra_alvo']?.toString() ??
        (widget.item['itens_alvo'] is List && (widget.item['itens_alvo'] as List).isNotEmpty
            ? widget.item['itens_alvo'][0].toString()
            : (correctAnswers.isNotEmpty ? correctAnswers[0] : null));

    if (tipo == 'completar' && target != null && target.trim().isNotEmpty) {
      final escaped = RegExp.escape(target.trim());
      enunciado = enunciado.replaceAll(RegExp(r'\b' + escaped + r'\b', caseSensitive: false), '______');
    }

    final bool canVerify = tipo == 'escolha_multipla'
        ? _selectedOption != null
        : tipo == 'completar'
            ? _textController.text.trim().isNotEmpty
            : tipo == 'associacao'
                ? (_associations.isNotEmpty && _associations.length == leftCount)
                : false;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Atalhos 1 a 4 para exercícios de múltipla escolha
          if (tipo == 'escolha_multipla') {
            final optionsCount = (widget.item['opcoes'] as List<dynamic>?)?.length ?? 0;
            if ((event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) && optionsCount >= 1) {
              setState(() => _selectedOption = 0);
            } else if ((event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) && optionsCount >= 2) {
              setState(() => _selectedOption = 1);
            } else if ((event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) && optionsCount >= 3) {
              setState(() => _selectedOption = 2);
            } else if ((event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) && optionsCount >= 4) {
              setState(() => _selectedOption = 3);
            }
          }

          // Tecla Enter para confirmar resposta se preenchida
          if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (canVerify) {
              _triggerVerification(tipo);
            }
          }
        }
      },
      child: Column(
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
                  ? MultipleChoiceView(
                      options: widget.item['opcoes'] as List<dynamic>? ?? [],
                      selectedIndex: _selectedOption,
                      onSelect: (index) => setState(() => _selectedOption = index),
                    )
                  : tipo == 'completar'
                      ? FillInTheBlankView(
                          textoComLacunas: widget.item['texto_com_lacunas'] ?? '',
                          textController: _textController,
                          onChanged: (_) => setState(() {}),
                          wordTranslations: widget.wordTranslations,
                          targetWord: target,
                          correctAnswers: correctAnswers,
                          sentenceTranslation: widget.item['traducao_pt']?.toString() ?? widget.item['significado_pt']?.toString(),
                          explanation: widget.item['explicacao']?.toString(),
                        )
                  : tipo == 'associacao'
                      ? MatchingColumnsView(
                          key: ValueKey(widget.item['id']),
                          leftItems: widget.item['coluna_esquerda'] as List<dynamic>? ?? [],
                          rightItems: widget.item['coluna_direita'] as List<dynamic>? ?? [],
                          initialAssociations: _associations,
                          onAssociationsChanged: (map) => setState(() {
                            _associations.clear();
                            _associations.addAll(map);
                          }),
                        )
                      : Center(child: Text('Tipo de exercício não suportado: $tipo')),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canVerify ? () => _triggerVerification(tipo) : null,
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
      ),
    );
  }
}
