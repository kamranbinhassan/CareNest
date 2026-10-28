import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_theme.dart';

enum AppearanceMode { system, light, dark, nightComfort }

enum AccentPreset {
  emerald('Emerald', Color(0xFF176B5B)),
  ocean('Ocean blue', Color(0xFF176C9A)),
  violet('Violet', Color(0xFF7056A8)),
  rose('Rose', Color(0xFFB34F69)),
  amber('Amber', Color(0xFFA36A16)),
  teal('Teal', Color(0xFF087F78));

  const AccentPreset(this.label, this.color);
  final String label;
  final Color color;
}

class AppearanceController extends ChangeNotifier with WidgetsBindingObserver {
  AppearanceController._() {
    WidgetsBinding.instance.addObserver(this);
    _syncThemePalette();
  }

  static final AppearanceController instance = AppearanceController._();
  static const _storage = FlutterSecureStorage();
  static const _modeKey = 'appearance_mode_v1';
  static const _accentKey = 'appearance_accent_v1';

  AppearanceMode mode = AppearanceMode.system;
  AccentPreset accent = AccentPreset.emerald;
  bool isLoaded = false;
  bool persistenceAvailable = true;
  String? persistenceMessage;
  Future<void> _writeQueue = Future<void>.value();

  ThemeMode get materialThemeMode => switch (mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark || AppearanceMode.nightComfort => ThemeMode.dark,
  };

  bool get isNightComfort => mode == AppearanceMode.nightComfort;
  bool get isDarkAppearance => switch (mode) {
    AppearanceMode.light => false,
    AppearanceMode.dark || AppearanceMode.nightComfort => true,
    AppearanceMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };

  Future<void> load() async {
    try {
      final modeValue = await _storage.read(key: _modeKey);
      mode =
          AppearanceMode.values
              .where((item) => item.name == modeValue)
              .firstOrNull ??
          AppearanceMode.system;
      final accentValue = await _storage.read(key: _accentKey);
      accent =
          AccentPreset.values
              .where((item) => item.name == accentValue)
              .firstOrNull ??
          AccentPreset.emerald;
      persistenceAvailable = true;
      persistenceMessage = null;
    } catch (_) {
      persistenceAvailable = false;
      persistenceMessage =
          'Appearance preferences could not be loaded. The default theme is active.';
    }
    isLoaded = true;
    _syncThemePalette();
    notifyListeners();
  }

  Future<void> setMode(AppearanceMode value) async {
    if (mode == value) return;
    mode = value;
    _applyAndPersist(_modeKey, value.name);
  }

  Future<void> setAccent(AccentPreset value) async {
    if (accent == value) return;
    accent = value;
    _applyAndPersist(_accentKey, value.name);
  }

  void _applyAndPersist(String key, String value) {
    _syncThemePalette();
    notifyListeners();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storage.write(key: key, value: value);
        persistenceAvailable = true;
        persistenceMessage = null;
      } catch (_) {
        persistenceAvailable = false;
        persistenceMessage =
            'This appearance choice is active for now but could not be saved on this device.';
      }
      notifyListeners();
    });
  }

  void _syncThemePalette() {
    final brightness = isNightComfort
        ? Brightness.dark
        : isDarkAppearance
        ? Brightness.dark
        : Brightness.light;
    AppTheme.configure(
      accent: accent.color,
      brightness: brightness,
      nightComfort: isNightComfort,
    );
  }

  @override
  void didChangePlatformBrightness() {
    if (mode == AppearanceMode.system) {
      _syncThemePalette();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

extension _AppearanceFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
