import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0D0F14);
  static const surface = Color(0xFF151820);
  static const surfaceElevated = Color(0xFF1C2129);
  static const surfaceHover = Color(0xFF242A34);
  static const border = Color(0xFF2A3140);
  static const borderLight = Color(0xFF353D4D);

  static const primary = Color(0xFF7C5CFC);
  static const primarySoft = Color(0x337C5CFC);
  static const accent = Color(0xFF00D4AA);
  static const accentSoft = Color(0x3300D4AA);

  static const textPrimary = Color(0xFFF4F6FA);
  static const textSecondary = Color(0xFF9AA3B2);
  static const textMuted = Color(0xFF6B7280);

  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0x3322C55E);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0x33F59E0B);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0x33EF4444);
  static const info = Color(0xFF3B82F6);

  /// Masa statusu — premium venue POS (sakit, göz yormayan, yüksək kontrastlı deyil).
  static const tableEmpty = Color(0xFF6B9080);
  static const tableActive = Color(0xFFCF6B6B);
  static const tablePaused = Color(0xFFC4A24D);
  static const tableClosed = Color(0xFF7B8798);

  static Color tableStatus(String status) => switch (status) {
        'empty' => tableEmpty,
        'active' => tableActive,
        'paused' => tablePaused,
        'closed' => tableClosed,
        _ => textMuted,
      };

  static Color tableStatusSoft(String status) => tableStatus(status).withValues(alpha: 0.10);

  static Color tableStatusBorder(String status) => tableStatus(status).withValues(alpha: 0.32);
}
