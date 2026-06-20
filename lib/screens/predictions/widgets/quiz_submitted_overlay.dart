import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

// ── SUBMITTED celebration overlay ─────────────────────────────────────────────
class SubmittedOverlay extends StatefulWidget {
  const SubmittedOverlay({
    required this.potentialXp,
    required this.count,
    required this.onDone,
    super.key,
  });

  final int potentialXp;
  final int count;
  final VoidCallback onDone;

  @override
  State<SubmittedOverlay> createState() => _SubmittedOverlayState();
}

class _SubmittedOverlayState extends State<SubmittedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _slammed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    playSound(SoundEffect.whoosh);
    // Ticker-driven (no timers) so this stays test-friendly: the seal slams
    // into place ~225ms in, the instant it lands.
    _c.addListener(() {
      if (_slammed || _c.value < 0.05) return;
      _slammed = true;
      playSound(SoundEffect.cardSlam);
      HapticFeedback.heavyImpact();
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
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
        final t = _c.value;
        // The seal slams in (elastic overshoot), a confirm pulse breathes out
        // once, a radar arc sweeps the ring and the checkmark draws itself in —
        // then the headline resolves and the XP charges up. One focal seal,
        // sequenced beats — no radial rays, no confetti.
        final pop = Curves.elasticOut.transform((t / 0.18).clamp(0.0, 1.0));
        final flash = (1 - t / 0.10).clamp(0.0, 1.0); // soft cyan lock flash
        final pulse = ((t - 0.06) / 0.24).clamp(0.0, 1.0); // single confirm ring
        final sweep = Curves.easeOutCubic.transform(
          ((t - 0.08) / 0.34).clamp(0.0, 1.0),
        );
        final check = Curves.easeOutCubic.transform(
          ((t - 0.18) / 0.18).clamp(0.0, 1.0),
        );
        // The headline reveals one letter at a time across this window.
        final headlineT = ((t - 0.14) / 0.26).clamp(0.0, 1.0);
        final textIn = ((t - 0.18) / 0.12).clamp(0.0, 1.0);
        final xpT = Curves.easeOut.transform(((t - 0.24) / 0.30).clamp(0.0, 1.0));
        final xpValue = (widget.potentialXp * xpT).round();
        // A long satisfying hold on the locked seal before the scrim fades.
        final scrim = (t < 0.86 ? 1.0 : (1 - (t - 0.86) / 0.14)).clamp(0.0, 1.0);
        return Opacity(
          opacity: scrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Cyber.bg.withValues(alpha: 0.92)),
              // CRT scanlines + vignette so the dark scrim reads as filmed HUD,
              // not a flat fill.
              const Positioned.fill(
                child: IgnorePointer(child: CyberTextureOverlay()),
              ),
              // ── Seal cluster, riding a touch above centre ──────────────────
              Align(
                alignment: const Alignment(0, -0.22),
                child: Transform.scale(
                  scale: pop,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Soft cyan lock flash at the instant it lands.
                        Opacity(
                          opacity: flash * 0.65,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Cyber.cyan.withValues(alpha: 0.7),
                                  Cyber.cyan.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Single confirm pulse ring (expands once, fades).
                        if (pulse > 0 && pulse < 1)
                          Opacity(
                            opacity: (1 - pulse) * 0.7,
                            child: Transform.scale(
                              scale: 0.45 + pulse * 1.25,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Cyber.cyan.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // The HUD seal: chamfered plate, corner brackets, a
                        // radar sweep ring and the checkmark drawing itself in.
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _SubmitSealPainter(sweep: sweep, check: check),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Headline + XP charge, below the seal ───────────────────────
              Align(
                alignment: const Alignment(0, 0.18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SubmittedHeadline(
                        text: 'PREDICTION SUBMITTED',
                        progress: headlineT,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: textIn,
                      child: Text(
                        '${widget.count} ANSWERS LOCKED IN',
                        style: Cyber.label(
                          11,
                          color: Cyber.muted,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: textIn,
                      child: SizedBox(
                        width: 188,
                        child: CyberProgressBar(
                          value: xpT,
                          accent: Cyber.gold,
                          height: 6,
                          animate: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Opacity(
                      opacity: textIn,
                      child: Text(
                        'UP TO $xpValue XP',
                        style:
                            Cyber.label(
                              13,
                              color: Cyber.gold,
                              letterSpacing: 1.6,
                            ).copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
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

/// The submit seal: a chamfered HUD plate ringed by corner brackets, a radar
/// [sweep] arc that completes into a glowing ring, and a checkmark that draws
/// itself in over [check]. This is the one focal "moment" element, so it earns
/// the glow (per THE GLOW RULE).
class _SubmitSealPainter extends CustomPainter {
  const _SubmitSealPainter({required this.sweep, required this.check});

  final double sweep; // 0..1 radar sweep around the ring
  final double check; // 0..1 checkmark stroke draw-on

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const half = 44.0; // plate is 88×88
    const cut = 13.0; // diagonal corner chamfer (signature shape)

    // Chamfered HUD plate — top-right and bottom-left cut for an off-axis,
    // hand-built feel rather than a symmetric box.
    final plate = Path()
      ..moveTo(center.dx - half, center.dy - half)
      ..lineTo(center.dx + half - cut, center.dy - half)
      ..lineTo(center.dx + half, center.dy - half + cut)
      ..lineTo(center.dx + half, center.dy + half)
      ..lineTo(center.dx - half + cut, center.dy + half)
      ..lineTo(center.dx - half, center.dy + half - cut)
      ..close();

    // Focal glow under the plate.
    canvas.drawPath(
      plate,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Fill with a vertical gradient for depth (not a flat tint).
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.cyan.withValues(alpha: 0.20),
            Cyber.cyan.withValues(alpha: 0.05),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: half),
        ),
    );
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: 0.85),
    );

    // Corner brackets just outside the plate.
    const bo = half + 12; // bracket offset from centre
    const bl = 14.0; // bracket arm length
    final bp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Cyber.cyan.withValues(alpha: 0.55);
    void bracket(double sx, double sy) {
      final c = center + Offset(sx * bo, sy * bo);
      canvas.drawLine(c, c + Offset(-sx * bl, 0), bp);
      canvas.drawLine(c, c + Offset(0, -sy * bl), bp);
    }

    bracket(-1, -1);
    bracket(1, -1);
    bracket(1, 1);
    bracket(-1, 1);

    // Radar ring: a faint full track + a glowing arc that sweeps around, with a
    // bright head dot while it travels.
    const ringR = half + 28;
    final ringRect = Rect.fromCircle(center: center, radius: ringR);
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.12),
    );
    const start = -pi / 2;
    if (sweep > 0) {
      canvas.drawArc(
        ringRect,
        start,
        sweep * 2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = Cyber.cyan.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      if (sweep < 1) {
        final a = start + sweep * 2 * pi;
        final tip = center + Offset(cos(a) * ringR, sin(a) * ringR);
        canvas.drawCircle(
          tip,
          6,
          Paint()
            ..color = Cyber.cyan.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
      }
    }

    // Checkmark, drawn on with a path-metric reveal.
    if (check > 0) {
      final tick = Path()
        ..moveTo(center.dx - 20, center.dy + 1)
        ..lineTo(center.dx - 6, center.dy + 16)
        ..lineTo(center.dx + 22, center.dy - 18);
      final drawn = Path();
      for (final m in tick.computeMetrics()) {
        drawn.addPath(m.extractPath(0, m.length * check), Offset.zero);
      }
      // Glow pass then the bright stroke.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Cyber.cyan.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SubmitSealPainter old) =>
      old.sweep != sweep || old.check != check;
}

/// The submit headline revealed one letter at a time — a clean staggered fade +
/// rise as [progress] goes 0 → 1. No chromatic ghosts (so nothing overlaps), and
/// kept to a single line via [FittedBox] so it never wraps on narrow screens.
class _SubmittedHeadline extends StatelessWidget {
  const _SubmittedHeadline({required this.text, required this.progress});

  final String text;
  final double progress; // 0..1 overall reveal

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final n = chars.length;
    final style =
        Cyber.display(22, color: Colors.white, letterSpacing: 1.5).copyWith(
          shadows: [
            Shadow(color: Cyber.cyan.withValues(alpha: 0.55), blurRadius: 14),
          ],
        );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            if (chars[i] == ' ')
              const SizedBox(width: 10)
            else
              _Letter(
                char: chars[i],
                style: style,
                // Each letter starts a touch after the previous; all land by 1.
                local: Curves.easeOutCubic.transform(
                  ((progress - (i / n) * 0.55) / 0.45).clamp(0.0, 1.0),
                ),
              ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.char,
    required this.style,
    required this.local,
  });

  final String char;
  final TextStyle style;
  final double local; // 0..1 this letter's reveal

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: local,
      child: Transform.translate(
        offset: Offset(0, (1 - local) * 12),
        child: Text(char, style: style),
      ),
    );
  }
}
