import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:psclub_pos/app.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PsClubApp()));
    expect(find.text('PS Club POS'), findsOneWidget);
  });
}
