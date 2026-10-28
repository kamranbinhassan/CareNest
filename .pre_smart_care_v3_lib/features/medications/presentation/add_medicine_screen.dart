import 'medication_schedule_screen.dart';
import 'package:flutter/material.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();

  String _form = 'Tablet';
  bool _isSaving = false;

  final List<String> _forms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Drops',
    'Cream',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _saveMedicine() {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => MedicationScheduleScreen(
              medicineName: _nameController.text.trim(),
              medicineDosage: _dosageController.text.trim(),
              medicineForm: _form,
            ),
          ),
        )
        .then((schedule) {
          if (!mounted) return;
          if (schedule != null) {
            Navigator.of(context).pop(schedule);
          } else {
            setState(() => _isSaving = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add medicine')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Add medicine',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter the basic details of the medicine. Treatment instructions can be added next.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Medicine name',
                  hintText: 'e.g. Paracetamol',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the medicine name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _dosageController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Strength / dosage',
                  hintText: 'e.g. 500 mg',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the dosage';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _form,
                decoration: const InputDecoration(
                  labelText: 'Medicine form',
                  border: OutlineInputBorder(),
                ),
                items: _forms.map((form) {
                  return DropdownMenuItem(value: form, child: Text(form));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _form = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveMedicine,
                  child: const Text(
                    'Save medicine',
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
