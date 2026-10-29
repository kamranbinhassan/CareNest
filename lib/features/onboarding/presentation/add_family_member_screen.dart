import '../../family/presentation/family_home_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  final bool returnToCaller;
  const AddFamilyMemberScreen({super.key, this.returnToCaller = false});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _relationship = 'Parent';
  bool _isSaving = false;

  final List<String> _relationships = [
    'Myself',
    'Parent',
    'Grandparent',
    'Spouse',
    'Child',
    'Sibling',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _skipToDashboard() async {
    CareSession.instance.getOrCreateOwnerMember();
    await CareSession.instance.flush();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FamilyHomeScreen()),
      (route) => false,
    );
  }

  Future<void> _addMember() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final member = CareSession.instance.addMember(
      name: _nameController.text,
      relationship: _relationship,
    );
    CareSession.instance.setActiveMember(member.id);
    await CareSession.instance.flush();
    if (!mounted) return;
    if (widget.returnToCaller) {
      Navigator.of(context).pop(member);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FamilyHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add family member'),
        actions: [
          if (!widget.returnToCaller)
            TextButton(onPressed: _skipToDashboard, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),

              const Text(
                'Who are you managing?',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 10),

              Text(
                'Start with the people whose treatment or health information you want to manage.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Member name',
                  hintText: 'e.g. Abdul Hassan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the member name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
                items: _relationships.map((relationship) {
                  return DropdownMenuItem(
                    value: relationship,
                    child: Text(relationship),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _relationship = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _addMember,
                  child: const Text(
                    'Add member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              if (!widget.returnToCaller) ...[
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _skipToDashboard,
                    child: const Text(
                      'Skip for now and go to dashboard',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
