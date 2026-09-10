import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/nivel_gauge.dart';
import 'widgets/xp_progress_bar.dart';
import 'widgets/streak_card.dart';
import 'widgets/performance_chart.dart';
import 'widgets/recent_lessons_list.dart';
import 'widgets/achievement_gallery.dart';
import '../../../../core/state/app_progression_notifier.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Armazena nível em memória para detectar promoção durante a sessão
  static int? _previousLevelInMemory;

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _historicoLicoes = [];
  List<Map<String, dynamic>> _desempenhoCapitulo = [];
  List<Map<String, dynamic>> _achievementsDesbloqueadas = [];
  List<Map<String, dynamic>> _achievementsBloqueadas = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    AppProgressionNotifier.instance.addListener(_onProgressionUpdated);
  }

  @override
  void dispose() {
    AppProgressionNotifier.instance.removeListener(_onProgressionUpdated);
    super.dispose();
  }

  void _onProgressionUpdated() {
    if (mounted) {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sessão não encontrada. Por favor, faça login novamente.';
        });
        return;
      }

      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/auth/profile'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic> && data['success'] == true) {
          final profile = data['profile'] as Map<String, dynamic>? ?? {};
          final historico = (data['historico_licoes'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final desempenho = (data['desempenho_por_capitulo'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final unlocked = (data['achievements'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final locked = (data['achievements_bloqueadas'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final currentLevel = (profile['nivel_atual'] as num?)?.toInt() ?? 1;

          // Celebração motivacional de subida de nível
          if (_previousLevelInMemory != null && currentLevel > _previousLevelInMemory!) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showLevelUpCelebration(currentLevel);
            });
          }
          _previousLevelInMemory = currentLevel;

          if (mounted) {
            setState(() {
              _profileData = profile;
              _historicoLicoes = historico;
              _desempenhoCapitulo = desempenho;
              _achievementsDesbloqueadas = unlocked;
              _achievementsBloqueadas = locked;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Falha ao carregar perfil (Status ${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro de conexão: $e';
        });
      }
    }
  }

  void _showLevelUpCelebration(int novoNivel) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'SUBIDA DE NÍVEL!',
              style: TextStyle(
                color: Color(0xFFD08A45),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Parabéns! Sua precisão nas últimas lições elevou seu nível real para $novoNivel.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continuar Rumo à Mestria', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD08A45)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFD08A45), size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF565D6D), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E5D4E)),
                child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profileData ?? {};
    final userName = (profile['name'] as String?) ?? 'Guerreiro(a)';
    final userEmail = (profile['email'] as String?) ?? '';
    final xpTotal = (profile['xp_total'] as num?)?.toInt() ?? 0;
    final nivelAtual = (profile['nivel_atual'] as num?)?.toInt() ?? 1;
    final diasOfensiva = (profile['dias_ofensiva'] as num?)?.toInt() ?? 0;
    final maiorStreak = (profile['maior_streak'] as num?)?.toInt() ?? diasOfensiva;
    final variante = profile['variante_ativa'] as Map<String, dynamic>?;
    final varianteNome = variante != null ? (variante['nome']?.toString() ?? 'Tupi Antigo') : 'Tupi Antigo';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: RefreshIndicator(
          onRefresh: _fetchProfile,
          color: const Color(0xFFD08A45),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // 1. Header do Usuário
              _buildUserHeader(userName, userEmail, varianteNome),
              const SizedBox(height: 16),

              // 2. Gauge de Nível Real (Calibração Backend TRI)
              NivelGauge(nivel: nivelAtual),
              const SizedBox(height: 16),

              // 3. Fogo da Ofensiva
              StreakCard(streakDays: diasOfensiva, maiorStreak: maiorStreak),
              const SizedBox(height: 16),

              // 4. Barra de Progresso de XP
              XpProgressBar(xpTotal: xpTotal),
              const SizedBox(height: 16),

              // 5. Desempenho por Capítulo (RF04)
              PerformanceChart(desempenho: _desempenhoCapitulo),
              const SizedBox(height: 16),

              // 6. Últimas Lições (RF04)
              RecentLessonsList(historico: _historicoLicoes),
              const SizedBox(height: 16),

              // 7. Galeria de Conquistas (RF10)
              AchievementGallery(
                unlockedAchievements: _achievementsDesbloqueadas,
                lockedAchievements: _achievementsBloqueadas,
              ),
              const SizedBox(height: 16),

              // 8. Seletor de Tema Ancestral (Claro / Escuro / Auto)
              _buildThemeSelectorCard(context),
              const SizedBox(height: 24),

              // 9. Botão de Logout
              OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/welcome');
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
                label: const Text('Sair da Conta', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFD32F2F).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelectorCard(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final currentMode = ThemeNotifier.instance.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFFD08A45)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isDark ? '🌙' : '☀️',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aparência Ancestral',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Noite na Selva (Modo Escuro)' : 'Areia Sagrada (Modo Claro)',
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildThemeOption(
                context,
                title: 'Areia',
                icon: Icons.wb_sunny_rounded,
                selected: currentMode == ThemeMode.light,
                onTap: () => ThemeNotifier.instance.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Noite',
                icon: Icons.nightlight_round,
                selected: currentMode == ThemeMode.dark,
                onTap: () => ThemeNotifier.instance.setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                title: 'Auto',
                icon: Icons.brightness_auto_rounded,
                selected: currentMode == ThemeMode.system,
                onTap: () => ThemeNotifier.instance.setThemeMode(ThemeMode.system),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final activeColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFFD08A45);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : AppTheme.surfaceSubtle(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? activeColor : AppTheme.border(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? activeColor : AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected ? activeColor : AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(String name, String email, String varianteNome) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFD08A45), Color(0xFF8B6914)],
              ),
              border: Border.all(color: const Color(0xFFD08A45), width: 2.5),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'G',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Variante: $varianteNome',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
