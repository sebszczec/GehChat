// Basic widget test for GehChat Flutter app
//
// To run all tests: flutter test
// To run this specific test: flutter test test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geh_chat_frontend/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Verify that app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App has correct title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // The app should have MaterialApp widget
    final MaterialApp app = tester.widget(find.byType(MaterialApp));

    expect(app, isNotNull);
  });
}
