import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import 'package:tupi_lingo/core/security/developer_enclave_session.dart';
import 'package:tupi_lingo/core/telemetry/telemetry_service.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/feature_flags/application/providers/feature_flag_provider.dart';
import 'widgets/developer_console_tabs.dart';
import 'widgets/security_gate_dialog.dart';
import 'widgets/zero_leak_logs_tab.dart';

// Painel central de controle para Live Ops, métricas de renderização do Impeller e flags em tempo de execução.
class DeveloperConsoleScreen extends ConsumerStatefulWidget {
  const DeveloperConsoleScreen({super.key});

  @override
  ConsumerState<DeveloperConsoleScreen> createState() => _DeveloperConsoleScreenState();
}

class _DeveloperConsoleScreenState extends ConsumerState<DeveloperConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _services = [];
  List<dynamic> _featureFlags = [];
  List<dynamic> _crashes = [];
  List<EncryptedLogEntry> _systemLogs = [];
  List<dynamic> _serverAuditLogs = [];

  // Enclave Security Gate — Preservado globalmente por 30 minutos
  bool get _isUnlocked => DeveloperEnclaveSession.instance.isUnlocked;
  String? get _sessionToken => DeveloperEnclaveSession.instance.sessionToken;
  static const String _authorizedEmail = 'felipe.a.m.lozano@gmail.com';

  // Configura as 6 abas de monitoramento e escuta eventos de segurança e novas linhas de log emitidas.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadOverview();
    AppLogger.instance.logChangeNotifier.addListener(_onLogsChanged);
    DeveloperEnclaveSession.instance.isUnlockedNotifier.addListener(_onEnclaveSessionChanged);
  }

  // Desinscreve os listeners reativos e descarta o controlador de abas ao fechar o console.
  @override
  void dispose() {
    AppLogger.instance.logChangeNotifier.removeListener(_onLogsChanged);
    DeveloperEnclaveSession.instance.isUnlockedNotifier.removeListener(_onEnclaveSessionChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Notifica o console quando a chave criptográfica em memória for liberada ou expirar.
  void _onEnclaveSessionChanged() {
    if (mounted) {
      setState(() {});
      if (_isUnlocked) {
        _loadDecryptedLogs();
      }
    }
  }

  // Recarrega automaticamente a listagem caso novos eventos de log sejam disparados enquanto logado.
  void _onLogsChanged() {
    if (_isUnlocked && mounted) {
      _loadDecryptedLogs();
    }
  }

  // Consulta a saúde dos serviços e feature flags no backend ou assume valores locais em modo offline.
  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/overview/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _services = data['services'] ?? [];
          _featureFlags = data['feature_flags'] ?? [];
          _crashes = data['active_crashes'] ?? [];
          _serverAuditLogs = data['recent_audit_logs'] ?? [];
        });
      }
    } catch (_) {
      // Fallback local caso o backend esteja desconectado
      setState(() {
        _services = [
          {'service_name': 'Django Core API', 'status': 'HEALTHY', 'latency_ms': 14.2, 'uptime_pct': 99.99},
          {'service_name': 'Supabase PostgreSQL', 'status': 'HEALTHY', 'latency_ms': 8.4, 'uptime_pct': 99.99},
          {'service_name': 'LiteLLM Proxy Router', 'status': 'HEALTHY', 'latency_ms': 85.0, 'uptime_pct': 99.95},
          {'service_name': 'TimescaleDB Telemetry', 'status': 'HEALTHY', 'latency_ms': 12.0, 'uptime_pct': 99.99},
        ];
        _featureFlags = [
          {'id': 1, 'key': 'pindorama_particles_v2', 'name': 'Efeitos de Partículas Avançados', 'is_enabled': true, 'rollout_percentage': 100},
          {'id': 2, 'key': 'impeller_dynamic_lod', 'name': 'LOD Dinâmico do Impeller', 'is_enabled': true, 'rollout_percentage': 100},
          {'id': 3, 'key': 'ai_adaptive_feedback', 'name': 'Feedback de IA Adaptativo', 'is_enabled': true, 'rollout_percentage': 100},
          {'id': 4, 'key': 'offline_pindorama_cache', 'name': 'Cache Offline de Pindorama', 'is_enabled': true, 'rollout_percentage': 100},
        ];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Decifra os registros locais em repouso utilizando a chave AES ativa da sessão do Enclave.
  Future<void> _loadDecryptedLogs() async {
    final token = _sessionToken ?? 'dev_session_active';
    final logs = await AppLogger.instance.getDecryptedLogs(token);
    if (mounted) {
      setState(() => _systemLogs = logs);
    }
  }

  // Abre o modal de autenticação OTP de dois fatores para validar privilégios de administrador.
  Future<void> _openSecurityGate({required VoidCallback onAuthorized}) async {
    await SecurityGateDialog.show(
      context,
      authorizedEmail: _authorizedEmail,
      onAuthorized: onAuthorized,
    );
  }

  // Intercepta a alternância de flag e exige destravamento do enclave antes de gravar o override.
  void _toggleFlag(int index) {
    final flag = _featureFlags[index];
    final key = flag['key']?.toString() ?? '';
    final newEnabled = !(flag['is_enabled'] as bool? ?? false);

    if (!_isUnlocked) {
      _openSecurityGate(onAuthorized: () => _executeFlagToggle(index, key, newEnabled));
    } else {
      _executeFlagToggle(index, key, newEnabled);
    }
  }

  // Aplica o override da flag em tempo real via Riverpod e persiste no backend para auditoria.
  Future<void> _executeFlagToggle(int index, String key, bool newEnabled) async {
    setState(() {
      _featureFlags[index]['is_enabled'] = newEnabled;
    });

    // 1. Aplica override em tempo real no app via Riverpod
    ref.read(featureFlagNotifierProvider.notifier).setOverride(key, newEnabled);

    // 2. Grava evento no AppLogger cifrado
    AppLogger.sec('FEATURE_FLAG', 'Flag $key alterada para $newEnabled por $_authorizedEmail');

    // 3. Notifica backend
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/flags/toggle/');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': key, 'is_enabled': newEnabled}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feature Flag "$key" atualizada em tempo de execução: $newEnabled'),
          backgroundColor: AppTheme.accent(context),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Renderiza a barra com status da sessão do enclave e as 6 abas de diagnóstico operacional.
  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.developer_board_rounded, color: AppTheme.accent(context), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Developer Console',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_isUnlocked)
            ValueListenableBuilder<int>(
              valueListenable: DeveloperEnclaveSession.instance.remainingSecondsNotifier,
              builder: (vBuilderCtx, remainingSecs, _) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent(vBuilderCtx).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent(vBuilderCtx).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, color: AppTheme.accent(vBuilderCtx), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'ENCLAVE (${DeveloperEnclaveSession.instance.formattedRemaining})',
                        style: TextStyle(
                          color: AppTheme.accent(vBuilderCtx),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.lock_rounded, color: AppTheme.accent(vBuilderCtx), size: 16),
                        tooltip: 'Bloquear Enclave Agora',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: this.context,
                            builder: (c) => AlertDialog(
                              backgroundColor: AppTheme.surface(c),
                              title: const Text('Bloquear Enclave?'),
                              content: const Text('Deseja encerrar a sessão de segurança de 30 minutos agora?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Bloquear'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await DeveloperEnclaveSession.instance.lock();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Enclave de Segurança bloqueado.')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            )
          else
            IconButton(
              icon: Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary(context)),
              tooltip: 'Desbloquear Enclave Dev',
              onPressed: () => _openSecurityGate(onAuthorized: () {}),
            ),
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent(context)),
                  )
                : Icon(Icons.refresh_rounded, color: AppTheme.textSecondary(context)),
            tooltip: 'Atualizar Métricas',
            onPressed: () {
              _loadOverview();
              if (_isUnlocked) _loadDecryptedLogs();
            },
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent(context),
          indicatorWeight: 3,
          labelColor: AppTheme.accent(context),
          unselectedLabelColor: AppTheme.textSecondary(context),
          tabs: const [
            Tab(icon: Icon(Icons.speed_rounded), text: 'Live Ops'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'Observatory'),
            Tab(icon: Icon(Icons.view_in_ar_rounded), text: 'World Engine'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'Feature Flags'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Zero-Leak Logs'),
            Tab(icon: Icon(Icons.bug_report_rounded), text: 'Crash Intel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LiveOpsTab(telemetry: telemetry, services: _services),
          ObservatoryTab(telemetry: telemetry),
          WorldEngineTab(telemetry: telemetry),
          FeatureFlagsTab(
            featureFlags: _featureFlags,
            isUnlocked: _isUnlocked,
            onRequestUnlock: () => _openSecurityGate(onAuthorized: () {}),
            onToggleFlag: _toggleFlag,
          ),
          ZeroLeakLogsTab(
            isUnlocked: _isUnlocked,
            onRequestUnlock: () => _openSecurityGate(onAuthorized: _loadDecryptedLogs),
            systemLogs: _systemLogs,
            serverAuditLogs: _serverAuditLogs,
            onClearLocalLogs: () async {
              await AppLogger.instance.clearLogs();
              _loadDecryptedLogs();
            },
            onRefreshLogs: () {
              _loadDecryptedLogs();
              _loadOverview();
            },
          ),
          CrashIntelTab(crashes: _crashes),
        ],
      ),
    );
  }
}
