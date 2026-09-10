import 'dart:convert';
import 'dart:math' as math;
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
import 'package:tupi_lingo/features/historical_map/presentation/widgets/lazy_map_loader.dart';
import 'package:tupi_lingo/core/state/app_progression_notifier.dart';
import 'package:tupi_lingo/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/routing/predictive_preloading_engine.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

/// Paleta de Cores com Identidade Visual Tupi Ancestral
class _TupiColors {
  static const backgroundSecondary = Color(0xFFEAE7DC); // Areia suave de contraste
  static const surfaceCard = Colors.white;            // Cards em branco puro
  static const surfaceCardLight = Color(0xFFFAF9F5);
  static const primary = Color(0xFFD08A45);           // Âmbar / Terracota Tupi (Ação principal)
  static const primaryDark = Color(0xFFA56627);       // Borda 3D botão terracota
  static const accent = Color(0xFF0E5D4E);            // Verde Floresta Profundo (Ancestral)
  static const accentDark = Color(0xFF083C32);        // Borda 3D botão verde
  static const textDark = Color(0xFF1F2937);          // Texto principal escuro (alto contraste)
  static const textMuted = Color(0xFF565D6D);         // Subtítulos e textos secundários (AppColors.subtitle)
  static const border = Color(0xFFD0D0D0);            // Bordas padrão do app (AppColors.inputBorder)
  static const nodeLocked = Color(0xFFE2DFD4);        // Pedra clara para nós bloqueados
  static const nodeLockedBorder = Color(0xFFC7C3B6);  // Borda 3D nó bloqueado
  static const xpColor = Color(0xFFD08A45);           // Âmbar/Dourado Tupi
  static const streakColor = Color(0xFFE05638);       // Fogo da Ofensiva
  static const shellColor = Color(0xFF0E5D4E);        // Conchas / Moedas do Pindorama
}

enum LicaoStatus { bloqueada, disponivel, emAndamento, concluida }

class LicaoMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final int xpBase;
  final double posX;
  final double posY;
  final LicaoStatus status;
  final int earnedXp;

  const LicaoMapData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.numero,
    required this.xpBase,
    required this.posX,
    required this.posY,
    required this.status,
    this.earnedXp = 0,
  });

  LicaoMapData copyWith({
    int? id,
    String? titulo,
    String? descricao,
    int? numero,
    int? xpBase,
    double? posX,
    double? posY,
    LicaoStatus? status,
    int? earnedXp,
  }) {
    return LicaoMapData(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      numero: numero ?? this.numero,
      xpBase: xpBase ?? this.xpBase,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      status: status ?? this.status,
      earnedXp: earnedXp ?? this.earnedXp,
    );
  }
}

class ChestRewardMapData {
  final int milestoneIndex;
  final String status; // 'bloqueado', 'disponivel', 'concluido'
  final bool unlocked;
  final bool collected;
  final int recompensaXp;
  final int recompensaConchas;
  final int afterLessonNumber;

  const ChestRewardMapData({
    required this.milestoneIndex,
    required this.status,
    required this.unlocked,
    required this.collected,
    required this.recompensaXp,
    required this.recompensaConchas,
    required this.afterLessonNumber,
  });
}

class CapituloMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final Color paletteColor;
  final List<LicaoMapData> licoes;
  final ChestRewardMapData? chestReward;
  final double moduleProgressPercentage;

  const CapituloMapData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.numero,
    required this.paletteColor,
    required this.licoes,
    this.chestReward,
    this.moduleProgressPercentage = 0.0,
  });

  CapituloMapData copyWith({
    int? id,
    String? titulo,
    String? descricao,
    int? numero,
    Color? paletteColor,
    List<LicaoMapData>? licoes,
    ChestRewardMapData? chestReward,
    double? moduleProgressPercentage,
  }) {
    return CapituloMapData(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      numero: numero ?? this.numero,
      paletteColor: paletteColor ?? this.paletteColor,
      licoes: licoes ?? this.licoes,
      chestReward: chestReward ?? this.chestReward,
      moduleProgressPercentage: moduleProgressPercentage ?? this.moduleProgressPercentage,
    );
  }
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

  void _onProgressionUpdated() {
    if (mounted) {
      _loadUserDataAndTrail();
    }
  }

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
                // Preservação estrita da variante: só adota a variante do check-user
                // se a lista de capítulos estiver vazia (cold boot inicial).
                // Caso contrário, respeita a variante que o usuário está ativamente cursando.
                if (_capitulos.isEmpty) {
                  _varianteId = userVarId;
                  _varianteNome = varianteAtiva['nome']?.toString() ?? 'Tupi Antigo';
                } else if (_varianteId == userVarId) {
                  _varianteNome = varianteAtiva['nome']?.toString() ?? _varianteNome;
                }
              }
              _xpTotal = (profileData['xp_total'] as num?)?.toInt() ?? _xpTotal;
              _streakDays = (profileData['streak_atual'] as num?)?.toInt() ??
                  (profileData['dias_ofensiva'] as num?)?.toInt() ??
                  _streakDays;
              _conchas = (profileData['conchas'] as num?)?.toInt() ?? _conchas;
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
              _xpTotal = (us['xp_total'] as num?)?.toInt() ?? _xpTotal;
              _streakDays = (us['streak_atual'] as num?)?.toInt() ??
                  (us['dias_ofensiva'] as num?)?.toInt() ??
                  _streakDays;
              _conchas = (us['conchas'] as num?)?.toInt() ?? _conchas;
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

            if (mounted) {
              setState(() {
                _capitulos = mergedCapitulos;
                _isLoading = false;
              });
              _preheatNextLesson();
              // Pré-aquecimento do Painel de Desempenho em background (Zero Loading no 1º clique)
              Future.microtask(() => DashboardRepositoryImpl().getUserProgressStats());
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

  LicaoStatus _parseLicaoStatus(String raw) {
    switch (raw) {
      case 'concluida': return LicaoStatus.concluida;
      case 'em_andamento': return LicaoStatus.emAndamento;
      case 'disponivel': return LicaoStatus.disponivel;
      default: return LicaoStatus.bloqueada;
    }
  }

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

  // ─── Barra Superior Global ──────────────────────────────────────────────────
  Widget _buildGlobalTopBar() {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Variante Ativa Badge com Seletor de Idioma
          Flexible(
            child: GestureDetector(
              onTap: () => _showLanguageSwitcher(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _varianteNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Métricas de Gamificação: Ofensiva, Conchas, XP + Atalhos Interativos
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopStat(icon: '🔥', label: '$_streakDays', color: _TupiColors.streakColor),
              const SizedBox(width: 5),
              _buildTopStat(icon: '🐚', label: '$_conchas', color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.shellColor),
              const SizedBox(width: 5),
              // Toque no XP abre o Dashboard de Progresso 3D
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProgressDashboardScreen()),
                ),
                child: _buildTopStat(icon: '⭐', label: '$_xpTotal', color: _TupiColors.xpColor),
              ),
              const SizedBox(width: 5),
              // Botão de alternância rápida de Tema Ancestral (Sol / Lua)
              GestureDetector(
                onTap: () => ThemeNotifier.instance.toggleTheme(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 5),
              // Botão do Mapa Interativo de Aldeias
              GestureDetector(
                onTap: _showInteractiveMapModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text('🗺️', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({required String icon, required String label, required Color color}) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ABA 1: TRILHA (Caminho Interativo de Aventura) ──────────────────────────
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
            _buildChapterBannerCard(cap),
            const SizedBox(height: 24),

            // O Caminho de Lições Serpenteante
            _buildWindingLessonPath(cap),
          ],
        ),
      ),
    );
  }

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

  Widget _buildChapterBannerCard(CapituloMapData cap) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5D4E), Color(0xFF134E41)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5D4E).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAPÍTULO ${cap.numero} • UNIDADE BÁSICA',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => _showCulturalGuideDialog(cap),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📜', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Guia Cultural',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cap.titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cap.descricao,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // Barra de progresso real do capítulo
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (cap.moduleProgressPercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD166)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${cap.moduleProgressPercentage.toInt()}%',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói o caminho de lições ondulado verticalmente com baú cultural
  Widget _buildWindingLessonPath(CapituloMapData cap) {
    final licoes = cap.licoes;
    if (licoes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Nenhuma lição neste capítulo.', style: TextStyle(color: _TupiColors.textMuted)),
        ),
      );
    }

    // Padrão de zigue-zague harmônico para os botões (-0.5 = esq, 0.0 = centro, 0.5 = dir)
    final offsets = [0.0, -0.45, 0.45, 0.0, -0.45, 0.45];

    // Localiza a lição prioritária que o aluno deve fazer agora
    final targetIndex = licoes.indexWhere(
      (l) => l.status == LicaoStatus.disponivel || l.status == LicaoStatus.emAndamento,
    );

    return Column(
      children: List.generate(licoes.length, (index) {
        final licao = licoes[index];
        final dx = offsets[index % offsets.length];

        final isTarget = (index == targetIndex);
        final isInProgress = licao.status == LicaoStatus.emAndamento;

        return Column(
          children: [
            if (index > 0) _buildTrailConnector(index),

            // Nó da Lição com posicionamento ondulado
            Align(
              alignment: Alignment(dx, 0),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Aura pulsante radiante isolada por RepaintBoundary para fluidez 120 FPS
                  if (isTarget && _pulseController != null)
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulseController!,
                        builder: (context, _) {
                          final val = _pulseController?.value ?? 0.0;
                          return Container(
                            width: 86 + (val * 18),
                            height: 86 + (val * 18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFB300).withValues(alpha: 0.32 - (val * 0.18)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD54F).withValues(alpha: 0.40 - (val * 0.20)),
                                  blurRadius: 18 + (val * 8),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  // Balãozinho de destaque "SUA VEZ / CONTINUAR" flutuante animado
                  if (isTarget && _floatController != null)
                    Positioned(
                      top: -36,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _floatController!,
                          builder: (context, _) {
                            final val = _floatController?.value ?? 0.0;
                            final dy = math.sin(val * math.pi) * 3.5;
                            return Transform.translate(
                              offset: Offset(0, dy),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0E5D4E), Color(0xFF1B4332)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFFD166), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD166).withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(isInProgress ? '⚡ ' : '✨ ', style: const TextStyle(fontSize: 11)),
                                    Text(
                                      isInProgress ? 'CONTINUAR' : 'SUA VEZ',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD166),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Botão 3D Tátil com suporte a destaque e brilho
                  _build3DNodeButton(licao, isTarget: isTarget),
                ],
              ),
            ),

            // Se for após a Lição 2, insere o baú de recompensa cultural do capítulo
            if (index == 1 && licoes.length > 2) ...[
              const SizedBox(height: 16),
              _buildTrailConnector(99),
              _buildChestRewardNode(cap, cap.chestReward),
            ],
          ],
        );
      }),
    );
  }

  Widget _build3DNodeButton(LicaoMapData licao, {bool isTarget = false}) {
    final isCompleted = licao.status == LicaoStatus.concluida;
    final isInProgress = licao.status == LicaoStatus.emAndamento;
    final isAvailable = licao.status == LicaoStatus.disponivel;
    final isPlayable = isAvailable || isInProgress;
    final isLocked = licao.status == LicaoStatus.bloqueada;

    Widget iconWidget;
    Gradient? bgGradient;
    Color? solidColor;
    Color bottomColor;
    List<BoxShadow> shadows;

    final isDark = AppTheme.isDark(context);

    if (isCompleted) {
      solidColor = isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent;
      bottomColor = isDark ? const Color(0xFF0E6955) : _TupiColors.accentDark;
      iconWidget = const Text('👑', style: TextStyle(fontSize: 28));
      shadows = [
        BoxShadow(
          color: (isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent).withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isTarget) {
      // 🌟 LIÇÃO QUE ELE DEVE FAZER: Super brilhante, dourada radiante, efeito glossy
      bgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFDF70), // Dourado brilhante no topo
          Color(0xFFFFB300), // Ouro vivo
          Color(0xFFF57C00), // Âmbar solar na base
        ],
      );
      bottomColor = const Color(0xFFC67D00);
      iconWidget = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 32)),
          Positioned(
            right: -6,
            top: -4,
            child: const Text('✨', style: TextStyle(fontSize: 14)),
          ),
        ],
      );
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFB300).withValues(alpha: 0.60),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.40),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (isPlayable) {
      // Outra lição disponível ou em andamento (não é a lição alvo primária)
      solidColor = _TupiColors.primary;
      bottomColor = _TupiColors.primaryDark;
      iconWidget = Text(isInProgress ? '🏹' : '⭐', style: const TextStyle(fontSize: 28));
      shadows = [
        BoxShadow(
          color: _TupiColors.primary.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      // Bloqueada: pedra clara ou obsidiana escura com cadeado
      solidColor = isDark ? const Color(0xFF19231F) : _TupiColors.nodeLocked;
      bottomColor = isDark ? const Color(0xFF23322C) : _TupiColors.nodeLockedBorder;
      iconWidget = Icon(Icons.lock_rounded, color: AppTheme.textSecondary(context), size: 26);
      shadows = [
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFC7C3B6).withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    }

    return GestureDetector(
      onTap: () => _onLessonNodeTapped(licao),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: solidColor,
              gradient: bgGradient,
              border: Border(
                bottom: BorderSide(color: bottomColor, width: 6),
              ),
              boxShadow: shadows,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Reflexo glossy curvo (efeito botão vítreo brilhante 3D)
                if (isTarget || isPlayable)
                  Positioned(
                    top: 4,
                    left: 10,
                    right: 10,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: isTarget ? 0.70 : 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Center(child: iconWidget),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isTarget ? const Color(0xFFFFB300) : AppTheme.border(context),
                width: isTarget ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTarget
                      ? const Color(0xFFFFB300).withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              licao.titulo,
              style: TextStyle(
                color: isLocked
                    ? AppTheme.textSecondary(context)
                    : isTarget
                        ? const Color(0xFFFFB300)
                        : AppTheme.textPrimary(context),
                fontSize: 11,
                fontWeight: isTarget ? FontWeight.w900 : FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailConnector(int index) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: 6,
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF263833) : const Color(0xFFDCD8CB),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildChestRewardNode(CapituloMapData cap, ChestRewardMapData? chest) {
    final status = chest?.status ?? 'bloqueado';
    final isUnlocked = status == 'disponivel';
    final isCollected = status == 'concluido';
    final isDark = AppTheme.isDark(context);

    Color bgColor;
    Border border;
    List<BoxShadow> shadows;
    Widget icon;
    String badgeText;

    if (isCollected) {
      bgColor = isDark ? const Color(0xFF172420) : const Color(0xFFFAF9F5);
      border = Border.all(color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent, width: 2.5);
      shadows = [
        BoxShadow(
          color: (isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent).withValues(alpha: 0.2),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
      icon = const Text('✨', style: TextStyle(fontSize: 26));
      badgeText = 'COLETADO';
    } else if (isUnlocked) {
      bgColor = AppTheme.surface(context);
      border = Border.all(color: _TupiColors.xpColor, width: 3);
      shadows = [
        BoxShadow(
          color: _TupiColors.xpColor.withValues(alpha: 0.45),
          blurRadius: 14,
          spreadRadius: 3,
        ),
      ];
      icon = const Text('🏺', style: TextStyle(fontSize: 28));
      badgeText = 'ABRIR BAÚ';
    } else {
      bgColor = isDark ? const Color(0xFF19231F) : _TupiColors.nodeLocked;
      border = Border.all(color: isDark ? const Color(0xFF23322C) : _TupiColors.nodeLockedBorder, width: 2);
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
      icon = const Text('🔒', style: TextStyle(fontSize: 22));
      badgeText = 'BLOQUEADO';
    }

    return GestureDetector(
      onTap: () {
        if (isCollected) {
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
                      'Baú do Capítulo ${cap.numero} já resgatado! (+${chest?.recompensaXp ?? 75} XP)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (isUnlocked) {
          _openIndigenousChestModal(cap, chest!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _TupiColors.textDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: const Row(
                children: [
                  Text('🔒', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conclua as lições anteriores do capítulo para abrir este baú cultural.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Column(
        children: [
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: border,
                boxShadow: shadows,
              ),
              child: Center(child: icon),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCollected
                  ? _TupiColors.accent.withValues(alpha: 0.15)
                  : isUnlocked
                      ? _TupiColors.primary.withValues(alpha: 0.2)
                      : const Color(0xFFE2DFD4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: isCollected
                    ? _TupiColors.accent
                    : isUnlocked
                        ? _TupiColors.primaryDark
                        : _TupiColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  void _showInteractiveMapModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFFF3F2E8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: LazyHistoricalMapLoader(
                capitulos: _capitulos,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    // Abre BottomSheet de Início da Lição
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildLessonModal(licao),
    );
  }

  Widget _buildLessonModal(LicaoMapData licao) {
    final isCompleted = licao.status == LicaoStatus.concluida;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: _TupiColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: _TupiColors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text(isCompleted ? '👑' : '🏹', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIÇÃO ${licao.numero}',
                      style: const TextStyle(
                        color: _TupiColors.xpColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      licao.titulo,
                      style: const TextStyle(
                        color: _TupiColors.textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            licao.descricao,
            style: const TextStyle(color: _TupiColors.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Recompensas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _TupiColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _TupiColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '+${licao.xpBase} XP',
                      style: const TextStyle(
                        color: _TupiColors.xpColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('🐚', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Text(
                      '+10 Conchas',
                      style: TextStyle(
                        color: _TupiColors.shellColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão Grande Começar
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final dynamic result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonPlayerScreen(licaoId: licao.id),
                ),
              );

              // Atualização otimista instantânea (0ms) na interface
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
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? _TupiColors.accent : _TupiColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
            ),
            child: Text(
              isCompleted
                  ? 'REVISAR LIÇÃO'
                  : licao.status == LicaoStatus.emAndamento
                      ? 'CONTINUAR LIÇÃO'
                      : 'COMEÇAR LIÇÃO',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showCulturalGuideDialog(CapituloMapData cap) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _TupiColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('📜', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Guia do Capítulo ${cap.numero}',
                style: const TextStyle(color: _TupiColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cap.titulo,
              style: const TextStyle(color: _TupiColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            const Text(
              'No Tupi Antigo, a fala expressava conexão íntima com a terra e com os ancestrais. '
              'As palavras tinham sonoridade rica em vogais nasais e guturais (como o som de "Y"). '
              'Pratique os termos e preste atenção aos animais sagrados da floresta.',
              style: TextStyle(color: _TupiColors.textDark, fontSize: 13, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(color: _TupiColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LanguageSwitcherBottomSheet(
        varianteIdAtiva: _varianteId,
        onVarianteSelected: (variante, precisaNivelar) {
          if (precisaNivelar) {
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
  Widget _buildPraticaTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text(
              'Centro de Prática Ancestral 🏹',
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
                              'Revisão Espaçada (SM-2)',
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

  void _startFlashcardSession() {
    showDialog(
      context: context,
      builder: (ctx) => _FlashcardPracticeDialog(vocabulary: _vocabularyBank),
    );
  }

  // ─── Barra de Navegação Inferior (BottomNavigationBar) ───────────────────────
  Widget _buildBottomNavigationBar() {
    final maxTabs = _isAdmin ? 4 : 3;
    final safeIndex = _currentTabIndex < maxTabs ? _currentTabIndex : 0;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        selectedItemColor: isDark ? const Color(0xFFE69A56) : _TupiColors.primary,
        unselectedItemColor: AppTheme.textSecondary(context),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_rounded),
            activeIcon: Icon(Icons.explore_rounded, color: isDark ? const Color(0xFFE69A56) : _TupiColors.primary),
            label: 'Trilha',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center_rounded),
            activeIcon: Icon(Icons.fitness_center_rounded, color: isDark ? const Color(0xFF1EC9A5) : _TupiColors.accent),
            label: 'Prática',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded, color: isDark ? const Color(0xFFE69A56) : _TupiColors.primary),
            label: 'Perfil',
          ),
          if (_isAdmin)
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              activeIcon: Icon(Icons.admin_panel_settings_rounded, color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)),
              label: 'Admin',
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _TupiColors.primary, size: 54),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar a jornada.',
              style: TextStyle(color: _TupiColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: const TextStyle(color: _TupiColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserDataAndTrail,
              style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.primary),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo Interativo de Flashcards (Treino Rápido) ──────────────────────────
class _FlashcardPracticeDialog extends StatefulWidget {
  final List<Map<String, String>> vocabulary;
  const _FlashcardPracticeDialog({required this.vocabulary});

  @override
  State<_FlashcardPracticeDialog> createState() => _FlashcardPracticeDialogState();
}

class _FlashcardPracticeDialogState extends State<_FlashcardPracticeDialog> {
  int _currentIndex = 0;
  bool _revealed = false;
  int _reviewedCount = 0;

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.vocabulary.length) {
      return AlertDialog(
        backgroundColor: _TupiColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Revisão Concluída!',
              style: TextStyle(color: _TupiColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Você revisou $_reviewedCount palavras ancestrais com sucesso.',
              style: const TextStyle(color: _TupiColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.accent),
              child: const Text('Concluir (+15 XP)'),
            ),
          ],
        ),
      );
    }

    final item = widget.vocabulary[_currentIndex];

    return AlertDialog(
      backgroundColor: _TupiColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Palavra ${_currentIndex + 1}/${widget.vocabulary.length}',
            style: const TextStyle(color: _TupiColors.textMuted, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: _TupiColors.textMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _revealed = !_revealed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _TupiColors.surfaceCardLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _revealed ? _TupiColors.accent : _TupiColors.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['tupi']!,
                    style: const TextStyle(
                      color: _TupiColors.textDark,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '[${item['pronuncia']!}]',
                    style: const TextStyle(color: _TupiColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_revealed)
                    Text(
                      item['pt']!,
                      style: const TextStyle(
                        color: _TupiColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Toque para ver a tradução',
                      style: TextStyle(color: _TupiColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex++;
                      _revealed = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _TupiColors.textMuted,
                    side: const BorderSide(color: _TupiColors.border),
                  ),
                  child: const Text('Rever Depois'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _reviewedCount++;
                      _currentIndex++;
                      _revealed = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.accent),
                  child: const Text('Acertei!'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── BottomSheet Seletor de Idioma / Variante ──────────────────────────────────
class _LanguageSwitcherBottomSheet extends StatefulWidget {
  final int varianteIdAtiva;
  final Function(Map<String, dynamic> variante, bool precisaNivelar) onVarianteSelected;

  const _LanguageSwitcherBottomSheet({
    required this.varianteIdAtiva,
    required this.onVarianteSelected,
  });

  @override
  State<_LanguageSwitcherBottomSheet> createState() => _LanguageSwitcherBottomSheetState();
}

class _LanguageSwitcherBottomSheetState extends State<_LanguageSwitcherBottomSheet> {
  bool _isLoading = true;
  int? _updatingVarianteId;
  String? _error;
  List<Map<String, dynamic>> _variantes = [];

  @override
  void initState() {
    super.initState();
    _fetchVariantes();
  }

  Future<void> _fetchVariantes() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/trilha/variantes/'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['variantes'] is List) {
          if (mounted) {
            setState(() {
              _variantes = List<Map<String, dynamic>>.from(data['variantes']);
              _isLoading = false;
            });
            return;
          }
        }
      }
      throw Exception('Não foi possível carregar as variantes.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectVariante(Map<String, dynamic> v) async {
    final int vId = (v['id'] as num).toInt();
    if (vId == widget.varianteIdAtiva) {
      Navigator.pop(context);
      return;
    }

    setState(() => _updatingVarianteId = vId);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/update-variante'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'variante_id': vId}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final bool precisaNivelar = data['precisa_nivelar'] == true;

        if (mounted) {
          Navigator.pop(context);
          widget.onVarianteSelected(v, precisaNivelar);
        }
      } else {
        throw Exception('Erro ao atualizar variante ativa');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingVarianteId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _TupiColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _TupiColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🌿', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    'Selecione o Idioma',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _TupiColors.accent,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _TupiColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore diferentes troncos e variações históricas das línguas Tupi.',
            style: TextStyle(fontSize: 13, color: _TupiColors.textMuted),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _TupiColors.primary),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _fetchVariantes();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.primary),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            )
          else ...[
            ..._variantes.map((v) {
              final int vId = (v['id'] as num).toInt();
              final bool isSelected = vId == widget.varianteIdAtiva;
              final bool isUpdating = _updatingVarianteId == vId;
              final String nome = v['nome']?.toString() ?? 'Tupi';
              final String icone = v['icone']?.toString() ?? '🌿';
              final String desc = v['descricao']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: isUpdating ? null : () => _selectVariante(v),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? _TupiColors.primary.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? _TupiColors.primary : _TupiColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _TupiColors.primary.withValues(alpha: 0.15)
                                : _TupiColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(icone, style: const TextStyle(fontSize: 24)),
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
                                    nome,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? _TupiColors.primary : _TupiColors.accent,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _TupiColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'ATIVO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _TupiColors.textMuted,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isUpdating)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _TupiColors.primary),
                          )
                        else if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: _TupiColors.primary, size: 22)
                        else
                          const Icon(Icons.chevron_right_rounded, color: _TupiColors.textMuted, size: 22),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

