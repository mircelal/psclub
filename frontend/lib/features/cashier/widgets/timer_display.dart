import 'package:flutter/material.dart';
import '../../../core/billing/billing_calculator.dart';
import '../../../core/theme/app_colors.dart';

class TimerDisplay extends StatelessWidget {
  const TimerDisplay({
    super.key,
    required this.bill,
    required this.isPaused,
    this.tick,
    this.compact = false,
    this.large = false,
    this.isExpired = false,
    this.isUrgent = false,
    this.color,
  });

  final BillingPreview bill;
  final bool isPaused;
  final int? tick;
  final bool compact;
  final bool large;
  final bool isExpired;
  final bool isUrgent;
  final Color? color;

  int get _tick => tick ?? DateTime.now().second;

  @override
  Widget build(BuildContext context) {
    final size = large ? 28.0 : (compact ? 13.0 : 18.0);

    if (isPaused) {
      return Text(
        'Pause',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: size,
          color: AppColors.tablePaused,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    if (bill.isCountdown && bill.remainingSeconds != null) {
      if (isExpired) {
        return Text(
          'Vaxt bitdi',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: size + 1,
            color: AppColors.tableActive,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      }
      return _AnimatedClock(
        totalSeconds: bill.remainingSeconds!,
        tick: _tick,
        fontSize: size,
        color: isUrgent ? AppColors.tablePaused : AppColors.tablePaused.withValues(alpha: 0.95),
        urgent: isUrgent,
      );
    }

    return _AnimatedClock(
      totalSeconds: bill.activeSeconds,
      tick: _tick,
      fontSize: size,
      color: color,
      urgent: false,
    );
  }
}

class _AnimatedClock extends StatelessWidget {
  const _AnimatedClock({
    required this.totalSeconds,
    required this.tick,
    required this.fontSize,
    required this.color,
    required this.urgent,
  });

  final int totalSeconds;
  final int tick;
  final double fontSize;
  final Color? color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final colonOn = tick.isEven;
    final colonOpacity = urgent ? (colonOn ? 1.0 : 0.15) : (colonOn ? 1.0 : 0.35);
    final defaultColor = Theme.of(context).textTheme.bodyLarge?.color;

    final style = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
      color: color ?? defaultColor,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.0,
      letterSpacing: fontSize > 20 ? -0.5 : 0,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (h > 0) ...[
          _TickDigit(value: h, style: style, pad: 2),
          _Colon(opacity: colonOpacity, size: fontSize),
        ],
        _TickDigit(value: m, style: style, pad: 2),
        _Colon(opacity: colonOpacity, size: fontSize),
        _TickDigit(value: s, style: style, pad: 2),
      ],
    );
  }
}

class _TickDigit extends StatelessWidget {
  const _TickDigit({required this.value, required this.style, required this.pad});

  final int value;
  final TextStyle style;
  final int pad;

  @override
  Widget build(BuildContext context) {
    final text = value.toString().padLeft(pad, '0');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon({required this.opacity, required this.size});

  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(':', style: TextStyle(fontWeight: FontWeight.w600, fontSize: size, height: 1.1)),
    );
  }
}
