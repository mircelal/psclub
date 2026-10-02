import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:psclub_pos/core/api/api_client.dart';
import 'package:psclub_pos/core/api/token_storage.dart';
import 'package:psclub_pos/core/config/business_config_provider.dart';
import 'package:psclub_pos/features/cashier/close_session_dialog.dart';
import 'package:psclub_pos/services/pos_service.dart';

/// Birbaşa (counter) satış üçün ödəniş dialoqunu test edir.
/// Regress: müştəri fikrini dəyişsə, kassir ödənişi almadan geri dönə bilməli.
class _FakePos extends PosService {
  _FakePos() : super(ApiClient(const TokenStorage()));

  int closeCalls = 0;

  @override
  Future<Map<String, dynamic>> getSession(int id) async => {
        'id': id,
        'session_type': 'counter',
        'status': 'active',
        'table_name': 'Birbaşa satış',
        'opened_at': DateTime.now().toUtc().toIso8601String(),
        'items': [
          {'id': 1, 'name': 'Cola', 'unit_price': 5.0, 'quantity': 1},
        ],
        'bill_preview': {'products_total': 5.0},
      };

  @override
  Future<Map<String, dynamic>> closeSession(
    int id, {
    required String method,
    double cashAmount = 0,
    double cardAmount = 0,
  }) async {
    closeCalls++;
    return {
      'receipt': {'receipt_number': 'R1', 'receipt_lines': <dynamic>[]},
    };
  }
}

Future<void> _openDialog(WidgetTester tester, _FakePos pos) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        posServiceProvider.overrideWithValue(pos),
        businessConfigProvider.overrideWith((ref) async => BusinessConfig.fallback),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: ctx,
                  builder: (_) => const CloseSessionDialog(
                    sessionId: 1,
                    tableName: 'Birbaşa satış',
                    isCounter: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Counter payment dialog exposes a back/cancel action', (tester) async {
    final pos = _FakePos();
    await _openDialog(tester, pos);

    // Ödəniş dialoqu açıqdır (birbaşa satış üçün primar düymə).
    expect(find.text('Ödənişi al və bağla'), findsOneWidget);
    // Düzəlişdən sonra geri qayıtmaq mümkündür.
    expect(find.text('Geri qayıt'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('Tapping "Geri qayıt" closes dialog without taking payment', (tester) async {
    final pos = _FakePos();
    await _openDialog(tester, pos);

    expect(find.byType(CloseSessionDialog), findsOneWidget);
    await tester.tap(find.text('Geri qayıt'));
    await tester.pumpAndSettle();

    // Dialoq bağlandı, amma ödəniş alınmadı.
    expect(find.byType(CloseSessionDialog), findsNothing);
    expect(pos.closeCalls, 0);
  });

  testWidgets('Close (X) icon also dismisses counter payment dialog', (tester) async {
    final pos = _FakePos();
    await _openDialog(tester, pos);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(CloseSessionDialog), findsNothing);
    expect(pos.closeCalls, 0);
  });
}
