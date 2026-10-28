import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'appearance_screen.dart';
import 'reminder_settings_screen.dart';
import '../../onboarding/presentation/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Personalize CareNest',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Choose a comfortable look for your family care workspace.',
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.paleTeal,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.teal,
                ),
              ),
              title: const Text(
                'Medicine reminders',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Upcoming doses and notification access'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReminderSettingsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.paleTeal,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.palette_outlined, color: AppTheme.teal),
              ),
              title: const Text(
                'Appearance',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Theme mode and accent color'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.paleTeal,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.cloud_outlined, color: AppTheme.teal),
              ),
              title: const Text(
                'Connect backend account',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Sign in or register to use the configured API. Local demo data is not uploaded.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Data storage'),
              subtitle: Text(
                'Local demo records stay on this device. Backend records are separately stored by your configured API.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
