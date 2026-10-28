import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/presentation/adherence_screen.dart';
import '../../members/presentation/member_health_screen.dart';
import '../../medications/domain/models/medication_schedule.dart';
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
      final schedule = <_ScheduledDose>[];
      if (selected != null) {
        for (final medicine in session.medicinesFor(selected.id)) {
          final start = DateTime(
            medicine.startDate.year,
            medicine.startDate.month,
            medicine.startDate.day,
          );
          final end = medicine.endDate == null
              ? null
              : DateTime(
                  medicine.endDate!.year,
                  medicine.endDate!.month,
                  medicine.endDate!.day,
                );
          final today = DateTime(now.year, now.month, now.day);
          if (today.isBefore(start) ||
              (end != null && today.isAfter(end)) ||
              !_occursToday(medicine, start, today)) {
            continue;
          }
          for (final time in medicine.doseTimes) {
            schedule.add(
              _ScheduledDose(
                medicine,
                DateTime(now.year, now.month, now.day, time.hour, time.minute),
              ),
            );
          }
        }
        schedule.sort((a, b) => a.at.compareTo(b.at));
      }
      final recordedToday = session.doseEvents
          .where(
            (e) =>
                e.memberId == selected?.id &&
                e.scheduledAt.year == now.year &&
                e.scheduledAt.month == now.month &&
                e.scheduledAt.day == now.day,
          )
          .toList();
      final taken = recordedToday
          .where((e) => e.status == DoseStatus.taken)
          .length;
      final pct = recordedToday.isEmpty
          ? null
          : (taken * 100 / recordedToday.length).round();
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
              if (!session.persistenceAvailable)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Device storage is unavailable. Changes are held only until this app closes.',
                    style: TextStyle(color: Color(0xFF9A5A16), fontSize: 12),
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
                      child: _doseCard(selected, dose, now),
                    ),
                  )
                else
                  _emptySchedule(selected),
                const SizedBox(height: 17),
                _heading('Treatment summary', null),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        Icons.medication_outlined,
                        '${session.medicineCount}',
                        'Active medicines',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metric(
                        Icons.check_circle_outline,
                        pct == null ? '—' : '$pct%',
                        pct == null ? 'No doses recorded' : 'Today’s adherence',
                      ),
                    ),
                  ],
                ),
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

  Widget _memberCard(FamilyMember member, bool selected) => Material(
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
                    '${member.relationship} · ${session.medicinesFor(member.id).length} medicines',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
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

  Widget _doseCard(FamilyMember member, _ScheduledDose dose, DateTime now) {
    final event = session.doseEventFor(
      member.id,
      dose.medicine.medicineName,
      dose.at,
    );
    final past = dose.at.isBefore(now);
    final statusText = event != null
        ? (event.status == DoseStatus.taken ? 'Taken' : 'Marked missed')
        : past
        ? 'Past due · unrecorded'
        : 'Upcoming';
    final color = event?.status == DoseStatus.taken
        ? AppTheme.teal
        : event?.status == DoseStatus.missed || (past && event == null)
        ? const Color(0xFFB45A4A)
        : AppTheme.muted;
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
                  '${_time(dose.at)} · ${dose.medicine.doseAmount}',
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
          if (event == null)
            PopupMenuButton<DoseStatus>(
              tooltip: 'Record dose',
              onSelected: (status) async {
                session.recordDose(
                  memberId: member.id,
                  medicine: dose.medicine,
                  scheduledAt: dose.at,
                  status: status,
                );
                await session.flush();
                if (mounted && !session.persistenceAvailable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Dose recorded for this session, but not saved to device storage.',
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: DoseStatus.taken,
                  child: Text('Mark taken'),
                ),
                PopupMenuItem(
                  value: DoseStatus.missed,
                  child: Text('Mark missed'),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            )
          else
            Icon(
              event.status == DoseStatus.taken
                  ? Icons.check_circle_rounded
                  : Icons.event_busy_rounded,
              color: color,
            ),
        ],
      ),
    );
  }

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
  Widget _metric(IconData icon, String value, String label) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.teal),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
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
  bool _occursToday(
    MedicationSchedule medicine,
    DateTime start,
    DateTime today,
  ) {
    switch (medicine.frequency) {
      case 'Every other day':
        return today.difference(start).inDays % 2 == 0;
      case 'Weekly':
        return today.weekday == start.weekday;
      case 'As needed':
        return false;
      default:
        return true;
    }
  }

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

class _ScheduledDose {
  final MedicationSchedule medicine;
  final DateTime at;
  const _ScheduledDose(this.medicine, this.at);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
