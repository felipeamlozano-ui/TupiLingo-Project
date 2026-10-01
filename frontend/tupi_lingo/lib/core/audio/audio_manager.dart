import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../features/settings/data/settings_service.dart';

/// Gerenciador Global de Áudio e Efeitos Sonoros (SFX) do TupiLingo.
/// Reproduz efeitos de:
/// - Acerto de resposta (`playCorrect`)
/// - Erro de resposta (`playIncorrect`)
/// - Toque / Navegação (`playTap`)
/// - Abertura de Baú / Recompensa (`playChestReward`)
/// Respeita rigorosamente a configuração do usuário em [SettingsService].
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  AudioPlayer? _player;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    try {
      _player = AudioPlayer();
      _player?.setPlayerMode(PlayerMode.lowLatency);
      _initialized = true;
    } catch (e) {
      debugPrint('[AudioManager] Erro ao inicializar player de áudio: $e');
    }
  }

  /// Toca som de acerto de exercício e vibração de sucesso
  Future<void> playCorrect() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.lightImpact();
      }
      return;
    }

    try {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      _player ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _player?.play(AssetSource('audio/correct.wav'), volume: 0.8);
    } catch (e) {
      debugPrint('[AudioManager] Erro ao tocar som de acerto: $e');
    }
  }

  /// Toca som de erro de exercício e vibração de alerta
  Future<void> playIncorrect() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.vibrate();
      }
      return;
    }

    try {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      _player ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _player?.play(AssetSource('audio/incorrect.wav'), volume: 0.7);
    } catch (e) {
      debugPrint('[AudioManager] Erro ao tocar som de erro: $e');
    }
  }

  /// Toca som suave de clique / navegação de abas e botões
  Future<void> playTap() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
      return;
    }

    try {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
      _player ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _player?.play(AssetSource('audio/tap.wav'), volume: 0.4);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Toca fanfarra festiva ao abrir um Baú Ancestral
  Future<void> playChestReward() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      return;
    }

    try {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      _player ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await _player?.play(AssetSource('audio/chest.wav'), volume: 0.9);
    } catch (e) {
      debugPrint('[AudioManager] Erro ao tocar som de baú: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
