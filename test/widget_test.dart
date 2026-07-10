import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ilb/features/home/presentation/home_page.dart';

void main() {
  testWidgets('Home page shows main feature card', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('IWIP TalkBridge'), findsOneWidget);
    expect(find.text('Tap to speak and translate'), findsOneWidget);
  });
}
