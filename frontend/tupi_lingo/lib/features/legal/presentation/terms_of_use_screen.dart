import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Fullscreen Material 3 Expressive Terms of Use, Indigenous Language Disclaimer,
/// and Application Features Catalogue Screen.
class TermsOfUseScreen extends StatefulWidget {
  final bool requireAcceptance;
  final FutureOr<void> Function()? onAccepted;

  const TermsOfUseScreen({
    super.key,
    this.requireAcceptance = false,
    this.onAccepted,
  });

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _termsAccepted = false;
  bool _disclaimerAccepted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primaryColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);
    final accentTerracotta = const Color(0xFFD08A45);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text(
          'Termos & Isenção Legal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.surface(context),
        foregroundColor: AppTheme.textPrimary(context),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: AppTheme.textSecondary(context),
          indicatorColor: primaryColor,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined, size: 20), text: 'Termos de Uso'),
            Tab(icon: Icon(Icons.shield_outlined, size: 20), text: 'Isenção da Língua'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsOfUseTab(context),
          _buildLanguageDisclaimerTab(context),
        ],
      ),
      bottomNavigationBar: widget.requireAcceptance
          ? _buildAcceptanceFooter(context, primaryColor, accentTerracotta)
          : null,
    );
  }

  Widget _buildTermsOfUseTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.verified_user_outlined,
          title: 'Termos de Serviço da Plataforma',
          subtitle: 'Versão 1.2.0 • Atualizada em Setembro de 2026',
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          title: '1. Objeto & Natureza Educacional',
          content:
              'O TupiLingo é um software experimental e aberto de ensino, concebido exclusivamente para finalidades pedagógicas, '
              'documentais e de difusão histórica do patrimônio linguístico Tupi Antigo. O aplicativo NÃO possui caráter normativo ou oficial '
              'e não substitui a pesquisa acadêmica de campo nem a autoridade sociolinguística das comunidades indígenas originárias.',
        ),
        _buildInfoCard(
          context,
          title: '2. Gratuidade & Economia Virtual Sem Valor Real',
          content:
              'O acesso a todas as lições, módulos e ao mapa histórico de Pindorama é 100% gratuito. A moeda interna denominada "Conchas" '
              'é um mero artifício de gamificação pedagógica e NÃO POSSUI VALOR MONETÁRIO REAL, não podendo ser comercializada, convertida '
              'ou transferida por moeda corrente nacional ou estrangeira. Não há transações financeiras reais ou mecânicas "pay-to-win".',
        ),
        _buildInfoCard(
          context,
          title: '3. Privacidade Estrita & Zero-PII (LGPD)',
          content:
              'Em conformidade com a Lei Geral de Proteção de Dados (Lei nº 13.709/2018), a plataforma opera sob arquitetura Zero-PII. '
              'Não coletamos CPF, número de telefone celular, dados bancários, geolocalização física precisa por satélite ou dados biométricos. '
              'O processamento de pronúncia de fala ocorre localmente no dispositivo do usuário.',
        ),
        _buildInfoCard(
          context,
          title: '4. Regras de Conduta & Uso Aceitável',
          content:
              'O usuário compromete-se a utilizar o aplicativo de forma ética e respeitosa, abstendo-se de tentar explorar vulnerabilidades, '
              'executar scraping não autorizado ou disseminar discursos de ódio, discriminação étnico-racial ou apropriação indevida.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLanguageDisclaimerTab(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.gavel_rounded,
          title: 'Aviso Legal de Isenção sobre a Língua Indígena',
          subtitle: 'Cláusula de Isenção Total de Responsabilidade Civil e Cultural',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD08A45).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD08A45).withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD08A45), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ATENÇÃO: A equipe de desenvolvimento, autores e colaboradores do TupiLingo '
                  'ISENTAM-SE EXPRESSAMENTE DE TODA E QUALQUER RESPONSABILIDADE quanto a decisões '
                  'ortográficas, escolhas de tradução, pronúncias, variações dialetais ou interpretações da língua.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF8D4B00),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          title: 'A. Diacronia e Corpus Colonial',
          content:
              'O conteúdo linguístico do TupiLingo baseia-se primordialmente no corpus documental dos séculos XVI e XVII '
              '(como as obras do Pe. José de Anchieta, Pe. Luís Figueira e cronistas coloniais) e na sistematização contemporânea '
              'do Prof. Dr. Eduardo de Almeida Navarro. O usuário reconhece que tais registros representam transcrições históricas '
              'sujeitas a limitações filológicas da época.',
        ),
        _buildInfoCard(
          context,
          title: 'B. Isenção sobre Ortografia, Fonética e Dialetos',
          content:
              'A equipe isenta-se de litígios ou reclamações quanto a convenções ortográficas adotadas (acentuações, diacríticos ou romanizações), '
              'divergências dialetais regionais (Tupinambá, Tupiniquim, Carijó, etc.) ou aproximações fonéticas sintetizadas. '
              'O app não reivindica infalibilidade e acolhe a multiplicidade de correntes científicas.',
        ),
        _buildInfoCard(
          context,
          title: 'C. Vedação de Uso Sagrado, Ritualístico ou Litúrgico',
          content:
              'O TupiLingo enfoca a morfologia, gramática e léxico secular histórico. É expressamente vedado o uso dos vocábulos ou materiais '
              'daqui extraídos para fins litúrgicos, rituais sagrados, celebrações religiosas tradicionais ou usurpação de autoridade espiritual indígena.',
        ),
        _buildInfoCard(
          context,
          title: 'D. Soberania e Direitos Originários (Art. 231 CF & OIT 169)',
          content:
              'O aplicativo não representa politicamente, não tutela e não fala em nome de qualquer comunidade ou povo indígena contemporâneo. '
              'Reconhece-se e respeita-se a soberania exclusiva e inalienável dos povos indígenas sobre suas línguas, memórias e saberes ancestrais.',
        ),
        _buildInfoCard(
          context,
          title: 'E. Isenção sobre Saídas de Inteligência Artificial (RAG Mesh)',
          content:
              'Explicações contextuais fornecidas pelo Tutor Inteligente utilizam modelos generativos probabilísticos de linguagem (LLMs). '
              'A equipe não garante a infalibilidade das explicações automáticas geradas pela IA e isenta-se de responsabilidade por aproximações '
              'ou alucinações sintáticas.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }



  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = AppTheme.isDark(context);
    final primaryColor = isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final isDark = AppTheme.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary(context).withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildAcceptanceFooter(
    BuildContext context,
    Color primaryColor,
    Color accentColor,
  ) {
    final canAccept = _termsAccepted && _disclaimerAccepted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _termsAccepted,
                onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                title: const Text(
                  'Li e concordo com os Termos de Uso e a Política de Privacidade Zero-PII.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: primaryColor,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _disclaimerAccepted,
                onChanged: (val) => setState(() => _disclaimerAccepted = val ?? false),
                title: const Text(
                  'Declaro ciência inequívoca da isenção pedagógica, histórica e cultural sobre a língua Tupi Antigo.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canAccept
                    ? () async {
                        if (widget.onAccepted != null) {
                          await widget.onAccepted!();
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'CONFIRMAR E CONTINUAR',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
