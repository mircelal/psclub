import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_panel.dart';

/// 13–24" ekranlar üçün geniş mərkəzlənmiş modal; kiçik ekranda tam en bottom sheet.
void showSessionPanel(BuildContext context, WidgetRef ref, int sessionId, VoidCallback onChanged) {
  final size = MediaQuery.sizeOf(context);
  final isWide = size.width >= 900;

  if (isWide) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sessiya',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        final maxW = math.min(size.width * 0.94, 1320.0);
        final maxH = math.min(size.height * 0.94, 900.0);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: SessionPanel(
                sessionId: sessionId,
                onChanged: onChanged,
                isWideLayout: true,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      expand: false,
      builder: (ctx, scrollController) => SessionPanel(
        sessionId: sessionId,
        scrollController: scrollController,
        onChanged: onChanged,
        isWideLayout: false,
      ),
    ),
  );
}
