import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'ten_isolates_engine.dart';

/// RFC-009C Camada 1 — Background Execution Abstraction.
///
/// Interface unificada de execução em background para a aplicação.
/// No Android: opera via TenIsolatesEngine e Isolates nativos com Zero-Copy.
/// Na Web: opera via Web Workers / Async Event Loop sem invocar dart:isolate.
class BackgroundExecutionEngine {
  BackgroundExecutionEngine._();

  static final BackgroundExecutionEngine instance = BackgroundExecutionEngine._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializa o subsistema de background conforme a plataforma.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('⚡ [BackgroundExecutionEngine] Web Runtime WRCL inicializado com sucesso.');
    } else {
      await TenIsolatesEngine.instance.initialize();
      _isInitialized = true;
      debugPrint('⚡ [BackgroundExecutionEngine] Android TenIsolatesEngine inicializado com sucesso.');
    }
  }

  /// Executa uma tarefa pesada de computação/parsing em background.
  Future<T> computeTask<T>({
    required IsolateRole role,
    required String action,
    Map<String, dynamic>? metadata,
    T Function()? task,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb) {
      if (task != null) {
        return await Future.microtask(task);
      }
      final res = await TenIsolatesEngine.instance.dispatch(
        role: role,
        action: action,
        metadata: metadata,
      );
      return res.jsonResult as T;
    } else {
      final res = await TenIsolatesEngine.instance.dispatch(
        role: role,
        action: action,
        metadata: metadata,
      );
      return (res.jsonResult ?? res.binaryResult) as T;
    }
  }

  /// Executa uma função pura de forma segura na Web e Android.
  Future<R> compute<Q, R>(R Function(Q message) callback, Q message) async {
    if (kIsWeb) {
      return await Future.microtask(() => callback(message));
    } else {
      return await foundation.compute(callback, message);
    }
  }

  /// Executa uma computação assíncrona desacoplada da UI.
  Future<T> run<T>(FutureOr<T> Function() computation) async {
    return await Future.microtask(computation);
  }
}
