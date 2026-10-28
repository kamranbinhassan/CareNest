import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/analytics/dose_analytics.dart';
import 'package:medicine_adherence_monitoring/core/data/care_session.dart';
import 'package:medicine_adherence_monitoring/features/medications/domain/models/medication_schedule.dart';

void main() {
  final medicine = MedicationSchedule(
    id: 'medicine-1',
    medicineName: 'Sample medicine',
    medicineDosage: '10 mg',
    medicineForm: 'Tablet',
    frequency: 'Once daily',
    doseAmount: '1',
    foodInstruction: 'After food',
    instructions: '',
    startDate: DateTime(2026, 10, 26),
    doseTimes: const [MedicationDoseTime(hour: 9, minute: 0)],
  );

  DoseOccurrence occurrence(OccurrenceStatus status, int day) => DoseOccurrence(
    memberId: 'member-1',
    medicine: medicine,
    scheduledAt: DateTime(2026, 10, day, 9),
    event: status == OccurrenceStatus.taken || status == OccurrenceStatus.missed
        ? DoseEvent(
            id: 'event-$day',
            memberId: 'member-1',
            medicineId: medicine.id,
            medicineName: medicine.medicineName,
            scheduledAt: DateTime(2026, 10, day, 9),
            status: status == OccurrenceStatus.taken
                ? DoseStatus.taken
                : DoseStatus.missed,
            recordedAt: DateTime(2026, 10, day, 9, 1),
          )
        : null,
    status: status,
  );

  test('adherence excludes pending and overdue occurrences', () {
    final summary = DoseSummary.from([
      occurrence(OccurrenceStatus.taken, 26),
      occurrence(OccurrenceStatus.missed, 25),
      occurrence(OccurrenceStatus.overdue, 24),
      occurrence(OccurrenceStatus.upcoming, 27),
    ]);
    expect(summary.scheduled, 4);
    expect(summary.adherencePercent, 50);
    expect(summary.completionPercent, 25);
    expect(summary.overdue, 1);
    expect(summary.upcoming, 1);
  });

  test('unrecorded occurrences do not create a completed percentage', () {
    final summary = DoseSummary.from([
      occurrence(OccurrenceStatus.overdue, 26),
      occurrence(OccurrenceStatus.upcoming, 27),
    ]);
    expect(summary.adherencePercent, isNull);
    expect(summary.completionPercent, 0);
  });

  test('daily grouping uses the scheduled local calendar date', () {
    final start = DateTime(2026, 10, 25);
    final grouped = DoseAnalytics.byDay(
      occurrences: [occurrence(OccurrenceStatus.taken, 26)],
      firstDay: start,
      dayCount: 3,
    );
    expect(grouped.map((day) => day.summary.taken), [0, 1, 0]);
  });
  test('correcting a dose preserves the scheduled-occurrence identity', () {
    final scheduledAt = DateTime(2026, 10, 26, 9);
    final firstAction = DoseEvent.record(
      previous: null,
      memberId: 'member-1',
      medicineId: medicine.id,
      medicineName: medicine.medicineName,
      scheduledAt: scheduledAt,
      status: DoseStatus.missed,
      actionAt: DateTime(2026, 10, 26, 9, 5),
    );
    final correction = DoseEvent.record(
      previous: firstAction,
      memberId: 'member-1',
      medicineId: medicine.id,
      medicineName: medicine.medicineName,
      scheduledAt: scheduledAt,
      status: DoseStatus.taken,
      actionAt: DateTime(2026, 10, 26, 9, 8),
    );
    expect(correction.id, firstAction.id);
    expect(correction.status, DoseStatus.taken);
    expect(correction.recordedAt, DateTime(2026, 10, 26, 9, 8));
  });
}
