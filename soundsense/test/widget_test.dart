// SoundSense widget tests

import 'package:flutter_test/flutter_test.dart';
import 'package:soundsense/main.dart';

void main() {
  testWidgets('SoundSense app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SoundSenseApp());

    // Verify that the app title is displayed
    expect(find.text('SoundSense'), findsOneWidget);
  });
}
