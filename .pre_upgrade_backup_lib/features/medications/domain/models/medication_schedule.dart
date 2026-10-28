
class MedicationSchedule {

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

Map<String, dynamic> toJson() {
  return {
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
  }

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {

return MedicationSchedule(
  medicineName: json['medicineName'] as String,
  medicineDosage: json['medicineDosage'] as String,
  frequency: json['frequency'] as String,
      foodInstruction: json['foodInstruction'] as String,
      doseAmount: json['doseAmount'] as String,
      
medicineForm: json['medicineForm'] as String,
instructions: json['instructions'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      doseTimes: (json['doseTimes'] as List<dynamic>)
          .map(
            (time) => MedicationDoseTime.fromJson(time as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class MedicationDoseTime {
  final int hour;
  final int minute;

  const MedicationDoseTime({required this.hour, required this.minute});

  Map<String, dynamic> toJson() {
    return {'hour': hour, 'minute': minute};
  }

  factory MedicationDoseTime.fromJson(Map<String, dynamic> json) {
    return MedicationDoseTime(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }
}
