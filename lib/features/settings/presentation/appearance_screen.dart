import 'package:flutter/material.dart';
import '../../../core/theme/appearance_controller.dart';
import '../../../core/theme/app_theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppearanceController.instance,
    builder: (context, _) {
      final preferences = AppearanceController.instance;
      return Scaffold(
        appBar: AppBar(title: const Text('Appearance')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Make it yours',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your choices apply throughout the app and are saved on this device.',
                style: TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 21),
              const _SectionLabel(
                title: 'Theme mode',
                subtitle: 'Choose how CareNest looks across the day.',
              ),
              const SizedBox(height: 10),
              ...AppearanceMode.values.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ModeCard(
                    mode: mode,
                    selected: preferences.mode == mode,
                    onTap: () => preferences.setMode(mode),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel(
                title: 'Accent color',
                subtitle:
                    'Used for buttons, charts, selection, and highlights.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: AccentPreset.values
                    .map(
                      (preset) => _AccentOption(
                        preset: preset,
                        selected: preferences.accent == preset,
                        onTap: () => preferences.setAccent(preset),
                      ),
                    )
                    .toList(),
              ),
              if (preferences.persistenceMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2DB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    preferences.persistenceMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF70501C),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _preview(context),
            ],
          ),
        ),
      );
    },
  );

  Widget _preview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colors.onPrimary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Family care overview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: .72,
                minHeight: 8,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final AppearanceMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = switch (mode) {
      AppearanceMode.system => (
        'System default',
        'Follows your phone’s appearance.',
        Icons.brightness_auto_rounded,
      ),
      AppearanceMode.light => (
        'Light',
        'Bright surfaces with clear contrast.',
        Icons.light_mode_rounded,
      ),
      AppearanceMode.dark => (
        'Dark',
        'A dark interface for low-light settings.',
        Icons.dark_mode_rounded,
      ),
      AppearanceMode.nightComfort => (
        'Night Comfort',
        'A softer near-black palette with warm text and reduced glare.',
        Icons.nights_stay_rounded,
      ),
    };
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                details.$3,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.$2,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              RadioGroup<AppearanceMode>(
                groupValue: mode,
                onChanged: (_) => onTap(),
                child: Radio<AppearanceMode>(value: mode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentOption extends StatelessWidget {
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;
  const _AccentOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${preset.label} accent${selected ? ', selected' : ''}',
      button: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 104,
            height: 75,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? preset.color : theme.colorScheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: preset.color,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    preset.color,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : const Color(0xFF17211D),
                        )
                      : null,
                ),
                const SizedBox(height: 5),
                Text(
                  preset.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.ink,
        ),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
    ],
  );
}
