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

  const MedicationSchedule({
    this.id = '',
    required this.medicineName,
    required this.medicineDosage,
    required this.frequency,
    required this.foodInstruction,
    required this.doseAmount,
    required this.medicineForm,
    required this.instructions,
    required this.startDate,
    this.endDate,
    required this.doseTimes,
  });

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
  };

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    final name = json['medicineName'] as String? ?? '';
    final startDate = DateTime.tryParse(json['startDate'] as String? ?? '');
    if (name.trim().isEmpty || startDate == null) {
      throw const FormatException('Invalid medication schedule.');
    }
    final parsedEnd = json['endDate'] is String
        ? DateTime.tryParse(json['endDate'] as String)
        : null;
    if (json['endDate'] != null && parsedEnd == null) {
      throw const FormatException('Invalid treatment end date.');
    }
    final stableId = json['id'] as String?;
    return MedicationSchedule(
      id: stableId?.isNotEmpty == true
          ? stableId!
          : 'legacy_${name.toLowerCase()}_${startDate.millisecondsSinceEpoch}',
      medicineName: name,
      medicineDosage: json['medicineDosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'Once daily',
      foodInstruction:
          json['foodInstruction'] as String? ?? 'No food instruction',
      doseAmount: json['doseAmount'] as String? ?? '',
      medicineForm: json['medicineForm'] as String? ?? 'Other',
      instructions: json['instructions'] as String? ?? '',
      startDate: startDate,
      endDate: parsedEnd,
      doseTimes: (json['doseTimes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MedicationDoseTime.fromJson)
          .where(
            (time) =>
                time.hour >= 0 &&
                time.hour < 24 &&
                time.minute >= 0 &&
                time.minute < 60,
          )
          .toList(),
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
