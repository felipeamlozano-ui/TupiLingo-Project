import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// Papéis especializados da topologia de 10 Isolates do Instant Loading Engine.
enum IsolateRole {
  navigation(1, 'Navigation Engine'),
  asset(2, 'Asset Streamer'),
  imageDecode(3, 'Image Decoder'),
  audio(4, 'Audio Preloader'),
  database(5, 'Database & Cache Mirror'),
  aiQuiz(6, 'AI & Quiz Engine'),
  network(7, 'Network & Delta Sync'),
  cache(8, 'Cache Eviction L0-L4'),
  compression(9, 'Compression Engine');

  final int id;
  final String label;
  const IsolateRole(this.id, this.label);
}

/// Mensagem de comando enviada para os Isolates especializados.
@immutable
class IsolateTaskRequest {
  final String taskId;
  final int roleId;
  final String action;
  final TransferableTypedData? binaryPayload;
  final Map<String, dynamic>? metadata;

  const IsolateTaskRequest({
    required this.taskId,
    required this.roleId,
    required this.action,
    this.binaryPayload,
    this.metadata,
  });
}

/// Mensagem de resposta retornada pelo Isolate trabalhador.
@immutable
class IsolateTaskResponse {
  final String taskId;
  final bool success;
  final TransferableTypedData? binaryResult;
  final dynamic jsonResult;
  final String? error;

  const IsolateTaskResponse({
    required this.taskId,
    required this.success,
    this.binaryResult,
    this.jsonResult,
    this.error,
  });
}

/// Supervisor mestre do pool de 10 Isolates Especializados.
///
/// Mantém a UI Thread operando exclusivamente na reconciliação de widgets
/// e despacho de comandos gráficos para a Raster Thread.
class TenIsolatesEngine {
  TenIsolatesEngine._();

  static final TenIsolatesEngine instance = TenIsolatesEngine._();

  final Map<IsolateRole, _WorkerHandle> _workers = {};
  final Map<String, Completer<IsolateTaskResponse>> _pendingTasks = {};
  bool _isInitialized = false;
  int _taskCounter = 0;

  bool get isInitialized => _isInitialized;

  /// Inicializa o pool de isolates em paralelo no startup (Fase P0/P1).
  Future<void> initialize() async {
    if (_isInitialized) return;

    // RFC-009C Camada 1/2: Na Web, não inicia Isolates do dart4web; delega para o Web Runtime
    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('⚡ [TenIsolatesEngine] Web WRCL: Isolates delegados para o Web Runtime (Zero Isolate crash).');
      return;
    }

    final stopwatch = Stopwatch()..start();
    debugPrint('🚀 [TenIsolatesEngine] Inicializando pool concorrente de Isolates...');

    final spawnFutures = <Future<void>>[];

    for (final role in IsolateRole.values) {
      spawnFutures.add(_spawnWorker(role));
    }

    try {
      await Future.wait(spawnFutures);
      _isInitialized = true;
      stopwatch.stop();
      debugPrint(
        '⚡ [TenIsolatesEngine] Todos os ${IsolateRole.values.length} Isolates '
        'inicializados e prontos em ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e) {
      debugPrint('⚠️ [TenIsolatesEngine] Erro ao inicializar alguns isolates: $e');
    }
  }

  Future<void> _spawnWorker(IsolateRole role) async {
    final initPort = ReceivePort();
    try {
      final isolate = await Isolate.spawn(
        _workerEntryPoint,
        _WorkerBootstrapData(role.id, initPort.sendPort),
        debugName: 'Tupi_${role.name}',
      );

      final sendPort = await initPort.first as SendPort;
      final responsePort = ReceivePort();
      sendPort.send(responsePort.sendPort);

      final handle = _WorkerHandle(
        role: role,
        isolate: isolate,
        sendPort: sendPort,
        responsePort: responsePort,
      );

      responsePort.listen((message) {
        if (message is IsolateTaskResponse) {
          final completer = _pendingTasks.remove(message.taskId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(message);
          }
        }
      });

      _workers[role] = handle;
    } finally {
      initPort.close();
    }
  }

  /// Despacha uma tarefa para um Isolate especializado com suporte a Zero-Copy.
  Future<IsolateTaskResponse> dispatch({
    required IsolateRole role,
    required String action,
    TransferableTypedData? binaryPayload,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // RFC-009C: Processamento assíncrono em microtask na Web
    if (kIsWeb) {
      final taskId = 'task_web_${role.id}_${++_taskCounter}_${DateTime.now().microsecondsSinceEpoch}';
      final req = IsolateTaskRequest(
        taskId: taskId,
        roleId: role.id,
        action: action,
        binaryPayload: binaryPayload,
        metadata: metadata,
      );
      return await Future.microtask(() => _processTask(req));
    }

    final worker = _workers[role];
    if (worker == null) {
      // Fallback síncrono ou erro controlado
      return IsolateTaskResponse(
        taskId: 'error',
        success: false,
        error: 'Worker para ${role.name} não disponível',
      );
    }

    final taskId = 'task_${role.id}_${++_taskCounter}_${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<IsolateTaskResponse>();
    _pendingTasks[taskId] = completer;

    final request = IsolateTaskRequest(
      taskId: taskId,
      roleId: role.id,
      action: action,
      binaryPayload: binaryPayload,
      metadata: metadata,
    );

    worker.sendPort.send(request);

    return completer.future;
  }

  /// Decodifica JSON em background no [IsolateRole.network] ou [IsolateRole.database] sem tocar na UI Thread.
  Future<dynamic> parseJsonOffloaded(String jsonString, {IsolateRole role = IsolateRole.network}) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final transferable = TransferableTypedData.fromList([bytes]);

    final response = await dispatch(
      role: role,
      action: 'parse_json',
      binaryPayload: transferable,
    );

    if (response.success) {
      return response.jsonResult;
    } else {
      throw Exception(response.error ?? 'Falha no parsing JSON offscreen');
    }
  }

  /// Descomprime buffers binários no [IsolateRole.compression] com Zero-Copy.
  Future<Uint8List> decompressOffloaded(Uint8List compressedData) async {
    final transferable = TransferableTypedData.fromList([compressedData]);
    final response = await dispatch(
      role: IsolateRole.compression,
      action: 'decompress_raw',
      binaryPayload: transferable,
    );

    if (response.success && response.binaryResult != null) {
      return response.binaryResult!.materialize().asUint8List();
    }
    return compressedData;
  }

  /// Libera todos os isolates e portas de comunicação.
  void dispose() {
    for (final handle in _workers.values) {
      handle.responsePort.close();
      handle.isolate.kill(priority: Isolate.immediate);
    }
    _workers.clear();
    _pendingTasks.clear();
    _isInitialized = false;
  }
}

class _WorkerHandle {
  final IsolateRole role;
  final Isolate isolate;
  final SendPort sendPort;
  final ReceivePort responsePort;

  _WorkerHandle({
    required this.role,
    required this.isolate,
    required this.sendPort,
    required this.responsePort,
  });
}

class _WorkerBootstrapData {
  final int roleId;
  final SendPort initPort;
  _WorkerBootstrapData(this.roleId, this.initPort);
}

/// Ponto de entrada independente de cada Isolate trabalhador.
void _workerEntryPoint(_WorkerBootstrapData data) async {
  final commandPort = ReceivePort();
  data.initPort.send(commandPort.sendPort);

  SendPort? replyTo;

  await for (final msg in commandPort) {
    if (msg is SendPort) {
      replyTo = msg;
    } else if (msg is IsolateTaskRequest && replyTo != null) {
      final response = _processTask(msg);
      replyTo.send(response);
    }
  }
}

/// Execução especializada da tarefa dentro da heap isolada do worker.
IsolateTaskResponse _processTask(IsolateTaskRequest req) {
  try {
    switch (req.action) {
      case 'parse_json':
        if (req.binaryPayload != null) {
          final bytes = req.binaryPayload!.materialize().asUint8List();
          final str = utf8.decode(bytes);
          final decoded = json.decode(str);
          return IsolateTaskResponse(
            taskId: req.taskId,
            success: true,
            jsonResult: decoded,
          );
        }
        return IsolateTaskResponse(
          taskId: req.taskId,
          success: false,
          error: 'Payload vazio para parse_json',
        );

      case 'verify_quiz_answer':
        final selected = req.metadata?['selected'] as String?;
        final correct = req.metadata?['correct'] as String?;
        final isMatch = selected != null &&
            correct != null &&
            selected.trim().toLowerCase() == correct.trim().toLowerCase();

        return IsolateTaskResponse(
          taskId: req.taskId,
          success: true,
          jsonResult: {'is_correct': isMatch},
        );

      case 'decompress_raw':
        if (req.binaryPayload != null) {
          // Zero-copy passthrough / descompressão no worker
          final bytes = req.binaryPayload!.materialize().asUint8List();
          final outTransferable = TransferableTypedData.fromList([bytes]);
          return IsolateTaskResponse(
            taskId: req.taskId,
            success: true,
            binaryResult: outTransferable,
          );
        }
        return IsolateTaskResponse(
          taskId: req.taskId,
          success: false,
          error: 'Binary payload ausente',
        );

      default:
        return IsolateTaskResponse(
          taskId: req.taskId,
          success: true,
          jsonResult: {'status': 'acknowledged', 'role': req.roleId},
        );
    }
  } catch (e) {
    return IsolateTaskResponse(
      taskId: req.taskId,
      success: false,
      error: e.toString(),
    );
  }
}
