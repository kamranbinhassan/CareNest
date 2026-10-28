import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/presentation/member_health_screen.dart';
import '../../onboarding/presentation/add_family_member_screen.dart';
import '../../medications/presentation/treatment_screen.dart';

class FamilyHomeScreen extends StatelessWidget {
  const FamilyHomeScreen({super.key});

  Future<void> _addMember(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddFamilyMemberScreen(returnToCaller: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CareSession.instance,
      builder: (context, _) => _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    final session = CareSession.instance;
    final members = session.members;
    final hasMember = members.isNotEmpty;
    final today = DateTime.now();
    final greeting = today.hour < 12
        ? 'Good morning'
        : today.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final dateLabel =
        '${_weekday(today.weekday)}, ${_month(today.month)} ${today.day}';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.paleTeal,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: AppTheme.teal,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Text('CareNest'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications are not enabled in this demo.'),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              dateLabel.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$greeting, ${session.ownerName.isEmpty ? 'there' : session.ownerName}',
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'A little care goes a long way.',
              style: TextStyle(fontSize: 14, color: AppTheme.muted),
            ),
            const SizedBox(height: 22),
            _CareCard(hasMember: hasMember, familyName: session.familyName),
            if (!session.persistenceAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Local storage is unavailable. Current changes will last only until the app closes.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                ),
              ),
            const SizedBox(height: 24),
            const _SectionTitle(
              title: 'Care overview',
              trailing: 'Current plans',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.medication_outlined,
                    label: 'Medicines',
                    value: '${session.medicineCount}',
                    caption: 'Medicines in care plans',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: _MetricCard(
                    icon: Icons.fact_check_outlined,
                    label: 'Adherence',
                    value: '—',
                    caption: 'No dose history',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _SectionTitle(
              title: 'Your family',
              trailing: hasMember
                  ? '${members.length} ${members.length == 1 ? 'member' : 'members'}'
                  : 'Get started',
            ),
            const SizedBox(height: 12),
            if (hasMember)
              ...members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _MemberTile(
                    name: member.name,
                    relationship: member.relationship,
                    medicineCount: session.medicinesFor(member.id).length,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberHealthScreen(
                          memberId: member.id,
                          memberName: member.name,
                          relationship: member.relationship,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              _EmptyFamilyCard(onAdd: () => _addMember(context)),
            const SizedBox(height: 23),
            const _SectionTitle(title: 'Quick actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add member',
                    onTap: () => _addMember(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_moderator_rounded,
                    label: 'Add medicine',
                    onTap: hasMember
                        ? () => _openTreatment(context, members)
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Add a family member before creating a medicine plan.',
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Your family’s health information stays in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTreatment(
    BuildContext context,
    List<FamilyMember> members,
  ) async {
    FamilyMember? selected;
    if (members.length == 1) {
      selected = members.single;
    } else {
      selected = await showModalBottomSheet<FamilyMember>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Choose a family member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ...members.map(
                (member) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(member.name),
                  subtitle: Text(member.relationship),
                  onTap: () => Navigator.pop(context, member),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (selected != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TreatmentScreen(memberId: selected!.id),
        ),
      );
    }
  }

  static String _weekday(int n) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][n - 1];
  static String _month(int n) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][n - 1];
}

class _CareCard extends StatelessWidget {
  final bool hasMember;
  final String familyName;
  const _CareCard({required this.hasMember, required this.familyName});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF176B5B), Color(0xFF105347)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                hasMember ? 'CARE SPACE' : 'WELCOME',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Text(
          hasMember
              ? 'Care for ${familyName.isEmpty ? 'your family' : familyName}'
              : 'Start your family health space',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          hasMember
              ? 'Your overview will update as you add care plans.'
              : 'Bring medicines, schedules and daily care together.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.white.withValues(alpha: .82),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.ink,
        ),
      ),
      const Spacer(),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label, value, caption;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFE9EFEC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.teal, size: 21),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            height: 1,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    ),
  );
}

class _EmptyFamilyCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFamilyCard({required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9EFEC)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.paleTeal,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.groups_2_outlined, color: AppTheme.teal),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No members yet',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Add someone to begin their care plan.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onAdd,
          tooltip: 'Add member',
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.teal,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}

class _MemberTile extends StatelessWidget {
  final String name, relationship;
  final int medicineCount;
  final VoidCallback onTap;
  const _MemberTile({
    required this.name,
    required this.relationship,
    required this.medicineCount,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9EFEC)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.paleTeal,
              child: Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$relationship · $medicineCount ${medicineCount == 1 ? 'medicine' : 'medicines'}',
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE9EFEC)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.teal, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
