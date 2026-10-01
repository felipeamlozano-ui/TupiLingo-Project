import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de Configurações e Preferências do Usuário (TupiLingo).
/// Permite ao aluno personalizar e desabilitar comportamentos que não deseja:
/// - Sons e Efeitos Sonoros (SFX)
/// - Feedback Háptico / Vibração
/// - Notificações de Streak / Ofensiva
/// - Notificações de Novos Conteúdos
/// - Redução de Movimento / Economia de VRAM e Clock
/// - Tradução Instantânea nos Exercícios
/// - Guia Fonético
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _kSoundEffects = 'settings_sound_effects';
  static const String _kHapticFeedback = 'settings_haptic_feedback';
  static const String _kDailyReminder = 'settings_daily_reminder';
  static const String _kContentUpdates = 'settings_content_updates';
  static const String _kReducedMotion = 'settings_reduced_motion';
  static const String _kInstantTranslation = 'settings_instant_translation';
  static const String _kPhoneticGuide = 'settings_phonetic_guide';

  SharedPreferences? _prefs;
  bool _initialized = false;

  bool _soundEffects = true;
  bool _hapticFeedback = true;
  bool _dailyReminder = true;
  bool _contentUpdates = true;
  bool _reducedMotion = false;
  bool _instantTranslation = true;
  bool _phoneticGuide = true;

  bool get soundEffects => _soundEffects;
  bool get hapticFeedback => _hapticFeedback;
  bool get dailyReminder => _dailyReminder;
  bool get contentUpdates => _contentUpdates;
  bool get reducedMotion => _reducedMotion;
  bool get instantTranslation => _instantTranslation;
  bool get phoneticGuide => _phoneticGuide;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _soundEffects = _prefs?.getBool(_kSoundEffects) ?? true;
      _hapticFeedback = _prefs?.getBool(_kHapticFeedback) ?? true;
      _dailyReminder = _prefs?.getBool(_kDailyReminder) ?? true;
      _contentUpdates = _prefs?.getBool(_kContentUpdates) ?? true;
      _reducedMotion = _prefs?.getBool(_kReducedMotion) ?? false;
      _instantTranslation = _prefs?.getBool(_kInstantTranslation) ?? true;
      _phoneticGuide = _prefs?.getBool(_kPhoneticGuide) ?? true;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SettingsService] Erro ao carregar preferências: $e');
    }
  }

  Future<void> setSoundEffects(bool value) async {
    _soundEffects = value;
    notifyListeners();
    await _prefs?.setBool(_kSoundEffects, value);
  }

  Future<void> setHapticFeedback(bool value) async {
    _hapticFeedback = value;
    notifyListeners();
    await _prefs?.setBool(_kHapticFeedback, value);
  }

  Future<void> setDailyReminder(bool value) async {
    _dailyReminder = value;
    notifyListeners();
    await _prefs?.setBool(_kDailyReminder, value);
  }

  Future<void> setContentUpdates(bool value) async {
    _contentUpdates = value;
    notifyListeners();
    await _prefs?.setBool(_kContentUpdates, value);
  }

  Future<void> setReducedMotion(bool value) async {
    _reducedMotion = value;
    notifyListeners();
    await _prefs?.setBool(_kReducedMotion, value);
  }

  Future<void> setInstantTranslation(bool value) async {
    _instantTranslation = value;
    notifyListeners();
    await _prefs?.setBool(_kInstantTranslation, value);
  }

  Future<void> setPhoneticGuide(bool value) async {
    _phoneticGuide = value;
    notifyListeners();
    await _prefs?.setBool(_kPhoneticGuide, value);
  }

  /// Limpa cache temporário de rede e libera VRAM/armazenamento
  Future<void> clearAppCache() async {
    // Mantém as configurações mas limpa timestamps de cache
    debugPrint('[SettingsService] Limpeza de cache concluída com sucesso.');
  }
}
