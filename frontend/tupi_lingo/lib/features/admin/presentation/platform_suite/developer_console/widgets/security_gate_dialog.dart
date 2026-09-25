import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import 'package:tupi_lingo/core/security/developer_enclave_session.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Modal de autenticação em dois fatores (Passcode Mestre + OTP por e-mail) para proteger o Enclave de Desenvolvedor.
class SecurityGateDialog {
  // Abre o diálogo de autorização e só executa o callback pós-validação se o OTP for aceito.
  static Future<void> show(
    BuildContext context, {
    required String authorizedEmail,
    required VoidCallback onAuthorized,
  }) async {
    final passCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    bool otpSent = false;
    bool dialogLoading = false;
    String? dialogError;
    String? dialogNotice;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface(dialogCtx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.border(dialogCtx)),
            ),
            title: Row(
              children: [
                Icon(Icons.security_rounded, color: AppTheme.accent(dialogCtx), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enclave de Segurança Dev',
                    style: TextStyle(
                      color: AppTheme.textPrimary(dialogCtx),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acesso restrito ao desenvolvedor principal ($authorizedEmail). Requer Master Passcode e código OTP enviado ao e-mail com sessão de 30 minutos.',
                    style: TextStyle(color: AppTheme.textSecondary(dialogCtx), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (dialogNotice != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogNotice!,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    enabled: !otpSent,
                    decoration: InputDecoration(
                      labelText: 'Master Passcode',
                      labelStyle: TextStyle(color: AppTheme.textSecondary(dialogCtx)),
                      prefixIcon: Icon(Icons.password_rounded, color: AppTheme.accent(dialogCtx)),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle(dialogCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!otpSent)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent(dialogCtx),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: dialogLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Solicitar OTP de 6 dígitos', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                const kMasterPasscode = 'tupi_master_2026';
                                if (passCtrl.text.trim() != kMasterPasscode) {
                                  setDialogState(() {
                                    dialogError = 'Master Passcode incorreto.';
                                    dialogNotice = null;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  dialogLoading = true;
                                  dialogError = null;
                                  dialogNotice = null;
                                });

                                try {
                                  final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/auth/otp/request/');
                                  final res = await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({
                                      'email': authorizedEmail,
                                      'passcode': passCtrl.text.trim(),
                                    }),
                                  ).timeout(const Duration(seconds: 6));
                                  final data = jsonDecode(res.body);
                                  if (res.statusCode == 200 && data['success'] == true) {
                                    setDialogState(() {
                                      otpSent = true;
                                      dialogLoading = false;
                                      dialogError = null;
                                      dialogNotice = data['message'] ??
                                          'Código OTP de 6 dígitos enviado para $authorizedEmail! Verifique sua caixa de entrada.';
                                      otpCtrl.clear();
                                    });
                                  } else {
                                    setDialogState(() {
                                      dialogError = data['message'] ?? 'Falha ao solicitar código OTP.';
                                      dialogLoading = false;
                                    });
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    dialogLoading = false;
                                    dialogError = 'Falha ao conectar com o servidor para enviar o código OTP.';
                                  });
                                }
                              },
                      ),
                    )
                  else ...[
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        labelText: 'Código OTP (6 dígitos)',
                        labelStyle: TextStyle(color: AppTheme.textSecondary(dialogCtx)),
                        hintText: '• • • • • •',
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle(dialogCtx),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent(dialogCtx),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: dialogLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text('Validar e Desbloquear', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                final code = otpCtrl.text.trim();
                                if (code.length != 6) {
                                  setDialogState(() {
                                    dialogError = 'Por favor, digite os 6 dígitos recebidos no seu e-mail.';
                                    dialogNotice = null;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  dialogLoading = true;
                                  dialogError = null;
                                  dialogNotice = null;
                                });

                                bool isAuthValid = false;
                                String sessionToken = 'dev_session_${DateTime.now().millisecondsSinceEpoch}';

                                try {
                                  final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/auth/otp/verify/');
                                  final res = await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({
                                      'email': authorizedEmail,
                                      'code': code,
                                    }),
                                  ).timeout(const Duration(seconds: 6));
                                  final data = jsonDecode(res.body);
                                  if (res.statusCode == 200 && data['success'] == true) {
                                    isAuthValid = true;
                                    sessionToken = data['session_token'] ?? sessionToken;
                                  } else {
                                    setDialogState(() {
                                      dialogError = data['message'] ?? 'Código OTP incorreto ou expirado.';
                                      dialogLoading = false;
                                    });
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    dialogError = 'Falha de conexão com o servidor ao validar o código OTP.';
                                    dialogLoading = false;
                                  });
                                }

                                if (isAuthValid) {
                                  await DeveloperEnclaveSession.instance.unlock(sessionToken);
                                  AppLogger.sec(
                                    'ENCLAVE_AUTH',
                                    'Enclave desbloqueado por $authorizedEmail com validação OTP manual.',
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                  onAuthorized();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text('Enclave Desbloqueado! Sessão preservada por 30 minutos.'),
                                          ],
                                        ),
                                        backgroundColor: AppTheme.accent(context),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() {
                                    dialogError ??= 'Código incorreto ou expirado. Tente novamente.';
                                    dialogLoading = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary(dialogCtx))),
              ),
            ],
          );
        },
      ),
    );
  }
}
