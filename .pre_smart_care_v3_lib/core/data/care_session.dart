import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/medications/domain/models/medication_schedule.dart';

enum DoseStatus { taken, missed }

enum OccurrenceStatus { taken, missed, upcoming, overdue }

class DoseEvent {
  final String id;
  final String memberId;
  final String medicineId;
  final String medicineName;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime recordedAt;

  const DoseEvent({
    required this.id,
    required this.memberId,
    required this.medicineId,
    required this.medicineName,
    required this.scheduledAt,
    required this.status,
    required this.recordedAt,
  });

  DoseEvent copyWith({DoseStatus? status, DateTime? recordedAt}) => DoseEvent(
    id: id,
    memberId: memberId,
    medicineId: medicineId,
    medicineName: medicineName,
    scheduledAt: scheduledAt,
    status: status ?? this.status,
    recordedAt: recordedAt ?? this.recordedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'memberId': memberId,
    'medicineId': medicineId,
    'medicineName': medicineName,
    'scheduledAt': scheduledAt.toIso8601String(),
    'status': status.name,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory DoseEvent.fromJson(Map<String, dynamic> json) {
    final scheduledAt = DateTime.tryParse(json['scheduledAt'] as String? ?? '');
    final status = DoseStatus.values
        .where((value) => value.name == json['status'])
        .firstOrNull;
    if (scheduledAt == null || status == null) {
      throw const FormatException('Invalid dose event.');
    }
    final memberId = json['memberId'] as String? ?? '';
    final medicineName = json['medicineName'] as String? ?? 'Medicine';
    final id =
        json['id'] as String? ??
        _occurrenceId(
          memberId,
          json['medicineId'] as String? ?? '',
          scheduledAt,
        );
    return DoseEvent(
      id: id,
      memberId: memberId,
      medicineId: json['medicineId'] as String? ?? '',
      medicineName: medicineName,
      scheduledAt: scheduledAt,
      status: status,
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? scheduledAt,
    );
  }
}

class FamilyMember {
  final String id;
  final String name;
  final String relationship;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'Family member',
  );
}

class DoseOccurrence {
  final String memberId;
  final MedicationSchedule medicine;
  final DateTime scheduledAt;
  final DoseEvent? event;
  final OccurrenceStatus status;

  const DoseOccurrence({
    required this.memberId,
    required this.medicine,
    required this.scheduledAt,
    required this.event,
    required this.status,
  });
}

String _occurrenceId(String memberId, String medicineId, DateTime at) =>
    '${memberId}_${medicineId}_${at.toIso8601String()}';

class CareSession extends ChangeNotifier {
  CareSession._();
  static final CareSession instance = CareSession._();
  static const _storageKey = 'care_session_v1';
  static const _storage = FlutterSecureStorage();

  String familyName = '';
  String ownerName = '';
  final List<FamilyMember> _members = [];
  final Map<String, List<MedicationSchedule>> _medicines = {};
  final List<DoseEvent> _doseEvents = [];
  Future<void> _writeQueue = Future<void>.value();
  bool persistenceAvailable = false;
  String? storageError;

  List<FamilyMember> get members => List.unmodifiable(_members);
  List<DoseEvent> get doseEvents => List.unmodifiable(_doseEvents);
  List<MedicationSchedule> medicinesFor(String memberId) =>
      List.unmodifiable(_medicines[memberId] ?? const []);
  int get medicineCount =>
      _medicines.values.fold(0, (sum, items) => sum + items.length);
  Future<void> flush() => _writeQueue;

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Invalid care data.');
        }
        familyName = data['familyName'] as String? ?? '';
        ownerName = data['ownerName'] as String? ?? '';
        _members
          ..clear()
          ..addAll(
            _readItems(
              data['members'],
              FamilyMember.fromJson,
            ).where((member) => member.id.isNotEmpty),
          );
        _medicines
          ..clear()
          ..addAll(_readMedicineMap(data['medicines']));
        _doseEvents
          ..clear()
          ..addAll(
            _readItems(
              data['doseEvents'],
              DoseEvent.fromJson,
            ).map(_migrateEventMedicineId),
          );
      }
      persistenceAvailable = true;
      storageError = null;
    } catch (error) {
      persistenceAvailable = false;
      storageError =
          'Saved care data could not be read. Existing device data was left untouched.';
      // Keep any valid data already restored, rather than clearing it.
    }
    notifyListeners();
  }

  List<T> _readItems<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
    if (raw is! List) return [];
    final result = <T>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        try {
          result.add(decode(item));
        } catch (_) {
          /* Skip malformed rows. */
        }
      }
    }
    return result;
  }

  Map<String, List<MedicationSchedule>> _readMedicineMap(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    final result = <String, List<MedicationSchedule>>{};
    for (final entry in raw.entries) {
      if (entry.value is! List) continue;
      final medicines = <MedicationSchedule>[];
      for (final item in entry.value as List) {
        if (item is! Map<String, dynamic>) continue;
        try {
          var medicine = MedicationSchedule.fromJson(item);
          if ((item['id'] as String?)?.isNotEmpty != true) {
            medicine = _withId(
              medicine,
              'legacy_${entry.key}_${medicines.length}',
            );
          }
          medicines.add(medicine);
        } catch (_) {
          // Keep valid schedules even if one old row is malformed.
        }
      }
      result[entry.key] = medicines;
    }
    return result;
  }

  DoseEvent _migrateEventMedicineId(DoseEvent event) {
    if (event.medicineId.isNotEmpty) return event;
    final medicine = medicinesFor(
      event.memberId,
    ).where((item) => item.medicineName == event.medicineName).firstOrNull;
    if (medicine == null) return event;
    return DoseEvent(
      id: _occurrenceId(event.memberId, medicine.id, event.scheduledAt),
      memberId: event.memberId,
      medicineId: medicine.id,
      medicineName: event.medicineName,
      scheduledAt: event.scheduledAt,
      status: event.status,
      recordedAt: event.recordedAt,
    );
  }

  void setFamily({required String name, String owner = ''}) {
    familyName = name.trim();
    if (owner.trim().isNotEmpty) ownerName = owner.trim();
    _changed();
  }

  void createFamily({required String name}) {
    familyName = name.trim();
    _changed();
  }

  FamilyMember addMember({required String name, required String relationship}) {
    final member = FamilyMember(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_members.length}',
      name: name.trim(),
      relationship: relationship,
    );
    _members.add(member);
    _medicines[member.id] = [];
    _changed();
    return member;
  }

  void removeMember(String memberId) {
    if (!_members.any((member) => member.id == memberId)) return;
    _members.removeWhere((member) => member.id == memberId);
    _medicines.remove(memberId);
    _doseEvents.removeWhere((event) => event.memberId == memberId);
    _changed();
  }

  MedicationSchedule? medicineById(String memberId, String medicineId) =>
      medicinesFor(
        memberId,
      ).where((medicine) => medicine.id == medicineId).firstOrNull;

  void addMedicine(String memberId, MedicationSchedule medicine) {
    if (!_members.any((member) => member.id == memberId)) return;
    final saved = medicine.id.isEmpty
        ? _withId(medicine, '${DateTime.now().microsecondsSinceEpoch}')
        : medicine;
    (_medicines[memberId] ??= []).add(saved);
    _changed();
  }

  MedicationSchedule _withId(MedicationSchedule medicine, String id) =>
      MedicationSchedule(
        id: id,
        medicineName: medicine.medicineName,
        medicineDosage: medicine.medicineDosage,
        medicineForm: medicine.medicineForm,
        frequency: medicine.frequency,
        doseAmount: medicine.doseAmount,
        foodInstruction: medicine.foodInstruction,
        instructions: medicine.instructions,
        startDate: medicine.startDate,
        endDate: medicine.endDate,
        doseTimes: medicine.doseTimes,
      );

  bool recordDose({
    required String memberId,
    required String medicineId,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) {
    final medicine = medicineById(memberId, medicineId);
    if (medicine == null ||
        scheduledAt.isAfter(DateTime.now()) ||
        !_isExpected(medicine, scheduledAt)) {
      return false;
    }
    final id = _occurrenceId(memberId, medicineId, scheduledAt);
    final existingIndex = _doseEvents.indexWhere((event) => event.id == id);
    final event = DoseEvent(
      id: id,
      memberId: memberId,
      medicineId: medicine.id,
      medicineName: medicine.medicineName,
      scheduledAt: scheduledAt,
      status: status,
      recordedAt: DateTime.now(),
    );
    if (existingIndex < 0) {
      _doseEvents.add(event);
    } else {
      _doseEvents[existingIndex] = event;
    }
    _changed();
    return true;
  }

  DoseEvent? doseEventFor(
    String memberId,
    String medicineId,
    DateTime scheduledAt,
  ) {
    final id = _occurrenceId(memberId, medicineId, scheduledAt);
    return _doseEvents.where((event) => event.id == id).firstOrNull;
  }

  void removeMedicine(String memberId, String medicineId) {
    final medicines = _medicines[memberId];
    if (medicines == null) return;
    final removed = medicines
        .where((medicine) => medicine.id == medicineId)
        .isNotEmpty;
    if (!removed) return;
    medicines.removeWhere((medicine) => medicine.id == medicineId);
    // Keep dose history; events are still useful as an audit trail after plan removal.
    _changed();
  }

  List<DoseOccurrence> occurrencesFor({
    required String memberId,
    required DateTime from,
    required DateTime through,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final firstDay = DateTime(from.year, from.month, from.day);
    final lastDay = DateTime(through.year, through.month, through.day);
    if (lastDay.isBefore(firstDay)) return [];
    final occurrences = <DoseOccurrence>[];
    for (final medicine in medicinesFor(memberId)) {
      final medicineStart = DateTime(
        medicine.startDate.year,
        medicine.startDate.month,
        medicine.startDate.day,
      );
      final medicineEnd = medicine.endDate == null
          ? null
          : DateTime(
              medicine.endDate!.year,
              medicine.endDate!.month,
              medicine.endDate!.day,
            );
      var day = firstDay.isAfter(medicineStart) ? firstDay : medicineStart;
      final last = medicineEnd != null && medicineEnd.isBefore(lastDay)
          ? medicineEnd
          : lastDay;
      while (!day.isAfter(last)) {
        if (_occursOn(medicine.frequency, medicineStart, day)) {
          for (final time in medicine.doseTimes) {
            final scheduledAt = DateTime(
              day.year,
              day.month,
              day.day,
              time.hour,
              time.minute,
            );
            final event = doseEventFor(memberId, medicine.id, scheduledAt);
            final status = scheduledAt.isAfter(clock)
                ? OccurrenceStatus.upcoming
                : event != null
                ? (event.status == DoseStatus.taken
                      ? OccurrenceStatus.taken
                      : OccurrenceStatus.missed)
                : OccurrenceStatus.overdue;
            occurrences.add(
              DoseOccurrence(
                memberId: memberId,
                medicine: medicine,
                scheduledAt: scheduledAt,
                event: event,
                status: status,
              ),
            );
          }
        }
        day = day.add(const Duration(days: 1));
      }
    }
    occurrences.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return occurrences;
  }

  bool _isExpected(MedicationSchedule medicine, DateTime scheduledAt) {
    final day = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
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
    return !day.isBefore(start) &&
        (end == null || !day.isAfter(end)) &&
        _occursOn(medicine.frequency, start, day) &&
        medicine.doseTimes.any(
          (time) =>
              time.hour == scheduledAt.hour &&
              time.minute == scheduledAt.minute &&
              scheduledAt.second == 0,
        );
  }

  bool _occursOn(String frequency, DateTime start, DateTime day) {
    switch (frequency) {
      case 'Every other day':
        return day.difference(start).inDays % 2 == 0;
      case 'Weekly':
        return day.weekday == start.weekday;
      case 'As needed':
        return false;
      default:
        return true;
    }
  }

  void _changed() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storage.write(key: _storageKey, value: jsonEncode(_toJson()));
        persistenceAvailable = true;
        storageError = null;
      } catch (_) {
        persistenceAvailable = false;
        storageError =
            'Unable to save on this device. Current changes may be lost when the app closes.';
      }
      notifyListeners();
    });
  }

  Map<String, dynamic> _toJson() => {
    'familyName': familyName,
    'ownerName': ownerName,
    'members': _members.map((member) => member.toJson()).toList(),
    'doseEvents': _doseEvents.map((event) => event.toJson()).toList(),
    'medicines': _medicines.map(
      (id, items) =>
          MapEntry(id, items.map((medicine) => medicine.toJson()).toList()),
    ),
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
