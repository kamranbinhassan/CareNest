import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/data/care_session.dart';
import 'package:medicine_adherence_monitoring/core/notifications/reminder_service.dart';
import 'package:medicine_adherence_monitoring/features/medications/domain/models/medication_schedule.dart';
import 'package:medicine_adherence_monitoring/features/medications/presentation/medication_schedule_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('One dose per day', () {
    test('creates and serializes schedule with a single dose time', () {
      final schedule = MedicationSchedule(
        id: 'once_1',
        medicineName: 'Atorvastatin',
        medicineDosage: '20 mg',
        medicineForm: 'Tablet',
        frequency: 'Once daily',
        foodInstruction: 'No food instruction',
        doseAmount: '1',
        instructions: 'Take at night',
        startDate: DateTime(2026, 10, 29),
        doseTimes: const [MedicationDoseTime(hour: 21, minute: 0)],
      );

      final json = schedule.toJson();
      final decoded = jsonDecode(jsonEncode(json));
      final restored = MedicationSchedule.fromJson(decoded);

      expect(restored.frequency, 'Once daily');
      expect(restored.doseTimes.length, 1);
      expect(restored.doseTimes.first.hour, 21);
      expect(restored.doseTimes.first.minute, 0);
    });

    test('generates exactly one daily occurrence in CareSession', () {
      final session = CareSession.instance;
      session.createFamily(name: 'Test Family');
      final member = session.addMember(name: 'Alice', relationship: 'Self');

      final schedule = MedicationSchedule(
        id: 'med_once',
        medicineName: 'Aspirin',
        medicineDosage: '81 mg',
        medicineForm: 'Tablet',
        frequency: 'Once daily',
        foodInstruction: 'With food',
        doseAmount: '1',
        instructions: '',
        startDate: DateTime(2026, 10, 29),
        doseTimes: const [MedicationDoseTime(hour: 8, minute: 30)],
      );

      session.addMedicine(member.id, schedule);

      final occurrences = session.occurrencesFor(
        memberId: member.id,
        from: DateTime(2026, 10, 29),
        through: DateTime(2026, 10, 29),
        now: DateTime(2026, 10, 29, 6, 0),
      );

      expect(occurrences.length, 1);
      expect(occurrences.first.scheduledAt, DateTime(2026, 10, 29, 8, 30));
    });
  });

  group('Multiple doses per day', () {
    test(
      'retains all distinct dose times across serialization and deserialization',
      () {
        final schedule = MedicationSchedule(
          id: 'med_twice',
          medicineName: 'Amoxicillin',
          medicineDosage: '500 mg',
          medicineForm: 'Capsule',
          frequency: 'Twice daily',
          foodInstruction: 'With food',
          doseAmount: '1',
          instructions: 'Every 12 hours',
          startDate: DateTime(2026, 10, 29),
          doseTimes: const [
            MedicationDoseTime(hour: 9, minute: 0),
            MedicationDoseTime(hour: 21, minute: 0),
          ],
        );

        final json = schedule.toJson();
        final decoded = jsonDecode(jsonEncode(json));
        final restored = MedicationSchedule.fromJson(decoded);

        expect(restored.frequency, 'Twice daily');
        expect(restored.doseTimes.length, 2);
        expect(restored.doseTimes[0].hour, 9);
        expect(restored.doseTimes[1].hour, 21);
      },
    );

    test(
      'normalizes legacy multi-dose schedules that only had one dose time',
      () {
        // Legacy JSON where frequency is 'Twice daily' but only 1 dose was stored
        final legacyJson = {
          'id': 'legacy_1',
          'medicineName': 'Metformin',
          'medicineDosage': '500 mg',
          'frequency': 'Twice daily',
          'startDate': '2026-10-29T00:00:00.000',
          'doseTimes': [
            {'hour': 8, 'minute': 0},
          ],
        };

        final restored = MedicationSchedule.fromJson(legacyJson);
        expect(restored.frequency, 'Twice daily');
        expect(restored.doseTimes.length, 2);
        expect(restored.doseTimes[0].hour, 8);
        // Second dose time was safely supplemented with a non-colliding default
        expect(restored.doseTimes[1].hour, isNot(8));
      },
    );

    test('supports backend schema with dose_times snake_case keys', () {
      final backendJson = {
        'id': 'backend_1',
        'name': 'Ibuprofen',
        'dosage': '400 mg',
        'frequency': 'Three times daily',
        'start_date': '2026-10-29T00:00:00.000',
        'dose_times': [
          {'hour': 8, 'minute': 0},
          {'hour': 14, 'minute': 0},
          {'hour': 20, 'minute': 0},
        ],
      };

      final restored = MedicationSchedule.fromJson(backendJson);
      expect(restored.medicineName, 'Ibuprofen');
      expect(restored.frequency, 'Three times daily');
      expect(restored.doseTimes.length, 3);
      expect(restored.doseTimes.map((d) => d.hour).toList(), [8, 14, 20]);
    });

    test(
      'generates all scheduled occurrences for multi-dose schedules in CareSession',
      () {
        final session = CareSession.instance;
        session.createFamily(name: 'CareNest');
        final member = session.addMember(name: 'Bob', relationship: 'Father');

        final threeDoseSchedule = MedicationSchedule(
          id: 'med_three',
          medicineName: 'Antibiotic',
          medicineDosage: '250 mg',
          medicineForm: 'Tablet',
          frequency: 'Three times daily',
          foodInstruction: 'After food',
          doseAmount: '1',
          instructions: '',
          startDate: DateTime(2026, 10, 29),
          doseTimes: const [
            MedicationDoseTime(hour: 8, minute: 0),
            MedicationDoseTime(hour: 14, minute: 0),
            MedicationDoseTime(hour: 20, minute: 0),
          ],
        );

        session.addMedicine(member.id, threeDoseSchedule);

        final occurrences = session.occurrencesFor(
          memberId: member.id,
          from: DateTime(2026, 10, 29),
          through: DateTime(2026, 10, 29),
          now: DateTime(2026, 10, 29, 6, 0),
        );

        expect(occurrences.length, 3);
        expect(occurrences[0].scheduledAt, DateTime(2026, 10, 29, 8, 0));
        expect(occurrences[1].scheduledAt, DateTime(2026, 10, 29, 14, 0));
        expect(occurrences[2].scheduledAt, DateTime(2026, 10, 29, 20, 0));
      },
    );

    test('schedules all distinct reminder plan upcoming times', () {
      final plan = ReminderPlan(
        memberId: 'm1',
        medicineId: 'med_four',
        name: 'Pain Relief',
        dosage: '500 mg',
        amount: '1',
        frequency: 'Four times daily',
        startDate: DateTime(2026, 10, 29),
        times: const [
          MedicationDoseTime(hour: 6, minute: 0),
          MedicationDoseTime(hour: 12, minute: 0),
          MedicationDoseTime(hour: 18, minute: 0),
          MedicationDoseTime(hour: 23, minute: 59),
        ],
      );

      final upcoming = plan
          .upcoming(now: DateTime(2026, 10, 29, 5, 0), days: 1)
          .toList();

      expect(upcoming.length, 4);
      expect(upcoming[0], DateTime(2026, 10, 29, 6, 0));
      expect(upcoming[1], DateTime(2026, 10, 29, 12, 0));
      expect(upcoming[2], DateTime(2026, 10, 29, 18, 0));
      expect(upcoming[3], DateTime(2026, 10, 29, 23, 59));
    });

    testWidgets(
      'MedicationScheduleScreen displays all dose cards when frequency is Twice daily',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: MedicationScheduleScreen(
              medicineName: 'Amoxicillin',
              medicineDosage: '500 mg, twice daily',
              medicineForm: 'Capsule',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dose 1'), findsOneWidget);
        expect(find.text('Dose 2'), findsOneWidget);
      },
    );
  });

  group('Editing an existing schedule', () {
    testWidgets(
      'editing preserves existing distinct dose times and pre-populates form',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final initial = MedicationSchedule(
          id: 'edit_med_1',
          medicineName: 'Metformin',
          medicineDosage: '850 mg',
          medicineForm: 'Tablet',
          frequency: 'Twice daily',
          foodInstruction: 'With food',
          doseAmount: '1',
          instructions: 'Take with morning and evening meals',
          startDate: DateTime(2026, 10, 1),
          doseTimes: const [
            MedicationDoseTime(hour: 8, minute: 0),
            MedicationDoseTime(hour: 20, minute: 0),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MedicationScheduleScreen(
              medicineName: initial.medicineName,
              medicineDosage: initial.medicineDosage,
              medicineForm: initial.medicineForm,
              initialSchedule: initial,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit medication schedule'), findsOneWidget);
        expect(find.text('Dose 1'), findsOneWidget);
        expect(find.text('Dose 2'), findsOneWidget);
        expect(find.text('8:00 AM'), findsOneWidget);
        expect(find.text('8:00 PM'), findsOneWidget);
      },
    );

    test(
      'updating existing medicine replaces it in-place in CareSession without duplication',
      () {
        final session = CareSession.instance;
        session.createFamily(name: 'CareNest');
        final member = session.addMember(
          name: 'Charlie',
          relationship: 'Child',
        );

        final original = MedicationSchedule(
          id: 'med_charlie_1',
          medicineName: 'Vitamin D',
          medicineDosage: '1000 IU',
          medicineForm: 'Tablet',
          frequency: 'Once daily',
          foodInstruction: 'With food',
          doseAmount: '1',
          instructions: '',
          startDate: DateTime(2026, 10, 29),
          doseTimes: const [MedicationDoseTime(hour: 9, minute: 0)],
        );

        session.addMedicine(member.id, original);
        expect(session.medicinesFor(member.id).length, 1);
        expect(session.medicinesFor(member.id).first.frequency, 'Once daily');

        // Edit schedule: change to Twice daily with 2 dose times
        final updated = MedicationSchedule(
          id: 'med_charlie_1', // same ID
          medicineName: 'Vitamin D',
          medicineDosage: '1000 IU',
          medicineForm: 'Tablet',
          frequency: 'Twice daily',
          foodInstruction: 'With food',
          doseAmount: '1',
          instructions: '',
          startDate: DateTime(2026, 10, 29),
          doseTimes: const [
            MedicationDoseTime(hour: 9, minute: 0),
            MedicationDoseTime(hour: 21, minute: 0),
          ],
        );

        session.addMedicine(member.id, updated);

        // Must remain 1 medicine (updated in-place, not duplicated)
        final medicines = session.medicinesFor(member.id);
        expect(medicines.length, 1);
        expect(medicines.first.frequency, 'Twice daily');
        expect(medicines.first.doseTimes.length, 2);
        expect(medicines.first.doseTimes[1].hour, 21);
      },
    );
  });
}
