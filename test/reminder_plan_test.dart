import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/notifications/reminder_service.dart';
import 'package:medicine_adherence_monitoring/features/medications/domain/models/medication_schedule.dart';

void main() {
  group('ReminderPlan.upcoming', () {
    final times = [
      const MedicationDoseTime(hour: 8, minute: 0),
      const MedicationDoseTime(hour: 20, minute: 30),
    ];

    test('returns each future dose time and excludes elapsed doses today', () {
      final now = DateTime(2026, 10, 27, 12);
      final plan = ReminderPlan(
        memberId: 'member',
        medicineId: 'medicine',
        name: 'Medicine',
        dosage: '10 mg',
        amount: '1 tablet',
        frequency: 'Once daily',
        startDate: DateTime(2026, 10, 27),
        times: times,
      );

      expect(plan.upcoming(now: now, days: 1), [
        DateTime(2026, 10, 27, 20, 30),
      ]);
    });

    test('honors start, end, every other day, and weekly boundaries', () {
      final now = DateTime(2026, 10, 27, 7);
      final alternate = ReminderPlan(
        memberId: 'm',
        medicineId: 'a',
        name: 'A',
        dosage: '',
        amount: '1',
        frequency: 'Every other day',
        startDate: DateTime(2026, 10, 27),
        endDate: DateTime(2026, 10, 30),
        times: [times.first],
      );
      expect(alternate.upcoming(now: now, days: 6), [
        DateTime(2026, 10, 27, 8),
        DateTime(2026, 10, 29, 8),
      ]);

      final weekly = ReminderPlan(
        memberId: 'm',
        medicineId: 'w',
        name: 'W',
        dosage: '',
        amount: '1',
        frequency: 'Weekly',
        startDate: DateTime(2026, 10, 27),
        times: [times.first],
      );
      expect(weekly.upcoming(now: now, days: 8), [
        DateTime(2026, 10, 27, 8),
        DateTime(2026, 11, 3, 8),
      ]);
    });

    test('does not invent dose times for as-needed or empty schedules', () {
      ReminderPlan plan(String frequency, List<MedicationDoseTime> values) =>
          ReminderPlan(
            memberId: 'm',
            medicineId: 'x',
            name: 'X',
            dosage: '',
            amount: '',
            frequency: frequency,
            startDate: DateTime(2026),
            times: values,
          );
      expect(
        plan('As needed', times).upcoming(now: DateTime(2026), days: 2),
        isEmpty,
      );
      expect(
        plan('Once daily', []).upcoming(now: DateTime(2026), days: 2),
        isEmpty,
      );
    });

    test('deduplicates repeated dose times in a malformed plan', () {
      final duplicate = ReminderPlan(
        memberId: 'm',
        medicineId: 'd',
        name: 'D',
        dosage: '5 mg',
        amount: '1 tablet',
        frequency: 'Once daily',
        startDate: DateTime(2026, 10, 27),
        times: [times.first, times.first],
      );
      expect(duplicate.upcoming(now: DateTime(2026, 10, 27, 7), days: 1), [
        DateTime(2026, 10, 27, 8),
      ]);
    });

    test('persists and restores the same medicine plan', () {
      final original = ReminderPlan(
        memberId: 'm',
        medicineId: 'x',
        name: 'X',
        dosage: '20 mg',
        amount: '1 capsule',
        frequency: 'Twice daily',
        startDate: DateTime(2026, 10, 27),
        endDate: DateTime(2026, 11, 2),
        times: times,
      );
      final restored = ReminderPlan.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.dosage, original.dosage);
      expect(restored.frequency, original.frequency);
      expect(
        restored.times.map((time) => time.toJson()).toList(),
        original.times.map((time) => time.toJson()).toList(),
      );
    });
  });
}
