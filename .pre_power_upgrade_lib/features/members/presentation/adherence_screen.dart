import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';

class AdherenceScreen extends StatelessWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CareSession.instance,
    builder: (context, _) {
      final session = CareSession.instance;
      final events = session.doseEvents;
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final weekly = List.generate(
        7,
        (i) => events
            .where(
              (e) =>
                  !e.scheduledAt.isBefore(weekStart.add(Duration(days: i))) &&
                  e.scheduledAt.isBefore(weekStart.add(Duration(days: i + 1))),
            )
            .toList(),
      );
      final taken = events.where((e) => e.status == DoseStatus.taken).length;
      final percent = events.isEmpty
          ? null
          : (taken * 100 / events.length).round();
      final recent = events.toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return Scaffold(
        appBar: AppBar(title: const Text('Adherence history')),
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
              const SizedBox(height: 7),
              const Text(
                'A summary of doses you have recorded.',
                style: TextStyle(fontSize: 14, color: AppTheme.muted),
              ),
              const SizedBox(height: 20),
              _panel(
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: percent == null ? 0 : percent / 100,
                              strokeWidth: 7,
                              backgroundColor: const Color(0xFFE7EEEB),
                              valueColor: const AlwaysStoppedAnimation(
                                AppTheme.teal,
                              ),
                            ),
                          ),
                          Text(
                            percent == null ? '—' : '$percent%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            percent == null
                                ? 'No adherence score yet'
                                : '$taken of ${events.length} recorded doses taken',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            percent == null
                                ? 'Record doses from today’s schedule to build a real summary.'
                                : 'Calculated only from saved Taken and Missed events.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recorded doses by scheduled day',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 130,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final dayEvents = weekly[i];
                          final ratio = dayEvents.isEmpty
                              ? 0.0
                              : dayEvents
                                        .where(
                                          (e) => e.status == DoseStatus.taken,
                                        )
                                        .length /
                                    dayEvents.length;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    dayEvents.isEmpty
                                        ? ''
                                        : '${(ratio * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: dayEvents.isEmpty
                                        ? 5
                                        : 88 * ratio + 8,
                                    decoration: BoxDecoration(
                                      color: dayEvents.isEmpty
                                          ? const Color(0xFFE7EEEB)
                                          : AppTheme.teal.withValues(
                                              alpha: .45 + ratio * .5,
                                            ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    const [
                                      'M',
                                      'T',
                                      'W',
                                      'T',
                                      'F',
                                      'S',
                                      'S',
                                    ][i],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Recent dose events',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                _panel(
                  const Text(
                    'No doses have been recorded yet. Adding a medicine never counts as a dose taken.',
                    style: TextStyle(color: AppTheme.muted, height: 1.45),
                  ),
                )
              else
                ...recent.take(30).map((event) {
                  final member = session.members
                      .where((m) => m.id == event.memberId)
                      .firstOrNull;
                  final takenEvent = event.status == DoseStatus.taken;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _panel(
                      Row(
                        children: [
                          Icon(
                            takenEvent
                                ? Icons.check_circle_rounded
                                : Icons.event_busy_rounded,
                            color: takenEvent
                                ? AppTheme.teal
                                : const Color(0xFFB45A4A),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.medicineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  '${member?.name ?? 'Family member'} · ${_dateTime(event.scheduledAt)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            takenEvent ? 'Taken' : 'Missed',
                            style: TextStyle(
                              color: takenEvent
                                  ? AppTheme.teal
                                  : const Color(0xFFB45A4A),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              const Text(
                'Adherence reflects recorded dose events only. This local demo does not send reminders or sync with a server.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  static Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE7ECE9)),
    ),
    child: child,
  );
  static String _dateTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · $h:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
