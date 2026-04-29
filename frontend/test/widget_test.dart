import 'package:flutter_test/flutter_test.dart';
import 'package:car_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CarManagerApp());
    expect(find.text('CarManager'), findsWidgets);
  });
}
