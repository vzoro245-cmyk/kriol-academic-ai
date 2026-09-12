import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kriol_academic_ai/app/app.dart';

void main() {
  testWidgets('Verify Login Screen exists', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KriolAcademicApp(),
      ),
    );

    expect(find.text('Kriol Academic AI'), findsAtLeastNWidgets(1));
    expect(find.text('Entrar'), findsOneWidget);
  });
}
