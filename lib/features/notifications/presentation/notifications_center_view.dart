import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/care_session.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../medications/presentation/medication_detail_screen.dart';
import '../../settings/presentation/reminder_settings_screen.dart';

enum NotificationFilter { all, upcoming, alerts }

class NotificationsCenterView extends StatefulWidget {
  const NotificationsCenterView({super.key});

  @override
  State<NotificationsCenterView> createState() => _NotificationsCenterViewState();
}

class _NotificationsCenterViewState extends State<NotificationsCenterView> {
  NotificationFilter _filter = NotificationFilter.all;
  bool _testingNotification = false;

  final _reminderService = ReminderService.instance;
  CareSession get session => CareSession.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_reminderService.refreshPermission());
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _relativeDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _sendTest() async {
    setState(() => _testingNotification = true);
    try {
      await _reminderService.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingNotification = false);
    }
  }

  Future<void> _recordDose(DoseOccurrence dose, DoseStatus status) async {
    final recorded = session.recordDose(
      memberId: dose.memberId,
      medicineId: dose.medicine.id,
      scheduledAt: dose.scheduledAt,
      status: status,
    );
    if (!recorded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Future doses cannot be recorded before their scheduled time.',
          ),
        ),
      );
      return;
    }
    await session.flush();
    if (!mounted) return;
    final label = status == DoseStatus.taken ? 'Taken' : 'Missed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label recorded for ${dose.medicine.medicineName}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => session.undoDoseChange(
            memberId: dose.memberId,
            medicineId: dose.medicine.id,
            scheduledAt: dose.scheduledAt,
            previousEvent: dose.event,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([session, _reminderService]),
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final members = session.members;

        // Upcoming scheduled reminders from ReminderService
        final upcomingPlans = _reminderService.upcomingPlans;

        // Today's occurrences for alert tracking
        final todayOccurrences = members
            .expand(
              (m) => session.occurrencesFor(
                memberId: m.id,
                from: today,
                through: today,
                now: now,
              ),
            )
            .toList();

        final alerts = todayOccurrences.where(
          (o) =>
              o.status == OccurrenceStatus.missed ||
              o.status == OccurrenceStatus.overdue,
        ).toList();

        final isPermissionBlocked = _reminderService.permissionGranted == false;
        final isRemindersDisabled = !_reminderService.enabled;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications & Reminders'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'Reminder Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReminderSettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                // Service status banner
                if (isPermissionBlocked || isRemindersDisabled)
                  _buildServiceWarningBanner(
                    isPermissionBlocked: isPermissionBlocked,
                    isRemindersDisabled: isRemindersDisabled,
                  ),

                // Header info
                Text(
                  'Notification Center',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review scheduled dose alarms, missed-dose alerts, and reminder delivery status.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick tools row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testingNotification ? null : _sendTest,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'Test Notification',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReminderSettingsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text(
                          'Preferences',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Filter tabs
                SegmentedButton<NotificationFilter>(
                  segments: const [
                    ButtonSegment(
                      value: NotificationFilter.all,
                      label: Text('All'),
                      icon: Icon(Icons.all_inbox_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: NotificationFilter.upcoming,
                      label: Text('Upcoming'),
                      icon: Icon(Icons.alarm_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: NotificationFilter.alerts,
                      label: Text('Alerts'),
                      icon: Icon(Icons.warning_amber_rounded, size: 16),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) => setState(() => _filter = set.first),
                ),
                const SizedBox(height: 18),

                // Content list
                if (_filter == NotificationFilter.all ||
                    _filter == NotificationFilter.alerts) ...[
                  if (alerts.isNotEmpty) ...[
                    _buildSectionHeader('Attention Needed', alerts.length),
                    const SizedBox(height: 8),
                    ...alerts.map((alert) => _buildAlertItem(alert)),
                    const SizedBox(height: 16),
                  ],
                ],

                if (_filter == NotificationFilter.all ||
                    _filter == NotificationFilter.upcoming) ...[
                  _buildSectionHeader('Scheduled Reminders', upcomingPlans.length),
                  const SizedBox(height: 8),
                  if (upcomingPlans.isEmpty)
                    _buildEmptyUpcomingCard()
                  else
                    ...upcomingPlans.take(30).map(
                          (entry) => _buildReminderItem(entry),
                        ),
                ],

                if (_filter == NotificationFilter.alerts && alerts.isEmpty)
                  _buildEmptyAlertsCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceWarningBanner({
    required bool isPermissionBlocked,
    required bool isRemindersDisabled,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.statusWarning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_rounded, color: AppTheme.statusWarning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPermissionBlocked
                      ? 'Notifications Blocked in Android'
                      : 'Reminders are Paused',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPermissionBlocked
                      ? 'System notification permission is denied. Enable it to hear dose alerts.'
                      : 'Turn on medicine reminders in settings to receive scheduled alarms.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReminderSettingsScreen(),
              ),
            ),
            child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const Spacer(),
        Text(
          '$count items',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertItem(DoseOccurrence alert) {
    final member = session.members
        .where((m) => m.id == alert.memberId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.statusError.withValues(alpha: 0.4)),
        ),
        color: AppTheme.statusError.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.statusError.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.statusError,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.status == OccurrenceStatus.missed ? 'Missed Dose' : 'Overdue'}: ${alert.medicine.medicineName}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTime(alert.scheduledAt)} · ${alert.medicine.doseAmount}${member != null ? ' · For ${member.name}' : ''}',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => _recordDose(alert, DoseStatus.taken),
                child: const Text('Take', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderItem(ReminderEntry entry) {
    final plan = entry.plan;
    final scheduledAt = entry.at;
    final member = session.members
        .where((m) => m.id == plan.memberId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (member != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicationDetailScreen(
                    memberId: member.id,
                    medicineId: plan.medicineId,
                    memberName: member.name,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.paleTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.paleTeal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _relativeDay(scheduledAt),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatTime(scheduledAt)} · ${plan.amount}${plan.dosage.isNotEmpty ? ' · ${plan.dosage}' : ''}${member != null ? ' · For ${member.name}' : ''}',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUpcomingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.alarm_off_rounded, color: AppTheme.muted, size: 30),
              const SizedBox(height: 10),
              Text(
                'No upcoming reminders scheduled.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reminders are scheduled automatically when medicines are added to a treatment plan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAlertsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.done_all_rounded, color: AppTheme.teal, size: 30),
              const SizedBox(height: 10),
              Text(
                'No missed doses or overdue alerts!',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All scheduled doses for today are up to date.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
