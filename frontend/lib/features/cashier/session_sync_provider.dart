import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Açıq sessiya paneli — masalar poll-u ilə koordinasiya üçün.
class OpenSessionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setOpen(int? sessionId) => state = sessionId;
}

final openSessionIdProvider = NotifierProvider<OpenSessionIdNotifier, int?>(OpenSessionIdNotifier.new);

/// Masalar yenilənəndə sessiya `updated_at` dəyişəndə panelə siqnal.
class SessionRevisionNotifier extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() => const {};

  void bump(int sessionId, String revision) {
    if (state[sessionId] == revision) return;
    state = {...state, sessionId: revision};
  }
}

final sessionRevisionProvider =
    NotifierProvider<SessionRevisionNotifier, Map<int, String>>(SessionRevisionNotifier.new);
