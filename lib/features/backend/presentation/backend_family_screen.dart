import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../onboarding/presentation/welcome_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../medications/domain/models/medication_schedule.dart';

class BackendFamilyScreen extends StatefulWidget {
  const BackendFamilyScreen({super.key});
  @override
  State<BackendFamilyScreen> createState() => _BackendFamilyScreenState();
}

class _BackendFamilyScreenState extends State<BackendFamilyScreen> {
  static const _frequencies = <String, int>{
    'Once daily': 1,
    'Twice daily': 2,
    'Three times daily': 3,
    'Four times daily': 4,
    'Every other day': 1,
    'Weekly': 1,
  };
  final _api = ApiClient();
  bool _loading = true, _busy = false;
  bool _sessionExpired = false;
  String? _error, _familyId;
  List<dynamic> _families = [], _members = [];
  Map<String, List<dynamic>> _medicines = {}, _occurrences = {};
  final DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _date =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessionExpired = false;
    });
    try {
      final families = await _api.get('/families') as List<dynamic>;
      var familyId = _familyId;
      if (familyId == null || !families.any((f) => f['id'] == familyId)) {
        familyId = families.isEmpty ? null : families.first['id'] as String;
      }
      final members = familyId == null
          ? <dynamic>[]
          : await _api.get('/families/$familyId/members') as List<dynamic>;
      final medicines = <String, List<dynamic>>{},
          occurrences = <String, List<dynamic>>{};
      for (final member in members) {
        final id = member['id'] as String;
        medicines[id] =
            await _api.get('/members/$id/medicines') as List<dynamic>;
        occurrences[id] =
            await _api.get(
                  '/members/$id/occurrences?from_date=$_date&through_date=$_date',
                )
                as List<dynamic>;
      }
      if (!mounted) return;
      final reminderPlans = _reminderPlansFor(members, medicines);
      setState(() {
        _families = families;
        _familyId = familyId;
        _members = members;
        _medicines = medicines;
        _occurrences = occurrences;
      });
      await ReminderService.instance.synchronize(reminderPlans);
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _sessionExpired = e is ApiException && e.statusCode == 401;
        });
        if (e is ApiException && e.statusCode == 401) {
          await ReminderService.instance.synchronize(const []);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ReminderPlan> _reminderPlansFor(
    List<dynamic> members,
    Map<String, List<dynamic>> medicinesByMember,
  ) {
    final plans = <ReminderPlan>[];
    for (final member in members) {
      for (final medicine in medicinesByMember[member['id']] ?? const []) {
        if (medicine is! Map || medicine['schedule'] is! Map) continue;
        final schedule = medicine['schedule'] as Map;
        final startDate = DateTime.tryParse(
          schedule['start_date'] as String? ?? '',
        );
        if (startDate == null) continue;
        plans.add(
          ReminderPlan(
            memberId: member['id'] as String,
            medicineId: medicine['id'] as String,
            name: medicine['name'] as String? ?? 'Medicine',
            dosage: medicine['dosage'] as String? ?? '',
            amount: medicine['dose_amount'] as String? ?? '',
            frequency: schedule['frequency'] as String? ?? '',
            startDate: startDate,
            endDate: DateTime.tryParse(schedule['end_date'] as String? ?? ''),
            times: (schedule['dose_times'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (time) => MedicationDoseTime(
                    hour: (time['hour'] as num?)?.toInt() ?? -1,
                    minute: (time['minute'] as num?)?.toInt() ?? -1,
                  ),
                )
                .where(
                  (time) =>
                      time.hour >= 0 &&
                      time.hour < 24 &&
                      time.minute >= 0 &&
                      time.minute < 60,
                )
                .toList(),
          ),
        );
      }
    }
    return plans;
  }

  Future<void> _createFamily() async {
    final name = await _ask('Family name');
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      final result =
          await _api.post('/families', {'name': name.trim()})
              as Map<String, dynamic>;
      _familyId = result['id'] as String;
      await _load();
    });
  }

  Future<void> _addMember() async {
    final name = await _ask('Member name');
    if (name == null || name.trim().isEmpty || _familyId == null) return;
    final relation =
        await _ask('Relationship (for example, Parent)') ?? 'Family member';
    await _run(() async {
      await _api.post('/families/$_familyId/members', {
        'name': name.trim(),
        'relationship_label': relation.trim().isEmpty
            ? 'Family member'
            : relation.trim(),
      });
      await _load();
    });
  }

  Future<void> _addMedicine(Map member) async {
    final name = await _ask('Medicine name');
    if (name == null || name.trim().isEmpty) return;
    final dosage = await _ask('Dosage as prescribed (for example, 500 mg)');
    if (dosage == null || dosage.trim().isEmpty) return;
    final amount = await _ask('Dose amount (for example, 1 tablet)');
    if (amount == null || amount.trim().isEmpty) return;
    if (!mounted) return;
    final frequency = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Schedule frequency'),
        children: _frequencies.keys
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item),
              ),
            )
            .toList(),
      ),
    );
    if (frequency == null || !mounted) return;
    final defaultZone =
        DateTime.now().timeZoneOffset == const Duration(minutes: 330)
        ? 'Asia/Kolkata'
        : 'UTC';
    final zone = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Schedule time zone'),
        children: [
          for (final item in const ['Asia/Kolkata', 'UTC'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Row(
                children: [
                  Expanded(child: Text(item)),
                  if (item == defaultZone)
                    const Icon(Icons.check_circle_outline_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (zone == null || !mounted) return;
    final times = <TimeOfDay>[];
    const defaults = [8, 12, 18, 21];
    for (var index = 0; index < _frequencies[frequency]!; index++) {
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: defaults[index], minute: 0),
        helpText: 'Select dose time ${index + 1}',
      );
      if (selected == null || !mounted) return;
      if (times.any(
        (time) => time.hour == selected.hour && time.minute == selected.minute,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dose times must be different. Start again to choose another time.',
            ),
          ),
        );
        return;
      }
      times.add(selected);
    }
    final form = await _ask('Form (tablet, capsule, liquid…)') ?? 'Tablet';
    if (!mounted) return;
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _run(() async {
      await _api.post('/members/${member['id']}/medicines', {
        'name': name.trim(),
        'dosage': dosage.trim(),
        'form': form.trim().isEmpty ? 'Tablet' : form.trim(),
        'dose_amount': amount.trim(),
        'food_instruction': 'No food instruction',
        'instructions': '',
        'schedule': {
          'frequency': frequency,
          'start_date': today,
          'dose_times': times
              .map((time) => {'hour': time.hour, 'minute': time.minute})
              .toList(),
          'time_zone': zone,
        },
      });
      await _load();
    });
  }

  Future<void> _record(Map occurrence, String status) async {
    await _run(() async {
      final endpoint = '/occurrences/${occurrence['id']}/events';
      final payload = {'status': status};
      if (occurrence['event_id'] == null) {
        await _api.post(endpoint, payload);
      } else {
        await _api.put(endpoint, payload);
      }
      await _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _sessionExpired = e is ApiException && e.statusCode == 401;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title) async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    return value;
  }

  Future<void> _logout() async {
    await _api.clearToken();
    await ReminderService.instance.synchronize(const []);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Connected care'),
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_outlined),
        ),
        IconButton(
          tooltip: 'Refresh server data',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Backend family space',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Live records from the authenticated FastAPI service.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_error!),
                    ),
                  ),
                  if (_sessionExpired)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                              (_) => false,
                            ),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Return to sign in'),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                if (_families.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _familyId,
                    decoration: const InputDecoration(
                      labelText: 'Selected family',
                    ),
                    items: _families
                        .map(
                          (f) => DropdownMenuItem(
                            value: f['id'] as String,
                            child: Text(f['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() {
                              _familyId = v;
                              _members = [];
                              _medicines = {};
                              _occurrences = {};
                            });
                            _load();
                          },
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _createFamily,
                      icon: const Icon(Icons.add_home_rounded),
                      label: const Text('New family'),
                    ),
                    if (_familyId != null)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _addMember,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add member'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_families.isEmpty)
                  _empty(
                    'Create your first backend family',
                    'This account has no family records yet. Create one to begin.',
                  ),
                if (_familyId != null && _members.isEmpty)
                  _empty(
                    'Add a family member',
                    'Members and plans are stored on the connected server.',
                  ),
                for (final member in _members) _memberCard(member),
                const SizedBox(height: 18),
                Text(
                  'Backend storage is active for this screen. Existing local demo records have not been uploaded or merged.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
  );

  Widget _empty(String title, String subtitle) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
  Widget _memberCard(Map member) {
    final id = member['id'] as String;
    final medicines = _medicines[id] ?? [];
    final doses = (_occurrences[id] ?? []).cast<Map>();
    doses.sort(
      (a, b) =>
          (a['scheduled_at'] as String).compareTo(b['scheduled_at'] as String),
    );
    final taken = doses.where((d) => d['status'] == 'taken').length;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    (member['name'] as String).substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['name'] as String,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(member['relationship_label'] as String),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add medicine',
                  onPressed: _busy ? null : () => _addMedicine(member),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${medicines.length} treatment plans · $taken of ${doses.length} doses taken today',
            ),
            for (final medicine in medicines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.medication_outlined),
                title: Text(medicine['name'] as String),
                subtitle: Text(
                  '${medicine['dosage']} · ${medicine['schedule']['frequency']}${_formatBackendDoseTimes(medicine['schedule']?['dose_times'])}',
                ),
                dense: true,
              ),
            if (doses.isNotEmpty) const Divider(),
            for (final dose in doses) _doseTile(dose),
          ],
        ),
      ),
    );
  }

  String _formatBackendDoseTimes(Object? raw) {
    if (raw is! List || raw.isEmpty) return '';
    final times = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final hour = (item['hour'] as num?)?.toInt() ?? 0;
        final minute = (item['minute'] as num?)?.toInt() ?? 0;
        final h = hour % 12 == 0 ? 12 : hour % 12;
        final period = hour >= 12 ? 'PM' : 'AM';
        times.add('$h:${minute.toString().padLeft(2, '0')} $period');
      }
    }
    return times.isEmpty ? '' : ' · ${times.join(', ')}';
  }

  Widget _doseTile(Map dose) {
    final time = DateTime.tryParse(dose['scheduled_at'] as String)?.toLocal();
    final status = dose['status'] as String;
    final label = status == 'taken'
        ? 'Taken'
        : status == 'missed'
        ? 'Missed'
        : status == 'overdue'
        ? 'Overdue'
        : 'Upcoming';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status == 'taken'
            ? Icons.check_circle
            : status == 'missed' || status == 'overdue'
            ? Icons.warning_amber_rounded
            : Icons.schedule,
      ),
      title: Text(
        '${time == null ? 'Dose' : TimeOfDay.fromDateTime(time).format(context)} · ${dose['medicine_name']}',
      ),
      subtitle: Text('${dose['member_name']} · $label'),
      trailing:
          (status == 'taken' ||
              status == 'missed' ||
              status == 'overdue' ||
              (status == 'pending' && !(time?.isAfter(DateTime.now()) ?? true)))
          ? PopupMenuButton<String>(
              tooltip: status == 'taken' || status == 'missed'
                  ? 'Correct dose record'
                  : 'Record dose',
              onSelected: (v) => _record(dose, v),
              itemBuilder: (_) => [
                if (status != 'taken')
                  const PopupMenuItem(value: 'taken', child: Text('Taken')),
                if (status != 'missed')
                  const PopupMenuItem(value: 'missed', child: Text('Missed')),
              ],
            )
          : null,
    );
  }
}
