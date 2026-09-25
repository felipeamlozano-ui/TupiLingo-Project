import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

class _AppColors {
  static const Color primary = Color(0xFFD08A45);
  static const Color accent = Color(0xFF0E5D4E);
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentSession == null) {
        _showSnackBar('Sessão inválida. Por favor, tente recuperar novamente.');
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Exibe snackbar com ícone indicativo de sucesso ou erro seguindo as cores do tema
  void _showSnackBar(String message, {bool isError = true}) {
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

  // Valida a força da nova senha e salva no Supabase Auth deslogando a sessão temporária
  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Preencha todos os campos.');
      return;
    }

    // FLUTTER-017: política de senha mais forte
    if (password.length < 8) {
      _showSnackBar('A nova senha deve ter pelo menos 8 caracteres.');
      return;
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      _showSnackBar('A senha deve conter pelo menos um número.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('As senhas não coincidem.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // atualiza a senha lá no auth do supabase
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      _showSnackBar('Senha atualizada com sucesso! Faça login novamente.', isError: false);
      
      // desloga da sessão temporária de recuperação pra forçar login novo
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      // limpa a pilha e manda pra tela de login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      
    } on AuthException catch (e) {

      if (mounted) {
        _showSnackBar(e.message);
      }

    } catch (e) {
      if (mounted) {
        _showSnackBar('Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Renderiza os campos de senha com botões de alternar visualização do texto
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
          'Nova Senha',
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
                          child: Icon(Icons.lock_reset, size: 40, color: _AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Redefinir Senha',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF1EC9A5) : _AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Crie uma nova senha de pelo menos 6 caracteres para a sua conta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Nova senha',
                          labelStyle: TextStyle(color: AppTheme.textSecondary(context)),
                          filled: true,
                          fillColor: AppTheme.surface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border(context)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: _AppColors.primary, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textSecondary(context),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Confirmar nova senha',
                          labelStyle: TextStyle(color: AppTheme.textSecondary(context)),
                          filled: true,
                          fillColor: AppTheme.surface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border(context)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: _AppColors.primary, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textSecondary(context),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'ATUALIZAR SENHA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
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
