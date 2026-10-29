import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/data/care_session.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/theme/app_theme.dart';

class CareSupportScreen extends StatefulWidget {
  const CareSupportScreen({super.key});

  @override
  State<CareSupportScreen> createState() => _CareSupportScreenState();
}

class _CareSupportScreenState extends State<CareSupportScreen> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  String _generateDiagnostics() {
    final session = CareSession.instance;
    final totalMembers = session.members.length;
    final totalMeds = session.medicineCount;
    final totalEvents = session.doseEvents.length;
    final storageStatus = session.persistenceAvailable
        ? 'Healthy (Persistent)'
        : 'Memory / Error';
    final hasPerm = ReminderService.instance.permissionGranted == true;

    return '''=== CareNest Diagnostic Summary ===
App Version: 2.1.0 (Build 42)
Platform: Android / Cross-Platform
Persistence: $storageStatus
Family Space: ${session.familyName.isEmpty ? '(Not set)' : session.familyName}
Family Members: $totalMembers
Registered Medicines: $totalMeds
Recorded Dose Events: $totalEvents
Notifications Enabled: ${hasPerm ? 'Granted' : 'Disabled / Needs Permission'}
Timestamp: ${DateTime.now().toUtc().toIso8601String()}
===================================''';
  }

  void _copyDiagnostics(BuildContext context) {
    final report = _generateDiagnostics();
    Clipboard.setData(ClipboardData(text: report));
    _copyTimer?.cancel();
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostic summary copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
    _copyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.9);

    return Scaffold(
      appBar: AppBar(title: const Text('Care & Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.teal.withValues(alpha: 0.15),
                    AppTheme.accentFill.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.teal.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppTheme.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Guidance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Troubleshooting, device diagnostics, and health adherence safety guidelines.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Diagnostic Section
            Text(
              'DEVICE & APP DIAGNOSTICS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Column(
                children: [
                  _DiagnosticRow(
                    icon: Icons.shield_outlined,
                    label: 'Storage Health',
                    value: CareSession.instance.persistenceAvailable
                        ? 'Secure Storage Online'
                        : 'Active (Local Memory)',
                    color: Colors.green,
                  ),
                  const Divider(height: 1, indent: 56),
                  _DiagnosticRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Alarm & Notification Engine',
                    value: ReminderService.instance.permissionGranted == true
                        ? 'Active & Permitted'
                        : 'Permission Pending',
                    color: ReminderService.instance.permissionGranted == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const Divider(height: 1, indent: 56),
                  _DiagnosticRow(
                    icon: Icons.group_outlined,
                    label: 'Care Space Stats',
                    value:
                        '${CareSession.instance.members.length} members · ${CareSession.instance.medicineCount} medicines',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _copyDiagnostics(context),
                        icon: Icon(
                          _copied
                              ? Icons.check_circle_rounded
                              : Icons.copy_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _copied
                              ? 'Diagnostic Summary Copied'
                              : 'Copy Diagnostic Report',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Frequently Asked Questions / Guides
            Text(
              'HELP GUIDES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),

            _GuideAccordion(
              icon: Icons.notifications_paused_outlined,
              title: 'Not receiving dose notifications?',
              content:
                  'On Android, power-saving and battery optimization can delay scheduled alarms. Go to your phone Settings > Apps > CareNest > Battery and select "Unrestricted". Also make sure Exact Alarms are granted.',
            ),
            _GuideAccordion(
              icon: Icons.schedule_rounded,
              title: 'Multi-dose scheduling (2x, 3x, 4x daily)',
              content:
                  'When selecting Twice daily, Three times daily, or Four times daily, CareNest automatically creates distinct times spaced evenly throughout your day. You can customize each specific dose time by tapping on it during creation.',
            ),
            _GuideAccordion(
              icon: Icons.inventory_2_outlined,
              title: 'Stock tracking & refill alerts',
              content:
                  'When adding or editing a medicine, you can provide the current stock count and refill threshold. Each time you mark a dose as "Taken", the remaining stock decreases automatically. You will see an alert when it drops below the threshold.',
            ),
            _GuideAccordion(
              icon: Icons.wifi_off_rounded,
              title: 'Offline mode and data synchronization',
              content:
                  'CareNest operates fully offline with secure local storage. If you choose to configure a self-hosted or cloud CareNest server, your logs sync safely whenever an internet connection is available.',
            ),
            _GuideAccordion(
              icon: Icons.calculate_outlined,
              title: 'How is adherence calculated?',
              content:
                  'CareNest calculates adherence using the clinical formula: Taken ÷ (Taken + Missed) × 100%. Pending and future doses are not counted as failures, ensuring a fair and motivating progress score.',
            ),

            const SizedBox(height: 24),

            // Disclaimers
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Important Medical Disclaimer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CareNest is an independent personal adherence tool designed to assist caregivers and patients with reminder management. It does not provide medical diagnoses, treatment decisions, or clinical advice. In an emergency, always contact local emergency services immediately.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _DiagnosticRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideAccordion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _GuideAccordion({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.outline),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.outline),
          ),
          leading: Icon(icon, color: AppTheme.teal),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
