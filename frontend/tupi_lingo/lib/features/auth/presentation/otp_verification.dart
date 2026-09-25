import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class _AppColors {
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
}

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String nivel;
  // SUPA-001: dados do onboarding para criar o perfil Django após OTP verificado
  final String? userName;
  final String? userSource;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.nivel,
    this.userName,
    this.userSource,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  // FLUTTER-014: cooldown de reenvio — igual ao recovery_otp.dart
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Trava o botão de reenviar por 60s pra não estourar limite de envio de e-mails
  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Exibe toast de alerta respeitando as cores e tema ativo
  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surface(context),
        elevation: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color: isError ? Colors.red.shade400 : Colors.green.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// SUPA-001: Registra o perfil do usuário no backend Django após OTP verificado.
  /// Este era o Split Brain Problem crítico — usuários email/senha nunca tinham
  /// UserProfile criado no Django, ficando em loop infinito de onboarding.
  Future<void> _registerUserInDjango(String accessToken) async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      // URLS-001: prefixo /api/v1/
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/register-user'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'name': widget.userName ?? '',
              'source': widget.userSource ?? '',
              'tupi_level': widget.nivel,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('[OTP] register-user status: ${response.statusCode}');
      }
    } catch (e) {
      // Falha silenciosa com log — não bloqueia a navegação
      // O AuthGate detectará exists=false e redirecionará para onboarding novamente
      if (kDebugMode) {
        debugPrint('[OTP] Erro ao registrar no Django: ${e.runtimeType}');
      }
    }
  }

  // Valida o token numérico de 6 dígitos no Supabase e cria o usuário no Django
  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();

    // FLUTTER-016: validar que são exatamente 6 dígitos numéricos
    final isNumericOtp = RegExp(r'^\d{6}$').hasMatch(token);
    if (!isNumericOtp) {
      _showSnackBar('O código deve conter exatamente 6 dígitos numéricos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: widget.email,
      );

      if (!mounted) return;

      if (res.session != null) {
        // SUPA-001: criar perfil no Django agora que temos sessão válida
        await _registerUserInDjango(res.session!.accessToken);

        if (!mounted) return;
        _showSnackBar('E-mail verificado com sucesso!', isError: false);

        if (widget.nivel == 'nenhum') {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TesteScreen(nivel: widget.nivel),
            ),
          );
        }
      } else {
        _showSnackBar('Código inválido. Tente novamente.');
      }
    } on AuthException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } catch (_) {
      if (mounted) _showSnackBar('Erro inesperado. Tente novamente mais tarde.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Solicita ao Supabase o reenvio do token de cadastro por e-mail
  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        _showSnackBar('Código reenviado com sucesso!', isError: false);
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } catch (_) {
      if (mounted) _showSnackBar('Erro ao reenviar código.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Constrói a tela de confirmação de código com campo de texto e ações
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        foregroundColor: AppTheme.textPrimary(context),
        title: Text(
          'Verificar E-mail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('✉️', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Confirme seu E-mail',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF1EC9A5) : _AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enviamos um código de 6 dígitos para:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: AppTheme.surface(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.border(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppTheme.border(context)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(
                                color: _AppColors.primary, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _verifyOtp(),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'VERIFICAR CÓDIGO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FLUTTER-014: botão de reenvio com cooldown de 60 segundos
                      TextButton(
                        onPressed: (_isLoading || _resendCooldown > 0)
                            ? null
                            : _resendCode,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Reenviar em ${_resendCooldown}s'
                              : 'Não recebeu o código? Reenviar',
                          style: TextStyle(
                            color: _resendCooldown > 0
                                ? Colors.grey
                                : (isDark ? const Color(0xFF1EC9A5) : _AppColors.accent),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: _AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
