import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/state/app_progression_notifier.dart';
import '../../domain/entities/user_progress_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../widgets/progress_3d_bar_chart.dart';
import '../widgets/vocabulary_mastery_card.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final DashboardRepository? repository;

  const ProgressDashboardScreen({super.key, this.repository});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  late final DashboardRepository _repository;
  UserProgressStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DashboardRepositoryImpl();
    _loadStats();

    // Sincronização em tempo real de alta fluidez
    AppProgressionNotifier.instance.addListener(_onProgressionUpdated);
  }

  @override
  void dispose() {
    AppProgressionNotifier.instance.removeListener(_onProgressionUpdated);
    super.dispose();
  }

  void _onProgressionUpdated() {
    if (mounted) {
      _loadStats(forceRefresh: true);
    }
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    if (_stats == null) {
      setState(() => _isLoading = true);
    }
    final stats = await _repository.getUserProgressStats(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Text('🏛️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Painel de Desempenho & Memória',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0E5D4E)),
            onPressed: () => _loadStats(forceRefresh: true),
            tooltip: 'Atualizar Estatísticas',
          ),
        ],
      ),
      body: _isLoading && _stats == null
          ? _buildSkeletonLoading()
          : RefreshIndicator(
              color: const Color(0xFF0E5D4E),
              onRefresh: () => _loadStats(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: _stats != null && _stats!.isEmptyState
                    ? _buildEmptyState()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Resumo de KPIs Principais (RepaintBoundary para 120 FPS)
                          RepaintBoundary(
                            child: _buildKpiRow(_stats!),
                          ),
                          const SizedBox(height: 20),

                          // Gráfico de Barras 3D (RepaintBoundary para fluidez máxima)
                          RepaintBoundary(
                            child: Progress3DBarChart(weeklyActivity: _stats!.weeklyActivity),
                          ),
                          const SizedBox(height: 20),

                          // Card de Domínio de Categorias Lexicais
                          RepaintBoundary(
                            child: VocabularyMasteryCard(
                              categories: _stats!.categoryMasteries,
                              totalWords: _stats!.totalWords,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ),
    );
  }

  /// Estado Vazio Amigável e Autêntico (quando usuário tem 0 lições e 0 XP)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF0E5D4E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🏹', style: TextStyle(fontSize: 44)),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            const Text(
              'Sua Jornada Começa Aqui!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Você ainda não concluiu lições nesta jornada. Complete sua primeira lição na Trilha para registrar seu XP diário, acender a fogueira da ofensiva e desbloquear as métricas de vocabulário e memória.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF565D6D),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Ir para a Trilha de Estudos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton Loading fluido para evitar layout shifts e jank
  Widget _buildSkeletonLoading() {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Container(
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(UserProgressStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'XP Total',
            value: '${stats.totalXp}',
            icon: '⭐',
            accentColor: const Color(0xFFD08A45),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            title: 'Ofensiva',
            value: '${stats.streakDays} dias',
            icon: '🔥',
            accentColor: const Color(0xFFE05638),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCard(
            title: 'Progresso',
            value: '${(stats.overallProgressPercentage * 100).toInt()}%',
            icon: '🏹',
            accentColor: const Color(0xFF0E5D4E),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D0D0).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF565D6D),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
