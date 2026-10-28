import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(width: 9),
                const Text(
                  'CareNest',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppTheme.paleTeal,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 72,
                color: AppTheme.teal,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'Stay on top of your family’s treatment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: AppTheme.ink,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Keep family care plans and medicine schedules together. Adherence trends are illustrative until dose tracking is available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateAccountScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Create account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  'I already have an account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
