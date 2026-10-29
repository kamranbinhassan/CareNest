import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/data/care_session.dart';
import 'package:medicine_adherence_monitoring/features/medications/domain/models/medication_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CareSession.instance.createFamily(name: 'CareNest Home');
  });

  tearDown(() {
    for (final m in CareSession.instance.members.toList()) {
      CareSession.instance.removeMember(m.id);
    }
  });

  test(
    'Personal mode: Myself creates single owner profile without forcing extra members',
    () {
      final session = CareSession.instance;
      expect(session.members, isEmpty);

      final owner = session.getOrCreateOwnerMember(name: 'Rahim');
      expect(owner.name, 'Rahim');
      expect(owner.relationship, 'Myself');
      expect(session.members.length, 1);
      expect(session.activeMemberId, owner.id);
    },
  );

  test('Reopening onboarding does not create duplicate owner profiles', () {
    final session = CareSession.instance;
    final owner1 = session.getOrCreateOwnerMember(name: 'Rahim');
    expect(session.members.length, 1);

    // Reopen / call again
    final owner2 = session.getOrCreateOwnerMember(name: 'Rahim');
    expect(session.members.length, 1);
    expect(owner2.id, owner1.id);
  });

  test('Manage Family allows adding family members later', () {
    final session = CareSession.instance;
    final owner = session.getOrCreateOwnerMember(name: 'Rahim');
    final mother = session.addMember(name: 'Amina', relationship: 'Parent');

    expect(session.members.length, 2);
    expect(mother.name, 'Amina');
    expect(mother.relationship, 'Parent');
    expect(mother.id, isNot(owner.id));
  });

  test(
    'Updating member profile preserves member ID and medication schedules',
    () {
      final session = CareSession.instance;
      final member = session.addMember(name: 'Father', relationship: 'Parent');

      final med = MedicationSchedule(
        medicineName: 'Metformin',
        medicineDosage: '500mg',
        frequency: 'Once daily',
        startDate: DateTime(2026, 1, 1),
        doseTimes: [MedicationDoseTime(hour: 8, minute: 0)],
      );
      session.addMedicine(member.id, med);
      expect(session.medicinesFor(member.id).length, 1);

      // Update father's name and relationship
      session.updateMember(
        memberId: member.id,
        name: 'Tariq Hassan',
        relationship: 'Father',
      );

      final updated = session.members.firstWhere((m) => m.id == member.id);
      expect(updated.name, 'Tariq Hassan');
      expect(updated.relationship, 'Father');

      // Schedules must be fully preserved
      final medsAfter = session.medicinesFor(member.id);
      expect(medsAfter.length, 1);
      expect(medsAfter.first.medicineName, 'Metformin');
    },
  );

  test(
    'Family space name can be updated without wiping members or medications',
    () {
      final session = CareSession.instance;
      session.updateFamilyName('Hassan Residence');
      expect(session.familyName, 'Hassan Residence');

      final member = session.addMember(name: 'Sara', relationship: 'Child');
      session.updateFamilyName('The Hassan Family');

      expect(session.familyName, 'The Hassan Family');
      expect(session.members.length, 1);
      expect(member.name, 'Sara');
    },
  );

  test('Member removal isolates data and does not affect other members', () {
    final session = CareSession.instance;
    final m1 = session.addMember(name: 'Alice', relationship: 'Child');
    final m2 = session.addMember(name: 'Bob', relationship: 'Child');

    session.addMedicine(
      m1.id,
      MedicationSchedule(
        medicineName: 'Amoxicillin',
        medicineDosage: '250mg',
        frequency: 'Three times daily',
        startDate: DateTime(2026, 1, 1),
        doseTimes: [
          MedicationDoseTime(hour: 8, minute: 0),
          MedicationDoseTime(hour: 14, minute: 0),
          MedicationDoseTime(hour: 20, minute: 0),
        ],
      ),
    );

    session.addMedicine(
      m2.id,
      MedicationSchedule(
        medicineName: 'Vitamin D',
        medicineDosage: '1000 IU',
        frequency: 'Once daily',
        startDate: DateTime(2026, 1, 1),
        doseTimes: [MedicationDoseTime(hour: 9, minute: 0)],
      ),
    );

    expect(session.medicinesFor(m1.id).length, 1);
    expect(session.medicinesFor(m2.id).length, 1);

    session.removeMember(m1.id);
    expect(session.members.length, 1);
    expect(session.members.first.id, m2.id);
    expect(session.medicinesFor(m1.id), isEmpty);
    expect(session.medicinesFor(m2.id).length, 1);
  });
}
