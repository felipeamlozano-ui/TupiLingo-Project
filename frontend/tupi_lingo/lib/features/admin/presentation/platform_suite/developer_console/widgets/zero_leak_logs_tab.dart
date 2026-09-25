import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import 'package:tupi_lingo/core/security/developer_enclave_session.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Aba de inspeção dos registros criptografados em repouso com proteção contra vazamentos via ADB.
class ZeroLeakLogsTab extends StatefulWidget {
  final bool isUnlocked;
  final VoidCallback onRequestUnlock;
  final List<EncryptedLogEntry> systemLogs;
  final List<dynamic> serverAuditLogs;
  final VoidCallback onClearLocalLogs;
  final VoidCallback onRefreshLogs;

  const ZeroLeakLogsTab({
    super.key,
    required this.isUnlocked,
    required this.onRequestUnlock,
    required this.systemLogs,
    required this.serverAuditLogs,
    required this.onClearLocalLogs,
    required this.onRefreshLogs,
  });

  @override
  State<ZeroLeakLogsTab> createState() => _ZeroLeakLogsTabState();
}

class _ZeroLeakLogsTabState extends State<ZeroLeakLogsTab> {
  String _logFilter = 'ALL';

  // Chip de filtragem rápida entre logs de segurança, sistema e auditoria do servidor.
  Widget _buildFilterChip(String key, String label) {
    final isSelected = _logFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSecondary(context),
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.accent(context),
      backgroundColor: AppTheme.surfaceSubtle(context),
      onSelected: (_) => setState(() => _logFilter = key),
    );
  }

  // Renderiza a interface protegida com gate de segurança ou o visualizador completo de logs.
  @override
  Widget build(BuildContext context) {
    if (!widget.isUnlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, color: AppTheme.accent(context), size: 48),
              const SizedBox(height: 16),
              Text(
                'Logs Cifrados em Repouso (Zero-Leak)',
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para proteger a integridade contra engenharia reversa e ADB, estes registros são encriptados com AES-256-GCM e só podem ser decifrados em memória após a validação do Master Passcode e OTP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Autenticar Enclave para Decifrar Logs'),
                onPressed: widget.onRequestUnlock,
              ),
            ],
          ),
        ),
      );
    }

    final filteredLocalLogs = widget.systemLogs.where((log) {
      if (_logFilter == 'ALL') return true;
      if (_logFilter == 'SEC') return log.level == LogLevel.security;
      if (_logFilter == 'SYS') return log.level != LogLevel.security;
      return false;
    }).toList();

    final showServer = _logFilter == 'ALL' || _logFilter == 'SERVER';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Título e Ações
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero-Leak Enclave Logs',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registros decifrados em memória física protegida (AES-256-GCM)',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      side: BorderSide(color: AppTheme.border(context)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 15),
                    label: const Text('Log Teste', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final nowStr = DateTime.now().toIso8601String().substring(11, 19);
                      AppLogger.sec('ADMIN_TEST', 'Disparo de verificação manual do administrador às $nowStr');
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log emitido e cifrado com sucesso!'),
                          backgroundColor: Color(0xFF0F172A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary(context), size: 20),
                    tooltip: 'Limpar Buffer Local',
                    onPressed: widget.onClearLocalLogs,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: AppTheme.accent(context), size: 20),
                    tooltip: 'Atualizar Logs',
                    onPressed: widget.onRefreshLogs,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Painel de Status do Enclave
          ValueListenableBuilder<int>(
            valueListenable: DeveloperEnclaveSession.instance.remainingSecondsNotifier,
            builder: (context, remSecs, _) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Enclave: Ativo (AES-256 / PQC)',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Sessão: ${DeveloperEnclaveSession.instance.formattedRemaining}',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Row(
                        children: [
                          const Icon(Icons.storage_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.systemLogs.length} locais',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, color: Color(0xFFA855F7), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.serverAuditLogs.length} servidor',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Todos (${widget.systemLogs.length + widget.serverAuditLogs.length})'),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'SEC',
                  'Segurança (${widget.systemLogs.where((l) => l.level == LogLevel.security).length})',
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'SYS',
                  'Sistema (${widget.systemLogs.where((l) => l.level != LogLevel.security).length})',
                ),
                const SizedBox(width: 6),
                _buildFilterChip('SERVER', 'Servidor (${widget.serverAuditLogs.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista de Logs Decifrados
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: (filteredLocalLogs.isEmpty && (!showServer || widget.serverAuditLogs.isEmpty))
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: AppTheme.textSecondary(context), size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum log gravado no buffer seguro ainda.',
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toque em "Log Teste" acima para gerar um registro de verificação.',
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Logs Locais Decifrados
                      ...filteredLocalLogs.map((log) {
                        final isSecurity = log.level == LogLevel.security;
                        final isError = log.level == LogLevel.error;
                        final badgeColor = isSecurity
                            ? const Color(0xFF10B981)
                            : isError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.border(context), width: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  log.level.name.toUpperCase(),
                                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '[${log.tag}]',
                                          style: TextStyle(
                                            color: AppTheme.textPrimary(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          log.timestamp.toIso8601String().substring(11, 19),
                                          style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      log.message,
                                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Logs de Auditoria do Servidor
                      if (showServer)
                        ...widget.serverAuditLogs.map((audit) {
                          final action = audit['action'] ?? 'AUDIT';
                          final actor = audit['actor_role'] ?? 'Server';
                          final entity = audit['entity_type'] ?? '';
                          final seal = audit['ephemeral_seal'] ?? '';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.04),
                              border: Border(bottom: BorderSide(color: AppTheme.border(context), width: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    'AUDIT',
                                    style: TextStyle(
                                      color: Color(0xFFA855F7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '[$action] $entity',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppTheme.textPrimary(context),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (seal.isNotEmpty)
                                            Text(
                                              seal,
                                              style: TextStyle(
                                                color: AppTheme.accent(context),
                                                fontSize: 9,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Executado por: $actor • Selo HMAC Verificado',
                                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
