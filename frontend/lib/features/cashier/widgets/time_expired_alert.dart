import '../../../core/feedback/app_feedback.dart';

/// Eyni sessiya üçün vaxt bitmə səsini təkrarlamır.
class TimeExpiredAlert {
  TimeExpiredAlert._();

  static final _played = <int>{};

  static void check(int? sessionId, bool isExpired) {
    if (sessionId == null) return;
    if (!isExpired) {
      _played.remove(sessionId);
      return;
    }
    if (_played.add(sessionId)) {
      AppFeedback.timeExpired();
    }
  }
}
