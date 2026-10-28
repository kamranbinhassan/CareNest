import 'package:flutter/material.dart';
import 'dart:async';
import 'core/data/care_session.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance_controller.dart';
import 'core/network/api_client.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/family/presentation/family_home_screen.dart';
import 'features/backend/presentation/backend_family_screen.dart';
import 'core/notifications/reminder_service.dart';
import 'features/settings/presentation/reminder_settings_screen.dart';

bool _hasBackendSession = false;
final _navigatorKey = GlobalKey<NavigatorState>();
String? _pendingReminderPayload;
bool _pendingReminderNavigation = false;

void _openReminderCenter(String? payload) {
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    _pendingReminderNavigation = true;
    _pendingReminderPayload = payload;
    return;
  }
  navigator.push(
    MaterialPageRoute(builder: (_) => const ReminderSettingsScreen()),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CareSession.instance.load();
  await AppearanceController.instance.load();
  _hasBackendSession = await ApiClient().hasToken;
  ReminderService.instance.onNotificationTap = _openReminderCenter;
  await ReminderService.instance.initialize();
  CareSession.instance.addListener(() {
    unawaited(
      ReminderService.instance.synchronize(CareSession.instance.reminderPlans),
    );
  });
  if (!_hasBackendSession) {
    await ReminderService.instance.synchronize(
      CareSession.instance.reminderPlans,
    );
  }
  runApp(const MedicineAdherenceApp());
}

class MedicineAdherenceApp extends StatefulWidget {
  const MedicineAdherenceApp({super.key});

  @override
  State<MedicineAdherenceApp> createState() => _MedicineAdherenceAppState();
}

class _MedicineAdherenceAppState extends State<MedicineAdherenceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingReminderNavigation) {
        final payload = _pendingReminderPayload;
        _pendingReminderPayload = null;
        _pendingReminderNavigation = false;
        _openReminderCenter(payload);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ReminderService.instance.refreshForDeviceTimeChange());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppearanceController.instance,
    builder: (context, _) {
      final appearance = AppearanceController.instance;
      return MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Medicine Adherence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: appearance.isNightComfort
            ? AppTheme.comfortTheme
            : AppTheme.darkTheme,
        themeMode: appearance.materialThemeMode,
        home: _hasBackendSession
            ? const BackendFamilyScreen()
            : CareSession.instance.familyName.isEmpty
            ? const WelcomeScreen()
            : const FamilyHomeScreen(),
      );
    },
  );
}
