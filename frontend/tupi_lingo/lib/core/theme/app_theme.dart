import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/security/secure_vault.dart';

/// Gerenciador reativo de modo de tema com persistência segura
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static final ThemeNotifier instance = ThemeNotifier._();

  static const String _storageKey = 'tupilingo_theme_mode';

  ThemeNotifier._() : super(ThemeMode.system) {
    _loadPersistedTheme();
  }

  bool isDark(BuildContext context) {
    if (value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return value == ThemeMode.dark;
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final saved = await SecureVault.readSecret(_storageKey);
      if (saved == 'dark') {
        value = ThemeMode.dark;
      } else if (saved == 'light') {
        value = ThemeMode.light;
      } else {
        value = ThemeMode.system;
      }
    } catch (_) {
      // Degradação graciosa mantendo ThemeMode.system
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    try {
      final str = mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system');
      await SecureVault.writeSecret(_storageKey, str);
    } catch (_) {}
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentlyDark = isDark(context);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Sistema Central de Temas e Identidade Visual Ancestral Tupi
class AppTheme {
  // ─── Paleta Clara (Areia Sagrada & Floresta Diurna) ───────────────────────────
  static const Color lightBackground = Color(0xFFF3F2E8);
  static const Color lightCardSurface = Colors.white;
  static const Color lightSurfaceSubtle = Color(0xFFFAF9F5);
  static const Color lightPrimary = Color(0xFFD08A45);
  static const Color lightPrimaryDark = Color(0xFFA56627);
  static const Color lightAccent = Color(0xFF0E5D4E);
  static const Color lightAccentDark = Color(0xFF083C32);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF565D6D);
  static const Color lightBorder = Color(0xFFD0D0D0);
  static const Color lightNodeLocked = Color(0xFFE2DFD4);
  static const Color lightNodeLockedBorder = Color(0xFFC7C3B6);

  // ─── Paleta Noturna Ancestral (Obsidiana da Floresta & Jade Polido) ───────────
  static const Color darkBackground = Color(0xFF0C1210);       // Obsidiana da Noite Amazônica
  static const Color darkCardSurface = Color(0xFF151E1B);      // Jade Escuro Polido
  static const Color darkSurfaceSubtle = Color(0xFF1C2723);    // Camada de elevação
  static const Color darkPrimary = Color(0xFFE69A56);          // Âmbar Flamejante Ancestral
  static const Color darkPrimaryDark = Color(0xFFB87030);      // Sombra 3D Âmbar
  static const Color darkAccent = Color(0xFF1EC9A5);           // Esmeralda Radiante
  static const Color darkAccentDark = Color(0xFF0E6955);       // Sombra 3D Esmeralda
  static const Color darkTextPrimary = Color(0xFFF3F4F6);      // Luar Noturno
  static const Color darkTextSecondary = Color(0xFF9CA3AF);    // Névoa Prateada
  static const Color darkBorder = Color(0xFF263833);           // Rocha de Jade
  static const Color darkNodeLocked = Color(0xFF19231F);       // Pedra Noturna Adormecida
  static const Color darkNodeLockedBorder = Color(0xFF23322C); // Sombra Pedra Noturna

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
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightAccent,
        surface: lightCardSurface,
        surfaceContainer: lightSurfaceSubtle,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
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
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: darkCardSurface,
        surfaceContainer: darkSurfaceSubtle,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCardSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextSecondary,
      ),
    );
  }
}
