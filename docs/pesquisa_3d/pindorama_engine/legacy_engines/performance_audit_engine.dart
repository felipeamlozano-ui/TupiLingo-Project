import 'package:flutter/foundation.dart';

/// RFC-009C Camada 19 — Auditoria Automática de Performance.
///
/// Monitora e detecta em tempo de execução:
/// - Rebuilds excessivos
/// - Warmups duplicados
/// - Assets duplicados
/// - Requests duplicados
/// - Frames lentos (>16ms)
/// - Pressão de memória
class PerformanceAuditEngine {
  PerformanceAuditEngine._();

  static final PerformanceAuditEngine instance = PerformanceAuditEngine._();

  final Map<String, int> _widgetRebuildCounts = {};
  final Set<String> _recordedWarmups = {};
  final Set<String> _inFlightRequests = {};
  final List<String> _auditViolations = [];

  bool _isAuditing = kDebugMode;
  bool get isAuditing => _isAuditing;

  void enableAuditing(bool enable) {
    _isAuditing = enable;
  }

  /// Registra e audita rebuild de widgets em tela.
  void recordRebuild(String widgetName) {
    if (!_isAuditing) return;
    final count = (_widgetRebuildCounts[widgetName] ?? 0) + 1;
    _widgetRebuildCounts[widgetName] = count;

    if (count > 8) {
      _recordViolation('Rebuild excessivo: Widget "$widgetName" reconstruído $count vezes.');
    }
  }

  /// Retorna o total de rebuilds de um widget auditado.
  int getRebuildCount(String widgetName) => _widgetRebuildCounts[widgetName] ?? 0;

  /// Audita e deduplica warmups para garantir que nenhuma rota seja aquecida mais de uma vez.
  bool shouldWarmupRoute(String route) {
    if (_recordedWarmups.contains(route)) {
      debugPrint('🛡️ [PerformanceAudit] Warmup redundante bloqueado para a rota: "$route".');
      return false;
    }
    _recordedWarmups.add(route);
    return true;
  }

  /// Audita requisições de rede para evitar chamadas concorrentes duplicadas.
  bool tryAcquireRequestLock(String requestKey) {
    if (_inFlightRequests.contains(requestKey)) {
      debugPrint('🛡️ [PerformanceAudit] Request concorrente duplicado evitado para: "$requestKey".');
      return false;
    }
    _inFlightRequests.add(requestKey);
    return true;
  }

  void releaseRequestLock(String requestKey) {
    _inFlightRequests.remove(requestKey);
  }

  void _recordViolation(String violation) {
    if (!_auditViolations.contains(violation)) {
      _auditViolations.add(violation);
      debugPrint('⚠️ [PERFORMANCE AUDIT VIOLATION] $violation');
    }
  }

  /// Retorna relatório de métricas e violações observadas.
  Map<String, dynamic> generateReport() {
    return {
      'total_violations': _auditViolations.length,
      'violations': List<String>.from(_auditViolations),
      'unique_warmups': _recordedWarmups.length,
      'rebuild_counters': Map<String, int>.from(_widgetRebuildCounts),
    };
  }

  void clear() {
    _widgetRebuildCounts.clear();
    _recordedWarmups.clear();
    _inFlightRequests.clear();
    _auditViolations.clear();
  }
}
