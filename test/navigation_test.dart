import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/core/data/care_session.dart';
import 'package:medicine_adherence_monitoring/features/family/presentation/family_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CareSession.instance.createFamily(name: 'CareNest Family');
    CareSession.instance.addMember(name: 'Alice', relationship: 'Mother');
  });

  testWidgets(
    'FamilyHomeScreen displays persistent bottom navigation with 5 destinations',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: FamilyHomeScreen()));
      await tester.pumpAndSettle();

      // Verify 5 navigation destinations exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);

      // Initial tab is Home
      expect(find.text('Today’s Adherence'), findsOneWidget);

      // Switch to Analysis tab
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('Adherence Overview'), findsOneWidget);
      expect(find.text('Daily Consistency Trend'), findsOneWidget);

      // Switch to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notification Center'), findsOneWidget);

      // Switch to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Preferences & Security'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);

      // Switch to Me tab
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Family Care Space'), findsOneWidget);
      expect(find.text('CareNest Roadmap & Labs'), findsOneWidget);
    },
  );
}
