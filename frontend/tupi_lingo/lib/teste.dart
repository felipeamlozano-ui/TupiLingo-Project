import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TesteScreen extends StatefulWidget {
  final String nivel;

  const TesteScreen({super.key, required this.nivel});

  @override
  State<TesteScreen> createState() => _TesteScreenState();
}

class _TesteScreenState extends State<TesteScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  bool _isLoading = true;
  String? _feedbackMessage;
  int _currentNivel = 1;

  @override
  void initState() {
    super.initState();
    _initNivel();
    _fetchQuestions();
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

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Usuário não autenticado');

      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final url = Uri.parse('$baseUrl/api/nivelamento/gerar-questao/');
      
      final Map<String, dynamic> payload = {
        'nivel_atual': _currentNivel,
        'acertou_anterior': null, // Não usamos mais modo adaptativo por questão
      };

      final response = await http.post(
        url,
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
          if (_questions.isEmpty) {
            throw Exception('Nenhuma questão gerada.');
          }
          _isLoading = false;
        });
      } else {
        throw Exception('Erro ao gerar questões: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _feedbackMessage = 'Erro de conexão: $e';
      });
    }
  }

  void _handleAnswer(String resposta) {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    
    final currentQuestion = _questions[_currentQuestionIndex];
    final bool acertou = resposta == currentQuestion['resposta_correta'];
    
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
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    acertou ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: acertou ? const Color(0xFF0E5D4E) : const Color(0xFFD32F2F),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    acertou ? 'Mandou bem!' : 'Quase lá!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: acertou ? const Color(0xFF0E5D4E) : const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                currentQuestion['explicacao'] ?? 'Sem explicação.',
                style: const TextStyle(fontSize: 15, color: Color(0xFF565D6D), height: 1.5),
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
                    backgroundColor: acertou ? const Color(0xFF0E5D4E) : const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
    // Lógica Anti-Chutes
    // Em 10 perguntas de múltipla escolha (4 opções), a média de acertos por chute é 2.5 (25%).
    // Portanto, <= 3 acertos = Nível 1.
    int finalLevel = 1;
    if (_correctAnswers <= 3) {
      finalLevel = 1;
    } else {
      // 4 acertos -> nível 2, 5 -> 3, ..., 10 -> 8
      finalLevel = _correctAnswers - 2; 
    }

    // Exibir loading enquanto salva o nível
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF0E5D4E))),
    );

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
        await http.post(
          Uri.parse('$baseUrl/auth/update-level'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({'level': finalLevel.toString()}),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar nível final: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Remove o loading

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
                  color: const Color(0xFFD08A45).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Teste Concluído!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0E5D4E),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Você acertou $_correctAnswers de 10 perguntas!',
                style: const TextStyle(fontSize: 16, color: Color(0xFF565D6D)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Seu nível estabilizado é o Nível $finalLevel.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD08A45),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD08A45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'IR PARA INÍCIO',
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
      ),
    );
  }

  void _nextState() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishTest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFF3F2E8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Teste de Nivelamento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / 10,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0E5D4E)),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFD08A45)),
                    const SizedBox(height: 24),
                    const Text(
                      'Aguarde um pouquinho, estamos preparando um teste para você... :)',
                      style: TextStyle(fontSize: 16, color: Color(0xFF565D6D), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nível $_currentNivel · Questão ${_currentQuestionIndex + 1}/10',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              )
            : _feedbackMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_feedbackMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchQuestions,
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD08A45).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Questão ${_currentQuestionIndex + 1} de 10',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Color(0xFFD08A45), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _questions.isNotEmpty ? _questions[_currentQuestionIndex]['enunciado'] ?? '' : '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0E5D4E), height: 1.4),
                          ),
                          const SizedBox(height: 48),
                          ...(_questions.isNotEmpty ? _questions[_currentQuestionIndex]['opcoes'] as List<dynamic> : []).map((opcao) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _handleAnswer(opcao.toString()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFD0D0D0), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opcao.toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF0E5D4E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD0D0D0), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
      ),
    );
  }
}
