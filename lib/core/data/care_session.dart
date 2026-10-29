import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/medications/domain/models/medication_schedule.dart';
import '../notifications/reminder_service.dart';

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

  static String occurrenceId(String memberId, String medicineId, DateTime at) =>
      '${memberId}_${medicineId}_${at.toIso8601String()}';

  factory DoseEvent.record({
    required DoseEvent? previous,
    required String memberId,
    required String medicineId,
    required String medicineName,
    required DateTime scheduledAt,
    required DoseStatus status,
    required DateTime actionAt,
  }) => DoseEvent(
    id: previous?.id ?? occurrenceId(memberId, medicineId, scheduledAt),
    memberId: memberId,
    medicineId: medicineId,
    medicineName: medicineName,
    scheduledAt: scheduledAt,
    status: status,
    recordedAt: actionAt,
  );

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
    DoseEvent.occurrenceId(memberId, medicineId, at);

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
  List<ReminderPlan> get reminderPlans => [
    for (final entry in _medicines.entries)
      for (final medicine in entry.value)
        ReminderPlan(
          memberId: entry.key,
          medicineId: medicine.id,
          name: medicine.medicineName,
          dosage: medicine.medicineDosage,
          amount: medicine.doseAmount,
          frequency: medicine.frequency,
          startDate: medicine.startDate,
          endDate: medicine.endDate,
          times: medicine.doseTimes,
        ),
  ];
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
      if (item is Map) {
        try {
          result.add(decode(Map<String, dynamic>.from(item)));
        } catch (_) {
          /* Skip malformed rows. */
        }
      }
    }
    return result;
  }

  Map<String, List<MedicationSchedule>> _readMedicineMap(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, List<MedicationSchedule>>{};
    for (final entry in raw.entries) {
      if (entry.value is! List) continue;
      final medicines = <MedicationSchedule>[];
      for (final item in entry.value as List) {
        if (item is! Map) continue;
        try {
          final itemMap = Map<String, dynamic>.from(item);
          var medicine = MedicationSchedule.fromJson(itemMap);
          if ((itemMap['id'] as String?)?.isNotEmpty != true) {
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
      result[entry.key.toString()] = medicines;
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

  void updateFamilyName(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      familyName = trimmed;
      _changed();
    }
  }

  void createFamily({required String name}) {
    familyName = name.trim();
    _changed();
  }

  String? _activeMemberId;
  String? get activeMemberId => _activeMemberId;
  void setActiveMember(String? memberId) {
    if (memberId == null || _members.any((m) => m.id == memberId)) {
      _activeMemberId = memberId;
      notifyListeners();
    }
  }

  FamilyMember getOrCreateOwnerMember({String? name}) {
    final existing = _members
        .where(
          (m) =>
              m.relationship == 'Myself' ||
              m.relationship == 'Self' ||
              (ownerName.isNotEmpty && m.name == ownerName),
        )
        .firstOrNull;
    if (existing != null) {
      if (name != null &&
          name.trim().isNotEmpty &&
          existing.name != name.trim()) {
        updateMember(
          memberId: existing.id,
          name: name.trim(),
          relationship: existing.relationship,
        );
      }
      _activeMemberId ??= existing.id;
      return existing;
    }

    final ownerDisplayName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (ownerName.trim().isNotEmpty ? ownerName.trim() : 'Myself');

    final member = FamilyMember(
      id: 'owner_${DateTime.now().millisecondsSinceEpoch}',
      name: ownerDisplayName,
      relationship: 'Myself',
    );
    _members.add(member);
    _medicines[member.id] = [];
    _activeMemberId ??= member.id;
    _changed();
    return member;
  }

  FamilyMember addMember({required String name, required String relationship}) {
    final member = FamilyMember(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_members.length}',
      name: name.trim(),
      relationship: relationship,
    );
    _members.add(member);
    _medicines[member.id] = [];
    _activeMemberId ??= member.id;
    _changed();
    return member;
  }

  void updateMember({
    required String memberId,
    required String name,
    required String relationship,
  }) {
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index >= 0) {
      _members[index] = FamilyMember(
        id: memberId,
        name: name.trim(),
        relationship: relationship.trim(),
      );
      _changed();
    }
  }

  void removeMember(String memberId) {
    if (!_members.any((member) => member.id == memberId)) return;
    _members.removeWhere((member) => member.id == memberId);
    _medicines.remove(memberId);
    _doseEvents.removeWhere((event) => event.memberId == memberId);
    if (_activeMemberId == memberId) {
      _activeMemberId = _members.firstOrNull?.id;
    }
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
    final list = _medicines[memberId] ??= [];
    final existingIndex = list.indexWhere((m) => m.id == saved.id);
    if (existingIndex >= 0) {
      list[existingIndex] = saved;
    } else {
      list.add(saved);
    }
    _changed();
  }

  void updateMedicineStock(
    String memberId,
    String medicineId,
    int newStock, {
    int? refillThreshold,
  }) {
    final list = _medicines[memberId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == medicineId);
    if (index >= 0) {
      list[index] = list[index].copyWith(
        currentStock: newStock,
        refillAlertThreshold:
            refillThreshold ?? list[index].refillAlertThreshold,
      );
      _changed();
    }
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
        currentStock: medicine.currentStock,
        refillAlertThreshold: medicine.refillAlertThreshold,
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
    final previous = existingIndex < 0 ? null : _doseEvents[existingIndex];
    final event = DoseEvent.record(
      previous: previous,
      memberId: memberId,
      medicineId: medicine.id,
      medicineName: medicine.medicineName,
      scheduledAt: scheduledAt,
      status: status,
      actionAt: DateTime.now(),
    );
    if (existingIndex < 0) {
      _doseEvents.add(event);
    } else {
      _doseEvents[existingIndex] = event;
    }

    // Auto-decrement tracked stock when marking dose taken
    if (status == DoseStatus.taken &&
        (previous == null || previous.status != DoseStatus.taken)) {
      if (medicine.currentStock != null && medicine.currentStock! > 0) {
        final amount =
            (double.tryParse(medicine.doseAmount.split(' ').first) ?? 1.0)
                .toInt()
                .clamp(1, 99);
        final newStock = (medicine.currentStock! - amount).clamp(0, 99999);
        final list = _medicines[memberId];
        if (list != null) {
          final medIndex = list.indexWhere((m) => m.id == medicine.id);
          if (medIndex >= 0) {
            list[medIndex] = list[medIndex].copyWith(currentStock: newStock);
          }
        }
      }
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

  void undoDoseChange({
    required String memberId,
    required String medicineId,
    required DateTime scheduledAt,
    required DoseEvent? previousEvent,
  }) {
    final id = _occurrenceId(memberId, medicineId, scheduledAt);
    final current = _doseEvents.where((event) => event.id == id).firstOrNull;

    // Restore stock if undoing a taken dose
    if (current?.status == DoseStatus.taken &&
        previousEvent?.status != DoseStatus.taken) {
      final medicine = medicineById(memberId, medicineId);
      if (medicine != null && medicine.currentStock != null) {
        final amount =
            (double.tryParse(medicine.doseAmount.split(' ').first) ?? 1.0)
                .toInt()
                .clamp(1, 99);
        final list = _medicines[memberId];
        if (list != null) {
          final medIndex = list.indexWhere((m) => m.id == medicine.id);
          if (medIndex >= 0) {
            list[medIndex] = list[medIndex].copyWith(
              currentStock: medicine.currentStock! + amount,
            );
          }
        }
      }
    }

    _doseEvents.removeWhere((event) => event.id == id);
    if (previousEvent != null) _doseEvents.add(previousEvent);
    _changed();
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
        day = DateTime(day.year, day.month, day.day + 1);
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
        final calendarDays = DateTime.utc(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
        return calendarDays % 2 == 0;
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
