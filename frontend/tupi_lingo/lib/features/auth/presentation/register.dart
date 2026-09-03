import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'package:tupi_lingo/features/auth/presentation/otp_verification.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class _AppColors {
  static const Color background = Color(0xFFF3F2E8);
  static const Color subtitle = Color(0xFF565D6D);
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
  static const Color inputBorder = Color(0xFFD0D0D0);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
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

  final List<Map<String, dynamic>> _sourceOptions = const [
    {'value': 'redes_sociais', 'label': 'Redes Sociais', 'icon': Icons.share},
    {
      'value': 'indicacao',
      'label': 'Indicação de amigo',
      'icon': Icons.people,
    },
    {
      'value': 'escola',
      'label': 'Escola / Universidade',
      'icon': Icons.school,
    },
    {
      'value': 'pesquisa',
      'label': 'Pesquisa na internet',
      'icon': Icons.search,
    },
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

  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    // se o cara veio pelo google ele já tem conta, então pula a tela de criar senha
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


  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }


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
          _showSnackBar(
            'Selecione como você conheceu o TupiLingo.',
          );
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

    // Pelo menos 1 número para senha mais segura
    if (!RegExp(r'\d').hasMatch(password)) {
      _showSnackBar('A senha deve conter pelo menos um número.');
      return false;
    }

    return true;
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    isError ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color:
                    isError ? Colors.red.shade700 : Colors.green.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black87,
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

  Future<void> _handleRegister() async {
    if (!_validateCredentials()) return;


    setState(() => _isLoading = true);

    try {
      // cria a conta no auth do supabase e dispara o código de 6 dígitos pro email
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
        // SUPA-001: passa name e source para que OtpVerificationScreen possa
        // criar o UserProfile no Django após OTP verificado
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

      // URLS-001: prefixo /api/v1/ + SUPA-001: sincroniza perfil com Django
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
        debugPrint('REGISTER ERRO: ${response.statusCode} - ${response.body}');
        _showSnackBar('Erro ao salvar perfil. Tente novamente.');
      }
    } catch (e, stackTrace) {
      debugPrint('REGISTER GOOGLE ERRO: $e');
      debugPrint('STACKTRACE: $stackTrace');
      if (mounted) {
        _showSnackBar('Erro de conexão. Verifique sua internet.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
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
                      _buildStepName(),
                      _buildStepSource(),
                      // Para usuários Google, a Etapa 3 (nível) é a última.
                      // Para email/senha, segue com Etapa 4 (credenciais).
                      _buildStepLevel(),
                      if (!_isGoogleUser) _buildStepCredentials(),
                    ],
                  ),
                ),
              ],
            ),

            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: _AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // CABEÇALHO COM BARRA DE PROGRESSO E BOTÃO VOLTAR
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // Linha superior: botão voltar + indicador de etapa
          Row(
            children: [
              // Botão voltar (só aparece a partir da etapa 2)
              AnimatedOpacity(
                opacity: _currentStep > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  onPressed: _currentStep > 0 ? _previousStep : null,
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Indicador textual da etapa
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Etapa ${_currentStep + 1} de $_totalSteps',
                  style: const TextStyle(
                    color: _AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progresso animada
          AnimatedBuilder(
            animation: _progressAnimController,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  minHeight: 6,
                  backgroundColor: _AppColors.inputBorder.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _AppColors.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStepName() {
    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Emoji e título de boas-vindas
          Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: const Center(
                child: Text('🦜', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Bem-vindo ao TupiLingo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Para começar, nos diga como podemos te chamar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _AppColors.subtitle,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Campo de nome
          _buildTextField(
            controller: _nameController,
            label: 'Seu nome',
            hint: 'Ex: Felipe',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _nextStep(),
          ),

          const SizedBox(height: 32),
          _buildContinueButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepSource() {
    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: const Center(
                child: Text('🧭', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Como nos encontrou?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Queremos saber como você conheceu o TupiLingo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _AppColors.subtitle,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Grid de opções selecionáveis
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sourceOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final option = _sourceOptions[index];
              final isSelected = _selectedSource == option['value'];
              return _SelectableCard(
                icon: option['icon'] as IconData,
                label: option['label'] as String,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedSource = option['value'] as String);
                },
              );
            },
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 12),
          _buildContinueButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepLevel() {
    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: const Center(
                child: Text('🌱', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Qual seu nível em Tupi?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Isso nos ajuda a preparar uma experiência personalizada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _AppColors.subtitle,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Cards de nível
          ...List.generate(_levelOptions.length, (index) {
            final option = _levelOptions[index];
            final isSelected = _selectedLevel == option['value'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LevelCard(
                icon: option['icon'] as IconData,
                label: option['label'] as String,
                description: option['description'] as String,
                accentColor: option['color'] as Color,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedLevel = option['value'] as String);
                },
              ),
            );
          }),

          const SizedBox(height: 32),
          // Para Google: botão final que envia dados ao Django.
          // Para email/senha: botão "Continuar" para a Etapa 4.
          _isGoogleUser ? _buildFinalizeGoogleButton() : _buildContinueButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepCredentials() {
    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔐', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Quase lá!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Crie suas credenciais para salvar seu progresso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _AppColors.subtitle,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Campo de e-mail
          _buildTextField(
            controller: _emailController,
            label: 'E-mail',
            hint: 'seuemail@exemplo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Campo de senha
          _buildTextField(
            controller: _passwordController,
            label: 'Senha',
            hint: 'Mínimo 6 caracteres',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _AppColors.subtitle,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),

          const SizedBox(height: 32),

          // Botão final "Finalizar e Fazer Teste"
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent,
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
                    'FINALIZAR E FAZER TESTE',
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
                      Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // WIDGETS REUTILIZÁVEIS

  /// Botão "Continuar" padrão usado nas etapas 1, 2 e 3.
  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primary,
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

  /// Botão final para usuários Google na Etapa 3 (nível).
  /// Envia os dados de perfil ao backend Django.
  Widget _buildFinalizeGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.accent,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        labelStyle: const TextStyle(
          color: _AppColors.subtitle,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: _AppColors.primary, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// WIDGET: CONTAINER DA ETAPA (Padding uniforme)
class _StepContainer extends StatelessWidget {
  final Widget child;
  const _StepContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: child,
      ),
    );
  }
}

// WIDGET: CARD SELECIONÁVEL (Usado na etapa 2 - Fonte)
class _SelectableCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? _AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _AppColors.primary : _AppColors.inputBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Ícone com fundo
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? _AppColors.primary : _AppColors.subtitle,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Texto
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _AppColors.primary : Colors.black87,
                ),
              ),
            ),
            // Checkmark animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? _AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? _AppColors.primary : _AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET: CARD DE NÍVEL (Usado na etapa 3 - Nível)
// Com cor de destaque e descrição auxiliar.
class _LevelCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : _AppColors.inputBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Ícone com cor do nível
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.8)
                          : _AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : _AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
