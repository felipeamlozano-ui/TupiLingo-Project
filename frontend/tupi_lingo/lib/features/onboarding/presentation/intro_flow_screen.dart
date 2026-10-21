import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/audio/audio_manager.dart';
import '../application/intro_controller.dart';
import '../domain/demo_lesson_content.dart';
import 'widgets/mascot_avatar.dart';
import 'widgets/speech_bubble.dart';
import 'widgets/onboarding_progress_bar.dart';
import 'widgets/tupi_3d_button.dart';
import 'package:tupi_lingo/features/auth/presentation/register.dart';
import 'package:tupi_lingo/features/auth/presentation/login.dart';

/// Tela principal do fluxo de introdução e tutorial imersivo do TupiLingo.
class IntroFlowScreen extends StatefulWidget {
  const IntroFlowScreen({super.key});

  @override
  State<IntroFlowScreen> createState() => _IntroFlowScreenState();
}

class _IntroFlowScreenState extends State<IntroFlowScreen> {
  late final IntroController _controller;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _controller = IntroController();
    _controller.addListener(_onControllerUpdated);
  }

  void _onControllerUpdated() {
    if (_pageController.hasClients &&
        _pageController.page?.round() != _controller.currentStep) {
      _pageController.animateToPage(
        _controller.currentStep,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_controller.currentStep + 1) / IntroController.totalSteps;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progresso com botão voltar (a partir da etapa 1)
            OnboardingProgressBar(
              progress: progress,
              onBack: _controller.currentStep > 0
                  ? () => _controller.previousStep()
                  : null,
              onSkip: _controller.currentStep < 8
                  ? () {
                      // Permite pular direto para o cadastro se o usuário tiver pressa
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    }
                  : null,
              skipLabel: 'Cadastrar direto',
            ),

            // Conteúdo paginado
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Navegação controlada
                children: [
                  _buildStep0MeetTupi(),
                  _buildStep1YouAlreadySpeakTupi(),
                  _buildStep2Motivation(),
                  _buildStep3Source(),
                  _buildStep4Level(),
                  _buildStep5DailyGoal(),
                  _buildStep6Preparing(),
                  _buildStep7PlanSummary(),
                  _buildStep8DemoLesson(),
                  _buildStep9CelebrationAndSave(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ETAPA 0: Conhecendo o Mascote Tupi
  // ==========================================
  Widget _buildStep0MeetTupi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const MascotAvatar(
            size: 150,
            mood: MascotMood.talking,
          ),
          const SizedBox(height: 18),
          const SpeechBubble(
            title: 'Aué! Eu sou o Tupi 🐒',
            text:
                'Vou te guiar na redescoberta do Tupi Antigo, a bela língua originária que moldou a alma, a fala e a natureza do Brasil!',
            typewriterEffect: true,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF0E5D4E), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Lições rápidas de 3 minutos, com histórias ancestrais, fonética autêntica e muita prática interativa.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 36),
          Tupi3DButton(
            text: 'VAMOS COMEÇAR!',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _controller.nextStep(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              'JÁ TENHO UMA CONTA',
              style: TextStyle(
                color: Color(0xFF0E5D4E),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 1: "Você já fala Tupi!"
  // ==========================================
  Widget _buildStep1YouAlreadySpeakTupi() {
    final words = [
      {'word': 'Pipoca', 'origin': 'Piboka', 'mean': 'A que estoura na pele', 'icon': '🍿'},
      {'word': 'Abacaxi', 'origin': 'Ibacati', 'mean': 'Fruta cheirosa saborosa', 'icon': '🍍'},
      {'word': 'Capivara', 'origin': 'Kapi\'iwara', 'mean': 'Comedor de capim', 'icon': '🦫'},
      {'word': 'Mandioca', 'origin': 'Mani\'oka', 'mean': 'Casa de Mani (raiz sagrada)', 'icon': '🌿'},
      {'word': 'Maracanã', 'origin': 'Marakanã', 'mean': 'Pássaro do som de chocalho', 'icon': '🦜'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MascotAvatar(size: 70, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sabia que você já fala Tupi todo dia?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Centenas de palavras do nosso cotidiano vieram diretamente da língua Tupi Antigo. Veja só algumas:',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ...words.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['word']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['origin']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD08A45),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['mean']!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Tupi3DButton(
            text: 'QUE DEMAIS! CONTINUAR',
            onPressed: () => _controller.nextStep(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 2: Motivação
  // ==========================================
  Widget _buildStep2Motivation() {
    final motivations = [
      {'id': 'raizes', 'label': 'Reconectar com minhas raízes ancestrais', 'icon': Icons.favorite_rounded},
      {'id': 'historia', 'label': 'Conhecer a história e a cultura brasileira', 'icon': Icons.account_balance_rounded},
      {'id': 'estudos', 'label': 'Apoiar meus estudos / faculdade / pesquisa', 'icon': Icons.school_rounded},
      {'id': 'curiosidade', 'label': 'Gosto de línguas e novidades culturais', 'icon': Icons.lightbulb_rounded},
      {'id': 'preservacao', 'label': 'Apoiar a valorização das línguas originárias', 'icon': Icons.eco_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MascotAvatar(size: 65, mood: MascotMood.thinking),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'O que te motivou a começar agora?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Isso nos ajuda a sugerir histórias e trilhas que você vai adorar.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 20),
          ...motivations.map((item) {
            final isSelected = _controller.draft.motivation == item['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _controller.setMotivation(item['id'] as String),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD08A45).withValues(alpha: 0.12)
                        : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD08A45) : AppTheme.border(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? const Color(0xFFD08A45) : AppTheme.textSecondary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFFD08A45) : AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFD08A45), size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Tupi3DButton(
            text: 'CONTINUAR',
            onPressed: _controller.draft.motivation != null
                ? () => _controller.nextStep()
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 3: Origem (Como conheceu o app)
  // ==========================================
  Widget _buildStep3Source() {
    final sources = [
      {'id': 'redes_sociais', 'label': 'Redes Sociais (Instagram, TikTok, etc.)', 'icon': Icons.share_rounded},
      {'id': 'indicacao', 'label': 'Indicação de amigos ou família', 'icon': Icons.people_alt_rounded},
      {'id': 'escola', 'label': 'Escola, universidade ou professor', 'icon': Icons.school_rounded},
      {'id': 'pesquisa', 'label': 'Pesquisa na Google Play ou internet', 'icon': Icons.search_rounded},
      {'id': 'outro', 'label': 'Outro lugar', 'icon': Icons.more_horiz_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MascotAvatar(size: 65, mood: MascotMood.idle),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Como você descobriu o TupiLingo?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...sources.map((item) {
            final isSelected = _controller.draft.source == item['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _controller.setSource(item['id'] as String),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
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
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? const Color(0xFF0E5D4E) : AppTheme.textSecondary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0E5D4E) : AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF0E5D4E), size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Tupi3DButton.forest(
            text: 'CONTINUAR',
            onPressed: _controller.draft.source != null
                ? () => _controller.nextStep()
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 4: Declaração de Nível
  // ==========================================
  Widget _buildStep4Level() {
    final levels = [
      {
        'id': 'nenhum',
        'title': 'Novo por aqui',
        'subtitle': 'Não conheço nada de Tupi (começar do zero)',
        'icon': Icons.fiber_new_rounded,
        'color': const Color(0xFF2196F3),
      },
      {
        'id': 'iniciante',
        'title': 'Iniciante',
        'subtitle': 'Nunca estudei, mas conheço algumas palavras soltas',
        'icon': Icons.eco_rounded,
        'color': const Color(0xFF4CAF50),
      },
      {
        'id': 'intermediario',
        'title': 'Intermediário',
        'subtitle': 'Conheço frases básicas e estrutura gramatical inicial',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFFF9800),
      },
      {
        'id': 'avancado',
        'title': 'Avançado',
        'subtitle': 'Consigo formar sentenças e interpretar textos antigos',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFD08A45),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MascotAvatar(size: 65, mood: MascotMood.happy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quanto você já conhece de Tupi?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Você pode começar do zero absoluto ou fazer o teste de nivelamento adaptativo depois.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 20),
          ...levels.map((item) {
            final isSelected = _controller.draft.tupiLevel == item['id'];
            final color = item['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _controller.setTupiLevel(item['id'] as String),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : AppTheme.border(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item['icon'] as IconData, color: color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? color : AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: color, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Tupi3DButton(
            text: 'CONTINUAR',
            onPressed: _controller.draft.tupiLevel != null
                ? () => _controller.nextStep()
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 5: Meta Diária
  // ==========================================
  Widget _buildStep5DailyGoal() {
    final goals = [
      {'minutes': 5, 'label': 'Tranquilo', 'desc': '5 min / dia (1 lição rápida)'},
      {'minutes': 10, 'label': 'Regular', 'desc': '10 min / dia (2 lições + prática)', 'recommended': true},
      {'minutes': 15, 'label': 'Sério', 'desc': '15 min / dia (3 lições completas)'},
      {'minutes': 20, 'label': 'Intenso', 'desc': '20 min / dia (imersão cultural profunda)'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MascotAvatar(size: 65, mood: MascotMood.talking),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Qual é a sua meta diária de estudo?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Criar o hábito de 5 a 10 minutos por dia é o grande segredo para nunca esquecer o que aprendeu.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 20),
          ...goals.map((item) {
            final isSelected = _controller.draft.dailyGoalMinutes == item['minutes'];
            final isRec = item['recommended'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _controller.setDailyGoal(item['minutes'] as int),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD08A45).withValues(alpha: 0.12)
                        : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD08A45) : AppTheme.border(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD08A45).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item['minutes']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? const Color(0xFFD08A45) : AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFFD08A45) : AppTheme.textPrimary(context),
                                  ),
                                ),
                                if (isRec) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E5D4E),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'RECOMENDADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['desc'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFD08A45), size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Tupi3DButton(
            text: 'CONTINUAR',
            onPressed: _controller.draft.dailyGoalMinutes != null
                ? () => _controller.nextStep()
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 6: Montando Trilha (Transição Rápida)
  // ==========================================
  Widget _buildStep6Preparing() {
    return _PreparingStepWidget(
      onReady: () => _controller.nextStep(),
    );
  }

  // ==========================================
  // ETAPA 7: Resumo do Plano de Aprendizado
  // ==========================================
  Widget _buildStep7PlanSummary() {
    final goalMin = _controller.draft.dailyGoalMinutes ?? 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const MascotAvatar(size: 130, mood: MascotMood.celebrating),
          const SizedBox(height: 16),
          Text(
            'Seu plano está pronto!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preparamos sua trilha com base no seu objetivo e disponibilidade de tempo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFD08A45),
                  title: 'Meta Diária',
                  value: '$goalMin minutos por dia',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  icon: Icons.map_outlined,
                  color: const Color(0xFF0E5D4E),
                  title: 'Primeiro Destino',
                  value: 'Capítulo 1: Saudações e Boas-Vindas',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFFA000),
                  title: 'Primeiro Desafio',
                  value: 'Aprender a cumprimentar em Tupi (~90s)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Tupi3DButton(
            text: 'COMEÇAR PRIMEIRA LIÇÃO',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              _controller.startDemoLesson();
              _controller.nextStep();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ETAPA 8: Mini-Lição Demonstrativa (90s)
  // ==========================================
  Widget _buildStep8DemoLesson() {
    final subStep = _controller.demoSubStep;
    final totalSubSteps = DemoLessonContent.steps.length;
    final item = DemoLessonContent.steps[subStep];

    return _DemoLessonItemView(
      item: item,
      subStepIndex: subStep,
      totalSubSteps: totalSubSteps,
      isAnswerVerified: _controller.isAnswerVerified,
      isLastAnswerCorrect: _controller.isLastAnswerCorrect,
      onVerify: (isCorrect) => _controller.setDemoVerification(isCorrect: isCorrect),
      onAdvance: () => _controller.advanceDemoSubStep(totalSubSteps: totalSubSteps),
    );
  }

  // ==========================================
  // ETAPA 9: Celebração e Salvar Progresso
  // ==========================================
  Widget _buildStep9CelebrationAndSave() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const MascotAvatar(size: 140, mood: MascotMood.celebrating),
          const SizedBox(height: 14),
          const Text(
            'Mandou bem demais! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E5D4E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Você acabou de concluir sua primeira atividade em Tupi Antigo!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 24),

          // Cards de Conquistas e Recompensas
          Row(
            children: [
              Expanded(
                child: _buildRewardMetricCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFE05638),
                  title: 'OFENSIVA',
                  value: '1 DIA',
                  desc: 'Chama acesa!',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRewardMetricCard(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFD08A45),
                  title: 'XP TOTAL',
                  value: '+15 XP',
                  desc: 'Nível 1 iniciado',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRewardMetricCard(
                  icon: Icons.spa_rounded,
                  iconColor: const Color(0xFF0E5D4E),
                  title: 'CONCHAS',
                  value: '+10',
                  desc: 'Moeda da aldeia',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_rounded, color: Color(0xFFD08A45), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Crie sua conta agora para salvar seu XP, manter sua ofensiva acesa e explorar a aldeia!',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Tupi3DButton(
            text: 'SALVAR MEU PROGRESSO',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () {
              // Navega para o registro passando o rascunho salvo
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              'JÁ TENHO CONTA (ENTRAR)',
              style: TextStyle(
                color: Color(0xFF0E5D4E),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Widget Auxiliar: Transição "Montando Trilha"
// ==========================================
class _PreparingStepWidget extends StatefulWidget {
  final VoidCallback onReady;
  const _PreparingStepWidget({required this.onReady});

  @override
  State<_PreparingStepWidget> createState() => _PreparingStepWidgetState();
}

class _PreparingStepWidgetState extends State<_PreparingStepWidget> {
  int _completedItems = 0;

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _completedItems = 1);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _completedItems = 2);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _completedItems = 3);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotAvatar(size: 130, mood: MascotMood.thinking),
          const SizedBox(height: 32),
          Text(
            'Preparando sua jornada...',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 32),
          _buildCheckItem(title: 'Calibrando rota com seu objetivo', isDone: _completedItems >= 1),
          const SizedBox(height: 16),
          _buildCheckItem(title: 'Reunindo o acervo do Capítulo 1', isDone: _completedItems >= 2),
          const SizedBox(height: 16),
          _buildCheckItem(title: 'Acendendo a chama da sua aldeia', isDone: _completedItems >= 3),
        ],
      ),
    );
  }

  Widget _buildCheckItem({required String title, required bool isDone}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF0E5D4E).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? const Color(0xFF0E5D4E) : AppTheme.border(context),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF0E5D4E) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? const Color(0xFF0E5D4E) : Colors.grey,
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : const SizedBox(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                color: isDone ? const Color(0xFF0E5D4E) : AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Widget Auxiliar: Visualizador dos Exercícios da Lição Demo
// ==========================================
class _DemoLessonItemView extends StatefulWidget {
  final DemoStepItem item;
  final int subStepIndex;
  final int totalSubSteps;
  final bool isAnswerVerified;
  final bool isLastAnswerCorrect;
  final ValueChanged<bool> onVerify;
  final VoidCallback onAdvance;

  const _DemoLessonItemView({
    required this.item,
    required this.subStepIndex,
    required this.totalSubSteps,
    required this.isAnswerVerified,
    required this.isLastAnswerCorrect,
    required this.onVerify,
    required this.onAdvance,
  });

  @override
  State<_DemoLessonItemView> createState() => _DemoLessonItemViewState();
}

class _DemoLessonItemViewState extends State<_DemoLessonItemView> {
  int? _selectedMultipleChoice;
  String? _selectedBlankWord;
  Map<String, String> _userMatches = {};
  String? _selectedMatchLeft;

  @override
  void didUpdateWidget(covariant _DemoLessonItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subStepIndex != widget.subStepIndex) {
      _selectedMultipleChoice = null;
      _selectedBlankWord = null;
      _userMatches = {};
      _selectedMatchLeft = null;
    }
  }

  void _checkAnswer() {
    bool isCorrect = false;

    switch (widget.item.type) {
      case DemoStepType.vocabCard:
        isCorrect = true;
        break;
      case DemoStepType.multipleChoice:
        isCorrect = _selectedMultipleChoice == widget.item.correctOptionIndex;
        break;
      case DemoStepType.fillInTheBlank:
        isCorrect = _selectedBlankWord == widget.item.correctBlankAnswer;
        break;
      case DemoStepType.matching:
        final pairs = widget.item.matchingPairs ?? {};
        isCorrect = _userMatches.length == pairs.length &&
            _userMatches.entries.every((e) => pairs[e.key] == e.value);
        break;
    }

    if (isCorrect) {
      AudioManager.instance.playCorrect();
    } else {
      AudioManager.instance.playIncorrect();
    }

    widget.onVerify(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Indicador de progresso da demo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                'Lição Demonstrativa (${widget.subStepIndex + 1}/${widget.totalSubSteps})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD08A45),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.item.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                if (widget.item.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.item.subtitle!,
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context)),
                  ),
                ],
                const SizedBox(height: 24),
                _buildSpecificExerciseContent(),
              ],
            ),
          ),
        ),

        // Barra inferior de feedback ou botão de ação
        _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSpecificExerciseContent() {
    switch (widget.item.type) {
      case DemoStepType.vocabCard:
        return _buildVocabCard();
      case DemoStepType.multipleChoice:
        return _buildMultipleChoice();
      case DemoStepType.fillInTheBlank:
        return _buildFillInTheBlank();
      case DemoStepType.matching:
        return _buildMatching();
    }
  }

  Widget _buildVocabCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.volume_up_rounded, color: Color(0xFFD08A45), size: 36),
          const SizedBox(height: 12),
          Text(
            widget.item.tupiWord ?? '',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E5D4E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.pronunciation ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFFD08A45),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            widget.item.portugueseWord ?? '',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.item.explanation ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary(context), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoice() {
    final options = widget.item.options ?? [];
    return Column(
      children: List.generate(options.length, (index) {
        final opt = options[index];
        final isSelected = _selectedMultipleChoice == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: widget.isAnswerVerified
                ? null
                : () => setState(() => _selectedMultipleChoice = index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFD08A45).withValues(alpha: 0.12)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFD08A45) : AppTheme.border(context),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD08A45) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFFD08A45) : AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFillInTheBlank() {
    final sentence = widget.item.sentenceWithBlank ?? '';
    final parts = sentence.split('____');
    final wordBank = widget.item.wordBank ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              if (parts.isNotEmpty && parts[0].isNotEmpty)
                Text(
                  parts[0],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedBlankWord != null
                      ? const Color(0xFFD08A45).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedBlankWord != null
                        ? const Color(0xFFD08A45)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Text(
                  _selectedBlankWord ?? ' ______ ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD08A45),
                  ),
                ),
              ),
              if (parts.length > 1 && parts[1].isNotEmpty)
                Text(
                  parts[1],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Escolha a palavra correta para preencher:',
          style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary(context)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: wordBank.map((word) {
            final isSelected = _selectedBlankWord == word;
            return ChoiceChip(
              label: Text(
                word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textPrimary(context),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFD08A45),
              backgroundColor: AppTheme.surface(context),
              onSelected: widget.isAnswerVerified
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedBlankWord = selected ? word : null;
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMatching() {
    final pairs = widget.item.matchingPairs ?? {};
    final leftList = pairs.keys.toList();
    final rightList = pairs.values.toList()..shuffle();

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna Esquerda (Tupi)
            Expanded(
              child: Column(
                children: leftList.map((tupi) {
                  final isMatched = _userMatches.containsKey(tupi);
                  final isSelected = _selectedMatchLeft == tupi;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: isMatched || widget.isAnswerVerified
                          ? null
                          : () => setState(() => _selectedMatchLeft = tupi),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? Colors.green.withValues(alpha: 0.12)
                              : isSelected
                                  ? const Color(0xFFD08A45).withValues(alpha: 0.15)
                                  : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMatched
                                ? Colors.green
                                : isSelected
                                    ? const Color(0xFFD08A45)
                                    : AppTheme.border(context),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          tupi,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isMatched ? Colors.green : AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 14),
            // Coluna Direita (Português)
            Expanded(
              child: Column(
                children: rightList.map((pt) {
                  final isMatched = _userMatches.containsValue(pt);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: isMatched || _selectedMatchLeft == null || widget.isAnswerVerified
                          ? null
                          : () {
                              setState(() {
                                _userMatches[_selectedMatchLeft!] = pt;
                                _selectedMatchLeft = null;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? Colors.green.withValues(alpha: 0.12)
                              : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMatched ? Colors.green : AppTheme.border(context),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          pt,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isMatched ? Colors.green : AppTheme.textPrimary(context),
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

  Widget _buildBottomActionBar() {
    final bool canCheck = widget.item.type == DemoStepType.vocabCard ||
        (widget.item.type == DemoStepType.multipleChoice && _selectedMultipleChoice != null) ||
        (widget.item.type == DemoStepType.fillInTheBlank && _selectedBlankWord != null) ||
        (widget.item.type == DemoStepType.matching &&
            _userMatches.length == (widget.item.matchingPairs?.length ?? 0));

    if (!widget.isAnswerVerified) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(top: BorderSide(color: AppTheme.border(context))),
        ),
        child: Tupi3DButton(
          text: widget.item.type == DemoStepType.vocabCard ? 'ENTENDI, CONTINUAR' : 'VERIFICAR RESPOSTA',
          onPressed: canCheck ? _checkAnswer : null,
        ),
      );
    }

    final isCorrect = widget.isLastAnswerCorrect;
    final feedbackColor = isCorrect ? const Color(0xFF0E5D4E) : const Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFEAF3F1) : const Color(0xFFFDECEE),
        border: Border(top: BorderSide(color: feedbackColor.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                color: feedbackColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Excelente!' : 'Quase lá!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: feedbackColor,
                ),
              ),
            ],
          ),
          if (widget.item.explanation != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.item.explanation!,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textPrimary(context),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Tupi3DButton(
            text: 'CONTINUAR',
            backgroundColor: feedbackColor,
            shadowColor: isCorrect ? const Color(0xFF073C32) : const Color(0xFF9E1B1B),
            onPressed: widget.onAdvance,
          ),
        ],
      ),
    );
  }
}
