import 'package:flutter_test/flutter_test.dart';
import 'package:safaron/main.dart';

void main() {
  testWidgets('Welcome screen shows Boshlash button', (tester) async {
    await tester.pumpWidget(const SafaronApp());
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Boshlash'), findsOneWidget);
  });
}
