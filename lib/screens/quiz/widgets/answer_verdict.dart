import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// "SIGNAL LOCK" — the per-question verdict cinematic for the Knowledge Arena.
///
/// One controller in the play screen runs 0→1 over [kVerdictDuration] and every
/// widget here reads its own slice of that timeline:
///
///   0.00 → 0.30  SCAN     a cyan scanline sweeps the option stack. Identical
///                         for right and wrong, so it gives nothing away.
///   0.30 → 0.62  IMPACT   correct → chevron sweep + circuit trace;
///                         wrong    → glitch tear + neon flicker.
///   0.62 → 1.00  BOOT     (wrong only) the real answer powers on.
///
/// The chevron is deliberately drawn at 45° — the same angle as the app's
/// signature corner chamfer — so the success beat is the shape language in
/// motion rather than generic confetti.
const Duration kVerdictDuration = Duration(milliseconds: 700);

const double kVerdictScanEnd = 0.30;
const double kVerdictImpactEnd = 0.62;

/// How long the player gets to read the verdict before the next question is
/// dealt automatically. The NEXT button charges across this window.
const Duration kAutoAdvanceDelay = Duration(seconds: 3);

/// Re-maps the master timeline onto a single beat, clamped to 0–1.
double verdictBeat(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Streak escalation is pure feedback — it never multiplies XP. The accent
/// climbs success → amber → gold so a hot run visibly heats up.
Color verdictStreakAccent(int streak) {
  if (streak >= 5) return Cyber.gold;
  if (streak >= 3) return Cyber.amber;
  return Cyber.success;
}

/// Beat 0 — a 2px scanline with a soft tail sweeping down the option stack.
/// Verifying, not judging: the same sweep plays whatever the answer turns out
/// to be, which is what buys the reveal its tension.
class VerdictScanline extends StatelessWidget {
  const VerdictScanline({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = verdictBeat(progress, 0, kVerdictScanEnd);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanlinePainter(t: t),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    const tail = 24.0;
    final fade = math.sin(t * math.pi).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, y - tail, size.width, tail),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - tail),
          Offset(0, y),
          [
            Cyber.cyan.withValues(alpha: 0),
            Cyber.cyan.withValues(alpha: 0.16 * fade),
          ],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1, size.width, 2),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => old.t != t;
}

/// Beat 1 (correct) — chevrons sweeping across the tile face at the chamfer
/// angle, plus a stroke that *draws* itself around the tile perimeter starting
/// from the letter badge. [chevrons] grows with the streak.
class SignalLockFx extends StatelessWidget {
  const SignalLockFx({
    required this.progress,
    required this.accent,
    this.chevrons = 3,
    super.key,
  });

  final double progress;
  final Color accent;
  final int chevrons;

  @override
  Widget build(BuildContext context) {
    final t = verdictBeat(progress, kVerdictScanEnd, 1);
    if (t <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SignalLockPainter(t: t, accent: accent, chevrons: chevrons),
      ),
    );
  }
}

class _SignalLockPainter extends CustomPainter {
  const _SignalLockPainter({
    required this.t,
    required this.accent,
    required this.chevrons,
  });

  final double t;
  final Color accent;
  final int chevrons;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrace(canvas, size);
    _paintChevrons(canvas, size);
  }

  /// A stroke that runs the tile perimeter clockwise from the letter badge,
  /// then flashes the whole outline once it closes.
  void _paintTrace(Canvas canvas, Size size) {
    final draw = Curves.easeOutCubic.transform(
      verdictBeat(t, 0, 0.62).clamp(0.0, 1.0),
    );
    if (draw <= 0) return;

    final start = math.min(26.0, size.width * 0.2);
    final path = Path()
      ..moveTo(start, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(start, 0);

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * draw;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = accent;

    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      canvas.drawPath(metric.extractPath(0, take), paint);
      remaining -= take;
    }

    // Closing flash — the outline briefly blooms once the circuit completes.
    final flash = 1 - verdictBeat(t, 0.58, 0.9);
    if (draw >= 1 && flash > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 3 * flash
          ..color = accent.withValues(alpha: 0.5 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * flash),
      );
    }
  }

  void _paintChevrons(Canvas canvas, Size size) {
    const spacing = 17.0;
    const arm = 9.0;
    final travel = size.width + spacing * chevrons + arm * 2;
    final cy = size.height / 2;
    final head = Curves.easeOutCubic.transform(
      verdictBeat(t, 0, 0.75).clamp(0.0, 1.0),
    );

    for (var i = 0; i < chevrons; i++) {
      final x = -arm + head * travel - i * spacing;
      if (x < -arm * 2 || x > size.width + arm * 2) continue;
      // Leading chevron is brightest; the tail thins out behind it.
      final lead = 1 - i / chevrons;
      final edge = math.min(x, size.width - x) / 26;
      final alpha = (lead * (1 - head) * 1.5 * edge.clamp(0.0, 1.0)).clamp(
        0.0,
        1.0,
      );
      if (alpha <= 0.01) continue;

      canvas.drawPath(
        Path()
          ..moveTo(x - arm, cy - arm)
          ..lineTo(x, cy)
          ..lineTo(x - arm, cy + arm),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 - 2 * head
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter
          ..color = accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalLockPainter old) =>
      old.t != t || old.accent != accent || old.chevrons != chevrons;
}

/// Beat 1 (wrong) — the panel tears. A decaying square-wave shake underneath,
/// displaced ghost bands and an RGB split painted over the top. Nothing is
/// rasterised, so the child keeps rendering live.
class GlitchTear extends StatelessWidget {
  const GlitchTear({
    required this.progress,
    required this.active,
    required this.child,
    super.key,
  });

  final double progress;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final t = verdictBeat(progress, kVerdictScanEnd, kVerdictImpactEnd);
    if (t <= 0 || t >= 1) return child;

    // Three hard cycles, decaying — reads as a mechanical fault, not a wobble.
    final decay = 1 - t;
    final shake = math.sin(t * math.pi * 6).sign * 4 * decay;

    return Transform.translate(
      offset: Offset(shake, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlitchPainter(t: t)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  const _GlitchPainter({required this.t});

  final double t;

  // Fixed band geometry (top fraction, height fraction, drift) so the tear is
  // deterministic — it must not re-scramble on every rebuild.
  static const List<List<double>> _bands = [
    [0.08, 0.05, 1.0],
    [0.27, 0.03, -0.6],
    [0.46, 0.07, 0.8],
    [0.68, 0.04, -1.0],
    [0.85, 0.05, 0.5],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final decay = 1 - t;
    final pulse = math.sin(t * math.pi * 6).sign;

    // RGB split across the whole panel.
    final splitPaint = Paint()..blendMode = BlendMode.plus;
    canvas.drawRect(
      Rect.fromLTWH(2 * pulse, 0, size.width, size.height),
      splitPaint..color = Cyber.danger.withValues(alpha: 0.14 * decay),
    );
    canvas.drawRect(
      Rect.fromLTWH(-2 * pulse, 0, size.width, size.height),
      splitPaint..color = Cyber.cyan.withValues(alpha: 0.08 * decay),
    );

    for (var i = 0; i < _bands.length; i++) {
      final band = _bands[i];
      final top = size.height * band[0];
      final height = math.max(2.0, size.height * band[1]);
      final dx = band[2] * (2 + 7 * decay) * pulse;

      // Displaced ghost slab — the "torn" slice.
      canvas.drawRect(
        Rect.fromLTWH(dx, top, size.width, height),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = (i.isEven ? Cyber.danger : Cyber.cyan).withValues(
            alpha: 0.16 * decay,
          ),
      );
      // Hot edge on the tear.
      canvas.drawRect(
        Rect.fromLTWH(dx, top, size.width, 1),
        Paint()..color = Cyber.danger.withValues(alpha: 0.55 * decay),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) => old.t != t;
}

/// The NEXT button as a charging cell: it starts calm and a bright focal fill
/// sweeps left→right over [kAutoAdvanceDelay], firing the next question when it
/// tops up. Tapping it any time skips the wait.
///
/// Rather than repaint the shared [HudPagerButton], this stacks two of them —
/// calm underneath, focal on top clipped to [fill] — so the label and icon each
/// pick up the right ink on their own side of the charge line.
class ChargingHudButton extends StatelessWidget {
  const ChargingHudButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;

  /// 0–1. At 0 the button is fully charged-looking (focal) — pass 0 when there
  /// is no auto-advance running so it behaves like a normal focal CTA.
  final double fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = fill.clamp(0.0, 1.0);
    return Stack(
      children: [
        HudPagerButton(
          label: label,
          trailingIcon: icon,
          focal: false,
          enabled: true,
          onTap: onTap,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              clipper: _ChargeClipper(t),
              child: HudPagerButton(
                label: label,
                trailingIcon: icon,
                focal: true,
                enabled: true,
                onTap: null,
              ),
            ),
          ),
        ),
        if (t > 0 && t < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ChargeEdgePainter(t)),
            ),
          ),
      ],
    );
  }
}

class _ChargeClipper extends CustomClipper<Rect> {
  const _ChargeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _ChargeClipper old) =>
      old.fraction != fraction;
}

/// The bright leading edge riding the charge front.
class _ChargeEdgePainter extends CustomPainter {
  const _ChargeEdgePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * fraction;
    canvas.drawRect(
      Rect.fromLTWH(x - 1.5, 0, 3, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _ChargeEdgePainter old) =>
      old.fraction != fraction;
}

/// Beat 3 — the strip that lands under the options and stays until NEXT.
/// Flat fill + border, never a glow: the verdict tile above it is the one
/// focal element on screen.
class VerdictDebriefStrip extends StatelessWidget {
  const VerdictDebriefStrip({
    required this.correct,
    required this.xp,
    required this.streak,
    required this.correctLabel,
    super.key,
  });

  final bool correct;
  final int xp;
  final int streak;
  final String correctLabel;

  @override
  Widget build(BuildContext context) {
    final accent = correct ? verdictStreakAccent(streak) : Cyber.danger;
    final overclocked = correct && streak >= 3;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 10, smallCut: 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withValues(alpha: 0.1), Cyber.panel),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Icon(
              correct ? Icons.verified_outlined : Icons.report_gmailerrorred,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overclocked
                        ? 'OVERCLOCK ×$streak'
                        : correct
                        ? 'SIGNAL LOCKED'
                        : 'SIGNAL LOST',
                    style: Cyber.label(11, color: accent, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    correct
                        ? 'ANSWER CONFIRMED · $correctLabel'
                        : 'ANSWER WAS · $correctLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(11.5, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            if (correct) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Cyber.gold.withValues(alpha: 0.13),
                  border: Border.all(color: Cyber.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '+$xp XP',
                  style: Cyber.display(11, color: Cyber.gold).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
