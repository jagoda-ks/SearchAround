import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:search_around/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads map search and settings control', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DangerZoneApp());
    await tester.pump(); // allow settings load future to start
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Dyslexia-friendly font'), findsOneWidget);
  });
}
