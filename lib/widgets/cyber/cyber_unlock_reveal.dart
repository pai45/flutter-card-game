import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_cta_button.dart';
import 'cyber_widgets.dart';

/// Full-screen "lock breaks open" moment shared by every unlock beat — NEW
/// GAME UNLOCKED, SPORT UNLOCKED, BEGINNER'S QUEST COMPLETE.
///
/// Beats: vignette → the padlock rattles, then its shackle springs open with a
/// particle burst → the unlocked item's plate slams in → title, optional
/// reward chip and CTA slide up. Glow is intentional here: it is a reward
/// moment, which the glow rule allows. Tap outside the CTA to dismiss.
class CyberUnlockReveal extends StatefulWidget {
  const CyberUnlockReveal({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onDismissed,
    this.rewardLabel,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  /// Small spaced line above the plate, e.g. `NEW GAME UNLOCKED`.
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  /// Optional reward chip under the title, e.g. `+50 OZ`.
  final String? rewardLabel;
  final String? ctaLabel;

  /// Runs the CTA; the reveal dismisses itself first.
  final VoidCallback? onCta;
  final VoidCallback onDismissed;

  @override
  State<CyberUnlockReveal> createState() => _CyberUnlockRevealState();
}

class _CyberUnlockRevealState extends State<CyberUnlockReveal>
    with TickerProviderStateMixin {
  late final AnimationController _vignette = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  late final AnimationController _rattle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _plate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _banner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  final List<Timer> _timers = [];
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _after(200, () => _rattle.forward());
    _after(720, () {
      playSound(SoundEffect.quizUnlock);
      HapticFeedback.heavyImpact();
      _open.forward();
      _burst.forward();
    });
    _after(1050, () => _plate.forward());
    _after(1300, () {
      _banner.forward();
      if (widget.rewardLabel != null) playSound(SoundEffect.achievement);
    });
    // Without a CTA there is nothing to wait for; auto-advance like the other
    // app-root moments so the queue never stalls.
    if (widget.onCta == null) _after(4200, _dismiss);
  }

  void _after(int ms, VoidCallback run) {
    _timers.add(
      Timer(Duration(milliseconds: ms), () {
        if (mounted) run();
      }),
    );
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismissed();
  }

  void _cta() {
    if (_dismissed) return;
    _dismiss();
    widget.onCta?.call();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _vignette.dispose();
    _rattle.dispose();
    _open.dispose();
    _burst.dispose();
    _plate.dispose();
    _banner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _vignette,
              builder: (context, _) => ColoredBox(
                color: Colors.black.withValues(alpha: _vignette.value * 0.86),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: CyberTextureOverlay()),
            ),
            AnimatedBuilder(
              animation: _burst,
              builder: (context, _) => Center(
                child: CustomPaint(
                  size: const Size(340, 340),
                  painter: _UnlockBurstPainter(
                    progress: _burst.value,
                    accent: accent,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _rattle,
                      _open,
                      _plate,
                      _banner,
                    ]),
                    builder: (context, _) => _content(accent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Color accent) {
    final bannerIn = Curves.easeOutCubic.transform(_banner.value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _vignette.value,
          child: Text(
            widget.eyebrow,
            textAlign: TextAlign.center,
            style: Cyber.label(13, color: accent, letterSpacing: 3.4).copyWith(
              shadows: [
                Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The padlock rattles, springs open, then drops away as the
              // unlocked plate slams in over it.
              Opacity(
                opacity: (1 - _plate.value * 1.4).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(
                    math.sin(_rattle.value * math.pi * 8) *
                        6 *
                        (1 - _rattle.value),
                    _plate.value * 30,
                  ),
                  child: CustomPaint(
                    size: const Size(72, 88),
                    painter: _PadlockPainter(
                      open: Curves.easeOutBack.transform(_open.value),
                      color: accent,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: Curves.easeOutBack.transform(_plate.value),
                child: Opacity(
                  opacity: _plate.value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: Cyber.glow(accent, alpha: 0.45, blur: 30),
                    ),
                    child: ClipPath(
                      clipper: const HudChamferClipper(bigCut: 18, smallCut: 8),
                      child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.16),
                            Cyber.panel,
                          ),
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Icon(widget.icon, color: accent, size: 58),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Opacity(
          opacity: bannerIn,
          child: Transform.translate(
            offset: Offset(0, (1 - bannerIn) * 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style:
                      Cyber.display(
                        28,
                        color: Colors.white,
                        letterSpacing: 1.4,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: Cyber.body(14, color: Cyber.muted),
                  ),
                ),
                if (widget.rewardLabel != null) ...[
                  const SizedBox(height: 14),
                  CyberChip(label: widget.rewardLabel!, color: Cyber.gold),
                ],
                if (widget.ctaLabel != null && widget.onCta != null) ...[
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 280,
                    child: HudCtaButton(
                      key: const ValueKey('unlock-reveal-cta'),
                      label: widget.ctaLabel!,
                      icon: Icons.play_arrow_rounded,
                      accent: accent,
                      height: 56,
                      onTap: _cta,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  widget.onCta == null ? 'TAP TO CONTINUE' : 'TAP TO CLOSE',
                  style: Cyber.label(11, color: Cyber.muted, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A flat HUD padlock; [open] 0→1 lifts and swings the shackle free.
class _PadlockPainter extends CustomPainter {
  _PadlockPainter({required this.open, required this.color});

  final double open;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyTop = size.height * 0.42;
    final body = Rect.fromLTWH(0, bodyTop, size.width, size.height - bodyTop);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.square;

    // Shackle: rises and pivots on its right leg as it opens.
    canvas.save();
    final pivot = Offset(size.width * 0.78, bodyTop);
    canvas.translate(pivot.dx, pivot.dy - open * 12);
    canvas.rotate(-open * 0.55);
    canvas.translate(-pivot.dx, -pivot.dy);
    final shackle = Path()
      ..moveTo(size.width * 0.22, bodyTop)
      ..lineTo(size.width * 0.22, size.height * 0.2)
      ..arcToPoint(
        Offset(size.width * 0.78, size.height * 0.2),
        radius: Radius.circular(size.width * 0.28),
      )
      ..lineTo(size.width * 0.78, bodyTop);
    canvas.drawPath(shackle, stroke);
    canvas.restore();

    // Body: chamfered plate + keyhole.
    const cut = 10.0;
    final bodyPath = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.right, body.top)
      ..lineTo(body.right, body.bottom - cut)
      ..lineTo(body.right - cut, body.bottom)
      ..lineTo(body.left + cut, body.bottom)
      ..lineTo(body.left, body.bottom - cut)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = Cyber.panel);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final keyhole = Offset(body.center.dx, body.center.dy - 4);
    canvas.drawCircle(keyhole, 6, Paint()..color = color);
    canvas.drawRect(
      Rect.fromCenter(center: keyhole.translate(0, 9), width: 5, height: 12),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PadlockPainter oldDelegate) =>
      oldDelegate.open != open || oldDelegate.color != color;
}

/// Radial shard burst as the lock breaks.
class _UnlockBurstPainter extends CustomPainter {
  _UnlockBurstPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const count = 24;
    final center = size.center(Offset.zero);
    final maxRadius = size.width * 0.48;
    final eased = Curves.easeOutCubic.transform(progress);
    final paint = Paint()
      ..color = accent.withValues(alpha: (1 - progress) * 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    for (var i = 0; i < count; i++) {
      final angle = i * (2 * math.pi / count) + (i.isEven ? 0 : 0.12);
      final reach = (i % 3 == 0 ? 1.0 : 0.72) * maxRadius * eased;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * (reach * 0.72);
      final end = center + direction * reach;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_UnlockBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
