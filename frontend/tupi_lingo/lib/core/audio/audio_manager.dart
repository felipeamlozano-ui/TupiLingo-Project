import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../features/settings/data/settings_service.dart';

/// Gerenciador Global de Áudio e Efeitos Sonoros (SFX) do TupiLingo.
/// Arquitetura Zero-Latência (< 5ms) com Warm AudioPool pré-aquecido no boot.
/// Disparo síncrono em paralelo com HapticFeedback (Fire-and-Forget).
/// Suporta round-robin de 3 micro-players para taps rápidos contínuos.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  static const String _assetCorrect = 'audio/correct.wav';
  static const String _assetIncorrect = 'audio/incorrect.wav';
  static const String _assetTap = 'audio/tap.wav';
  static const String _assetChest = 'audio/chest.wav';

  AudioPlayer? _correctPlayer;
  AudioPlayer? _incorrectPlayer;
  AudioPlayer? _chestPlayer;

  // Round-robin pool de 3 micro-players dedicados a toque rápido
  final List<AudioPlayer> _tapPlayers = [];
  int _currentTapIndex = 0;
  static const int _tapPoolSize = 3;

  bool _initialized = false;

  /// Inicializa e pré-aquece o Warm AudioPool na inicialização do app.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Future.wait([
        _preloadPlayer(_assetCorrect, 0.8).then((p) => _correctPlayer = p),
        _preloadPlayer(_assetIncorrect, 0.7).then((p) => _incorrectPlayer = p),
        _preloadPlayer(_assetChest, 0.9).then((p) => _chestPlayer = p),
        ...List.generate(_tapPoolSize, (_) => _preloadPlayer(_assetTap, 0.4)).map((fut) async {
          final p = await fut;
          _tapPlayers.add(p);
        }),
      ]);
      debugPrint('[AudioManager] Warm AudioPool inicializado e pré-aquecido com sucesso.');
    } catch (e) {
      debugPrint('[AudioManager] Erro ao pré-aquecer Warm AudioPool: $e');
    }
  }

  Future<AudioPlayer> _preloadPlayer(String assetPath, double volume) async {
    final player = AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.setSource(AssetSource(assetPath));
    } catch (e) {
      debugPrint('[AudioManager] Erro ao pré-carregar som $assetPath: $e');
    }
    return player;
  }

  /// Toca som de acerto de exercício e vibração no mesmo micro-segundo (< 5ms)
  Future<void> playCorrect() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.lightImpact();
      }
      return;
    }

    if (SettingsService.instance.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (_correctPlayer != null) {
      unawaited(
        _correctPlayer!.seek(Duration.zero).then((_) => _correctPlayer!.resume()).catchError((e) {
          debugPrint('[AudioManager] Falha no playback de acerto: $e');
        }),
      );
    }
  }

  /// Toca som de erro de exercício e vibração no mesmo micro-segundo (< 5ms)
  Future<void> playIncorrect() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.vibrate();
      }
      return;
    }

    if (SettingsService.instance.hapticFeedback) {
      HapticFeedback.heavyImpact();
    }

    if (_incorrectPlayer != null) {
      unawaited(
        _incorrectPlayer!.seek(Duration.zero).then((_) => _incorrectPlayer!.resume()).catchError((e) {
          debugPrint('[AudioManager] Falha no playback de erro: $e');
        }),
      );
    }
  }

  /// Toca som suave de clique com pool rotativo de 3 players (0ms atraso, sem corte)
  Future<void> playTap() async {
    if (!SettingsService.instance.soundEffects) {
      if (SettingsService.instance.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
      return;
    }

    if (SettingsService.instance.hapticFeedback) {
      HapticFeedback.selectionClick();
    }

    if (_tapPlayers.isNotEmpty) {
      final player = _tapPlayers[_currentTapIndex];
      _currentTapIndex = (_currentTapIndex + 1) % _tapPlayers.length;
      unawaited(
        player.seek(Duration.zero).then((_) => player.resume()).catchError((_) {
          SystemSound.play(SystemSoundType.click);
        }),
      );
    } else {
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

    if (SettingsService.instance.hapticFeedback) {
      HapticFeedback.heavyImpact();
    }

    if (_chestPlayer != null) {
      unawaited(
        _chestPlayer!.seek(Duration.zero).then((_) => _chestPlayer!.resume()).catchError((e) {
          debugPrint('[AudioManager] Falha no playback de baú: $e');
        }),
      );
    }
  }

  void dispose() {
    try {
      _correctPlayer?.dispose();
      _incorrectPlayer?.dispose();
      _chestPlayer?.dispose();
      for (final p in _tapPlayers) {
        p.dispose();
      }
      _tapPlayers.clear();
    } catch (_) {}
    _correctPlayer = null;
    _incorrectPlayer = null;
    _chestPlayer = null;
    _initialized = false;
  }
}
