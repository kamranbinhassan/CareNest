import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../medications/domain/models/medication_schedule.dart';
import 'adherence_screen.dart';
import '../../medications/presentation/treatment_screen.dart';
import '../../support/presentation/care_support_screen.dart';

class MemberHealthScreen extends StatelessWidget {
  final String memberId;
  final String memberName;
  final String relationship;
  const MemberHealthScreen({
    super.key,
    required this.memberId,
    this.memberName = 'Family member',
    this.relationship = 'Family member',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CareSession.instance,
      builder: (context, _) => _buildScreen(context),
    );
  }

  Future<void> _showEditMemberDialog(
    BuildContext context,
    String currentName,
    String currentRelationship,
  ) async {
    final nameController = TextEditingController(text: currentName);
    String selectedRelationship = currentRelationship;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Member Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Name cannot be empty'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      [
                        'Myself',
                        'Parent',
                        'Grandparent',
                        'Spouse',
                        'Child',
                        'Sibling',
                        'Other',
                      ].contains(selectedRelationship)
                      ? selectedRelationship
                      : 'Other',
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Myself', child: Text('Myself')),
                    DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                    DropdownMenuItem(
                      value: 'Grandparent',
                      child: Text('Grandparent'),
                    ),
                    DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                    DropdownMenuItem(value: 'Child', child: Text('Child')),
                    DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRelationship = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  CareSession.instance.updateMember(
                    memberId: memberId,
                    name: nameController.text.trim(),
                    relationship: selectedRelationship,
                  );
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await CareSession.instance.flush();
    }
  }

  Future<void> _confirmRemoveMember(BuildContext context) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove family member?'),
        content: Text(
          'Remove $memberName and their medicine schedules and dose history from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep member'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (shouldRemove == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      CareSession.instance.removeMember(memberId);
      await CareSession.instance.flush();
      if (!context.mounted) return;
      navigator.pop();
      if (!CareSession.instance.persistenceAvailable) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              CareSession.instance.storageError ??
                  'Member removal could not be saved.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildScreen(BuildContext context) {
    final session = CareSession.instance;
    final medicines = session.medicinesFor(memberId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDoses = session.occurrencesFor(
      memberId: memberId,
      from: today,
      through: today,
      now: now,
    );
    final historyFrom = DateTime(today.year, today.month, today.day - 29);
    final recentEvents =
        session.doseEvents.where((event) => event.memberId == memberId).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final history = session.occurrencesFor(
      memberId: memberId,
      from: historyFrom,
      through: today,
      now: now,
    );
    final takenCount = history
        .where((dose) => dose.status == OccurrenceStatus.taken)
        .length;
    final missedCount = history
        .where((dose) => dose.status == OccurrenceStatus.missed)
        .length;
    final memberItem = session.members
        .where((m) => m.id == memberId)
        .firstOrNull;
    final currentMemberName = memberItem?.name ?? memberName;
    final currentRelationship = memberItem?.relationship ?? relationship;

    final historyDone = takenCount + missedCount;
    final historyScore = historyDone == 0 ? null : takenCount / historyDone;
    final initial = currentMemberName.trim().isEmpty
        ? '?'
        : currentMemberName.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member health'),
        actions: [
          IconButton(
            tooltip: 'Edit member profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditMemberDialog(
              context,
              currentMemberName,
              currentRelationship,
            ),
          ),
          IconButton(
            tooltip: 'Remove family member',
            onPressed: () => _confirmRemoveMember(context),
            icon: const Icon(Icons.person_remove_alt_1_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.paleTeal,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.accentFill,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentMemberName,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$currentRelationship · Family care',
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_user_outlined, color: AppTheme.teal),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Treatment overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              icon: Icons.medication_outlined,
              title: 'Medication schedule',
              description: medicines.isEmpty
                  ? 'No medicines added yet'
                  : '${medicines.length} ${medicines.length == 1 ? 'medicine' : 'medicines'} in the treatment plan',
              action: 'Set up treatment',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreatmentScreen(memberId: memberId),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 65,
                          height: 65,
                          child: CircularProgressIndicator(
                            value: historyScore,
                            strokeWidth: 6,
                            backgroundColor: AppTheme.outline,
                            valueColor: AlwaysStoppedAnimation(AppTheme.teal),
                          ),
                        ),
                        Text(
                          historyScore == null
                              ? '—'
                              : '${(historyScore * 100).round()}%',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adherence overview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          historyScore == null
                              ? 'No completed doses in the last 30 days.'
                              : '$takenCount taken · $missedCount missed in the last 30 days.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Medicines and today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (medicines.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No medicines in this member’s plan yet.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ),
              )
            else
              ...medicines.map(
                (medicine) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.medicineName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${medicine.medicineDosage} ${medicine.medicineForm.toLowerCase()} · ${medicine.doseAmount} per dose · ${medicine.frequency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                          Text(
                            '${medicine.foodInstruction} · ${_date(medicine.startDate)}${medicine.endDate == null ? ' · no end date' : ' to ${_date(medicine.endDate!)}'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                          if (medicine.doseTimes.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Dose times: ${medicine.doseTimes.map(_formatDoseTime).join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.teal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 7),
            if (todayDoses.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'No scheduled doses today.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ),
              )
            else
              ...todayDoses.map(
                (dose) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Card(
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        dose.status == OccurrenceStatus.taken
                            ? Icons.check_circle_rounded
                            : dose.status == OccurrenceStatus.missed
                            ? Icons.event_busy_rounded
                            : dose.status == OccurrenceStatus.overdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        color: dose.status == OccurrenceStatus.taken
                            ? AppTheme.teal
                            : dose.status == OccurrenceStatus.missed ||
                                  dose.status == OccurrenceStatus.overdue
                            ? AppTheme.statusError
                            : AppTheme.muted,
                      ),
                      title: Text(
                        '${_time(dose.scheduledAt)} · ${dose.medicine.medicineName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        _status(dose.status),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 15),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      todayDoses.any(
                            (dose) => dose.status == OccurrenceStatus.overdue,
                          )
                          ? Icons.warning_amber_rounded
                          : Icons.lightbulb_outline_rounded,
                      color:
                          todayDoses.any(
                            (dose) => dose.status == OccurrenceStatus.overdue,
                          )
                          ? AppTheme.statusWarning
                          : AppTheme.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Member insight',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            todayDoses.any(
                                  (dose) =>
                                      dose.status == OccurrenceStatus.overdue,
                                )
                                ? '${todayDoses.where((dose) => dose.status == OccurrenceStatus.overdue).length} scheduled dose(s) are overdue without a recorded action.'
                                : historyScore == null
                                ? 'No completed scheduled doses are recorded for this member in the last 30 days.'
                                : '$takenCount of $historyDone recorded scheduled doses were taken in the last 30 days.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Recent dose history',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 9),
            if (recentEvents.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'No dose actions recorded for this member yet.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ),
              )
            else
              ...recentEvents
                  .take(8)
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            event.status == DoseStatus.taken
                                ? Icons.check_circle_rounded
                                : Icons.event_busy_rounded,
                            color: event.status == DoseStatus.taken
                                ? AppTheme.teal
                                : AppTheme.statusError,
                          ),
                          title: Text(
                            '${event.medicineName} · ${event.status == DoseStatus.taken ? 'Taken' : 'Missed'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Scheduled ${_time(event.scheduledAt)} · action saved ${_dateTime(event.recordedAt)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 22),
            Text(
              'Health & support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            _SectionTile(
              icon: Icons.medication_rounded,
              title: 'Treatment',
              subtitle: 'Medicines and schedules',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreatmentScreen(memberId: memberId),
                ),
              ),
            ),
            const SizedBox(height: 9),
            _SectionTile(
              icon: Icons.insights_rounded,
              title: 'Adherence',
              subtitle: 'Recorded dose history',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdherenceScreen(memberId: memberId),
                ),
              ),
            ),
            const SizedBox(height: 9),
            _SectionTile(
              icon: Icons.support_agent_rounded,
              title: 'Care & support',
              subtitle: 'Troubleshooting & help guides',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CareSupportScreen()),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Health information is only shown when it has been added.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _dateTime(DateTime date) => '${_date(date)} ${_time(date)}';

  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDoseTime(MedicationDoseTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _status(OccurrenceStatus status) => switch (status) {
    OccurrenceStatus.taken => 'Taken',
    OccurrenceStatus.missed => 'Missed',
    OccurrenceStatus.upcoming => 'Upcoming',
    OccurrenceStatus.overdue => 'Overdue · unrecorded',
  };
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title, description, action;
  final VoidCallback onTap;
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.outline),
    ),
    child: Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: AppTheme.paleTeal,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.teal),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 7),
              GestureDetector(
                onTap: onTap,
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
      ],
    ),
  );
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.paleTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppTheme.teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    ),
  );
}
