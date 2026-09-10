import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/core/platform/web/web_engine_bootstrap.dart';
import 'package:tupi_lingo/core/platform/web/web_network_deduplicator.dart';

/// Ponte de Plataforma Unificada (Platform Bridge).
///
/// Encaminha otimizações para a camada Web (`platform/web/`) apenas quando
/// `kIsWeb == true`. Em ambiente nativo (Android), repassa as operações
/// diretamente sem qualquer modificação, assegurando ZERO REGRESSÃO MOBILE.
class PlatformWebBridge {
  PlatformWebBridge._();

  static final PlatformWebBridge instance = PlatformWebBridge._();

  /// Inicializa o subsistema de plataforma correspondente.
  Future<void> initialize() async {
    if (kIsWeb) {
      await WebEngineBootstrap.instance.initialize();
    }
  }

  /// Executa requisições de rede aplicando deduplicação em voo se estiver na Web,
  /// ou executando diretamente no Android sem interferência no pipeline nativo.
  Future<T> executeRequest<T>({
    required String key,
    required Future<T> Function() action,
  }) {
    if (kIsWeb) {
      return WebNetworkDeduplicator.instance.execute(
        requestKey: key,
        requestFactory: action,
      );
    }
    // Android Nativo: Execução direta sem overhead
    return action();
  }
}
