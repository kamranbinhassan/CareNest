import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AdherenceScreen extends StatelessWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Adherence')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Medication routine',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'A clear picture of doses taken over time.',
            style: TextStyle(fontSize: 14, color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE9EFEC)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 66,
                        height: 66,
                        child: CircularProgressIndicator(
                          value: 0,
                          strokeWidth: 7,
                          backgroundColor: Color(0xFFE7EEEB),
                          valueColor: AlwaysStoppedAnimation(AppTheme.teal),
                        ),
                      ),
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No adherence score yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'A score appears after doses are recorded.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE9EFEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Visual preview · demo data',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
                const SizedBox(height: 17),
                const SizedBox(height: 130, child: _DemoChart()),
                const SizedBox(height: 5),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('M'),
                    Text('T'),
                    Text('W'),
                    Text('T'),
                    Text('F'),
                    Text('S'),
                    Text('S'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.paleTeal,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: AppTheme.teal,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No dose history has been recorded. The chart above is illustrative demo data and does not represent a patient.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DemoChart extends StatelessWidget {
  const _DemoChart();
  @override
  Widget build(BuildContext context) {
    const values = [0.42, 0.66, 0.55, 0.8, 0.48, 0.9, 0.68];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 100 * value,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: .15 + value * .55),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
