import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/settings_service.dart';
import '../services/device_permissions_and_locale_service.dart';

/// Serviço de Notificações do TupiLingo.
/// Gerencia canal nativo Android de alta importância (`tupilingo_streak_channel`),
/// permissões nativas, sincronização com o Supabase e disparo de notificações
/// locais instantâneas e escuta de eventos agendados pelo `pg_cron` da Supabase.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _streakChannel = AndroidNotificationChannel(
    'tupilingo_streak_channel',
    'Ofensiva e Lembretes Diários',
    description: 'Canal dedicado a lembretes diários de ofensiva e prática em Tupi Antigo.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  bool _initialized = false;
  RealtimeChannel? _subscriptionChannel;

  /// Callback para disparar notificação visual / banner no aplicativo
  void Function(String title, String body, Map<String, dynamic>? payload)? onNotificationReceived;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Solicita permissões de notificação e localização aproximada (Zero-PII)
      await DevicePermissionsAndLocaleService.instance.requestPermissionsAndResolveLocale();

      // 2. Inicializa o plugin de notificações nativas
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Notificação tocada: ${response.payload}');
        },
      );

      // 3. Registra canal de alta importância no Android
      if (!kIsWeb) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_streakChannel);
        }
      }

      // 4. Conecta sessão ativa do Supabase e escuta fila de eventos
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await registerDeviceToken('device_token_${session.user.id.substring(0, 8)}');
        _listenForUserNotifications(session.user.id);
      }
    } catch (e) {
      debugPrint('[NotificationService] Erro ao inicializar notificações nativas: $e');
    }
  }

  /// Dispara uma notificação nativa instantânea na barra de status do celular
  Future<void> showNativeNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _streakChannel.id,
        _streakChannel.name,
        channelDescription: _streakChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      debugPrint('[NotificationService] Notificação nativa disparada: $title - $body');
    } catch (e) {
      debugPrint('[NotificationService] Erro ao exibir notificação nativa: $e');
    }
  }

  /// Registra ou atualiza o token push do dispositivo na tabela `users_push_tokens`
  Future<void> registerDeviceToken(String fcmToken) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

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
          .channel('public:notification_queue:$supabaseUid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notification_queue',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supabase_uid',
              value: supabaseUid,
            ),
            callback: (payload) async {
              final newRecord = payload.newRecord;
              if (newRecord['supabase_uid'] != null &&
                  newRecord['supabase_uid'].toString() != supabaseUid) {
                return;
              }
              final title = newRecord['title']?.toString() ?? 'TupiLingo — Lembrete de Ofensiva';
              final body = newRecord['body']?.toString() ?? 'Pratique sua lição de Tupi Antigo hoje para manter seus dias de estudo!';
              final notifType = newRecord['notification_type']?.toString() ?? 'streak_reminder';

              // Respeita as configurações do usuário
              if (notifType == 'streak_reminder' && !SettingsService.instance.dailyReminder) {
                return;
              }
              if (notifType == 'new_content' && !SettingsService.instance.contentUpdates) {
                return;
              }

              // Dispara notificação nativa na barra de status
              await showNativeNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: title,
                body: body,
                payload: notifType,
              );

              // Dispara banner / callback in-app
              onNotificationReceived?.call(
                title,
                body,
                newRecord['payload'] as Map<String, dynamic>?,
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[NotificationService] Erro ao subscrever a notification_queue: $e');
    }
  }

  void dispose() {
    _subscriptionChannel?.unsubscribe();
    _subscriptionChannel = null;
    _initialized = false;
  }
}
