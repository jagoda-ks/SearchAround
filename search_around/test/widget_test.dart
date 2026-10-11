import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:search_around/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings opens dyslexia font toggle', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DangerZoneApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Dyslexia-friendly font'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final Switch toggle = tester.widget(find.byType(Switch));
    expect(toggle.value, isTrue);
  });
}
