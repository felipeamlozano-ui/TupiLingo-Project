import 'package:flutter/foundation.dart';

/// Deterministic A/B Experiment variant assigner (RFC-012B Chapter 46).
class ABExperimentEngine {
  /// Deterministically assigns [userId] to an experiment bucket [control, treatment_a, treatment_b].
  String assignVariant({
    required String experimentId,
    required String userId,
    List<String> variants = const ['control', 'treatment_a'],
  }) {
    if (variants.isEmpty) return 'control';
    if (userId.isEmpty) return variants.first;

    final key = '$experimentId:$userId';
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = (31 * hash + key.codeUnitAt(i)) & 0x7FFFFFFF;
    }

    final index = hash % variants.length;
    return variants[index];
  }
}

/// Analytics event telemetry logger.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  final List<Map<String, dynamic>> _events = [];

  List<Map<String, dynamic>> get loggedEvents => List.unmodifiable(_events);

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final payload = {
      'event_name': eventName,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    _events.add(payload);
    if (kDebugMode) {
      debugPrint('📊 [Analytics] $eventName: $parameters');
    }
  }

  void clear() {
    _events.clear();
  }
}
