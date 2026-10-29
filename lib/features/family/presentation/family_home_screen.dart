import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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

  static const _navItems = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Analysis',
    ),
    (
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Notifications',
    ),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Me',
    ),
  ];

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xE61E232A)
                      : Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppTheme.outline.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(_navItems.length, (index) {
                    final item = _navItems[index];
                    final isSelected = index == _currentIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () => _onTabSelected(index),
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 8 : 4,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.teal.withValues(
                                      alpha: isDark ? 0.22 : 0.12,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? AppTheme.teal
                                      : (isDark
                                            ? Colors.white60
                                            : AppTheme.muted),
                                ),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.teal
                                          : (isDark
                                                ? Colors.white70
                                                : AppTheme.muted),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
