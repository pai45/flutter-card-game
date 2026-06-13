import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/level_up_celebration.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/spotlight_walkthrough.dart';

/// Unified full-time screen: victory, scoreline, XP, MVP, and match logs.
class FinalResultPhase extends StatefulWidget {
  const FinalResultPhase({
    required this.state,
    required this.onNavigate,
    super.key,
  });

  final GameState state;
  final ValueChanged<AppSection> onNavigate;

  @override
  State<FinalResultPhase> createState() => _FinalResultPhaseState();
}

class _FinalResultPhaseState extends State<FinalResultPhase>
    with TickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _bannerOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
  );

  late final Animation<double> _scoreScale = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.12, 0.35, curve: Curves.easeOutBack),
  );

  late final Animation<Offset> _xpPanelSlide = Tween<Offset>(
    begin: const Offset(0, 0.5),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.28, 0.50, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _xpPanelOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.28, 0.48, curve: Curves.easeOut),
  );

  late final Animation<double> _xpBarProgress = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.50, 0.82, curve: Curves.easeInOut),
  );

  late final int _oldXpIntoLevel;
  late final int _oldXpToNextLevel;
  bool _showLevelUp = false;
  final _bannerKey = GlobalKey();
  final _actionsKey = GlobalKey();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _bannerKey,
      title: 'Full Time',
      body: 'Final score, XP earned, and match recap.',
      icon: Icons.emoji_events,
      accent: Cyber.cyan,
    ),
    SpotlightStep(
      targetKey: _actionsKey,
      title: 'What\'s Next',
      body: 'Play Again or head Home.',
      icon: Icons.home,
      accent: Cyber.lime,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final prev = widget.state.previousProgression;
    assert(prev != null, 'previousProgression must be set at finalResult phase');
    _oldXpIntoLevel = prev!.xpIntoLevel;
    _oldXpToNextLevel = prev.xpToNextLevel;

    _seq.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          widget.state.hasLevelUp) {
        setState(() => _showLevelUp = true);
      }
    });
    _seq.forward();

    final s = widget.state;
    final won = s.playerScore > s.opponentScore;
    final drawn = s.playerScore == s.opponentScore;
    playSound(
      won
          ? SoundEffect.matchWin
          : drawn
          ? SoundEffect.bannerSlam
          : SoundEffect.matchLose,
    );
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final won = state.playerScore > state.opponentScore;
    final drawn = state.playerScore == state.opponentScore;
    final mvp = state.roundResults
        .where(
          (round) =>
              round.outcome == RoundOutcome.goal && round.playerAttacking,
        )
        .map((round) => round.attackerCard)
        .firstOrNull;

    final List<({int p, int c})> runningScores = [];
    var pGoals = 0, cGoals = 0;
    for (final r in state.roundResults) {
      if (r.outcome == RoundOutcome.goal) {
        if (r.playerAttacking) {
          pGoals++;
        } else {
          cGoals++;
        }
      }
      runningScores.add((p: pGoals, c: cGoals));
    }

    final outcomeTitle = drawn ? 'DRAW' : (won ? 'VICTORY' : 'DEFEAT');
    final outcomeAccent = drawn
        ? Cyber.amber
        : won
        ? Cyber.success
        : Cyber.danger;

    return GameScaffold(
      title: 'Full Time',
      showTitle: true,
      grain: true,
      compactHeader: true,
      rightSlot: MatchHeaderScore(
        playerScore: state.playerScore,
        opponentScore: state.opponentScore,
      ),
      leading: IconButton(
        onPressed: () {
          context.read<GameBloc>().add(MatchReset());
          widget.onNavigate(AppSection.home);
        },
        icon: const Icon(Icons.close, color: Cyber.cyan),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: StadiumBackground()),
          AnimatedBuilder(
            animation: _seq,
            builder: (context, _) {
              final tickerT = ((_seq.value - 0.38) / 0.40).clamp(0.0, 1.0);
              final displayedXP = (state.lastMatchXP!.abs() * tickerT).round();
              final oldRatio = _oldXpIntoLevel / _oldXpToNextLevel;
              final newRatio =
                  state.progression.xpIntoLevel / state.progression.xpToNextLevel;
              final barFill =
                  (oldRatio + (newRatio - oldRatio) * _xpBarProgress.value)
                      .clamp(0.0, 1.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeTransition(
                      opacity: _bannerOpacity,
                      child: SpotlightTarget(
                        spotlightKey: _bannerKey,
                        child: _OutcomeBanner(
                          title: outcomeTitle,
                          accent: outcomeAccent,
                          won: won,
                          drawn: drawn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ScaleTransition(
                      scale: _scoreScale,
                      child: _GiantScoreline(
                        playerScore: state.playerScore,
                        opponentScore: state.opponentScore,
                      ),
                    ),
                    if (state.lastMatchXP != null) ...[
                      const SizedBox(height: 14),
                      SlideTransition(
                        position: _xpPanelSlide,
                        child: FadeTransition(
                          opacity: _xpPanelOpacity,
                          child: _XpProgressPanel(
                            xpDelta: state.lastMatchXP!,
                            displayedCount: displayedXP,
                            barFillRatio: barFill,
                            level: state.progression.playerLevel,
                            xpIntoLevel: state.progression.xpIntoLevel,
                            xpToNextLevel: state.progression.xpToNextLevel,
                          ),
                        ),
                      ),
                    ],
                    if (mvp != null) ...[
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'MVP',
                            style: Cyber.label(
                              12,
                              color: Cyber.cyan,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CyberPlayerCardTile(card: mvp, selected: true),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _RoundLogHeader(count: state.roundResults.length),
                    if (state.roundResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _RoundGoalTrail(rounds: state.roundResults),
                    ],
                    for (var i = 0; i < state.roundResults.length; i++) ...[
                      const SizedBox(height: 4),
                      _FinalRoundLogItem(
                        round: state.roundResults[i],
                        playerGoals: runningScores[i].p,
                        cpuGoals: runningScores[i].c,
                        index: i,
                        isLast: i == state.roundResults.length - 1,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SpotlightTarget(
              spotlightKey: _actionsKey,
              child: _ResultFooterDock(
                onPlayAgain: () {
                  context.read<GameBloc>().add(MatchStarted());
                },
                onHome: () {
                  context.read<GameBloc>().add(MatchReset());
                  widget.onNavigate(AppSection.home);
                },
              ),
            ),
          ),
          SpotlightTutorial(
            keyName: 'final',
            steps: _spotlightSteps,
            startDelay: const Duration(milliseconds: 1400),
          ),
          if (_showLevelUp)
            LevelUpCelebration(
              levels: widget.state.pendingLevelUps,
              onDismissed: () => setState(() => _showLevelUp = false),
            ),
        ],
      ),
    );
  }

}

// ── Outcome banner ────────────────────────────────────────────────────────────

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({
    required this.title,
    required this.accent,
    required this.won,
    required this.drawn,
  });

  final String title;
  final Color accent;
  final bool won;
  final bool drawn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            drawn
                ? Icons.balance
                : won
                ? Icons.emoji_events
                : Icons.sentiment_dissatisfied,
            color: accent,
            size: 36,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Cyber.display(36, color: accent, letterSpacing: 3),
          ),
        ],
      ),
    );
  }
}

// ── Giant scoreline ─────────────────────────────────────────────────────────────

class _GiantScoreline extends StatelessWidget {
  const _GiantScoreline({
    required this.playerScore,
    required this.opponentScore,
  });

  final int playerScore;
  final int opponentScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$playerScore',
          style: Cyber.display(72, color: Cyber.cyan),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('-', style: Cyber.display(48, color: Cyber.muted)),
        ),
        Text(
          '$opponentScore',
          style: Cyber.display(72, color: Cyber.danger),
        ),
      ],
    );
  }
}

// ── Fixed footer dock (PLAY AGAIN | HOME) ─────────────────────────────────────

class _ResultFooterDock extends StatelessWidget {
  const _ResultFooterDock({
    required this.onPlayAgain,
    required this.onHome,
  });

  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF010517), Color(0xF2010517), Color(0x00010517)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: _ResultDockButton(
                  label: 'PLAY AGAIN',
                  leadingIcon: Icons.refresh,
                  focal: true,
                  onTap: onPlayAgain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ResultDockButton(
                  label: 'HOME',
                  leadingIcon: Icons.home_outlined,
                  focal: false,
                  onTap: onHome,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultDockButton extends StatelessWidget {
  const _ResultDockButton({
    required this.label,
    required this.focal,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool focal;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final Color content = focal ? const Color(0xff06121b) : Cyber.cyan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: CustomPaint(
          painter: _ResultDockBtnPainter(focal: focal),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, color: content, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Cyber.body(
                  15,
                  color: content,
                  weight: FontWeight.w800,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultDockBtnPainter extends CustomPainter {
  const _ResultDockBtnPainter({required this.focal});
  final bool focal;

  static const _clipper = HudChamferClipper(bigCut: 14, smallCut: 7);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _clipper.buildPath(size);
    if (focal) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(Cyber.cyan, Colors.white, 0.28)!, Cyber.cyan],
          ).createShader(Offset.zero & size),
      );
    } else {
      canvas.drawPath(path, Paint()..color = const Color(0xff1b2336));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Cyber.cyan.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResultDockBtnPainter old) =>
      old.focal != focal;
}

// ── XP panel ──────────────────────────────────────────────────────────────────

class _XpProgressPanel extends StatelessWidget {
  const _XpProgressPanel({
    required this.xpDelta,
    required this.displayedCount,
    required this.barFillRatio,
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
  });

  final int xpDelta;
  final int displayedCount;
  final double barFillRatio;
  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;

  @override
  Widget build(BuildContext context) {
    final isWin = xpDelta >= 0;
    final accentColor = isWin ? Cyber.cyan : const Color(0xFFFF4D6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isWin ? '+$displayedCount XP' : '−$displayedCount XP',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: barFillRatio,
            accent: accentColor,
            height: 6,
            radius: 3,
            animate: false,
            trackColor: accentColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            '$xpIntoLevel / $xpToNextLevel XP · LEVEL $level',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Match log ─────────────────────────────────────────────────────────────────

class _RoundLogHeader extends StatelessWidget {
  const _RoundLogHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MATCH LOG',
          style: Cyber.label(12, color: Cyber.cyan, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Text(
          '$count ROUNDS PLAYED',
          style: Cyber.label(10, color: Colors.white38, letterSpacing: 1),
        ),
      ],
    );
  }
}

class _RoundGoalTrail extends StatelessWidget {
  const _RoundGoalTrail({required this.rounds});
  final List<RoundResult> rounds;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < rounds.length; i++)
          Expanded(
            child: _RoundGoalDot(
              hasGoal: rounds[i].outcome == RoundOutcome.goal,
              playerScored: rounds[i].playerAttacking,
              index: i,
            ),
          ),
      ],
    );
  }
}

class _RoundGoalDot extends StatelessWidget {
  const _RoundGoalDot({
    required this.hasGoal,
    required this.playerScored,
    required this.index,
  });

  final bool hasGoal;
  final bool playerScored;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = hasGoal
        ? (playerScored ? Cyber.cyan : Colors.orange)
        : Colors.white.withValues(alpha: 0.2);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  if (hasGoal)
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinalRoundLogItem extends StatelessWidget {
  const _FinalRoundLogItem({
    required this.round,
    required this.playerGoals,
    required this.cpuGoals,
    required this.index,
    required this.isLast,
  });

  final RoundResult round;
  final int playerGoals;
  final int cpuGoals;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isGoal = round.outcome == RoundOutcome.goal;
    final goalColor = isGoal
        ? (round.playerAttacking ? Cyber.cyan : Colors.orange)
        : Colors.white38;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.28, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: AlwaysStoppedAnimation(value),
              curve: Curves.linear,
            ),
          ),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        color: isGoal
            ? (round.playerAttacking
                ? Cyber.cyan.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.08))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                'R${round.round}',
                style: Cyber.label(
                  10,
                  color: Cyber.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Text(
                round.scenario.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                outcomeLabel(round.outcome),
                style: TextStyle(
                  color: goalColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                '$playerGoals - $cpuGoals',
                style: Cyber.display(14, color: Colors.white, letterSpacing: 1),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
