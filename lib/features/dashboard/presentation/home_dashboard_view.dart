import 'package:flutter/material.dart';

import '../../../core/analytics/dose_analytics.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../medications/presentation/medication_detail_screen.dart';
import '../../medications/presentation/treatment_screen.dart';
import '../../members/presentation/member_health_screen.dart';
import '../../onboarding/presentation/add_family_member_screen.dart';

class HomeDashboardView extends StatefulWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const HomeDashboardView({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  String? _selectedMemberId;

  CareSession get session => CareSession.instance;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _timeRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'due now';
    if (diff.inHours > 0) {
      final mins = diff.inMinutes % 60;
      return mins > 0 ? 'in ${diff.inHours}h ${mins}m' : 'in ${diff.inHours}h';
    }
    return 'in ${diff.inMinutes}m';
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
      animation: session,
      builder: (context, _) {
        final members = session.members;
        if (_selectedMemberId != null &&
            !members.any((m) => m.id == _selectedMemberId)) {
          _selectedMemberId = null;
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final targetMembers = _selectedMemberId == null
            ? members
            : members.where((m) => m.id == _selectedMemberId).toList();

        final todayDoses = targetMembers
            .expand(
              (m) => session.occurrencesFor(
                memberId: m.id,
                from: today,
                through: today,
                now: now,
              ),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        final summary = DoseSummary.from(todayDoses);

        // Find next upcoming dose
        final nextDose = todayDoses
            .where(
              (d) =>
                  d.status == OccurrenceStatus.upcoming &&
                  d.scheduledAt.isAfter(now),
            )
            .firstOrNull;

        final overdueCount = todayDoses
            .where(
              (d) =>
                  d.status == OccurrenceStatus.overdue ||
                  d.status == OccurrenceStatus.missed,
            )
            .length;

        final caregiverName = session.ownerName.trim().isNotEmpty
            ? session.ownerName.trim()
            : 'Caregiver';

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Header
                _buildHeader(caregiverName, overdueCount),
                const SizedBox(height: 18),

                // Family Member Selector
                _buildMemberSelector(members),
                const SizedBox(height: 18),

                // Today Adherence Summary
                _buildAdherenceSummaryCard(summary, todayDoses.length),
                const SizedBox(height: 18),

                // Next Scheduled Medicine Card
                _buildNextScheduledCard(nextDose, todayDoses),
                const SizedBox(height: 22),

                // Quick Actions
                _buildQuickActions(),
                const SizedBox(height: 24),

                // Today's Medicines List
                _buildTodayScheduleSection(todayDoses),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String caregiverName, int overdueCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF187462), Color(0xFF104F45)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $caregiverName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                session.familyName.isNotEmpty
                    ? session.familyName
                    : 'Family Care Space',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton.filledTonal(
              tooltip: 'Notifications',
              onPressed: () => widget.onNavigateToTab(2),
              icon: const Icon(Icons.notifications_outlined, size: 22),
            ),
            if (overdueCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.statusError,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    overdueCount > 9 ? '9+' : '$overdueCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSelector(List<FamilyMember> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Family Members',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddFamilyMemberScreen(
                      returnToCaller: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No family members added yet. Add a member to manage their medications.',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All Members'),
                    selected: _selectedMemberId == null,
                    onSelected: (_) => setState(() => _selectedMemberId = null),
                  ),
                ),
                ...members.map((m) {
                  final isSelected = _selectedMemberId == m.id;
                  final initial = m.name.isNotEmpty ? m.name[0].toUpperCase() : '?';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppTheme.paleTeal,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.teal,
                          ),
                        ),
                      ),
                      label: Text(m.name),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedMemberId = m.id),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAdherenceSummaryCard(DoseSummary summary, int totalScheduled) {
    final adherenceRate = summary.adherencePercent;
    final adherenceText = adherenceRate != null ? '$adherenceRate%' : '—';
    final ratio = totalScheduled > 0 ? (summary.taken / totalScheduled) : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s Adherence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.taken} of $totalScheduled scheduled doses completed',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.paleTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    adherenceText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.teal),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatPill('Taken', summary.taken, AppTheme.teal),
                const SizedBox(width: 8),
                _buildStatPill('Pending', summary.upcoming, AppTheme.statusInfo),
                const SizedBox(width: 8),
                _buildStatPill('Missed', summary.missed, AppTheme.statusError),
                if (summary.overdue > 0) ...[
                  const SizedBox(width: 8),
                  _buildStatPill('Overdue', summary.overdue, AppTheme.statusWarning),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextScheduledCard(
    DoseOccurrence? nextDose,
    List<DoseOccurrence> todayDoses,
  ) {
    if (nextDose != null) {
      final medicine = nextDose.medicine;
      final doseMember = session.members
          .where((m) => m.id == nextDose.memberId)
          .firstOrNull;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF187462), Color(0xFF104F45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF187462).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_filled, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'NEXT DOSE · ${_timeRemaining(nextDose.scheduledAt).toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(nextDose.scheduledAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              medicine.medicineName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${medicine.medicineDosage} ${medicine.medicineForm.toLowerCase()} · Dose: ${medicine.doseAmount}${doseMember != null ? ' · For ${doseMember.name}' : ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
              ),
            ),
            if (medicine.foodInstruction.isNotEmpty &&
                medicine.foodInstruction != 'No food instruction') ...[
              const SizedBox(height: 4),
              Text(
                'Instruction: ${medicine.foodInstruction}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF104F45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _recordDose(nextDose, DoseStatus.taken),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Mark Dose as Taken',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final allTaken = todayDoses.isNotEmpty &&
        todayDoses.every((d) => d.status == OccurrenceStatus.taken);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.paleTeal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                allTaken
                    ? Icons.celebration_rounded
                    : Icons.event_available_rounded,
                color: AppTheme.teal,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allTaken
                        ? 'All doses completed!'
                        : 'No pending doses remaining today',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    allTaken
                        ? 'Great job keeping up with your family’s routine.'
                        : 'Check back later or review your weekly schedule.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Add Medicine',
                subtitle: 'Prescription & times',
                onTap: () {
                  final target = _selectedMemberId ?? session.members.firstOrNull?.id;
                  if (target != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TreatmentScreen(memberId: target),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddFamilyMemberScreen(
                          returnToCaller: true,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.insights_rounded,
                title: 'View Reports',
                subtitle: 'Adherence trends',
                onTap: () => widget.onNavigateToTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.group_outlined,
                title: 'Members',
                subtitle: 'Care plans',
                onTap: () {
                  final target = session.members.firstOrNull;
                  if (target != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberHealthScreen(
                          memberId: target.id,
                          memberName: target.name,
                          relationship: target.relationship,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddFamilyMemberScreen(
                          returnToCaller: true,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.paleTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.teal, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayScheduleSection(List<DoseOccurrence> doses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Today’s Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const Spacer(),
            Text(
              '${doses.length} doses total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (doses.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppTheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppTheme.muted,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No doses scheduled for today.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check medicine treatment dates or add a new schedule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...doses.map((dose) => _buildDoseItem(dose)),
      ],
    );
  }

  Widget _buildDoseItem(DoseOccurrence dose) {
    final statusColor = switch (dose.status) {
      OccurrenceStatus.taken => AppTheme.teal,
      OccurrenceStatus.missed || OccurrenceStatus.overdue => AppTheme.statusError,
      _ => AppTheme.statusInfo,
    };

    final statusText = switch (dose.status) {
      OccurrenceStatus.taken => 'Taken',
      OccurrenceStatus.missed => 'Missed',
      OccurrenceStatus.upcoming => 'Upcoming',
      OccurrenceStatus.overdue => 'Overdue',
    };

    final statusIcon = switch (dose.status) {
      OccurrenceStatus.taken => Icons.check_circle_rounded,
      OccurrenceStatus.missed ||
      OccurrenceStatus.overdue => Icons.warning_amber_rounded,
      _ => Icons.schedule_rounded,
    };

    final member = session.members
        .where((m) => m.id == dose.memberId)
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
                    medicineId: dose.medicine.id,
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
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
                              dose.medicine.medicineName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatTime(dose.scheduledAt)} · Dose: ${dose.medicine.doseAmount}${dose.medicine.foodInstruction != 'No food instruction' ? ' · ${dose.medicine.foodInstruction}' : ''}${member != null ? ' · For ${member.name}' : ''}',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<DoseStatus>(
                  tooltip: 'Record status',
                  onSelected: (status) => _recordDose(dose, status),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: DoseStatus.taken,
                      child: Text(
                        dose.status == OccurrenceStatus.taken
                            ? 'Already marked taken'
                            : 'Mark as Taken',
                      ),
                    ),
                    PopupMenuItem(
                      value: DoseStatus.missed,
                      child: Text(
                        dose.status == OccurrenceStatus.missed
                            ? 'Already marked missed'
                            : 'Mark as Missed',
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert_rounded, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
