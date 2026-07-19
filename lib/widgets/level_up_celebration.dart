import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/progression.dart';
import '../utils/sound_effects.dart';
import 'cyber/cyber_cta_button.dart';
import 'cyber/cyber_widgets.dart';

/// Full-screen promotion moment shown after post-game XP crosses a level.
///
/// Each queued level receives its own impact beat. The final promotion settles
/// into an XP summary and remains on screen until the player presses CONTINUE.
class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({
    required this.levels,
    required this.progression,
    required this.xpEarned,
    required this.onDismissed,
    super.key,
  });

  final List<int> levels;
  final PlayerProgression progression;
  final int xpEarned;
  final VoidCallback onDismissed;

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration>
    with SingleTickerProviderStateMixin {
  static const _sequenceDuration = Duration(milliseconds: 1550);
  static const _betweenLevels = Duration(milliseconds: 250);
  static const _impactThreshold = 600 / 1550;

  late final AnimationController _sequence =
      AnimationController(vsync: this, duration: _sequenceDuration)
        ..addListener(_handleSequenceTick)
        ..addStatusListener(_handleSequenceStatus);

  Timer? _nextLevelTimer;
  int _currentIndex = 0;
  bool _started = false;
  bool _reducedMotion = false;
  bool _impactPlayed = false;
  bool _settled = false;
  bool _dismissed = false;

  int get _level => widget.levels[_currentIndex];
  bool get _isFinalLevel => _currentIndex == widget.levels.length - 1;

  @override
  void initState() {
    super.initState();
    assert(
      widget.levels.isNotEmpty,
      'LevelUpCelebration requires at least one level',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);

    if (_reducedMotion) {
      _currentIndex = widget.levels.length - 1;
      _impactPlayed = true;
      _settled = true;
      _sequence.value = 1;
      playSound(SoundEffect.levelUp);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playCurrentLevel();
    });
  }

  void _playCurrentLevel() {
    _impactPlayed = false;
    playSound(SoundEffect.riser);
    _sequence.forward(from: 0);
  }

  void _handleSequenceTick() {
    if (_reducedMotion || _impactPlayed || _sequence.value < _impactThreshold) {
      return;
    }
    _impactPlayed = true;
    playSound(SoundEffect.levelUp);
    HapticFeedback.heavyImpact();
  }

  void _handleSequenceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _reducedMotion || !mounted) {
      return;
    }

    if (!_isFinalLevel) {
      _nextLevelTimer?.cancel();
      _nextLevelTimer = Timer(_betweenLevels, () {
        if (!mounted) return;
        setState(() => _currentIndex++);
        _playCurrentLevel();
      });
      return;
    }

    if (!_settled) setState(() => _settled = true);
  }

  void _dismiss() {
    if (!_settled || _dismissed) return;
    _dismissed = true;
    widget.onDismissed();
  }

  double _segment(double start, double end, Curve curve) {
    final raw = ((_sequence.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return curve.transform(raw);
  }

  @override
  void dispose() {
    _nextLevelTimer?.cancel();
    _sequence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('level-up-celebration'),
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _sequence,
        builder: (context, _) {
          final backdrop = _reducedMotion
              ? 1.0
              : _segment(0, 220 / 1550, Curves.easeOutCubic);
          final charge = _reducedMotion
              ? 1.0
              : _segment(180 / 1550, 600 / 1550, Curves.easeInOutCubic);
          final impact = _reducedMotion
              ? 1.0
              : _segment(600 / 1550, 900 / 1550, Curves.easeOutBack);
          final burst = _reducedMotion
              ? 1.0
              : _segment(600 / 1550, 1350 / 1550, Curves.easeOutCubic);
          final headline = _reducedMotion
              ? 1.0
              : _segment(850 / 1550, 1120 / 1550, Curves.easeOutCubic);
          final details = _reducedMotion
              ? 1.0
              : _segment(1000 / 1550, 1300 / 1550, Curves.easeOutCubic);
          final cta = _reducedMotion
              ? 1.0
              : _segment(1350 / 1550, 1550 / 1550, Curves.easeOutCubic);

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: backdrop,
                child: CyberBackground(
                  grain: true,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!_reducedMotion)
                        ExcludeSemantics(
                          child: CustomPaint(
                            painter: _PromotionFxPainter(
                              charge: charge,
                              burst: burst,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const ModalBarrier(dismissible: false, color: Colors.transparent),
              Opacity(
                opacity: backdrop,
                child: Semantics(
                  key: const ValueKey('level-up-announcement'),
                  container: true,
                  explicitChildNodes: true,
                  liveRegion: _settled,
                  label: _settled
                      ? 'Level $_level reached. '
                            '${widget.progression.xpIntoLevel} of '
                            '${widget.progression.xpToNextLevel} XP toward level '
                            '${widget.progression.playerLevel + 1}.'
                      : 'Level promotion in progress',
                  child: _PromotionLayout(
                    level: _level,
                    promotionIndex: _currentIndex + 1,
                    promotionCount: widget.levels.length,
                    progression: widget.progression,
                    xpEarned: widget.xpEarned,
                    charge: charge,
                    impact: impact,
                    headline: headline,
                    details: _isFinalLevel ? details : 0,
                    cta: _isFinalLevel ? cta : 0,
                    settled: _settled,
                    reducedMotion: _reducedMotion,
                    onContinue: _dismiss,
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

class _PromotionLayout extends StatelessWidget {
  const _PromotionLayout({
    required this.level,
    required this.promotionIndex,
    required this.promotionCount,
    required this.progression,
    required this.xpEarned,
    required this.charge,
    required this.impact,
    required this.headline,
    required this.details,
    required this.cta,
    required this.settled,
    required this.reducedMotion,
    required this.onContinue,
  });

  final int level;
  final int promotionIndex;
  final int promotionCount;
  final PlayerProgression progression;
  final int xpEarned;
  final double charge;
  final double impact;
  final double headline;
  final double details;
  final double cta;
  final bool settled;
  final bool reducedMotion;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 700;
          final horizontalPadding = compact ? 16.0 : 24.0;
          final coreSize = compact ? 170.0 : 216.0;
          final ctaHeight = compact ? 56.0 : 64.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 12 : 24,
              horizontalPadding,
              compact ? 12 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PromotionTelemetry(
                      index: promotionIndex,
                      count: promotionCount,
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _PromotionHero(
                            level: level,
                            coreSize: coreSize,
                            charge: charge,
                            impact: impact,
                            headline: headline,
                            settled: settled,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    SizedBox(
                      height: compact ? 104 : 112,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: details,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - details)),
                            child: _XpSummaryPanel(
                              progression: progression,
                              xpEarned: xpEarned,
                              reveal: details,
                              compact: compact,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    SizedBox(
                      height: ctaHeight,
                      child: cta <= 0
                          ? const SizedBox.shrink()
                          : IgnorePointer(
                              ignoring: !settled,
                              child: Opacity(
                                opacity: cta,
                                child: Transform.translate(
                                  offset: Offset(0, 12 * (1 - cta)),
                                  child: Semantics(
                                    button: true,
                                    enabled: settled,
                                    label: 'Continue',
                                    child: ExcludeSemantics(
                                      child: HudCtaButton(
                                        key: const ValueKey(
                                          'level-up-continue',
                                        ),
                                        label: 'CONTINUE',
                                        icon: Icons.arrow_forward_rounded,
                                        height: ctaHeight,
                                        accent: Cyber.cyan,
                                        tapSound: SoundEffect.uiTap,
                                        glow: settled && !reducedMotion,
                                        enabled: settled,
                                        onTap: settled ? onContinue : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PromotionTelemetry extends StatelessWidget {
  const _PromotionTelemetry({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final counter = index.toString().padLeft(2, '0');
    final total = count.toString().padLeft(2, '0');
    return Column(
      children: [
        Row(
          children: [
            Text(
              'PROMOTION CONFIRMED',
              style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 2.4),
            ),
            const Spacer(),
            Text(
              '$counter // $total',
              style: Cyber.label(
                10,
                color: Cyber.muted,
                letterSpacing: 1.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const HudLine(),
      ],
    );
  }
}

class _PromotionHero extends StatelessWidget {
  const _PromotionHero({
    required this.level,
    required this.coreSize,
    required this.charge,
    required this.impact,
    required this.headline,
    required this.settled,
    required this.compact,
  });

  final int level;
  final double coreSize;
  final double charge;
  final double impact;
  final double headline;
  final bool settled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heroScale =
        (0.88 + charge * 0.12) +
        math.sin(impact * math.pi) * 0.12 * (1 - impact * 0.25);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: heroScale,
          child: _LevelCore(
            size: coreSize,
            oldLevel: level - 1,
            newLevel: level,
            charge: charge,
            impact: impact,
            focused: !settled,
            compact: compact,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        Opacity(
          opacity: headline,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - headline)),
            child: Column(
              children: [
                Text(
                  'LEVEL UP',
                  style:
                      Cyber.display(
                        compact ? 36 : 44,
                        color: Cyber.cyan,
                        letterSpacing: 2.2,
                      ).copyWith(
                        shadows: settled
                            ? null
                            : [
                                Shadow(
                                  color: Cyber.cyan.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                ),
                              ],
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransitionLevel(level: level - 1, active: false),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Cyber.cyan.withValues(alpha: 0.75),
                      ),
                    ),
                    _TransitionLevel(level: level, active: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransitionLevel extends StatelessWidget {
  const _TransitionLevel({required this.level, required this.active});

  final int level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      'LVL ${level.toString().padLeft(2, '0')}',
      style: Cyber.label(
        11,
        color: active ? Cyber.gold : Cyber.muted,
        letterSpacing: 1.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _LevelCore extends StatelessWidget {
  const _LevelCore({
    required this.size,
    required this.oldLevel,
    required this.newLevel,
    required this.charge,
    required this.impact,
    required this.focused,
    required this.compact,
  });

  final double size;
  final int oldLevel;
  final int newLevel;
  final double charge;
  final double impact;
  final bool focused;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final newOpacity = impact.clamp(0.0, 1.0).toDouble();
    final oldOpacity = (1 - impact * 2).clamp(0.0, 1.0).toDouble();
    final bigCut = size * 0.11;
    final smallCut = size * 0.045;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: focused
              ? Cyber.glow(Cyber.cyan, alpha: 0.48, blur: 34, spread: 1)
              : null,
        ),
        child: CustomPaint(
          foregroundPainter: _LevelCorePainter(
            charge: charge,
            impact: impact,
            bigCut: bigCut,
            smallCut: smallCut,
          ),
          child: ClipPath(
            clipper: HudChamferClipper(bigCut: bigCut, smallCut: smallCut),
            child: ColoredBox(
              color: Color.alphaBlend(
                Cyber.cyan.withValues(alpha: 0.05 + charge * 0.06),
                Cyber.panel,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PLAYER LEVEL',
                          style: Cyber.label(
                            compact ? 9 : 10,
                            color: Cyber.cyan,
                            letterSpacing: 2.4,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        SizedBox(
                          height: compact ? 70 : 88,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: oldOpacity,
                                child: Transform.translate(
                                  offset: Offset(0, -14 * impact),
                                  child: Text(
                                    '$oldLevel',
                                    key: const ValueKey('level-up-core-old'),
                                    style:
                                        Cyber.display(
                                          compact ? 68 : 88,
                                          color: Cyber.muted,
                                          letterSpacing: 0,
                                        ).copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: newOpacity,
                                child: Transform.scale(
                                  scale: 0.7 + newOpacity * 0.3,
                                  child: Text(
                                    '$newLevel',
                                    key: const ValueKey('level-up-core-new'),
                                    style:
                                        Cyber.display(
                                          compact ? 68 : 88,
                                          color: Cyber.gold,
                                          letterSpacing: 0,
                                        ).copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          impact < 0.25 ? 'CALIBRATING' : 'PROMOTED',
                          style: Cyber.label(
                            9,
                            color: impact < 0.25 ? Cyber.muted : Cyber.gold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _XpSummaryPanel extends StatelessWidget {
  const _XpSummaryPanel({
    required this.progression,
    required this.xpEarned,
    required this.reveal,
    required this.compact,
  });

  final PlayerProgression progression;
  final int xpEarned;
  final double reveal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = progression.xpIntoLevel / progression.xpToNextLevel;
    final barReveal = ((reveal - 0.25) / 0.75).clamp(0.0, 1.0).toDouble();
    return CyberPanel(
      key: const ValueKey('level-up-progress-panel'),
      accent: Cyber.cyan,
      glow: false,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATCH XP',
                    style: Cyber.label(
                      9,
                      color: Cyber.muted,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '+$xpEarned',
                    style:
                        Cyber.display(
                          compact ? 24 : 28,
                          color: Cyber.gold,
                          letterSpacing: 0.5,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Cyber.borderSubtle,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT // LVL ${progression.playerLevel + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        9,
                        color: Cyber.cyan,
                        letterSpacing: 1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${progression.xpIntoLevel} / '
                      '${progression.xpToNextLevel} XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        compact ? 11 : 12,
                        color: Cyber.muted,
                        letterSpacing: 0.7,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: progress * barReveal,
            accent: Cyber.cyan,
            height: 7,
            radius: 0,
            animate: false,
            trackColor: Cyber.bg,
            trackBorderColor: Cyber.borderSubtle,
          ),
        ],
      ),
    );
  }
}

class _LevelCorePainter extends CustomPainter {
  const _LevelCorePainter({
    required this.charge,
    required this.impact,
    required this.bigCut,
    required this.smallCut,
  });

  final double charge;
  final double impact;
  final double bigCut;
  final double smallCut;

  @override
  void paint(Canvas canvas, Size size) {
    final path = HudChamferClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25 + impact * 0.75
        ..color = Color.lerp(
          Cyber.cyan,
          Cyber.gold,
          impact * 0.45,
        )!.withValues(alpha: 0.75 + impact * 0.2),
    );

    canvas.save();
    canvas.clipPath(path);
    final sweepY = size.height * (1 - charge);
    final sweepRect = Rect.fromLTWH(0, sweepY - 14, size.width, 28);
    canvas.drawRect(
      sweepRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(sweepRect),
    );
    canvas.restore();

    final tick = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.4 + impact * 0.35)
      ..strokeWidth = 1;
    const inset = 12.0;
    const length = 20.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + length, inset),
      tick,
    );
    canvas.drawLine(
      Offset(size.width - inset - length, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      tick,
    );
  }

  @override
  bool shouldRepaint(_LevelCorePainter oldDelegate) =>
      oldDelegate.charge != charge || oldDelegate.impact != impact;
}

class _PromotionFxPainter extends CustomPainter {
  const _PromotionFxPainter({required this.charge, required this.burst});

  final double charge;
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.39);

    if (charge > 0 && burst == 0) {
      final chargePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.08 + charge * 0.18);
      final radius = 92 + charge * 44;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 1.55 * charge,
        false,
        chargePaint,
      );
    }

    if (burst <= 0 || burst >= 1) return;
    final fade = 1 - burst;
    final easedDistance = Curves.easeOutCubic.transform(burst);
    final shockwaveRadius = 96 + 150 * easedDistance;
    canvas.drawCircle(
      center,
      shockwaveRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * fade
        ..color = Cyber.cyan.withValues(alpha: 0.52 * fade),
    );

    for (var i = 0; i < 24; i++) {
      final angle = -math.pi / 2 + i * (math.pi * 2 / 24);
      final variance = (i % 5) * 7.0;
      final distance = 78 + (128 + variance) * easedDistance;
      final length = 4.0 + (i % 4) * 2.0;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * distance;
      final end = start + direction * length;
      final accent = i % 6 == 0 ? Cyber.gold : Cyber.cyan;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeCap = StrokeCap.square
          ..strokeWidth = i.isEven ? 2 : 1
          ..color = accent.withValues(alpha: 0.72 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_PromotionFxPainter oldDelegate) =>
      oldDelegate.charge != charge || oldDelegate.burst != burst;
}
