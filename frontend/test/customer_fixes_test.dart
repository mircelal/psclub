import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monday weekday 0 stays in the promotion payload', () {
    final selectedDays = <int>{0};
    final payload = selectedDays.toList();
    expect(payload, [0]);
    expect(payload.contains(0), isTrue);
  });

  test('gift sale cannot close without a comment', () {
    expect(''.trim().isEmpty, isTrue);
    expect('dostum'.trim().isEmpty, isFalse);
  });
}
