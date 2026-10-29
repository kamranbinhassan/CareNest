import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/models/medication_schedule.dart';

class MedicationScheduleScreen extends StatefulWidget {
  final String medicineName;
  final String medicineDosage;
  final String medicineForm;
  final MedicationSchedule? initialSchedule;

  const MedicationScheduleScreen({
    super.key,
    required this.medicineName,
    required this.medicineDosage,
    required this.medicineForm,
    this.initialSchedule,
  });

  static String? inferFrequency(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('four times') ||
        lower.contains('4 times') ||
        lower.contains('4x') ||
        lower.contains('qid')) {
      return 'Four times daily';
    }
    if (lower.contains('three times') ||
        lower.contains('3 times') ||
        lower.contains('3x') ||
        lower.contains('tid')) {
      return 'Three times daily';
    }
    if (lower.contains('twice') ||
        lower.contains('2 times') ||
        lower.contains('2x') ||
        lower.contains('bid')) {
      return 'Twice daily';
    }
    if (lower.contains('every other day') || lower.contains('qod')) {
      return 'Every other day';
    }
    if (lower.contains('weekly')) {
      return 'Weekly';
    }
    if (lower.contains('as needed') || lower.contains('prn')) {
      return 'As needed';
    }
    return null;
  }

  @override
  State<MedicationScheduleScreen> createState() =>
      _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _instructionsController = TextEditingController();
  final _doseAmountController = TextEditingController();
  final _stockController = TextEditingController();
  final _refillController = TextEditingController();

  String _frequency = 'Once daily';
  String _foodInstruction = 'No food instruction';
  final List<String> _foodInstructions = [
    'No food instruction',
    'Before food',
    'After food',
    'With food',
    'Empty stomach',
  ];

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  final List<TimeOfDay> _doseTimes = [const TimeOfDay(hour: 9, minute: 0)];

  @override
  void initState() {
    super.initState();
    if (widget.initialSchedule != null) {
      final initial = widget.initialSchedule!;
      _frequency = initial.frequency;
      _foodInstruction = initial.foodInstruction;
      _instructionsController.text = initial.instructions;
      _doseAmountController.text = initial.doseAmount;
      if (initial.currentStock != null) {
        _stockController.text = initial.currentStock.toString();
      }
      if (initial.refillAlertThreshold != null) {
        _refillController.text = initial.refillAlertThreshold.toString();
      }
      _startDate = initial.startDate;
      _endDate = initial.endDate;
      _doseTimes.clear();
      _doseTimes.addAll(
        initial.doseTimes.map(
          (time) => TimeOfDay(hour: time.hour, minute: time.minute),
        ),
      );
      if (_doseTimes.isEmpty && _frequency != 'As needed') {
        _updateDoseTimes(_frequency);
      }
    } else {
      final inferred = MedicationScheduleScreen.inferFrequency(
        widget.medicineDosage,
      );
      if (inferred != null && _frequencies.contains(inferred)) {
        _frequency = inferred;
        _updateDoseTimes(inferred);
      }
    }
  }

  void _updateDoseTimes(String frequency) {
    int count;

    switch (frequency) {
      case 'Twice daily':
        count = 2;
        break;
      case 'Three times daily':
        count = 3;
        break;
      case 'Four times daily':
        count = 4;
        break;
      case 'As needed':
        count = 0;
        break;
      default:
        count = 1;
    }

    setState(() {
      _frequency = frequency;

      final defaultTimes = [
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 13, minute: 0),
        const TimeOfDay(hour: 17, minute: 0),
        const TimeOfDay(hour: 21, minute: 0),
      ];
      if (_doseTimes.length < count) {
        while (_doseTimes.length < count) {
          TimeOfDay? candidate;
          for (final dt in defaultTimes) {
            if (!_doseTimes.any(
              (t) => t.hour == dt.hour && t.minute == dt.minute,
            )) {
              candidate = dt;
              break;
            }
          }
          candidate ??= TimeOfDay(
            hour: (_doseTimes.last.hour + 4) % 24,
            minute: 0,
          );
          _doseTimes.add(candidate);
        }
      } else if (_doseTimes.length > count) {
        _doseTimes.removeRange(count, _doseTimes.length);
      }
    });
  }

  final List<String> _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'Every other day',
    'Weekly',
    'As needed',
  ];

  Future<void> _selectTime(int index) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _doseTimes[index],
    );

    if (selectedTime != null && mounted) {
      setState(() {
        _doseTimes[index] = selectedTime;
      });
    }
  }

  String? _getDuplicateDoseTime() {
    final seen = <String>{};

    for (final time in _doseTimes) {
      final key = '${time.hour}:${time.minute}';

      if (!seen.add(key)) {
        final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
        final period = time.hour >= 12 ? 'PM' : 'AM';
        final minute = time.minute.toString().padLeft(2, '0');

        return '$hour:$minute $period';
      }
    }

    return null;
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate = isStartDate ? _startDate : (_endDate ?? _startDate);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime(2100),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;

          if (_endDate != null && _endDate!.isBefore(selectedDate)) {
            _endDate = null;
          }
        } else {
          _endDate = selectedDate;
        }
      });
    }
  }

  void _saveSchedule() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final duplicateTime = _getDuplicateDoseTime();

    if (duplicateTime != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Two doses are scheduled at $duplicateTime.')),
      );
      return;
    }

    final doseAmount = _doseAmountController.text.trim();
    final instructions = _instructionsController.text.trim();

    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before the start date.'),
        ),
      );
      return;
    }

    final sortedDoseTimes = List<TimeOfDay>.from(_doseTimes)
      ..sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });

    final schedule = MedicationSchedule(
      id: widget.initialSchedule?.id.isNotEmpty == true
          ? widget.initialSchedule!.id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      medicineName: widget.medicineName,
      medicineDosage: widget.medicineDosage,
      frequency: _frequency,
      foodInstruction: _foodInstruction,
      doseAmount: doseAmount,
      medicineForm: widget.medicineForm,
      instructions: instructions,
      startDate: _startDate,
      endDate: _endDate,
      doseTimes: sortedDoseTimes
          .map(
            (time) => MedicationDoseTime(hour: time.hour, minute: time.minute),
          )
          .toList(),
      currentStock: int.tryParse(_stockController.text.trim()),
      refillAlertThreshold: int.tryParse(_refillController.text.trim()),
    );

    setState(() => _isSaving = true);
    Navigator.of(context).pop(schedule);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _doseAmountController.dispose();
    _stockController.dispose();
    _refillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialSchedule != null
              ? 'Edit medication schedule'
              : 'Medication schedule',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.initialSchedule != null
                    ? 'Update schedule'
                    : 'Set the schedule',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose how often this medicine should be taken and when each dose is normally due.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),

                items: _frequencies.map((frequency) {
                  return DropdownMenuItem(
                    value: frequency,
                    child: Text(frequency),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _updateDoseTimes(value);
                  }
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                initialValue: _foodInstruction,
                decoration: const InputDecoration(
                  labelText: 'Food instructions',
                  border: OutlineInputBorder(),
                ),
                items: _foodInstructions.map((instruction) {
                  return DropdownMenuItem(
                    value: instruction,
                    child: Text(instruction),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _foodInstruction = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _instructionsController,
                maxLines: 3,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Treatment instructions',
                  hintText: 'Add any special instructions for this medicine',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _doseAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the dose amount';
                  }

                  final dose = double.tryParse(value.trim());

                  if (dose == null || dose <= 0) {
                    return 'Enter a valid dose amount';
                  }

                  return null;
                },

                decoration: const InputDecoration(
                  labelText: 'Dose amount',
                  hintText: 'e.g. 1',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock (Optional)',
                        hintText: 'e.g. 30',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _refillController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Refill Alert At',
                        hintText: 'e.g. 5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    color: AppTheme.teal,
                  ),
                  title: const Text(
                    'Start date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDate(isStartDate: true),
                ),
              ),

              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(Icons.event_outlined, color: AppTheme.teal),
                  title: const Text(
                    'End date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _endDate == null
                          ? 'No end date'
                          : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDate(isStartDate: false),
                ),
              ),

              const SizedBox(height: 20),

              if (_doseTimes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This medicine is taken only when needed. '
                            'No fixed dose time will be scheduled.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(
                    _doseTimes.length,
                    (index) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(Icons.access_time, color: AppTheme.teal),
                        title: Text(
                          'Dose ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_formatTime(_doseTimes[index])),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectTime(index),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveSchedule,
                  child: const Text(
                    'Save schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
