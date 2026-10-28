import 'package:flutter/material.dart';

import '../../analysis/presentation/adherence_analysis_view.dart';
import '../../dashboard/presentation/home_dashboard_view.dart';
import '../../notifications/presentation/notifications_center_view.dart';
import '../../profile/presentation/profile_view.dart';
import '../../settings/presentation/settings_view.dart';

class FamilyHomeScreen extends StatefulWidget {
  final int initialIndex;

  const FamilyHomeScreen({super.key, this.initialIndex = 0});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  void _onTabSelected(int index) {
    if (index != _currentIndex && mounted) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeDashboardView(onNavigateToTab: _onTabSelected),
          const AdherenceAnalysisView(),
          const NotificationsCenterView(),
          SettingsView(onNavigateToTab: _onTabSelected),
          ProfileView(onNavigateToTab: _onTabSelected),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
