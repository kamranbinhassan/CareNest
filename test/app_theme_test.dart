import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/theme/app_theme.dart';
import 'package:medicine_adherence_monitoring/core/theme/appearance_controller.dart';

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() {
    AppTheme.configure(
      accent: AccentPreset.emerald.color,
      brightness: Brightness.light,
      nightComfort: false,
    );
  });

  test('dark and night comfort surfaces retain readable body contrast', () {
    for (final comfort in [false, true]) {
      AppTheme.configure(
        accent: AccentPreset.emerald.color,
        brightness: Brightness.dark,
        nightComfort: comfort,
      );
      expect(AppTheme.surface, isNot(Colors.white));
      expect(
        _contrast(AppTheme.ink, AppTheme.surface),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrast(AppTheme.muted, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, isNot(Colors.black));
    }
  });

  test('light muted text remains readable on app surfaces', () {
    AppTheme.configure(
      accent: AccentPreset.emerald.color,
      brightness: Brightness.light,
      nightComfort: false,
    );
    expect(
      _contrast(AppTheme.muted, AppTheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppTheme.muted, AppTheme.canvas),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('dark accent text and status colors remain distinguishable', () {
    for (final preset in AccentPreset.values) {
      AppTheme.configure(
        accent: preset.color,
        brightness: Brightness.dark,
        nightComfort: false,
      );
      expect(
        _contrast(AppTheme.teal, AppTheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(AppTheme.statusWarning, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppTheme.statusError, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppTheme.statusInfo, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('accent buttons retain readable foregrounds in both themes', () {
    for (final brightness in Brightness.values) {
      for (final preset in AccentPreset.values) {
        AppTheme.configure(
          accent: preset.color,
          brightness: brightness,
          nightComfort: false,
        );
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final style = theme.filledButtonTheme.style!;
        final background = style.backgroundColor!.resolve({})!;
        final foreground = style.foregroundColor!.resolve({})!;
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    }
  });
}
