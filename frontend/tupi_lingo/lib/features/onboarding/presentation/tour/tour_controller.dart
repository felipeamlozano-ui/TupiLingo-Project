import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/onboarding/data/onboarding_repository.dart';
import 'package:tupi_lingo/features/onboarding/data/onboarding_analytics.dart';
import '../widgets/mascot_avatar.dart';
import 'coach_mark_overlay.dart';

/// Controlador da máquina de estados do Tour Guiado em 2 partes da tela Home.
class TourController {
  TourController._();
  static final TourController instance = TourController._();

  bool _isTourRunning = false;

  bool get isTourRunning => _isTourRunning;

  /// Dispara a Parte 1 do Tour (Primeiro contato com a trilha).
  /// Ilumina o nó ativo inicial "SUA VEZ".
  Future<void> maybeStartPart1({
    required BuildContext context,
    required GlobalKey targetNodeKey,
  }) async {
    if (_isTourRunning) return;

    final alreadyDone = await OnboardingRepository.instance.isTourPart1Completed();
    if (alreadyDone) return;

    // Aguarda montagem estável dos frames da trilha
    await Future.delayed(const Duration(milliseconds: 650));
    if (!context.mounted) return;

    if (targetNodeKey.currentContext == null) {
      // Se a chave ainda não está renderizada, não bloqueia o usuário
      return;
    }

    _isTourRunning = true;
    OnboardingAnalytics.logTourStarted(1);

    CoachMarkOverlay.show(
      context: context,
      target: TourStepTarget(
        key: targetNodeKey,
        title: 'Essa é a sua trilha ancestral!',
        description:
            'Cada nó circular representa uma lição prática com histórias e saberes de Pindorama. Toque aqui para iniciar!',
        mascotMood: MascotMood.celebrating,
        requiresTap: true,
      ),
      currentStep: 1,
      totalSteps: 1,
      onNext: () {
        _isTourRunning = false;
        OnboardingRepository.instance.setTourPart1Completed();
        OnboardingAnalytics.logTourCompleted(1);
      },
      onSkip: () {
        _isTourRunning = false;
        OnboardingRepository.instance.setTourPart1Completed();
        OnboardingAnalytics.logTourSkipped(1);
      },
    );
  }

  /// Dispara a Parte 2 do Tour (após o aluno completar a sua 1ª lição real).
  /// Apresenta a Ofensiva (Streak), Conchas, XP e a Aba de Prática.
  Future<void> maybeStartPart2({
    required BuildContext context,
    required GlobalKey streakKey,
    required GlobalKey conchasKey,
    required GlobalKey xpKey,
    required GlobalKey practiceTabKey,
  }) async {
    if (_isTourRunning) return;

    final alreadyDone = await OnboardingRepository.instance.isTourPart2Completed();
    if (alreadyDone) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;

    _isTourRunning = true;
    OnboardingAnalytics.logTourStarted(2);

    final steps = [
      TourStepTarget(
        key: streakKey,
        title: 'Chama da Ofensiva! 🔥',
        description:
            'Estude ao menos 5 minutos todos os dias para manter sua chama acesa e proteger seu progresso!',
        mascotMood: MascotMood.celebrating,
      ),
      TourStepTarget(
        key: conchasKey,
        title: 'Conchas Sagradas 🐚',
        description:
            'Sua moeda da aldeia! Use na Oca de Trocas para desbloquear temas visuais, novos avatares e molduras.',
        mascotMood: MascotMood.happy,
      ),
      TourStepTarget(
        key: xpKey,
        title: 'Pontos de Experiência ⭐',
        description:
            'Acompanhe seu avanço de nível e veja relatórios completos de domínio no painel de desempenho.',
        mascotMood: MascotMood.talking,
      ),
      TourStepTarget(
        key: practiceTabKey,
        title: 'Aba de Prática & Revisão 🏋️',
        description:
            'Revise seu vocabulário acumulado com flashcards e sessões temáticas sob medida com IA.',
        mascotMood: MascotMood.happy,
      ),
    ];

    _runSequence(context: context, steps: steps, partIndex: 2);
  }

  void _runSequence({
    required BuildContext context,
    required List<TourStepTarget> steps,
    required int partIndex,
    int stepIndex = 0,
  }) {
    if (stepIndex >= steps.length || !context.mounted) {
      _isTourRunning = false;
      if (partIndex == 2) {
        OnboardingRepository.instance.setTourPart2Completed();
      }
      OnboardingAnalytics.logTourCompleted(partIndex);
      return;
    }

    final target = steps[stepIndex];

    if (target.key.currentContext == null) {
      // Pula alvo se não estiver na tela (ex: tab oculta)
      _runSequence(
        context: context,
        steps: steps,
        partIndex: partIndex,
        stepIndex: stepIndex + 1,
      );
      return;
    }

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
      onSkip: () {
        _isTourRunning = false;
        if (partIndex == 2) {
          OnboardingRepository.instance.setTourPart2Completed();
        }
        OnboardingAnalytics.logTourSkipped(partIndex);
      },
    );
  }
}
