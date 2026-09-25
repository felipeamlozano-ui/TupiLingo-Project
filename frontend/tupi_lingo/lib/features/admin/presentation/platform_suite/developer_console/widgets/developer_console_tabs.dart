import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/telemetry/telemetry_service.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../../shared/metric_card.dart';
import '../../shared/status_badge.dart';

// Aba de telemetria em tempo real e monitoramento SRE dos microsserviços.
class LiveOpsTab extends StatelessWidget {
  final TelemetryState telemetry;
  final List<dynamic> services;

  const LiveOpsTab({
    super.key,
    required this.telemetry,
    required this.services,
  });

  // Renderiza os cartões de FPS, latência e memória junto com a listagem dos serviços backend.
  @override
  Widget build(BuildContext context) {
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
                          title: 'Taxa de Quadros (FPS)',
                          value: '${telemetry.currentFps.toStringAsFixed(1)} FPS',
                          subtitle: 'Alvo: 60.0 FPS constante',
                          icon: Icons.monitor_heart_rounded,
                          accentColor: AppTheme.accent(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          title: 'Latência p95 de Rede',
                          value: '${telemetry.networkLatencyMs.toStringAsFixed(1)} ms',
                          subtitle: 'Target SLO: < 120 ms',
                          icon: Icons.wifi_tethering_rounded,
                          accentColor: AppTheme.primary(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          title: 'Memória Heap (RAM)',
                          value: '${telemetry.memoryMb.toStringAsFixed(0)} MB',
                          subtitle: 'Target: < 220 MB',
                          icon: Icons.memory_rounded,
                          accentColor: AppTheme.accent(context),
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
                      title: 'Taxa de Quadros (FPS)',
                      value: '${telemetry.currentFps.toStringAsFixed(1)} FPS',
                      subtitle: 'Alvo: 60.0 FPS constante',
                      icon: Icons.monitor_heart_rounded,
                      accentColor: AppTheme.accent(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Latência p95 de Rede',
                      value: '${telemetry.networkLatencyMs.toStringAsFixed(1)} ms',
                      subtitle: 'Target SLO: < 120 ms',
                      icon: Icons.wifi_tethering_rounded,
                      accentColor: AppTheme.primary(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Memória Heap (RAM)',
                      value: '${telemetry.memoryMb.toStringAsFixed(0)} MB',
                      subtitle: 'Target: < 220 MB',
                      icon: Icons.memory_rounded,
                      accentColor: AppTheme.accent(context),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Estado de Serviços Críticos (SRE)',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (_, _) => Divider(color: AppTheme.border(context), height: 1),
              itemBuilder: (context, index) {
                final svc = services[index];
                return ListTile(
                  leading: Icon(Icons.dns_rounded, color: AppTheme.accent(context)),
                  title: Text(
                    svc['service_name'] ?? 'Service',
                    style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Latência: ${svc['latency_ms'] ?? 0}ms • Uptime: ${svc['uptime_pct'] ?? 100}%',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                  ),
                  trailing: StatusBadge.healthy(label: svc['status'] ?? 'HEALTHY'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Aba de diagnóstico detalhado de threads gráficas do motor Flutter/Impeller.
class ObservatoryTab extends StatelessWidget {
  final TelemetryState telemetry;

  const ObservatoryTab({
    super.key,
    required this.telemetry,
  });

  // Medidor estilizado para tempos de execução de threads ou contagem de drops.
  Widget _buildThreadGauge(
    BuildContext context, {
    required String name,
    required double durationMs,
    required double targetMs,
    required Color color,
    bool isCount = false,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            isCount ? '${durationMs.toInt()}' : '${durationMs.toStringAsFixed(2)} ms',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCount ? 'Limite Alvo: < ${targetMs.toInt()}' : 'Orçamento: < ${targetMs.toStringAsFixed(1)} ms',
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Monta a visão de diagnóstico com gauges para raster, UI thread e perda de quadros.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnóstico Profundo do Impeller & Engine Threads',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildThreadGauge(
                    context,
                    name: 'Raster Thread',
                    durationMs: telemetry.avgRasterMs,
                    targetMs: 8.0,
                    color: AppTheme.accent(context),
                  ),
                  _buildThreadGauge(
                    context,
                    name: 'UI Thread',
                    durationMs: telemetry.avgBuildMs,
                    targetMs: 8.0,
                    color: AppTheme.primary(context),
                  ),
                  _buildThreadGauge(
                    context,
                    name: 'Frame Drops Acumulados',
                    durationMs: telemetry.droppedFrames.toDouble(),
                    targetMs: 5.0,
                    color: const Color(0xFFEF4444),
                    isCount: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Aba de inspeção dos parâmetros do motor do mapa e quadtrees de névoa de guerra.
class WorldEngineTab extends StatelessWidget {
  final TelemetryState telemetry;

  const WorldEngineTab({
    super.key,
    required this.telemetry,
  });

  // Cartão com ícone e métricas estruturais da engine gráfica.
  Widget _buildEngineParamCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Renderiza a grade de configurações e shaders ativos no pipeline cartográfico.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parâmetros do Pindorama World Engine',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildEngineParamCard(context, 'Pipeline Gráfico', 'Pure CustomPainter', Icons.draw_rounded, AppTheme.accent(context)),
              _buildEngineParamCard(context, 'Backend Shader', 'Impeller Vulkan / Metal', Icons.graphic_eq_rounded, AppTheme.primary(context)),
              _buildEngineParamCard(context, 'Fog of War Engine', 'Hierarchical Quadtree', Icons.cloud_rounded, AppTheme.accent(context)),
              _buildEngineParamCard(context, 'Orçamento de Partículas', '240 ativas', Icons.grain_rounded, AppTheme.primary(context)),
            ],
          ),
        ],
      ),
    );
  }
}

// Aba de controle e alternância dinâmica de feature flags do aplicativo em execução.
class FeatureFlagsTab extends StatelessWidget {
  final List<dynamic> featureFlags;
  final bool isUnlocked;
  final VoidCallback onRequestUnlock;
  final ValueChanged<int> onToggleFlag;

  const FeatureFlagsTab({
    super.key,
    required this.featureFlags,
    required this.isUnlocked,
    required this.onRequestUnlock,
    required this.onToggleFlag,
  });

  // Renderiza o painel de toggles de flags e botão de destravamento com Enclave de Segurança.
  @override
  Widget build(BuildContext context) {
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
                  'Controle de Rollout & Feature Flags de Runtime',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isUnlocked)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('Destravar Enclave'),
                  onPressed: onRequestUnlock,
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
              itemCount: featureFlags.length,
              separatorBuilder: (_, _) => Divider(color: AppTheme.border(context), height: 1),
              itemBuilder: (context, index) {
                final flag = featureFlags[index];
                final isEnabled = flag['is_enabled'] as bool? ?? false;

                return SwitchListTile(
                  value: isEnabled,
                  activeThumbColor: AppTheme.accent(context),
                  title: Text(
                    flag['name'] ?? flag['key'],
                    style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Chave: ${flag['key']} • Rollout: ${flag['rollout_percentage'] ?? 100}%',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                  ),
                  onChanged: (_) => onToggleFlag(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Aba de inteligência e diagnóstico consolidado de erros e exceções não tratadas.
class CrashIntelTab extends StatelessWidget {
  final List<dynamic> crashes;

  const CrashIntelTab({
    super.key,
    required this.crashes,
  });

  // Renderiza o resumo dos clusters de exceções ou indicador de zero falhas ativas.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inteligência de Falhas Anônima (Zero-Crash Assurance)',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: crashes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.accent(context), size: 40),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhum cluster de falha ativo no momento.',
                            style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: crashes.length,
                    separatorBuilder: (_, _) => Divider(color: AppTheme.border(context), height: 1),
                    itemBuilder: (context, index) {
                      final c = crashes[index];
                      return ListTile(
                        leading: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                        title: Text(c['error_type'] ?? 'Error', style: TextStyle(color: AppTheme.textPrimary(context))),
                        subtitle: Text(c['exception_message'] ?? '', style: TextStyle(color: AppTheme.textSecondary(context))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
