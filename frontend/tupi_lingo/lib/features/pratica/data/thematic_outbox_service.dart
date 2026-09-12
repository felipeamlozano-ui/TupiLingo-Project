import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

/// Serviço de Fila Offline-First (Outbox Pattern) para Prática Temática do TupiLingo.
///
/// Salva interações de quiz localmente no SharedPreferences em caso de oscilações
/// de rede (3G/4G), registrando timestamps precisos (presented_at e answered_at)
/// para que a engine TRI psicométrica processe os dados em lote com latência reduzida.
class ThematicOutboxService {
  ThematicOutboxService._();
  static final ThematicOutboxService instance = ThematicOutboxService._();

  static const String _storageKey = 'tupilingo_thematic_outbox_queue';

  /// Enfileira uma resposta/interação localmente
  Future<void> enqueueInteraction(Map<String, dynamic> interaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawQueue = prefs.getStringList(_storageKey) ?? [];
      rawQueue.add(jsonEncode(interaction));
      await prefs.setStringList(_storageKey, rawQueue);
      debugPrint('[OutboxService] Interação enfileirada com sucesso (total: ${rawQueue.length}).');
    } catch (e) {
      debugPrint('[OutboxService] Falha ao enfileirar interação: $e');
    }
  }

  /// Retorna as interações pendentes para uma determinada sessão
  Future<List<Map<String, dynamic>>> getPending(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawQueue = prefs.getStringList(_storageKey) ?? [];
      final List<Map<String, dynamic>> items = [];

      for (final raw in rawQueue) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (map['session_id'] == sessionId) {
            items.add(map);
          }
        } catch (_) {}
      }
      return items;
    } catch (e) {
      debugPrint('[OutboxService] Falha ao ler fila pendente: $e');
      return [];
    }
  }

  /// Limpa as interações de uma determinada sessão após sincronização
  Future<void> clearSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawQueue = prefs.getStringList(_storageKey) ?? [];
      final List<String> remaining = [];

      for (final raw in rawQueue) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (map['session_id'] != sessionId) {
            remaining.add(raw);
          }
        } catch (_) {
          remaining.add(raw);
        }
      }
      await prefs.setStringList(_storageKey, remaining);
      debugPrint('[OutboxService] Fila da sessão $sessionId limpa com sucesso.');
    } catch (e) {
      debugPrint('[OutboxService] Falha ao limpar sessão: $e');
    }
  }

  /// Sincroniza o lote de interações pendentes com o backend Django
  Future<Map<String, dynamic>?> syncBatch({
    required String sessionId,
    required String baseUrl,
  }) async {
    final pending = await getPending(sessionId);
    if (pending.isEmpty) {
      return {'success': true, 'empty': true};
    }

    try {
      final response = await ApiClient.post(
        '$baseUrl/api/v1/pratica/sincronizar-lote/',
        body: {
          'session_id': sessionId,
          'batch': pending,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['success'] == true) {
          await clearSession(sessionId);
          debugPrint('[OutboxService] Lote de ${pending.length} itens sincronizado com sucesso.');
          return data;
        }
      }
      debugPrint('[OutboxService] Backend retornou erro na sincronização: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[OutboxService] Falha de conexão ao sincronizar lote: $e');
      return null;
    }
  }
}
