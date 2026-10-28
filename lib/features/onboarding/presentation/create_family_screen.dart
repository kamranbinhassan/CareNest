import 'add_family_member_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/data/care_session.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    CareSession.instance.createFamily(name: _familyNameController.text);
    await CareSession.instance.flush();
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your family')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),

              const Text(
                'Create your family space',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 10),

              Text(
                'This is the shared space where you can manage treatment and health information for your family.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              TextFormField(
                controller: _familyNameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Family name',
                  hintText: 'e.g. Hassan Family',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a family name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _continue,
                  child: const Text(
                    'Continue',
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
