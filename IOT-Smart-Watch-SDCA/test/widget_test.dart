// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_watch_app/main.dart';
import 'package:my_watch_app/models/watch_data.dart';
import 'package:my_watch_app/screens/heart_rate_screen.dart';
import 'package:my_watch_app/screens/patient_screen.dart';
import 'package:my_watch_app/screens/steps_screen.dart';

Widget _wrapWatch(Widget child) {
  return const MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 170, height: 284, child: Placeholder()),
      ),
    ),
  );
}

void main() {
  testWidgets('smart watch shell loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartWatchApp());
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('heart activity and patient pages render without overflow', (WidgetTester tester) async {
    final controller = WatchController();

    Future<void> pumpPage(Widget page) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 170, height: 284, child: page),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpPage(HeartRateScreen(controller: controller));
    expect(find.text('Heart & Vitals'), findsOneWidget);

    await pumpPage(StepsScreen(controller: controller));
    expect(find.text('Activity'), findsOneWidget);

    await pumpPage(PatientScreen(controller: controller));
    expect(find.text('Patient Details'), findsOneWidget);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
