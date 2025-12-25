import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:popote/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PopoteApp(),
      ),
    );

    // App should show splash screen initially
    expect(find.text('Popote'), findsOneWidget);
  });
}
