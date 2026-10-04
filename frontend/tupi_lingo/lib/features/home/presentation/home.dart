import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/lesson/presentation/lesson_player.dart';
import 'package:tupi_lingo/features/profile/presentation/profile_screen.dart';
import 'package:tupi_lingo/features/admin/presentation/admin_screen.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/select_level_screen.dart';
import 'package:tupi_lingo/features/dashboard/presentation/pages/progress_dashboard_screen.dart';
import 'package:tupi_lingo/features/rewards/presentation/widgets/indigenous_artifact_chest.dart';
import 'package:tupi_lingo/features/rewards/domain/entities/indigenous_reward.dart';
import 'package:tupi_lingo/core/state/app_progression_notifier.dart';
import 'package:tupi_lingo/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tupi_lingo/core/network/api_cache_manager.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/pratica/presentation/thematic_practice_screen.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';
import 'package:tupi_lingo/features/home/data/repositories/trail_vocabulary_repository.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/flashcard_practice_dialog.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/language_switcher_bottom_sheet.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/trail_app_bar.dart';
import 'package:tupi_lingo/features/store/presentation/store_screen.dart';
import 'package:tupi_lingo/features/feature_flags/application/providers/feature_flag_provider.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/flag_ids.dart';
import 'package:tupi_lingo/features/legal/data/legal_consent_service.dart';
import 'package:tupi_lingo/features/settings/presentation/settings_screen.dart';
import 'package:tupi_lingo/core/audio/audio_manager.dart';
import 'widgets/cultural_guide_dialog.dart';
import 'widgets/home_bottom_bar.dart';
import 'widgets/lesson_start_modal.dart';
import 'tabs/practice_tab_view.dart';
import 'tabs/trail_tab_view.dart';

// Paleta de cores com identidade visual Tupi para a tela inicial
class _TupiColors {
  static const primary = Color(0xFFD08A45);
  static const accent = Color(0xFF0E5D4E);
  static const textDark = Color(0xFF1F2937);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTabIndex = 0; // 0: Trilha, 1: Prática, 2: Perfil, 3: Admin (se autorizado)
  int _selectedCapituloIndex = 0;
  bool _isAdmin = false;

  AnimationController? _pulseController;
  AnimationController? _floatController;

  List<CapituloMapData> _capitulos = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Dados do Aluno (100% autênticos do Supabase/Django)
  int _xpTotal = 0;
  int _streakDays = 0;
  int _conchas = 0;
  int _varianteId = 1;
  String _varianteNome = 'Tupi Antigo';
  String _vocabCategoryFilter = 'Todas';

  // Maior capítulo alcançado na trilha pelo usuário
  int get _highestChapterReached {
    int maxCap = 1;
    for (final cap in _capitulos) {
      final hasCompleted = cap.licoes.any((l) => l.status == LicaoStatus.concluida);
      final hasAvailable = cap.licoes.any((l) => l.status == LicaoStatus.disponivel);
      if ((hasCompleted || hasAvailable) && cap.numero > maxCap) {
        maxCap = cap.numero;
      }
    }
    return maxCap;
  }

  // Vocabulário dinâmico atrelado à evolução do usuário na trilha
  List<Map<String, String>> get _vocabularyBank {
    final unlocked = TrailVocabularyRepository.getUnlockedVocabulary(_highestChapterReached);
    if (_vocabCategoryFilter != 'Todas') {
      return unlocked
          .where((item) => item.cat == _vocabCategoryFilter)
          .map((item) => item.toMap())
          .toList();
    }
    return unlocked.map((item) => item.toMap()).toList();
  }

  @override
  void initState() {
    super.initState();
    _initAnimControllers();
    _tryLoadCachedTrail();
    _loadUserDataAndTrail();
    AppProgressionNotifier.instance.addListener(_onProgressionUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LegalConsentService.instance.showConsentModalIfNeeded(context);
      }
    });
  }

  /// Carrega dados em cache local instantaneamente (0ms) antes do roundtrip de rede
  Future<void> _tryLoadCachedTrail() async {
    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final cached = await ApiCacheManager.instance.getCachedResponse('$baseUrl/api/v1/trilha/$_varianteId/capitulos/');
    if (cached != null && cached.isNotEmpty && _capitulos.isEmpty && mounted) {
      try {
        final dynamic mapData = jsonDecode(cached);
        if (mapData is Map<String, dynamic>) {
          _processMapData(mapData, isFromCache: true);
        }
      } catch (e) {
        debugPrint('[Home] Erro ao carregar cache local: $e');
      }
    }
  }

  // Atualiza conchas locais e recarrega os dados quando o progresso global é notificado
  void _onProgressionUpdated() {
    if (mounted) {
      final gained = AppProgressionNotifier.instance.lastConchasGained;
      if (gained > 0) {
        setState(() {
          _conchas += gained;
        });
      }
      _loadUserDataAndTrail();
    }
  }

  // Instancia controladores de animação para os efeitos de pulso e flutuação da trilha
  void _initAnimControllers() {
    _pulseController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _floatController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimControllers();
  }

  @override
  void dispose() {
    AppProgressionNotifier.instance.removeListener(_onProgressionUpdated);
    _pulseController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  // Destrava a próxima lição otimisticamente na memória para dar feedback instantâneo ao aluno
  void _optimisticallyUnlockLesson(int completedLessonId, {int? unlockedNextLessonId}) {
    if (!mounted || _capitulos.isEmpty) return;
    setState(() {
      bool found = false;
      for (int c = 0; c < _capitulos.length; c++) {
        final cap = _capitulos[c];
        final updatedLicoes = <LicaoMapData>[];
        for (int l = 0; l < cap.licoes.length; l++) {
          final lic = cap.licoes[l];
          if (lic.id == completedLessonId) {
            updatedLicoes.add(lic.copyWith(
              status: LicaoStatus.concluida,
              earnedXp: lic.earnedXp > 0 ? lic.earnedXp : lic.xpBase,
            ));
            found = true;
          } else if (unlockedNextLessonId != null && lic.id == unlockedNextLessonId) {
            updatedLicoes.add(lic.copyWith(status: LicaoStatus.disponivel));
          } else if (found && lic.status == LicaoStatus.bloqueada) {
            updatedLicoes.add(lic.copyWith(status: LicaoStatus.disponivel));
            found = false;
          } else {
            updatedLicoes.add(lic);
          }
        }
        _capitulos[c] = cap.copyWith(licoes: updatedLicoes);
      }
    });
  }

  /// Mescla o estado carregado da rede com o estado otimista da sessão local.
  /// Impede terminantemente rollbacks visuais caso a resposta da rede venha com cache
  /// desatualizado ou ocorra race condition antes da replicação do banco.
  List<CapituloMapData> _mergeCapitulosWithLocalProgress(
    List<CapituloMapData> current,
    List<CapituloMapData> incoming,
  ) {
    if (current.isEmpty) return incoming;

    final locallyCompleted = <int>{};
    final locallyUnlocked = <int>{};
    for (final cap in current) {
      for (final lic in cap.licoes) {
        if (lic.status == LicaoStatus.concluida) {
          locallyCompleted.add(lic.id);
        } else if (lic.status == LicaoStatus.disponivel || lic.status == LicaoStatus.emAndamento) {
          locallyUnlocked.add(lic.id);
        }
      }
    }

    if (locallyCompleted.isEmpty && locallyUnlocked.isEmpty) return incoming;

    return incoming.map((cap) {
      final mergedLicoes = cap.licoes.map((lic) {
        if (locallyCompleted.contains(lic.id)) {
          return lic.copyWith(status: LicaoStatus.concluida);
        }
        if (locallyUnlocked.contains(lic.id) && lic.status == LicaoStatus.bloqueada) {
          return lic.copyWith(status: LicaoStatus.disponivel);
        }
        return lic;
      }).toList();

      return cap.copyWith(licoes: mergedLicoes);
    }).toList();
  }

  // Bate na API pra trazer perfil do aluno, dias de ofensiva, conchas e lista de capítulos
  Future<void> _loadUserDataAndTrail() async {
    // Exibe loading se não houver capítulos carregados
    if (_capitulos.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      if (session != null) {
        final headers = {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        };

        // 1. Sincroniza dados vitais do usuário (perfil, variante ativa, stats) e status admin
        final checkUserReq = http.post(
          Uri.parse('$baseUrl/api/v1/auth/check-user'),
          headers: headers,
        ).timeout(const Duration(seconds: 6)).catchError((_) => http.Response('{}', 500));

        final adminReq = http.get(
          Uri.parse('$baseUrl/api/v1/admin/me'),
          headers: headers,
        ).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('{}', 500));

        final initResponses = await Future.wait([checkUserReq, adminReq]);
        final profileRes = initResponses[0];
        final adminRes = initResponses[1];

        if (profileRes.statusCode == 200) {
          try {
            final dynamic profileData = jsonDecode(utf8.decode(profileRes.bodyBytes));
            if (profileData is Map<String, dynamic>) {
              final varianteAtiva = profileData['variante_ativa'];
              if (varianteAtiva is Map<String, dynamic>) {
                final userVarId = (varianteAtiva['id'] as num?)?.toInt() ?? _varianteId;
                _varianteId = userVarId;
                _varianteNome = varianteAtiva['nome']?.toString() ?? _varianteNome;
              }
              if (mounted) {
                setState(() {
                  _xpTotal = (profileData['xp_total'] as num?)?.toInt() ?? 0;
                  _streakDays = (profileData['streak_atual'] as num?)?.toInt() ??
                      (profileData['dias_ofensiva'] as num?)?.toInt() ??
                      0;
                  _conchas = (profileData['conchas'] as num?)?.toInt() ?? 0;
                });
              }
            }
          } catch (_) {}
        }

        if (adminRes.statusCode == 200) {
          try {
            final dynamic adminData = jsonDecode(utf8.decode(adminRes.bodyBytes));
            if (adminData is Map<String, dynamic> && adminData['is_admin'] == true) {
              _isAdmin = true;
            }
          } catch (_) {}
        }

        // 2. Busca os capítulos da variante ativa calibrada do usuário
        final mapRes = await http.get(
          Uri.parse('$baseUrl/api/v1/trilha/$_varianteId/capitulos/'),
          headers: headers,
        ).timeout(const Duration(seconds: 8)).catchError((_) => http.Response('{}', 500));

        if (mapRes.statusCode == 200) {
          final String bodyStr = utf8.decode(mapRes.bodyBytes);
          await ApiCacheManager.instance.saveResponse('$baseUrl/api/v1/trilha/$_varianteId/capitulos/', bodyStr);
          final dynamic mapData = jsonDecode(bodyStr);
          if (mapData is Map<String, dynamic>) {
            _processMapData(mapData, isFromCache: false);
            Future.microtask(() {
              DashboardRepositoryImpl().getUserProgressStats();
              LanguageSwitcherBottomSheet.preloadVariantes();
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Falha ao carregar trilha: $e';
        });
      }
    }
  }

  /// Processa a carga de dados da trilha vinda do cache local ou da rede
  void _processMapData(Map<String, dynamic> mapData, {bool isFromCache = false}) {
    if (mapData['user_stats'] is Map<String, dynamic>) {
      final us = mapData['user_stats'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _xpTotal = (us['xp_total'] as num?)?.toInt() ?? 0;
          _streakDays = (us['streak_atual'] as num?)?.toInt() ??
              (us['dias_ofensiva'] as num?)?.toInt() ??
              0;
          _conchas = (us['conchas'] as num?)?.toInt() ?? 0;
        });
      }
    }

    final List<dynamic> capsJson = mapData['capitulos'] as List<dynamic>? ?? [];

    final loadedCapitulos = capsJson.map((cap) {
      final capMap = cap as Map<String, dynamic>? ?? {};
      final List<dynamic> licoesJson = capMap['licoes'] as List<dynamic>? ?? [];
      final licoes = licoesJson.map((l) {
        final lMap = l as Map<String, dynamic>? ?? {};
        return LicaoMapData(
          id: (lMap['id'] as num?)?.toInt() ?? 0,
          titulo: lMap['titulo']?.toString() ?? '',
          descricao: lMap['descricao']?.toString() ?? '',
          numero: (lMap['numero'] as num?)?.toInt() ?? 1,
          xpBase: (lMap['xp_base'] as num?)?.toInt() ?? 25,
          posX: (lMap['pos_x'] as num?)?.toDouble() ?? 50.0,
          posY: (lMap['pos_y'] as num?)?.toDouble() ?? 50.0,
          status: _parseLicaoStatus(lMap['status']?.toString() ?? 'bloqueada'),
          earnedXp: (lMap['earned_xp'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      final int capNum = (capMap['numero'] as num?)?.toInt() ?? 1;
      final double progressPct = (capMap['module_progress_percentage'] as num?)?.toDouble() ?? 0.0;

      ChestRewardMapData? chestReward;
      if (capMap['chest_reward'] != null) {
        final cr = capMap['chest_reward'] as Map<String, dynamic>;
        final statusStr = cr['status']?.toString() ?? 'bloqueado';
        final isCollected = cr['collected'] == true || statusStr == 'concluido';
        chestReward = ChestRewardMapData(
          milestoneIndex: (cr['milestone_index'] as num?)?.toInt() ?? 1,
          status: isCollected ? 'concluido' : statusStr,
          unlocked: cr['unlocked'] == true,
          collected: isCollected,
          recompensaXp: (cr['recompensa_xp'] as num?)?.toInt() ?? 75,
          recompensaConchas: (cr['recompensa_conchas'] as num?)?.toInt() ?? 50,
          afterLessonNumber: (cr['after_lesson_number'] as num?)?.toInt() ?? 2,
        );
      }

      return CapituloMapData(
        id: (capMap['id'] as num?)?.toInt() ?? 0,
        titulo: capMap['titulo']?.toString() ?? 'Capítulo $capNum',
        descricao: capMap['descricao']?.toString() ?? '',
        numero: capNum,
        paletteColor: _TupiColors.accent,
        licoes: licoes,
        chestReward: chestReward,
        moduleProgressPercentage: progressPct,
      );
    }).toList();

    final mergedCapitulos = _mergeCapitulosWithLocalProgress(_capitulos, loadedCapitulos);

    // Determina qual capítulo contém a lição ativa (disponível ou em andamento)
    int activeCapIdx = 0;
    for (int i = 0; i < mergedCapitulos.length; i++) {
      final hasActiveLesson = mergedCapitulos[i].licoes.any(
        (l) => l.status == LicaoStatus.disponivel || l.status == LicaoStatus.emAndamento,
      );
      if (hasActiveLesson) {
        activeCapIdx = i;
        break;
      }
    }

    final bool currentCapFinished = _selectedCapituloIndex < mergedCapitulos.length &&
        mergedCapitulos[_selectedCapituloIndex].licoes.isNotEmpty &&
        mergedCapitulos[_selectedCapituloIndex].licoes.every((l) => l.status == LicaoStatus.concluida);

    final bool shouldUpdateSelectedCap = _capitulos.isEmpty ||
        _selectedCapituloIndex >= mergedCapitulos.length ||
        currentCapFinished;

    if (mounted) {
      setState(() {
        _capitulos = mergedCapitulos;
        if (shouldUpdateSelectedCap) {
          _selectedCapituloIndex = activeCapIdx;
        }
        _isLoading = false;
      });
    }
  }

  // Converte a string de status vinda da API para o enum tipado da trilha
  LicaoStatus _parseLicaoStatus(String raw) {
    switch (raw) {
      case 'concluida': return LicaoStatus.concluida;
      case 'em_andamento': return LicaoStatus.emAndamento;
      case 'disponivel': return LicaoStatus.disponivel;
      default: return LicaoStatus.bloqueada;
    }
  }

  // Monta a tela principal com topbar persistente, alternância de abas e bottom bar
  @override
  Widget build(BuildContext context) {
    _initAnimControllers();
    final maxTabs = _isAdmin ? 5 : 4;
    final currentTab = _currentTabIndex < maxTabs ? _currentTabIndex : 0;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildGlobalTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _TupiColors.primary),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : IndexedStack(
                          index: currentTab,
                          children: [
                            TickerMode(
                              enabled: currentTab == 0,
                              child: RepaintBoundary(child: _buildTrilhaTab()),
                            ),
                            TickerMode(
                              enabled: currentTab == 1,
                              child: RepaintBoundary(child: _buildPraticaTab()),
                            ),
                            TickerMode(
                              enabled: currentTab == 2,
                              child: const RepaintBoundary(child: ProfileScreen()),
                            ),
                            TickerMode(
                              enabled: currentTab == 3,
                              child: const RepaintBoundary(child: SettingsScreen()),
                            ),
                            if (_isAdmin)
                              TickerMode(
                                enabled: currentTab == 4,
                                child: const RepaintBoundary(child: AdminScreen()),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Abre a Oca de Trocas com saldo de conchas e atualiza a carteira no retorno
  Future<void> _openStore() async {
    final updatedConchas = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => StoreScreen(initialConchas: _conchas),
      ),
    );
    if (updatedConchas != null && mounted) {
      setState(() {
        _conchas = updatedConchas;
      });
    }
  }

  // ─── Barra Superior Global ──────────────────────────────────────────────────
  // Barra superior com ofensiva, XP, conchas e botão de troca de idioma
  Widget _buildGlobalTopBar() {
    final bool isCustomThemesEnabled = featureFlagRepositoryInstance.isEnabled(FlagIds.customThemesEnabled);
    return TrailAppBar(
      varianteNome: _varianteNome,
      streakDays: _streakDays,
      conchas: _conchas,
      xpTotal: _xpTotal,
      showThemeToggle: isCustomThemesEnabled,
      onLanguageTap: () => _showLanguageSwitcher(context),
      onXpTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProgressDashboardScreen()),
      ),
      onThemeToggle: () => ThemeNotifier.instance.toggleTheme(context),
      onConchasTap: _openStore,
    );
  }

  // ─── ABA 1: TRILHA (Caminho Interativo de Aventura) ──────────────────────────
  Widget _buildTrilhaTab() {
    return TrailTabView(
      capitulos: _capitulos,
      selectedCapituloIndex: _selectedCapituloIndex,
      onSelectCapituloIndex: (idx) => setState(() => _selectedCapituloIndex = idx),
      pulseController: _pulseController,
      floatController: _floatController,
      onReloadTrail: _loadUserDataAndTrail,
      onCulturalGuideTap: (cap) => CulturalGuideDialog.show(context, cap),
      onLessonTap: _onLessonNodeTapped,
      onChestTap: (c, chest) => _openIndigenousChestModal(c, chest),
      onCollectedChestTap: (c, chest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _TupiColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Baú do Capítulo ${c.numero} já resgatado! (+${chest?.recompensaXp ?? 75} XP)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // Dispara o diálogo de abertura de baú de artefato e credita recompensas de XP e conchas
  void _openIndigenousChestModal(CapituloMapData cap, ChestRewardMapData chest) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: IndigenousArtifactChest(
          reward: IndigenousReward.sampleMuiraquita(),
          onCollected: () async {
            Navigator.pop(ctx);
            AudioManager.instance.playChestReward();

            // Marcação otimista imediata apenas no capítulo específico coletado
            setState(() {
              _capitulos = _capitulos.map((c) {
                if (c.id == cap.id && c.chestReward != null) {
                  return c.copyWith(
                    chestReward: ChestRewardMapData(
                      milestoneIndex: c.chestReward!.milestoneIndex,
                      status: 'concluido',
                      unlocked: c.chestReward!.unlocked,
                      collected: true,
                      recompensaXp: c.chestReward!.recompensaXp,
                      recompensaConchas: c.chestReward!.recompensaConchas,
                      afterLessonNumber: c.chestReward!.afterLessonNumber,
                    ),
                  );
                }
                return c;
              }).toList();
            });

            final session = Supabase.instance.client.auth.currentSession;
            final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

            try {
              if (session != null) {
                final response = await http.post(
                  Uri.parse('$baseUrl/api/v1/trilha/capitulo/${cap.id}/bau/${chest.milestoneIndex}/coletar/'),
                  headers: {
                    'Authorization': 'Bearer ${session.accessToken}',
                    'Content-Type': 'application/json',
                  },
                ).timeout(const Duration(seconds: 8));

                if (response.statusCode == 200) {
                  final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
                  final xpGanho = (data['recompensa_xp'] as num?)?.toInt() ?? 75;
                  final conchasGanho = (data['recompensa_conchas'] as num?)?.toInt() ?? 50;

                  setState(() {
                    _xpTotal = (data['xp_total'] as num?)?.toInt() ?? (_xpTotal + xpGanho);
                    _conchas += conchasGanho;
                  });

                  DashboardRepositoryImpl.invalidateCache();
                  AppProgressionNotifier.instance.notifyProgressUpdated(
                    xpGained: xpGanho,
                    conchasGained: conchasGanho,
                  );

                  _loadUserDataAndTrail();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _TupiColors.accent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Baú Coletado! +$xpGanho XP e +$conchasGanho Conchas sagradas.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return;
                } else if (response.statusCode == 409) {
                  // Baú já coletado - regra de abertura única
                  _loadUserDataAndTrail();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _TupiColors.textDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: const Row(
                          children: [
                            Icon(Icons.info_rounded, color: Colors.white70, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este baú já foi resgatado! Cada usuário pode abrir o baú da trilha apenas uma vez.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return;
                }
              }
            } catch (e) {
              debugPrint('Erro ao coletar baú: $e');
            }

            _loadUserDataAndTrail();
          },
        ),
      ),
    );
  }

  // Trata o toque em um nó de lição verificando se está bloqueada antes de abrir o modal
  void _onLessonNodeTapped(LicaoMapData licao) {
    if (licao.status == LicaoStatus.bloqueada) {
      if (!_isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _TupiColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Complete a Lição ${licao.numero - 1} para desbloquear "${licao.titulo}".',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Se for administrador, exibe aviso de bypass e prossegue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _TupiColors.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acesso Admin: Visualizando "${licao.titulo}" (bloqueada para alunos).',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Abre modal com detalhes da lição e inicia o player ao confirmar
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LessonStartModal(
        licao: licao,
        onStart: () async {
          Navigator.pop(ctx);
          final dynamic result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonPlayerScreen(licaoId: licao.id),
            ),
          );

          if (result != null && (result is Map<String, dynamic> || result == true)) {
            int? nextLicaoId;
            if (result is Map<String, dynamic>) {
              nextLicaoId = (result['proxima_licao_id'] as num?)?.toInt();
              final earnedXp = (result['earned_xp'] as num?)?.toInt() ?? 0;
              final totalXp = (result['xp_total'] as num?)?.toInt();
              final streak = (result['streak_atual'] as num?)?.toInt() ??
                  (result['dias_ofensiva'] as num?)?.toInt();
              if (totalXp != null && totalXp > 0) {
                _xpTotal = totalXp;
              } else if (earnedXp > 0) {
                _xpTotal += earnedXp;
              }
              if (streak != null && streak > 0) {
                _streakDays = streak;
              }
              final returnedVid = (result['variante_id'] as num?)?.toInt();
              if (returnedVid != null && returnedVid > 0) {
                _varianteId = returnedVid;
                if (result['variante_nome'] != null) {
                  _varianteNome = result['variante_nome'].toString();
                }
              }
            }
            _optimisticallyUnlockLesson(licao.id, unlockedNextLessonId: nextLicaoId);

            DashboardRepositoryImpl.invalidateCache();
            AppProgressionNotifier.instance.notifyProgressUpdated(
              completedLessonId: licao.id,
              unlockedLessonId: nextLicaoId,
              newStreak: _streakDays,
            );
          } else {
            DashboardRepositoryImpl.invalidateCache();
            AppProgressionNotifier.instance.notifyProgressUpdated();
          }
        },
      ),
    );
  }

  // Abre o bottomsheet para alternar a variante linguística indígena ativa
  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LanguageSwitcherBottomSheet(
        varianteIdAtiva: _varianteId,
        onVarianteSelected: (variante, precisaNivelar) {
          if (precisaNivelar) {
            setState(() {
              _varianteId = (variante['id'] as num).toInt();
              _varianteNome = variante['nome']?.toString() ?? 'Tupi Antigo';
              _capitulos = [];
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelectLevelScreen(variante: variante),
              ),
            ).then((_) => _loadUserDataAndTrail());
          } else {
            setState(() {
              _varianteId = (variante['id'] as num).toInt();
              _varianteNome = variante['nome']?.toString() ?? 'Tupi Antigo';
              _capitulos = [];
            });
            _loadUserDataAndTrail();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Idioma alterado para ${variante['nome']}!'),
                backgroundColor: _TupiColors.accent,
              ),
            );
          }
        },
      ),
    );
  }

  // ─── ABA 2: PRÁTICA (Hub de Treino e Revisão Espaçada) ────────────────────────
  Widget _buildPraticaTab() {
    return PracticeTabView(
      highestChapterReached: _highestChapterReached,
      vocabularyBank: _vocabularyBank,
      vocabCategoryFilter: _vocabCategoryFilter,
      onVocabCategoryChanged: (cat) => setState(() => _vocabCategoryFilter = cat),
      onStartFlashcardSession: _startFlashcardSession,
      onOpenThematicPractice: (tema, {temaId}) => _openThematicPractice(tema, temaId: temaId),
      onShowCustomThemeDialog: _showCustomThemeDialog,
    );
  }

  // Inicia diálogo interativo de flashcards com o vocabulário local
  void _startFlashcardSession() {
    showDialog(
      context: context,
      builder: (ctx) => FlashcardPracticeDialog(vocabulary: _vocabularyBank),
    );
  }

  // Navega para a tela de treino temático passando a variante e o tema selecionado
  Future<void> _openThematicPractice(String tema, {String? temaId, bool bypassCache = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThematicPracticeScreen(
          tema: tema,
          temaId: temaId,
          varianteId: _varianteId,
          varianteNome: _varianteNome,
          initialConchas: _conchas,
          bypassCache: bypassCache,
        ),
      ),
    );
    if (mounted) {
      _loadUserDataAndTrail();
    }
  }

  // Diálogo para o aluno digitar um tema livre e praticar com vocabulário contextualizado
  void _showCustomThemeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF0E5D4E), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tema Personalizado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha um assunto de interesse para praticar termos e vocabulários contextualizados:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ex: Constelações, Pesca, Pintura corporal...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final tema = controller.text.trim();
                if (tema.isNotEmpty) {
                  Navigator.pop(ctx);
                  _openThematicPractice(tema);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('INICIAR'),
            ),
          ],
        );
      },
    );
  }

  // Barra de navegação inferior com abas de Trilha, Prática, Perfil, Ajustes e Admin
  Widget _buildBottomNavigationBar() {
    return HomeBottomBar(
      currentTabIndex: _currentTabIndex,
      isAdmin: _isAdmin,
      onTabSelected: (index) {
        if (_currentTabIndex != index) {
          setState(() => _currentTabIndex = index);
          // Otimização de Clock e VRAM: Se saiu da Trilha (aba 0), para os tickers contínuos
          if (index == 0) {
            _pulseController?.repeat(reverse: true);
            _floatController?.repeat(reverse: true);
          } else {
            _pulseController?.stop();
            _floatController?.stop();
          }
        }
      },
    );
  }

  // Tela de erro com botão de recarregar caso a conexão falhe
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _TupiColors.primary, size: 54),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar a jornada.',
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserDataAndTrail,
              style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.primary),
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}


