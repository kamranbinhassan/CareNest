import 'package:flutter/material.dart';

import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/models/medication_schedule.dart';
import 'add_medicine_screen.dart';

class TreatmentScreen extends StatelessWidget {
  final String memberId;

  const TreatmentScreen({super.key, required this.memberId});

  Future<void> _addMedicine(BuildContext context) async {
    final result = await Navigator.of(context).push<MedicationSchedule>(
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (result != null && memberId.isNotEmpty) {
      CareSession.instance.addMedicine(memberId, result);
      await CareSession.instance.flush();
      if (!context.mounted) return;
      _showStorageFailure(context);
    }
  }

  Future<void> _deleteMedicine(
    BuildContext context,
    MedicationSchedule medicine,
    int index,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove medicine?'),
        content: Text(
          'Remove ${medicine.medicineName} from this treatment plan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      CareSession.instance.removeMedicine(memberId, index);
      await CareSession.instance.flush();
      if (!context.mounted) return;
      _showStorageFailure(context);
    }
  }

  void _showStorageFailure(BuildContext context) {
    if (!CareSession.instance.persistenceAvailable && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This change is available for this session only; it was not saved on the device.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CareSession.instance,
    builder: (context, _) {
      final medicines = CareSession.instance.medicinesFor(memberId);
      return Scaffold(
        appBar: AppBar(title: const Text('Treatment')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Text(
                'Treatment plan',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage medicines and treatment instructions for this member.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              if (medicines.isEmpty)
                _EmptyTreatment(onAdd: () => _addMedicine(context))
              else ...[
                ...medicines.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _MedicineCard(
                      medicine: entry.value,
                      onDelete: () =>
                          _deleteMedicine(context, entry.value, entry.key),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () => _addMedicine(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add another medicine'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _EmptyTreatment extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTreatment({required this.onAdd});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.medication_outlined, size: 30, color: AppTheme.teal),
          const SizedBox(height: 16),
          const Text(
            'Your treatment plan is empty',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a medicine and its schedule to keep treatment details together.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add medicine'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MedicineCard extends StatelessWidget {
  final MedicationSchedule medicine;
  final VoidCallback onDelete;
  const _MedicineCard({required this.medicine, required this.onDelete});

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _time(MedicationDoseTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 15, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.paleTeal,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppTheme.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.medicineName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medicine.medicineDosage} ${medicine.medicineForm.toLowerCase()} · ${medicine.frequency}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove medicine',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Dose ${medicine.doseAmount} · ${medicine.foodInstruction}',
            style: const TextStyle(fontSize: 13, color: AppTheme.ink),
          ),
          const SizedBox(height: 5),
          Text(
            'From ${_date(medicine.startDate)}${medicine.endDate == null ? '' : ' to ${_date(medicine.endDate!)}'}',
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          if (medicine.doseTimes.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Dose times: ${medicine.doseTimes.map(_time).join(', ')}',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
          if (medicine.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              medicine.instructions,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    ),
  );
}
