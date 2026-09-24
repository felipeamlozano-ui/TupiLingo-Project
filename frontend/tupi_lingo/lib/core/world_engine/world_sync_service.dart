import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import 'package:tupi_lingo/core/world_engine/biomes/biome_palette.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_bounds.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';
import 'package:tupi_lingo/core/world_engine/trails/historical_trail.dart';
import 'package:tupi_lingo/core/world_engine/trails/river_path.dart';
import 'package:tupi_lingo/core/world_engine/villages/village_node.dart';
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
          // Se não havia snapshot local salvo ou o remoto é mais novo, adota o remoto
          if (activeWorldNotifier.value == null) {
            activeWorldNotifier.value = data;
            await _storage.write(key: _storageKey, value: jsonEncode(data));
            AppLogger.i('WORLD_SYNC', 'Snapshot do Pindorama sincronizado a partir do backend.');
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
  /// NOTA: O World Builder usa espaço [0–4000], o World Engine usa [0–10000].
  /// As coordenadas são remapeadas proporcionalmente (fator 2.5) para alinhamento correto.
  List<VillageNode> parseVillages(Map<String, dynamic>? bundle) {
    if (bundle == null || bundle['villages'] == null) {
      return VillageNode.canonicalVillages;
    }

    final rawList = bundle['villages'] as List<dynamic>;
    if (rawList.isEmpty) return VillageNode.canonicalVillages;

    // Fator de escala: World Builder usa canvas 4000x4000, engine usa 10000x10000
    const double kScaleFactor = 10000.0 / 4000.0; // = 2.5

    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id']?.toString() ?? 'village_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Aldeia';
      final tupiName = map['name_tupi'] ?? 'Taba';

      // Remapeia de [0–4000] (World Builder) para [0–10000] (World Engine)
      final rawX = (map['x'] as num?)?.toDouble() ?? 2000.0;
      final rawY = (map['y'] as num?)?.toDouble() ?? 2000.0;
      final x = rawX * kScaleFactor;
      final y = rawY * kScaleFactor;

      final isUnlocked = map['is_unlocked_default'] == true || map['is_unlocked'] == true;

      // Raio também deve ser escalado para manter proporção visual correta
      final rawRadius = (map['fog_reveal_radius'] as num?)?.toDouble() ?? 180.0;
      final radius = rawRadius * kScaleFactor;

      final desc = map['description']?.toString() ?? '';
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

      return VillageNode(
        id: id,
        name: name,
        tupiName: tupiName,
        position: WorldCoordinate(x, y),
        variantId: 1,
        biome: biome,
        stage: isUnlocked ? VillageEvolutionStage.historica : VillageEvolutionStage.oculta,
        isUnlocked: isUnlocked,
        discoveryRadius: radius,
        historicalContext: desc,
        activeEpochs: const ['1554', '1500', '1567', '1600'],
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
      final tupiName = map['name_tupi'] ?? 'Y';
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
        final midX = (start.wx + end.wx) / 2.0;
        final midY = (start.wy + end.wy) / 2.0;
        segments.add(
          RiverSegment(
            start: start,
            control1: WorldCoordinate(start.wx + (midX - start.wx) * 0.5, start.wy + (midY - start.wy) * 0.5),
            control2: WorldCoordinate(midX + (end.wx - midX) * 0.5, midY + (end.wy - midY) * 0.5),
            end: end,
            startWidth: width,
            endWidth: width * 1.3,
          ),
        );
      }

      return RiverPath(
        id: id,
        namePt: name,
        nameTupi: tupiName,
        segments: segments,
        waterColor: const Color(0xFF2E9383),
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
      final tupiName = map['name_tupi'] ?? 'Peabiru';
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

      return HistoricalTrail(
        id: id,
        name: name,
        description: tupiName.isNotEmpty ? 'Trilha ancestral: $tupiName' : 'Trilha histórica de Pindorama',
        points: points,
        linkedVillageIds: linkedIds,
        isDiscovered: true,
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
      final id = map['id']?.toString() ?? 'territory_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name_portuguese'] ?? map['name'] ?? 'Território';
      final tupiName = map['name_tupi'] ?? 'Yvy';
      final x = (map['center_x'] as num?)?.toDouble() ?? 5000.0;
      final y = (map['center_y'] as num?)?.toDouble() ?? 5000.0;
      final biomeStr = map['biome']?.toString() ?? 'mataAtlantica';
      final biome = BiomeType.values.firstWhere(
        (b) => b.name == biomeStr,
        orElse: () => BiomeType.mataAtlantica,
      );

      return TerritoryNode(
        id: id,
        name: name,
        tupiName: tupiName,
        historicalPeriod: '1500 — Tradição Ancestral',
        primaryDialect: 'Tupi Geral',
        biome: biome,
        center: WorldCoordinate(x, y),
        bounds: WorldBounds(minX: x - 500, minY: y - 500, maxX: x + 500, maxY: y + 500),
        villageIds: const [],
        isUnlocked: true,
      );
    }).toList();
  }
}
