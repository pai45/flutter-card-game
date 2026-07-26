import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../blocs/game/game_state.dart';
import '../config/theme.dart';
import '../models/streak.dart';
import '../screens/predictions/widgets/history_hud.dart' show CutChipBorder;
import '../utils/sound_effects.dart';
import 'cyber/fixture_card.dart' show kFixtureShadow;
import 'streak_widgets.dart';

class StreakCelebrationHost extends StatelessWidget {
  const StreakCelebrationHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.streak.celebrationQueue != current.streak.celebrationQueue,
      builder: (context, state) {
        if (state.streak.celebrationQueue.isEmpty) {
          return const SizedBox.shrink();
        }
        final celebration = state.streak.celebrationQueue.first;
        return _StreakCelebrationOverlay(
          key: ValueKey(celebration.id),
          celebration: celebration,
        );
      },
    );
  }
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({required this.celebration, super.key});

  final StreakCelebration celebration;

  @override
  State<_StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<_StreakCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _panelCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _ringCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  late final AnimationController _iconCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _numberCtrl = AnimationController(
    vsync: this,
    duration: StreakTheme.countDuration,
  );
  late final AnimationController _contentCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  late final Animation<double> _panelScale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _iconScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.44,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 58,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.14,
        end: 0.96,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 24,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.96,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
  ]).animate(_iconCtrl);
  late final Animation<double> _numberScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.82,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
  ]).animate(_numberCtrl);
  late final Animation<Offset> _contentSlide = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAnimation();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _panelCtrl.dispose();
    _ringCtrl.dispose();
    _iconCtrl.dispose();
    _numberCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _startAnimation() {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _panelCtrl.value = 1;
      _ringCtrl.value = 1;
      _iconCtrl.value = 1;
      _numberCtrl.value = 1;
      _contentCtrl.value = 1;
    } else {
      playSound(SoundEffect.streak);
      HapticFeedback.mediumImpact();
      _panelCtrl.forward();
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _ringCtrl.forward();
        _iconCtrl.forward();
      });
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _numberCtrl.forward();
        _contentCtrl.forward();
      });
    }
    if (widget.celebration.type == StreakCelebrationType.daily) {
      _timer = Timer(StreakTheme.autoDismissDuration, _consume);
    }
  }

  void _consume() {
    if (!mounted) return;
    context.read<GameBloc>().add(StreakCelebrationConsumed());
  }

  void _claim() {
    final days = widget.celebration.milestoneDays;
    if (days == null) return;
    context.read<GameBloc>().add(StreakMilestoneClaimed(days));
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final celebration = widget.celebration;
    final milestone = celebration.milestoneDays == null
        ? null
        : streakMilestones
              .where((item) => item.days == celebration.milestoneDays)
              .firstOrNull;
    final next = _nextMilestone(celebration.streak);

    return Material(
      color: StreakTheme.overlayBarrier,
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _panelCtrl,
              _ringCtrl,
              _iconCtrl,
              _numberCtrl,
              _contentCtrl,
            ]),
            builder: (context, _) {
              final panelOpacity = reducedMotion ? 1.0 : _panelCtrl.value;
              return Opacity(
                opacity: panelOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: reducedMotion ? 1 : _panelScale.value,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StreakTheme.maxContentWidth,
                    ),
                    child: Padding(
                      padding: StreakTheme.celebrationPadding,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Cyber.card,
                          shape: CutChipBorder(
                            cut: 12,
                            side: BorderSide(
                              color: StreakTheme.primary.withValues(
                                alpha: 0.78,
                              ),
                              width: StreakTheme.activeBorderWidth,
                            ),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: kFixtureShadow,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: StreakTheme.celebrationPadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StreakRevealIcon(
                                ringProgress: reducedMotion
                                    ? 1
                                    : _ringCtrl.value,
                                iconScale: reducedMotion ? 1 : _iconScale.value,
                                reducedMotion: reducedMotion,
                              ),
                              const SizedBox(height: StreakTheme.space12),
                              SlideTransition(
                                position: _contentSlide,
                                child: FadeTransition(
                                  opacity: _contentCtrl,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        celebration.type ==
                                                StreakCelebrationType.milestone
                                            ? 'MILESTONE REACHED'
                                            : 'DAILY STREAK',
                                        textAlign: TextAlign.center,
                                        style: StreakTheme.title(
                                          color: StreakTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: StreakTheme.space8,
                                      ),
                                      Transform.scale(
                                        scale: reducedMotion
                                            ? 1
                                            : _numberScale.value,
                                        child: Text(
                                          '${_visibleStreakValue(celebration.streak, reducedMotion)}',
                                          style:
                                              StreakTheme.celebrationNumber(),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: StreakTheme.space4,
                                      ),
                                      Text(
                                        celebration.streak == 1
                                            ? 'DAY'
                                            : 'DAYS',
                                        style: StreakTheme.label(
                                          color: StreakTheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: StreakTheme.space16,
                                      ),
                                      Text(
                                        celebration.type ==
                                                StreakCelebrationType.milestone
                                            ? milestone?.rewardLabel ??
                                                  'REWARD READY'
                                            : streakActivityLabel(
                                                celebration.activity,
                                              ),
                                        textAlign: TextAlign.center,
                                        style: StreakTheme.bodyStrong(),
                                      ),
                                      if (celebration.type ==
                                              StreakCelebrationType.daily &&
                                          next != null) ...[
                                        const SizedBox(
                                          height: StreakTheme.space16,
                                        ),
                                        StreakProgressBar(
                                          value: celebration.streak / next.days,
                                        ),
                                        const SizedBox(
                                          height: StreakTheme.space8,
                                        ),
                                        Text(
                                          '${next.days - celebration.streak} '
                                          'days to ${next.days}-day reward',
                                          textAlign: TextAlign.center,
                                          style: StreakTheme.body(),
                                        ),
                                      ],
                                      if (celebration.type ==
                                          StreakCelebrationType.milestone) ...[
                                        const SizedBox(
                                          height: StreakTheme.space20,
                                        ),
                                        StreakClaimButton(
                                          label: 'CLAIM REWARD',
                                          onPressed: _claim,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _visibleStreakValue(int streak, bool reducedMotion) {
    if (reducedMotion) return streak;
    final eased = Curves.easeOutCubic.transform(_numberCtrl.value);
    final rounded = (streak * eased).round();
    if (rounded < 1) return 1;
    if (rounded > streak) return streak;
    return rounded;
  }
}

class _StreakRevealIcon extends StatelessWidget {
  const _StreakRevealIcon({
    required this.ringProgress,
    required this.iconScale,
    required this.reducedMotion,
  });

  final double ringProgress;
  final double iconScale;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: StreakTheme.celebrationIconSize,
      height: StreakTheme.celebrationIconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StreakRevealRingPainter(progress: ringProgress),
            ),
          ),
          Transform.scale(
            scale: iconScale,
            child: SizedBox(
              width: StreakTheme.celebrationIconSize * 0.78,
              height: StreakTheme.celebrationIconSize * 0.78,
              child: Lottie.asset(
                'assets/animations/streak_animation.json',
                repeat: !reducedMotion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakRevealRingPainter extends CustomPainter {
  const _StreakRevealRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.46;
    for (final delay in const [0.0, 0.18]) {
      final raw = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (raw <= 0 || raw >= 1) continue;
      final t = Curves.easeOutCubic.transform(raw);
      final alpha = (1 - t) * 0.72;
      final radius = math.max(0.0, maxRadius * t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * (1 - t) + 0.7
        ..shader = SweepGradient(
          colors: [
            StreakTheme.primary.withValues(alpha: alpha),
            StreakTheme.secondary.withValues(alpha: alpha * 0.86),
            Cyber.danger.withValues(alpha: alpha * 0.34),
            StreakTheme.primary.withValues(alpha: alpha),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final core = (1 - progress).clamp(0.0, 1.0);
    if (core > 0) {
      canvas.drawCircle(
        center,
        maxRadius * 0.3 * Curves.easeOut.transform(progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = StreakTheme.secondary.withValues(alpha: core * 0.44),
      );
    }
  }

  @override
  bool shouldRepaint(_StreakRevealRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

StreakMilestone? _nextMilestone(int streak) {
  for (final milestone in streakMilestones) {
    if (milestone.days > streak) return milestone;
  }
  return null;
}
