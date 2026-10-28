import 'package:flutter/material.dart';
import '../../../core/analytics/dose_analytics.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';

class AdherenceScreen extends StatefulWidget {
  final String? memberId;
  const AdherenceScreen({super.key, this.memberId});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  int _rangeDays = 7;
  String? _memberId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CareSession.instance,
    builder: (context, _) {
      final session = CareSession.instance;
      final members = session.members;
      if (_memberId == null ||
          !members.any((member) => member.id == _memberId)) {
        _memberId =
            widget.memberId != null &&
                members.any((member) => member.id == widget.memberId)
            ? widget.memberId
            : null;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = DateTime(
        today.year,
        today.month,
        today.day - _rangeDays + 1,
      );
      final selectedMembers = _memberId == null
          ? members
          : members.where((member) => member.id == _memberId).toList();
      final occurrences =
          selectedMembers
              .expand(
                (member) => session.occurrencesFor(
                  memberId: member.id,
                  from: from,
                  through: today,
                  now: now,
                ),
              )
              .toList()
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      final periodSummary = DoseSummary.from(occurrences);
      final taken = periodSummary.taken;
      final missed = periodSummary.missed;
      final overdue = periodSummary.overdue;
      final pending = periodSummary.upcoming;
      final adherence = periodSummary.adherencePercent;
      final medicines = <String, List<DoseOccurrence>>{};
      for (final dose in occurrences) {
        medicines
            .putIfAbsent('${dose.memberId}_${dose.medicine.id}', () => [])
            .add(dose);
      }
      final trend = _trend(session, selectedMembers, from, today, now);
      final eventHistory =
          session.doseEvents
              .where(
                (event) =>
                    !event.scheduledAt.isBefore(from) &&
                    !event.scheduledAt.isAfter(
                      DateTime(now.year, now.month, now.day, 23, 59, 59),
                    ) &&
                    (_memberId == null || event.memberId == _memberId),
              )
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      return Scaffold(
        appBar: AppBar(title: const Text('Adherence analytics')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Text(
                'Medication routine',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Trends from scheduled occurrences and actions recorded in this family space.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _memberId,
                      decoration: const InputDecoration(
                        labelText: 'Family member',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All members'),
                        ),
                        ...members.map(
                          (member) => DropdownMenuItem<String?>(
                            value: member.id,
                            child: Text(member.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _memberId = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _rangeDays,
                      decoration: const InputDecoration(
                        labelText: 'Date range',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                        DropdownMenuItem(value: 90, child: Text('90 days')),
                      ],
                      onChanged: (value) =>
                          setState(() => _rangeDays = value ?? 7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _summaryCard(adherence, taken, missed, overdue, pending),
              const SizedBox(height: 16),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adherence trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Taken ÷ (taken + missed). Pending and overdue are excluded.',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 125,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: trend.map((day) {
                          final daySummary = DoseSummary.from(day);
                          final ratio = daySummary.adherencePercent == null
                              ? 0.0
                              : daySummary.adherencePercent! / 100;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    daySummary.adherencePercent == null
                                        ? '—'
                                        : '${daySummary.adherencePercent}%',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: daySummary.actioned == 0
                                        ? 6
                                        : 80 * ratio + 8,
                                    decoration: BoxDecoration(
                                      color: daySummary.actioned == 0
                                          ? const Color(0xFFE7EEEB)
                                          : AppTheme.teal.withValues(
                                              alpha: .45 + ratio * .5,
                                            ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _trendLabel(day),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'By medicine',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 9),
              if (medicines.isEmpty)
                _panel(
                  Text(
                    occurrences.isEmpty
                        ? 'No scheduled occurrences in this period. As-needed medicines are not treated as scheduled doses.'
                        : 'No medicine schedule found.',
                    style: const TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                )
              else
                ...medicines.entries.map((entry) {
                  final doses = entry.value;
                  final medicine = doses.first.medicine;
                  final member = members
                      .where((item) => item.id == doses.first.memberId)
                      .firstOrNull;
                  final metrics = DoseSummary.from(doses);
                  final t = metrics.taken;
                  final m = metrics.missed;
                  final o = metrics.overdue;
                  final p = metrics.upcoming;
                  final score = metrics.adherencePercent == null
                      ? '—'
                      : '${metrics.adherencePercent}%';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _panel(
                      Row(
                        children: [
                          const Icon(
                            Icons.medication_rounded,
                            color: AppTheme.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medicine.medicineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  '${member?.name ?? 'Family member'} · ${medicine.medicineDosage} · ${medicine.frequency}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                                Text(
                                  '$t taken · $m missed · $o overdue · $p pending',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            score,
                            style: const TextStyle(
                              color: AppTheme.teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 9),
              const Text(
                'Overdue means the scheduled time passed without an action. It is not automatically recorded as missed. Choose Taken or Missed from the daily schedule to complete that occurrence.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 9),
              if (eventHistory.isEmpty)
                _panel(
                  const Text(
                    'No dose actions recorded in this period.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                )
              else
                ...eventHistory.take(30).map((event) {
                  final member = members
                      .where((item) => item.id == event.memberId)
                      .firstOrNull;
                  final isTaken = event.status == DoseStatus.taken;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _panel(
                      Row(
                        children: [
                          Icon(
                            isTaken
                                ? Icons.check_circle_rounded
                                : Icons.event_busy_rounded,
                            color: isTaken
                                ? AppTheme.teal
                                : const Color(0xFFB45A4A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.medicineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  '${member?.name ?? 'Family member'} · scheduled ${_dateTime(event.scheduledAt)} · recorded ${_dateTime(event.recordedAt)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.35,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isTaken ? 'Taken' : 'Missed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isTaken
                                  ? AppTheme.teal
                                  : const Color(0xFFB45A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    },
  );

  List<List<DoseOccurrence>> _trend(
    CareSession session,
    List<FamilyMember> members,
    DateTime from,
    DateTime through,
    DateTime now,
  ) {
    final step = _rangeDays == 7
        ? 1
        : _rangeDays <= 30
        ? 5
        : 15;
    final result = <List<DoseOccurrence>>[];
    for (var offset = 0; offset < _rangeDays; offset += step) {
      final start = DateTime(from.year, from.month, from.day + offset);
      final end = DateTime(
        from.year,
        from.month,
        from.day + (offset + step - 1).clamp(0, _rangeDays - 1),
      );
      result.add(
        members
            .expand(
              (member) => session.occurrencesFor(
                memberId: member.id,
                from: start,
                through: end.isAfter(through) ? through : end,
                now: now,
              ),
            )
            .toList(),
      );
    }
    return result;
  }

  String _trendLabel(List<DoseOccurrence> day) {
    if (day.isEmpty) return '';
    final date = day.first.scheduledAt;
    return _rangeDays == 7
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1]
        : '${date.day}/${date.month}';
  }

  Widget _summaryCard(
    int? adherence,
    int taken,
    int missed,
    int overdue,
    int pending,
  ) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: adherence == null ? 0 : adherence / 100,
                      strokeWidth: 7,
                      backgroundColor: const Color(0xFFE7EEEB),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.teal),
                    ),
                  ),
                  Text(
                    adherence == null ? '—' : '$adherence%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adherence == null
                        ? 'No completed dose data'
                        : 'Recorded adherence',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adherence == null
                        ? 'Mark scheduled occurrences to build a real adherence score.'
                        : 'Based on $taken taken and $missed missed actions.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _countChip('Taken', taken, AppTheme.teal),
            const SizedBox(width: 6),
            _countChip('Missed', missed, const Color(0xFFB45A4A)),
            const SizedBox(width: 6),
            _countChip('Overdue', overdue, const Color(0xFF9A5A16)),
            const SizedBox(width: 6),
            _countChip('Pending', pending, AppTheme.muted),
          ],
        ),
      ],
    ),
  );

  Widget _countChip(String label, int count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ],
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
  String _dateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
