import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dopamind/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyApp(prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('DopamiND'), findsWidgets);
  });
}
