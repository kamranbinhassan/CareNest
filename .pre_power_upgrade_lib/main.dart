import 'package:flutter/material.dart';
import 'core/data/care_session.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/family/presentation/family_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CareSession.instance.load();
  runApp(const MedicineAdherenceApp());
}

class MedicineAdherenceApp extends StatelessWidget {
  const MedicineAdherenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Adherence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: CareSession.instance.familyName.isEmpty
          ? const WelcomeScreen()
          : const FamilyHomeScreen(),
    );
  }
}
