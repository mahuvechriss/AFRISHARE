import 'package:flutter_test/flutter_test.dart';
import 'package:afrishare/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AfriShare app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AfriShareApp(),
      ),
    );

    // Verify the app renders
    expect(find.text('AfriShare'), findsOneWidget);
  });
}
