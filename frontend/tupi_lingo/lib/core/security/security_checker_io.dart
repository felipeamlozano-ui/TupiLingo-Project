import 'dart:io';

/// Executa verificação de integridade de filesystem no Android e iOS.
List<String> checkPlatformRootAndJailbreak({
  required List<String> androidRootPaths,
  required List<String> iosJailbreakPaths,
}) {
  final anomalies = <String>[];
  if (Platform.isAndroid) {
    for (final path in androidRootPaths) {
      try {
        if (File(path).existsSync()) {
          anomalies.add('Binário de Root detectado no sistema: $path');
          break;
        }
      } catch (_) {
        // Permissão negada pelo SO é comum e esperado em sandbox
      }
    }
  } else if (Platform.isIOS) {
    for (final path in iosJailbreakPaths) {
      try {
        if (File(path).existsSync()) {
          anomalies.add('Assinatura de Jailbreak detectada: $path');
          break;
        }
      } catch (_) {}
    }
  }
  return anomalies;
}
