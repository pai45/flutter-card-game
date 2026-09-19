import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../blocs/achievement/achievement_celebration_controller.dart';
import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../blocs/game/game_state.dart';
import '../config/theme.dart';
import '../models/streak.dart';
import '../models/unlock_progress.dart';
import '../utils/sound_effects.dart';
import 'cyber/cyber_cta_button.dart';
import 'cyber/cyber_widgets.dart';
import 'streak_widgets.dart';

const _autoDismiss = Duration(milliseconds: 2600);

class StreakCelebrationHost extends StatelessWidget {
  const StreakCelebrationHost({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = context
        .watch<AchievementCelebrationController?>()
        ?.state;
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) =>
          previous.streak.celebrationQueue != current.streak.celebrationQueue ||
          previous.unlocks != current.unlocks ||
          previous.questRewardCoins != current.questRewardCoins,
      builder: (context, state) {
        final reveals = state.unlocks.pendingReveals;
        final rookieGraduationPending =
            reveals.isNotEmpty &&
            reveals.first.kind == UnlockRevealKind.questComplete &&
            reveals.first.sport == state.unlocks.homeSport;
        if (rookieGraduationPending) return const SizedBox.shrink();
        if (state.streak.celebrationQueue.isEmpty) {
          if (state.questRewardCoins > 0 &&
              !(achievements?.holding ?? false) &&
              (achievements?.queue.isEmpty ?? true)) {
            return _QuestRewardReveal(coins: state.questRewardCoins);
          }
          return const SizedBox.shrink();
        }
        final celebration = state.streak.celebrationQueue.first;
        if (state.unlocks.initialQuestActive &&
            (celebration.type == StreakCelebrationType.shieldEarned ||
                celebration.type == StreakCelebrationType.shieldSaved)) {
          return const SizedBox.shrink();
        }
        return _StreakCelebrationOverlay(
          key: ValueKey(celebration.id),
          celebration: celebration,
          streak: state.streak,
        );
      },
    );
  }
}

/// Expanding rings + a radial ray burst behind a popping icon.
class _BurstIcon extends StatelessWidget {
  const _BurstIcon({
    required this.progress,
    required this.pop,
    required this.accent,
    required this.child,
  });

  final double progress;
  final double pop;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RevealBurstPainter(progress: progress, accent: accent),
            ),
          ),
          Transform.scale(scale: pop, child: child),
        ],
      ),
    );
  }
}

class _RevealBurstPainter extends CustomPainter {
  const _RevealBurstPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 0.5;
    final hot = Color.lerp(accent, Colors.white, 0.35)!;

    for (final delay in const [0.0, 0.18]) {
      final raw = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (raw <= 0 || raw >= 1) continue;
      final t = Curves.easeOutCubic.transform(raw);
      final alpha = (1 - t) * 0.72;
      final radius = math.max(0.0, maxRadius * t);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * (1 - t) + 0.7
          ..shader = SweepGradient(
            colors: [
              accent.withValues(alpha: alpha),
              hot.withValues(alpha: alpha * 0.86),
              accent.withValues(alpha: alpha * 0.34),
              accent.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final t = Curves.easeOutCubic.transform(progress);
    final rays = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = accent.withValues(alpha: (1 - t) * 0.6);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final inner = maxRadius * (0.3 + 0.4 * t);
      final outer = inner + maxRadius * 0.28 * (1 - t) + 3;
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        rays,
      );
    }
  }

  @override
  bool shouldRepaint(_RevealBurstPainter old) =>
      old.progress != progress || old.accent != accent;
}

/// Quest claims share the streak host's presentation slot, so they wait for
/// streak and achievement moments instead of covering the gameplay payoff.
class _QuestRewardReveal extends StatefulWidget {
  const _QuestRewardReveal({required this.coins});
  final int coins;
  @override
  State<_QuestRewardReveal> createState() => _QuestRewardRevealState();
}

class _QuestRewardRevealState extends State<_QuestRewardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      playSound(SoundEffect.coins);
      HapticFeedback.mediumImpact();
      if (MediaQuery.disableAnimationsOf(context)) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward();
      }
    });
    _dismiss = Timer(const Duration(seconds: 3), _consume);
  }

  void _consume() {
    if (mounted) context.read<GameBloc>().add(DailyQuestRewardConsumed());
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: Cyber.bg.withValues(alpha: 0.9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = reduced ? 1.0 : _ctrl.value;
                  return Opacity(
                    opacity: reduced ? 1 : (t * 3).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * Curves.easeOutCubic.transform(t),
                      child: StreakMomentPanel(
                        accent: Cyber.gold,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BurstIcon(
                              progress: t,
                              pop: reduced
                                  ? 1
                                  : 0.4 + 0.6 * Curves.elasticOut.transform(t),
                              accent: Cyber.gold,
                              child: SvgPicture.asset(
                                'assets/icons/oz_coins.svg',
                                width: 58,
                                height: 58,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QUEST REWARDS',
                              textAlign: TextAlign.center,
                              style: Cyber.display(18, color: Cyber.gold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'DAILY OPS PAYOUT',
                              style: Cyber.label(
                                9,
                                color: Cyber.muted,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: widget.coins.toDouble(),
                              ),
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Text(
                                '+${value.round()}',
                                style:
                                    Cyber.display(
                                      46,
                                      color: Cyber.gold,
                                      letterSpacing: 0,
                                    ).copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OZ COINS',
                              style: Cyber.label(
                                10,
                                color: Cyber.muted,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            HudCtaButton(
                              label: 'CONTINUE',
                              icon: Icons.check,
                              accent: Cyber.gold,
                              height: 52,
                              labelStyle: Cyber.display(18),
                              tapSound: SoundEffect.uiConfirm,
                              onTap: _consume,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({
    required this.celebration,
    required this.streak,
    super.key,
  });

  final StreakCelebration celebration;
  final StreakSnapshot streak;

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
    duration: const Duration(milliseconds: 820),
  );
  late final AnimationController _iconCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _numberCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
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

  StreakCelebrationType get _type => widget.celebration.type;

  /// Informational moments dismiss themselves (and on tap); a milestone waits
  /// for its claim and a save waits for acknowledgement.
  bool get _autoDismisses =>
      _type == StreakCelebrationType.daily ||
      _type == StreakCelebrationType.shieldEarned;

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
      playSound(switch (_type) {
        StreakCelebrationType.daily => SoundEffect.streak,
        StreakCelebrationType.milestone => SoundEffect.levelUp,
        StreakCelebrationType.shieldSaved => SoundEffect.save,
        StreakCelebrationType.shieldEarned => SoundEffect.achievement,
      });
      _type == StreakCelebrationType.milestone
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.mediumImpact();
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
    if (_autoDismisses) _timer = Timer(_autoDismiss, _consume);
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
    final isShield =
        _type == StreakCelebrationType.shieldSaved ||
        _type == StreakCelebrationType.shieldEarned;
    final accent = isShield
        ? Cyber.cyan
        : milestone != null
        ? streakMilestoneAccent(milestone)
        : Cyber.gold;
    final shields = celebration.shields ?? widget.streak.shields;
    final used = celebration.shieldsUsed ?? 1;

    final title = switch (_type) {
      StreakCelebrationType.daily => 'DAILY STREAK',
      StreakCelebrationType.milestone => 'MILESTONE REACHED',
      StreakCelebrationType.shieldSaved => 'STREAK SAVED',
      StreakCelebrationType.shieldEarned => 'SHIELD FORGED',
    };
    final subline = switch (_type) {
      StreakCelebrationType.daily => streakActivityLabel(celebration.activity),
      StreakCelebrationType.milestone =>
        milestone?.rewardLabel ?? 'REWARD READY',
      StreakCelebrationType.shieldSaved =>
        used == 1 ? '1 missed day covered' : '$used missed days covered',
      StreakCelebrationType.shieldEarned => 'Daily Sweep complete',
    };

    return Material(
      color: Cyber.bg.withValues(alpha: 0.9),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _autoDismisses ? _consume : null,
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
                return Opacity(
                  opacity: (reducedMotion ? 1.0 : _panelCtrl.value).clamp(
                    0.0,
                    1.0,
                  ),
                  child: Transform.scale(
                    scale: reducedMotion ? 1 : _panelScale.value,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: StreakMomentPanel(
                          accent: accent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BurstIcon(
                                progress: reducedMotion ? 1 : _ringCtrl.value,
                                pop: reducedMotion ? 1 : _iconScale.value,
                                accent: accent,
                                child: isShield
                                    ? Icon(
                                        Icons.shield,
                                        size: 70,
                                        color: accent,
                                        shadows: [
                                          Shadow(
                                            color: accent.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      )
                                    : SizedBox.square(
                                        dimension: 102,
                                        child: Lottie.asset(
                                          'assets/animations/streak_animation.json',
                                          repeat: !reducedMotion,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              SlideTransition(
                                position: _contentSlide,
                                child: FadeTransition(
                                  opacity: _contentCtrl,
                                  child: _content(
                                    reducedMotion: reducedMotion,
                                    accent: accent,
                                    title: title,
                                    subline: subline,
                                    milestone: milestone,
                                    next: next,
                                    shields: shields,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _content({
    required bool reducedMotion,
    required Color accent,
    required String title,
    required String subline,
    required StreakMilestone? milestone,
    required StreakMilestone? next,
    required int shields,
  }) {
    final celebration = widget.celebration;
    final numberScale = reducedMotion ? 1.0 : _numberScale.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Cyber.display(20, color: accent),
        ),
        const SizedBox(height: 10),
        if (_type == StreakCelebrationType.shieldEarned) ...[
          Transform.scale(
            scale: numberScale,
            child: StreakShieldPips(shields: shields, size: 40),
          ),
          const SizedBox(height: 10),
          Text(
            '$shields/$streakShieldCap SHIELDS ARMED',
            style: Cyber.label(11, letterSpacing: 1.2),
          ),
        ] else ...[
          Transform.scale(
            scale: numberScale,
            child: Text(
              '${_visibleStreakValue(celebration.streak, reducedMotion)}',
              style: Cyber.display(
                58,
                letterSpacing: 0,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            celebration.streak == 1 ? 'DAY' : 'DAYS',
            style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.6),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (milestone != null) ...[
              Icon(
                streakRewardIcon(milestone.rewardType),
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                subline,
                textAlign: TextAlign.center,
                style: Cyber.body(14, weight: FontWeight.w800, height: 1.3),
              ),
            ),
          ],
        ),
        if (_type == StreakCelebrationType.daily ||
            _type == StreakCelebrationType.shieldSaved) ...[
          const SizedBox(height: 16),
          StreakWeekChain(
            streak: widget.streak,
            now: DateTime.now(),
            compact: true,
          ),
        ],
        if (_type == StreakCelebrationType.daily && next != null) ...[
          const SizedBox(height: 16),
          CyberProgressBar(
            value: celebration.streak / next.days,
            accent: Cyber.gold,
            animate: !reducedMotion,
          ),
          const SizedBox(height: 8),
          Text(
            '${next.days - celebration.streak} days to ${next.rewardLabel}',
            textAlign: TextAlign.center,
            style: Cyber.body(12.5, color: Cyber.muted),
          ),
        ],
        if (_type == StreakCelebrationType.shieldSaved) ...[
          const SizedBox(height: 14),
          StreakShieldPips(shields: shields, size: 20),
          const SizedBox(height: 6),
          Text(
            '$shields LEFT IN THE BANK',
            style: Cyber.label(9.5, color: Cyber.muted, letterSpacing: 1),
          ),
          const SizedBox(height: 20),
          HudCtaButton(
            label: 'KEEP IT ALIVE',
            icon: Icons.local_fire_department,
            accent: Cyber.cyan,
            height: 52,
            labelStyle: Cyber.display(17),
            tapSound: SoundEffect.uiConfirm,
            onTap: _consume,
          ),
        ],
        if (_type == StreakCelebrationType.shieldEarned) ...[
          const SizedBox(height: 8),
          Text(
            'Miss a day and this shield keeps your run alive.',
            textAlign: TextAlign.center,
            style: Cyber.body(12.5, color: Cyber.muted),
          ),
        ],
        if (_type == StreakCelebrationType.milestone) ...[
          const SizedBox(height: 20),
          HudCtaButton(
            label: 'CLAIM REWARD',
            icon: Icons.redeem,
            accent: accent,
            height: 56,
            labelStyle: Cyber.display(18),
            tapSound: SoundEffect.uiConfirm,
            onTap: _claim,
          ),
        ],
      ],
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

StreakMilestone? _nextMilestone(int streak) {
  for (final milestone in streakMilestones) {
    if (milestone.days > streak) return milestone;
  }
  return null;
}
