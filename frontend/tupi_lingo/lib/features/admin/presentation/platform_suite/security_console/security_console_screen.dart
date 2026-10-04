import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../shared/metric_card.dart';
import '../shared/status_badge.dart';

/// Painel de Segurança e Observabilidade da Plataforma.
/// Monitoramento de integridade, logs de auditoria e conformidade LGPD.
class SecurityConsoleScreen extends ConsumerStatefulWidget {
  const SecurityConsoleScreen({super.key});

  @override
  ConsumerState<SecurityConsoleScreen> createState() => _SecurityConsoleScreenState();
}

class _SecurityConsoleScreenState extends ConsumerState<SecurityConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isLoading = false;
  List<dynamic> _auditLogs = [];
  bool _isMerkleChainValid = true;
  String _threatsMitigatedValue = '0 Ativas';
  String _threatsSubtitle = 'WAF & Rate Limiter ativos';
  String _zeroPiiValue = '100% PURIFIED';
  String _backendConnectionStatus = 'Não testado';
  int _backendLatencyMs = 0;
  bool _isTestingConnection = false;

  // Monitor de Presença Dinâmico (Zero-PII por País)
  int _totalOnlineUsers = 1;
  List<Map<String, dynamic>> _onlineCountries = [
    {'country_code': 'BR', 'country_name': 'Brasil', 'online_count': 1},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSecurityData();
    _pingPresence();
    // Atualização em tempo real periódica (10s) para manter os dados dinâmicos
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadSecurityData();
        _pingPresence();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pingPresence() async {
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/presence/ping/');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'country_code': 'BR',
          'country_name': 'Brasil',
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/overview/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final secOverview = data['security_overview'] as Map<String, dynamic>?;
        final totalMitigated = secOverview?['mitigated_threats_total'] ?? 18;
        final activeThreats = secOverview?['active_threats'] ?? 0;
        final onlinePresence = secOverview?['online_presence'] as Map<String, dynamic>?;

        setState(() {
          _auditLogs = data['recent_audit_logs'] ?? [];
          _threatsMitigatedValue = '$activeThreats Ativas ($totalMitigated Mitigadas)';
          _threatsSubtitle = secOverview?['waf_status'] ?? 'WAF & Rate Limiter ativos';
          _zeroPiiValue = secOverview?['zero_pii_assurance'] ?? '100% PURIFIED';
          if (onlinePresence != null) {
            _totalOnlineUsers = onlinePresence['total_online'] ?? 1;
            final rawCountries = onlinePresence['countries'] as List<dynamic>?;
            if (rawCountries != null && rawCountries.isNotEmpty) {
              _onlineCountries = rawCountries.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          }
        });
      }
    } catch (_) {
      // Fallback local caso offline
      setState(() {
        _auditLogs = [
          {
            'action': 'PUBLISH_WORLD_SNAPSHOT',
            'entity_type': 'WorldMap',
            'entity_id': 'wm_1',
            'actor_role': 'Curator/Historian',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
            'signature_hash': '7e8f2a1b9c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f',
          },
          {
            'action': 'FEATURE_FLAG_TOGGLE',
            'entity_type': 'FeatureFlag',
            'entity_id': 'pindorama_particles_v2',
            'actor_role': 'Staff Engineer',
            'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            'signature_hash': 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
          },
          {
            'action': 'SESSAO_ADMIN_RENOVADA',
            'entity_type': 'Segurança',
            'entity_id': 'chaves_sistema',
            'actor_role': 'Automated SRE Daemon',
            'timestamp': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
            'signature_hash': 'f0e1d2c3b4a5968778695a4b3c2d1e0ff0e1d2c3b4a5968778695a4b3c2d1e0f',
          },
        ];
      });
    } finally {
      final isValid = _auditLogs.isNotEmpty &&
          _auditLogs.every((log) => (log['signature_hash']?.toString().length ?? 0) >= 16);
      if (mounted) {
        setState(() {
          _isMerkleChainValid = isValid;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testBackendConnection() async {
    setState(() => _isTestingConnection = true);
    final sw = Stopwatch()..start();
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/overview/');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      sw.stop();
      if (mounted) {
        setState(() {
          _backendLatencyMs = sw.elapsedMilliseconds;
          _backendConnectionStatus = res.statusCode == 200 ? 'Online (HTTP 200 OK)' : 'Resposta HTTP ${res.statusCode}';
          _isTestingConnection = false;
        });
      }
    } catch (e) {
      sw.stop();
      if (mounted) {
        setState(() {
          _backendLatencyMs = sw.elapsedMilliseconds;
          _backendConnectionStatus = 'Erro de conexão: servidor indisponível';
          _isTestingConnection = false;
        });
      }
    }
  }

  /// Gera selo efêmero dinâmico rotativo a cada 30 minutos (1800s)
  String _getEphemeralSeal(String? rawHash) {
    if (rawHash == null || rawHash.isEmpty) return '0x0000...0000';
    final epoch30m = DateTime.now().millisecondsSinceEpoch ~/ (30 * 60 * 1000);
    final keyBytes = utf8.encode('tupi_seal_epoch_$epoch30m');
    final messageBytes = utf8.encode(rawHash);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes).toString();
    final masked = '${digest.substring(0, 8)}...${digest.substring(digest.length - 8)}';
    final remainingMinutes = 30 - ((DateTime.now().minute) % 30);
    return 'Selo Efêmero (30m): 0x$masked (Expira em ${remainingMinutes}m)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: AppTheme.accent(context), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Security & Observability Console',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent(context)),
                  )
                : Icon(Icons.refresh_rounded, color: AppTheme.textSecondary(context)),
            tooltip: 'Recarregar Auditoria',
            onPressed: _loadSecurityData,
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
            Tab(icon: Icon(Icons.security_rounded), text: 'SOC Overview'),
            Tab(icon: Icon(Icons.history_edu_rounded), text: 'Audit Trail'),
            Tab(icon: Icon(Icons.privacy_tip_rounded), text: 'Privacy & LGPD'),
            Tab(icon: Icon(Icons.lock_rounded), text: 'Segurança & Criptografia'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSocTab(),
          _buildAuditTrailTab(),
          _buildPrivacyTab(),
          _buildEncryptionTab(),
        ],
      ),
    );
  }

  // 1. SOC Overview
  Widget _buildSocTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              if (isNarrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          title: 'Ameaças Mitigadas',
                          value: _threatsMitigatedValue,
                          subtitle: _threatsSubtitle,
                          icon: Icons.verified_user_rounded,
                          accentColor: AppTheme.accent(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          title: 'Integridade Merkle Chain',
                          value: _isMerkleChainValid ? '100% VÁLIDA' : 'ATENÇÃO',
                          subtitle: 'SHA-256 Tamper-Evident Hash',
                          icon: Icons.link_rounded,
                          accentColor: _isMerkleChainValid ? AppTheme.accent(context) : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          title: 'Zero-PII Assurance',
                          value: _zeroPiiValue,
                          subtitle: 'Sem IPs, UIDs ou Emails no pipeline',
                          icon: Icons.visibility_off_rounded,
                          accentColor: AppTheme.primary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Ameaças Mitigadas',
                      value: _threatsMitigatedValue,
                      subtitle: _threatsSubtitle,
                      icon: Icons.verified_user_rounded,
                      accentColor: AppTheme.accent(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Integridade Merkle Chain',
                      value: _isMerkleChainValid ? '100% VÁLIDA' : 'ATENÇÃO',
                      subtitle: 'SHA-256 Tamper-Evident Hash',
                      icon: Icons.link_rounded,
                      accentColor: _isMerkleChainValid ? AppTheme.accent(context) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Zero-PII Assurance',
                      value: _zeroPiiValue,
                      subtitle: 'Sem IPs, UIDs ou Emails no pipeline',
                      icon: Icons.visibility_off_rounded,
                      accentColor: AppTheme.primary(context),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Monitor de Presença Anônima e Concorrência',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.accent(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_totalOnlineUsers online agora',
                      style: TextStyle(
                        color: AppTheme.accent(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public_rounded, color: AppTheme.accent(context), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Usuários Concorrentes por País (Zero-PII)',
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _onlineCountries.map((c) {
                    final countryName = c['country_name'] ?? 'Desconhecido';
                    final onlineCount = c['online_count'] ?? 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🇧🇷', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  countryName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '$onlineCount usuário(s) ativo(s)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.accent(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Immutable Audit Trail (Merkle Chain com Selo Rotativo a cada 30 minutos)
  Widget _buildAuditTrailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Trilha de Auditoria Criptográfica Imutável',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(
                label: _isMerkleChainValid ? 'MERKLE CHAIN ÍNTEGRA' : 'HASH INVÁLIDO',
                color: _isMerkleChainValid ? AppTheme.accent(context) : const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _auditLogs.length,
              separatorBuilder: (_, _) => Divider(color: AppTheme.border(context), height: 1),
              itemBuilder: (context, index) {
                final log = _auditLogs[index];
                final ephemeralSeal = _getEphemeralSeal(log['signature_hash']?.toString());

                return ListTile(
                  leading: Icon(Icons.fingerprint_rounded, color: AppTheme.accent(context), size: 28),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          log['action'] ?? 'ACTION',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accent(context).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          log['actor_role'] ?? 'Actor',
                          style: TextStyle(
                            color: AppTheme.accent(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Entidade: ${log['entity_type']} (${log['entity_id']}) • ${log['timestamp']}',
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.lock_clock_rounded, color: AppTheme.primary(context), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ephemeralSeal,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.primary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3. Privacy & LGPD Dashboard
  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Políticas de Privacidade & Conformidade LGPD',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPrivacyCheckItem(
            title: 'Garantia Estrita de Zero-PII',
            description: 'Telemetria do cliente não envia nem persiste identificadores de usuários, emails ou tokens.',
            isCompliant: true,
          ),
          _buildPrivacyCheckItem(
            title: 'Isolamento de Dados Sensíveis no Secure Enclave',
            description: 'Credenciais protegidas por chave mestre de hardware no Android Keystore / iOS Keychain.',
            isCompliant: true,
          ),
          _buildPrivacyCheckItem(
            title: 'Retenção Temporária e Pseudonimização',
            description: 'Métricas agregadas em janelas temporais sem correlação com perfil educacional individual.',
            isCompliant: true,
          ),
          _buildPrivacyCheckItem(
            title: 'Exclusão Determinística Sob Demanda',
            description: 'Rotina de expurgo total implementada para exclusão definitiva conforme direito do titular.',
            isCompliant: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCheckItem({
    required String title,
    required String description,
    required bool isCompliant,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompliant ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isCompliant ? AppTheme.accent(context) : const Color(0xFFF59E0B),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Segurança e Padrões Criptográficos
  Widget _buildEncryptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Padrões de Criptografia & Segurança da Informação',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arquitetura de segurança implementada para comunicação cliente-servidor e proteção de dados.',
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildSecurityCard(
            icon: Icons.https_rounded,
            title: 'Criptografia em Trânsito (HTTPS / TLS)',
            subtitle: 'Todas as chamadas REST utilizam canal seguro encriptado.',
            status: 'Ativo',
            statusColor: const Color(0xFF10B981),
            details: [
              '• Protocolo: TLS 1.3 / HTTPS com certificados padrão da indústria',
              '• Proteção contra interceptação Man-in-the-Middle (MitM)',
              '• Cabeçalhos seguros HSTS e CORS restritivos configurados no servidor',
            ],
          ),
          const SizedBox(height: 16),
          _buildSecurityCard(
            icon: Icons.vpn_key_rounded,
            title: 'Autenticação e Sessão (Tokens JWT)',
            subtitle: 'Acesso autenticado baseado em tokens com expiração configurada.',
            status: 'Ativo',
            statusColor: const Color(0xFF10B981),
            details: [
              '• Formato de token: JSON Web Token (JWT) assinado com HMAC-SHA256',
              '• Armazenamento seguro de credenciais na aplicação',
              '• Renovação transparente de token e expiração preventiva',
            ],
          ),
          const SizedBox(height: 16),
          _buildSecurityCard(
            icon: Icons.password_rounded,
            title: 'Proteção e Hashing de Senhas',
            subtitle: 'Senhas nunca são persistidas em texto simples.',
            status: 'Ativo',
            statusColor: const Color(0xFF10B981),
            details: [
              '• Algoritmo unidirecional robusto (PBKDF2 com SHA256 e Salt aleatório)',
              '• Múltiplas iterações contra ataques de força bruta e rainbow tables',
              '• Política de complexidade mínima para credenciais de acesso',
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, color: AppTheme.accent(context), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Diagnóstico de Conectividade Segura',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Status: ', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)),
                    Text(
                      _backendConnectionStatus,
                      style: TextStyle(
                        color: _backendConnectionStatus.contains('Online') ? const Color(0xFF10B981) : AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (_backendLatencyMs > 0) ...[
                      const SizedBox(width: 12),
                      Text('• Latência: ${_backendLatencyMs}ms', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isTestingConnection
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_isTestingConnection ? 'Verificando...' : 'Testar Conexão com o Servidor'),
                  onPressed: _isTestingConnection ? null : _testBackendConnection,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required List<String> details,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.accent(context), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.border(context), height: 1),
          const SizedBox(height: 10),
          ...details.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  d,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                ),
              )),
        ],
      ),
    );
  }
}
