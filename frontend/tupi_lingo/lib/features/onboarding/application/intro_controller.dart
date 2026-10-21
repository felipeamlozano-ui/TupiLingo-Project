import 'package:flutter/material.dart';
import '../domain/onboarding_draft.dart';
import '../data/onboarding_repository.dart';
import '../data/onboarding_analytics.dart';

/// Controlador reativo do fluxo de introdução e lição demo pré-cadastro.
class IntroController extends ChangeNotifier {
  int _currentStep = 0;
  OnboardingDraft _draft = const OnboardingDraft();
  bool _isLoading = false;

  // Estado da lição demo interna
  int _demoSubStep = 0;
  int _demoMistakes = 0;
  bool _isAnswerVerified = false;
  bool _isLastAnswerCorrect = false;

  int get currentStep => _currentStep;
  OnboardingDraft get draft => _draft;
  bool get isLoading => _isLoading;
  int get demoSubStep => _demoSubStep;
  int get demoMistakes => _demoMistakes;
  bool get isAnswerVerified => _isAnswerVerified;
  bool get isLastAnswerCorrect => _isLastAnswerCorrect;

  static const int totalSteps = 10;

  IntroController() {
    _loadInitialDraft();
  }

  Future<void> _loadInitialDraft() async {
    _isLoading = true;
    notifyListeners();

    final savedDraft = await OnboardingRepository.instance.loadDraft();
    if (savedDraft != null) {
      _draft = savedDraft;
      // Se já estava em algum passo avançado antes do cadastro, recupera
      if (savedDraft.stepIndex > 0 && savedDraft.stepIndex < totalSteps) {
        _currentStep = savedDraft.stepIndex;
      }
    }
    _isLoading = false;
    notifyListeners();

    OnboardingAnalytics.logIntroStarted();
  }

  void goToStep(int step) {
    if (step >= 0 && step < totalSteps) {
      _currentStep = step;
      _draft = _draft.copyWith(stepIndex: step);
      OnboardingRepository.instance.saveDraft(_draft);
      OnboardingAnalytics.logStepViewed(step, _getStepName(step));
      notifyListeners();
    }
  }

  void nextStep() {
    goToStep(_currentStep + 1);
  }

  void previousStep() {
    if (_currentStep > 0) {
      goToStep(_currentStep - 1);
    }
  }

  void setMotivation(String motivation) {
    _draft = _draft.copyWith(motivation: motivation);
    OnboardingRepository.instance.saveDraft(_draft);
    OnboardingAnalytics.logMotivationSelected(motivation);
    notifyListeners();
  }

  void setSource(String source) {
    _draft = _draft.copyWith(source: source);
    OnboardingRepository.instance.saveDraft(_draft);
    notifyListeners();
  }

  void setTupiLevel(String level) {
    _draft = _draft.copyWith(tupiLevel: level);
    OnboardingRepository.instance.saveDraft(_draft);
    OnboardingAnalytics.logLevelSelected(level);
    notifyListeners();
  }

  void setDailyGoal(int minutes) {
    _draft = _draft.copyWith(dailyGoalMinutes: minutes);
    OnboardingRepository.instance.saveDraft(_draft);
    OnboardingAnalytics.logDailyGoalSelected(minutes);
    notifyListeners();
  }

  void setName(String name) {
    _draft = _draft.copyWith(name: name.trim());
    OnboardingRepository.instance.saveDraft(_draft);
    notifyListeners();
  }

  // --- Controle da Lição Demo ---
  void startDemoLesson() {
    _demoSubStep = 0;
    _demoMistakes = 0;
    _isAnswerVerified = false;
    _isLastAnswerCorrect = false;
    OnboardingAnalytics.logDemoStarted();
    notifyListeners();
  }

  void setDemoVerification({required bool isCorrect}) {
    _isAnswerVerified = true;
    _isLastAnswerCorrect = isCorrect;
    if (!isCorrect) {
      _demoMistakes++;
    }
    notifyListeners();
  }

  void advanceDemoSubStep({required int totalSubSteps}) {
    _isAnswerVerified = false;
    _isLastAnswerCorrect = false;

    if (_demoSubStep < totalSubSteps - 1) {
      _demoSubStep++;
      OnboardingAnalytics.logDemoStepCompleted(_demoSubStep);
      notifyListeners();
    } else {
      // Demo concluída!
      _draft = _draft.copyWith(demoCompleted: true);
      OnboardingRepository.instance.saveDraft(_draft);
      OnboardingAnalytics.logDemoFinished(mistakesCount: _demoMistakes);
      nextStep(); // Vai para a tela de celebração
    }
  }

  String _getStepName(int step) {
    switch (step) {
      case 0:
        return 'meet_tupi';
      case 1:
        return 'you_already_speak_tupi';
      case 2:
        return 'motivation';
      case 3:
        return 'source';
      case 4:
        return 'level_declaration';
      case 5:
        return 'daily_goal';
      case 6:
        return 'preparing_trail';
      case 7:
        return 'plan_summary';
      case 8:
        return 'demo_lesson';
      case 9:
        return 'celebration_and_save';
      default:
        return 'step_$step';
    }
  }
}
