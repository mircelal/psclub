import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:psclub_pos/core/config/business_config_provider.dart';
import 'package:psclub_pos/features/auth/login_screen.dart';

void main() {
  testWidgets('Login screen renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessConfigProvider.overrideWith((ref) async => BusinessConfig.fallback),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daxil ol'), findsWidgets);
  });
}
