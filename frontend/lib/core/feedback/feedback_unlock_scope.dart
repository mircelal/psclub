import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_feedback.dart';

/// İlk toxunuşda səs kilidini açır (vebdə hər klikdə yox — donma riski).
class FeedbackUnlockScope extends StatelessWidget {
  const FeedbackUnlockScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AppFeedback.unlock(),
      child: child,
    );
  }
}
