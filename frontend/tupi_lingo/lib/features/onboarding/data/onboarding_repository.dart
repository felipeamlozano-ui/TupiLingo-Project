import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/onboarding_draft.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';

/// Repositório para persistência local de rascunhos de onboarding e controle de exibição do tour guiado.
class OnboardingRepository {
  OnboardingRepository._();
  static final OnboardingRepository instance = OnboardingRepository._();

  static const String _draftKey = 'tupilingo_onboarding_draft_v1';
  static const String _completedKeyPrefix = 'tupilingo_onboarding_completed_v1_';
  static const String _tourPart1KeyPrefix = 'tupilingo_tour_part1_v1_';
  static const String _tourPart2KeyPrefix = 'tupilingo_tour_part2_v1_';
  static const String _tourFullV2KeyPrefix = 'tupilingo_tour_full_v2_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _userKey(String prefix, [String? userId]) {
    final uid = userId ?? Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return '$prefix$uid';
  }

  /// Salva o estado atual das respostas do onboarding pré-cadastro.
  Future<void> saveDraft(OnboardingDraft draft) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_draftKey, draft.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('[OnboardingRepo] Erro ao salvar rascunho: $e');
    }
  }

  /// Recupera o rascunho salvo do onboarding, se houver.
  Future<OnboardingDraft?> loadDraft() async {
    try {
      final prefs = await _getPrefs();
      final str = prefs.getString(_draftKey);
      if (str != null && str.isNotEmpty) {
        return OnboardingDraft.fromJson(str);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OnboardingRepo] Erro ao carregar rascunho: $e');
    }
    return null;
  }

  /// Limpa o rascunho local após a conclusão com sucesso do cadastro.
  Future<void> clearDraft() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  /// Verifica se o onboarding foi concluído para o usuário especificado.
  Future<bool> isOnboardingCompleted([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_userKey(_completedKeyPrefix, userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marca o onboarding como concluído para o usuário.
  Future<void> setOnboardingCompleted([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_userKey(_completedKeyPrefix, userId), true);
    } catch (_) {}
  }

  /// Verifica se o Tour Guiado Completo da Home já foi exibido.
  Future<bool> isFullTourCompleted([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_userKey(_tourFullV2KeyPrefix, userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marca o Tour Guiado Completo como concluído.
  Future<void> setFullTourCompleted([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_userKey(_tourFullV2KeyPrefix, userId), true);
      await prefs.setBool(_userKey(_tourPart1KeyPrefix, userId), true);
      await prefs.setBool(_userKey(_tourPart2KeyPrefix, userId), true);
      _syncTourProgressToBackend(part1: true, part2: true);
    } catch (_) {}
  }

  /// Redefine o estado do tour para permitir ao usuário rever todo o tour.
  Future<void> resetTourStatus([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_userKey(_tourFullV2KeyPrefix, userId));
      await prefs.remove(_userKey(_tourPart1KeyPrefix, userId));
      await prefs.remove(_userKey(_tourPart2KeyPrefix, userId));
    } catch (_) {}
  }

  /// Verifica se a Parte 1 do Tour Guiado da Home já foi exibida (legado).
  Future<bool> isTourPart1Completed([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_userKey(_tourPart1KeyPrefix, userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marca a Parte 1 do Tour como concluída (legado).
  Future<void> setTourPart1Completed([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_userKey(_tourPart1KeyPrefix, userId), true);
      _syncTourProgressToBackend(part1: true);
    } catch (_) {}
  }

  /// Verifica se a Parte 2 do Tour Guiado da Home já foi exibida (legado).
  Future<bool> isTourPart2Completed([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_userKey(_tourPart2KeyPrefix, userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marca a Parte 2 do Tour como concluída (legado).
  Future<void> setTourPart2Completed([String? userId]) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_userKey(_tourPart2KeyPrefix, userId), true);
      _syncTourProgressToBackend(part2: true);
    } catch (_) {}
  }

  /// Envia assincronamente o progresso do tour para o backend Django quando o usuário estiver autenticado.
  void _syncTourProgressToBackend({bool? part1, bool? part2}) {
    Future.microtask(() async {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return;

        final baseUrl = AppConfig.backendBaseUrl;
        await ApiClient.post(
          '$baseUrl/api/v1/auth/onboarding',
          body: {
            'tour_part1': ?part1,
            'tour_part2': ?part2,
          },
        );
      } catch (_) {}
    });
  }
}
