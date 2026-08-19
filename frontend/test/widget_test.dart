import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:handover/main.dart';

void main() {
  testWidgets('App renders the intro screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HandoverApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Handover'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
