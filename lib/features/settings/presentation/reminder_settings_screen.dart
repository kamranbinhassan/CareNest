import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/notifications/reminder_service.dart';
import '../../../core/theme/app_theme.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _reminders = ReminderService.instance;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reminders.refreshPermission());
  }

  Future<void> _toggle(bool value) async {
    setState(() => _working = true);
    try {
      if (value) {
        final enabled = await _reminders.enable();
        if (!enabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are disabled. Allow them in Android settings to receive reminders.',
              ),
            ),
          );
        }
      } else {
        await _reminders.disable();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update reminder settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _test() async {
    setState(() => _working = true);
    try {
      await _reminders.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _reminders,
    builder: (context, _) {
      final upcoming = _reminders.upcomingTimes;
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine reminders')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: SwitchListTile.adaptive(
                value: _reminders.enabled,
                onChanged: _working ? null : _toggle,
                title: const Text(
                  'Medicine reminders',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _reminders.permissionGranted == false
                      ? 'Notifications are blocked by Android. Allow them in system settings.'
                      : 'Reminders use the dose times saved in each treatment plan.',
                ),
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.teal,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification status',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _reminders.permissionGranted == true
                          ? 'Allowed by Android'
                          : _reminders.permissionGranted == false
                          ? 'Permission denied. Change this in Android app notification settings.'
                          : 'Permission status is not available on this platform.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _test,
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('Send test notification'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Android battery restrictions and inexact alarms can delay delivery.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Upcoming dose times',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_reminders.error != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_reminders.error!),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_reminders.scheduleLimitReached) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'This device reached its 450 reminder limit. Only the nearest upcoming doses are scheduled.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!_reminders.enabled)
              const _EmptyMessage(
                'Turn on reminders to schedule doses from your treatment plans.',
              )
            else if (upcoming.isEmpty)
              const _EmptyMessage(
                'No scheduled doses are coming up. Add dose times to an active treatment plan.',
              )
            else
              ..._reminders.upcomingPlans.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(Icons.schedule_rounded, color: AppTheme.teal),
                    title: Text(item.plan.name),
                    subtitle: Text(
                      '${item.plan.amount}${item.plan.dosage.isEmpty ? '' : ' · ${item.plan.dosage}'}',
                    ),
                    trailing: Text(_formatTime(item.at)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Only upcoming schedules are shown here. The app does not keep a history of delivered Android notifications.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );

  String _formatTime(DateTime value) =>
      '${value.day}/${value.month} · ${TimeOfDay.fromDateTime(value).format(context)}';
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
