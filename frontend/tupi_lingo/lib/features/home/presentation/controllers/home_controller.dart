import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/memory/memory_residency_engine.dart';
import 'package:tupi_lingo/core/state/app_progression_notifier.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';

class HomeController extends ChangeNotifier {
  bool _isLoading = true;
  String? _errorMessage;
  int _currentTabIndex = 0;
  bool _isAdmin = false;

  // Dados do Usuário
  int _streakDays = 0;
  int _conchas = 0;
  int _xpTotal = 0;
  String _varianteNome = 'Tupi Antigo';
  int _varianteAtivaId = 1;

  // Dados da Trilha
  List<CapituloMapData> _capitulos = [];
  List<Map<String, dynamic>> _rawCapitulos = [];
  int _totalLicoesCompletas = 0;
  int _totalLicoes = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentTabIndex => _currentTabIndex;
  bool get isAdmin => _isAdmin;
  int get streakDays => _streakDays;
  int get conchas => _conchas;
  int get xpTotal => _xpTotal;
  String get varianteNome => _varianteNome;
  int get varianteAtivaId => _varianteAtivaId;
  List<CapituloMapData> get capitulos => _capitulos;
  List<Map<String, dynamic>> get rawCapitulos => _rawCapitulos;
  int get totalLicoesCompletas => _totalLicoesCompletas;
  int get totalLicoes => _totalLicoes;

  HomeController() {
    AppProgressionNotifier.instance.addListener(_onProgressionUpdated);
  }

  @override
  void dispose() {
    AppProgressionNotifier.instance.removeListener(_onProgressionUpdated);
    super.dispose();
  }

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  void _onProgressionUpdated() {
    final int gained = AppProgressionNotifier.instance.consumeLastConchasGained();
    if (gained > 0) {
      _conchas += gained;
      notifyListeners();
    }
    loadUserDataAndTrail();
  }

  void updateConchasDelta(int delta) {
    if (delta != 0) {
      _conchas += delta;
      notifyListeners();
    }
  }

  void setVarianteAtiva(int id, String nome) {
    _varianteAtivaId = id;
    _varianteNome = nome;
    notifyListeners();
  }

  Future<void> loadUserDataAndTrail({bool forceRefresh = false}) async {
    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (session == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final String cacheKey = 'trail_data_${session.user.id}';

    // 1. Tenta recuperar do MemoryResidencyEngine (L1 Cache) se não for forceRefresh
    if (!forceRefresh) {
      final cached = MemoryResidencyEngine.instance.getL1<Map<String, dynamic>>(cacheKey);
      if (cached != null && _capitulos.isNotEmpty) {
        _parseTrailPayload(cached);
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/trilha/mapa/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true) {
          MemoryResidencyEngine.instance.putL1(cacheKey, data);
          _parseTrailPayload(data);
          _errorMessage = null;
        } else {
          _errorMessage = data['error'] ?? 'Falha ao carregar trilha.';
        }
      } else {
        _errorMessage = 'Servidor indisponível (${res.statusCode})';
      }
    } catch (e) {
      if (_capitulos.isEmpty) {
        _errorMessage = 'Sem conexão com o servidor da aldeia.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _parseTrailPayload(Map<String, dynamic> data) {
    // 1. Dados do Usuário
    final user = data['usuario'] ?? {};
    _streakDays = (user['streak_atual'] as num?)?.toInt() ?? _streakDays;
    _conchas = (user['conchas'] as num?)?.toInt() ?? _conchas;
    _xpTotal = (user['xp_total'] as num?)?.toInt() ?? _xpTotal;
    _isAdmin = user['is_staff'] == true || user['is_superuser'] == true;

    // 2. Variante Ativa
    final variante = data['variante'] ?? {};
    _varianteNome = variante['nome'] ?? _varianteNome;
    _varianteAtivaId = (variante['id'] as num?)?.toInt() ?? _varianteAtivaId;

    // 3. Capítulos e Lições
    final capsList = (data['capitulos'] as List?) ?? [];
    _rawCapitulos = List<Map<String, dynamic>>.from(capsList);

    int totalCompletas = 0;
    int totalGeral = 0;
    final List<CapituloMapData> parsedCaps = [];

    const List<Color> palette = [
      Color(0xFF0E5D4E),
      Color(0xFFD08A45),
      Color(0xFF1EC9A5),
      Color(0xFFE05638),
      Color(0xFF5B3E8C),
    ];

    for (int i = 0; i < capsList.length; i++) {
      final c = capsList[i];
      final licoesList = (c['licoes'] as List?) ?? [];
      final List<LicaoMapData> parsedLicoes = [];

      for (final l in licoesList) {
        totalGeral++;
        final String rawStatus = l['status']?.toString() ?? 'bloqueada';
        final LicaoStatus status = parseLicaoStatus(rawStatus);
        if (status == LicaoStatus.concluida) {
          totalCompletas++;
        }

        parsedLicoes.add(LicaoMapData(
          id: (l['id'] as num).toInt(),
          titulo: l['titulo'] ?? '',
          descricao: l['descricao'] ?? '',
          numero: (l['numero'] as num?)?.toInt() ?? 1,
          xpBase: (l['xp_base'] as num?)?.toInt() ?? 20,
          posX: (l['pos_x'] as num?)?.toDouble() ?? 50.0,
          posY: (l['pos_y'] as num?)?.toDouble() ?? 50.0,
          status: status,
          earnedXp: (l['earned_xp'] as num?)?.toInt() ?? 0,
        ));
      }

      ChestRewardMapData? chest;
      final cr = c['chest_reward'];
      if (cr != null) {
        chest = ChestRewardMapData(
          milestoneIndex: (cr['milestone_index'] as num?)?.toInt() ?? 1,
          status: cr['status']?.toString() ?? 'bloqueado',
          unlocked: cr['unlocked'] == true,
          collected: cr['collected'] == true,
          recompensaXp: (cr['recompensa_xp'] as num?)?.toInt() ?? 75,
          recompensaConchas: (cr['recompensa_conchas'] as num?)?.toInt() ?? 50,
          afterLessonNumber: (cr['after_lesson_number'] as num?)?.toInt() ?? 3,
        );
      }

      parsedCaps.add(CapituloMapData(
        id: (c['id'] as num).toInt(),
        titulo: c['titulo'] ?? '',
        descricao: c['descricao'] ?? '',
        numero: (c['numero'] as num?)?.toInt() ?? (i + 1),
        paletteColor: palette[i % palette.length],
        licoes: parsedLicoes,
        chestReward: chest,
        moduleProgressPercentage: (c['module_progress_percentage'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    _capitulos = parsedCaps;
    _totalLicoesCompletas = totalCompletas;
    _totalLicoes = totalGeral;
  }

  void updateFromPayload(Map<String, dynamic> data) {
    _parseTrailPayload(data);
    notifyListeners();
  }

  static LicaoStatus parseLicaoStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'concluida':
      case 'completed':
        return LicaoStatus.concluida;
      case 'em_andamento':
      case 'in_progress':
        return LicaoStatus.emAndamento;
      case 'disponivel':
      case 'available':
        return LicaoStatus.disponivel;
      case 'bloqueada':
      case 'locked':
      default:
        return LicaoStatus.bloqueada;
    }
  }
}
