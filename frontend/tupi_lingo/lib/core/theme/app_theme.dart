import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/core/security/secure_vault.dart';

/// Gerenciador reativo de modo de tema e cosmético equipado com persistência segura
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static final ThemeNotifier instance = ThemeNotifier._();

  static const String _storageKey = 'tupilingo_theme_mode';
  static const String _keyEquippedTheme = 'tupilingo_cosmetic_equipped_theme';

  String _equippedTheme = 'theme_floresta_jade';
  String get equippedTheme => _equippedTheme;

  ThemeNotifier._() : super(ThemeMode.system) {
    _loadPersistedTheme();
  }

  /// Inicialização síncrona a partir do SharedPreferences em cold-boot
  void init(SharedPreferences prefs) {
    final savedMode = prefs.getString(_storageKey);
    if (savedMode == 'dark') {
      value = ThemeMode.dark;
    } else if (savedMode == 'light') {
      value = ThemeMode.light;
    } else {
      value = ThemeMode.system;
    }

    final savedTheme = prefs.getString(_keyEquippedTheme);
    if (savedTheme != null && savedTheme.isNotEmpty) {
      _equippedTheme = savedTheme;
    }
    notifyListeners();
  }

  bool isDark(BuildContext context) {
    if (value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return value == ThemeMode.dark;
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_storageKey) ?? await SecureVault.readSecret(_storageKey);
      if (savedMode == 'dark') {
        value = ThemeMode.dark;
      } else if (savedMode == 'light') {
        value = ThemeMode.light;
      } else {
        value = ThemeMode.system;
      }

      final savedTheme = prefs.getString(_keyEquippedTheme) ?? await SecureVault.readSecret(_keyEquippedTheme);
      if (savedTheme != null && savedTheme.isNotEmpty) {
        _equippedTheme = savedTheme;
      }
      notifyListeners();
    } catch (_) {
      // Degradação graciosa mantendo ThemeMode.system e tema padrão
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    notifyListeners();
    try {
      final str = mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, str);
      await SecureVault.writeSecret(_storageKey, str);
    } catch (_) {}
  }

  /// Equipa um tema cosmético da Loja e atualiza o aplicativo instantaneamente
  Future<void> setEquippedTheme(String themeId) async {
    _equippedTheme = themeId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEquippedTheme, themeId);
      await SecureVault.writeSecret(_keyEquippedTheme, themeId);
    } catch (_) {}
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentlyDark = isDark(context);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Sistema Central de Temas e Identidade Visual Ancestral Tupi
class AppTheme {
  // ─── Paletas Dinâmicas por Tema Cosmético Equipado ───────────────────────────

  static Color get lightBackground {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFFBF7EE);
      case 'theme_noite_tupa':
        return const Color(0xFFF0F6FA);
      case 'theme_fogo_caapora':
        return const Color(0xFFFDF2F0);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFF3F2E8);
    }
  }

  static Color get darkBackground {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFF18130C);
      case 'theme_noite_tupa':
        return const Color(0xFF060B15);
      case 'theme_fogo_caapora':
        return const Color(0xFF150808);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF0C1210);
    }
  }

  static Color get lightCardSurface => Colors.white;

  static Color get darkCardSurface {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFF241C13);
      case 'theme_noite_tupa':
        return const Color(0xFF0F172A);
      case 'theme_fogo_caapora':
        return const Color(0xFF220D0D);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF151E1B);
    }
  }

  static Color get lightSurfaceSubtle {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFFFFDF7);
      case 'theme_noite_tupa':
        return const Color(0xFFF7FAFC);
      case 'theme_fogo_caapora':
        return const Color(0xFFFFF8F7);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFFAF9F5);
    }
  }

  static Color get darkSurfaceSubtle {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFF2E2419);
      case 'theme_noite_tupa':
        return const Color(0xFF1E293B);
      case 'theme_fogo_caapora':
        return const Color(0xFF2E1212);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF1C2723);
    }
  }

  static Color get lightPrimary {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFD08A45);
      case 'theme_noite_tupa':
        return const Color(0xFF0284C7);
      case 'theme_fogo_caapora':
        return const Color(0xFFDC2626);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFD08A45);
    }
  }

  static Color get lightPrimaryDark {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFA56627);
      case 'theme_noite_tupa':
        return const Color(0xFF0369A1);
      case 'theme_fogo_caapora':
        return const Color(0xFFB91C1C);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFA56627);
    }
  }

  static Color get darkPrimary {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFF59E0B);
      case 'theme_noite_tupa':
        return const Color(0xFF38BDF8);
      case 'theme_fogo_caapora':
        return const Color(0xFFF87171);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFE69A56);
    }
  }

  static Color get darkPrimaryDark {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFD97706);
      case 'theme_noite_tupa':
        return const Color(0xFF0284C7);
      case 'theme_fogo_caapora':
        return const Color(0xFFDC2626);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFB87030);
    }
  }

  static Color get lightAccent {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFC27803);
      case 'theme_noite_tupa':
        return const Color(0xFF0284C7);
      case 'theme_fogo_caapora':
        return const Color(0xFFEA580C);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF0E5D4E);
    }
  }

  static Color get lightAccentDark {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFF8D5500);
      case 'theme_noite_tupa':
        return const Color(0xFF075985);
      case 'theme_fogo_caapora':
        return const Color(0xFFC2410C);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF083C32);
    }
  }

  static Color get darkAccent {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFE08B38);
      case 'theme_noite_tupa':
        return const Color(0xFF38BDF8);
      case 'theme_fogo_caapora':
        return const Color(0xFFFB923C);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF1EC9A5);
    }
  }

  static Color get darkAccentDark {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFB46318);
      case 'theme_noite_tupa':
        return const Color(0xFF0369A1);
      case 'theme_fogo_caapora':
        return const Color(0xFFEA580C);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF0E6955);
    }
  }

  static Color get lightTextPrimary => const Color(0xFF1F2937);

  static Color get lightTextSecondary => const Color(0xFF565D6D);

  static Color get darkTextPrimary => const Color(0xFFF3F4F6);

  static Color get darkTextSecondary => const Color(0xFF9CA3AF);

  static Color get lightBorder {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFFEADFC9);
      case 'theme_noite_tupa':
        return const Color(0xFFCFE2EE);
      case 'theme_fogo_caapora':
        return const Color(0xFFF2D2CE);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFFD0D0D0);
    }
  }

  static Color get darkBorder {
    switch (ThemeNotifier.instance.equippedTheme) {
      case 'theme_areia_sagrada':
        return const Color(0xFF3D2E1F);
      case 'theme_noite_tupa':
        return const Color(0xFF1E293B);
      case 'theme_fogo_caapora':
        return const Color(0xFF3D1818);
      case 'theme_floresta_jade':
      default:
        return const Color(0xFF263833);
    }
  }

  static Color get lightNodeLocked => const Color(0xFFE2DFD4);
  static Color get lightNodeLockedBorder => const Color(0xFFC7C3B6);
  static Color get darkNodeLocked => const Color(0xFF19231F);
  static Color get darkNodeLockedBorder => const Color(0xFF23322C);

  // ─── Gamificação Comum ────────────────────────────────────────────────────────
  static const Color xpColor = Color(0xFFD08A45);
  static const Color xpColorDark = Color(0xFFF59E0B);
  static const Color streakColor = Color(0xFFE05638);
  static const Color shellColor = Color(0xFF1EC9A5);

  // ─── Helpers de Acesso Dinâmico por Contexto ──────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkCardSurface : lightCardSurface;

  static Color surfaceSubtle(BuildContext context) =>
      isDark(context) ? darkSurfaceSubtle : lightSurfaceSubtle;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color primary(BuildContext context) =>
      isDark(context) ? darkPrimary : lightPrimary;

  static Color primaryDark(BuildContext context) =>
      isDark(context) ? darkPrimaryDark : lightPrimaryDark;

  static Color accent(BuildContext context) =>
      isDark(context) ? darkAccent : lightAccent;

  static Color accentDark(BuildContext context) =>
      isDark(context) ? darkAccentDark : lightAccentDark;

  static Color nodeLocked(BuildContext context) =>
      isDark(context) ? darkNodeLocked : lightNodeLocked;

  static Color nodeLockedBorder(BuildContext context) =>
      isDark(context) ? darkNodeLockedBorder : lightNodeLockedBorder;

  // ─── ThemeData: Tema Claro ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCardSurface,
      dividerColor: lightBorder,
      colorScheme: ColorScheme.light(
        primary: lightPrimary,
        secondary: lightAccent,
        surface: lightCardSurface,
        surfaceContainer: lightSurfaceSubtle,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightCardSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightTextSecondary,
      ),
    );
  }

  // ─── ThemeData: Tema Escuro ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCardSurface,
      dividerColor: darkBorder,
      colorScheme: ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: darkCardSurface,
        surfaceContainer: darkSurfaceSubtle,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCardSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextSecondary,
      ),
    );
  }
}
