import 'package:flutter/material.dart';
import '../../../core/analytics/dose_analytics.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/presentation/adherence_screen.dart';
import '../../members/presentation/member_health_screen.dart';
import '../../medications/presentation/treatment_screen.dart';
import '../../onboarding/presentation/add_family_member_screen.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});
  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  String? _selectedMemberId;
  CareSession get session => CareSession.instance;

  Future<void> _addMember() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddFamilyMemberScreen(returnToCaller: true),
      ),
    );
  }

  Future<void> _openTreatment(FamilyMember member) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TreatmentScreen(memberId: member.id)),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final members = session.members;
      if (members.isNotEmpty &&
          !members.any((m) => m.id == _selectedMemberId)) {
        _selectedMemberId = members.first.id;
      }
      final selected = members
          .where((m) => m.id == _selectedMemberId)
          .firstOrNull;
      final now = DateTime.now();
      final greeting = now.hour < 12
          ? 'Good morning'
          : now.hour < 17
          ? 'Good afternoon'
          : 'Good evening';
      final today = DateTime(now.year, now.month, now.day);
      final schedule = selected == null
          ? <DoseOccurrence>[]
          : session.occurrencesFor(
              memberId: selected.id,
              from: today,
              through: today,
              now: now,
            );
      final dailySummary = DoseSummary.from(schedule);
      final weekStart = DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      );
      final weekOccurrences = selected == null
          ? <DoseOccurrence>[]
          : List.generate(
              7,
              (index) => session.occurrencesFor(
                memberId: selected.id,
                from: DateTime(
                  weekStart.year,
                  weekStart.month,
                  weekStart.day + index,
                ),
                through: DateTime(
                  weekStart.year,
                  weekStart.month,
                  weekStart.day + index,
                ),
                now: now,
              ),
            ).expand((items) => items).toList();
      final weekly = DoseAnalytics.byDay(
        occurrences: weekOccurrences,
        firstDay: weekStart,
        dayCount: 7,
      );
      final allToday = members
          .expand(
            (member) => session.occurrencesFor(
              memberId: member.id,
              from: today,
              through: today,
              now: now,
            ),
          )
          .toList();
      final allWeek = members
          .expand(
            (member) => session.occurrencesFor(
              memberId: member.id,
              from: weekStart,
              through: today,
              now: now,
            ),
          )
          .toList();
      final nextDose = schedule
          .where((dose) => dose.status == OccurrenceStatus.upcoming)
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: AppTheme.teal),
              SizedBox(width: 9),
              Text('CareNest'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Adherence history',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdherenceScreen()),
              ),
              icon: const Icon(Icons.insights_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Text(
                '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}'
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '$greeting, ${session.ownerName.isEmpty ? 'there' : session.ownerName}',
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                session.familyName.isEmpty
                    ? 'Your family health space'
                    : session.familyName,
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 20),
              _hero(members.isNotEmpty),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 14),
                _completionCard(selected, dailySummary),
                const SizedBox(height: 12),
                _nextDoseCard(nextDose, selected),
                const SizedBox(height: 18),
                _statusGrid(dailySummary),
                const SizedBox(height: 18),
                _insightsPanel(members, allToday, allWeek, now),
              ],
              if (!session.persistenceAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    session.storageError ??
                        'Device storage is unavailable. Changes are held only until this app closes.',
                    style: const TextStyle(
                      color: Color(0xFF9A5A16),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              _heading(
                'Family members',
                members.isEmpty ? 'GET STARTED' : '${members.length} total',
              ),
              const SizedBox(height: 11),
              if (members.isEmpty)
                _emptyFamily()
              else
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _memberCard(member, selected?.id == member.id),
                  ),
                ),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 16),
                _heading('Today’s medication schedule', selected?.name ?? ''),
                const SizedBox(height: 11),
                if (selected != null && schedule.isNotEmpty)
                  ...schedule.map(
                    (dose) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _doseCard(dose),
                    ),
                  )
                else
                  _emptySchedule(selected),
                const SizedBox(height: 17),
                _heading(
                  'Weekly adherence · ${selected?.name ?? 'member'}',
                  null,
                ),
                const SizedBox(height: 10),
                _weeklyChart(weekly),
              ],
              const SizedBox(height: 21),
              _heading('Quick actions', null),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _action(
                      Icons.person_add_alt_1_rounded,
                      'Add member',
                      _addMember,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _action(
                      Icons.add_moderator_rounded,
                      'Add medicine',
                      selected == null
                          ? _addMember
                          : () => _openTreatment(selected),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _action(
                Icons.assignment_outlined,
                'View treatment plans',
                selected == null ? _addMember : () => _openTreatment(selected),
                wide: true,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  session.persistenceAvailable
                      ? 'Your family care plans are saved on this device.'
                      : 'Local demo · storage unavailable',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _hero(bool hasMembers) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF187462), Color(0xFF104F45)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasMembers
                    ? 'Your family, cared for.'
                    : 'Build your family care space',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                hasMembers
                    ? 'Keep schedules and daily check-ins together.'
                    : 'Add members and organize their medicine schedules.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
      ],
    ),
  );

  Widget _emptyFamily() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.groups_2_outlined, color: AppTheme.teal, size: 29),
        const SizedBox(height: 10),
        const Text(
          'No family members yet',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Add someone to create their personal treatment plan.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _addMember,
          icon: const Icon(Icons.add),
          label: const Text('Add family member'),
        ),
      ],
    ),
  );

  Widget _memberCard(FamilyMember member, bool selected) {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final doses = session.occurrencesFor(
      memberId: member.id,
      from: day,
      through: day,
      now: today,
    );
    final done = doses
        .where((dose) => dose.status == OccurrenceStatus.taken)
        .length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => setState(() => _selectedMemberId = member.id),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.teal : const Color(0xFFE6ECE9),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.paleTeal,
                foregroundColor: AppTheme.teal,
                child: Text(
                  member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    Text(
                      '${session.medicinesFor(member.id).length} medicines · ${doses.length} today · $done taken',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open ${member.name} profile',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberHealthScreen(
                      memberId: member.id,
                      memberName: member.name,
                      relationship: member.relationship,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doseCard(DoseOccurrence dose) {
    final statusText = switch (dose.status) {
      OccurrenceStatus.taken => 'Taken',
      OccurrenceStatus.missed => 'Missed',
      OccurrenceStatus.upcoming => 'Upcoming',
      OccurrenceStatus.overdue => 'Overdue · unrecorded',
    };
    final color = switch (dose.status) {
      OccurrenceStatus.taken => AppTheme.teal,
      OccurrenceStatus.missed ||
      OccurrenceStatus.overdue => const Color(0xFFB45A4A),
      _ => AppTheme.muted,
    };
    return _panel(
      Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppTheme.paleTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medication_rounded, color: AppTheme.teal),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicine.medicineName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                Text(
                  '${_time(dose.scheduledAt)} · ${dose.medicine.doseAmount} ${dose.medicine.foodInstruction == 'No food instruction' ? '' : '· ${dose.medicine.foodInstruction}'}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<DoseStatus>(
            tooltip: dose.event == null
                ? 'Record dose'
                : 'Correct recorded dose',
            onSelected: (status) async {
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
                      'A future dose cannot be recorded before its scheduled time.',
                    ),
                  ),
                );
                return;
              }
              await session.flush();
              if (mounted && session.persistenceAvailable) {
                final actionLabel = status == DoseStatus.taken
                    ? 'Taken'
                    : 'Missed';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$actionLabel recorded for ${dose.medicine.medicineName}.',
                    ),
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
              if (mounted && !session.persistenceAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      session.storageError ?? 'Dose could not be saved.',
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: DoseStatus.taken,
                child: Text(
                  dose.status == OccurrenceStatus.taken
                      ? 'Correct to taken'
                      : 'Mark taken',
                ),
              ),
              PopupMenuItem(
                value: DoseStatus.missed,
                child: Text(
                  dose.status == OccurrenceStatus.missed
                      ? 'Correct to missed'
                      : 'Mark missed',
                ),
              ),
            ],
            icon: Icon(
              dose.event == null
                  ? Icons.more_vert_rounded
                  : Icons.edit_note_rounded,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionCard(FamilyMember? member, DoseSummary summary) {
    final ratio = summary.completionPercent;
    return _panel(
      Row(
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: ratio == null ? 0 : ratio / 100,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFE7EEEB),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.teal),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ratio == null ? '—' : '$ratio%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppTheme.ink,
                      ),
                    ),
                    const Text(
                      'today',
                      style: TextStyle(fontSize: 9, color: AppTheme.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member == null
                      ? 'Daily care completion'
                      : '${member.name}’s daily care',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.scheduled == 0
                      ? 'No doses are scheduled for today.'
                      : '${summary.taken} of ${summary.scheduled} scheduled doses taken.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 7),
                Text(
                  summary.scheduled == 0
                      ? 'Add a treatment plan to begin tracking.'
                      : '${summary.remaining} still need an action · ${summary.missed} marked missed',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusGrid(DoseSummary summary) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _statusTile(
              'Taken',
              summary.taken,
              Icons.check_circle_rounded,
              AppTheme.teal,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _statusTile(
              'Upcoming',
              summary.upcoming,
              Icons.schedule_rounded,
              const Color(0xFF477C9C),
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Expanded(
            child: _statusTile(
              'Overdue',
              summary.overdue,
              Icons.warning_amber_rounded,
              const Color(0xFF9A5A16),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _statusTile(
              'Missed',
              summary.missed,
              Icons.event_busy_rounded,
              const Color(0xFFB45A4A),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _statusTile(String label, int count, IconData icon, Color color) =>
      _panel(
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _nextDoseCard(DoseOccurrence? dose, FamilyMember? member) {
    if (dose == null) {
      return _panel(
        Row(
          children: [
            const Icon(Icons.event_available_rounded, color: AppTheme.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                member == null
                    ? 'Select a family member to see the next dose.'
                    : 'No upcoming dose today for ${member.name}.',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F0),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFD8EAE3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppTheme.teal,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT DOSE',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.teal,
                  ),
                ),
                Text(
                  dose.medicine.medicineName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                Text(
                  '${member?.name ?? 'Family member'} · ${dose.medicine.doseAmount} · ${dose.medicine.foodInstruction}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Text(
            _time(dose.scheduledAt),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppTheme.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightsPanel(
    List<FamilyMember> members,
    List<DoseOccurrence> today,
    List<DoseOccurrence> week,
    DateTime now,
  ) {
    final insights = <(IconData, Color, String, String)>[];
    final overdue = today
        .where((dose) => dose.status == OccurrenceStatus.overdue)
        .toList();
    if (overdue.isNotEmpty) {
      final first = overdue.first;
      final member = members
          .where((item) => item.id == first.memberId)
          .firstOrNull;
      insights.add((
        Icons.warning_amber_rounded,
        const Color(0xFF9A5A16),
        '${overdue.length} overdue ${overdue.length == 1 ? 'dose' : 'doses'}',
        'No action is recorded for ${first.medicine.medicineName} · ${member?.name ?? 'member'} at ${_time(first.scheduledAt)}.',
      ));
    }
    final upcoming = today
        .where((dose) => dose.status == OccurrenceStatus.upcoming)
        .toList();
    if (upcoming.isNotEmpty) {
      final next = upcoming.first;
      final member = members
          .where((item) => item.id == next.memberId)
          .firstOrNull;
      insights.add((
        Icons.schedule_rounded,
        AppTheme.teal,
        'Next up at ${_time(next.scheduledAt)}',
        '${next.medicine.medicineName} is scheduled for ${member?.name ?? 'a family member'}.',
      ));
    }
    final missedWeek = week
        .where((dose) => dose.status == OccurrenceStatus.missed)
        .length;
    if (missedWeek > 0) {
      insights.add((
        Icons.event_busy_rounded,
        const Color(0xFFB45A4A),
        '$missedWeek missed ${missedWeek == 1 ? 'dose' : 'doses'} this week',
        'This count comes from doses explicitly marked Missed in the current schedules.',
      ));
    }
    final daily = DoseAnalytics.byDay(
      occurrences: week,
      firstDay: DateTime(now.year, now.month, now.day - now.weekday + 1),
      dayCount: 7,
    );
    final recordedDays = daily
        .where((day) => day.summary.actioned > 0)
        .toList();
    if (recordedDays.length >= 2) {
      final previous =
          recordedDays[recordedDays.length - 2].summary.adherencePercent!;
      final latest = recordedDays.last.summary.adherencePercent!;
      if (latest != previous) {
        final direction = latest > previous ? 'up' : 'down';
        insights.add((
          Icons.trending_up_rounded,
          AppTheme.teal,
          'Adherence is $direction',
          'Recorded-dose adherence changed from $previous% to $latest% across the latest two days with completed records.',
        ));
      }
    }
    if (insights.isEmpty) {
      insights.add((
        Icons.check_circle_outline_rounded,
        AppTheme.teal,
        'No doses need attention right now',
        'This insight checks overdue and upcoming occurrences generated from saved treatment schedules.',
      ));
    }
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local care insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Transparent checks from saved schedules and dose records.',
            style: TextStyle(fontSize: 10, color: AppTheme.muted),
          ),
          const SizedBox(height: 11),
          ...insights
              .take(3)
              .map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(insight.$1, size: 18, color: insight.$2),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.$3,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: insight.$2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              insight.$4,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.35,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _weeklyChart(List<DailyDoseSummary> days) => _panel(
    Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final ratio = day.summary.adherencePercent == null
            ? 0.0
            : day.summary.adherencePercent! / 100;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  day.summary.adherencePercent == null
                      ? '—'
                      : '${day.summary.adherencePercent}%',
                  style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                ),
                const SizedBox(height: 5),
                Container(
                  height: day.summary.actioned == 0 ? 6 : 70 * ratio + 8,
                  decoration: BoxDecoration(
                    color: day.summary.actioned == 0
                        ? const Color(0xFFE7EEEB)
                        : AppTheme.teal.withValues(alpha: .45 + ratio * .5),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weekday(day.day.weekday),
                  style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _emptySchedule(FamilyMember? selected) => _panel(
    Text(
      selected == null
          ? 'Select a member to view their schedule.'
          : session.medicinesFor(selected.id).isEmpty
          ? 'No medicines saved for ${selected.name} yet.'
          : 'No doses scheduled for today. Check the treatment dates or schedule.',
      style: const TextStyle(color: AppTheme.muted, height: 1.45),
    ),
  );
  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool wide = false,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: wide ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6ECE9)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.teal, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFE6ECE9)),
    ),
    child: child,
  );
  Widget _heading(String title, String? detail) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.ink,
        ),
      ),
      const Spacer(),
      if (detail != null)
        Flexible(
          child: Text(
            detail,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
        ),
    ],
  );
  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _weekday(int n) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][n - 1];
  static String _month(int n) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][n - 1];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
