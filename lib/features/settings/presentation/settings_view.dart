import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/care_session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/theme/appearance_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/login_screen.dart';
import 'reminder_settings_screen.dart';

class SettingsView extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const SettingsView({super.key, this.onNavigateToTab});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _appearance = AppearanceController.instance;
  final _reminders = ReminderService.instance;
  final _session = CareSession.instance;

  bool _isTogglingReminders = false;
  bool? _hasCloudToken;

  @override
  void initState() {
    super.initState();
    _checkCloudStatus();
  }

  Future<void> _checkCloudStatus() async {
    final hasToken = await ApiClient().hasToken;
    if (mounted) setState(() => _hasCloudToken = hasToken);
  }

  Future<void> _toggleReminders(bool enable) async {
    setState(() => _isTogglingReminders = true);
    try {
      if (enable) {
        final allowed = await _reminders.enable();
        if (!allowed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications blocked by system. Allow them in Android settings.',
              ),
            ),
          );
        }
      } else {
        await _reminders.disable();
      }
    } finally {
      if (mounted) setState(() => _isTogglingReminders = false);
    }
  }

  void _showExportDialog() {
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'CareNest',
      'version': '1.2.0',
      'familyName': _session.familyName,
      'caregiver': _session.ownerName,
      'members': _session.members.map((m) => m.toJson()).toList(),
      'medicines': {
        for (final m in _session.members)
          m.id: _session.medicinesFor(m.id).map((med) => med.toJson()).toList(),
      },
      'doseHistoryCount': _session.doseEvents.length,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Care Data'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Here is a readable backup summary of your family care plan. You can copy it to your clipboard for safekeeping.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Care data copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_appearance, _reminders, _session]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                Text(
                  'Preferences & Security',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Customize appearance, manage reminder notifications, and control device storage.',
                  style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.4),
                ),
                const SizedBox(height: 22),

                // Section 1: Appearance & Theme
                _buildSectionHeader('Appearance & Theme', Icons.palette_outlined),
                const SizedBox(height: 10),
                _buildAppearanceCard(),
                const SizedBox(height: 22),

                // Section 2: Notifications & Reminders
                _buildSectionHeader('Medicine Reminders', Icons.notifications_active_outlined),
                const SizedBox(height: 10),
                _buildRemindersCard(),
                const SizedBox(height: 22),

                // Section 3: Data & Privacy
                _buildSectionHeader('Data & Storage Security', Icons.lock_outline_rounded),
                const SizedBox(height: 10),
                _buildDataSecurityCard(),
                const SizedBox(height: 22),

                // Section 4: Cloud Account
                _buildSectionHeader('Cloud Sync & API', Icons.cloud_outlined),
                const SizedBox(height: 10),
                _buildCloudSyncCard(),
                const SizedBox(height: 24),

                // App info footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'CareNest Family Health · v1.2.0',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'On-device encryption enabled · Zero tracking',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Mode',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how CareNest renders across the day.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AppearanceMode>(
              segments: const [
                ButtonSegment(
                  value: AppearanceMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AppearanceMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AppearanceMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AppearanceMode.nightComfort,
                  label: Text('Night'),
                  icon: Icon(Icons.bedtime_rounded, size: 16),
                ),
              ],
              selected: {_appearance.mode},
              onSelectionChanged: (set) => _appearance.setMode(set.first),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Accent Color',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Highlight color for buttons, progress bars, and tabs.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccentPreset.values.map((preset) {
                final isSelected = _appearance.accent == preset;
                return ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: preset.color,
                    radius: 7,
                  ),
                  label: Text(preset.label),
                  selected: isSelected,
                  onSelected: (_) => _appearance.setAccent(preset),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _reminders.enabled,
            onChanged: _isTogglingReminders ? null : _toggleReminders,
            title: const Text(
              'Scheduled Reminders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              _reminders.permissionGranted == false
                  ? 'Permission blocked. Notifications cannot be delivered until allowed in Android settings.'
                  : 'Delivers local alarms at each prescribed dose time.',
              style: const TextStyle(fontSize: 12),
            ),
            secondary: Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.teal,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.vibration_rounded, color: AppTheme.teal),
            title: const Text(
              'Sound & Vibration',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: const Text(
              'Configured via Android Notification Channels (Medicine Reminders Channel: High Priority).',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReminderSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSecurityCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _session.persistenceAvailable
                      ? Icons.verified_user_rounded
                      : Icons.warning_amber_rounded,
                  color: _session.persistenceAvailable
                      ? AppTheme.teal
                      : AppTheme.statusWarning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _session.persistenceAvailable
                      ? 'Local Encrypted Storage (AES-256)'
                      : 'Temporary In-Memory Storage',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'All family profiles, medications, dose times, and historical records are encrypted and stored solely on your device. CareNest never sells health data.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _showExportDialog,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Backup / Export Care Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSyncCard() {
    final isConnected = _hasCloudToken == true;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          color: isConnected ? AppTheme.teal : AppTheme.muted,
        ),
        title: Text(
          isConnected ? 'CareNest Cloud API Connected' : 'Local Device Only',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          isConnected
              ? 'Synchronized with your configured backend family endpoint.'
              : 'Using isolated on-device demo storage. Sign in to sync remotely.',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          _checkCloudStatus();
        },
      ),
    );
  }
}
