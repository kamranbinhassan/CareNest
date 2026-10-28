import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/models/medication_schedule.dart';

class MedicationDetailScreen extends StatelessWidget {
  final String memberId;
  final String medicineId;
  final String memberName;

  const MedicationDetailScreen({
    super.key,
    required this.memberId,
    required this.medicineId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CareSession.instance,
    builder: (context, _) {
      final session = CareSession.instance;
      final medicine = session.medicineById(memberId, medicineId);
      if (medicine == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Medicine details')),
          body: const Center(
            child: Text('This medicine is no longer in the treatment plan.'),
          ),
        );
      }
      final history =
          session.doseEvents
              .where(
                (event) =>
                    event.memberId == memberId &&
                    event.medicineId == medicineId,
              )
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text('Medicine details'),
          actions: [
            IconButton(
              tooltip: 'Remove medicine',
              onPressed: () =>
                  _remove(context, medicineName: medicine.medicineName),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF187462), Color(0xFF105347)],
                  ),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.medicineName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'For $memberName · ${medicine.medicineDosage}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .84),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              _section('Treatment details', [
                _detail('Medicine form', medicine.medicineForm),
                _detail('Dose amount', medicine.doseAmount),
                _detail('Frequency', medicine.frequency),
                _detail('Food instructions', medicine.foodInstruction),
                _detail(
                  'Treatment dates',
                  '${_date(medicine.startDate)} — ${medicine.endDate == null ? 'Ongoing' : _date(medicine.endDate!)}',
                ),
                _detail(
                  'Dose times',
                  medicine.doseTimes.isEmpty
                      ? 'As needed · no fixed times'
                      : medicine.doseTimes.map(_time).join(' · '),
                ),
                if (medicine.instructions.trim().isNotEmpty)
                  _detail('Instructions', medicine.instructions),
              ]),
              const SizedBox(height: 17),
              const Text(
                'Dose history',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 9),
              if (history.isEmpty)
                _panel(
                  const Text(
                    'No doses have been recorded for this medicine.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                )
              else
                ...history.take(50).map((event) {
                  final isTaken = event.status == DoseStatus.taken;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _panel(
                      Row(
                        children: [
                          Icon(
                            isTaken
                                ? Icons.check_circle_rounded
                                : Icons.event_busy_rounded,
                            color: isTaken
                                ? AppTheme.teal
                                : const Color(0xFFB45A4A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${isTaken ? 'Taken' : 'Missed'} · scheduled ${_dateTime(event.scheduledAt)}\nRecorded ${_dateTime(event.recordedAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              const Text(
                'This plan displays information entered by the caregiver. It does not provide prescribing advice.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _remove(
    BuildContext context, {
    required String medicineName,
  }) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove medicine?'),
        content: Text(
          'Remove $medicineName from $memberName’s active treatment plan? Recorded dose history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove plan'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    CareSession.instance.removeMedicine(memberId, medicineId);
    await CareSession.instance.flush();
    if (!context.mounted) return;
    navigator.pop();
    if (!CareSession.instance.persistenceAvailable) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            CareSession.instance.storageError ??
                'Medicine removal could not be saved.',
          ),
        ),
      );
    }
  }

  Widget _section(String title, List<Widget> children) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFE6ECE9)),
    ),
    child: child,
  );
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _time(MedicationDoseTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dateTime(DateTime date) =>
      '${_date(date)} ${_time(MedicationDoseTime(hour: date.hour, minute: date.minute))}';
}
