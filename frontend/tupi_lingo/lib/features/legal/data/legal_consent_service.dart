import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/core/logging/app_logger.dart';
import '../presentation/terms_of_use_screen.dart';

/// Service managing persistent acceptance of Terms of Use and Indigenous Language Disclaimer.
class LegalConsentService {
  static final LegalConsentService instance = LegalConsentService._();
  LegalConsentService._();

  static const _storage = FlutterSecureStorage();
  static const String currentTermsVersion = '1.2.0';

  static const String _keyTermsAccepted = 'legal_terms_accepted_v1_2';
  static const String _keyDisclaimerAccepted = 'legal_disclaimer_accepted_v1_2';
  static const String _keyAcceptedTimestamp = 'legal_terms_accepted_at';

  bool _isAcceptedMemory = false;

  bool get isAccepted => _isAcceptedMemory;

  /// Synchronous warm-up on app start via SharedPreferences
  void init(SharedPreferences prefs) {
    try {
      final termsBool = prefs.getBool(_keyTermsAccepted) ?? false;
      final disclaimerBool = prefs.getBool(_keyDisclaimerAccepted) ?? false;
      final termsStr = prefs.getString(_keyTermsAccepted);
      final disclaimerStr = prefs.getString(_keyDisclaimerAccepted);

      final termsOk = termsBool || termsStr == 'true';
      final disclaimerOk = disclaimerBool || disclaimerStr == 'true';

      if (termsOk && disclaimerOk) {
        _isAcceptedMemory = true;
      }
    } catch (_) {}
  }

  /// Checks whether the user has already accepted the current terms version
  Future<bool> checkConsentGiven() async {
    if (_isAcceptedMemory) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final termsBool = prefs.getBool(_keyTermsAccepted) ?? false;
      final disclaimerBool = prefs.getBool(_keyDisclaimerAccepted) ?? false;
      final termsStr = prefs.getString(_keyTermsAccepted);
      final disclaimerStr = prefs.getString(_keyDisclaimerAccepted);

      final termsOk = termsBool || termsStr == 'true';
      final disclaimerOk = disclaimerBool || disclaimerStr == 'true';

      if (termsOk && disclaimerOk) {
        _isAcceptedMemory = true;
        return true;
      }
    } catch (_) {}

    try {
      final terms = await _storage.read(key: _keyTermsAccepted);
      final disclaimer = await _storage.read(key: _keyDisclaimerAccepted);
      if (terms == 'true' && disclaimer == 'true') {
        _isAcceptedMemory = true;
        // Replicate to SharedPreferences for resilient offline reads
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyTermsAccepted, true);
          await prefs.setBool(_keyDisclaimerAccepted, true);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      AppLogger.w('LEGAL_CONSENT', 'Falha ao ler consentimento do storage seguro: $e');
    }

    return _isAcceptedMemory;
  }

  /// Persists user acceptance in secure storage and SharedPreferences
  Future<void> saveConsent({
    required bool termsAccepted,
    required bool disclaimerAccepted,
  }) async {
    _isAcceptedMemory = termsAccepted && disclaimerAccepted;
    final now = DateTime.now().toIso8601String();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTermsAccepted, termsAccepted);
      await prefs.setBool(_keyDisclaimerAccepted, disclaimerAccepted);
      await prefs.setString(_keyAcceptedTimestamp, now);
    } catch (e) {
      AppLogger.w('LEGAL_CONSENT', 'Erro ao salvar consentimento em SharedPreferences: $e');
    }

    try {
      await _storage.write(key: _keyTermsAccepted, value: termsAccepted.toString());
      await _storage.write(key: _keyDisclaimerAccepted, value: disclaimerAccepted.toString());
      await _storage.write(key: _keyAcceptedTimestamp, value: now);
      AppLogger.i('LEGAL_CONSENT', 'Termos v$currentTermsVersion aceitos com sucesso em $now.');
    } catch (e) {
      AppLogger.e('LEGAL_CONSENT', 'Erro ao salvar consentimento em secure storage: $e');
    }
  }

  /// Displays the acceptance screen modal if the user has not accepted yet
  Future<bool> showConsentModalIfNeeded(BuildContext context) async {
    final alreadyAccepted = await checkConsentGiven();
    if (alreadyAccepted) return true;

    if (!context.mounted) return false;

    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => TermsOfUseScreen(
          requireAcceptance: true,
          onAccepted: () async {
            await saveConsent(termsAccepted: true, disclaimerAccepted: true);
          },
        ),
      ),
    );

    return accepted == true;
  }
}
