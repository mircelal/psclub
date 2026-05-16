import '../../../core/utils/json_parse.dart';

/// Masa kartı / menyusu üçün açıq sessiya vəziyyəti (API + köhnə status uyğunluğu).
abstract final class TableSessionState {
  static int? openSessionId(Map<String, dynamic> table) => jsonToIntOrNull(table['session_id']);

  static bool hasOpenSession(Map<String, dynamic> table) => openSessionId(table) != null;

  static bool isPaused(Map<String, dynamic> table) {
    final sessionStatus = table['session_status'] as String?;
    final tableStatus = table['status'] as String? ?? 'empty';
    return sessionStatus == 'paused' || tableStatus == 'paused';
  }

  /// Yeni sessiya açıla bilər (açıq hesab yoxdur).
  static bool canOpenSession(Map<String, dynamic> table) => !hasOpenSession(table);

  /// Hesab bağlana bilər (aktiv və ya pause sessiya var).
  static bool canCloseBill(Map<String, dynamic> table) => hasOpenSession(table);
}
