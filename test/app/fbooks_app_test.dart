import 'package:fbooks/app/fbooks_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the empty library landing page', (tester) async {
    await tester.pumpWidget(const FbooksApp());

    expect(find.text('Fbooks'), findsOneWidget);
    expect(find.text('Your library will appear here.'), findsOneWidget);
  });
}
