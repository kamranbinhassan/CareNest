import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const emerald = Color(0xFF176B5B);
  static const ocean = Color(0xFF176C9A);
  static const violet = Color(0xFF7056A8);
  static const rose = Color(0xFFB34F69);
  static const amber = Color(0xFFA36A16);
  static const tealPreset = Color(0xFF087F78);

  static Color _accent = emerald;
  static Brightness _brightness = Brightness.light;
  static bool _nightComfort = false;

  static Color get teal => _brightness == Brightness.dark
      ? Color.lerp(_accent, Colors.white, .42)!
      : _accent;
  static Color get accentFill => _accent;
  static Color get surface => _nightComfort
      ? const Color(0xFF191B16)
      : _brightness == Brightness.dark
      ? const Color(0xFF18211D)
      : Colors.white;
  static Color get outline => _nightComfort
      ? const Color(0xFF34352D)
      : _brightness == Brightness.dark
      ? const Color(0xFF34413B)
      : const Color(0xFFE2EAE6);
  static Color get statusInfo => _brightness == Brightness.dark
      ? const Color(0xFF9BD6F3)
      : const Color(0xFF346B8A);
  static Color get statusWarning => _brightness == Brightness.dark
      ? const Color(0xFFFFD27A)
      : const Color(0xFF8A580D);
  static Color get statusError => _brightness == Brightness.dark
      ? const Color(0xFFFF9A8E)
      : const Color(0xFF9C4038);
  static Color get ink => _nightComfort
      ? const Color(0xFFE8E5DC)
      : _brightness == Brightness.dark
      ? const Color(0xFFE5ECE8)
      : const Color(0xFF17312D);
  static Color get muted => _nightComfort
      ? const Color(0xFFAAA99F)
      : _brightness == Brightness.dark
      ? const Color(0xFFAFBCB6)
      : const Color(0xFF62706B);
  static Color get canvas => _nightComfort
      ? const Color(0xFF11130F)
      : _brightness == Brightness.dark
      ? const Color(0xFF101714)
      : const Color(0xFFF6F8F6);
  static Color get paleTeal => _nightComfort
      ? const Color(0xFF28291F)
      : _brightness == Brightness.dark
      ? Color.alphaBlend(
          _accent.withValues(alpha: .20),
          const Color(0xFF17211D),
        )
      : Color.alphaBlend(
          _accent.withValues(alpha: .12),
          const Color(0xFFF7FBF9),
        );

  static void configure({
    required Color accent,
    required Brightness brightness,
    required bool nightComfort,
  }) {
    _accent = accent;
    _brightness = brightness;
    _nightComfort = nightComfort;
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get comfortTheme =>
      _buildTheme(Brightness.dark, comfort: true);

  static ThemeData _buildTheme(Brightness brightness, {bool comfort = false}) {
    final dark = brightness == Brightness.dark;
    final background = comfort
        ? const Color(0xFF11130F)
        : dark
        ? const Color(0xFF101714)
        : const Color(0xFFF6F8F6);
    final surface = comfort
        ? const Color(0xFF191B16)
        : dark
        ? const Color(0xFF18211D)
        : Colors.white;
    final foreground = comfort
        ? const Color(0xFFE8E5DC)
        : dark
        ? const Color(0xFFE5ECE8)
        : const Color(0xFF17312D);
    final secondaryText = comfort
        ? const Color(0xFFAAA99F)
        : dark
        ? const Color(0xFFAFBCB6)
        : const Color(0xFF71817D);
    final outline = comfort
        ? const Color(0xFF34352D)
        : dark
        ? const Color(0xFF34413B)
        : const Color(0xFFE2EAE6);
    final themeAccent = dark
        ? Color.lerp(_accent, Colors.white, .42)!
        : _accent;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: themeAccent,
          onPrimary: _onAccent(themeAccent),
          secondary: dark ? themeAccent : _accent.withValues(alpha: .82),
          onSecondary: dark ? _onAccent(themeAccent) : Colors.white,
          surface: surface,
          onSurface: foreground,
          outline: outline,
          surfaceContainerHighest: comfort
              ? const Color(0xFF22241E)
              : dark
              ? const Color(0xFF222D28)
              : const Color(0xFFEEF3F0),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: 'sans',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
      ),
      dividerColor: outline,
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(bodyColor: foreground, displayColor: foreground),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: themeAccent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          backgroundColor: _accent,
          foregroundColor: _onAccent(_accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 54),
          foregroundColor: themeAccent,
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: themeAccent.withValues(alpha: dark ? .24 : .14),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(color: foreground),
        secondaryLabelStyle: TextStyle(color: themeAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF28332E)
            : const Color(0xFF17312D),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: themeAccent.withValues(alpha: dark ? .24 : .14),
        backgroundColor: surface,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? themeAccent
                : secondaryText,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: themeAccent,
        linearTrackColor: outline,
      ),
    );
  }

  static Color _onAccent(Color color) {
    const darkText = Color(0xFF17211D);
    return _contrast(color, Colors.white) >= _contrast(color, darkText)
        ? Colors.white
        : darkText;
  }

  static double _contrast(Color first, Color second) {
    final a = first.computeLuminance();
    final b = second.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + .05) / (darker + .05);
  }
}
