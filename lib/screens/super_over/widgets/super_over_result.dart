import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../data/super_over_batter_profiles.dart';
import '../../../models/super_over.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class SuperOverResult extends StatefulWidget {
  const SuperOverResult({
    required this.state,
    required this.previousHigh,
    required this.onPlayAgain,
    required this.onExit,
    this.settings = const SuperOverSettings(),
    this.onChangeMode,
    this.onChangeBatters,
    super.key,
  });

  final SuperOverState state;
  final int previousHigh;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final SuperOverSettings settings;
  final VoidCallback? onChangeMode;
  final VoidCallback? onChangeBatters;

  @override
  State<SuperOverResult> createState() => _SuperOverResultState();
}

class _SuperOverResultState extends State<SuperOverResult>
    with SingleTickerProviderStateMixin {
  Timer? _soundTimer;
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  bool get _won => widget.state.wonChase == true;
  bool get _scoreAttack => widget.state.mode == SuperOverMode.scoreAttack;
  bool get _record =>
      widget.state.score > widget.previousHigh && widget.state.score > 0;

  @override
  void initState() {
    super.initState();
    _seq.forward();
    _soundTimer = Timer(const Duration(milliseconds: 420), () {
      if (widget.settings.soundEnabled) {
        playSound(
          _won || _scoreAttack
              ? SoundEffect.cricketVictory
              : SoundEffect.cricketDefeat,
        );
      }
      if (widget.settings.hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _soundTimer?.cancel();
    _seq.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _seq.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final accent = _scoreAttack
        ? Cyber.gold
        : _won
        ? Cyber.lime
        : Cyber.danger;
    final sixes = state.wagonWheel.where((o) => o == ShotOutcome.six).length;
    final fours = state.wagonWheel.where((o) => o == ShotOutcome.four).length;
    final summary = state.summary;
    final rewards = summary?.rewardBreakdown;
    final finisherIndex = state.battingOrder.indexWhere(
      (card) => card.id == summary?.finishingBatterCardId,
    );
    final finisher = finisherIndex < 0
        ? null
        : SuperOverBatterProfiles.fromCard(
            state.battingOrder[finisherIndex],
            orderIndex: finisherIndex,
          ).displayName;

    return _ResultArenaBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedBuilder(
                animation: _seq,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _seq,
                          curve: const Interval(0.0, 0.22),
                        ),
                        child: _StatusStrip(
                          won: _won,
                          scoreAttack: _scoreAttack,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _seq,
                          curve: const Interval(
                            0.08,
                            0.42,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: _OutcomePanel(
                          won: _won,
                          title: _scoreAttack
                              ? 'OVER COMPLETE'
                              : _won
                              ? 'CHASE WON'
                              : 'CHASE LOST',
                          icon: _scoreAttack
                              ? Icons.bolt
                              : _won
                              ? Icons.emoji_events
                              : Icons.close,
                          accent: accent,
                          margin: _marginLine(state),
                          score: _scoreAttack
                              ? '${state.score}/${state.wickets} FROM ${state.ballsFaced} BALLS'
                              : '${state.score}/${state.wickets} CHASING ${state.cpuTarget + 1}',
                          record: _record,
                          grade: summary?.grade.label ?? 'C',
                          finisher: finisher,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _seq,
                          curve: const Interval(0.30, 0.56),
                        ),
                        child: _BallTrail(outcomes: state.wagonWheel),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _seq,
                          curve: const Interval(0.42, 0.68),
                        ),
                        child: _StatGrid(
                          sixes: sixes,
                          fours: fours,
                          perfect:
                              summary?.perfectContacts ?? state.perfectContacts,
                          openHits:
                              summary?.openSectorHits ?? state.openGapHits,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InsightPanel(insight: _improvementInsight(state)),
                      if (rewards != null) ...[
                        const SizedBox(height: 14),
                        _XpBreakdown(rewards: rewards),
                      ],
                      const SizedBox(height: 20),
                      HudCtaButton(
                        label: 'PLAY AGAIN',
                        icon: Icons.replay,
                        accent: _won ? Cyber.cyan : Cyber.gold,
                        helper: _scoreAttack
                            ? 'BEAT YOUR SCORE'
                            : _won
                            ? 'RUN IT BACK'
                            : 'TARGET LOCKED',
                        tapSound: SoundEffect.playMatch,
                        onTap: widget.onPlayAgain,
                      ),
                      const SizedBox(height: 12),
                      if (widget.onChangeMode != null ||
                          widget.onChangeBatters != null)
                        Row(
                          children: [
                            if (widget.onChangeMode != null)
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Change Mode',
                                  clip: false,
                                  onPressed: widget.onChangeMode,
                                ),
                              ),
                            if (widget.onChangeMode != null &&
                                widget.onChangeBatters != null)
                              const SizedBox(width: 10),
                            if (widget.onChangeBatters != null)
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Change Batters',
                                  clip: false,
                                  onPressed: widget.onChangeBatters,
                                ),
                              ),
                          ],
                        ),
                      if (widget.onChangeMode != null ||
                          widget.onChangeBatters != null)
                        const SizedBox(height: 12),
                      CyberCtaButton(
                        label: 'Back To Games',
                        clip: false,
                        onPressed: () {
                          playSound(SoundEffect.uiTap);
                          widget.onExit();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _marginLine(SuperOverState state) {
    if (state.mode == SuperOverMode.scoreAttack) {
      return state.objectiveComplete
          ? 'Objective complete // ${state.objective.label}'
          : '${state.maxCombo}x best combo // ${state.perfectContacts} perfect';
    }
    if (_won) {
      final ballsLeft = 6 - state.ballsFaced;
      final wicketsLeft = 2 - state.wickets;
      if (ballsLeft > 0) {
        return 'Won with $ballsLeft ball${ballsLeft == 1 ? '' : 's'} left';
      }
      return 'Won with $wicketsLeft wicket${wicketsLeft == 1 ? '' : 's'} left';
    }
    if (state.wickets >= 2) return 'All out';
    final short = state.cpuTarget + 1 - state.score;
    return 'Lost by $short run${short == 1 ? '' : 's'}';
  }

  String _improvementInsight(SuperOverState state) {
    final summary = state.summary;
    if (state.wickets >= 2) {
      return 'Protect the second wicket: use Ground intent when a sector is packed.';
    }
    if ((summary?.perfectContacts ?? state.perfectContacts) == 0) {
      return 'Track release and bounce longer. Perfect timing removes normal catch geometry.';
    }
    if ((summary?.openSectorHits ?? state.openGapHits) == 0) {
      return 'Read the Field Radar before run-up and attack the labelled Open sector.';
    }
    if (state.ballRecords.any(
      (ball) =>
          ball.intent?.style == ShotStyle.loft &&
          ball.outcome == ShotOutcome.caught,
    )) {
      return 'Mix in Ground shots against Packed sectors to lower interception risk.';
    }
    return 'Strong over. Build Rhythm early and save Finisher Mode for the decisive ball.';
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.won, required this.scoreAttack});

  final bool won;
  final bool scoreAttack;

  @override
  Widget build(BuildContext context) {
    final color = scoreAttack
        ? Cyber.gold
        : won
        ? Cyber.lime
        : Cyber.danger;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(color, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            scoreAttack
                ? 'SCORE LOCKED'
                : won
                ? 'CHASE COMPLETE'
                : 'CHASE FAILED',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Cyber.label(9, color: color, letterSpacing: 1.8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.cyan.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'SYS://SUPER_OVER RESULT',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            textAlign: TextAlign.end,
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
          ),
        ),
      ],
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({
    required this.won,
    required this.title,
    required this.icon,
    required this.accent,
    required this.margin,
    required this.score,
    required this.record,
    required this.grade,
    required this.finisher,
  });

  final bool won;
  final String title;
  final IconData icon;
  final Color accent;
  final String margin;
  final String score;
  final bool record;
  final String grade;
  final String? finisher;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Icon(
            icon,
            color: accent,
            size: 34,
            shadows: [
              Shadow(color: accent.withValues(alpha: 0.45), blurRadius: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Cyber.display(33, color: accent, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            margin,
            textAlign: TextAlign.center,
            style: Cyber.body(13, color: Cyber.muted, weight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            score,
            textAlign: TextAlign.center,
            style: Cyber.display(
              23,
              color: Colors.white,
              letterSpacing: 0.1,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 10),
          Text(
            finisher == null
                ? 'GRADE $grade'
                : 'FINISHER $finisher  //  GRADE $grade',
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.1),
          ),
          if (record) ...[
            const SizedBox(height: 12),
            const CyberChip(label: 'NEW HIGH SCORE', color: Cyber.gold),
          ],
        ],
      ),
    );
  }
}

class _BallTrail extends StatelessWidget {
  const _BallTrail({required this.outcomes});

  final List<ShotOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'BALL BY BALL',
                style: Cyber.label(11, color: Colors.white, letterSpacing: 1.2),
              ),
              const Spacer(),
              Text(
                '${outcomes.length}/6',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final outcome = index < outcomes.length ? outcomes[index] : null;
              return _SummaryBall(outcome: outcome);
            }),
          ),
        ],
      ),
    );
  }
}

class _SummaryBall extends StatelessWidget {
  const _SummaryBall({required this.outcome});

  final ShotOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final resolved = outcome;
    final color = resolved == null
        ? Cyber.cyan.withValues(alpha: 0.30)
        : _color(resolved);
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: resolved == null ? Cyber.panel2 : color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
        boxShadow: resolved == null
            ? null
            : Cyber.glow(color, alpha: 0.13, blur: 12, spread: -5),
      ),
      child: Center(
        child: Text(
          resolved == null ? '-' : _label(resolved),
          style: Cyber.display(
            resolved == null ? 11 : 14,
            color: resolved == null ? Cyber.muted : Cyber.bg,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Color _color(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => Cyber.gold,
      ShotOutcome.four => Cyber.lime,
      ShotOutcome.caught || ShotOutcome.bowled => Cyber.danger,
      _ => Cyber.cyan,
    };
  }

  String _label(ShotOutcome outcome) {
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
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.sixes,
    required this.fours,
    required this.perfect,
    required this.openHits,
  });

  final int sixes;
  final int fours;
  final int perfect;
  final int openHits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'SIXES', value: '$sixes', accent: Cyber.gold),
        const SizedBox(width: 8),
        _Stat(label: 'FOURS', value: '$fours', accent: Cyber.lime),
        const SizedBox(width: 8),
        _Stat(label: 'PERFECT', value: '$perfect', accent: Cyber.cyan),
        const SizedBox(width: 8),
        _Stat(label: 'OPEN', value: '$openHits', accent: Cyber.violet),
      ],
    );
  }
}

class _XpBreakdown extends StatelessWidget {
  const _XpBreakdown({required this.rewards});

  final SuperOverRewardBreakdown rewards;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, int)>[
      ('COMPLETION', rewards.completionXp),
      ('RUNS', rewards.runsXp),
      ('SIXES', rewards.sixesXp),
      ('CHASE WIN', rewards.chaseWinXp),
      ('OBJECTIVE', rewards.objectiveXp),
    ];
    return CyberPanel(
      accent: Cyber.violet,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text('XP BREAKDOWN', style: Cyber.label(10, color: Cyber.muted)),
              const Spacer(),
              Text(
                '+${rewards.totalXp} XP',
                style: Cyber.display(16, color: Cyber.violet),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              for (final entry in entries)
                Text(
                  '${entry.$1} +${entry.$2}',
                  style: Cyber.label(8, color: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.insight});

  final String insight;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_outlined, color: Cyber.cyan, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPROVEMENT INSIGHT',
                  style: Cyber.label(8, color: Cyber.cyan),
                ),
                const SizedBox(height: 4),
                Text(insight, style: Cyber.body(10, color: Cyber.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.84),
          border: Border.all(color: accent.withValues(alpha: 0.36)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Cyber.display(
                  19,
                  color: Colors.white,
                  letterSpacing: 0,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultArenaBackground extends StatefulWidget {
  const _ResultArenaBackground({required this.child});

  final Widget child;

  @override
  State<_ResultArenaBackground> createState() => _ResultArenaBackgroundState();
}

class _ResultArenaBackgroundState extends State<_ResultArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff020812), Color(0xff071522), Color(0xff02050b)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * math.pi * 2;
                return Transform.translate(
                  offset: Offset(math.sin(phase) * 7, math.cos(phase) * 5),
                  child: Transform.scale(
                    scale: 1.05 + 0.008 * math.sin(phase * 2),
                    child: child,
                  ),
                );
              },
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/backgrounds/home_stadium.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) =>
                  CustomPaint(painter: _ResultMotionPainter(_controller.value)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.28),
                    Cyber.bg.withValues(alpha: 0.12),
                    Cyber.bg.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}

class _ResultMotionPainter extends CustomPainter {
  const _ResultMotionPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;
    final pulse = 0.5 + 0.5 * math.sin(phase * 2);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.42),
          radius: 0.92,
          colors: [
            Cyber.cyan.withValues(alpha: 0.09 + pulse * 0.03),
            Cyber.violet.withValues(alpha: 0.035),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    final streak = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final travel = (progress + i * 0.067) % 1.0;
      final x = ((i * 43.0) % size.width) + math.sin(phase + i) * 16;
      final y = size.height * (0.96 - travel * 0.88);
      streak.color = Cyber.cyan.withValues(alpha: 0.025 + 0.035 * pulse);
      canvas.drawLine(Offset(x, y), Offset(x + 7, y - 16), streak);
    }
  }

  @override
  bool shouldRepaint(covariant _ResultMotionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
