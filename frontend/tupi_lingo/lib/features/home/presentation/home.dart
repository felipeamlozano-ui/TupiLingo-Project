import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/lesson/presentation/lesson_player.dart';

/// HomeScreen — Mapa Interativo de Aventura do TupiLingo.
///
/// Substitui a tela de cards/ações genérica por uma jornada narrativa imersiva
/// com pontos de lição espalhados sobre um cenário temático (Mata Atlântica,
/// Aldeia, Rio...). Cada ponto reage ao seu estado:
/// - Bloqueada: pedra coberta de musgo (cinza)
/// - Disponível: totem brilhando (dourado pulsante)
/// - Em Andamento: fogueira (laranja animado)
/// - Concluída: totem dourado (verde check)

// ─── Palette ─────────────────────────────────────────────────────────────────

class _TupiColors {
  static const background = Color(0xFF0D1F1A);
  static const surfaceCard = Color(0xFF132A23);
  static const primary = Color(0xFFD08A45);       // Âmbar Tupi
  static const accent = Color(0xFF27C98A);         // Verde Floresta vibrante
  static const textLight = Color(0xFFF0EAD6);      // Pergaminho
  static const textMuted = Color(0xFF7A9E90);
  static const nodeLocked = Color(0xFF3A4A44);
  static const nodeAvailable = Color(0xFFD08A45);
  static const nodeInProgress = Color(0xFFE8742A);
  static const nodeCompleted = Color(0xFF27C98A);
  static const xpColor = Color(0xFFFFD166);
}

// ─── Fake Data Model (substituído pela API) ───────────────────────────────────

enum LicaoStatus { bloqueada, disponivel, emAndamento, concluida }

class LicaoMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final int xpBase;
  final double posX; // 0-100% da largura
  final double posY; // 0-100% da altura
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

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _fireController;
  int _selectedCapituloIndex = 0;

  // API-driven chapter list
  List<CapituloMapData> _capitulos = [];
  bool _isLoadingMap = true;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _fetchCapitulos();
  }

  /// Busca os capítulos da variante ativa do usuário via API.
  Future<void> _fetchCapitulos() async {
    setState(() {
      _isLoadingMap = true;
      _mapError = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Sessão expirada');

      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      // 1. Descobre a variante ativa do usuário via check-user
      final profileRes = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/check-user'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (profileRes.statusCode != 200) {
        throw Exception('Erro ao obter perfil (HTTP ${profileRes.statusCode})');
      }

      final profileData = jsonDecode(profileRes.body);
      final varianteId = profileData['variante_ativa']?['id'];
      if (varianteId == null) {
        throw Exception('Nenhuma variante ativa configurada.');
      }

      // 2. Busca os capítulos da variante ativa
      final mapRes = await http.get(
        Uri.parse('$baseUrl/api/v1/trilha/$varianteId/capitulos/'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (mapRes.statusCode != 200) {
        throw Exception('Erro ao carregar mapa (HTTP ${mapRes.statusCode})');
      }

      final mapData = jsonDecode(utf8.decode(mapRes.bodyBytes));
      final List<dynamic> capitulosJson = mapData['capitulos'] ?? [];

      final List<CapituloMapData> capitulos = capitulosJson.map((cap) {
        final List<dynamic> licoesJson = cap['licoes'] ?? [];
        final Color paletteColor = _parsePaletteColor(cap['scenario']?['palette']);

        final licoes = licoesJson.map((l) {
          return LicaoMapData(
            id: l['id'] as int,
            titulo: l['titulo'] ?? '',
            descricao: l['descricao'] ?? '',
            numero: l['numero'] as int,
            xpBase: l['xp_base'] as int? ?? 10,
            posX: (l['pos_x'] as num?)?.toDouble() ?? 50.0,
            posY: (l['pos_y'] as num?)?.toDouble() ?? 50.0,
            status: _parseLicaoStatus(l['status'] as String? ?? 'bloqueada'),
            earnedXp: l['earned_xp'] as int? ?? 0,
          );
        }).toList();

        return CapituloMapData(
          id: cap['id'] as int,
          titulo: cap['titulo'] ?? '',
          descricao: cap['descricao'] ?? '',
          numero: cap['numero'] as int,
          paletteColor: paletteColor,
          licoes: licoes,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _capitulos = capitulos;
          _selectedCapituloIndex = 0;
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
          _mapError = e.toString();
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

  Color _parsePaletteColor(dynamic palette) {
    if (palette is Map && palette['primary'] is String) {
      try {
        final hex = (palette['primary'] as String).replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return _TupiColors.accent;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['name']?.toString() ??
        user?.email?.split('@').first ??
        'Aprendiz';

    // Loading state
    if (_isLoadingMap) {
      return Scaffold(
        backgroundColor: _TupiColors.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _TupiColors.primary),
              SizedBox(height: 16),
              Text('Carregando sua jornada...', style: TextStyle(color: _TupiColors.textMuted)),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_mapError != null) {
      return Scaffold(
        backgroundColor: _TupiColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: _TupiColors.primary, size: 56),
                const SizedBox(height: 16),
                const Text('Não foi possível carregar o mapa.',
                    style: TextStyle(color: _TupiColors.textLight, fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_mapError!, style: const TextStyle(color: _TupiColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchCapitulos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(backgroundColor: _TupiColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_capitulos.isEmpty) {
      return Scaffold(
        backgroundColor: _TupiColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Nenhum conteúdo disponível ainda.',
                  style: TextStyle(color: _TupiColors.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchCapitulos, child: const Text('Recarregar')),
            ],
          ),
        ),
      );
    }

    final capitulo = _capitulos[_selectedCapituloIndex];

    return Scaffold(
      backgroundColor: _TupiColors.background,
      body: Stack(
        children: [
          // ── Fundo gradiente do cenário ───────────────────────────────────
          _buildScenarioBackground(capitulo),

          // ── Conteúdo principal ───────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(userName),
                _buildXpBar(user),
                _buildChapterSelector(),
                Expanded(
                  child: _buildAdventureMap(capitulo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fundo do cenário ────────────────────────────────────────────────────────

  Widget _buildScenarioBackground(CapituloMapData capitulo) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _TupiColors.background,
            capitulo.paletteColor.withValues(alpha: 0.25),
            _TupiColors.background,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  // ── Barra superior ──────────────────────────────────────────────────────────

  Widget _buildTopBar(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFD08A45), Color(0xFF8B6914)],
              ),
              boxShadow: [
                BoxShadow(color: _TupiColors.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kauê, $userName!',
                  style: TextStyle(
                    fontSize: 13, color: _TupiColors.textMuted, fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'TupiLingo',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: _TupiColors.textLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Botão de sair
          IconButton(
            icon: Icon(Icons.logout_rounded, color: _TupiColors.textMuted, size: 22),
            tooltip: 'Sair',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
    );
  }

  // ── Barra de XP ─────────────────────────────────────────────────────────────

  Widget _buildXpBar(User? user) {
    // Demo: XP estático, substituído pelo UserProfile.xp_total da API
    const xpTotal = 55;
    const xpNivelAtual = 'Folha 🍃';
    const xpProximo = 500;
    const progresso = xpTotal / xpProximo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _TupiColors.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _TupiColors.xpColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        xpNivelAtual,
                        style: const TextStyle(
                          fontSize: 12, color: _TupiColors.xpColor, fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$xpTotal / $xpProximo XP',
                        style: TextStyle(fontSize: 11, color: _TupiColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progresso,
                      backgroundColor: _TupiColors.nodeLocked,
                      valueColor: const AlwaysStoppedAnimation(_TupiColors.xpColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seletor de Capítulos ─────────────────────────────────────────────────────

  Widget _buildChapterSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _capitulos.length,
          itemBuilder: (context, i) {
            final cap = _capitulos[i];
            final selected = i == _selectedCapituloIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedCapituloIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? cap.paletteColor : _TupiColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? cap.paletteColor : _TupiColors.textMuted.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'Cap. ${cap.numero}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : _TupiColors.textMuted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Mapa de Aventura ─────────────────────────────────────────────────────────

  Widget _buildAdventureMap(CapituloMapData capitulo) {
    return Column(
      children: [
        // Título do capítulo
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  capitulo.titulo,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: _TupiColors.textLight, letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          capitulo.descricao,
          style: TextStyle(fontSize: 12, color: _TupiColors.textMuted, height: 1.4),
          textAlign: TextAlign.center,
        ).paddingHorizontal(20),
        const SizedBox(height: 16),

        // O mapa interativo com os nodes posicionados
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapW = constraints.maxWidth;
              final mapH = constraints.maxHeight;
              return Stack(
                children: [
                  // Linha de trilha conectando os nodes
                  CustomPaint(
                    size: Size(mapW, mapH),
                    painter: _TrailPainter(
                      licoes: capitulo.licoes,
                      mapWidth: mapW,
                      mapHeight: mapH,
                    ),
                  ),

                  // Nodes das lições
                  ...capitulo.licoes.map((licao) {
                    final x = (licao.posX / 100) * mapW;
                    final y = (licao.posY / 100) * mapH;
                    return Positioned(
                      left: x - 32,
                      top: y - 32,
                      child: _LessonNode(
                        licao: licao,
                        pulseAnimation: _pulseController,
                        fireAnimation: _fireController,
                        onTap: () => _onLessonTap(licao),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _onLessonTap(LicaoMapData licao) {
    if (licao.status == LicaoStatus.bloqueada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _TupiColors.surfaceCard,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete as lições anteriores para desbloquear "${licao.titulo}".',
                  style: const TextStyle(color: _TupiColors.textLight, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LessonPreviewSheet(licao: licao),
    );
  }
}

// ─── Lesson Node Widget ───────────────────────────────────────────────────────

class _LessonNode extends StatelessWidget {
  final LicaoMapData licao;
  final Animation<double> pulseAnimation;
  final Animation<double> fireAnimation;
  final VoidCallback onTap;

  const _LessonNode({
    required this.licao,
    required this.pulseAnimation,
    required this.fireAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildNodeBody(),
            _buildNodeLabel(),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeBody() {
    switch (licao.status) {
      case LicaoStatus.bloqueada:
        return _LockedNode();

      case LicaoStatus.disponivel:
        return AnimatedBuilder(
          animation: pulseAnimation,
          builder: (_, __) => _AvailableNode(pulse: pulseAnimation.value),
        );

      case LicaoStatus.emAndamento:
        return AnimatedBuilder(
          animation: fireAnimation,
          builder: (_, __) => _InProgressNode(fire: fireAnimation.value),
        );

      case LicaoStatus.concluida:
        return _CompletedNode();
    }
  }

  Widget _buildNodeLabel() {
    return Positioned(
      bottom: -2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _TupiColors.background.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${licao.numero}',
          style: const TextStyle(
            fontSize: 9, color: _TupiColors.textMuted, fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LockedNode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _TupiColors.nodeLocked,
        border: Border.all(color: _TupiColors.textMuted.withValues(alpha: 0.3), width: 2),
      ),
      child: const Icon(Icons.lock_outline_rounded, color: _TupiColors.textMuted, size: 22),
    );
  }
}

class _AvailableNode extends StatelessWidget {
  final double pulse;
  const _AvailableNode({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final glowRadius = 8 + (pulse * 6);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFD166), Color(0xFFD08A45)],
        ),
        boxShadow: [
          BoxShadow(
            color: _TupiColors.primary.withValues(alpha: 0.5 + pulse * 0.3),
            blurRadius: glowRadius,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text('🏹', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _InProgressNode extends StatelessWidget {
  final double fire;
  const _InProgressNode({required this.fire});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(
          _TupiColors.nodeInProgress,
          const Color(0xFFFFD166),
          fire * 0.4,
        ),
        boxShadow: [
          BoxShadow(
            color: _TupiColors.nodeInProgress.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text('🔥', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _CompletedNode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF3DFFC0), Color(0xFF27C98A)],
        ),
        boxShadow: [
          BoxShadow(
            color: _TupiColors.accent.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text('✅', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

// ─── Trail Painter (CustomPainter) ───────────────────────────────────────────

class _TrailPainter extends CustomPainter {
  final List<LicaoMapData> licoes;
  final double mapWidth;
  final double mapHeight;

  const _TrailPainter({
    required this.licoes,
    required this.mapWidth,
    required this.mapHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < licoes.length - 1; i++) {
      final from = licoes[i];
      final to = licoes[i + 1];
      final fromPt = Offset((from.posX / 100) * mapWidth, (from.posY / 100) * mapHeight);
      final toPt = Offset((to.posX / 100) * mapWidth, (to.posY / 100) * mapHeight);

      final isActive = from.status == LicaoStatus.concluida;
      paint.color = isActive
          ? _TupiColors.accent.withValues(alpha: 0.5)
          : _TupiColors.nodeLocked.withValues(alpha: 0.4);

      // Linha curva tipo Bézier
      final control = Offset(
        (fromPt.dx + toPt.dx) / 2 + math.sin(i.toDouble()) * 30,
        (fromPt.dy + toPt.dy) / 2 - 20,
      );
      final path = Path()
        ..moveTo(fromPt.dx, fromPt.dy)
        ..quadraticBezierTo(control.dx, control.dy, toPt.dx, toPt.dy);

      if (isActive) {
        // Linha tracejada para trilha ativa
        paint.color = _TupiColors.accent.withValues(alpha: 0.55);
        canvas.drawPath(path, paint);
        // Pontinhos de ouro ao longo da trilha concluída
        final dashPaint = Paint()
          ..color = _TupiColors.xpColor.withValues(alpha: 0.6)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (double t = 0.2; t < 1.0; t += 0.25) {
          final pt = _bezierPoint(fromPt, control, toPt, t);
          canvas.drawCircle(pt, 2.5, dashPaint);
        }
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  Offset _bezierPoint(Offset p0, Offset p1, Offset p2, double t) {
    final x = (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx;
    final y = (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_TrailPainter old) => false;
}

// ─── Lesson Preview Bottom Sheet ─────────────────────────────────────────────

class _LessonPreviewSheet extends StatelessWidget {
  final LicaoMapData licao;

  const _LessonPreviewSheet({required this.licao});

  @override
  Widget build(BuildContext context) {
    final statusIcon = licao.status == LicaoStatus.concluida ? '✅' :
                       licao.status == LicaoStatus.emAndamento ? '🔥' : '🏹';
    final statusLabel = licao.status == LicaoStatus.concluida ? 'Concluída' :
                        licao.status == LicaoStatus.emAndamento ? 'Em andamento' : 'Disponível';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: _TupiColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _TupiColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _TupiColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text(statusIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lição ${licao.numero}',
                      style: TextStyle(fontSize: 12, color: _TupiColors.textMuted),
                    ),
                    Text(
                      licao.titulo,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: _TupiColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _TupiColors.xpColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _TupiColors.xpColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${licao.xpBase} XP',
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _TupiColors.xpColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            licao.descricao,
            style: TextStyle(fontSize: 14, color: _TupiColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _StatusChip(label: statusLabel),
              if (licao.earnedXp > 0) ...[
                const SizedBox(width: 8),
                _StatusChip(label: '+${licao.earnedXp} XP ganhos', color: _TupiColors.xpColor),
              ],
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: Key('btn_iniciar_licao_${licao.id}'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonPlayerScreen(licaoId: licao.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: licao.status == LicaoStatus.concluida
                    ? _TupiColors.accent
                    : _TupiColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(
                licao.status == LicaoStatus.concluida ? '🔄 Revisar Lição' :
                licao.status == LicaoStatus.emAndamento ? '▶️ Continuar' : '▶️ Iniciar Jornada',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, this.color = _TupiColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Extension ───────────────────────────────────────────────────────────────

extension _WidgetPadding on Widget {
  Widget paddingHorizontal(double h) => Padding(
    padding: EdgeInsets.symmetric(horizontal: h),
    child: this,
  );
}
