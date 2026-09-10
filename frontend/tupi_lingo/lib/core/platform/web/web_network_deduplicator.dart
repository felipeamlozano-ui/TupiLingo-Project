import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Deduplicador de Requisições de Rede em Voo e Circuit Breaker Adaptativo (HPWE Camada 19).
///
/// Garante que se múltiplos componentes solicitarem simultaneamente o mesmo
/// recurso pela rede (ex: dados da lição, trilha, perfil), apenas uma única
/// requisição física HTTP/3 seja despachada, compartilhando a mesma Promise/Future.
class WebNetworkDeduplicator {
  WebNetworkDeduplicator._();

  static final WebNetworkDeduplicator instance = WebNetworkDeduplicator._();

  final Map<String, Future<dynamic>> _inFlightRequests = {};
  final Map<String, int> _failureCounts = {};
  final Map<String, DateTime> _circuitBreakerUntil = {};

  /// Executa uma requisição com compartilhamento de Future em voo e proteção por Circuit Breaker.
  Future<T> execute<T>({
    required String requestKey,
    required Future<T> Function() requestFactory,
    Duration timeout = const Duration(seconds: 10),
  }) {
    // 1. Verifica Circuit Breaker (se houver falhas consecutivas, bloqueia requisição em loop)
    final breakerUntil = _circuitBreakerUntil[requestKey];
    if (breakerUntil != null && DateTime.now().isBefore(breakerUntil)) {
      debugPrint('⚡ [HPWE CircuitBreaker] Requisição "$requestKey" retida até $breakerUntil');
      return Future.error(TimeoutException('Circuit Breaker ativo para $requestKey'));
    }

    // 2. Se já existe uma requisição idêntica em andamento, retorna o mesmo Future (Promise Sharing)
    if (_inFlightRequests.containsKey(requestKey)) {
      debugPrint('⚡ [HPWE Deduplicator] Compartilhando requisição em voo para "$requestKey" (0 overhead)');
      return _inFlightRequests[requestKey]! as Future<T>;
    }

    // 3. Cria a nova requisição protegida
    final completer = Completer<T>();
    _inFlightRequests[requestKey] = completer.future;

    requestFactory().timeout(timeout).then((result) {
      _failureCounts[requestKey] = 0;
      _circuitBreakerUntil.remove(requestKey);
      _inFlightRequests.remove(requestKey);
      completer.complete(result);
    }).catchError((error, stackTrace) {
      _inFlightRequests.remove(requestKey);

      // Incrementa contador de falhas para Circuit Breaker com Exponential Backoff
      final failures = (_failureCounts[requestKey] ?? 0) + 1;
      _failureCounts[requestKey] = failures;

      if (failures >= 3) {
        final backoffSeconds = math.min(30, math.pow(2, failures).toInt());
        _circuitBreakerUntil[requestKey] = DateTime.now().add(Duration(seconds: backoffSeconds));
        debugPrint('⚠️ [HPWE CircuitBreaker] Ativado para "$requestKey" por ${backoffSeconds}s.');
      }

      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  /// Limpa todas as requisições em voo e reseta os breakers.
  void clear() {
    _inFlightRequests.clear();
    _failureCounts.clear();
    _circuitBreakerUntil.clear();
  }
}
