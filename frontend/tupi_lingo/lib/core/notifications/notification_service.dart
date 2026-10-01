import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/settings_service.dart';

/// Serviço de Notificações do TupiLingo.
/// Gerencia o registro do token do dispositivo, sincronização com o Supabase
/// e escuta de lembretes periódicos agendados pelo `pg_cron` (Streak e Conteúdos Novos).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  RealtimeChannel? _subscriptionChannel;

  /// Callback para disparar notificação visual / banner no aplicativo
  void Function(String title, String body, Map<String, dynamic>? payload)? onNotificationReceived;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await registerDeviceToken('simulated_device_token_${session.user.id.substring(0, 8)}');
        _listenForUserNotifications(session.user.id);
      }
    } catch (e) {
      debugPrint('[NotificationService] Erro ao inicializar notificações: $e');
    }
  }

  /// Registra ou atualiza o token push do dispositivo na tabela `users_push_tokens`
  Future<void> registerDeviceToken(String fcmToken) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // Obtém o ID numérico do usuário
      final userProfile = await client
          .from('users_userprofile')
          .select('id')
          .eq('supabase_uid', userId)
          .maybeSingle();

      if (userProfile != null && userProfile['id'] != null) {
        final int profileId = userProfile['id'];
        await client.from('users_push_tokens').upsert({
          'user_id': profileId,
          'fcm_token': fcmToken,
          'device_os': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'streak_notifications_enabled': SettingsService.instance.dailyReminder,
          'content_notifications_enabled': SettingsService.instance.contentUpdates,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,fcm_token');
        debugPrint('[NotificationService] Token push sincronizado para usuário $profileId.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Falha ao registrar token: $e');
    }
  }

  /// Escuta notificações pendentes na fila gerada pelo pg_cron
  void _listenForUserNotifications(String supabaseUid) {
    try {
      final client = Supabase.instance.client;
      _subscriptionChannel = client
          .channel('public:notification_queue')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notification_queue',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final title = newRecord['title']?.toString() ?? 'TupiLingo';
              final body = newRecord['body']?.toString() ?? '';
              final notifType = newRecord['notification_type']?.toString();

              // Respeita as configurações do usuário
              if (notifType == 'streak_reminder' && !SettingsService.instance.dailyReminder) {
                return;
              }
              if (notifType == 'new_content' && !SettingsService.instance.contentUpdates) {
                return;
              }

              onNotificationReceived?.call(
                title,
                body,
                newRecord['payload'] as Map<String, dynamic>?,
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[NotificationService] Erro ao subscrever canal de notificações: $e');
    }
  }

  void dispose() {
    _subscriptionChannel?.unsubscribe();
    _subscriptionChannel = null;
    _initialized = false;
  }
}
