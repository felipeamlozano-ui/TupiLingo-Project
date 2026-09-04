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

/// Paleta de Cores com Identidade Visual Tupi Ancestral
class _TupiColors {
  static const background = Color(0xFFF3F2E8);        // Pergaminho Claro / Areia Sagrada (Idêntico ao resto do app)
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
}

class CapituloMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final Color paletteColor;
  final List<LicaoMapData> licoes;

  const CapituloMapData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.numero,
    required this.paletteColor,
    required this.licoes,
  });
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

  // Dados do Aluno
  int _xpTotal = 85;
  int _streakDays = 3;
  int _conchas = 140;
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
    _loadUserDataAndTrail();
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
    _pulseController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndTrail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      int varianteId = 1;

      if (session != null) {
        // 1. Carrega dados atualizados do usuário
        try {
          final profileRes = await http.post(
            Uri.parse('$baseUrl/api/v1/auth/check-user'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));

          if (profileRes.statusCode == 200) {
            final dynamic profileData = jsonDecode(utf8.decode(profileRes.bodyBytes));
            if (profileData is Map<String, dynamic>) {
              final varianteAtiva = profileData['variante_ativa'];
              if (varianteAtiva is Map<String, dynamic>) {
                varianteId = (varianteAtiva['id'] as num?)?.toInt() ?? 1;
                _varianteId = varianteId;
                _varianteNome = varianteAtiva['nome']?.toString() ?? 'Tupi Antigo';
              }
              _xpTotal = (profileData['xp_total'] as num?)?.toInt() ?? 85;
              _streakDays = (profileData['dias_ofensiva'] as num?)?.toInt() ?? 3;
              _conchas = (profileData['conchas'] as num?)?.toInt() ?? 140;
            }
          }
        } catch (_) {}

        // 1.1 Checagem se o usuário possui permissão de Administrador
        try {
          final adminRes = await http.get(
            Uri.parse('$baseUrl/api/v1/admin/me'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 5));

          if (adminRes.statusCode == 200) {
            final dynamic adminData = jsonDecode(utf8.decode(adminRes.bodyBytes));
            if (adminData is Map<String, dynamic> && adminData['is_admin'] == true) {
              _isAdmin = true;
            }
          }
        } catch (_) {}

        // 2. Carrega capítulos e lições da variante
        final mapRes = await http.get(
          Uri.parse('$baseUrl/api/v1/trilha/$varianteId/capitulos/'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (mapRes.statusCode == 200) {
          final dynamic mapData = jsonDecode(utf8.decode(mapRes.bodyBytes));
          if (mapData is Map<String, dynamic>) {
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
              return CapituloMapData(
                id: (capMap['id'] as num?)?.toInt() ?? 0,
                titulo: capMap['titulo']?.toString() ?? 'Capítulo $capNum',
                descricao: capMap['descricao']?.toString() ?? '',
                numero: capNum,
                paletteColor: _TupiColors.accent,
                licoes: licoes,
              );
            }).toList();

            if (mounted) {
              setState(() {
                _capitulos = loadedCapitulos;
                _selectedCapituloIndex = 0;
                _isLoading = false;
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
      backgroundColor: _TupiColors.background,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _TupiColors.background,
        border: Border(
          bottom: BorderSide(color: _TupiColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Variante Ativa Badge com Seletor de Idioma
          GestureDetector(
            onTap: () => _showLanguageSwitcher(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _TupiColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    _varianteNome,
                    style: const TextStyle(
                      color: _TupiColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _TupiColors.accent,
                  ),
                ],
              ),
            ),
          ),

          // Métricas de Gamificação: Ofensiva, Conchas, XP
          Row(
            children: [
              _buildTopStat(icon: '🔥', label: '$_streakDays', color: _TupiColors.streakColor),
              const SizedBox(width: 10),
              _buildTopStat(icon: '🐚', label: '$_conchas', color: _TupiColors.shellColor),
              const SizedBox(width: 10),
              _buildTopStat(icon: '⭐', label: '$_xpTotal', color: _TupiColors.xpColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({required String icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _TupiColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            _buildWindingLessonPath(cap.licoes),
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
                color: isSelected ? _TupiColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected ? _TupiColors.primary : _TupiColors.border,
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
                  color: isSelected ? Colors.white : _TupiColors.textMuted,
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
        ],
      ),
    );
  }

  /// Constrói o caminho de lições ondulado verticalmente
  Widget _buildWindingLessonPath(List<LicaoMapData> licoes) {
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

    return Column(
      children: List.generate(licoes.length, (index) {
        final licao = licoes[index];
        final dx = offsets[index % offsets.length];

        final isAvailable = licao.status == LicaoStatus.disponivel;

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
                  // Aura pulsante na lição ativa
                  if (isAvailable && _pulseController != null)
                    AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, _) {
                        final val = _pulseController?.value ?? 0.0;
                        return Container(
                          width: 84 + (val * 12),
                          height: 84 + (val * 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _TupiColors.primary.withValues(alpha: 0.25 - (val * 0.15)),
                          ),
                        );
                      },
                    ),

                  // Balãozinho de "COMEÇAR" flutuando acima do nó ativo
                  if (isAvailable && _floatController != null)
                    Positioned(
                      top: -34,
                      child: AnimatedBuilder(
                        animation: _floatController!,
                        builder: (context, _) {
                          final val = _floatController?.value ?? 0.0;
                          final dy = math.sin(val * math.pi) * 3;
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _TupiColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'COMEÇAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Botão 3D Tátil
                  _build3DNodeButton(licao),
                ],
              ),
            ),

            // Se for após a Lição 2, insere um baú de recompensa cultural no caminho
            if (index == 1 && licoes.length > 2) ...[
              const SizedBox(height: 16),
              _buildTrailConnector(99),
              _buildChestRewardNode(),
            ],
          ],
        );
      }),
    );
  }

  Widget _build3DNodeButton(LicaoMapData licao) {
    final isCompleted = licao.status == LicaoStatus.concluida;
    final isAvailable = licao.status == LicaoStatus.disponivel;
    final isLocked = licao.status == LicaoStatus.bloqueada;

    Color topColor;
    Color bottomColor;
    Widget iconWidget;

    if (isCompleted) {
      topColor = _TupiColors.accent;
      bottomColor = _TupiColors.accentDark;
      iconWidget = const Text('👑', style: TextStyle(fontSize: 28));
    } else if (isAvailable) {
      topColor = _TupiColors.primary;
      bottomColor = _TupiColors.primaryDark;
      iconWidget = const Text('⭐', style: TextStyle(fontSize: 28));
    } else {
      topColor = _TupiColors.nodeLocked;
      bottomColor = _TupiColors.nodeLockedBorder;
      iconWidget = const Icon(Icons.lock_rounded, color: _TupiColors.textMuted, size: 26);
    }

    return GestureDetector(
      onTap: () => _onLessonNodeTapped(licao),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: topColor,
              border: Border(
                bottom: BorderSide(color: bottomColor, width: 6),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCompleted ? _TupiColors.accent : isAvailable ? _TupiColors.primary : const Color(0xFFC7C3B6))
                      .withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _TupiColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              licao.titulo,
              style: TextStyle(
                color: isLocked ? _TupiColors.textMuted : _TupiColors.textDark,
                fontSize: 11,
                fontWeight: FontWeight.bold,
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
    return Container(
      width: 6,
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCD8CB),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildChestRewardNode() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _TupiColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Text('🏺', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Baú do Pajé: Continue avançando na trilha para desbloquear conchas e artefatos!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _TupiColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: _TupiColors.xpColor.withValues(alpha: 0.4), width: 2),
        ),
        child: const Text('🏺', style: TextStyle(fontSize: 26)),
      ),
    );
  }

  void _onLessonNodeTapped(LicaoMapData licao) {
    if (licao.status == LicaoStatus.bloqueada) {
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonPlayerScreen(licaoId: licao.id),
                ),
              );
              _loadUserDataAndTrail();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? _TupiColors.accent : _TupiColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
            ),
            child: Text(
              isCompleted ? 'REVISAR LIÇÃO' : 'COMEÇAR LIÇÃO',
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
            const Text(
              'Centro de Prática Ancestral 🏹',
              style: TextStyle(
                color: _TupiColors.textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fortaleça sua memória com treinos rápidos e revisão espaçada.',
              style: TextStyle(color: _TupiColors.textMuted, fontSize: 13),
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
            const Text(
              'Banco de Vocabulário da Trilha',
              style: TextStyle(
                color: _TupiColors.textDark,
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
                  color: _TupiColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _TupiColors.border),
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
                                style: const TextStyle(
                                  color: _TupiColors.textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '[${item['pronuncia']!}]',
                                style: TextStyle(color: _TupiColors.textMuted.withValues(alpha: 0.7), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['pt']!,
                            style: const TextStyle(color: _TupiColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _TupiColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['cat']!,
                        style: const TextStyle(color: _TupiColors.textMuted, fontSize: 10),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _TupiColors.border, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _TupiColors.primary,
        unselectedItemColor: _TupiColors.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            activeIcon: Icon(Icons.explore_rounded, color: _TupiColors.primary),
            label: 'Trilha',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            activeIcon: Icon(Icons.fitness_center_rounded, color: _TupiColors.accent),
            label: 'Prática',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded, color: _TupiColors.primary),
            label: 'Perfil',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_rounded),
              activeIcon: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0E5D4E)),
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

