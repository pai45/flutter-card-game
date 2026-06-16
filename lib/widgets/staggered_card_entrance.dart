import 'package:flutter/material.dart';

class StaggeredCardEntrance extends StatelessWidget {
  const StaggeredCardEntrance({
    required this.index,
    required this.animate,
    required this.child,
    this.maxAnimatedIndex = 7,
    this.slideOffset = 48,
    this.slideFromLeft = true,
    super.key,
  });

  final int index;
  final bool animate;
  final int maxAnimatedIndex;
  final double slideOffset;
  final bool slideFromLeft;
  final Widget child;

  static const _baseDuration = Duration(milliseconds: 320);
  static const _stagger = Duration(milliseconds: 70);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (!animate ||
        index > maxAnimatedIndex ||
        (mediaQuery?.disableAnimations ?? false)) {
      return child;
    }

    final delay = Duration(milliseconds: _stagger.inMilliseconds * index);
    final duration = _baseDuration + delay;
    final delayFactor = delay.inMilliseconds / duration.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(delayFactor, 1, curve: Curves.easeOutCubic),
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              (slideFromLeft ? -slideOffset : slideOffset) * (1 - value),
              0,
            ),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}
