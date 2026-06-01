import '../utils/json_parse.dart';
import '../utils/session_datetime.dart';

/// Server bill_preview + SessionClock əsasında aktiv saniyə / qalan saniyə.
({int activeSeconds, int? remainingSeconds}) liveSessionSeconds({
  required Map<String, dynamic>? billPreview,
  required int? plannedMinutes,
  required String? openedAtRaw,
  required bool isPaused,
}) {
  final plannedSecs = plannedMinutes != null && plannedMinutes > 0 ? plannedMinutes * 60 : null;
  final now = SessionClock.nowUtc();

  if (billPreview != null && !isPaused) {
    final computedAt = parseSessionDateTime(billPreview['computed_at']?.toString());
    final tick = computedAt != null
        ? now.difference(computedAt.toUtc()).inSeconds.clamp(0, 999999)
        : 0;

    final serverActive = jsonToInt(billPreview['active_seconds']);
    var activeSeconds = serverActive + tick;

    int? remaining;
    if (plannedSecs != null) {
      final serverRem = jsonToIntOrNull(billPreview['remaining_seconds']);
      final baseRem = serverRem ?? (plannedSecs - serverActive);
      remaining = (baseRem - tick).clamp(0, plannedSecs);
      activeSeconds = plannedSecs - remaining;
    }

    return (activeSeconds: activeSeconds, remainingSeconds: remaining);
  }

  final opened = parseSessionDateTime(openedAtRaw);
  if (opened == null) {
    return (activeSeconds: 0, remainingSeconds: plannedSecs);
  }

  final openedUtc = opened.toUtc();
  if (plannedSecs != null) {
    final endUtc = openedUtc.add(Duration(seconds: plannedSecs));
    final remaining = endUtc.difference(now).inSeconds.clamp(0, plannedSecs);
    return (activeSeconds: plannedSecs - remaining, remainingSeconds: remaining);
  }

  final active = now.difference(openedUtc).inSeconds.clamp(0, 999999);
  return (activeSeconds: active, remainingSeconds: null);
}
