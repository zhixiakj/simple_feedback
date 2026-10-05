import 'package:flutter_test/flutter_test.dart';
import 'package:simple_feedback_example/main.dart' as app;

void main() {
  testWidgets('demo page renders and opens the dialog', (tester) async {
    await tester.pumpWidget(const app.ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Open feedback dialog'), findsOneWidget);

    await tester.tap(find.text('Open feedback dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Send feedback'), findsOneWidget);
  });
}
