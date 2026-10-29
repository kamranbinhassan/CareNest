import 'package:flutter/material.dart';

import '../../../core/data/care_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/presentation/family_home_screen.dart';
import 'add_family_member_screen.dart';

enum OnboardingCareMode { myself, family }

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _spaceNameController;
  OnboardingCareMode _selectedMode = OnboardingCareMode.myself;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final owner = CareSession.instance.ownerName.trim();
    final defaultName = owner.isNotEmpty
        ? '$owner’s Care Space'
        : 'Family Care Space';
    _spaceNameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _spaceNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final spaceName = _spaceNameController.text.trim();
    CareSession.instance.createFamily(name: spaceName);

    if (_selectedMode == OnboardingCareMode.myself) {
      // Create or select the owner's personal profile (no duplicate creation)
      final ownerMember = CareSession.instance.getOrCreateOwnerMember(
        name: CareSession.instance.ownerName,
      );
      CareSession.instance.setActiveMember(ownerMember.id);
      await CareSession.instance.flush();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FamilyHomeScreen()),
        (route) => false,
      );
    } else {
      await CareSession.instance.flush();
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup your space')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Text(
                'Welcome to CareNest',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Whether you’re managing personal prescriptions or coordinating treatment for loved ones, CareNest adapts to your needs.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),

              TextFormField(
                controller: _spaceNameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Space or Family Name',
                  hintText: 'e.g. Hassan Family Care',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for this space';
                  }
                  if (value.trim().length > 60) {
                    return 'Name cannot exceed 60 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 26),

              Text(
                'Who will you be managing?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You can always add more people or switch anytime.',
                style: TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 14),

              // Option 1: Myself
              _buildChoiceCard(
                mode: OnboardingCareMode.myself,
                icon: Icons.person_rounded,
                title: 'Myself',
                badge: 'Personal Routine',
                subtitle:
                    'Manage my own medicine schedules, daily doses, and adherence alarms.',
              ),

              const SizedBox(height: 12),

              // Option 2: Manage Family
              _buildChoiceCard(
                mode: OnboardingCareMode.family,
                icon: Icons.groups_rounded,
                title: 'Manage Family',
                badge: 'Caregiver Space',
                subtitle:
                    'Coordinate prescriptions and check-ins for parents, children, or relatives.',
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _continue,
                  child: Text(
                    _selectedMode == OnboardingCareMode.myself
                        ? 'Go to My Dashboard'
                        : 'Continue to Add Members',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required OnboardingCareMode mode,
    required IconData icon,
    required String title,
    required String badge,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == mode;
    return Material(
      color: isSelected
          ? AppTheme.teal.withValues(alpha: 0.08)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppTheme.teal : AppTheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.teal : AppTheme.paleTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.teal.withValues(alpha: 0.15)
                                : AppTheme.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.teal
                                  : AppTheme.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.teal : AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
