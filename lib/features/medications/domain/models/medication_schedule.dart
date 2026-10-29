class MedicationSchedule {
  final String id;
  final String foodInstruction;
  final String medicineName;
  final String medicineDosage;
  final String medicineForm;
  final String frequency;
  final String doseAmount;
  final String instructions;
  final DateTime startDate;
  final DateTime? endDate;
  final List<MedicationDoseTime> doseTimes;
  final int? currentStock;
  final int? refillAlertThreshold;

  const MedicationSchedule({
    this.id = '',
    required this.medicineName,
    required this.medicineDosage,
    required this.frequency,
    this.foodInstruction = 'No food instruction',
    this.doseAmount = '1',
    this.medicineForm = 'Tablet',
    this.instructions = '',
    required this.startDate,
    this.endDate,
    required this.doseTimes,
    this.currentStock,
    this.refillAlertThreshold,
  });

  bool get hasStockTracking => currentStock != null;

  bool get isLowStock =>
      currentStock != null &&
      refillAlertThreshold != null &&
      currentStock! <= refillAlertThreshold!;

  MedicationSchedule copyWith({
    String? id,
    String? medicineName,
    String? medicineDosage,
    String? frequency,
    String? foodInstruction,
    String? doseAmount,
    String? medicineForm,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    List<MedicationDoseTime>? doseTimes,
    int? currentStock,
    int? refillAlertThreshold,
  }) => MedicationSchedule(
    id: id ?? this.id,
    medicineName: medicineName ?? this.medicineName,
    medicineDosage: medicineDosage ?? this.medicineDosage,
    frequency: frequency ?? this.frequency,
    foodInstruction: foodInstruction ?? this.foodInstruction,
    doseAmount: doseAmount ?? this.doseAmount,
    medicineForm: medicineForm ?? this.medicineForm,
    instructions: instructions ?? this.instructions,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    doseTimes: doseTimes ?? this.doseTimes,
    currentStock: currentStock ?? this.currentStock,
    refillAlertThreshold: refillAlertThreshold ?? this.refillAlertThreshold,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'medicineName': medicineName,
    'medicineDosage': medicineDosage,
    'frequency': frequency,
    'foodInstruction': foodInstruction,
    'doseAmount': doseAmount,
    'medicineForm': medicineForm,
    'instructions': instructions,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'doseTimes': doseTimes.map((time) => time.toJson()).toList(),
    'currentStock': currentStock,
    'refillAlertThreshold': refillAlertThreshold,
  };

  static List<MedicationDoseTime> normalizeDoseTimes(
    String frequency,
    List<MedicationDoseTime> times,
  ) {
    final expectedCount = switch (frequency) {
      'Twice daily' => 2,
      'Three times daily' => 3,
      'Four times daily' => 4,
      'As needed' => 0,
      _ => 1,
    };
    if (expectedCount == 0) return const [];

    final uniqueTimes = <MedicationDoseTime>[];
    final seen = <int>{};
    for (final t in times) {
      if (t.hour >= 0 && t.hour < 24 && t.minute >= 0 && t.minute < 60) {
        final key = t.hour * 60 + t.minute;
        if (seen.add(key)) {
          uniqueTimes.add(t);
        }
      }
    }

    if (uniqueTimes.length == expectedCount) {
      uniqueTimes.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return uniqueTimes;
    }

    const defaultTimes = [
      MedicationDoseTime(hour: 9, minute: 0),
      MedicationDoseTime(hour: 13, minute: 0),
      MedicationDoseTime(hour: 17, minute: 0),
      MedicationDoseTime(hour: 21, minute: 0),
    ];

    if (uniqueTimes.length > expectedCount) {
      uniqueTimes.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return uniqueTimes.sublist(0, expectedCount);
    }

    final result = List<MedicationDoseTime>.from(uniqueTimes);
    for (final def in defaultTimes) {
      if (result.length >= expectedCount) break;
      final key = def.hour * 60 + def.minute;
      if (seen.add(key)) {
        result.add(def);
      }
    }

    while (result.length < expectedCount) {
      final lastHour = result.isEmpty ? 9 : (result.last.hour + 4) % 24;
      result.add(MedicationDoseTime(hour: lastHour, minute: 0));
    }

    result.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
    return result;
  }

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    final name = (json['medicineName'] ?? json['name']) as String? ?? '';
    final startDateStr =
        json['startDate'] ??
        json['start_date'] ??
        (json['schedule'] is Map ? json['schedule']['start_date'] : null);
    final startDate = DateTime.tryParse(startDateStr as String? ?? '');
    if (name.trim().isEmpty || startDate == null) {
      throw const FormatException('Invalid medication schedule.');
    }
    final endDateStr =
        json['endDate'] ??
        json['end_date'] ??
        (json['schedule'] is Map ? json['schedule']['end_date'] : null);
    final parsedEnd = endDateStr is String
        ? DateTime.tryParse(endDateStr)
        : null;
    if (endDateStr != null && parsedEnd == null) {
      throw const FormatException('Invalid treatment end date.');
    }
    final stableId = json['id'] as String?;
    final frequency =
        (json['frequency'] ??
                (json['schedule'] is Map
                    ? json['schedule']['frequency']
                    : null))
            as String? ??
        'Once daily';
    final rawTimes =
        json['doseTimes'] ??
        json['dose_times'] ??
        (json['schedule'] is Map ? json['schedule']['dose_times'] : null);

    final parsedTimes = <MedicationDoseTime>[];
    if (rawTimes is List) {
      for (final item in rawTimes) {
        if (item is Map) {
          final time = MedicationDoseTime.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (time.hour >= 0 &&
              time.hour < 24 &&
              time.minute >= 0 &&
              time.minute < 60) {
            parsedTimes.add(time);
          }
        }
      }
    }

    final normalizedTimes = normalizeDoseTimes(frequency, parsedTimes);

    return MedicationSchedule(
      id: stableId?.isNotEmpty == true
          ? stableId!
          : 'legacy_${name.toLowerCase()}_${startDate.millisecondsSinceEpoch}',
      medicineName: name,
      medicineDosage:
          (json['medicineDosage'] ?? json['dosage']) as String? ?? '',
      frequency: frequency,
      foodInstruction:
          (json['foodInstruction'] ?? json['food_instruction']) as String? ??
          'No food instruction',
      doseAmount: (json['doseAmount'] ?? json['dose_amount']) as String? ?? '',
      medicineForm:
          (json['medicineForm'] ?? json['form']) as String? ?? 'Other',
      instructions: json['instructions'] as String? ?? '',
      startDate: startDate,
      endDate: parsedEnd,
      doseTimes: normalizedTimes,
      currentStock: (json['currentStock'] as num?)?.toInt(),
      refillAlertThreshold: (json['refillAlertThreshold'] as num?)?.toInt(),
    );
  }
}

class MedicationDoseTime {
  final int hour;
  final int minute;

  const MedicationDoseTime({required this.hour, required this.minute});

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory MedicationDoseTime.fromJson(Map<String, dynamic> json) =>
      MedicationDoseTime(
        hour: (json['hour'] as num?)?.toInt() ?? -1,
        minute: (json['minute'] as num?)?.toInt() ?? -1,
      );
}
