import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import 'package:tupi_lingo/core/world_engine/biomes/biome_palette.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_bounds.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';
import 'package:tupi_lingo/core/world_engine/trails/historical_overlay.dart';
import 'package:tupi_lingo/core/world_engine/trails/historical_trail.dart';
import 'package:tupi_lingo/core/world_engine/trails/river_path.dart';
import 'package:tupi_lingo/core/world_engine/villages/village_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/lesson_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/territory_node.dart';

/// Serviço Canônico de Persistência e Sincronização em Tempo Real do Pindorama World Engine.
/// Garante que qualquer alteração feita no World Builder seja salva em disco e aplicada
/// instantaneamente no mapa exploratório do usuário sem necessidade de reiniciar o app.
class WorldSyncService {
  static final WorldSyncService instance = WorldSyncService._();
  WorldSyncService._();

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'pindorama_active_world_snapshot_v1';

  final ValueNotifier<Map<String, dynamic>?> activeWorldNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  bool _initialized = false;

  Map<String, dynamic>? get activeSnapshot => activeWorldNotifier.value;

  /// Inicializa o serviço carregando o snapshot persistido em cache local ou no backend
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final cachedJson = await _storage.read(key: _storageKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> parsed = jsonDecode(cachedJson);
        activeWorldNotifier.value = parsed;
        AppLogger.i('WORLD_SYNC', 'Snapshot do Pindorama carregado do cache local com sucesso.');
      }
    } catch (e) {
      AppLogger.w('WORLD_SYNC', 'Falha ao ler snapshot do cache: $e');
    }

    // Busca versão ativa atualizada no backend em background
    _fetchRemoteActiveWorld();
  }

  Future<void> _fetchRemoteActiveWorld() async {
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/world/active/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'];
        if (data is Map<String, dynamic> && (data['villages'] != null || data['territories'] != null)) {
          // Se não havia snapshot local salvo ou o remoto tem versão diferente/mais nova, adota o remoto
          final currentVersion = activeWorldNotifier.value?['version']?.toString();
          final remoteVersion = data['version']?.toString();
          if (activeWorldNotifier.value == null || currentVersion != remoteVersion) {
            activeWorldNotifier.value = data;
            await _storage.write(key: _storageKey, value: jsonEncode(data));
            AppLogger.i('WORLD_SYNC', 'Snapshot do Pindorama sincronizado a partir do backend (v$remoteVersion).');
          }
        }
      }
    } catch (_) {
      // Offline fallback gracioso
    }
  }

  /// Salva as alterações do World Builder, persiste localmente e notifica ouvintes instantaneamente.
  Future<bool> saveAndApplyWorld({
    required Map<String, dynamic> bundle,
    bool publishToBackend = true,
    String commitMessage = 'Alterações do World Builder',
    String authorRole = 'Administrator',
    String versionTag = '1.2.0',
  }) async {
    try {
      // 1. Aplicação reativa imediata na memória para todos os observadores do jogo
      activeWorldNotifier.value = Map<String, dynamic>.from(bundle);

      // 2. Persistência em repouso no Secure Storage do dispositivo
      await _storage.write(key: _storageKey, value: jsonEncode(bundle));
      AppLogger.sec('WORLD_BUILDER', 'Snapshot salvo em repouso local (${bundle['villages']?.length ?? 0} aldeias).');

      // 3. Disparo de sincronização com o backend
      if (publishToBackend) {
        try {
          final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/world/publish/');
          final res = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'world_bundle': bundle,
              'commit_message': commitMessage,
              'author_role': authorRole,
              'version_tag': versionTag,
            }),
          ).timeout(const Duration(seconds: 6));

          if (res.statusCode == 200 || res.statusCode == 201) {
            AppLogger.i('WORLD_BUILDER', 'Snapshot publicado no backend com sucesso (HTTP ${res.statusCode}).');
          } else {
            AppLogger.w('WORLD_BUILDER', 'Backend retornou HTTP ${res.statusCode} ao publicar snapshot.');
          }
        } catch (e) {
          AppLogger.w('WORLD_BUILDER', 'Backend offline durante publish. Salvo localmente com garantia offline.');
        }
      }

      return true;
    } catch (e) {
      AppLogger.e('WORLD_BUILDER', 'Erro ao salvar e aplicar mundo: $e');
      return false;
    }
  }

  /// Converte a lista serializada de aldeias para os nós gráficos de alta fidelidade.
  /// Suporta espaço [0–4000] (World Builder) e reescala proporcionalmente (fator 2.5) para [0–10000] (World Engine).
  List<VillageNode> parseVillages(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['villages'] == null) {
      return VillageNode.canonicalVillages;
    }

    final rawList = bundle['villages'] as List<dynamic>;
    if (rawList.isEmpty) return VillageNode.canonicalVillages;

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? map['slug']?.toString() ?? 'village_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Aldeia';
      final tupiName = map['name_tupi'] ?? map['tupi_name'] ?? 'Taba';

      // Remapeia de [0–4000] (World Builder) para [0–10000] (World Engine) se necessário
      final rawX = (map['x'] as num?)?.toDouble() ?? (map['cx'] as num?)?.toDouble() ?? 2000.0;
      final rawY = (map['y'] as num?)?.toDouble() ?? (map['cy'] as num?)?.toDouble() ?? 2000.0;
      final scale = (rawX <= 4000.0 && rawY <= 4000.0 && (rawX > 0 || rawY > 0)) ? 2.5 : 1.0;
      final x = rawX * scale;
      final y = rawY * scale;

      final bool isUnlocked = (map['is_unlocked'] as bool?) ?? (map['is_unlocked_default'] as bool?) ?? true;
      final bool isDiscovered = (map['is_discovered'] as bool?) ?? (isUnlocked && (id == 'piratininga' || id.contains('piratininga')));

      // Estágio de evolução da aldeia
      final rawStage = map['stage']?.toString().toLowerCase() ?? '';
      final rawEvo = map['evolution_stage'];
      VillageEvolutionStage stage;
      if (rawStage == 'historica' || rawEvo == 4 || rawEvo == 5) {
        stage = VillageEvolutionStage.historica;
      } else if (rawStage == 'dominada' || rawEvo == 3) {
        stage = VillageEvolutionStage.dominada;
      } else if (rawStage == 'explorada' || rawEvo == 2) {
        stage = VillageEvolutionStage.explorada;
      } else if (rawStage == 'descoberta' || rawEvo == 1) {
        stage = VillageEvolutionStage.descoberta;
      } else {
        stage = isUnlocked ? VillageEvolutionStage.explorada : VillageEvolutionStage.oculta;
      }

      // Raio de revelação da névoa
      final rawRadius = (map['fog_reveal_radius'] as num?)?.toDouble() ?? (map['discovery_radius'] as num?)?.toDouble() ?? 240.0;
      final radius = (rawRadius <= 350.0 ? rawRadius * 2.5 : rawRadius).clamp(450.0, 950.0);

      final desc = map['description']?.toString() ?? map['historical_context']?.toString() ?? '';
      final biomeStr = (map['biome']?.toString() ?? 'Mata Atlântica').toLowerCase();
      final biome = biomeStr.contains('cerrado')
          ? BiomeType.cerrado
          : biomeStr.contains('amaz')
              ? BiomeType.amazonia
              : biomeStr.contains('caatinga')
                  ? BiomeType.caatinga
                  : biomeStr.contains('pantanal')
                      ? BiomeType.pantanal
                      : BiomeType.mataAtlantica;

      // Épocas históricas ativas
      List<String> activeEpochs = const ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'];
      if (map['active_epochs'] is List && (map['active_epochs'] as List).isNotEmpty) {
        final parsed = (map['active_epochs'] as List).map((e) {
          final s = e.toString().toLowerCase();
          if (s.contains('pre') || s.contains('1500')) return 'pre1500';
          if (s.contains('1554')) return 'epoch1554';
          if (s.contains('1555')) return 'epoch1555';
          if (s.contains('1567')) return 'epoch1567';
          if (s.contains('atual') || s.contains('revitalizacao')) return 'atual';
          return s;
        }).toSet().toList();
        if (parsed.isNotEmpty) {
          activeEpochs = parsed;
        }
      }

      // Lições vinculadas ao capítulo
      final rawLessons = map['lessons'] as List<dynamic>? ?? [];
      final lessons = rawLessons.map((l) {
        final lmap = Map<String, dynamic>.from(l as Map);
        final lid = lmap['id']?.toString() ?? 'lic_${DateTime.now().millisecondsSinceEpoch}';
        final licaoId = lmap['licao_id'] as int?;
        final ltitle = lmap['title']?.toString() ?? 'Lição';
        final ltupi = lmap['tupi_title']?.toString() ?? ltitle;
        final ldesc = lmap['description']?.toString() ?? '';
        final lxp = (lmap['xp_reward'] as num?)?.toInt() ?? 50;
        final lduration = (lmap['duration_minutes'] as num?)?.toInt() ?? 5;
        final ltheme = lmap['practice_theme']?.toString();

        LessonDifficulty diff = LessonDifficulty.iniciante;
        final rawDiff = lmap['difficulty']?.toString().toLowerCase() ?? '';
        if (rawDiff.contains('inter')) {
          diff = LessonDifficulty.intermediario;
        } else if (rawDiff.contains('avan')) {
          diff = LessonDifficulty.avancado;
        } else if (rawDiff.contains('mest')) {
          diff = LessonDifficulty.mestre;
        }

        LessonType type = LessonType.vocabulario;
        final rawType = lmap['type']?.toString().toLowerCase() ?? '';
        if (rawType.contains('gram')) {
          type = LessonType.gramatica;
        } else if (rawType.contains('escut')) {
          type = LessonType.escuta;
        } else if (rawType.contains('hist')) {
          type = LessonType.historia;
        } else if (rawType.contains('boss') || rawType.contains('desafio')) {
          type = LessonType.bossChallenge;
        }

        LessonStatus status = LessonStatus.locked;
        final rawStatus = lmap['status']?.toString().toLowerCase() ?? '';
        if (rawStatus == 'available') {
          status = LessonStatus.available;
        } else if (rawStatus == 'inprogress') {
          status = LessonStatus.inProgress;
        } else if (rawStatus == 'completed') {
          status = LessonStatus.completed;
        } else if (rawStatus == 'mastered') {
          status = LessonStatus.mastered;
        }

        return LessonNode(
          id: lid,
          licaoId: licaoId,
          title: ltitle,
          tupiTitle: ltupi,
          description: ldesc,
          difficulty: diff,
          type: type,
          status: status,
          xpReward: lxp,
          durationMinutes: lduration,
          practiceTheme: ltheme,
        );
      }).toList();

      final chapterNum = map['chapter'] ?? 1;

      return VillageNode(
        id: id,
        name: name,
        tupiName: tupiName,
        position: WorldCoordinate(x, y),
        variantId: 1,
        biome: biome,
        stage: stage,
        isUnlocked: isUnlocked,
        isDiscovered: isDiscovered,
        discoveryRadius: radius,
        historicalContext: desc,
        residentCount: (map['resident_count'] as num?)?.toInt() ?? (200 + (chapterNum is int ? chapterNum * 15 : 20)),
        dialectVariant: map['dialect_variant']?.toString() ?? 'Tupi Antigo',
        leaderName: map['leader_name']?.toString() ?? 'Cacique Ancestral',
        hasBossChallenge: map['has_boss_challenge'] == true,
        territoryId: map['territory_id']?.toString() ?? 'reg_${chapterNum.toString().padLeft(2, '0')}',
        chapterId: map['chapter_id']?.toString() ?? 'cap_${chapterNum.toString().padLeft(2, '0')}',
        activeEpochs: activeEpochs,
        lessons: lessons,
      );
    }).toList();
  }

  /// Converte rios serializados para os caminhos fluviais
  List<RiverPath> parseRivers(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['rivers'] == null) {
      return RiverPath.canonicalRivers();
    }

    final rawList = bundle['rivers'] as List<dynamic>;
    if (rawList.isEmpty) return RiverPath.canonicalRivers();

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? 'river_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Rio';
      final tupiName = map['name_tupi'] ?? map['tupi_name'] ?? 'Y';
      final width = (map['river_width'] as num?)?.toDouble() ?? 14.0;
      final rawPoints = map['bezier_points'] as List<dynamic>? ?? [];

      final points = rawPoints.map((p) {
        if (p is List && p.length >= 2) {
          final rx = (p[0] as num).toDouble();
          final ry = (p[1] as num).toDouble();
          final scale = (rx <= 4000.0 && ry <= 4000.0 && (rx > 0 || ry > 0)) ? 2.5 : 1.0;
          return WorldCoordinate(rx * scale, ry * scale);
        }
        return const WorldCoordinate(5000.0, 5000.0);
      }).toList();

      if (points.length < 2) {
        points.addAll([
          const WorldCoordinate(4800.0, 4800.0),
          const WorldCoordinate(5200.0, 5200.0),
        ]);
      }

      final segments = <RiverSegment>[];
      for (int i = 0; i < points.length - 1; i++) {
        final start = points[i];
        final end = points[i + 1];

        // Smooth cubic Bézier control points with natural meandering hydrology
        WorldCoordinate c1;
        WorldCoordinate c2;

        if (points.length >= 3) {
          final prev = i > 0 ? points[i - 1] : points[i];
          final next = i + 2 < points.length ? points[i + 2] : points[i + 1];

          // Tangent at start: (end - prev) / 4.0
          final dx1 = (end.wx - prev.wx) / 4.0;
          final dy1 = (end.wy - prev.wy) / 4.0;
          // Tangent at end: (next - start) / 4.0
          final dx2 = (next.wx - start.wx) / 4.0;
          final dy2 = (next.wy - start.wy) / 4.0;

          c1 = WorldCoordinate(start.wx + dx1, start.wy + dy1);
          c2 = WorldCoordinate(end.wx - dx2, end.wy - dy2);
        } else {
          // 2-point river: add gentle natural lateral meander
          final dx = end.wx - start.wx;
          final dy = end.wy - start.wy;
          final normX = -dy * 0.16;
          final normY = dx * 0.16;
          c1 = WorldCoordinate(start.wx + dx * 0.33 + normX, start.wy + dy * 0.33 + normY);
          c2 = WorldCoordinate(start.wx + dx * 0.66 - normX * 0.6, start.wy + dy * 0.66 - normY * 0.6);
        }

        // Tapered width from mountain spring source to wide estuary mouth
        final double segStartW = (i == 0)
            ? width * 0.45
            : width * (0.65 + (i / (points.length - 1)) * 0.85);
        final double segEndW = (i == points.length - 2)
            ? width * 1.95
            : width * (0.65 + ((i + 1) / (points.length - 1)) * 0.85);

        segments.add(
          RiverSegment(
            start: start,
            control1: c1,
            control2: c2,
            end: end,
            startWidth: segStartW,
            endWidth: segEndW,
          ),
        );
      }

      final waterHex = map['water_color']?.toString() ?? '#2E9383';
      Color waterColor = const Color(0xFF2E9383);
      try {
        final hex = waterHex.replaceAll('#', '');
        waterColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      } catch (_) {}

      return RiverPath(
        id: id,
        namePt: name,
        nameTupi: tupiName,
        segments: segments,
        waterColor: waterColor,
      );
    }).toList();
  }

  /// Converte trilhas serializadas para as conexões históricas
  List<HistoricalTrail> parseTrails(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['trails'] == null) {
      return HistoricalTrail.canonicalTrails;
    }

    final rawList = bundle['trails'] as List<dynamic>;
    if (rawList.isEmpty) return HistoricalTrail.canonicalTrails;

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? 'trail_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Trilha';
      final tupiName = map['name_tupi'] ?? map['tupi_name'] ?? 'Peabiru';
      final fromId = map['from_id']?.toString() ?? '';
      final toId = map['to_id']?.toString() ?? '';
      final rawWaypoints = map['waypoints'] as List<dynamic>? ?? [];

      final points = rawWaypoints.map((p) {
        if (p is List && p.length >= 2) {
          final rx = (p[0] as num).toDouble();
          final ry = (p[1] as num).toDouble();
          final scale = (rx <= 4000.0 && ry <= 4000.0 && (rx > 0 || ry > 0)) ? 2.5 : 1.0;
          return WorldCoordinate(rx * scale, ry * scale);
        }
        return const WorldCoordinate(5000.0, 5000.0);
      }).toList();

      if (points.length < 2) {
        points.addAll([
          const WorldCoordinate(4900.0, 4900.0),
          const WorldCoordinate(5100.0, 5100.0),
        ]);
      }

      final linkedIds = <String>[];
      if (fromId.isNotEmpty) linkedIds.add(fromId);
      if (toId.isNotEmpty) linkedIds.add(toId);

      final colorHex = map['trail_color']?.toString() ?? map['color_hex']?.toString() ?? '#E5A93C';
      Color trailColor = const Color(0xFFE5A93C);
      try {
        final hex = colorHex.replaceAll('#', '');
        trailColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      } catch (_) {}

      final strokeWidth = (map['stroke_width'] as num?)?.toDouble() ?? 3.5;

      final activeEpochs = (map['active_epochs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['pre1500', 'epoch1532', 'epoch1554', 'epoch1555', 'epoch1567', 'atual'];

      return HistoricalTrail(
        id: id,
        name: name,
        description: tupiName.isNotEmpty ? 'Trilha ancestral: $tupiName' : 'Trilha histórica de Pindorama',
        points: points,
        linkedVillageIds: linkedIds,
        color: trailColor,
        strokeWidth: strokeWidth,
        isDiscovered: map['is_discovered'] != false,
        activeEpochs: activeEpochs,
      );
    }).toList();
  }

  /// Converte territórios serializados
  List<TerritoryNode> parseTerritories(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['territories'] == null) {
      return TerritoryNode.canonicalTerritories;
    }

    final rawList = bundle['territories'] as List<dynamic>;
    if (rawList.isEmpty) return TerritoryNode.canonicalTerritories;

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? map['slug']?.toString() ?? 'territory_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Território';
      final tupiName = map['name_tupi'] ?? map['tupi_name'] ?? 'Yvy';

      final rawX = (map['center_x'] as num?)?.toDouble() ?? (map['cx'] as num?)?.toDouble() ?? 2000.0;
      final rawY = (map['center_y'] as num?)?.toDouble() ?? (map['cy'] as num?)?.toDouble() ?? 2000.0;
      final scale = (rawX <= 4000.0 && rawY <= 4000.0 && (rawX > 0 || rawY > 0)) ? 2.5 : 1.0;
      final x = rawX * scale;
      final y = rawY * scale;

      final biomeStr = (map['biome']?.toString() ?? 'mataAtlantica').toLowerCase();
      final biome = biomeStr.contains('cerrado')
          ? BiomeType.cerrado
          : biomeStr.contains('amaz')
              ? BiomeType.amazonia
              : biomeStr.contains('caatinga')
                  ? BiomeType.caatinga
                  : biomeStr.contains('pantanal')
                      ? BiomeType.pantanal
                      : BiomeType.mataAtlantica;

      final rawVids = map['village_ids'] as List<dynamic>? ?? [];
      List<String> villageIds = rawVids.map((v) => v.toString()).toList();
      if (villageIds.isEmpty) {
        final slug = map['slug']?.toString() ?? id;
        villageIds = [slug.replaceAll('reg_', 'vila_')];
      }

      return TerritoryNode(
        id: id,
        name: name,
        tupiName: tupiName,
        historicalPeriod: map['historical_period']?.toString() ?? '1500 — Tradição Ancestral',
        primaryDialect: map['primary_dialect']?.toString() ?? 'Tupi Geral',
        biome: biome,
        center: WorldCoordinate(x, y),
        bounds: WorldBounds(minX: x - 1200, minY: y - 1200, maxX: x + 1200, maxY: y + 1200),
        villageIds: villageIds,
        isUnlocked: true,
      );
    }).toList();
  }

  /// Converte sobreposições territoriais e alianças históricas (Overlays)
  List<HistoricalOverlay> parseOverlays(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['overlays'] == null) {
      return HistoricalOverlay.canonicalOverlays;
    }

    final rawList = bundle['overlays'] as List<dynamic>;
    if (rawList.isEmpty) return HistoricalOverlay.canonicalOverlays;

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? map['slug']?.toString() ?? 'overlay_${DateTime.now().millisecondsSinceEpoch}';
      final title = map['title']?.toString() ?? 'Território Histórico';
      final desc = map['description']?.toString() ?? '';
      final rawType = map['overlay_type']?.toString() ?? 'alliance';
      final epoch = map['epoch_id']?.toString() ?? map['epoch']?.toString() ?? 'epoch1554';
      final colorHex = map['base_color_hex']?.toString() ?? '#E53935';

      Color color = const Color(0xFFE53935);
      try {
        final hex = colorHex.replaceAll('#', '');
        color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      } catch (_) {}

      HistoricalOverlayType type = HistoricalOverlayType.alliance;
      for (final t in HistoricalOverlayType.values) {
        if (t.name.toLowerCase() == rawType.toLowerCase()) {
          type = t;
          break;
        }
      }

      final rawPoints = map['polygon_points'] as List<dynamic>? ?? [];
      final points = rawPoints.map((p) {
        if (p is List && p.length >= 2) {
          final rx = (p[0] as num).toDouble();
          final ry = (p[1] as num).toDouble();
          final scale = (rx <= 4000.0 && ry <= 4000.0 && (rx > 0 || ry > 0)) ? 2.5 : 1.0;
          return WorldCoordinate(rx * scale, ry * scale);
        }
        return const WorldCoordinate(5000.0, 5000.0);
      }).toList();

      return HistoricalOverlay(
        id: id,
        title: title,
        description: desc,
        type: type,
        polygonPoints: points,
        baseColor: color,
        epochId: epoch,
      );
    }).toList();
  }
}
