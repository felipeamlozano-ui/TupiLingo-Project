import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/onboarding/data/onboarding_repository.dart';
import 'package:tupi_lingo/features/onboarding/data/onboarding_analytics.dart';
import '../widgets/mascot_avatar.dart';
import 'coach_mark_overlay.dart';

/// Controlador da máquina de estados do Tour Guiado Completo da tela Home.
class TourController {
  TourController._();
  static final TourController instance = TourController._();

  bool _isTourRunning = false;

  bool get isTourRunning => _isTourRunning;

  /// Dispara o Tour Guiado Completo com 10 passos cobrindo todas as áreas do aplicativo:
  /// 1. Capítulo & Guia Cultural
  /// 2. Nó da Lição
  /// 3. Seletor de Idiomas
  /// 4. Chama da Ofensiva (Streak)
  /// 5. Conchas & Loja (Oca de Trocas)
  /// 6. Pontos de XP
  /// 7. Aba da Trilha
  /// 8. Aba de Prática & Revisão com IA
  /// 9. Aba de Perfil & Conquistas
  /// 10. Aba de Ajustes
  Future<void> maybeStartFullTour({
    required BuildContext context,
    required GlobalKey chapterBannerKey,
    required GlobalKey targetNodeKey,
    required GlobalKey languageKey,
    required GlobalKey streakKey,
    required GlobalKey conchasKey,
    required GlobalKey xpKey,
    required GlobalKey trailTabKey,
    required GlobalKey practiceTabKey,
    required GlobalKey profileTabKey,
    required GlobalKey settingsTabKey,
    bool force = false,
  }) async {
    if (_isTourRunning) return;

    if (!force) {
      final alreadyDone = await OnboardingRepository.instance.isFullTourCompleted();
      if (alreadyDone) return;
    }

    // Aguarda montagem estável dos frames da interface
    await Future.delayed(const Duration(milliseconds: 650));
    if (!context.mounted) return;

    _isTourRunning = true;
    OnboardingAnalytics.logTourStarted(0);

    final steps = [
      TourStepTarget(
        key: chapterBannerKey,
        title: 'Capítulos & Guia Cultural 🌿',
        description:
            'Sua jornada é dividida em capítulos com saberes históricos de Pindorama. Toque no Guia Cultural para ler histórias, costumes e notas gramaticais.',
        mascotMood: MascotMood.celebrating,
        autoScroll: true,
      ),
      TourStepTarget(
        key: targetNodeKey,
        title: 'Caminho das Lições 📚',
        description:
            'Cada círculo na trilha representa uma lição prática com áudios, exercícios e narrativas orais. Toque no nó ativo para começar a aprender!',
        mascotMood: MascotMood.talking,
        autoScroll: true,
      ),
      TourStepTarget(
        key: languageKey,
        title: 'Idiomas & Variantes 🗣️',
        description:
            'Aqui você vê qual variante está ativa e pode alternar a qualquer momento entre o Tupi Antigo Clássico, Tupi Revitalizado e outras línguas indígenas!',
        mascotMood: MascotMood.happy,
      ),
      TourStepTarget(
        key: streakKey,
        title: 'Chama da Ofensiva 🔥',
        description:
            'Estude ao menos 5 minutos todos os dias para manter sua fogueira ancestral acesa e proteger seu ritmo de fluência!',
        mascotMood: MascotMood.celebrating,
      ),
      TourStepTarget(
        key: conchasKey,
        title: 'Conchas & Loja Ancestral 🐚',
        description:
            'Sua moeda da aldeia! Ganhe conchas concluindo lições e baús, e toque aqui para abrir a Oca de Trocas e desbloquear novos avatares, molduras e cosméticos.',
        mascotMood: MascotMood.happy,
      ),
      TourStepTarget(
        key: xpKey,
        title: 'Pontos de Experiência ⭐',
        description:
            'Cada resposta correta rende XP. Toque aqui para abrir seu painel de estatísticas com gráficos detalhados do seu vocabulário e nível alcançado.',
        mascotMood: MascotMood.talking,
      ),
      TourStepTarget(
        key: trailTabKey,
        title: 'Mapa da Trilha 🗺️',
        description:
            'Nesta aba você sempre pode retornar para o caminho principal de lições e navegar pelos capítulos de Pindorama.',
        mascotMood: MascotMood.happy,
      ),
      TourStepTarget(
        key: practiceTabKey,
        title: 'Aba de Prática & Revisão 🏋️',
        description:
            'Revise seu vocabulário com flashcards, repetição espaçada (SRS) e sessões temáticas sob medida com Inteligência Artificial!',
        mascotMood: MascotMood.talking,
      ),
      TourStepTarget(
        key: profileTabKey,
        title: 'Perfil & Conquistas 👤',
        description:
            'Acompanhe suas insígnias culturais (como o Muiraquitã e Fogo Sagrado), histórico de ofensiva e evolução na comunidade.',
        mascotMood: MascotMood.celebrating,
      ),
      TourStepTarget(
        key: settingsTabKey,
        title: 'Ajustes & Conclusão ⚙️',
        description:
            'Personalize efeitos de áudio, tema e notificações. Se quiser rever este tour completo no futuro, haverá uma opção exclusiva aqui em Ajustes!',
        mascotMood: MascotMood.happy,
      ),
    ];

    _runSequence(context: context, steps: steps, partIndex: 0);
  }

  /// Método legado de conveniência
  Future<void> maybeStartPart1({
    required BuildContext context,
    required GlobalKey targetNodeKey,
  }) async {
    // Redirecionado para o tour completo se ainda não executado
  }

  /// Método legado de conveniência
  Future<void> maybeStartPart2({
    required BuildContext context,
    required GlobalKey streakKey,
    required GlobalKey conchasKey,
    required GlobalKey xpKey,
    required GlobalKey practiceTabKey,
  }) async {
    // Redirecionado para o tour completo se ainda não executado
  }

  Future<void> _runSequence({
    required BuildContext context,
    required List<TourStepTarget> steps,
    required int partIndex,
    int stepIndex = 0,
  }) async {
    if (stepIndex >= steps.length || !context.mounted) {
      _isTourRunning = false;
      await OnboardingRepository.instance.setFullTourCompleted();
      OnboardingAnalytics.logTourCompleted(partIndex);
      return;
    }

    final target = steps[stepIndex];

    if (target.key.currentContext == null) {
      // Pula alvo se não estiver na tela (ex: em layout desktop vs mobile)
      _runSequence(
        context: context,
        steps: steps,
        partIndex: partIndex,
        stepIndex: stepIndex + 1,
      );
      return;
    }

    if (target.autoScroll && target.key.currentContext != null) {
      try {
        Scrollable.ensureVisible(
          target.key.currentContext!,
          duration: const Duration(milliseconds: 320),
          alignment: 0.5,
        );
        await Future.delayed(const Duration(milliseconds: 340));
      } catch (_) {}
    }

    if (!context.mounted) return;

    CoachMarkOverlay.show(
      context: context,
      target: target,
      currentStep: stepIndex + 1,
      totalSteps: steps.length,
      onNext: () {
        _runSequence(
          context: context,
          steps: steps,
          partIndex: partIndex,
          stepIndex: stepIndex + 1,
        );
      },
      onSkip: () async {
        _isTourRunning = false;
        await OnboardingRepository.instance.setFullTourCompleted();
        OnboardingAnalytics.logTourSkipped(partIndex);
      },
    );
  }
}
