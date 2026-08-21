import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tupi_lingo/recovery_otp.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // O login com Google (OAuth) abre o navegador. Quando o usuário volta,
    // o Supabase processa o link e dispara um evento. Precisamos ouvir esse evento!
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Quando o Supabase confirma que o usuário fez login via Google,
      // redirecionamos para o AuthGate ('/') que decidirá se vai para
      // /home (já registrado) ou /register (novo usuário).
      if (data.event == AuthChangeEvent.signedIn) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =========================
  // SNACKBAR BONITO (ERROS)
  // =========================
  void _showErrorSnackBar({
    required String title,
    required String message,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 16,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // LOGIN EMAIL/SENHA
  // =========================
  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar(
        title: 'Campo obrigatório',
        message: 'Digite seu e-mail para continuar.',
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar(
        title: 'Campo obrigatório',
        message: 'Digite sua senha para continuar.',
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      String errorTitle = 'Falha no login';
      
      if (e.message.toLowerCase().contains('email not confirmed')) {
        errorTitle = 'E-mail não verificado';
        errorMessage = 'Por favor, verifique a caixa de entrada do seu e-mail e valide o código recebido.';
      } else if (e.message.toLowerCase().contains('invalid login credentials')) {
        errorMessage = 'E-mail ou senha incorretos.';
      }
      
      _showErrorSnackBar(
        title: errorTitle,
        message: errorMessage,
      );
    } catch (e, stackTrace) {
      debugPrint('LOGIN EMAIL ERRO: $e');
      debugPrint('STACKTRACE: $stackTrace');
      _showErrorSnackBar(
        title: 'Erro inesperado',
        message: 'Tente novamente mais tarde.',
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================
  // LOGIN GOOGLE (OAuth)
  // =========================
  Future<void> _handleGoogleLogin() async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
      } else {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'tupilingo://callback',
        );
      }
    // [Auditoria 3.2] Registra internamente o erro + stacktrace para debug
    } catch (e, stackTrace) {
      debugPrint('LOGIN GOOGLE ERRO: $e');
      debugPrint('STACKTRACE: $stackTrace');
      _showErrorSnackBar(
        title: 'Erro Google',
        message: 'Não foi possível conectar com Google. Erro: $e',
      );
    } finally {
      // [Auditoria 3.1] Checagem mounted antes de setState para evitar memory leak
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================
  // RECUPERACAO DE SENHA
  // =========================
  Future<void> _handleForgotPassword() async {
    String email = _emailController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          final TextEditingController dialogEmailController = TextEditingController();
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Recuperar Senha', style: TextStyle(color: Color(0xFFB8AF64), fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Digite seu e-mail para receber o código de recuperação.', style: TextStyle(color: Color(0xFF565D6D))),
                const SizedBox(height: 16),
                TextField(
                  controller: dialogEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, dialogEmailController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD08A45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      );
      
      if (result == null || result.isEmpty) return;
      email = result;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Se esse e-mail estiver cadastrado, enviaremos um código para recuperação da conta.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          )
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecoveryOtpScreen(email: email)),
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        title: 'Erro de conexão',
        message: 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),

      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFF3F2E8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'TupiLingo',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),

      body: Center(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Entrar',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Faça login ou use sua conta Google',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF565D6D),
                        ),
                      ),

                      const SizedBox(height: 30),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD08A45),
                          ),
                          child: const Text(
                            'Esqueci minha senha',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Botão: Entrar com Email/Senha
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  await _handleLogin();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD08A45),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Entrar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botão principal: Login com Google
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  // [Auditoria 2.1] Removido Future.delayed(4s)
                                  await _handleGoogleLogin();
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFD0D0D0),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/google_logo.png',
                                width: 22,
                                height: 22,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'ENTRAR COM GOOGLE',
                                style: TextStyle(
                                  color: Color(0xFFD08A45),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
