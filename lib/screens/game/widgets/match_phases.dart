import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../config/tutorial_steps.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';

class TossPhase extends StatelessWidget {
  const TossPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      bottomAction: CyberCtaButton(
        label: 'Flip Coin',
        primary: true,
        onPressed: state.tossChoice == null
            ? null
            : () => context.read<GameBloc>().add(TossResolved()),
      ),
      children: [
        const SizedBox(height: 18),
        Icon(
          Icons.toll,
          size: 92,
          color: Cyber.cyan,
          shadows: [Shadow(color: Cyber.cyan, blurRadius: 18)],
        ),
        const SizedBox(height: 8),
        const Text(
          '> INITIATING TOSS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Heads',
                selected: state.tossChoice == 'heads',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('heads')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceButton(
                label: 'Tails',
                selected: state.tossChoice == 'tails',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('tails')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TossResultPhase extends StatelessWidget {
  const TossResultPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Result',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      bottomAction: state.playerWonToss == true
          ? Row(
              children: [
                Expanded(
                  child: CyberCtaButton(
                    label: 'Attack',
                    primary: true,
                    onPressed: () =>
                        context.read<GameBloc>().add(RoleChosen(true)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CyberCtaButton(
                    label: 'Defend',
                    primary: true,
                    onPressed: () =>
                        context.read<GameBloc>().add(RoleChosen(false)),
                  ),
                ),
              ],
            )
          : null,
      children: [
        const SizedBox(height: 8),
        Center(child: _CoinFlipReveal(result: state.tossResult ?? '')),
        const SizedBox(height: 8),
        InfoPanel(
          icon: Icons.toll,
          title: 'It landed ${state.tossResult?.toUpperCase()}',
          body: state.playerWonToss == true
              ? 'You won the toss. Pick your opening role.'
              : 'CPU won the toss and is choosing a role.',
        ),
        if (state.playerWonToss != true)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _CoinFlipReveal extends StatefulWidget {
  const _CoinFlipReveal({required this.result});
  final String result;

  @override
  State<_CoinFlipReveal> createState() => _CoinFlipRevealState();
}

class _CoinFlipRevealState extends State<_CoinFlipReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.coinFlip);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final angle = t * pi * 8; // four full flips
        final settle = 0.7 + 0.3 * Curves.easeOutBack.transform(_c.value);
        return Transform.scale(
          scale: settle.clamp(0.0, 1.2),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff8fe9ff), Cyber.cyan, Color(0xff1a4a5e)],
                ),
                border: Border.all(color: Cyber.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.cyan.withValues(alpha: 0.45),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: const Icon(Icons.toll, color: Cyber.bg, size: 38),
            ),
          ),
        );
      },
    );
  }
}

class ScenarioPhase extends StatelessWidget {
  const ScenarioPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final scenario = state.currentScenario;
    if (scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Scenario Briefing',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'scenario',
      tutorialSteps: scenarioTutorialSteps,
      children: [
        InfoPanel(
          icon: scenario.icon,
          title: scenario.title,
          body:
              '${scenario.description}\nAttack +${scenario.attackBonus}  Defense +${scenario.defenseBonus}\nYou are ${state.playerAttacking ? 'attacking' : 'defending'} this round.',
        ),
        _NextRoundCountdown(
          message: 'Card select starting...',
          onComplete: () => context.read<GameBloc>().add(PlayStarted()),
        ),
      ],
    );
  }
}

class PlayPhase extends StatelessWidget {
  const PlayPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerPool = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final hasCompleteSelection =
        state.selectedPlayerCard != null && state.selectedActionCard != null;
    final availablePlayers = playerPool
        .where((card) => !state.redCardedCards.contains(card.id))
        .toList();
    final availableActions = state.deckActions
        .where(
          (card) => state.playerAttacking
              ? card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special
              : card.category == ActionCategory.defense ||
                    card.category == ActionCategory.special,
        )
        .toList();
    final scenarioBonus = state.playerAttacking
        ? state.currentScenario?.attackBonus ?? 0
        : state.currentScenario?.defenseBonus ?? 0;
    final estimate =
        state.selectedPlayerCard == null || state.selectedActionCard == null
        ? null
        : state.selectedPlayerCard!.rating +
              state.selectedActionCard!.power +
              scenarioBonus;
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: state.currentScenario?.title ?? '// Play Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'play',
      tutorialSteps: playTutorialSteps,
      bottomAction: hasCompleteSelection
          ? CyberCtaButton(
              label: 'Execute Move',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(MovePlayed()),
            )
          : null,
      children: [
        RoleStrip(attacking: state.playerAttacking),
        SelectedMovePanel(
          attacking: state.playerAttacking,
          player: state.selectedPlayerCard,
          action: state.selectedActionCard,
          estimate: estimate,
        ),
        SectionLabel(
          label: state.playerAttacking
              ? 'Roster // Finishers'
              : 'Roster // Stoppers',
        ),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: availablePlayers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final card = availablePlayers[index];
              return CyberPlayerCardTile(
                card: card,
                selected: state.selectedPlayerCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(PlayerSelected(card)),
              );
            },
          ),
        ),
        const SectionLabel(label: 'Action Grid'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in availableActions)
              CyberActionCardTile(
                card: card,
                selected: state.selectedActionCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(ActionSelected(card)),
              ),
          ],
        ),
      ],
    );
  }
}

class RoundResultPhase extends StatelessWidget {
  const RoundResultPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final result = state.roundResults.last;
    return MatchPhaseScaffold(
      title: 'Round ${result.round} // Result',
      subtitle: '// Resolution Log',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'round-result',
      tutorialSteps: resultTutorialSteps,
      bottomAction: state.currentRound >= 4
          ? CyberCtaButton(
              label: 'Full-Time Result',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
            )
          : null,
      children: [
        _CinematicRoundResult(result: result),
        if (state.currentRound < 4)
          _NextRoundCountdown(
            startDelay: const Duration(milliseconds: 2300),
            onComplete: () => context.read<GameBloc>().add(RoundAdvanced()),
          ),
      ],
    );
  }
}

/// Accent color for an outcome (drives stamp + flashes).
Color outcomeColor(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => Cyber.success,
  RoundOutcome.saved => Cyber.cyan,
  RoundOutcome.blocked => Cyber.violet,
  RoundOutcome.missed => Cyber.muted,
  RoundOutcome.foul => Cyber.amber,
  RoundOutcome.redCard => Cyber.danger,
};

/// Theatrical round reveal: letterbox bars, cards slam in from the sides, a
/// pulsing VS, power bars fill, then the outcome stamp drops with a goal
/// particle burst.
class _CinematicRoundResult extends StatefulWidget {
  const _CinematicRoundResult({required this.result});
  final RoundResult result;

  @override
  State<_CinematicRoundResult> createState() => _CinematicRoundResultState();
}

class _CinematicRoundResultState extends State<_CinematicRoundResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _slammed = false;
  bool _stamped = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward();
  }

  void _onTick() {
    if (!_slammed && _c.value >= 0.16) {
      _slammed = true;
      playSound(SoundEffect.cardSlam);
    }
    if (!_stamped && _c.value >= 0.80) {
      _stamped = true;
      playSound(
        widget.result.outcome == RoundOutcome.redCard
            ? SoundEffect.redCard
            : (widget.result.outcome == RoundOutcome.goal
                  ? SoundEffect.goal
                  : SoundEffect.cardSlam),
      );
    }
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  double _interval(double a, double b, {Curve curve = Curves.easeOut}) {
    final t = ((_c.value - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final playerAttacking = r.playerAttacking;
    final playerCard = playerAttacking ? r.attackerCard : r.defenderCard;
    final oppCard = playerAttacking ? r.defenderCard : r.attackerCard;
    final playerAction = playerAttacking ? r.attackAction : r.defenseAction;
    final oppAction = playerAttacking ? r.defenseAction : r.attackAction;
    final playerPower = playerAttacking ? r.attackPower : r.defensePower;
    final oppPower = playerAttacking ? r.defensePower : r.attackPower;
    final accent = outcomeColor(r.outcome);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bars = _interval(0.0, 0.16);
        final pIn = _interval(0.16, 0.36, curve: Curves.easeOutBack);
        final oIn = _interval(0.30, 0.50, curve: Curves.easeOutBack);
        final vs = _interval(0.50, 0.64);
        final powerT = _interval(0.62, 0.82, curve: Curves.easeOutCubic);
        final stamp = _interval(0.80, 1.0, curve: Curves.easeOutBack);
        // easeOutBack overshoots <0 / >1, but Opacity requires [0,1].
        final pInO = pIn.clamp(0.0, 1.0);
        final oInO = oIn.clamp(0.0, 1.0);
        final vsO = vs.clamp(0.0, 1.0);
        final stampO = stamp.clamp(0.0, 1.0);
        final redShake = r.outcome == RoundOutcome.redCard
            ? sin(stamp * pi * 5) * 5 * (1 - stamp)
            : 0.0;

        return Transform.translate(
          offset: Offset(redShake, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35 * bars),
              border: Border.all(color: accent.withValues(alpha: 0.4 * stamp)),
            ),
            child: Column(
              children: [
                // Top letterbox bar.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(height: 14 * bars, color: Colors.black),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Transform.translate(
                            offset: Offset(-160 * (1 - pIn), 0),
                            child: Opacity(
                              opacity: pInO,
                              child: _RevealCardColumn(
                                label: 'YOU',
                                labelColor: Cyber.cyan,
                                card: playerCard,
                                action: playerAction,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(160 * (1 - oIn), 0),
                            child: Opacity(
                              opacity: oInO,
                              child: _RevealCardColumn(
                                label: 'CPU',
                                labelColor: Cyber.amber,
                                card: oppCard,
                                action: oppAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // VS marker.
                      Transform.scale(
                        scale: 0.6 + 0.4 * vs + 0.06 * sin(vs * pi),
                        child: Opacity(
                          opacity: vsO,
                          child: Text(
                            'VS',
                            style: Cyber.display(30, color: Cyber.gold)
                                .copyWith(
                                  shadows: [
                                    const Shadow(
                                      color: Cyber.gold,
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Power bars.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      _PowerBar(
                        label: 'YOUR POWER',
                        value: playerPower,
                        progress: powerT,
                        color: Cyber.cyan,
                      ),
                      const SizedBox(height: 6),
                      _PowerBar(
                        label: 'OPPONENT POWER',
                        value: oppPower,
                        progress: powerT,
                        color: Cyber.amber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Outcome stamp + goal particle burst.
                SizedBox(
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (r.outcome == RoundOutcome.goal && stamp > 0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BurstPainter(stamp, accent),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(0, -50 * (1 - stamp)),
                        child: Transform.rotate(
                          angle: -3 * pi / 180,
                          child: Opacity(
                            opacity: stampO,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                border: Border.all(color: accent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.5),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: Text(
                                outcomeLabel(r.outcome).toUpperCase(),
                                style: Cyber.display(
                                  36,
                                  color: accent,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom letterbox bar.
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(height: 14 * bars, color: Colors.black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevealCardColumn extends StatelessWidget {
  const _RevealCardColumn({
    required this.label,
    required this.labelColor,
    required this.card,
    required this.action,
  });

  final String label;
  final Color labelColor;
  final PlayerCard card;
  final ActionCard action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Cyber.display(13, color: labelColor, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        CyberPlayerCardTile(card: card, selected: false),
        const SizedBox(height: 6),
        CyberChip(label: action.title, color: actionColor(action.category)),
      ],
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final double value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Normalize against a plausible max power (~150) for the fill width.
    final fill = (value / 150).clamp(0.0, 1.0) * progress;
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Cyber.bg2,
              border: Border.all(color: Cyber.borderSubtle),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            (value * progress).toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: Cyber.display(18, color: color, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0, 1));
    final rng = Random(7);
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * pi + rng.nextDouble();
      final dist = 90 * t * (0.6 + rng.nextDouble() * 0.6);
      final p = center + Offset(cos(angle), sin(angle)) * dist;
      final s = 5 * (1 - t) + 2;
      canvas.drawRect(Rect.fromCenter(center: p, width: s, height: s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

class _NextRoundCountdown extends StatefulWidget {
  const _NextRoundCountdown({
    required this.onComplete,
    this.startDelay = Duration.zero,
    this.message = 'Next round starting...',
  });
  final VoidCallback onComplete;
  final Duration startDelay;
  final String message;

  @override
  State<_NextRoundCountdown> createState() => _NextRoundCountdownState();
}

class _NextRoundCountdownState extends State<_NextRoundCountdown> {
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    if (widget.startDelay > Duration.zero) {
      await Future<void>.delayed(widget.startDelay);
      if (!mounted) return;
    }
    for (var i = 3; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds = i - 1);
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _seconds > 0 ? '$_seconds' : 'Go!',
          style: const TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 48,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.message,
          style: const TextStyle(color: Cyber.line, fontSize: 13),
        ),
      ],
    );
  }
}

class MatchEndPhase extends StatelessWidget {
  const MatchEndPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final tied = state.playerScore == state.opponentScore;
    final won = state.playerScore > state.opponentScore;
    final title = tied ? 'DEADLOCK' : (won ? 'VICTORY' : 'DEFEAT');
    final accent = tied ? Cyber.amber : (won ? Cyber.success : Cyber.danger);
    return MatchPhaseScaffold(
      title: 'Full Time',
      subtitle: '// Match Archive',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'match-end',
      tutorialSteps: matchEndTutorialSteps,
      bottomAction: CyberCtaButton(
        label: tied ? 'Penalty Shootout' : 'Finish Match',
        primary: true,
        onPressed: () => context.read<GameBloc>().add(
          tied ? PenaltyStarted() : MatchFinished(),
        ),
      ),
      children: [
        const SizedBox(height: 8),
        // Outcome banner.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 24),
            ],
          ),
          child: Column(
            children: [
              Icon(
                tied
                    ? Icons.balance
                    : (won ? Icons.emoji_events : Icons.sentiment_dissatisfied),
                color: accent,
                size: 36,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: Cyber.display(40, color: accent, letterSpacing: 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Giant scoreline.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${state.playerScore}',
              style: Cyber.display(72, color: Cyber.cyan),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('-', style: Cyber.display(48, color: Cyber.muted)),
            ),
            Text(
              '${state.opponentScore}',
              style: Cyber.display(72, color: Cyber.danger),
            ),
          ],
        ),
        if (tied)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'The match is level - settle it from the spot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cyber.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ─── Match Intro ─────────────────────────────────────────────────────────────

class MatchIntroPhase extends StatefulWidget {
  const MatchIntroPhase({
    required this.deckName,
    required this.onComplete,
    super.key,
  });

  final String deckName;
  final VoidCallback onComplete;

  @override
  State<MatchIntroPhase> createState() => _MatchIntroPhaseState();
}

class _MatchIntroPhaseState extends State<MatchIntroPhase>
    with TickerProviderStateMixin {
  // 0 = cinematic reveal, 1 = countdown, 2 = kick off
  int _stage = 0;
  int _countdown = 3;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _kickoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener(_onRevealDone);
    _reveal.forward();
  }

  void _onRevealDone(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    setState(() {
      _stage = 1;
      _countdown = 3;
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      _pulse
        ..reset()
        ..forward();
      playSound(SoundEffect.cardSlam);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _stage = 2);
    _kickoff.forward();
    playSound(SoundEffect.goal);
    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _reveal
      ..removeStatusListener(_onRevealDone)
      ..dispose();
    _pulse.dispose();
    _kickoff.dispose();
    super.dispose();
  }

  // Interpolate a sub-interval of _reveal.value with an optional curve.
  double _rv(double a, double b, {Curve curve = Curves.easeOut}) =>
      curve.transform(((_reveal.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _pulse, _kickoff]),
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            if (_stage == 0) _buildReveal(context),
            if (_stage == 1) _buildCountdown(),
            if (_stage == 2) _buildKickoff(),
          ],
        ),
      ),
    );
  }

  // ── Stage 0: cinematic reveal ──────────────────────────────────────────────
  Widget _buildReveal(BuildContext context) {
    final gridIn = _rv(0.00, 0.30);
    final scanLine = _rv(0.08, 0.64);
    final titleIn = _rv(0.22, 0.52, curve: Curves.easeOutCubic);
    final subtitleIn = _rv(0.40, 0.70);
    final sidesIn = _rv(0.55, 1.00, curve: Curves.easeOutCubic);
    final screenH = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle grid
        CustomPaint(painter: _GridPainter(gridIn)),
        // Horizontal scan sweep
        Positioned(
          top: screenH * scanLine,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: Cyber.cyan,
              boxShadow: [
                BoxShadow(
                  color: Cyber.cyan.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // Centre: title + subtitle + VS badges
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Game title
              Transform.scale(
                scale: 0.72 + 0.28 * titleIn,
                child: Opacity(
                  opacity: titleIn.clamp(0.0, 1.0),
                  child: Text(
                    'CYBER REACT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Cyber.cyan,
                      fontFamily: 'Orbitron',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Cyber.cyan.withValues(alpha: titleIn * 0.85),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: subtitleIn.clamp(0.0, 1.0),
                child: Text(
                  '// MATCH PROTOCOL INITIATED',
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.58),
                    fontFamily: 'Orbitron',
                    fontSize: 10,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // YOU vs CPU badges
              Opacity(
                opacity: sidesIn.clamp(0.0, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(-38 * (1 - sidesIn), 0),
                      child: _VsBadge(
                        label: 'YOU',
                        sub: widget.deckName,
                        color: Cyber.lime,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'VS',
                        style: Cyber.display(24, color: Cyber.gold).copyWith(
                          shadows: [
                            const Shadow(color: Cyber.gold, blurRadius: 20),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(38 * (1 - sidesIn), 0),
                      child: const _VsBadge(
                        label: 'CPU',
                        sub: 'Opponent',
                        color: Cyber.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 1: 3-2-1 countdown ───────────────────────────────────────────────
  Widget _buildCountdown() {
    final p = _pulse.value;

    // Scale: slams from 2.0 → 1.0 in first 25%, holds, then expands + fades.
    final double scale;
    final double opacity;
    if (p < 0.25) {
      scale = 2.0 - Curves.easeOutBack.transform(p / 0.25);
      opacity = 1.0;
    } else if (p < 0.82) {
      scale = 1.0;
      opacity = 1.0;
    } else {
      final t = (p - 0.82) / 0.18;
      scale = 1.0 + 0.18 * t;
      opacity = 1.0 - t;
    }
    final glow = (1 - (p / 0.45).clamp(0.0, 1.0)) * 0.85 + 0.15;

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GridPainter(0.55)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCH STARTING IN',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.55),
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 18),
              Transform.scale(
                scale: scale.clamp(0.4, 2.5),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    '$_countdown',
                    style: TextStyle(
                      color: Cyber.lime,
                      fontFamily: 'Orbitron',
                      fontSize: 128,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Cyber.lime.withValues(alpha: glow),
                          blurRadius: 52,
                        ),
                        Shadow(
                          color: Cyber.cyan.withValues(alpha: glow * 0.55),
                          blurRadius: 80,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 2: KICK OFF stamp ────────────────────────────────────────────────
  Widget _buildKickoff() {
    final k = Curves.easeOutBack.transform(_kickoff.value);
    final flash = (1 - (_kickoff.value / 0.38).clamp(0.0, 1.0)) * 0.55;

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GridPainter(0.55)),
        // Flash overlay
        Container(color: Cyber.lime.withValues(alpha: flash.clamp(0.0, 1.0))),
        Center(
          child: Transform.translate(
            offset: Offset(0, -90 * (1 - k.clamp(0.0, 1.0))),
            child: Transform.scale(
              scale: (0.35 + 0.65 * k).clamp(0.0, 1.5),
              child: Opacity(
                opacity: k.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Cyber.lime.withValues(alpha: 0.13),
                    border: Border.all(color: Cyber.lime, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.lime.withValues(alpha: 0.6),
                        blurRadius: 44,
                      ),
                    ],
                  ),
                  child: Text(
                    'KICK OFF!',
                    style:
                        Cyber.display(
                          42,
                          color: Cyber.lime,
                          letterSpacing: 4,
                        ).copyWith(
                          shadows: [
                            const Shadow(color: Cyber.lime, blurRadius: 22),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.label, required this.sub, required this.color});

  final String label;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.65),
              fontFamily: 'Orbitron',
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.07 * opacity)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x <= size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.opacity != opacity;
}
