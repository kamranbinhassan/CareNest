import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_adherence_monitoring/main.dart';

void main() {
  testWidgets('Medicine Adherence app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MedicineAdherenceApp());

    expect(find.text('CareNest'), findsOneWidget);
  });
}
