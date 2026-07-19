import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_state.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/level_up_celebration.dart';
import '../../../widgets/match_widgets.dart';

/// Shootout summary: outcome, PEN scoreline, XP earned, and the kick log.
/// XP/level data is read from [GameBloc] (updated by ShootoutFinished).
class ShootoutResultPhase extends StatefulWidget {
  const ShootoutResultPhase({
    required this.state,
    required this.onPlayAgain,
    required this.onHome,
    super.key,
  });

  final ShootoutState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  State<ShootoutResultPhase> createState() => _ShootoutResultPhaseState();
}

class _ShootoutResultPhaseState extends State<ShootoutResultPhase>
    with TickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late final Animation<double> _bannerOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
  );

  late final Animation<double> _scoreScale = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.12, 0.35, curve: Curves.easeOutBack),
  );

  late final Animation<double> _xpPanelOpacity = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.28, 0.48, curve: Curves.easeOut),
  );

  late final Animation<double> _xpBarProgress = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.50, 0.82, curve: Curves.easeInOut),
  );

  bool _showLevelUp = false;

  static const _dirLabel = {
    PenaltyDirection.left: 'L',
    PenaltyDirection.center: 'C',
    PenaltyDirection.right: 'R',
  };

  @override
  void initState() {
    super.initState();
    _seq.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          context.read<GameBloc>().state.hasLevelUp) {
        setState(() => _showLevelUp = true);
      }
    });
    _seq.forward();

    final won = widget.state.winner == 'player';
    playSound(won ? SoundEffect.matchWin : SoundEffect.matchLose);
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final won = s.winner == 'player';

    return BlocBuilder<GameBloc, GameState>(
      builder: (context, game) {
        final prev = game.previousProgression ?? game.progression;
        final oldRatio = prev.xpToNextLevel == 0
            ? 0.0
            : prev.xpIntoLevel / prev.xpToNextLevel;
        final newRatio = game.progression.xpToNextLevel == 0
            ? 0.0
            : game.progression.xpIntoLevel / game.progression.xpToNextLevel;
        final xpDelta = game.lastMatchXP ?? 0;

        return GameScaffold(
          title: 'Shootout Over',
          showTitle: true,
          grain: true,
          compactHeader: true,
          rightSlot: MatchHeaderScore(
            label: 'PEN ${s.playerScore}-${s.opponentScore}',
            playerScore: s.playerScore,
            opponentScore: s.opponentScore,
          ),
          leading: IconButton(
            onPressed: widget.onHome,
            icon: const Icon(Icons.close, color: Cyber.cyan),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: StadiumBackground()),
              AnimatedBuilder(
                animation: _seq,
                builder: (context, _) {
                  final tickerT = ((_seq.value - 0.38) / 0.40).clamp(0.0, 1.0);
                  final displayedXP = (xpDelta.abs() * tickerT).round();
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
                          child: _ShootoutOutcomeBanner(won: won),
                        ),
                        const SizedBox(height: 14),
                        ScaleTransition(
                          scale: _scoreScale,
                          child: _PenScoreline(
                            playerScore: s.playerScore,
                            opponentScore: s.opponentScore,
                            suddenDeath: s.suddenDeath,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _xpPanelOpacity,
                          child: _ShootoutXpPanel(
                            xpDelta: xpDelta,
                            displayedCount: displayedXP,
                            barFillRatio: barFill,
                            level: game.progression.playerLevel,
                            xpIntoLevel: game.progression.xpIntoLevel,
                            xpToNextLevel: game.progression.xpToNextLevel,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _KickLogSection(
                          kicks: s.kicks,
                          dirLabel: _dirLabel,
                          opponentName: s.opponentName,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ShootoutFooterDock(
                  onPlayAgain: widget.onPlayAgain,
                  onHome: widget.onHome,
                ),
              ),
              if (_showLevelUp)
                LevelUpCelebration(
                  levels: game.pendingLevelUps,
                  progression: game.progression,
                  xpEarned: game.lastMatchXP ?? 0,
                  onDismissed: () => setState(() => _showLevelUp = false),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Outcome banner ────────────────────────────────────────────────────────────

class _ShootoutOutcomeBanner extends StatelessWidget {
  const _ShootoutOutcomeBanner({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    final accent = won ? Cyber.success : Cyber.danger;
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
            won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            color: accent,
            size: 36,
          ),
          const SizedBox(height: 6),
          Text(
            won ? 'SHOOTOUT WON' : 'SHOOTOUT LOST',
            style: Cyber.display(32, color: accent, letterSpacing: 3),
          ),
        ],
      ),
    );
  }
}

// ── PEN scoreline ─────────────────────────────────────────────────────────────

class _PenScoreline extends StatelessWidget {
  const _PenScoreline({
    required this.playerScore,
    required this.opponentScore,
    required this.suddenDeath,
  });

  final int playerScore;
  final int opponentScore;
  final bool suddenDeath;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$playerScore', style: Cyber.display(72, color: Cyber.cyan)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('-', style: Cyber.display(48, color: Cyber.muted)),
            ),
            Text(
              '$opponentScore',
              style: Cyber.display(72, color: Cyber.danger),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          suddenDeath ? 'DECIDED IN SUDDEN DEATH' : 'PENALTIES',
          style: Cyber.label(
            11,
            color: Cyber.cyan,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Footer dock (PLAY AGAIN | HOME) ───────────────────────────────────────────

class _ShootoutFooterDock extends StatelessWidget {
  const _ShootoutFooterDock({required this.onPlayAgain, required this.onHome});

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
                child: CyberCtaButton(
                  label: 'PLAY AGAIN',
                  primary: true,
                  onPressed: onPlayAgain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CyberCtaButton(label: 'HOME', onPressed: onHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── XP panel ──────────────────────────────────────────────────────────────────

class _ShootoutXpPanel extends StatelessWidget {
  const _ShootoutXpPanel({
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
    final gained = xpDelta >= 0;
    final accentColor = gained ? Cyber.cyan : const Color(0xFFFF4D6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gained ? '+$displayedCount XP' : '−$displayedCount XP',
            style: const TextStyle(
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

// ── Kick log (with shooter names) ─────────────────────────────────────────────

class _KickLogSection extends StatelessWidget {
  const _KickLogSection({
    required this.kicks,
    required this.dirLabel,
    required this.opponentName,
  });

  final List<PenaltyKick> kicks;
  final Map<PenaltyDirection, String> dirLabel;
  final String opponentName;

  static final _headerStyle = Cyber.label(
    10,
    color: Colors.white38,
    weight: FontWeight.w700,
    letterSpacing: 1,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KICK LOG',
          style: Cyber.label(12, color: Cyber.cyan, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: _headerStyle)),
                    Expanded(child: Text('TAKER', style: _headerStyle)),
                    SizedBox(
                      width: 44,
                      child: Text(
                        'SHOOT',
                        style: _headerStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        'DIVE',
                        style: _headerStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E3A5F)),
              for (final kick in kicks)
                _KickLogRow(
                  kick: kick,
                  dirLabel: dirLabel,
                  opponentName: opponentName,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KickLogRow extends StatelessWidget {
  const _KickLogRow({
    required this.kick,
    required this.dirLabel,
    required this.opponentName,
  });
  final PenaltyKick kick;
  final Map<PenaltyDirection, String> dirLabel;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final goalColor = kick.scored
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF1744);
    final takerName =
        kick.shooter?.shortName.toUpperCase() ??
        (kick.byPlayer ? 'YOU' : opponentName.toUpperCase());
    return Container(
      color: kick.scored
          ? const Color(0xFF00E5FF).withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${kick.kickNumber}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              takerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(
                11,
                color: kick.byPlayer ? Cyber.cyan : Colors.orange,
                weight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              dirLabel[kick.shootDirection]!,
              style: TextStyle(
                color: goalColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              dirLabel[kick.diveDirection]!,
              style: const TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Icon(
              kick.scored ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: goalColor,
            ),
          ),
        ],
      ),
    );
  }
}
