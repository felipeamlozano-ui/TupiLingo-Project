import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class _AppColors {
  static const Color background = Color(0xFFF3F2E8);
  static const Color subtitle = Color(0xFF565D6D);
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
  static const Color inputBorder = Color(0xFFD0D0D0);
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

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color: isError ? Colors.red.shade700 : Colors.green.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black87,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.background,
        elevation: 0,
        foregroundColor: _AppColors.accent,
        title: const Text(
          'Verificar E-mail',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                      const Text(
                        'Confirme seu E-mail',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enviamos um código de 6 dígitos para:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: _AppColors.subtitle,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: _AppColors.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: _AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
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
                                : _AppColors.accent,
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
                  color: Colors.black26,
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
