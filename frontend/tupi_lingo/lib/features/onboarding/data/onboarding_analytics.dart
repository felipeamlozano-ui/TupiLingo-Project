import '../../analytics/analytics_service.dart';

/// Telemetria e rastreamento de funil do fluxo de onboarding e tutorial.
class OnboardingAnalytics {
  static void logIntroStarted() {
    AnalyticsService.instance.logEvent('intro_started');
  }

  static void logStepViewed(int stepIndex, String stepName) {
    AnalyticsService.instance.logEvent('intro_step_viewed', parameters: {
      'step_index': stepIndex,
      'step_name': stepName,
    });
  }

  static void logMotivationSelected(String motivation) {
    AnalyticsService.instance.logEvent('intro_motivation_selected', parameters: {
      'motivation': motivation,
    });
  }

  static void logLevelSelected(String level) {
    AnalyticsService.instance.logEvent('intro_level_selected', parameters: {
      'level': level,
    });
  }

  static void logDailyGoalSelected(int minutes) {
    AnalyticsService.instance.logEvent('intro_goal_selected', parameters: {
      'daily_minutes': minutes,
    });
  }

  static void logDemoStarted() {
    AnalyticsService.instance.logEvent('demo_started');
  }

  static void logDemoStepCompleted(int stepIndex) {
    AnalyticsService.instance.logEvent('demo_step_completed', parameters: {
      'step_index': stepIndex,
    });
  }

  static void logDemoFinished({required int mistakesCount}) {
    AnalyticsService.instance.logEvent('demo_finished', parameters: {
      'mistakes_count': mistakesCount,
    });
  }

  static void logSignupPromptViewed() {
    AnalyticsService.instance.logEvent('signup_prompt_viewed');
  }

  static void logReminderAnswered(bool accepted, {int? preferredHour}) {
    AnalyticsService.instance.logEvent('reminder_answered', parameters: {
      'accepted': accepted,
      'preferred_hour': ?preferredHour,
    });
  }

  static void logTourStarted(int part) {
    AnalyticsService.instance.logEvent('tour_started', parameters: {
      'part': part,
    });
  }

  static void logTourCompleted(int part) {
    AnalyticsService.instance.logEvent('tour_completed', parameters: {
      'part': part,
    });
  }

  static void logTourSkipped(int part) {
    AnalyticsService.instance.logEvent('tour_skipped', parameters: {
      'part': part,
    });
  }
}
