import 'package:flutter/material.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../models/super_over.dart';

class SuperOverOverlays extends StatelessWidget {
  const SuperOverOverlays({
    required this.state,
    required this.onBatTap,
    required this.onExit,
    super.key,
  });

  final SuperOverState state;
  final VoidCallback onBatTap;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  final y = details.localPosition.dy;
                  final h = constraints.maxHeight;
                  if (y > h * 0.22 && y < h * 0.92) onBatTap();
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    _TopHud(state: state, onExit: onExit),
                    const SizedBox(height: 8),
                    _BallTracker(state: state),
                    const SizedBox(height: 10),
                    if (state.phase == SuperOverPhase.targetReveal)
                      _TargetReveal(target: state.cpuTarget)
                    else
                      _FeedbackChip(state: state),
                    const Spacer(),
                    _BatterStrip(state: state),
                    const SizedBox(height: 10),
                    _BatButton(enabled: state.canTap, onTap: onBatTap),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.state, required this.onExit});

  final SuperOverState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final need = state.runsToWin;
    final balls = state.ballsLeft;
    final needLabel = need <= 0 ? 'Target chased' : 'Need $need from $balls';
    return Row(
      children: [
        _RoundIconButton(icon: Icons.close, onTap: onExit),
        const SizedBox(width: 8),
        _HudPlate(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.score}/${state.wickets}',
                style: Cyber.display(
                  26,
                  color: Colors.white,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '${state.ballsFaced}/6 balls',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
        ),
        const Spacer(),
        _HudPlate(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Target ${state.cpuTarget}',
                style: Cyber.label(10, color: Cyber.muted),
              ),
              Text(
                needLabel,
                style: Cyber.display(
                  14,
                  color: need <= balls ? Cyber.lime : Cyber.danger,
                  letterSpacing: 0.4,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HudPlate extends StatelessWidget {
  const _HudPlate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: Cyber.cyan.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cyber.panel.withValues(alpha: 0.90),
      shape: CircleBorder(
        side: BorderSide(color: Cyber.cyan.withValues(alpha: 0.72), width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Cyber.cyan),
        ),
      ),
    );
  }
}

class _BallTracker extends StatelessWidget {
  const _BallTracker({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final completed = i < state.wagonWheel.length;
        final current = i == state.wagonWheel.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: current ? 34 : 30,
          height: current ? 34 : 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: completed
                ? _outcomeColor(state.wagonWheel[i])
                : Cyber.panel.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            border: Border.all(
              color: current
                  ? Cyber.gold
                  : Cyber.cyan.withValues(alpha: completed ? 0.35 : 0.62),
              width: current ? 2.5 : 1.4,
            ),
            boxShadow: current
                ? Cyber.glow(Cyber.gold, alpha: 0.18, blur: 12, spread: -4)
                : null,
          ),
          child: Center(
            child: Text(
              completed ? _outcomeText(state.wagonWheel[i]) : '${i + 1}',
              style: Cyber.display(
                completed ? 13 : 10,
                color: completed ? Cyber.bg : Cyber.cyan,
                letterSpacing: 0,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        );
      }),
    );
  }
}

class _TargetReveal extends StatelessWidget {
  const _TargetReveal({required this.target});

  final int target;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(
        scale: 0.78 + t * 0.22,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: _BigLabel(
        title: 'CHASE ${target + 1}',
        subtitle: '6 balls. 2 wickets.',
        color: Cyber.gold,
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    if (state.lastOutcome != null) {
      return _BigLabel(
        title: _outcomeTitle(state.lastOutcome!),
        subtitle: _sectorSubtitle(state.shotSector),
        color: _outcomeColor(state.lastOutcome!),
      );
    }
    if (state.timingTier != null) {
      return _BigLabel(
        title: _tierText(state.timingTier!),
        subtitle: _sectorSubtitle(state.shotSector),
        color: _tierColor(state.timingTier!),
      );
    }
    if (state.canTap) {
      return const _BigLabel(
        title: 'TAP TO SWING',
        subtitle: 'Watch the ball, one tap only',
        color: Cyber.gold,
      );
    }
    return _DeliveryChip(delivery: state.upcomingDelivery, phase: state.phase);
  }
}

class _BigLabel extends StatelessWidget {
  const _BigLabel({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Cyber.panel.withValues(alpha: 0.96),
            Cyber.bg.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.76), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _LabelFramePainter(color),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 3,
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: Cyber.glow(
                    color,
                    alpha: 0.18,
                    blur: 8,
                    spread: -2,
                  ),
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Cyber.display(24, color: color, letterSpacing: 1.2)
                    .copyWith(
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.34),
                          blurRadius: 14,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  12,
                  color: Cyber.muted,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelFramePainter extends CustomPainter {
  const _LabelFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.56)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;
    const cut = 13.0;
    canvas.drawLine(const Offset(0, cut), const Offset(cut, 0), p);
    canvas.drawLine(Offset(size.width - cut, 0), Offset(size.width, cut), p);
    canvas.drawLine(Offset(0, size.height - cut), Offset(cut, size.height), p);
    canvas.drawLine(
      Offset(size.width - cut, size.height),
      Offset(size.width, size.height - cut),
      p,
    );

    final scan = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var y = 8.0; y < size.height; y += 9) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), scan);
    }
  }

  @override
  bool shouldRepaint(covariant _LabelFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.delivery, required this.phase});

  final DeliveryType delivery;
  final SuperOverPhase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      SuperOverPhase.runUp => 'Bowler running in',
      SuperOverPhase.ballInFlight => 'Ball released',
      SuperOverPhase.swinging => 'Swinging',
      SuperOverPhase.ballSetup => 'Get ready',
      _ => 'Read the ball',
    };
    final deliveryLabel = switch (delivery) {
      DeliveryType.pace => 'Pace',
      DeliveryType.spin => 'Spin',
      DeliveryType.yorker => 'Yorker',
    };
    return _BigLabel(
      title: deliveryLabel,
      subtitle: label,
      color: switch (delivery) {
        DeliveryType.pace => Cyber.cyan,
        DeliveryType.spin => Cyber.gold,
        DeliveryType.yorker => Cyber.danger,
      },
    );
  }
}

class _BatterStrip extends StatelessWidget {
  const _BatterStrip({required this.state});

  final SuperOverState state;

  @override
  Widget build(BuildContext context) {
    final striker = state.striker;
    if (striker == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: state.onFire ? Cyber.gold : Cyber.cyan.withValues(alpha: 0.58),
          width: 1.4,
        ),
        boxShadow: state.onFire
            ? Cyber.glow(Cyber.gold, alpha: 0.18, blur: 18, spread: -5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.65),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.28)),
            ),
            clipBehavior: Clip.hardEdge,
            child: striker.hasPortrait
                ? Image.asset(striker.resolvedPortraitAsset!, fit: BoxFit.cover)
                : Icon(
                    Icons.sports_cricket,
                    color: state.onFire ? Cyber.gold : Cyber.cyan,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  striker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    14,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                ),
                Text(
                  state.onFire
                      ? 'ON FIRE'
                      : 'OVR ${striker.rating} . Combo ${state.combo}',
                  style: Cyber.label(
                    9,
                    color: state.onFire ? Cyber.gold : Cyber.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatButton extends StatelessWidget {
  const _BatButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? Cyber.gold : Cyber.cyan.withValues(alpha: 0.32);
    return AnimatedScale(
      scale: enabled ? 1 : 0.94,
      duration: const Duration(milliseconds: 160),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: enabled
              ? Cyber.glow(Cyber.gold, alpha: 0.26, blur: 24, spread: -2)
              : null,
        ),
        child: Material(
          color: enabled
              ? Cyber.gold.withValues(alpha: 0.94)
              : Cyber.panel.withValues(alpha: 0.86),
          shape: CircleBorder(side: BorderSide(color: accent, width: 3)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 78,
              height: 78,
              child: Icon(
                Icons.sports_cricket,
                size: 38,
                color: enabled ? Cyber.bg : Cyber.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _outcomeText(ShotOutcome outcome) {
  return switch (outcome) {
    ShotOutcome.six => '6',
    ShotOutcome.four => '4',
    ShotOutcome.three => '3',
    ShotOutcome.two => '2',
    ShotOutcome.one => '1',
    ShotOutcome.dot => '.',
    ShotOutcome.caught || ShotOutcome.bowled => 'W',
  };
}

String _outcomeTitle(ShotOutcome outcome) {
  return switch (outcome) {
    ShotOutcome.six => 'SIX',
    ShotOutcome.four => 'FOUR',
    ShotOutcome.three => '3 RUNS',
    ShotOutcome.two => '2 RUNS',
    ShotOutcome.one => '1 RUN',
    ShotOutcome.dot => 'DOT BALL',
    ShotOutcome.caught => 'CAUGHT',
    ShotOutcome.bowled => 'BOWLED',
  };
}

Color _outcomeColor(ShotOutcome outcome) {
  return switch (outcome) {
    ShotOutcome.six => Cyber.gold,
    ShotOutcome.four => Cyber.lime,
    ShotOutcome.caught || ShotOutcome.bowled => Cyber.danger,
    _ => Cyber.cyan,
  };
}

String _tierText(TimingTier tier) {
  return switch (tier) {
    TimingTier.perfect => 'PERFECT',
    TimingTier.great => 'GREAT',
    TimingTier.good => 'GOOD',
    TimingTier.edgePoor => 'EDGE',
    TimingTier.miss => 'MISS',
  };
}

Color _tierColor(TimingTier tier) {
  return switch (tier) {
    TimingTier.perfect => Cyber.gold,
    TimingTier.great => Cyber.lime,
    TimingTier.good => Cyber.cyan,
    TimingTier.edgePoor => Cyber.amber,
    TimingTier.miss => Cyber.danger,
  };
}

String _sectorSubtitle(ShotSector? sector) {
  return switch (sector) {
    ShotSector.leg => 'Pulled to leg side',
    ShotSector.v => 'Driven straight',
    ShotSector.off => 'Guided to off side',
    null => 'Timing decides direction',
  };
}
