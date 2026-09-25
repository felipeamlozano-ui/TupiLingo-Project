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
import 'package:tupi_lingo/features/historical_map/presentation/pages/pindorama_map_screen.dart';
import 'package:tupi_lingo/core/state/app_progression_notifier.dart';
import 'package:tupi_lingo/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tupi_lingo/features/historical_map/data/datasources/historical_map_remote_data_source.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/routing/predictive_preloading_engine.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/pratica/presentation/thematic_practice_screen.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/flashcard_practice_dialog.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/language_switcher_bottom_sheet.dart';
import 'package:tupi_lingo/features/home/presentation/widgets/trail_app_bar.dart';
import 'package:tupi_lingo/features/store/presentation/store_screen.dart';
import 'package:tupi_lingo/features/feature_flags/application/providers/feature_flag_provider.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/flag_ids.dart';
import 'widgets/chapter_banner_card.dart';
import 'widgets/home_bottom_bar.dart';
import 'widgets/lesson_start_modal.dart';
import 'widgets/trail_canvas_view.dart';

// Paleta de cores com identidade visual Tupi para a tela inicial
class _TupiColors {
  static const primary = Color(0xFFD08A45);
  static const accent = Color(0xFF0E5D4E);
  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF565D6D);
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

  // Vocabulário para o Hub de Prática
  final List<Map<String, String>> _vocabularyBank = [
    {'tupi': 'Kauê', 'pt': 'Olá / Salve', 'pronuncia': 'ka-u-Ê', 'cat': 'Saudações'},
    {'tupi': 'Abá', 'pt': 'Homem / Pessoa', 'pronuncia': 'a-BÁ', 'cat': 'Geral'},
    {'tupi': 'Kunhã', 'pt': 'Mulher', 'pronuncia': 'ku-NHÃ', 'cat': 'Geral'},
    {'tupi': 'Taba', 'pt': 'Aldeia', 'pronuncia': 'TA-ba', 'cat': 'Comunidade'},
    {'tupi': 'Jagûara', 'pt': 'Onça / Fera', 'pronuncia': 'ja-gwa-RA', 'cat': 'Fauna'},
    {'tupi': 'Pirá', 'pt': 'Peixe', 'pronuncia': 'pi-RÁ', 'cat': 'Fauna'},
    {'tupi': 'Gûyrá', 'pt': 'Pássaro / Ave', 'pronuncia': 'gwi-RÁ', 'cat': 'Fauna'},
    {'tupi': 'Tatu', 'pt': 'Tatu', 'pronuncia': 'ta-TU', 'cat': 'Fauna'},
    {'tupi': 'Y', 'pt': 'Água / Rio', 'pronuncia': 'Y (som gutural)', 'cat': 'Natureza'},
    {'tupi': 'Kûarasy', 'pt': 'Sol', 'pronuncia': 'kwa-ra-SY', 'cat': 'Natureza'},
    {'tupi': 'Jasy', 'pt': 'Lua', 'pronuncia': 'ja-SY', 'cat': 'Natureza'},
    {'tupi': 'Tatagûasu', 'pt': 'Fogo / Fogueira', 'pronuncia': 'ta-ta-gwa-SU', 'cat': 'Natureza'},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimControllers();
    _setupPredictivePreloading();
    _loadUserDataAndTrail();
    AppProgressionNotifier.instance.addListener(_onProgressionUpdated);
  }

  // Configura o preloader preditivo pra adiantar dados da lição em segundo plano
  void _setupPredictivePreloading() {
    PredictivePreloadingEngine.instance.setPreloadHandler((route, params) async {
      if (route == '/lesson' && params != null && params['licao_id'] != null) {
        final licaoId = params['licao_id'];
        final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
        try {
          final res = await ApiClient.get('$baseUrl/api/v1/trilha/licao/$licaoId/');
          if (res.statusCode == 200) {
            final data = jsonDecode(utf8.decode(res.bodyBytes));
            if (data['success'] == true) {
              PredictivePreloadingEngine.instance.storePreloadedData('licao_$licaoId', data);
              debugPrint('⚡ [HomeScreen Preload] Lição $licaoId pré-aquecida em memória (Zero Loading garantido).');
            }
          }
        } catch (_) {}
      }
    });
  }

  // Identifica a próxima lição liberada e já aquece em cache antes do clique
  void _preheatNextLesson() {
    for (final cap in _capitulos) {
      for (final lic in cap.licoes) {
        if (lic.status == LicaoStatus.disponivel || lic.status == LicaoStatus.emAndamento) {
          PredictivePreloadingEngine.instance.onRouteChanged(
            currentRoute: '/home',
            contextParams: {'licao_id': lic.id},
          );
          return;
        }
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
    // Silent background refresh se já houver capítulos carregados (zero spinner)
    if (_capitulos.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      int varianteId = _varianteId;

      if (session != null) {
        final headers = {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        };

        // Se ainda não carregamos capítulos (cold boot), sincroniza a variante ativa primeiro
        // para garantir que a trilha carregada corresponda à variante_ativa do usuário.
        if (_capitulos.isEmpty) {
          try {
            final checkUserRes = await http.post(
              Uri.parse('$baseUrl/api/v1/auth/check-user'),
              headers: headers,
            ).timeout(const Duration(seconds: 6));

            if (checkUserRes.statusCode == 200) {
              final dynamic profileData = jsonDecode(utf8.decode(checkUserRes.bodyBytes));
              if (profileData is Map<String, dynamic>) {
                final varianteAtiva = profileData['variante_ativa'];
                if (varianteAtiva is Map<String, dynamic>) {
                  _varianteId = (varianteAtiva['id'] as num?)?.toInt() ?? _varianteId;
                  _varianteNome = varianteAtiva['nome']?.toString() ?? _varianteNome;
                }
                _xpTotal = (profileData['xp_total'] as num?)?.toInt() ?? _xpTotal;
                _streakDays = (profileData['streak_atual'] as num?)?.toInt() ??
                    (profileData['dias_ofensiva'] as num?)?.toInt() ??
                    _streakDays;
                _conchas = (profileData['conchas'] as num?)?.toInt() ?? _conchas;
              }
            }
          } catch (_) {}
          varianteId = _varianteId;
        }

        // Dispara requisições em paralelo com Future.wait para máxima velocidade
        final checkUserReq = http.post(
          Uri.parse('$baseUrl/api/v1/auth/check-user'),
          headers: headers,
        ).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('{}', 500));

        final adminReq = http.get(
          Uri.parse('$baseUrl/api/v1/admin/me'),
          headers: headers,
        ).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('{}', 500));

        final mapReq = http.get(
          Uri.parse('$baseUrl/api/v1/trilha/$varianteId/capitulos/'),
          headers: headers,
        ).timeout(const Duration(seconds: 8)).catchError((_) => http.Response('{}', 500));

        final responses = await Future.wait([checkUserReq, adminReq, mapReq]);
        final profileRes = responses[0];
        final adminRes = responses[1];
        final mapRes = responses[2];

        // 1. Processa check-user
        if (profileRes.statusCode == 200) {
          try {
            final dynamic profileData = jsonDecode(utf8.decode(profileRes.bodyBytes));
            if (profileData is Map<String, dynamic>) {
              final varianteAtiva = profileData['variante_ativa'];
              if (varianteAtiva is Map<String, dynamic>) {
                final userVarId = (varianteAtiva['id'] as num?)?.toInt() ?? 1;
                // Se o check-user indicar uma variante diferente da que está em tela
                // (ex: após nivelamento ou troca de variante), atualiza a variante ativa
                // e recarrega os dados da trilha para essa variante imediatamente.
                if (_varianteId != userVarId) {
                  _varianteId = userVarId;
                  _varianteNome = varianteAtiva['nome']?.toString() ?? 'Tupi Antigo';
                  _capitulos = [];
                  if (mounted) {
                    setState(() {});
                    _loadUserDataAndTrail();
                  }
                  return;
                } else {
                  _varianteNome = varianteAtiva['nome']?.toString() ?? _varianteNome;
                }
              }
              if (mounted) {
                setState(() {
                  _xpTotal = (profileData['xp_total'] as num?)?.toInt() ?? _xpTotal;
                  _streakDays = (profileData['streak_atual'] as num?)?.toInt() ??
                      (profileData['dias_ofensiva'] as num?)?.toInt() ??
                      _streakDays;
                  _conchas = (profileData['conchas'] as num?)?.toInt() ?? _conchas;
                });
              }
            }
          } catch (_) {}
        }

        // 1.1 Processa admin
        if (adminRes.statusCode == 200) {
          try {
            final dynamic adminData = jsonDecode(utf8.decode(adminRes.bodyBytes));
            if (adminData is Map<String, dynamic> && adminData['is_admin'] == true) {
              _isAdmin = true;
            }
          } catch (_) {}
        }

        // 2. Processa capítulos e lições da trilha
        if (mapRes.statusCode == 200) {
          final dynamic mapData = jsonDecode(utf8.decode(mapRes.bodyBytes));
          if (mapData is Map<String, dynamic>) {
            if (mapData['user_stats'] is Map<String, dynamic>) {
              final us = mapData['user_stats'] as Map<String, dynamic>;
              if (mounted) {
                setState(() {
                  _xpTotal = (us['xp_total'] as num?)?.toInt() ?? _xpTotal;
                  _streakDays = (us['streak_atual'] as num?)?.toInt() ??
                      (us['dias_ofensiva'] as num?)?.toInt() ??
                      _streakDays;
                  _conchas = (us['conchas'] as num?)?.toInt() ?? _conchas;
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
              _preheatNextLesson();
              // Pré-aquecimento do Painel de Desempenho, Mapa e Variantes em background (Zero Loading no 1º clique)
              Future.microtask(() {
                DashboardRepositoryImpl().getUserProgressStats();
                HistoricalMapRemoteDataSourceImpl().fetchRegions();
                LanguageSwitcherBottomSheet.preloadVariantes();
              });
              return;
            }
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
                          index: _currentTabIndex < (_isAdmin ? 4 : 3) ? _currentTabIndex : 0,
                          children: [
                            _buildTrilhaTab(),
                            _buildPraticaTab(),
                            const ProfileScreen(),
                            if (_isAdmin) const AdminScreen(),
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
      onMapTap: _showInteractiveMapModal,
      onConchasTap: _openStore,
    );
  }

  // ─── ABA 1: TRILHA (Caminho Interativo de Aventura) ──────────────────────────
  // Aba principal com o caminho vertical da trilha e seletor de capítulos
  Widget _buildTrilhaTab() {
    if (_capitulos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Nenhum capítulo publicado para esta variante.',
                style: TextStyle(color: _TupiColors.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadUserDataAndTrail,
              style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.primary),
              child: const Text('Recarregar Trilha'),
            ),
          ],
        ),
      );
    }

    final safeIndex = (_selectedCapituloIndex >= 0 && _selectedCapituloIndex < _capitulos.length)
        ? _selectedCapituloIndex
        : 0;
    final cap = _capitulos[safeIndex];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Seletor de Capítulos
            _buildChapterTabsHeader(),
            const SizedBox(height: 14),

            // Card Principal da Unidade / Capítulo (Banner TupiLingo)
            ChapterBannerCard(
              cap: cap,
              onCulturalGuideTap: () => _showCulturalGuideDialog(cap),
            ),
            const SizedBox(height: 24),

            // O Caminho de Lições Serpenteante
            TrailCanvasView(
              cap: cap,
              isCurrentActiveChapter: (safeIndex < _capitulos.length && _capitulos[safeIndex].id == cap.id),
              pulseController: _pulseController,
              floatController: _floatController,
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
                        const Text('✨', style: TextStyle(fontSize: 18)),
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
            ),
          ],
        ),
      ),
    );
  }

  // Pílulas horizontais navegáveis com os capítulos disponíveis da variante
  Widget _buildChapterTabsHeader() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _capitulos.length,
        itemBuilder: (context, i) {
          final isSelected = i == _selectedCapituloIndex;
          final cap = _capitulos[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedCapituloIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _TupiColors.primary : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected ? _TupiColors.primary : AppTheme.border(context),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _TupiColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Capítulo ${cap.numero}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
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

            // Marcação otimista imediata para prevenir múltiplos cliques locais
            setState(() {
              _capitulos = _capitulos.map((c) {
                if (c.chestReward != null) {
                  return CapituloMapData(
                    id: c.id,
                    titulo: c.titulo,
                    descricao: c.descricao,
                    numero: c.numero,
                    paletteColor: c.paletteColor,
                    licoes: c.licoes,
                    chestReward: ChestRewardMapData(
                      milestoneIndex: c.chestReward!.milestoneIndex,
                      status: 'concluido',
                      unlocked: c.chestReward!.unlocked,
                      collected: true,
                      recompensaXp: c.chestReward!.recompensaXp,
                      recompensaConchas: c.chestReward!.recompensaConchas,
                      afterLessonNumber: c.chestReward!.afterLessonNumber,
                    ),
                    moduleProgressPercentage: c.moduleProgressPercentage,
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
                            const Text('✨', style: TextStyle(fontSize: 20)),
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
                            Text('🛡️', style: TextStyle(fontSize: 20)),
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

  // Abre o mapa histórico interativo do Pindorama com as aldeias ancestrais
  void _showInteractiveMapModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PindoramaMapScreen(),
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
                const Text('🔒', style: TextStyle(fontSize: 18)),
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
              const Text('🛡️', style: TextStyle(fontSize: 18)),
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

  // Exibe modal com contexto cultural, etnográfico e saberes tradicionais do capítulo
  void _showCulturalGuideDialog(CapituloMapData cap) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        title: Row(
          children: [
            const Text('📜', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Guia do Capítulo ${cap.numero}',
                style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cap.titulo,
                style: const TextStyle(color: _TupiColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                'No Tupi Antigo, a fala expressava conexão íntima com a terra e com os ancestrais. '
                'As palavras tinham sonoridade rica em vogais nasais e guturais (como o som de "Y"). '
                'Pratique os termos e preste atenção aos animais sagrados da floresta.',
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendi',
              style: TextStyle(
                color: AppTheme.isDark(context) ? const Color(0xFF1EC9A5) : _TupiColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
                content: Text('Idioma alterado para ${variante['nome']}! 🌿'),
                backgroundColor: _TupiColors.accent,
              ),
            );
          }
        },
      ),
    );
  }

  // ─── ABA 2: PRÁTICA (Hub de Treino e Revisão Espaçada) ────────────────────────
  // Hub de prática com cards de treino diário, flashcards e módulos temáticos
  Widget _buildPraticaTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text(
              'Centro de Prática Ancestral',
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fortaleça sua memória com treinos rápidos e revisão espaçada.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Card Destaque: Revisão Diária SM-2
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E5D4E), Color(0xFF094338)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _TupiColors.accent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🧠', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revisão Espaçada',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '4 palavras prontas para fixação hoje',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startFlashcardSession(),
                      icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                      label: const Text('PRATICAR AGORA (+15 XP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _TupiColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Treino Temático com IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Treino Inteligente ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pratique com questões contextualizadas usando o acervo histórico primário.',
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Carrossel/Cards de Temas Interativos
            _buildThematicPracticeSection(),

            const SizedBox(height: 24),
            Text(
              'Banco de Vocabulário da Trilha',
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Lista de Vocabulário Interativa
            ..._vocabularyBank.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _TupiColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('🌿', style: TextStyle(fontSize: 20)),
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
                                item['tupi']!,
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '[${item['pronuncia']!}]',
                                style: TextStyle(color: AppTheme.textSecondary(context).withValues(alpha: 0.7), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['pt']!,
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['cat']!,
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Inicia diálogo interativo de flashcards com o vocabulário local
  void _startFlashcardSession() {
    showDialog(
      context: context,
      builder: (ctx) => FlashcardPracticeDialog(vocabulary: _vocabularyBank),
    );
  }

  // Grade horizontal de temas (Natureza, Animais, Mitologia, etc.) gerados dinamicamente
  Widget _buildThematicPracticeSection() {
    final themes = [
      {'id': 'natureza', 'titulo': 'Natureza e Rios', 'icone': '🌿', 'desc': 'Águas, matas e cosmos', 'xp': 20, 'conchas': 3},
      {'id': 'animais', 'titulo': 'Animais e Caça', 'icone': '🐆', 'desc': 'Onças, aves e fauna', 'xp': 20, 'conchas': 3},
      {'id': 'mitologia', 'titulo': 'Mitologia e Tupã', 'icone': '⚡', 'desc': 'Entidades e cosmologia', 'xp': 25, 'conchas': 4},
      {'id': 'aldeia', 'titulo': 'Aldeia e Cotidiano', 'icone': '🏡', 'desc': 'Oka, taba e comunidade', 'xp': 20, 'conchas': 3},
      {'id': 'guerra', 'titulo': 'Guerra e Rituais', 'icone': '🏹', 'desc': 'Armas, chefias e cantos', 'xp': 25, 'conchas': 4},
      {'id': 'culinaria', 'titulo': 'Culinária e Roça', 'icone': '🍲', 'desc': 'Mandioca, cauim e peixes', 'xp': 20, 'conchas': 3},
    ];

    return Column(
      children: [
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final t = themes[idx];
              return InkWell(
                onTap: () => _openThematicPractice(t['titulo'] as String, temaId: t['id'] as String),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 165,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t['icone'] as String, style: const TextStyle(fontSize: 24)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD08A45).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${t['xp']} XP',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['titulo'] as String,
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t['desc'] as String,
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCustomThemeDialog,
            icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0E5D4E)),
            label: const Text(
              'DIGITAR TEMA PERSONALIZADO...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0E5D4E), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
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

  // Diálogo para o aluno digitar um tema livre e gerar treino por inteligência artificial
  void _showCustomThemeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🏹 ', style: TextStyle(fontSize: 22)),
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
                  'Escolha qualquer assunto. A inteligência da aldeia buscará os saberes e vocabulários adequados:',
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

  // Barra de navegação inferior com abas de Trilha, Prática, Perfil e Admin
  Widget _buildBottomNavigationBar() {
    return HomeBottomBar(
      currentTabIndex: _currentTabIndex,
      isAdmin: _isAdmin,
      onTabSelected: (index) => setState(() => _currentTabIndex = index),
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


