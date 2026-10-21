import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/network/api_cache_manager.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tupi_lingo/features/store/services/store_service.dart';

/// Serviço centralizado de autenticação do TupiLingo.
/// 
/// Gerencia fluxos de Login, Cadastro, Recuperação de Senha e Reenvio de Código OTP.
/// Implementa failover automático para a ponte de autenticação do backend Django
/// caso o Supabase Cloud bloqueie requisições diretas de clientes sem token de Captcha.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String get _baseUrl => AppConfig.backendBaseUrl;

  bool _isCaptchaError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('captcha') || msg.contains('captcha_failed') || msg.contains('no captcha_token found');
  }

  /// Retorna a URL canônica de redirecionamento para autenticação OAuth, confirmação de e-mail e recuperação de senha.
  static String getAuthRedirectUrl() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final host = Uri.base.host;
      final path = Uri.base.path;
      if (host.contains('github.io') || path.contains('/TupiLingo-Project/app')) {
        return '$origin/TupiLingo-Project/app/';
      }
      return '$origin/';
    }
    return 'tupilingo://callback';
  }

  /// Realiza login com e-mail e senha.
  /// 
  /// Tenta primeiro autenticação direta via Supabase Auth. Se houver exigência de Captcha
  /// não atendida pelo cliente, aciona transparentemente o endpoint autorizado do backend Django.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password;

    if (cleanEmail.isEmpty) {
      throw const AuthException('Digite seu e-mail para continuar.');
    }
    if (cleanPassword.isEmpty) {
      throw const AuthException('Digite sua senha para continuar.');
    }

    try {
      if (kDebugMode) {
        debugPrint('[AuthService] Tentando login direto via Supabase Auth...');
      }
      await Supabase.instance.client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      await ApiCacheManager.instance.clearAll();
      DashboardRepositoryImpl.invalidateCache();
      StoreService.instance.clearUserCache();
      await ThemeNotifier.instance.reloadForUser();
      if (kDebugMode) {
        debugPrint('[AuthService] Login direto via Supabase concluído com sucesso e cache limpo.');
      }
      return;
    } on AuthException catch (e) {
      if (_isCaptchaError(e.message)) {
        if (kDebugMode) {
          debugPrint('[AuthService] Supabase direto bloqueado por Captcha. Acionando ponte segura Django...');
        }
        await _loginViaBackend(cleanEmail, cleanPassword);
        await ApiCacheManager.instance.clearAll();
        DashboardRepositoryImpl.invalidateCache();
        StoreService.instance.clearUserCache();
        await ThemeNotifier.instance.reloadForUser();
        return;
      }
      throw _translateAuthException(e);
    } catch (e) {
      if (_isCaptchaError(e)) {
        await _loginViaBackend(cleanEmail, cleanPassword);
        await ApiCacheManager.instance.clearAll();
        DashboardRepositoryImpl.invalidateCache();
        StoreService.instance.clearUserCache();
        await ThemeNotifier.instance.reloadForUser();
        return;
      }
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || e.toString().contains('ClientException')) {
        throw const AuthException('Não foi possível conectar ao servidor. Verifique sua conexão com a internet.');
      }
      rethrow;
    }
  }

  Future<void> _loginViaBackend(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/login');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final refreshToken = data['refresh_token'] as String?;
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await Supabase.instance.client.auth.setSession(refreshToken);
          if (kDebugMode) {
            debugPrint('[AuthService] Sessão Supabase restabelecida via ponte segura com refresh_token.');
          }
          return;
        }
        throw const AuthException('Sessão recebida sem token de renovação.');
      }

      final errorMsg = data['error'] as String? ?? 'Falha ao autenticar usuário.';
      throw AuthException(errorMsg, statusCode: response.statusCode.toString());
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw const AuthException('Não foi possível conectar ao servidor. Verifique sua internet.');
      }
      throw AuthException('Erro ao processar login: $e');
    }
  }

  /// Realiza cadastro de nova conta com nome, e-mail, senha e nível inicial.
  Future<User?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String source,
    required String tupiLevel,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password;
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw const AuthException('Por favor, informe seu nome.');
    }
    if (cleanEmail.isEmpty) {
      throw const AuthException('Por favor, informe seu e-mail.');
    }
    if (cleanPassword.length < 6) {
      throw const AuthException('A senha deve conter no mínimo 6 caracteres.');
    }

    try {
      if (kDebugMode) {
        debugPrint('[AuthService] Tentando cadastro direto via Supabase Auth...');
      }
      final emailRedirectUri = kIsWeb ? AuthService.getAuthRedirectUrl() : null;
      final res = await Supabase.instance.client.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
        emailRedirectTo: emailRedirectUri,
        data: {
          'name': cleanName,
          'source': source,
          'tupi_level': tupiLevel,
        },
      );

      final user = res.user;
      if (user != null) {
        // SEGURANÇA & ANTI-DEADLOCK: O Supabase GoTrue retorna 'identities: []'
        // quando o e-mail já existe na base (prevent email enumeration ativo).
        final identities = user.identities;
        if (identities != null && identities.isEmpty) {
          if (kDebugMode) {
            debugPrint('[AuthService] Tentativa de cadastro com e-mail já existente detectada (identities vazias).');
          }
          throw const AuthException(
            'Este e-mail já está cadastrado. Faça login para continuar.',
            statusCode: '409',
          );
        }

        // Se o usuário já possuía confirmação e não foi gerada nova sessão
        if (user.emailConfirmedAt != null && res.session == null) {
          throw const AuthException(
            'Este e-mail já está cadastrado. Faça login para continuar.',
            statusCode: '409',
          );
        }
      } else {
        throw const AuthException('Não foi possível concluir o cadastro.');
      }

      await ApiCacheManager.instance.clearAll();
      DashboardRepositoryImpl.invalidateCache();
      StoreService.instance.clearUserCache();
      await ThemeNotifier.instance.reloadForUser();
      if (kDebugMode) {
        debugPrint('[AuthService] Cadastro direto via Supabase concluído com sucesso.');
      }
      return res.user;
    } on AuthException catch (e) {
      if (_isCaptchaError(e.message)) {
        if (kDebugMode) {
          debugPrint('[AuthService] Cadastro direto bloqueado por Captcha. Acionando ponte segura Django...');
        }
        return await _registerViaBackend(
          email: cleanEmail,
          password: cleanPassword,
          name: cleanName,
          source: source,
          tupiLevel: tupiLevel,
        );
      }
      throw _translateAuthException(e);
    } catch (e) {
      if (_isCaptchaError(e)) {
        return await _registerViaBackend(
          email: cleanEmail,
          password: cleanPassword,
          name: cleanName,
          source: source,
          tupiLevel: tupiLevel,
        );
      }
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || e.toString().contains('ClientException')) {
        throw const AuthException('Não foi possível conectar ao servidor. Verifique sua conexão com a internet.');
      }
      rethrow;
    }
  }

  Future<User?> _registerViaBackend({
    required String email,
    required String password,
    required String name,
    required String source,
    required String tupiLevel,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/register');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'source': source,
          'tupi_level': tupiLevel,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await ApiCacheManager.instance.clearAll();
        DashboardRepositoryImpl.invalidateCache();
        StoreService.instance.clearUserCache();
        await ThemeNotifier.instance.reloadForUser();
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          return User.fromJson(userData);
        }
        return null;
      }

      if (response.statusCode == 409 || data['code'] == 'already_registered') {
        throw AuthException(
          data['error'] as String? ?? 'Este e-mail já está cadastrado. Faça login para continuar.',
          statusCode: '409',
        );
      }

      final errorMsg = data['error'] as String? ?? 'Não foi possível cadastrar a conta.';
      throw AuthException(errorMsg, statusCode: response.statusCode.toString());
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is http.ClientException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw const AuthException('Não foi possível conectar ao servidor. Verifique sua internet.');
      }
      throw AuthException('Erro ao processar cadastro: $e');
    }
  }

  /// Solicita recuperação de senha enviando código OTP para o e-mail.
  Future<void> recoverPassword(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw const AuthException('Por favor, informe seu e-mail.');
    }

    try {
      final resetRedirectUri = AuthService.getAuthRedirectUrl();
      await Supabase.instance.client.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: resetRedirectUri,
      );
    } on AuthException catch (e) {
      if (_isCaptchaError(e.message)) {
        await _recoverViaBackend(cleanEmail);
        return;
      }
      throw _translateAuthException(e);
    } catch (e) {
      if (_isCaptchaError(e)) {
        await _recoverViaBackend(cleanEmail);
        return;
      }
      rethrow;
    }
  }

  Future<void> _recoverViaBackend(String email) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/recover-password');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(data['error'] as String? ?? 'Erro ao enviar recuperação de senha.');
    }
  }

  /// Reenvia o código OTP (cadastro ou recuperação).
  Future<void> resendVerificationCode({
    required String email,
    OtpType type = OtpType.signup,
  }) async {
    final cleanEmail = email.trim();
    try {
      await Supabase.instance.client.auth.resend(
        type: type,
        email: cleanEmail,
      );
    } on AuthException catch (e) {
      if (_isCaptchaError(e.message)) {
        await _resendViaBackend(cleanEmail, type == OtpType.signup ? 'signup' : 'recovery');
        return;
      }
      throw _translateAuthException(e);
    } catch (e) {
      if (_isCaptchaError(e)) {
        await _resendViaBackend(cleanEmail, type == OtpType.signup ? 'signup' : 'recovery');
        return;
      }
      rethrow;
    }
  }

  Future<void> _resendViaBackend(String email, String type) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/resend-code');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'type': type}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw AuthException(data['error'] as String? ?? 'Erro ao reenviar código.');
    }
  }

  /// Traduz mensagens técnicas do Supabase em avisos claros e humanizados em português.
  AuthException _translateAuthException(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return const AuthException('E-mail ou senha incorretos. Verifique suas credenciais.');
    }
    if (msg.contains('email not confirmed')) {
      return const AuthException('E-mail ainda não verificado. Por favor, valide o código recebido no seu e-mail.');
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('user_already_exists') ||
        e.statusCode == '409') {
      return const AuthException(
        'Este e-mail já está cadastrado. Faça login para continuar.',
        statusCode: '409',
      );
    }
    if (msg.contains('over_request_rate_limit') || msg.contains('too many requests')) {
      return const AuthException('Muitas tentativas em pouco tempo. Aguarde alguns instantes e tente novamente.');
    }
    if (msg.contains('network') || msg.contains('failed host lookup') || msg.contains('socket')) {
      return const AuthException('Não foi possível conectar ao servidor. Verifique sua conexão com a internet.');
    }
    if (msg.contains('user not found')) {
      return const AuthException('Conta não encontrada para este e-mail. Crie sua conta primeiro.');
    }

    return e;
  }
}
