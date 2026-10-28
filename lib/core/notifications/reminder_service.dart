import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/medications/domain/models/medication_schedule.dart';

@immutable
class ReminderPlan {
  const ReminderPlan({
    required this.memberId,
    required this.medicineId,
    required this.name,
    required this.dosage,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.times,
    this.endDate,
  });

  final String memberId;
  final String medicineId;
  final String name;
  final String dosage;
  final String amount;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final List<MedicationDoseTime> times;

  Map<String, Object?> toJson() => {
    'memberId': memberId,
    'medicineId': medicineId,
    'name': name,
    'dosage': dosage,
    'amount': amount,
    'frequency': frequency,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'times': times.map((time) => time.toJson()).toList(),
  };

  factory ReminderPlan.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startDate'] as String? ?? '');
    if (start == null) {
      throw const FormatException('Invalid reminder start date.');
    }
    final end = DateTime.tryParse(json['endDate'] as String? ?? '');
    return ReminderPlan(
      memberId: json['memberId'] as String? ?? '',
      medicineId: json['medicineId'] as String? ?? '',
      name: json['name'] as String? ?? 'Medicine',
      dosage: json['dosage'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      startDate: start,
      endDate: end,
      times: MedicationSchedule.normalizeDoseTimes(
        json['frequency'] as String? ?? '',
        (json['times'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (time) => MedicationDoseTime.fromJson(
                Map<String, dynamic>.from(time),
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

  Iterable<DateTime> upcoming({required DateTime now, int days = 21}) sync* {
    if (times.isEmpty || frequency == 'As needed') return;
    final today = DateTime(now.year, now.month, now.day);
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      if (day.isBefore(
            DateTime(startDate.year, startDate.month, startDate.day),
          ) ||
          (endDate != null &&
              day.isAfter(
                DateTime(endDate!.year, endDate!.month, endDate!.day),
              )) ||
          !_occursOn(day)) {
        continue;
      }
      final seenTimes = <String>{};
      for (final time in times) {
        if (!seenTimes.add('${time.hour}:${time.minute}')) continue;
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        // DateTime normalizes nonexistent wall times forward during a DST
        // jump. Skip those entries to match the backend occurrence rules.
        if (at.hour != time.hour || at.minute != time.minute) continue;
        if (at.isAfter(now)) yield at;
      }
    }
  }

  bool _occursOn(DateTime day) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final difference = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    switch (frequency) {
      case 'Every other day':
        return difference >= 0 && difference.isEven;
      case 'Weekly':
        return day.weekday == start.weekday;
      default:
        return true;
    }
  }
}

@immutable
class ReminderEntry {
  const ReminderEntry(this.plan, this.at);
  final ReminderPlan plan;
  final DateTime at;
}

class ReminderService extends ChangeNotifier {
  ReminderService._();
  static final instance = ReminderService._();
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'medicine_reminders_enabled_v1';
  static const _plansKey = 'medicine_reminder_plans_v1';
  static final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool enabled = false;
  bool? permissionGranted;
  bool scheduleLimitReached = false;
  String? error;
  List<ReminderPlan> _plans = const [];
  Future<void> _scheduleQueue = Future<void>.value();
  int _scheduleGeneration = 0;
  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Keep timezone's default if the platform cannot report a zone.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onNotificationTap?.call(response.payload),
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    enabled = (await _storage.read(key: _enabledKey)) == 'true';
    try {
      final rawPlans = await _storage.read(key: _plansKey);
      final decoded = rawPlans == null ? null : jsonDecode(rawPlans);
      if (decoded is List) {
        _plans = List.unmodifiable(
          decoded
              .whereType<Map>()
              .map(
                (item) =>
                    ReminderPlan.fromJson(Map<String, dynamic>.from(item)),
              ),
        );
      }
    } catch (_) {
      _plans = const [];
    }
    _initialized = true;
    await refreshPermission();
    if (!enabled) {
      await _plugin.cancelAll();
    } else {
      await synchronize(_plans);
    }
    notifyListeners();
    if (launchDetails?.didNotificationLaunchApp == true) {
      onNotificationTap?.call(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<void> refreshPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      permissionGranted = await android?.areNotificationsEnabled();
    } catch (_) {
      // In test environments or unsupported platforms, keep null / false.
    }
    notifyListeners();
  }

  Future<void> refreshForDeviceTimeChange() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Retain the last valid IANA zone if the platform lookup fails.
    }
    await synchronize(_plans);
  }

  Future<bool> enable() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final requested = await android?.requestNotificationsPermission();
    permissionGranted = requested ?? await android?.areNotificationsEnabled();
    if (permissionGranted != true) {
      enabled = false;
      await _storage.write(key: _enabledKey, value: 'false');
      await _plugin.cancelAll();
      notifyListeners();
      return false;
    }
    enabled = true;
    await _storage.write(key: _enabledKey, value: 'true');
    await synchronize(_plans);
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    _scheduleGeneration++;
    enabled = false;
    await _storage.write(key: _enabledKey, value: 'false');
    await _scheduleQueue;
    await _plugin.cancelAll();
    error = null;
    notifyListeners();
  }

  Future<void> synchronize(List<ReminderPlan> plans) async {
    if (!_initialized) await initialize();
    final snapshot = List<ReminderPlan>.unmodifiable(plans);
    _plans = snapshot;
    final generation = ++_scheduleGeneration;
    final operation = _scheduleQueue.then(
      (_) => _replaceSchedule(snapshot, generation),
    );
    _scheduleQueue = operation.catchError((Object _) {});
    await operation;
  }

  Future<void> _replaceSchedule(
    List<ReminderPlan> plans,
    int generation,
  ) async {
    scheduleLimitReached = false;
    try {
      await _storage.write(
        key: _plansKey,
        value: jsonEncode(plans.map((plan) => plan.toJson()).toList()),
      );
    } catch (_) {
      // Scheduling still proceeds; secure storage persistence is best effort.
    }
    if (generation != _scheduleGeneration ||
        !enabled ||
        permissionGranted == false) {
      await _plugin.cancelAll();
      return;
    }
    try {
      // Replacing the bounded rolling window prevents duplicates and removes
      // notifications for deleted or edited plans.
      await _plugin.cancelAll();
      final now = DateTime.now();
      final entries = [
        for (final plan in plans)
          for (final at in plan.upcoming(now: now)) ReminderEntry(plan, at),
      ]..sort((a, b) => a.at.compareTo(b.at));
      scheduleLimitReached = entries.length > 450;
      // Android vendors may limit the number of outstanding AlarmManager alarms.
      for (final entry in entries.take(450)) {
        if (generation != _scheduleGeneration || !enabled) break;
        final plan = entry.plan;
        final scheduledAt = entry.at;
        final local = tz.TZDateTime.from(scheduledAt, tz.local);
        await _plugin.zonedSchedule(
          _stableId(
            '${plan.memberId}|${plan.medicineId}|${scheduledAt.toIso8601String()}',
          ),
          'Time for your medicine',
          "It's time for ${plan.name} (${plan.amount}${plan.dosage.isEmpty ? '' : ' · ${plan.dosage}'}). Open the app to review your schedule.",
          local,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medicine_reminders',
              'Medicine reminders',
              channelDescription:
                  'Scheduled reminders for prescribed medicine doses.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'memberId': plan.memberId,
            'medicineId': plan.medicineId,
          }),
        );
      }
      if (generation != _scheduleGeneration || !enabled) {
        await _plugin.cancelAll();
      }
      error = null;
    } catch (e) {
      await _plugin.cancelAll();
      scheduleLimitReached = false;
      error =
          'Could not update medicine reminders. Check notification permission in Android settings.';
    }
    notifyListeners();
  }

  Future<void> sendTestNotification() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final requested = await android?.requestNotificationsPermission();
    permissionGranted = requested ?? await android?.areNotificationsEnabled();
    if (permissionGranted != true) {
      throw StateError(
        'Allow notifications in Android settings to send a test.',
      );
    }
    await _plugin.show(
      0,
      'Medicine reminders are ready',
      'This is a test notification from your reminder settings.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine reminders',
          channelDescription:
              'Scheduled reminders for prescribed medicine doses.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  List<DateTime> get upcomingTimes {
    return upcomingPlans.map((item) => item.at).toList();
  }

  List<ReminderEntry> get upcomingPlans {
    final now = DateTime.now();
    final result = [
      for (final plan in _plans)
        for (final at in plan.upcoming(now: now, days: 7))
          ReminderEntry(plan, at),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
