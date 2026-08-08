import 'package:flutter_test/flutter_test.dart';

import 'package:handover/main.dart';

void main() {
  testWidgets('App renders the intro screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HandoverApp());

    expect(find.text('Handover'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}