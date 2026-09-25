import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'package:tupi_lingo/features/auth/presentation/otp_verification.dart';
import 'steps/step_credentials_widget.dart';
import 'steps/step_level_widget.dart';
import 'steps/step_name_widget.dart';
import 'steps/step_source_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final bool _isGoogleUser;
  int _currentStep = 0;
  late final int _totalSteps;

  String? _selectedSource;
  String? _selectedLevel;

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;
  double _previousProgress = 0.0;

  static const Color _primaryTerracotta = Color(0xFFD08A45);
  static const Color _forestGreen = Color(0xFF0E5D4E);

  final List<Map<String, dynamic>> _sourceOptions = const [
    {'value': 'redes_sociais', 'label': 'Redes Sociais', 'icon': Icons.share},
    {'value': 'indicacao', 'label': 'Indicação de amigo', 'icon': Icons.people},
    {'value': 'escola', 'label': 'Escola / Universidade', 'icon': Icons.school},
    {'value': 'pesquisa', 'label': 'Pesquisa na internet', 'icon': Icons.search},
    {'value': 'outro', 'label': 'Outro', 'icon': Icons.more_horiz},
  ];

  final List<Map<String, dynamic>> _levelOptions = const [
    {
      'value': 'nenhum',
      'label': 'Novo por aqui',
      'description': 'Não conheço nada de Tupi',
      'icon': Icons.fiber_new,
      'color': Color(0xFF2196F3),
    },
    {
      'value': 'iniciante',
      'label': 'Iniciante',
      'description': 'Nunca estudei Tupi antes, mas conheço o básico',
      'icon': Icons.eco,
      'color': Color(0xFF4CAF50),
    },
    {
      'value': 'intermediario',
      'label': 'Intermediário',
      'description': 'Conheço algumas palavras e frases',
      'icon': Icons.trending_up,
      'color': Color(0xFFFF9800),
    },
    {
      'value': 'avancado',
      'label': 'Avançado',
      'description': 'Consigo formar frases completas',
      'icon': Icons.star,
      'color': Color(0xFFD08A45),
    },
  ];

  // Prepara o controller de progresso e detecta se o usuário veio via OAuth do Google para pular o passo de senha.
  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    _isGoogleUser = session != null;
    _totalSteps = _isGoogleUser ? 3 : 4;

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1 / _totalSteps,
    ).animate(
      CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeInOut,
      ),
    );
    _progressAnimController.forward();
  }

  // Libera os controllers de texto, animações e o pageView da memória pra evitar vazamento no encerramento da tela.
  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  // Checa as validações da etapa atual antes de animar o PageView pro próximo passo do cadastro.
  void _nextStep() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      final newStep = _currentStep + 1;
      _animateProgress(newStep);
      _pageController.animateToPage(
        newStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = newStep);
    }
  }

  // Volta uma etapa do onboarding mantendo os dados preenchidos pra o usuário não ter que redigitar tudo se errar.
  void _previousStep() {
    if (_currentStep > 0) {
      final newStep = _currentStep - 1;
      _animateProgress(newStep);
      _pageController.animateToPage(
        newStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = newStep);
    }
  }

  // Atualiza com suavidade a barra de progresso no topo da tela dando sensação de avanço rápido no fluxo.
  void _animateProgress(int step) {
    _previousProgress = _progressAnimation.value;
    final newProgress = (step + 1) / _totalSteps;
    _progressAnimation = Tween<double>(
      begin: _previousProgress,
      end: newProgress,
    ).animate(
      CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeInOut,
      ),
    );
    _progressAnimController
      ..reset()
      ..forward();
  }

  // Roda a validação específica de cada etapa pra barrar o usuário antes de ir pro próximo passo.
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _showSnackBar('Por favor, digite seu nome para continuar.');
          return false;
        }
        if (_nameController.text.trim().length < 2) {
          _showSnackBar('O nome deve ter pelo menos 2 caracteres.');
          return false;
        }
        return true;
      case 1:
        if (_selectedSource == null) {
          _showSnackBar('Selecione como você conheceu o TupiLingo.');
          return false;
        }
        return true;
      case 2:
        if (_selectedLevel == null) {
          _showSnackBar('Selecione seu nível de conhecimento.');
          return false;
        }
        return true;
      case 3:
        return _validateCredentials();
      default:
        return true;
    }
  }

  // Valida se o email tem formato válido e se a senha tem pelo menos 8 dígitos com número antes de bater no Supabase.
  bool _validateCredentials() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showSnackBar('Digite seu e-mail para continuar.');
      return false;
    }

    final emailRegex = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Digite um e-mail válido.');
      return false;
    }

    if (password.isEmpty) {
      _showSnackBar('Digite sua senha para continuar.');
      return false;
    }

    if (password.length < 8) {
      _showSnackBar('A senha deve ter pelo menos 8 caracteres.');
      return false;
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      _showSnackBar('A senha deve conter pelo menos um número.');
      return false;
    }

    return true;
  }

  // Exibe avisos rápidos de erro ou sucesso no rodapé respeitando a paleta clara ou escura ativa.
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surface(context),
        elevation: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color: isError ? Colors.red.shade400 : Colors.green.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cria a conta no Supabase Auth com email e senha e já direciona pro teste de nivelamento ou pra tela de validação de OTP.
  Future<void> _handleRegister() async {
    if (!_validateCredentials()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'name': _nameController.text.trim(),
          'source': _selectedSource,
          'tupi_level': _selectedLevel,
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: _emailController.text.trim(),
              nivel: _selectedLevel!,
              userName: _nameController.text.trim(),
              userSource: _selectedSource ?? '',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMsg;
        if (e.message.toLowerCase().contains('already registered')) {
          errorMsg = 'Este e-mail já está cadastrado. Tente fazer login.';
        } else {
          errorMsg = e.message;
        }
        _showSnackBar(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro inesperado. Tente novamente mais tarde.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Salva o perfil complementar do usuário que veio via login do Google diretamente na API do Django.
  Future<void> _handleGoogleRegister() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Por favor, preencha seu nome.');
      return;
    }
    if (_selectedLevel == null) {
      _showSnackBar('Selecione seu nível de conhecimento.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _showSnackBar('Sessão expirada. Faça login novamente.');
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/register-user'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'source': _selectedSource ?? '',
              'tupi_level': _selectedLevel ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (_selectedLevel == 'nenhum') {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TesteScreen(nivel: _selectedLevel!),
            ),
          );
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          final msg = errorBody['error'] ?? 'Erro ao salvar perfil. Tente novamente.';
          _showSnackBar(msg.toString());
        } catch (_) {
          _showSnackBar('Erro ao salvar perfil. Tente novamente.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro de conexão. Verifique sua internet.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Constrói a estrutura visual do cadastro com suporte a back button físico e safe area.
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 0) {
          _previousStep();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/welcome');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentStep = index);
                      },
                      children: [
                        StepNameWidget(
                          nameController: _nameController,
                          onContinue: _nextStep,
                          continueButton: _buildContinueButton(),
                        ),
                        StepSourceWidget(
                          sourceOptions: _sourceOptions,
                          selectedSource: _selectedSource,
                          onSelectSource: (val) => setState(() => _selectedSource = val),
                          continueButton: _buildContinueButton(),
                        ),
                        StepLevelWidget(
                          levelOptions: _levelOptions,
                          selectedLevel: _selectedLevel,
                          onSelectLevel: (val) => setState(() => _selectedLevel = val),
                          actionButton: _isGoogleUser
                              ? _buildFinalizeGoogleButton()
                              : _buildContinueButton(),
                        ),
                        if (!_isGoogleUser)
                          StepCredentialsWidget(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            onTogglePasswordVisibility: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                            onSubmit: _handleRegister,
                            isLoading: _isLoading,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: _primaryTerracotta),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Monta o cabeçalho com botão de retorno, badge da etapa atual e barra de progresso animada.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_currentStep > 0) {
                    _previousStep();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/welcome');
                  }
                },
                icon: Icon(
                  Icons.arrow_back,
                  size: 22,
                  color: AppTheme.textPrimary(context),
                ),
                tooltip: _currentStep > 0 ? 'Voltar etapa' : 'Voltar',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surface(context),
                  foregroundColor: AppTheme.textPrimary(context),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryTerracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Etapa ${_currentStep + 1} de $_totalSteps',
                  style: const TextStyle(
                    color: _primaryTerracotta,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimController,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  minHeight: 6,
                  backgroundColor: AppTheme.border(context).withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(_primaryTerracotta),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Cria o botão principal de avançar etapa com animação de seta em terracota ancestral.
  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryTerracotta,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CONTINUAR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // Exibe o botão de conclusão para usuários que autenticaram com o Google pulando o passo de senha.
  Widget _buildFinalizeGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FINALIZAR CADASTRO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
