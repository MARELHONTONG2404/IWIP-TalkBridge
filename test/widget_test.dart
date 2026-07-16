import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ilb/features/home/presentation/home_page.dart';
import 'package:ilb/features/settings/providers/settings_provider.dart';

void main() {
  testWidgets('Home page shows main feature card', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('IWIP TalkBridge'), findsOneWidget);
    expect(find.text('Ketuk untuk bicara & terjemahkan'), findsOneWidget);
  });
}
