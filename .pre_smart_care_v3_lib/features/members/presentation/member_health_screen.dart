import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import 'adherence_screen.dart';
import '../../medications/presentation/treatment_screen.dart';

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
    final historyFrom = today.subtract(const Duration(days: 29));
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
    final historyDone = takenCount + missedCount;
    final historyScore = historyDone == 0 ? null : takenCount / historyDone;
    final initial = memberName.trim().isEmpty
        ? '?'
        : memberName.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member health'),
        actions: [
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
                    backgroundColor: AppTheme.teal,
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
                          memberName,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$relationship · Family care',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9EFEC)),
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
                            backgroundColor: Color(0xFFE7EEEB),
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
                        const Text(
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
            const Text(
              'Medicines and today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (medicines.isEmpty)
              const Card(
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${medicine.medicineDosage} ${medicine.medicineForm.toLowerCase()} · ${medicine.doseAmount} per dose · ${medicine.frequency}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                          Text(
                            '${medicine.foodInstruction} · ${_date(medicine.startDate)}${medicine.endDate == null ? ' · no end date' : ' to ${_date(medicine.endDate!)}'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 7),
            if (todayDoses.isEmpty)
              const Card(
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
                            ? const Color(0xFFB45A4A)
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
            const SizedBox(height: 22),
            const Text(
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
              subtitle: 'Caregiver information',
              onTap: () => _showUnavailable(context),
            ),
            const SizedBox(height: 18),
            const Center(
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
  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _status(OccurrenceStatus status) => switch (status) {
    OccurrenceStatus.taken => 'Taken',
    OccurrenceStatus.missed => 'Missed',
    OccurrenceStatus.upcoming => 'Upcoming',
    OccurrenceStatus.overdue => 'Overdue · unrecorded',
  };

  void _showUnavailable(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caregiver sharing is not available in this app version.',
          ),
        ),
      );
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFEC)),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 7),
              GestureDetector(
                onTap: onTap,
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
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
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9EFEC)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    ),
  );
}
