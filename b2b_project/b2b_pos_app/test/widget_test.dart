// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:b2b_pos_app/main.dart';

void main() {
  testWidgets('B2B POS App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const B2BPosApp());

    // Wait for initialization
    await tester.pumpAndSettle();

    // Verify that the home screen is displayed
    expect(find.text('HOŞGELDİNİZ'), findsOneWidget);
    expect(find.text('B2B Teklif Görüntüleme Sistemi'), findsOneWidget);
  });
}
