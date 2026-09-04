import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';

class _TupiColors {
  static const background = Color(0xFFF3F2E8);
  static const subtitle = Color(0xFF565D6D);
  static const primary = Color(0xFFD08A45);
  static const accent = Color(0xFF0E5D4E);
  static const border = Color(0xFFD0D0D0);
}

class SelectLevelScreen extends StatefulWidget {
  final Map<String, dynamic> variante;

  const SelectLevelScreen({super.key, required this.variante});

  @override
  State<SelectLevelScreen> createState() => _SelectLevelScreenState();
}

class _SelectLevelScreenState extends State<SelectLevelScreen> {
  String? _selectedLevel;
  bool _isLoading = false;

  late final List<Map<String, dynamic>> _levelOptions;

  @override
  void initState() {
    super.initState();
    final String nome = widget.variante['nome']?.toString() ?? 'Tupi';
    _levelOptions = [
      {
        'value': 'nenhum',
        'label': 'Novo por aqui',
        'description': 'Não conheço nada de $nome',
        'icon': Icons.fiber_new_rounded,
        'color': const Color(0xFF2196F3),
      },
      {
        'value': 'iniciante',
        'label': 'Iniciante',
        'description': 'Nunca estudei $nome antes, mas conheço o básico',
        'icon': Icons.eco_rounded,
        'color': const Color(0xFF4CAF50),
      },
      {
        'value': 'intermediario',
        'label': 'Intermediário',
        'description': 'Conheço algumas palavras e frases de $nome',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFFF9800),
      },
      {
        'value': 'avancado',
        'label': 'Avançado',
        'description': 'Consigo formar frases completas em $nome',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFD08A45),
      },
    ];
  }

  Future<void> _handleContinue() async {
    if (_selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione seu nível de conhecimento.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Não autenticado');

      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final varianteId = widget.variante['id'];

      // Se for iniciante total ("nenhum"), define nível inicial 1 no backend e vai para a Home
      if (_selectedLevel == 'nenhum') {
        final res = await http.post(
          Uri.parse('$baseUrl/api/v1/nivelamento/definir-nivel-inicial/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'variante_id': varianteId,
            'nivel': 1,
          }),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (res.statusCode == 200) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          throw Exception('Erro ao definir nível inicial.');
        }
      } else {
        // Redireciona para o teste de nivelamento adaptativo daquela variante
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TesteScreen(
              nivel: _selectedLevel!,
              initialVariante: widget.variante,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nome = widget.variante['nome']?.toString() ?? 'Tupi';
    final String icone = widget.variante['icone']?.toString() ?? '🌿';

    return Scaffold(
      backgroundColor: _TupiColors.background,
      appBar: AppBar(
        backgroundColor: _TupiColors.background,
        elevation: 0,
        foregroundColor: _TupiColors.accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _TupiColors.primary))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _TupiColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(icone, style: const TextStyle(fontSize: 48)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Qual seu nível em $nome?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _TupiColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Isso nos ajuda a calibrar as lições e histórias sob medida para você.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _TupiColors.subtitle,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Lista de Opções de Nível
                      ..._levelOptions.map((opt) {
                        final isSelected = _selectedLevel == opt['value'];
                        final Color optColor = opt['color'] as Color;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () => setState(() => _selectedLevel = opt['value'] as String),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? optColor.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? optColor : _TupiColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: optColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(opt['icon'] as IconData, color: optColor, size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opt['label'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? optColor : _TupiColors.accent,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          opt['description'] as String,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: _TupiColors.subtitle,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? optColor : _TupiColors.border,
                                        width: 2,
                                      ),
                                      color: isSelected ? optColor : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 24),

                      // Botão Continuar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedLevel != null ? _handleContinue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _TupiColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _TupiColors.border,
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'CONTINUAR',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
