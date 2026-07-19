import 'package:flutter_test/flutter_test.dart';
import 'package:droidforge/main.dart';

void main() {
  testWidgets('DroidForge app launches', (tester) async {
    await tester.pumpWidget(const DroidForgeApp());

    expect(find.text('DroidForge'), findsOneWidget);
  });
}
