import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miam_planning/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MiamPlanningApp(),
      ),
    );

    // App should show splash screen initially
    expect(find.text('MiamPlanning'), findsOneWidget);
  });
}
