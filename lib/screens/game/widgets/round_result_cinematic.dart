import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Matches [CyberPlayerCardTile] at [VisualCardSize.sm].
const _kClashCardW = 96.0;
const _kClashCardH = 144.0;

/// Extra headroom for attacker border (1.5px), glow, and clash tilt.
const _kClashStackH = _kClashCardH + 12.0;

/// Reserved row height for action chips (prevents layout jump when they appear).
const _kActionRowH = 32.0;

/// Four-beat round reveal: approach → clash → power duel → outcome stamp.
class RoundClashArena extends StatefulWidget {
  const RoundClashArena({
    required this.result,
    this.onComplete,
    super.key,
  });

  final RoundResult result;
  final VoidCallback? onComplete;

  @override
  State<RoundClashArena> createState() => RoundClashArenaState();
}

@visibleForTesting
class RoundClashArenaState extends State<RoundClashArena>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3400);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  );

  bool _clashFired = false;
  bool _meterFired = false;
  bool _verdictFired = false;
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
      _c.value = 1.0;
      _fireClashSounds();
      _fireMeterHaptic();
      _fireVerdictSounds();
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
    if (!_clashFired && _c.value >= 0.26) {
      _clashFired = true;
      _fireClashSounds();
    }
    if (!_meterFired && _c.value >= 0.76) {
      _meterFired = true;
      _fireMeterHaptic();
    }
    if (!_verdictFired && _c.value >= 0.76) {
      _verdictFired = true;
      _fireVerdictSounds();
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

  @override
  void dispose() {
    _c
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
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
    _clashFired = t >= 0.26;
    _meterFired = t >= 0.76;
    _verdictFired = t >= 0.76;
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

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final approachT = _interval(0.0, 0.26, curve: Curves.easeOut);
        final clashT = _interval(0.26, 0.41, curve: Curves.easeOutBack);
        final compareT = _interval(0.41, 0.76, curve: Curves.easeOutCubic);
        final verdictT = _interval(0.76, 1.0, curve: Curves.easeOutBack);

        final clashProgress = _c.value >= 0.26 && _c.value < 0.41
            ? ((_c.value - 0.26) / 0.15).clamp(0.0, 1.0)
            : 0.0;
        final shakeX = clashProgress > 0
            ? sin(clashProgress * pi * 6) * 8 * (1 - clashProgress)
            : 0.0;

        final redShake = r.outcome == RoundOutcome.redCard
            ? sin(verdictT * pi * 5) * 5 * (1 - verdictT)
            : 0.0;

        final vsPeak = _interval(0.26, 0.30, curve: Curves.easeOut);
        final vsFade = 1.0 - _interval(0.30, 0.40);
        final vsOpacity = (_c.value >= 0.26 && _c.value < 0.40)
            ? (vsPeak * vsFade).clamp(0.0, 1.0)
            : 0.0;

        final showActions = _c.value >= 0.38;
        final panelGlow = verdictT > 0.35;

        return Transform.translate(
          offset: Offset(shakeX + redShake, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: (0.35 + 0.65 * approachT).clamp(0.0, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SideHeader(label: 'YOU', role: playerRole, accent: playerAccent),
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
                  const restOffset = 72.0;
                  const impactOffset = 22.0;
                  final offScreen = arenaW / 2 + cardHalfW + 12;

                  double playerX;
                  double oppX;
                  if (_c.value < 0.26) {
                    final t = _interval(0.0, 0.26, curve: Curves.easeIn);
                    playerX = -offScreen + (offScreen - impactOffset) * t;
                    oppX = offScreen - (offScreen - impactOffset) * t;
                  } else {
                    playerX = -impactOffset + (impactOffset - restOffset) * clashT;
                    oppX = impactOffset - (impactOffset - restOffset) * clashT;
                  }

                  final playerTilt = (1 - clashT.clamp(0.0, 1.0)) * 8 * pi / 180;
                  final oppTilt = -(1 - clashT.clamp(0.0, 1.0)) * 8 * pi / 180;

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
                                  child: _ClashCard(
                                    card: playerCard,
                                    showAttackerGlow:
                                        playerAttacking && approachT > 0.4,
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(oppX, 0),
                              child: Transform.rotate(
                                angle: oppTilt,
                                child: Opacity(
                                  opacity: _interval(0.04, 0.28, curve: Curves.easeOut)
                                      .clamp(0.0, 1.0),
                                  child: _ClashCard(
                                    card: oppCard,
                                    showAttackerGlow:
                                        !playerAttacking && approachT > 0.4,
                                  ),
                                ),
                              ),
                            ),
                            if (vsOpacity > 0)
                              Transform.scale(
                                scale: 0.55 +
                                    0.45 * vsPeak +
                                    0.05 * sin(vsPeak * pi),
                                child: Opacity(
                                  opacity: vsOpacity,
                                  child: Text(
                                    'VS',
                                    style: Cyber.display(28, color: Cyber.gold)
                                        .copyWith(
                                      shadows: const [
                                        Shadow(color: Cyber.gold, blurRadius: 16),
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: CyberChip(
                                          label: playerAction.title,
                                          color: actionColor(playerAction.category),
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
                                          color: actionColor(oppAction.category),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              SizedBox(
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (r.outcome == RoundOutcome.goal && verdictT > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BurstPainter(verdictT, outcomeAccent),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, -48 * (1 - verdictT.clamp(0.0, 1.0))),
                      child: Transform.rotate(
                        angle: -3 * pi / 180,
                        child: Opacity(
                          opacity: verdictT.clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: outcomeAccent.withValues(alpha: 0.16),
                              border: Border.all(color: outcomeAccent, width: 2),
                              boxShadow: panelGlow
                                  ? Cyber.glow(outcomeAccent, alpha: 0.45)
                                  : null,
                            ),
                            child: Text(
                              outcomeLabel(r.outcome).toUpperCase(),
                              style: Cyber.display(
                                34,
                                color: outcomeAccent,
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
            ],
          ),
        );
      },
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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Cyber.display(12, color: Cyber.line, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        CyberChip(label: role, color: accent),
      ],
    );
  }
}

class _ClashCard extends StatelessWidget {
  const _ClashCard({
    required this.card,
    required this.showAttackerGlow,
  });

  final PlayerCard card;
  final bool showAttackerGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kClashCardW,
      height: _kClashCardH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: showAttackerGlow
                ? Cyber.cyan.withValues(alpha: 0.85)
                : Cyber.borderSubtle.withValues(alpha: 0.6),
            width: showAttackerGlow ? 1.5 : 1,
          ),
          boxShadow: showAttackerGlow ? Cyber.glow(Cyber.cyan, alpha: 0.35) : null,
        ),
        child: CyberPlayerCardTile(card: card, selected: false),
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
    final winnerAccent = winnerIsPlayer ? playerAccent : oppAccent;
    final push = progress >= 1.0 ? 6.0 : 0.0;
    final displayPlayer = (playerPower * progress).round();
    final displayOpp = (oppPower * progress).round();
    final winnerGlow = progress >= 0.98;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PowerLabel(
              role: playerRole,
              value: displayPlayer,
              accent: playerAccent,
              glow: winnerIsPlayer && winnerGlow,
              winnerAccent: winnerAccent,
            ),
            _PowerLabel(
              role: oppRole,
              value: displayOpp,
              accent: oppAccent,
              glow: !winnerIsPlayer && winnerGlow,
              winnerAccent: winnerAccent,
              alignEnd: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            var playerW = w * playerRatio * progress;
            var oppW = w * oppRatio * progress;
            if (winnerIsPlayer) {
              playerW += push;
            } else {
              oppW += push;
            }

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
                      width: playerW.clamp(0.0, w),
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            playerAccent.withValues(alpha: 0.55),
                            playerAccent,
                          ],
                        ),
                        boxShadow: winnerIsPlayer && winnerGlow
                            ? Cyber.glow(playerAccent, alpha: 0.4)
                            : null,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: oppW.clamp(0.0, w),
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            oppAccent,
                            oppAccent.withValues(alpha: 0.55),
                          ],
                        ),
                        boxShadow: !winnerIsPlayer && winnerGlow
                            ? Cyber.glow(oppAccent, alpha: 0.4)
                            : null,
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
      ],
    );
  }
}

class _PowerLabel extends StatelessWidget {
  const _PowerLabel({
    required this.role,
    required this.value,
    required this.accent,
    required this.glow,
    required this.winnerAccent,
    this.alignEnd = false,
  });

  final String role;
  final int value;
  final Color accent;
  final bool glow;
  final Color winnerAccent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          role,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: glow ? Cyber.glow(winnerAccent, alpha: 0.5) : null,
          ),
          child: Text(
            '$value',
            style: Cyber.display(20, color: accent).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
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
