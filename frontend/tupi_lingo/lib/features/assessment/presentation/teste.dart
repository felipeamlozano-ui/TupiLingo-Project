import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class _TupiColors {
  static const background = Color(0xFFF3F2E8);
  static const subtitle = Color(0xFF565D6D);
  static const primary = Color(0xFFD08A45);
  static const accent = Color(0xFF0E5D4E);
  static const danger = Color(0xFFD32F2F);
  static const inputBorder = Color(0xFFD0D0D0);
}

class TesteScreen extends StatefulWidget {
  final String nivel;
  final Map<String, dynamic>? initialVariante;

  const TesteScreen({
    super.key,
    required this.nivel,
    this.initialVariante,
  });

  @override
  State<TesteScreen> createState() => _TesteScreenState();
}

class _TesteScreenState extends State<TesteScreen> with TickerProviderStateMixin {
  int _currentNivel = 1;
  
  // Fases do Nivelamento: 0 = Selecionar Variante, 1 = Carregando/Teste, 2 = Finalizado
  int _phase = 0;
  
  // Estado Variantes
  bool _isLoadingVariants = true;
  List<Map<String, dynamic>> _variantes = [];
  Map<String, dynamic>? _selectedVariante;

  // Estado Teste
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  bool _isLoadingTest = false;
  String? _feedbackMessage;
  final List<Map<String, dynamic>> _userAnswers = [];
  DateTime? _questionStartTime;
  int _finalLevel = 1;

  @override
  void initState() {
    super.initState();
    _initNivel();
    if (widget.initialVariante != null) {
      _selectedVariante = widget.initialVariante;
      _isLoadingVariants = false;
      _phase = 1;
      _startTestForVariante(widget.initialVariante!);
    } else {
      _fetchVariantes();
    }
  }

  void _initNivel() {
    switch (widget.nivel.toLowerCase()) {
      case 'iniciante':
        _currentNivel = 2;
        break;
      case 'intermediario':
        _currentNivel = 5;
        break;
      case 'avancado':
        _currentNivel = 8;
        break;
      default:
        _currentNivel = 1;
    }
  }

  Future<void> _fetchVariantes() async {
    setState(() {
      _isLoadingVariants = true;
      _feedbackMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Usuário não autenticado');

      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final url = Uri.parse('$baseUrl/api/v1/trilha/variantes/');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _variantes = List<Map<String, dynamic>>.from(data['variantes'] ?? []);
          _isLoadingVariants = false;
        });
      } else {
        throw Exception('Erro ao buscar línguas.');
      }
    } catch (e) {
      setState(() {
        _isLoadingVariants = false;
        _feedbackMessage = 'Erro de conexão: $e';
      });
    }
  }

  Future<void> _startTestForVariante(Map<String, dynamic> variante) async {
    setState(() {
      _selectedVariante = variante;
      _phase = 1;
      _isLoadingTest = true;
      _feedbackMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Usuário não autenticado');
      
      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      // 1. Atualizar a variante ativa do usuário
      final updateUrl = Uri.parse('$baseUrl/api/v1/auth/update-variante');
      final updateResponse = await http.post(
        updateUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'variante_id': variante['id']}),
      );

      if (updateResponse.statusCode != 200) {
        throw Exception('Erro ao definir variante ativa.');
      }

      // 2. Gerar Questões
      final testUrl = Uri.parse('$baseUrl/api/v1/nivelamento/gerar-questao/');
      final payload = {
        'nivel_atual': _currentNivel,
        'variante_id': variante['id'],
      };

      final response = await http.post(
        testUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _questions = List<Map<String, dynamic>>.from(data['questoes'] ?? []);
          if (_questions.isEmpty) throw Exception('Nenhuma questão gerada.');
          _isLoadingTest = false;
          _questionStartTime = DateTime.now();
        });
      } else if (response.statusCode == 409) {
        // Já testado! Vai pro final.
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _finalLevel = data['error']?['nivel_atual'] ?? 1;
          _correctAnswers = 0; // irrelevante
          _questions = [];
          _phase = 2; // Tela final
          _isLoadingTest = false;
        });
      } else {
        throw Exception('Erro ao gerar questões: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoadingTest = false;
        _feedbackMessage = 'Erro de conexão: $e';
        _phase = 0; // Volta para seleção se falhar
      });
    }
  }

  void _handleAnswer(String resposta) {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentQuestionIndex];
    final bool acertou = resposta == currentQuestion['resposta_correta'];
    
    final timeTaken = _questionStartTime != null 
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds / 1000.0 
        : 0.0;
        
    _userAnswers.add({
      'question_text': currentQuestion['enunciado'],
      'selected_letter': resposta,
      'is_correct': acertou,
      'time_taken_seconds': timeTaken,
    });
    
    if (acertou) {
      _correctAnswers++;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: acertou ? const Color(0xFFEAF3F1) : const Color(0xFFFDECEE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0, right: 24.0, top: 24.0, bottom: 24.0 + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    acertou ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: acertou ? _TupiColors.accent : _TupiColors.danger,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    acertou ? 'Mandou bem!' : 'Quase lá!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: acertou ? _TupiColors.accent : _TupiColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                currentQuestion['explicacao'] ?? 'Sem explicação.',
                style: const TextStyle(fontSize: 15, color: _TupiColors.subtitle, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _nextState();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: acertou ? _TupiColors.accent : _TupiColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('CONTINUAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishTest() async {
    setState(() => _isLoadingTest = true);

    bool savedSuccessfully = false;
    int finalLvl = _currentNivel;
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && _selectedVariante != null) {
        final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
        
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/nivelamento/avaliar/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'current_level': _currentNivel,
            'variante_id': _selectedVariante!['id'],
            'answers': _userAnswers,
          }),
        ).timeout(const Duration(seconds: 15));
            
        if (response.statusCode == 200) {
            savedSuccessfully = true;
            final responseData = jsonDecode(utf8.decode(response.bodyBytes));
            finalLvl = responseData['new_level'] ?? _currentNivel;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Teste] Erro ao avaliar/salvar nível: $e');
    }

    if (!mounted) return;
    
    if (!savedSuccessfully) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFFFF3CD),
          content: Text(
            '⚠️ Resultado salvo localmente. Sincronize quando conectar.',
            style: TextStyle(color: Color(0xFF856404)),
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
    
    setState(() {
      _isLoadingTest = false;
      _finalLevel = finalLvl;
      _phase = 2; // Finalizado
    });
  }

  void _nextState() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _questionStartTime = DateTime.now();
      });
    } else {
      _finishTest();
    }
  }

  Future<bool> _handleBackAttempt() async {
    // Se o teste já foi finalizado (fase 2), permite voltar para a Home diretamente
    if (_phase == 2) {
      Navigator.pushReplacementNamed(context, '/home');
      return false;
    }

    // Se estiver em andamento (fase 1) ou na seleção (fase 0)
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _TupiColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Desistir do Nivelamento?',
          style: TextStyle(fontWeight: FontWeight.bold, color: _TupiColors.accent),
        ),
        content: const Text(
          'Se você sair agora, seu progresso neste teste será cancelado e seu nível não será alterado.',
          style: TextStyle(color: _TupiColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar Teste', style: TextStyle(color: _TupiColors.accent, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _TupiColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair do Teste'),
          ),
        ],
      ),
    );

    if (shouldQuit == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackAttempt();
        }
      },
      child: Scaffold(
        backgroundColor: _TupiColors.background,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: _TupiColors.background,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBackAttempt,
          ),
          title: Text(
            _phase == 0 ? 'Escolha sua Língua' : 'Teste de Nivelamento',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          bottom: _phase == 1 && _questions.isNotEmpty && !_isLoadingTest
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / _questions.length,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(_TupiColors.accent),
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_phase == 0) return _buildVariantSelection();
    if (_phase == 1) return _buildTestPhase();
    return _buildFinalPhase();
  }

  Widget _buildVariantSelection() {
    if (_isLoadingVariants) {
      return const Center(child: CircularProgressIndicator(color: _TupiColors.primary));
    }
    
    if (_feedbackMessage != null && _variantes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_feedbackMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchVariantes,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Text('🦜', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text(
            'Qual língua você quer aprender?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _TupiColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Você pode alterar depois. Faremos um teste rápido para descobrir seu nível.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _TupiColors.subtitle, height: 1.4),
          ),
          const SizedBox(height: 40),
          ..._variantes.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () => _startTestForVariante(v),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _TupiColors.inputBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      v['icone'] ?? '🌿',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v['nome'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              color: _TupiColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v['descricao'] ?? 'Aprenda a língua nativa.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _TupiColors.subtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: _TupiColors.inputBorder),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTestPhase() {
    if (_isLoadingTest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _TupiColors.primary),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Preparando perguntas de ${_selectedVariante?['nome']} para você...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: _TupiColors.subtitle, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_feedbackMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_feedbackMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _startTestForVariante(_selectedVariante!),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _TupiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Questão ${_currentQuestionIndex + 1} de ${_questions.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _TupiColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _questions.isNotEmpty ? _questions[_currentQuestionIndex]['enunciado'] ?? '' : '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _TupiColors.accent, height: 1.4),
          ),
          const SizedBox(height: 48),
          ...(_questions.isNotEmpty ? _questions[_currentQuestionIndex]['alternativas'] as List<dynamic> : []).map((opcaoObj) {
            final String letra = opcaoObj['letra']?.toString() ?? '';
            final String texto = opcaoObj['texto']?.toString() ?? '';
            final String displayTexto = '$letra - $texto';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _handleAnswer(letra),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _TupiColors.inputBorder, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTexto,
                          style: const TextStyle(
                            fontSize: 16,
                            color: _TupiColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: _TupiColors.inputBorder, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinalPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _TupiColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Você está pronto!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _TupiColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            if (_questions.isNotEmpty) ...[
              Text(
                'Você acertou $_correctAnswers de ${_questions.length} perguntas!',
                style: const TextStyle(fontSize: 16, color: _TupiColors.subtitle),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 18, color: _TupiColors.subtitle),
                children: [
                  const TextSpan(text: 'Seu nível em '),
                  TextSpan(text: '${_selectedVariante?['nome']} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: 'foi estabilizado no '),
                  TextSpan(
                    text: 'Nível $_finalLevel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _TupiColors.primary,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _TupiColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'COMEÇAR MINHA JORNADA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
