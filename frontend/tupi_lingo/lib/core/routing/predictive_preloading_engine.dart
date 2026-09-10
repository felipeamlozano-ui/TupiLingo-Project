import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/core/concurrency/ten_isolates_engine.dart';
import 'package:tupi_lingo/core/memory/memory_residency_engine.dart';

/// Callback para carregadores de rota sob demanda.
typedef RoutePreloadCallback = Future<void> Function(String routeName, Map<String, dynamic>? params);

/// Motor de Predição e Pré-Carregamento Preditivo de Rotas (Cadeia de Markov de 1ª Ordem).
///
/// Prevê qual tela o usuário abrirá em seguida com base no histórico estatístico
/// de transições e dispara a preparação em paralelo nos Isolates antes do clique.
class PredictivePreloadingEngine {
  PredictivePreloadingEngine._();

  static final PredictivePreloadingEngine instance = PredictivePreloadingEngine._();

  // Matriz de transição de Markov: P(Next | Current)
  final Map<String, Map<String, int>> _transitionCounts = {};
  final Map<String, dynamic> _preloadedRouteData = {};
  final Set<String> _inFlightPreloadKeys = {};
  RoutePreloadCallback? _preloadHandler;

  /// Registra o handler que sabe como buscar dados da rota prevista.
  void setPreloadHandler(RoutePreloadCallback handler) {
    _preloadHandler = handler;
  }

  /// Notifica que o usuário navegou para uma rota, atualizando o modelo estatístico
  /// e disparando o preloading preditivo da próxima rota mais provável.
  void onRouteChanged({required String currentRoute, String? previousRoute, Map<String, dynamic>? contextParams}) {
    if (previousRoute != null && previousRoute.isNotEmpty) {
      final stateTransitions = _transitionCounts.putIfAbsent(previousRoute, () => {});
      stateTransitions[currentRoute] = (stateTransitions[currentRoute] ?? 0) + 1;
    }

    // Predição da próxima tela mais provável
    final predictedRoute = _predictNextRoute(currentRoute);
    if (predictedRoute != null) {
      _triggerPreload(predictedRoute, contextParams);
    }
  }

  /// Retorna o nome da rota com maior probabilidade condicional a partir da atual.
  String? _predictNextRoute(String currentRoute) {
    // 1. Regras heurísticas determinísticas para fluxos críticos
    if (currentRoute == '/home') {
      return '/lesson';
    } else if (currentRoute == '/lesson') {
      return '/lesson_success';
    } else if (currentRoute == '/welcome') {
      return '/login';
    }

    // 2. Modelo de Markov empírico caso haja histórico suficiente
    final transitions = _transitionCounts[currentRoute];
    if (transitions == null || transitions.isEmpty) return null;

    String? bestRoute;
    int maxCount = -1;

    for (final entry in transitions.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        bestRoute = entry.key;
      }
    }

    return bestRoute;
  }

  /// Dispara o pré-carregamento concorrente via Isolates para a rota prevista.
  void _triggerPreload(String targetRoute, Map<String, dynamic>? params) {
    final preloadKey = '$targetRoute:${params?['licao_id'] ?? ''}';
    if (_inFlightPreloadKeys.contains(preloadKey)) {
      // Deduplicação ativa: já em warmup ou em memória
      return;
    }
    _inFlightPreloadKeys.add(preloadKey);
    // Limpa a chave após cooldown de 15 segundos para permitir recarregamento se necessário
    Future.delayed(const Duration(seconds: 15), () {
      _inFlightPreloadKeys.remove(preloadKey);
    });

    debugPrint('🔮 [PredictiveRoute] Próxima tela prevista: "$targetRoute" (key: $preloadKey). Disparando Warmup...');

    // Dispara tarefa no Navigation Isolate
    TenIsolatesEngine.instance.dispatch(
      role: IsolateRole.navigation,
      action: 'predictive_route_warmup',
      metadata: {'route': targetRoute, ...?params},
    );

    // Executa o handler especializado registrado pelo app
    if (_preloadHandler != null) {
      _preloadHandler!(targetRoute, params).catchError((e) {
        debugPrint('⚠️ [PredictiveRoute] Erro no preload de "$targetRoute": $e');
      });
    }
  }

  /// Armazena dados de rota pré-carregados no cache de alta velocidade L1.
  void storePreloadedData(String key, dynamic data) {
    _preloadedRouteData[key] = data;
    MemoryResidencyEngine.instance.putL1('preloaded_$key', data);
  }

  /// Consome os dados pré-carregados para renderização instantânea (Zero Latency).
  T? consumePreloadedData<T>(String key) {
    final l1Value = MemoryResidencyEngine.instance.removeL1<T>('preloaded_$key');
    if (_preloadedRouteData.containsKey(key)) {
      return _preloadedRouteData.remove(key) as T?;
    }
    return l1Value;
  }

  /// Limpa todos os dados de preloading.
  void clear() {
    _preloadedRouteData.clear();
  }
}
