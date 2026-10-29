import 'package:flutter/material.dart';

import '../../../core/data/care_session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/presentation/member_health_screen.dart';
import '../../onboarding/presentation/add_family_member_screen.dart';
import '../../onboarding/presentation/login_screen.dart';
import '../../support/presentation/care_support_screen.dart';

class ProfileView extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const ProfileView({super.key, this.onNavigateToTab});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  CareSession get session => CareSession.instance;
  bool? _hasCloudToken;

  @override
  void initState() {
    super.initState();
    _checkCloud();
  }

  Future<void> _checkCloud() async {
    final token = await ApiClient().hasToken;
    if (mounted) setState(() => _hasCloudToken = token);
  }

  void _showRenameFamilyDialog() {
    final controller = TextEditingController(text: session.familyName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Family Space'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Family Space Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                session.setFamily(name: newName, owner: session.ownerName);
                await session.flush();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          content,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final caregiverName = session.ownerName.trim().isNotEmpty
            ? session.ownerName.trim()
            : 'Family Caregiver';
        final initial = caregiverName.isNotEmpty
            ? caregiverName[0].toUpperCase()
            : 'C';

        final membersCount = session.members.length;
        final medicineCount = session.medicineCount;
        final historyCount = session.doseEvents.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Me & Care Space'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 84),
              children: [
                // Profile Header Card
                _buildCaregiverCard(
                  caregiverName,
                  initial,
                  membersCount,
                  medicineCount,
                  historyCount,
                ),
                const SizedBox(height: 20),

                // Family space management
                _buildSectionHeader('Family Care Space', Icons.groups_rounded),
                const SizedBox(height: 10),
                _buildFamilyManagementCard(),
                const SizedBox(height: 22),

                // Account & Cloud status
                _buildSectionHeader('Account & Cloud', Icons.shield_outlined),
                const SizedBox(height: 10),
                _buildAccountCard(),
                const SizedBox(height: 22),

                // Future-ready roadmap (clearly framed)
                _buildSectionHeader(
                  'CareNest Roadmap & Labs',
                  Icons.rocket_launch_outlined,
                ),
                const SizedBox(height: 10),
                _buildRoadmapCard(),
                const SizedBox(height: 22),

                // Help & About
                _buildSectionHeader(
                  'Support & Principles',
                  Icons.help_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildSupportCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverCard(
    String caregiverName,
    String initial,
    int membersCount,
    int medicineCount,
    int historyCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF187462), Color(0xFF104F45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF187462).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.familyName.isNotEmpty
                          ? '${session.familyName} Space'
                          : 'Family Care Space',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat('$membersCount', 'Members'),
                _buildHeaderStat('$medicineCount', 'Medicines'),
                _buildHeaderStat('$historyCount', 'Logged Doses'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyManagementCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.teal),
            title: const Text(
              'Add Family Member',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Add a parent, child, or dependent to organize their medicines.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const AddFamilyMemberScreen(returnToCaller: true),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.edit_note_rounded, color: AppTheme.teal),
            title: const Text(
              'Rename Care Space',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              'Currently: "${session.familyName.isNotEmpty ? session.familyName : 'Family'}"',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showRenameFamilyDialog,
          ),
          if (session.members.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.badge_outlined, color: AppTheme.teal),
              title: const Text(
                'View Member Health Profiles',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                '${session.members.length} members in your family care plan.',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final first = session.members.first;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberHealthScreen(
                      memberId: first.id,
                      memberName: first.name,
                      relationship: first.relationship,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final isConnected = _hasCloudToken == true;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.offline_pin_rounded,
                  color: isConnected ? AppTheme.teal : AppTheme.muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'CareNest Account Active'
                        : 'Offline Device Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isConnected
                  ? 'Your family data synchronizes with your configured CareNest server.'
                  : 'You are currently using local storage. Sign in if you want to sync with a remote family server.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (isConnected)
              OutlinedButton.icon(
                onPressed: () async {
                  await ApiClient().clearToken();
                  await _checkCloud();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out of cloud account.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Disconnect Account'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  _checkCloud();
                },
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Connect Cloud Account'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.paleTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FUTURE ARCHITECTURE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'The following capabilities are in design phase for upcoming CareNest releases:',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _buildRoadmapTile(
              'Adherence Rescue',
              'Escalating follow-up reminders after an unconfirmed dose.',
              'Planned',
            ),
            _buildRoadmapTile(
              'Caregiver Escalation',
              'Consent-based SMS/alert notification if critical doses remain missed.',
              'In Design',
            ),
            _buildRoadmapTile(
              'Smart Refill & Stock Alerts',
              'Proactive pill counting and refill alerts before prescriptions run low.',
              'Planned',
            ),
            _buildRoadmapTile(
              'Doctor-Ready Clinical PDF',
              'Export formal compliance charts formatted for physician reviews.',
              'Coming Soon',
            ),
            _buildRoadmapTile(
              'AI Health Assistant',
              'Safety-bounded guidance for medicine schedules. No medical diagnosis.',
              'In Design',
            ),
            _buildRoadmapTile(
              'Cycle & Women’s Health',
              'Optional, strictly privacy-preserving cycle and symptom tracking.',
              'Planned',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapTile(String title, String desc, String badge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.radio_button_unchecked_rounded,
            size: 16,
            color: AppTheme.teal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.outline.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.support_agent_rounded, color: AppTheme.teal),
            title: const Text(
              'Help Guides & Diagnostics',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Troubleshooting, alarm setup & diagnostics report',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CareSupportScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: AppTheme.teal),
            title: const Text(
              'About CareNest',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Family-centered medicine adherence companion',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfoDialog(
              'About CareNest',
              'CareNest is a modern family healthcare application designed to keep track of daily prescriptions, scheduled dose times, and adherence consistency across all family members without tracking or ads.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: AppTheme.teal),
            title: const Text(
              'Privacy Principles',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Zero telemetry · Strict on-device encryption',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfoDialog(
              'Privacy Principles',
              'CareNest operates under a strict privacy-first architecture. Medical schedules, family member names, and dose events are encrypted locally. Data is never shared or uploaded to third-party ad networks.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.help_center_outlined, color: AppTheme.teal),
            title: const Text(
              'Scheduling & Offline Help',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'How multiple dose times and alarms work',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showInfoDialog(
              'Scheduling & Offline Help',
              'When you configure a medicine as Twice daily, Three times daily, or Four times daily, CareNest schedules distinct exact notification times for each dose. Alarms run through your device’s native alarm manager and work completely offline.',
            ),
          ),
        ],
      ),
    );
  }
}
