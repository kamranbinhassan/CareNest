import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/data/care_session.dart';
import 'package:medicine_adherence_monitoring/features/family/presentation/family_home_screen.dart';
import 'package:medicine_adherence_monitoring/features/medications/domain/models/medication_schedule.dart';
import 'package:medicine_adherence_monitoring/features/support/presentation/care_support_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CareSession.instance.createFamily(name: 'Test Family');
  });

  tearDown(() {
    for (final m in CareSession.instance.members.toList()) {
      CareSession.instance.removeMember(m.id);
    }
  });

  group('Stock Tracking & Refill Alerts', () {
    test(
      'MedicationSchedule stock tracking fields and low-stock detection',
      () {
        final med = MedicationSchedule(
          medicineName: 'Amlodipine',
          medicineDosage: '5mg',
          frequency: 'Once daily',
          startDate: DateTime(2026, 1, 1),
          doseTimes: [MedicationDoseTime(hour: 8, minute: 0)],
          currentStock: 5,
          refillAlertThreshold: 7,
        );

        expect(med.hasStockTracking, isTrue);
        expect(med.isLowStock, isTrue);

        final medStocked = med.copyWith(currentStock: 30);
        expect(medStocked.hasStockTracking, isTrue);
        expect(medStocked.isLowStock, isFalse);
      },
    );

    test('Taking dose decrements stock and undoing restores stock', () {
      final session = CareSession.instance;
      final member = session.addMember(
        name: 'Grandma',
        relationship: 'Grandparent',
      );

      final med = MedicationSchedule(
        id: 'med_stock_test',
        medicineName: 'Lisinopril',
        medicineDosage: '10mg',
        doseAmount: '1',
        frequency: 'Once daily',
        startDate: DateTime(2026, 1, 1),
        doseTimes: [MedicationDoseTime(hour: 8, minute: 0)],
        currentStock: 10,
        refillAlertThreshold: 5,
      );
      session.addMedicine(member.id, med);

      final scheduledAt = DateTime(2026, 1, 2, 8, 0);

      // Record dose as taken
      final recorded = session.recordDose(
        memberId: member.id,
        medicineId: med.id,
        scheduledAt: scheduledAt,
        status: DoseStatus.taken,
      );
      expect(recorded, isTrue);

      // Stock should decrement from 10 to 9
      final currentMed = session.medicineById(member.id, med.id);
      expect(currentMed?.currentStock, 9);
      expect(currentMed?.isLowStock, isFalse);

      // Undo the dose
      session.undoDoseChange(
        memberId: member.id,
        medicineId: med.id,
        scheduledAt: scheduledAt,
        previousEvent: null,
      );

      // Stock should be restored to 10
      final restoredMed = session.medicineById(member.id, med.id);
      expect(restoredMed?.currentStock, 10);
    });
  });

  group('Care & Support Screen', () {
    testWidgets('Renders diagnostics, help guides, and copy action', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: CareSupportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Care & Support'), findsOneWidget);
      expect(find.text('Help & Guidance'), findsOneWidget);
      expect(find.text('Storage Health'), findsOneWidget);
      expect(find.text('Copy Diagnostic Report'), findsOneWidget);
      expect(find.text('HELP GUIDES'), findsOneWidget);

      // Tap Copy Diagnostic Report
      await tester.tap(find.text('Copy Diagnostic Report'));
      await tester.pump();
      expect(
        find.text('Diagnostic summary copied to clipboard!'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));

      await tester.scrollUntilVisible(
        find.text('Important Medical Disclaimer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Important Medical Disclaimer'), findsOneWidget);
    });
  });

  group('Bottom Navigation Responsiveness', () {
    testWidgets('Renders all 5 labels on narrow screens without overflow', (
      tester,
    ) async {
      // Test narrow screen width: 320dp
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: FamilyHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
    });
  });
}
