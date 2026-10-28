import 'package:flutter/material.dart';

import '../domain/models/medication_schedule.dart';

class MedicationScheduleScreen extends StatefulWidget {
  final String medicineName;
  final String medicineDosage;
  final String medicineForm;

  const MedicationScheduleScreen({
    super.key,

    required this.medicineName,
    required this.medicineDosage,
    required this.medicineForm,
  });
  @override
  State<MedicationScheduleScreen> createState() =>
      _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _instructionsController = TextEditingController();
  final _doseAmountController = TextEditingController();

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
          _doseTimes.add(defaultTimes[_doseTimes.length]);
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
      id: DateTime.now().microsecondsSinceEpoch.toString(),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medication schedule')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Set the schedule',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose how often this medicine should be taken and when the dose is normally due.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey.shade700,
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

              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF2E7D6F),
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
                  leading: const Icon(
                    Icons.event_outlined,
                    color: Color(0xFF2E7D6F),
                  ),
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
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF2E7D6F),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This medicine is taken only when needed. '
                            'No fixed dose time will be scheduled.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey.shade700,
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
                        leading: const Icon(
                          Icons.access_time,
                          color: Color(0xFF2E7D6F),
                        ),
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
