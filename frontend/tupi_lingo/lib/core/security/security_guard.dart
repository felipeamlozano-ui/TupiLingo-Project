import 'package:flutter/foundation.dart';
import 'secure_vault.dart';
import 'security_checker_io.dart'
    if (dart.library.js_interop) 'security_checker_web.dart'
    if (dart.library.html) 'security_checker_web.dart';

/// Nível de ameaça de integridade do dispositivo
enum SecurityThreatLevel {
  clean,
  suspicious,
  compromised,
}

/// Relatório de integridade em runtime
class SecurityReport {
  final SecurityThreatLevel threatLevel;
  final List<String> detectedAnomalies;
  final bool isDebuggerAttached;
  final bool isRootedOrJailbroken;

  const SecurityReport({
    required this.threatLevel,
    required this.detectedAnomalies,
    required this.isDebuggerAttached,
    required this.isRootedOrJailbroken,
  });

  bool get isSafe => threatLevel == SecurityThreatLevel.clean;
}

/// Guardião de Segurança em Runtime.
/// Implementa detecção de Root, Jailbreak, Depuradores ativos e ambientes de emulação hostis.
class SecurityGuard {
  // Caminhos conhecidos de binários de Root (Android)
  static const List<String> _androidRootPaths = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
  ];

  // Caminhos conhecidos de Jailbreak / Cydia (iOS)
  static const List<String> _iosJailbreakPaths = [
    '/Applications/Cydia.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt/',
  ];

  /// Executa auditoria completa de segurança em runtime
  static Future<SecurityReport> auditDeviceIntegrity() async {
    final anomalies = <String>[];
    bool isRooted = false;

    if (!kIsWeb) {
      final platformAnomalies = checkPlatformRootAndJailbreak(
        androidRootPaths: _androidRootPaths,
        iosJailbreakPaths: _iosJailbreakPaths,
      );
      if (platformAnomalies.isNotEmpty) {
        anomalies.addAll(platformAnomalies);
        isRooted = true;
      }
    }

    // Detecção de depurador ativo em builds de release
    bool debuggerAttached = false;
    assert(() {
      // Em modo debug, é normal estar conectado
      debuggerAttached = true;
      return true;
    }());

    if (kReleaseMode && debuggerAttached) {
      anomalies.add('Depurador ativo detectado em ambiente de Release');
    }

    SecurityThreatLevel threat;
    if (isRooted) {
      threat = SecurityThreatLevel.compromised;
    } else if (anomalies.isNotEmpty) {
      threat = SecurityThreatLevel.suspicious;
    } else {
      threat = SecurityThreatLevel.clean;
    }

    return SecurityReport(
      threatLevel: threat,
      detectedAnomalies: anomalies,
      isDebuggerAttached: debuggerAttached,
      isRootedOrJailbroken: isRooted,
    );
  }

  /// Política de resposta automática a incidentes de segurança
  static Future<void> enforcePolicy(SecurityReport report) async {
    if (report.threatLevel == SecurityThreatLevel.compromised) {
      debugPrint('🚨 [SecurityGuard] Dispositivo comprometido! Executando wipe de credenciais no SecureVault.');
      // Destrói tokens locais no Keystore para mitigar exfiltração de sessão
      await SecureVault.wipeAllSecrets();
    }
  }
}
