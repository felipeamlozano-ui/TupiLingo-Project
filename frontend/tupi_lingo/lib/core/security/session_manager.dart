import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gerenciador de sessão JWT resiliente para Web e Mobile.
///
/// Mantém espelhamento estruturado das credenciais da sessão em [SharedPreferences],
/// com validação de expiração (`expires_at`), renovação antecipada (`refreshSession`)
/// e tolerância a falhas transitórias de rede no F5/Reload (evita deslogar o usuário).
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const String _keyAccessToken = 'tupilingo_jwt_access_token';
  static const String _keyRefreshToken = 'tupilingo_jwt_refresh_token';
  static const String _keyExpiresAt = 'tupilingo_jwt_expires_at';
  static const String _keyUserId = 'tupilingo_user_id';

  /// Salva e espelha os dados da sessão do Supabase no SharedPreferences.
  Future<void> saveSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, session.accessToken);
      if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
        await prefs.setString(_keyRefreshToken, session.refreshToken!);
      }
      if (session.expiresAt != null) {
        await prefs.setInt(_keyExpiresAt, session.expiresAt!);
      }
      await prefs.setString(_keyUserId, session.user.id);
      if (kDebugMode) {
        debugPrint('[SessionManager] Sessão espelhada com sucesso no cache local (expiresAt=${session.expiresAt}).');
      }
    } catch (e) {
      debugPrint('[SessionManager] Erro ao persistir sessão no cache local: $e');
    }
  }

  /// Limpa os dados de sessão do SharedPreferences.
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyExpiresAt);
      await prefs.remove(_keyUserId);
      if (kDebugMode) {
        debugPrint('[SessionManager] Cache local de sessão limpo.');
      }
    } catch (e) {
      debugPrint('[SessionManager] Erro ao limpar cache local: $e');
    }
  }

  /// Retorna o refresh token em cache local, se existir.
  Future<String?> getCachedRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Retorna o access token em cache local, se existir.
  Future<String?> getCachedAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    } catch (_) {
      return null;
    }
  }

  /// Tenta restaurar a sessão no cliente Supabase usando o refresh token em cache.
  Future<Session?> restoreSessionFromCache() async {
    final cachedRefreshToken = await getCachedRefreshToken();
    if (cachedRefreshToken == null || cachedRefreshToken.isEmpty) {
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint('[SessionManager] Tentando restaurar sessão via refresh_token em cache...');
      }
      final response = await Supabase.instance.client.auth.setSession(cachedRefreshToken);
      if (response.session != null) {
        await saveSession(response.session!);
        return response.session;
      }
    } on AuthException catch (e) {
      // Refresh token revogado ou inválido
      debugPrint('[SessionManager] Falha de autenticação ao restaurar sessão: ${e.message}');
      await clearSession();
    } catch (e) {
      // Erro transitório de rede - não limpa o cache
      debugPrint('[SessionManager] Erro de rede ao restaurar sessão: $e');
    }
    return null;
  }

  /// Obtém um token de acesso válido, renovando antecipadamente se estiver próximo do vencimento (< 120s).
  Future<String?> getValidAccessToken() async {
    var session = Supabase.instance.client.auth.currentSession;

    // Se o cliente Supabase não tiver sessão em memória, tenta recuperar do cache local
    session ??= await restoreSessionFromCache();

    if (session == null) {
      return await getCachedAccessToken();
    }

    final expiresAt = session.expiresAt;
    final isExpiringSoon = expiresAt != null &&
        (DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                .difference(DateTime.now())
                .inSeconds <
            120);

    if (session.isExpired || isExpiringSoon) {
      try {
        if (kDebugMode) {
          debugPrint('[SessionManager] Token expirado ou próximo de expirar. Renovando...');
        }
        final refreshRes = await Supabase.instance.client.auth.refreshSession();
        if (refreshRes.session != null) {
          session = refreshRes.session!;
          await saveSession(session);
          return session.accessToken;
        }
      } on AuthException catch (e) {
        debugPrint('[SessionManager] Erro de autenticação ao renovar token: ${e.message}');
        if (e.statusCode == '401' || e.message.toLowerCase().contains('invalid')) {
          await clearSession();
          return null;
        }
      } catch (e) {
        debugPrint('[SessionManager] Erro de rede ao renovar token (mantendo token atual): $e');
      }
    }

    return session?.accessToken;
  }

  /// Valida e renova a sessão para o AuthGate em `_checkAuth`.
  ///
  /// Retorna `true` se a sessão for válida (ou recuperável localmente),
  /// e `false` se não houver sessão ou se as credenciais forem definitivamente inválidas.
  /// **NUNCA** destrói a sessão local por erros transitórios de rede (ex: F5 offline ou oscilação).
  Future<bool> validateAndRefreshSession() async {
    var session = Supabase.instance.client.auth.currentSession;

    // 1. Tenta restaurar do cache se Supabase não tiver carregado em memória ainda
    session ??= await restoreSessionFromCache();

    if (session == null) {
      if (kDebugMode) {
        debugPrint('[SessionManager] Nenhuma sessão encontrada em memória ou cache.');
      }
      return false;
    }

    // 2. Salva o estado atual no cache para garantir coerência
    await saveSession(session);

    // 3. Verifica expiração e renova se necessário
    final expiresAt = session.expiresAt;
    final isExpiringSoon = expiresAt != null &&
        (DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                .difference(DateTime.now())
                .inSeconds <
            120);

    if (session.isExpired || isExpiringSoon) {
      try {
        if (kDebugMode) {
          debugPrint('[SessionManager] Renovando sessão no AuthGate...');
        }
        final refreshRes = await Supabase.instance.client.auth.refreshSession();
        if (refreshRes.session != null) {
          session = refreshRes.session!;
          await saveSession(session);
        }
      } on AuthException catch (e) {
        debugPrint('[SessionManager] AuthException na renovação AuthGate: ${e.message}');
        if (e.statusCode == '401' || e.message.toLowerCase().contains('invalid')) {
          await clearSession();
          return false;
        }
      } catch (e) {
        // Erro de rede na renovação: preserva sessão para tentar operar offline/cache
        debugPrint('[SessionManager] Falha transitória de rede na renovação: $e. Mantendo sessão.');
      }
    }

    // 4. Validação remota defensiva (getUser) - Não destrutiva
    try {
      await Supabase.instance.client.auth.getUser();
      return true;
    } on AuthException catch (authErr) {
      debugPrint('[SessionManager] AuthException em getUser: ${authErr.message}');
      if (authErr.statusCode == '401' || authErr.message.toLowerCase().contains('invalid')) {
        // Tenta um último refresh antes de declarar a sessão inválida
        try {
          final retryRefresh = await Supabase.instance.client.auth.refreshSession();
          if (retryRefresh.session != null) {
            await saveSession(retryRefresh.session!);
            return true;
          }
        } catch (_) {}
        await clearSession();
        return false;
      }
      // Se for outro erro de auth sem status 401, tolera temporariamente
      return true;
    } catch (networkErr) {
      // Erro de rede/timeout/socket no getUser:
      // CRÍTICO: NÃO destrói credenciais do localStorage! O usuário não deve ser deslogado por oscilação de internet.
      debugPrint('[SessionManager] Falha de conexão ao validar usuário com Supabase: $networkErr. Sessão mantida.');
      return true;
    }
  }
}
