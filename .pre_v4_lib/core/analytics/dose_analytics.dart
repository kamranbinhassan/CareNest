import '../data/care_session.dart';

/// Shared, deterministic summaries for a set of expected dose occurrences.
/// Upcoming and overdue doses never count as completed or missed.
class DoseSummary {
  final int scheduled;
  final int taken;
  final int missed;
  final int overdue;
  final int upcoming;

  const DoseSummary({
    required this.scheduled,
    required this.taken,
    required this.missed,
    required this.overdue,
    required this.upcoming,
  });

  factory DoseSummary.from(Iterable<DoseOccurrence> occurrences) {
    var scheduled = 0;
    var taken = 0;
    var missed = 0;
    var overdue = 0;
    var upcoming = 0;
    for (final occurrence in occurrences) {
      scheduled++;
      switch (occurrence.status) {
        case OccurrenceStatus.taken:
          taken++;
        case OccurrenceStatus.missed:
          missed++;
        case OccurrenceStatus.overdue:
          overdue++;
        case OccurrenceStatus.upcoming:
          upcoming++;
      }
    }
    return DoseSummary(
      scheduled: scheduled,
      taken: taken,
      missed: missed,
      overdue: overdue,
      upcoming: upcoming,
    );
  }

  int get actioned => taken + missed;
  int get remaining => overdue + upcoming;
  int? get adherencePercent =>
      actioned == 0 ? null : (taken * 100 / actioned).round();
  int? get completionPercent =>
      scheduled == 0 ? null : (taken * 100 / scheduled).round();
}

class DailyDoseSummary {
  final DateTime day;
  final DoseSummary summary;
  const DailyDoseSummary(this.day, this.summary);
}

class DoseAnalytics {
  const DoseAnalytics._();

  static List<DailyDoseSummary> byDay({
    required Iterable<DoseOccurrence> occurrences,
    required DateTime firstDay,
    required int dayCount,
  }) {
    final normalizedStart = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day,
    );
    return List.generate(dayCount, (index) {
      final day = DateTime(
        normalizedStart.year,
        normalizedStart.month,
        normalizedStart.day + index,
      );
      final nextDay = DateTime(day.year, day.month, day.day + 1);
      final doses = occurrences.where(
        (dose) =>
            !dose.scheduledAt.isBefore(day) &&
            dose.scheduledAt.isBefore(nextDay),
      );
      return DailyDoseSummary(day, DoseSummary.from(doses));
    });
  }
}
