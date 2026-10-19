import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/security/crypto_engine.dart';

/// Item da fila de saída (Outbox Pattern) representando uma lição concluída offline.
class LessonOutboxItem {
  final String id;
  final String userId;
  final int licaoId;
  final int acertos;
  final int totalExercicios;
  final int tempoSegundos;
  final int bonusExploracaoXp;
  final int xpGanho;
  final int timestamp;
  final String nonce;
  final String signature;

  LessonOutboxItem({
    required this.id,
    required this.userId,
    required this.licaoId,
    required this.acertos,
    required this.totalExercicios,
    required this.tempoSegundos,
    required this.bonusExploracaoXp,
    required this.xpGanho,
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'licao_id': licaoId,
        'acertos': acertos,
        'total_exercicios': totalExercicios,
        'tempo_segundos': tempoSegundos,
        'bonus_exploracao_xp': bonusExploracaoXp,
        'xp_ganho': xpGanho,
        'timestamp': timestamp,
        'nonce': nonce,
        'signature': signature,
      };

  factory LessonOutboxItem.fromJson(Map<String, dynamic> json) => LessonOutboxItem(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        licaoId: (json['licao_id'] as num?)?.toInt() ?? 0,
        acertos: (json['acertos'] as num?)?.toInt() ?? 0,
        totalExercicios: (json['total_exercicios'] as num?)?.toInt() ?? 1,
        tempoSegundos: (json['tempo_segundos'] as num?)?.toInt() ?? 60,
        bonusExploracaoXp: (json['bonus_exploracao_xp'] as num?)?.toInt() ?? 0,
        xpGanho: (json['xp_ganho'] as num?)?.toInt() ?? 0,
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        nonce: json['nonce']?.toString() ?? '',
        signature: json['signature']?.toString() ?? '',
      );
}

/// Serviço de Fila Offline-First (Outbox Pattern) para Lições do TupiLingo.
/// Garante que lições concluídas sem sinal de internet sejam validadas localmente,
/// assinadas com integridade criptográfica anti-replay (HMAC-SHA256) e sincronizadas
/// automaticamente com o backend assim que a conectividade for restabelecida.
class LessonOutboxService {
  LessonOutboxService._();
  static final LessonOutboxService instance = LessonOutboxService._();

  static const String _storageKeyEncryptedQueue = 'tupilingo_lesson_outbox_queue_v1';
  bool _isSyncing = false;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

  String _currentUserId() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) return user.id;
    } catch (_) {}
    return 'guest_user';
  }

  /// Recupera itens pendentes decifrando o armazenamento local
  Future<List<LessonOutboxItem>> getPendingItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedPayload = prefs.getString(_storageKeyEncryptedQueue);
      if (encryptedPayload == null || encryptedPayload.isEmpty) {
        pendingCountNotifier.value = 0;
        return [];
      }

      final decrypted = await CryptoEngine.instance.decryptAesGcm(encryptedPayload);
      if (decrypted == null || decrypted.isEmpty) {
        pendingCountNotifier.value = 0;
        return [];
      }

      final decoded = jsonDecode(decrypted);
      if (decoded is List) {
        final list = decoded
            .map((e) => LessonOutboxItem.fromJson(e as Map<String, dynamic>))
            .toList();
        pendingCountNotifier.value = list.length;
        return list;
      }
    } catch (e) {
      debugPrint('[LessonOutboxService] Erro ao recuperar itens pendentes: $e');
    }
    return [];
  }

  /// Salva a lista de itens cifrada com AES-256-GCM
  Future<void> _savePendingItems(List<LessonOutboxItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await prefs.remove(_storageKeyEncryptedQueue);
        pendingCountNotifier.value = 0;
        return;
      }

      final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
      final encryptedPayload = await CryptoEngine.instance.encryptAesGcm(jsonStr);
      await prefs.setString(_storageKeyEncryptedQueue, encryptedPayload);
      pendingCountNotifier.value = items.length;
    } catch (e) {
      debugPrint('[LessonOutboxService] Erro ao gravar itens cifrados: $e');
    }
  }

  /// Enfileira uma lição concluída offline com assinatura HMAC-SHA256 e nonce único
  Future<LessonOutboxItem> enqueueCompletedLesson({
    required int licaoId,
    required int acertos,
    required int totalExercicios,
    required int tempoSegundos,
    required int bonusExploracaoXp,
    required int xpGanho,
  }) async {
    final userId = _currentUserId();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = CryptoEngine.instance.generateNonce();

    // Gera assinatura HMAC-SHA256 vinculando usuário, lição, XP e nonce
    final signature = await CryptoEngine.instance.signOutboxLesson(
      userId: userId,
      lessonId: licaoId,
      xpEarned: xpGanho,
      timestamp: timestamp,
      nonce: nonce,
    );

    final item = LessonOutboxItem(
      id: 'OUTBOX_${licaoId}_$nonce',
      userId: userId,
      licaoId: licaoId,
      acertos: acertos,
      totalExercicios: totalExercicios,
      tempoSegundos: tempoSegundos,
      bonusExploracaoXp: bonusExploracaoXp,
      xpGanho: xpGanho,
      timestamp: timestamp,
      nonce: nonce,
      signature: signature,
    );

    final currentQueue = await getPendingItems();
    currentQueue.add(item);
    await _savePendingItems(currentQueue);

    debugPrint('[LessonOutboxService] Lição $licaoId enfileirada no Outbox com sucesso (Total pendente: ${currentQueue.length})');

    // Tenta sincronizar silenciosamente em background caso a rede volte
    syncPendingLessons();

    return item;
  }

  /// Sincroniza todos os itens pendentes com o backend com proteção contra reentrância
  Future<void> syncPendingLessons() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingItems = await getPendingItems();
      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[LessonOutboxService] Iniciando sincronização de ${pendingItems.length} lições pendentes...');

      final remainingItems = <LessonOutboxItem>[];

      for (final item in pendingItems) {
        try {
          final url = '$_baseUrl/api/v1/trilha/licoes/${item.licaoId}/concluir/';
          final payload = {
            'acertos': item.acertos,
            'tempo_segundos': item.tempoSegundos,
            'bonus_exploracao_xp': item.bonusExploracaoXp,
            'xp_ganho': item.xpGanho,
            'timestamp': item.timestamp,
            'nonce': item.nonce,
            'signature': item.signature,
            'idempotency_key': item.nonce,
          };

          final response = await ApiClient.post(url, body: payload).timeout(
            const Duration(seconds: 8),
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('[LessonOutboxService] Lição ${item.licaoId} sincronizada com sucesso.');
            // Removido da fila
            continue;
          } else if (response.statusCode == 409 || response.statusCode == 403) {
            // Lição já concluída anteriormente ou conflito de concorrência — seguro descartar
            debugPrint('[LessonOutboxService] Lição ${item.licaoId} já constava concluída no servidor (${response.statusCode}). Descartando do outbox.');
            continue;
          } else {
            // Erro de validação temporário ou servidor indisponível — mantém na fila
            debugPrint('[LessonOutboxService] Falha temporária no servidor para lição ${item.licaoId}: ${response.statusCode}');
            remainingItems.add(item);
          }
        } catch (e) {
          debugPrint('[LessonOutboxService] Conexão falhou ao sincronizar lição ${item.licaoId}: $e');
          remainingItems.add(item);
        }
      }

      await _savePendingItems(remainingItems);
    } finally {
      _isSyncing = false;
    }
  }
}
