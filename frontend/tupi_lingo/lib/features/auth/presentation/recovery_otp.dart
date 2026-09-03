import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/auth/presentation/reset_password.dart';
import 'dart:async';

class _AppColors {
  static const Color background = Color(0xFFF3F2E8);
  static const Color subtitle = Color(0xFF565D6D);
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
  static const Color inputBorder = Color(0xFFD0D0D0);
}

class RecoveryOtpScreen extends StatefulWidget {
  final String email;

  const RecoveryOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<RecoveryOtpScreen> createState() => _RecoveryOtpScreenState();
}

class _RecoveryOtpScreenState extends State<RecoveryOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  bool _canResend = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;


  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _cooldownSeconds = 60; // 60 segundos de cooldown
    });
    
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
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

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();

    // FLUTTER-016: verificar que são exatamente 6 dígitos numéricos
    final isNumericOtp = RegExp(r'^\d{6}$').hasMatch(token);
    if (!isNumericOtp) {
      _showSnackBar('O código deve conter exatamente 6 dígitos numéricos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        token: token,
        email: widget.email,
      );

      if (!mounted) return;

      if (res.session != null) {
        _showSnackBar('Código verificado! Crie sua nova senha.', isError: false);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ResetPasswordScreen(),
          ),
        );
      } else {
         _showSnackBar('Código inválido ou expirado. Tente novamente.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (msg.toLowerCase().contains('invalid')) {
          msg = 'O código informado é inválido.';
        } else if (msg.toLowerCase().contains('expired')) {
          msg = 'Esse código expirou. Solicite um novo código.';
        }
        _showSnackBar(msg);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);
      if (mounted) {
        _showSnackBar('Código reenviado com sucesso!', isError: false);
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro ao reenviar código. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.background,
        elevation: 0,
        foregroundColor: _AppColors.accent,
        title: const Text('Recuperar Senha', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        'Insira o Código',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enviamos um código para o seu e-mail:\n${_maskEmail(widget.email)}',
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
                        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 8),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _AppColors.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _AppColors.primary, width: 2),
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

                      TextButton(
                        onPressed: (_isLoading || !_canResend) ? null : _resendCode,
                        child: Text(
                          _canResend ? 'Não recebeu o código? Reenviar' : 'Aguarde $_cooldownSeconds s para reenviar',
                          style: TextStyle(
                            color: _canResend ? _AppColors.accent : Colors.grey,
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
                    child: CircularProgressIndicator(
                      color: _AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
