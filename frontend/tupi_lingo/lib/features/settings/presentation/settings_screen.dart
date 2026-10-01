import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/core/audio/audio_manager.dart';
import 'package:tupi_lingo/core/network/api_cache_manager.dart';
import 'package:tupi_lingo/features/settings/data/settings_service.dart';
import 'package:tupi_lingo/features/legal/presentation/terms_of_use_screen.dart';

/// Tela de Configurações e Preferências do Usuário.
/// Permite ao aluno personalizar sons, vibrações, notificações,
/// acessibilidade e desempenho (redução de animações/VRAM).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primaryColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
    final accentGold = isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            elevation: 0,
            backgroundColor: AppTheme.surface(context),
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.settings_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Configurações',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Áudio e Feedback
                _buildSectionHeader(context, 'ÁUDIO E SENSAÇÃO', Icons.volume_up_rounded, primaryColor),
                _buildCard(
                  context,
                  children: [
                    _buildSwitchTile(
                      context,
                      title: 'Efeitos Sonoros (SFX)',
                      subtitle: 'Sons de acerto, erro e abertura de baús',
                      icon: Icons.music_note_rounded,
                      value: _settings.soundEffects,
                      onChanged: (val) {
                        _settings.setSoundEffects(val);
                        if (val) AudioManager.instance.playTap();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      context,
                      title: 'Feedback Tátil / Vibração',
                      subtitle: 'Vibração suave de confirmação ao responder',
                      icon: Icons.vibration_rounded,
                      value: _settings.hapticFeedback,
                      onChanged: (val) {
                        _settings.setHapticFeedback(val);
                        if (val) AudioManager.instance.playTap();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Experiência de Aprendizado & Desempenho
                _buildSectionHeader(context, 'APRENDIZADO & PERFORMANCE', Icons.speed_rounded, accentGold),
                _buildCard(
                  context,
                  children: [
                    _buildSwitchTile(
                      context,
                      title: 'Tradução Instantânea ao Tocar',
                      subtitle: 'Exibe balão de tradução estilo Duolingo nas palavras',
                      icon: Icons.translate_rounded,
                      value: _settings.instantTranslation,
                      onChanged: (val) {
                        _settings.setInstantTranslation(val);
                        AudioManager.instance.playTap();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      context,
                      title: 'Guia Fonético nas Lições',
                      subtitle: 'Exibe a pronúncia recomendada abaixo dos termos',
                      icon: Icons.record_voice_over_rounded,
                      value: _settings.phoneticGuide,
                      onChanged: (val) {
                        _settings.setPhoneticGuide(val);
                        AudioManager.instance.playTap();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      context,
                      title: 'Modo de Alto Desempenho (Reduzir Animações)',
                      subtitle: 'Pausa loops visuais contínuos para poupar VRAM e bateria',
                      icon: Icons.bolt_rounded,
                      value: _settings.reducedMotion,
                      onChanged: (val) {
                        _settings.setReducedMotion(val);
                        AudioManager.instance.playTap();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Notificações
                _buildSectionHeader(context, 'NOTIFICAÇÕES', Icons.notifications_active_rounded, primaryColor),
                _buildCard(
                  context,
                  children: [
                    _buildSwitchTile(
                      context,
                      title: 'Lembretes de Ofensiva (Streak)',
                      subtitle: 'Alerta diário no final da tarde para não perder seus dias',
                      icon: Icons.local_fire_department_rounded,
                      value: _settings.dailyReminder,
                      onChanged: (val) {
                        _settings.setDailyReminder(val);
                        AudioManager.instance.playTap();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      context,
                      title: 'Novidades e Conteúdos',
                      subtitle: 'Avisos sobre novos capítulos, eventos e desafios',
                      icon: Icons.campaign_rounded,
                      value: _settings.contentUpdates,
                      onChanged: (val) {
                        _settings.setContentUpdates(val);
                        AudioManager.instance.playTap();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Armazenamento e Limpeza
                _buildSectionHeader(context, 'DADOS E ARMAZENAMENTO', Icons.storage_rounded, accentGold),
                _buildCard(
                  context,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 20),
                      ),
                      title: Text(
                        'Limpar Cache da Trilha',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Libera memória e força recarregamento limpo da rede',
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        AudioManager.instance.playTap();
                        await ApiCacheManager.instance.clearCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Cache limpo com sucesso! VRAM liberada.', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 5. Jurídico e Transparência
                _buildSectionHeader(context, 'SOBRE E LEGAL', Icons.info_outline_rounded, primaryColor),
                _buildCard(
                  context,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.policy_rounded, color: primaryColor, size: 20),
                      ),
                      title: Text(
                        'Termos de Uso e Isenção da Língua',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        AudioManager.instance.playTap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TupiLingo Versão', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)),
                          Text(
                            '1.2.0 • Pindorama Edition',
                            style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = AppTheme.isDark(context);
    final primaryColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: primaryColor,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.textPrimary(context),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.textSecondary(context),
          fontSize: 12,
        ),
      ),
    );
  }
}
