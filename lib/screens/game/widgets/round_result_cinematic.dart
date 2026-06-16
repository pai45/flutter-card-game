import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Matches [CyberPlayerCardTile] at [VisualCardSize.lg] (1.5× the sm tile).
const _kClashCardW = 144.0;
const _kClashCardH = 216.0;

/// Extra headroom for the clash tilt.
const _kClashStackH = _kClashCardH + 12.0;

/// Reserved row height for action chips (prevents layout jump when they appear).
const _kActionRowH = 32.0;

/// Reserved height for the verdict hero zone (icon row + 2-line narration).
const _kVerdictH = 120.0;

// ── Beat thresholds (kept in sync with [RoundClashArenaState.jumpToProgress]) ──
const _kPowerOnEnd = 0.10;
const _kApproachEnd = 0.28;
const _kClashEnd = 0.42;
const _kCompareEnd = 0.66;
const _kVerdictStart = 0.68;
const _kVerdictEnd = 0.86;

/// Six-beat round reveal: power-on → approach → clash → power duel → verdict →
/// score impact. The clash cinematic plays once, then the composition settles
/// into a dense HUD "resolution" panel that pays off by ticking the scoreline.
class RoundClashArena extends StatefulWidget {
  const RoundClashArena({
    required this.result,
    required this.playerScore,
    required this.opponentScore,
    this.onComplete,
    super.key,
  });

  final RoundResult result;

  /// Running match totals AFTER this round (used by the score-impact beat).
  final int playerScore;
  final int opponentScore;
  final VoidCallback? onComplete;

  @override
  State<RoundClashArena> createState() => RoundClashArenaState();
}

@visibleForTesting
class RoundClashArenaState extends State<RoundClashArena>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4600);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  );

  /// Full-bleed payoff stinger (GOAL! / DENIED!) fired at the verdict beat.
  late final AnimationController _stinger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  _StingerKind? get _stingerKind => switch (widget.result.outcome) {
    RoundOutcome.goal => _StingerKind.goal,
    RoundOutcome.saved || RoundOutcome.blocked => _StingerKind.denied,
    _ => null,
  };

  bool _clashFired = false;
  bool _meterFired = false;
  bool _verdictFired = false;
  bool _scoreFired = false;
  bool _started = false;
  bool _completeNotified = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _clashFired = true;
      _meterFired = true;
      _verdictFired = true;
      _scoreFired = true;
      _c.value = 1.0;
      _fireClashSounds();
      _fireMeterHaptic();
      _fireVerdictSounds();
      _fireScoreHaptic();
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _notifyComplete();
      });
    } else {
      _c.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _notifyComplete();
  }

  void _notifyComplete() {
    if (_completeNotified) return;
    _completeNotified = true;
    widget.onComplete?.call();
  }

  void _onTick() {
    if (!_clashFired && _c.value >= _kApproachEnd) {
      _clashFired = true;
      _fireClashSounds();
    }
    if (!_meterFired && _c.value >= _kCompareEnd) {
      _meterFired = true;
      _fireMeterHaptic();
    }
    if (!_verdictFired && _c.value >= _kVerdictStart) {
      _verdictFired = true;
      _fireVerdictSounds();
      if (_stingerKind != null) _stinger.forward(from: 0);
    }
    if (!_scoreFired && _c.value >= _kVerdictEnd) {
      _scoreFired = true;
      _fireScoreHaptic();
    }
  }

  void _fireClashSounds() {
    playSound(SoundEffect.cardSlam);
    playSound(SoundEffect.whoosh);
    HapticFeedback.heavyImpact();
  }

  void _fireMeterHaptic() {
    HapticFeedback.mediumImpact();
  }

  void _fireVerdictSounds() {
    playSound(switch (widget.result.outcome) {
      RoundOutcome.redCard => SoundEffect.redCard,
      RoundOutcome.goal => SoundEffect.goal,
      RoundOutcome.saved || RoundOutcome.blocked => SoundEffect.save,
      _ => SoundEffect.cardSlam,
    });
    if (widget.result.outcome == RoundOutcome.goal ||
        widget.result.outcome == RoundOutcome.redCard) {
      HapticFeedback.heavyImpact();
    }
  }

  void _fireScoreHaptic() {
    // The scoreline only changes on a goal — pop a light tick when it ticks up.
    if (widget.result.outcome == RoundOutcome.goal) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
    _stinger.dispose();
    super.dispose();
  }

  double _interval(double a, double b, {Curve curve = Curves.easeOut}) {
    if (_c.value <= a) return 0;
    if (_c.value >= b) return 1;
    final t = ((_c.value - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  /// Jump the cinematic timeline for widget tests / golden previews.
  @visibleForTesting
  void jumpToProgress(double progress) {
    final t = progress.clamp(0.0, 1.0);
    _clashFired = t >= _kApproachEnd;
    _meterFired = t >= _kCompareEnd;
    _verdictFired = t >= _kVerdictStart;
    _scoreFired = t >= _kVerdictEnd;
    _c.value = t;
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
    final playerAccent = roleAccent(playerAttacking);
    final oppAccent = roleAccent(!playerAttacking);
    final playerRole = playerAttacking ? 'ATTACK' : 'DEFEND';
    final oppRole = playerAttacking ? 'DEFEND' : 'ATTACK';
    final outcomeAccent = outcomeColor(r.outcome);

    // A goal is scored by the attacker; everything else leaves the score held.
    final goalScored = r.outcome == RoundOutcome.goal;
    final scoringIsPlayer = playerAttacking;

    // Side-aware stinger tint: your goal celebrates, a conceded goal alarms,
    // and a save is always the keeper's violet moment.
    final stingerAccent = switch (_stingerKind) {
      _StingerKind.goal => scoringIsPlayer ? Cyber.lime : Cyber.danger,
      _StingerKind.denied => Cyber.violet,
      null => Colors.transparent,
    };

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final powerOnT = _interval(0.0, _kPowerOnEnd, curve: Curves.easeOut);
        final approachT = _interval(
          _kPowerOnEnd,
          _kApproachEnd,
          curve: Curves.easeOut,
        );
        final clashT = _interval(
          _kApproachEnd,
          _kClashEnd,
          curve: Curves.easeOutBack,
        );
        final compareT = _interval(
          _kClashEnd,
          _kCompareEnd,
          curve: Curves.easeOutCubic,
        );
        final deflated = r.outcome == RoundOutcome.missed;
        final verdictT = _interval(
          _kVerdictStart,
          _kVerdictEnd,
          curve: deflated ? Curves.easeOut : Curves.easeOutBack,
        );
        final scoreT = _interval(_kVerdictEnd, 1.0, curve: Curves.easeOutCubic);

        final clashWindow = _kClashEnd - _kApproachEnd;
        final clashProgress = _c.value >= _kApproachEnd && _c.value < _kClashEnd
            ? ((_c.value - _kApproachEnd) / clashWindow).clamp(0.0, 1.0)
            : 0.0;
        final shakeX = clashProgress > 0
            ? sin(clashProgress * pi * 6) * 8 * (1 - clashProgress)
            : 0.0;

        final redShake = r.outcome == RoundOutcome.redCard
            ? sin(verdictT * pi * 5) * 5 * (1 - verdictT)
            : 0.0;

        final vsPeak = _interval(_kApproachEnd, 0.32, curve: Curves.easeOut);
        final vsFade = 1.0 - _interval(0.32, 0.42);
        final vsOpacity = (_c.value >= _kApproachEnd && _c.value < 0.42)
            ? (vsPeak * vsFade).clamp(0.0, 1.0)
            : 0.0;

        final showActions = _c.value >= 0.30;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(shakeX + redShake, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TelemetryStrip(round: r.round, opacity: powerOnT),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: (0.25 + 0.75 * approachT).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SideHeader(
                          label: 'YOU',
                          role: playerRole,
                          accent: playerAccent,
                        ),
                        _SideHeader(
                          label: 'CPU',
                          role: oppRole,
                          accent: oppAccent,
                          alignEnd: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final arenaW = constraints.maxWidth;
                      const cardHalfW = _kClashCardW / 2;
                      const restOffset = 84.0;
                      const impactOffset = 22.0;
                      final offScreen = arenaW / 2 + cardHalfW + 12;

                      double playerX;
                      double oppX;
                      if (_c.value < _kApproachEnd) {
                        final t = _interval(
                          _kPowerOnEnd,
                          _kApproachEnd,
                          curve: Curves.easeIn,
                        );
                        playerX = -offScreen + (offScreen - impactOffset) * t;
                        oppX = offScreen - (offScreen - impactOffset) * t;
                      } else {
                        playerX =
                            -impactOffset +
                            (impactOffset - restOffset) * clashT;
                        oppX =
                            impactOffset - (impactOffset - restOffset) * clashT;
                      }

                      final playerTilt =
                          (1 - clashT.clamp(0.0, 1.0)) * 8 * pi / 180;
                      final oppTilt =
                          -(1 - clashT.clamp(0.0, 1.0)) * 8 * pi / 180;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: _kClashStackH,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.hardEdge,
                              children: [
                                if (clashProgress > 0 && clashProgress < 0.85)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _ImpactFlashPainter(
                                        clashProgress,
                                        Cyber.cyan,
                                        const Color(0xFFC084FC),
                                      ),
                                    ),
                                  ),
                                if (clashProgress > 0 && clashProgress < 0.7)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _BurstPainter(
                                        clashProgress / 0.7,
                                        Cyber.gold,
                                      ),
                                    ),
                                  ),
                                Transform.translate(
                                  offset: Offset(playerX, 0),
                                  child: Transform.rotate(
                                    angle: playerTilt,
                                    child: Opacity(
                                      opacity: approachT.clamp(0.0, 1.0),
                                      child: _ClashCard(card: playerCard),
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(oppX, 0),
                                  child: Transform.rotate(
                                    angle: oppTilt,
                                    child: Opacity(
                                      opacity: _interval(
                                        _kPowerOnEnd + 0.02,
                                        _kApproachEnd,
                                        curve: Curves.easeOut,
                                      ).clamp(0.0, 1.0),
                                      child: _ClashCard(card: oppCard),
                                    ),
                                  ),
                                ),
                                if (vsOpacity > 0)
                                  Transform.scale(
                                    scale:
                                        0.55 +
                                        0.45 * vsPeak +
                                        0.05 * sin(vsPeak * pi),
                                    child: Opacity(
                                      opacity: vsOpacity,
                                      child: Text(
                                        'VS',
                                        style:
                                            Cyber.display(
                                              28,
                                              color: Cyber.gold,
                                            ).copyWith(
                                              shadows: const [
                                                Shadow(
                                                  color: Cyber.gold,
                                                  blurRadius: 16,
                                                ),
                                              ],
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: _kActionRowH,
                            child: showActions
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: CyberChip(
                                              label: playerAction.title,
                                              color: actionColor(
                                                playerAction.category,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: CyberChip(
                                              label: oppAction.title,
                                              color: actionColor(
                                                oppAction.category,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: compareT.clamp(0.0, 1.0),
                    child: _HeadToHeadPowerMeter(
                      playerRole: playerRole,
                      oppRole: oppRole,
                      playerPower: playerPower,
                      oppPower: oppPower,
                      playerAccent: playerAccent,
                      oppAccent: oppAccent,
                      progress: compareT,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _VerdictHero(
                    outcome: r.outcome,
                    playerAttacking: playerAttacking,
                    accent: outcomeAccent,
                    t: verdictT,
                  ),
                  const SizedBox(height: 14),
                  _ScoreImpactStrip(
                    playerScore: widget.playerScore,
                    opponentScore: widget.opponentScore,
                    goalScored: goalScored,
                    scoringIsPlayer: scoringIsPlayer,
                    t: scoreT,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: _StingerOverlay(
                kind: _stingerKind,
                accent: stingerAccent,
                animation: _stinger,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Thin top "greeble" strip: `// ROUND n · RESOLUTION LOG ———— SEC n/4`.
class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip({required this.round, required this.opacity});

  final int round;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '// ROUND $round · RESOLVED',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Cyber.label(
                10,
                color: Cyber.muted,
                letterSpacing: 1.6,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: HudLine()),
          const SizedBox(width: 10),
          Text(
            'R$round/4',
            style: Cyber.label(
              10,
              color: Cyber.line,
              letterSpacing: 1.6,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({
    required this.label,
    required this.role,
    required this.accent,
    this.alignEnd = false,
  });

  final String label;
  final String role;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          '$label //',
          style: Cyber.label(11, color: Cyber.muted, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        CyberChip(label: role, color: accent),
      ],
    );
  }
}

class _ClashCard extends StatelessWidget {
  const _ClashCard({required this.card});

  final PlayerCard card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kClashCardW,
      height: _kClashCardH,
      child: CyberPlayerCardTile(
        card: card,
        selected: false,
        size: VisualCardSize.lg,
      ),
    );
  }
}

class _HeadToHeadPowerMeter extends StatelessWidget {
  const _HeadToHeadPowerMeter({
    required this.playerRole,
    required this.oppRole,
    required this.playerPower,
    required this.oppPower,
    required this.playerAccent,
    required this.oppAccent,
    required this.progress,
  });

  final String playerRole;
  final String oppRole;
  final double playerPower;
  final double oppPower;
  final Color playerAccent;
  final Color oppAccent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final total = playerPower + oppPower;
    final playerRatio = total > 0 ? playerPower / total : 0.5;
    final oppRatio = total > 0 ? oppPower / total : 0.5;
    final winnerIsPlayer = playerPower >= oppPower;
    final winnerRole = winnerIsPlayer ? playerRole : oppRole;
    final winnerAccent = winnerIsPlayer ? playerAccent : oppAccent;
    final margin =
        (winnerIsPlayer ? playerPower - oppPower : oppPower - playerPower)
            .round();
    final marginShown = (margin * progress).round();
    final displayPlayer = (playerPower * progress).round();
    final displayOpp = (oppPower * progress).round();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PowerLabel(
              role: playerRole,
              value: displayPlayer,
              accent: playerAccent,
            ),
            _PowerLabel(
              role: oppRole,
              value: displayOpp,
              accent: oppAccent,
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final playerW = (w * playerRatio * progress).clamp(0.0, w);
            final oppW = (w * oppRatio * progress).clamp(0.0, w);

            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Cyber.bg2,
                      border: Border.all(color: Cyber.borderSubtle),
                    ),
                    child: const SizedBox(width: double.infinity, height: 16),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: playerW,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            playerAccent.withValues(alpha: 0.55),
                            playerAccent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: oppW,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            oppAccent,
                            oppAccent.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 16,
                    color: Cyber.line.withValues(alpha: 0.8),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 18,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Transform.scale(
                scale: 0.82 + 0.18 * progress,
                child: Text(
                  margin == 0
                      ? 'DEAD EVEN'
                      : '» $winnerRole EDGE +$marginShown «',
                  maxLines: 1,
                  style:
                      Cyber.label(
                        12,
                        color: margin == 0 ? Cyber.muted : winnerAccent,
                        letterSpacing: 1.8,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
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

class _PowerLabel extends StatelessWidget {
  const _PowerLabel({
    required this.role,
    required this.value,
    required this.accent,
    this.alignEnd = false,
  });

  final String role;
  final int value;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          role,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: Cyber.display(
            20,
            color: accent,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

/// Distinct per-outcome celebration treatment for the verdict hero.
enum _Celebration { goalBurst, denied, wall, deflate, caution, alarm }

_Celebration _celebrationFor(RoundOutcome o) => switch (o) {
  RoundOutcome.goal => _Celebration.goalBurst,
  RoundOutcome.saved => _Celebration.denied,
  RoundOutcome.blocked => _Celebration.wall,
  RoundOutcome.missed => _Celebration.deflate,
  RoundOutcome.foul => _Celebration.caution,
  RoundOutcome.redCard => _Celebration.alarm,
};

/// The single focal "moment" element: a chamfered HUD plate that lands with the
/// outcome icon, label and a short narration. The only glow on the screen
/// (except the goal score-pop). Treatment varies per outcome.
class _VerdictHero extends StatelessWidget {
  const _VerdictHero({
    required this.outcome,
    required this.playerAttacking,
    required this.accent,
    required this.t,
  });

  final RoundOutcome outcome;
  final bool playerAttacking;
  final Color accent;
  final double t;

  @override
  Widget build(BuildContext context) {
    final celebration = _celebrationFor(outcome);
    final deflate = celebration == _Celebration.deflate;
    final opacity = t.clamp(0.0, 1.0);
    final dy = deflate
        ? 10 *
              (1 - opacity) // gentle settle, no lift
        : -42 * (1 - opacity); // drops in from above (back-eased overshoot)
    final glow = !deflate && t > 0.35;

    return SizedBox(
      height: _kVerdictH,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (celebration == _Celebration.goalBurst && t > 0)
            Positioned.fill(
              child: CustomPaint(painter: _BurstPainter(t, accent)),
            ),
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _CornerBracketsPainter(
                  accent.withValues(alpha: deflate ? 0.3 : 0.55),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: deflate ? 0.08 : 0.16),
                    Cyber.panel,
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: deflate ? 0.5 : 0.9),
                    width: deflate ? 1.2 : 1.6,
                  ),
                  boxShadow: glow
                      ? Cyber.glow(accent, alpha: 0.45, blur: 22)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(outcomeIcon(outcome), color: accent, size: 30),
                          const SizedBox(width: 12),
                          Text(
                            outcomeLabel(outcome).toUpperCase(),
                            style: Cyber.display(
                              34,
                              color: accent,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      outcomeNarration(
                        outcome,
                        playerAttacking: playerAttacking,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(13, color: Cyber.muted, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact scoreline that reveals after the verdict and ticks the scoring side
/// up by one on a goal (with a scale-pop + glow), or reads "HELD" otherwise.
class _ScoreImpactStrip extends StatelessWidget {
  const _ScoreImpactStrip({
    required this.playerScore,
    required this.opponentScore,
    required this.goalScored,
    required this.scoringIsPlayer,
    required this.t,
  });

  final int playerScore;
  final int opponentScore;
  final bool goalScored;
  final bool scoringIsPlayer;
  final double t;

  @override
  Widget build(BuildContext context) {
    final opacity = t.clamp(0.0, 1.0);
    final popped = t >= 0.45;
    final shownPlayer = goalScored && scoringIsPlayer && !popped
        ? playerScore - 1
        : playerScore;
    final shownOpp = goalScored && !scoringIsPlayer && !popped
        ? opponentScore - 1
        : opponentScore;
    final popT = ((t - 0.45) / 0.22).clamp(0.0, 1.0);
    final popScale = 1 + 0.45 * sin(popT * pi);
    final tagColor = goalScored ? Cyber.success : Cyber.muted;

    // Full-width banner spanning the content column, square edges (no chamfer).
    return Opacity(
      opacity: opacity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(),
          border: const Border(
            top: BorderSide(color: Cyber.borderSubtle),
            bottom: BorderSide(color: Cyber.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Text(
              'SCORE',
              style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.6),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScoreCell(
                        label: 'YOU',
                        value: shownPlayer,
                        color: Cyber.cyan,
                        pop: goalScored && scoringIsPlayer ? popScale : 1,
                        glow: goalScored && scoringIsPlayer && popped,
                      ),
                      const SizedBox(width: 12),
                      Text('—', style: Cyber.display(18, color: Cyber.line)),
                      const SizedBox(width: 12),
                      _ScoreCell(
                        label: 'CPU',
                        value: shownOpp,
                        color: Cyber.danger,
                        pop: goalScored && !scoringIsPlayer ? popScale : 1,
                        glow: goalScored && !scoringIsPlayer && popped,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                border: Border.all(color: tagColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                goalScored ? '+1 GOAL' : 'HELD',
                style: Cyber.label(10, color: tagColor, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.label,
    required this.value,
    required this.color,
    required this.pop,
    required this.glow,
  });

  final String label;
  final int value;
  final Color color;
  final double pop;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Transform.scale(
          scale: pop,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: glow ? Cyber.glow(color, alpha: 0.5) : null,
            ),
            child: Text(
              '$value',
              style: Cyber.display(
                22,
                color: color,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ],
    );
  }
}

/// HUD corner ticks framing the verdict zone, tinted by the outcome accent.
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 18.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // bottom-left
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);
    // bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color;
}

class _ImpactFlashPainter extends CustomPainter {
  _ImpactFlashPainter(this.t, this.cyan, this.violet);

  final double t;
  final Color cyan;
  final Color violet;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45 * t;
    final alpha = (0.55 * (1 - t)).clamp(0.0, 0.55);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          cyan.withValues(alpha: alpha),
          violet.withValues(alpha: alpha * 0.7),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ImpactFlashPainter old) =>
      old.t != t || old.cyan != cyan || old.violet != violet;
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

enum _StingerKind { goal, denied }

/// Full-bleed payoff fired the instant the verdict lands: a stadium-wide
/// accent flash, a particle burst (goals only) and a chromatic "GOAL!" /
/// "DENIED!" stamp that slams in oversized and settles. Visual-only overlay —
/// it never affects layout or input, and stays empty unless its animation
/// is actually running (so reduced-motion and test timelines skip it).
class _StingerOverlay extends StatelessWidget {
  const _StingerOverlay({
    required this.kind,
    required this.accent,
    required this.animation,
  });

  final _StingerKind? kind;
  final Color accent;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final k = kind;
    if (k == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();

          // Flash ramps up fast then decays; stamp slams in, holds, fades out.
          final flashIn = Curves.easeOut.transform((t / 0.16).clamp(0.0, 1.0));
          final flashOut =
              1 - Curves.easeIn.transform(((t - 0.16) / 0.6).clamp(0.0, 1.0));
          final flash = 0.4 * flashIn * flashOut;
          final slamT = Curves.easeOutCubic.transform(
            (t / 0.32).clamp(0.0, 1.0),
          );
          final fadeOut =
              1 - Curves.easeIn.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));
          final scale = 2.3 - 1.3 * slamT;
          // Chromatic aberration settles as the stamp lands.
          final aberration = 6.0 * (1 - slamT);

          final label = k == _StingerKind.goal ? 'GOAL!' : 'DENIED!';
          final style = Cyber.display(54, color: accent, letterSpacing: 4)
              .copyWith(
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 26),
                ],
              );
          final ghost = style.copyWith(shadows: const []);

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: flash),
                        accent.withValues(alpha: flash * 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              if (k == _StingerKind.goal)
                Positioned.fill(
                  child: CustomPaint(painter: _BurstPainter(t, accent)),
                ),
              Opacity(
                opacity: (slamT * fadeOut).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(-aberration, 0),
                          child: Text(
                            label,
                            style: ghost.copyWith(
                              color: Cyber.cyan.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(aberration, 0),
                          child: Text(
                            label,
                            style: ghost.copyWith(
                              color: Cyber.magenta.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Text(label, style: style),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
