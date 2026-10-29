import 'package:flutter/material.dart';

import '../../../core/analytics/dose_analytics.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';

class AdherenceAnalysisView extends StatefulWidget {
  final String? initialMemberId;

  const AdherenceAnalysisView({super.key, this.initialMemberId});

  @override
  State<AdherenceAnalysisView> createState() => _AdherenceAnalysisViewState();
}

class _AdherenceAnalysisViewState extends State<AdherenceAnalysisView> {
  int _rangeDays = 7;
  String? _memberId;

  @override
  void initState() {
    super.initState();
    _memberId = widget.initialMemberId;
  }

  CareSession get session => CareSession.instance;

  String _formatShortDate(DateTime dt) => '${dt.day}/${dt.month}';

  String _weekday(int n) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][n - 1];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final members = session.members;
        if (_memberId != null && !members.any((m) => m.id == _memberId)) {
          _memberId = null;
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final from = DateTime(
          today.year,
          today.month,
          today.day - _rangeDays + 1,
        );

        final targetMembers = _memberId == null
            ? members
            : members.where((m) => m.id == _memberId).toList();

        final occurrences =
            targetMembers
                .expand(
                  (m) => session.occurrencesFor(
                    memberId: m.id,
                    from: from,
                    through: today,
                    now: now,
                  ),
                )
                .toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

        final periodSummary = DoseSummary.from(occurrences);

        // Group by medicine
        final medicineOccurrences = <String, List<DoseOccurrence>>{};
        for (final dose in occurrences) {
          final key = '${dose.memberId}_${dose.medicine.id}';
          medicineOccurrences.putIfAbsent(key, () => []).add(dose);
        }

        // Daily trend data
        final trendDays = List.generate(_rangeDays > 14 ? 14 : _rangeDays, (i) {
          final day = DateTime(
            today.year,
            today.month,
            today.day - (_rangeDays > 14 ? 13 : _rangeDays - 1) + i,
          );
          return targetMembers
              .expand(
                (m) => session.occurrencesFor(
                  memberId: m.id,
                  from: day,
                  through: day,
                  now: now,
                ),
              )
              .toList();
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('Adherence Analysis'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 84),
              children: [
                Text(
                  'Adherence Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review consistency and completed doses based on actual recorded events.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Filter controls: Member & Date Range
                _buildFilterControls(members),
                const SizedBox(height: 18),

                // High-level adherence score card
                _buildScoreCard(periodSummary, occurrences.length),
                const SizedBox(height: 18),

                // Adherence trend chart
                _buildTrendChart(trendDays),
                const SizedBox(height: 22),

                // Medicine breakdown
                _buildMedicineBreakdown(medicineOccurrences),
                const SizedBox(height: 22),

                // Medication history timeline
                _buildHistoryTimeline(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterControls(List<FamilyMember> members) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _memberId,
                decoration: const InputDecoration(
                  labelText: 'Family member',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All members'),
                  ),
                  ...members.map(
                    (m) => DropdownMenuItem<String?>(
                      value: m.id,
                      child: Text(m.name),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _memberId = val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _rangeDays,
                decoration: const InputDecoration(
                  labelText: 'Timeframe',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Today')),
                  DropdownMenuItem(value: 7, child: Text('7 Days (Week)')),
                  DropdownMenuItem(value: 30, child: Text('30 Days (Month)')),
                  DropdownMenuItem(value: 90, child: Text('90 Days (Quarter)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _rangeDays = val);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreCard(DoseSummary summary, int totalOccurrences) {
    final rate = summary.adherencePercent;
    final rateText = rate != null ? '$rate%' : '—';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adherence Rate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calculation: Taken ÷ (Taken + Missed)',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.paleTeal,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    rateText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildStatBox('Scheduled', totalOccurrences, AppTheme.ink),
                const SizedBox(width: 8),
                _buildStatBox('Taken', summary.taken, AppTheme.teal),
                const SizedBox(width: 8),
                _buildStatBox('Missed', summary.missed, AppTheme.statusError),
                const SizedBox(width: 8),
                _buildStatBox('Pending', summary.upcoming, AppTheme.statusInfo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(List<List<DoseOccurrence>> trendDays) {
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
            Text(
              'Daily Consistency Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Bar heights indicate completed ratio per day in this period.',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trendDays.map((dayDoses) {
                  final daySummary = DoseSummary.from(dayDoses);
                  final ratio = daySummary.adherencePercent == null
                      ? 0.0
                      : daySummary.adherencePercent! / 100.0;
                  final dayDate = dayDoses.isNotEmpty
                      ? dayDoses.first.scheduledAt
                      : DateTime.now();

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            daySummary.adherencePercent == null
                                ? '·'
                                : '${daySummary.adherencePercent}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: daySummary.adherencePercent == null
                                  ? AppTheme.muted
                                  : AppTheme.teal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: dayDoses.isEmpty
                                ? 4
                                : (ratio * 65.0).clamp(6.0, 65.0),
                            decoration: BoxDecoration(
                              color: dayDoses.isEmpty
                                  ? AppTheme.outline
                                  : ratio >= 0.8
                                  ? AppTheme.teal
                                  : ratio > 0.4
                                  ? AppTheme.statusWarning
                                  : AppTheme.statusError,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _rangeDays <= 7
                                ? _weekday(dayDate.weekday)
                                : _formatShortDate(dayDate),
                            style: TextStyle(
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
    );
  }

  Widget _buildMedicineBreakdown(
    Map<String, List<DoseOccurrence>> medicineMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medicine Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (medicineMap.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No medicine occurrences found for this timeframe.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13),
                ),
              ),
            ),
          )
        else
          ...medicineMap.entries.map((entry) {
            final doses = entry.value;
            final firstDose = doses.first;
            final med = firstDose.medicine;
            final member = session.members
                .where((m) => m.id == firstDose.memberId)
                .firstOrNull;

            final taken = doses
                .where((d) => d.status == OccurrenceStatus.taken)
                .length;
            final missed = doses
                .where((d) => d.status == OccurrenceStatus.missed)
                .length;
            final total = doses.length;
            final ratio = total > 0 ? (taken / total) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  med.medicineName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${med.medicineDosage} · ${med.frequency}${member != null ? ' · For ${member.name}' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$taken taken${missed > 0 ? ' · $missed missed' : ''} / $total total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppTheme.outline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ratio >= 0.75
                                ? AppTheme.teal
                                : AppTheme.statusWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHistoryTimeline() {
    final session = CareSession.instance;
    var events = session.doseEvents.toList();
    if (_memberId != null) {
      events = events.where((e) => e.memberId == _memberId).toList();
    }
    events.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: AppTheme.teal),
            const SizedBox(width: 8),
            Text(
              'Medication History Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Chronological log of verified dose events and recorded timestamps.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 32,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recorded dose history yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When you mark doses as Taken or Missed, an immutable log will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppTheme.outline),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length.clamp(0, 20),
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, idx) {
                final event = events[idx];
                final isTaken = event.status == DoseStatus.taken;
                final member = session.members
                    .where((m) => m.id == event.memberId)
                    .firstOrNull;
                final memberName = member?.name ?? 'Family member';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isTaken
                              ? AppTheme.teal.withValues(alpha: 0.12)
                              : AppTheme.statusError.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTaken
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isTaken ? AppTheme.teal : AppTheme.statusError,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.medicineName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'For $memberName · Scheduled: ${_formatDate(event.scheduledAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isTaken
                              ? AppTheme.teal.withValues(alpha: 0.1)
                              : AppTheme.statusError.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isTaken ? 'Taken' : 'Missed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isTaken
                                ? AppTheme.teal
                                : AppTheme.statusError,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hour:$minute $ampm';
  }
}
