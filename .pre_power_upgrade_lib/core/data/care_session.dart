import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/medications/domain/models/medication_schedule.dart';

enum DoseStatus { taken, missed }

class DoseEvent {
  final String id;
  final String memberId;
  final String medicineName;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime recordedAt;

  const DoseEvent({
    required this.id,
    required this.memberId,
    required this.medicineName,
    required this.scheduledAt,
    required this.status,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'memberId': memberId,
    'medicineName': medicineName,
    'scheduledAt': scheduledAt.toIso8601String(),
    'status': status.name,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory DoseEvent.fromJson(Map<String, dynamic> json) => DoseEvent(
    id: json['id'] as String,
    memberId: json['memberId'] as String,
    medicineName: json['medicineName'] as String,
    scheduledAt: DateTime.parse(json['scheduledAt'] as String),
    status: DoseStatus.values.firstWhere(
      (value) => value.name == json['status'],
    ),
    recordedAt: DateTime.parse(json['recordedAt'] as String),
  );
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
    id: json['id'] as String,
    name: json['name'] as String,
    relationship: json['relationship'] as String,
  );
}

/// Local family and treatment data shared by every screen in this app.
/// Writes are serialized so quick consecutive edits cannot overwrite newer data.
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

  List<FamilyMember> get members => List.unmodifiable(_members);

  List<MedicationSchedule> medicinesFor(String memberId) =>
      List.unmodifiable(_medicines[memberId] ?? const []);

  List<DoseEvent> get doseEvents => List.unmodifiable(_doseEvents);

  int get medicineCount =>
      _medicines.values.fold(0, (sum, items) => sum + items.length);

  Future<void> flush() => _writeQueue;

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        familyName = data['familyName'] as String? ?? '';
        ownerName = data['ownerName'] as String? ?? '';
        _members
          ..clear()
          ..addAll(
            (data['members'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map((item) => FamilyMember.fromJson(item)),
          );
        _medicines
          ..clear()
          ..addEntries(
            (data['medicines'] as Map<String, dynamic>? ?? const {}).entries
                .map(
                  (entry) => MapEntry(
                    entry.key,
                    (entry.value as List<dynamic>)
                        .whereType<Map<String, dynamic>>()
                        .map((item) => MedicationSchedule.fromJson(item))
                        .toList(),
                  ),
                ),
          );
        _doseEvents
          ..clear()
          ..addAll(
            (data['doseEvents'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(DoseEvent.fromJson),
          );
      }
      persistenceAvailable = true;
    } catch (_) {
      familyName = '';
      ownerName = '';
      _members.clear();
      _medicines.clear();
      _doseEvents.clear();
      persistenceAvailable = false;
    }
    notifyListeners();
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

  void addMedicine(String memberId, MedicationSchedule medicine) {
    if (!_members.any((member) => member.id == memberId)) return;
    (_medicines[memberId] ??= []).add(medicine);
    _changed();
  }

  void recordDose({
    required String memberId,
    required MedicationSchedule medicine,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) {
    final id =
        '${memberId}_${medicine.medicineName}_${scheduledAt.toIso8601String()}';
    _doseEvents.removeWhere((event) => event.id == id);
    _doseEvents.add(
      DoseEvent(
        id: id,
        memberId: memberId,
        medicineName: medicine.medicineName,
        scheduledAt: scheduledAt,
        status: status,
        recordedAt: DateTime.now(),
      ),
    );
    _changed();
  }

  DoseEvent? doseEventFor(
    String memberId,
    String medicineName,
    DateTime scheduledAt,
  ) {
    final id = '${memberId}_${medicineName}_${scheduledAt.toIso8601String()}';
    for (final event in _doseEvents) {
      if (event.id == id) return event;
    }
    return null;
  }

  void removeMedicine(String memberId, int index) {
    final medicines = _medicines[memberId];
    if (medicines == null || index < 0 || index >= medicines.length) return;
    medicines.removeAt(index);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storage.write(key: _storageKey, value: jsonEncode(_toJson()));
        final wasAvailable = persistenceAvailable;
        persistenceAvailable = true;
        if (!wasAvailable) notifyListeners();
      } catch (_) {
        final wasAvailable = persistenceAvailable;
        persistenceAvailable = false;
        if (wasAvailable) notifyListeners();
      }
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
