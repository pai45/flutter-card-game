import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

/// Accent blue used alongside [Cyber.cyan] for this button's gradient glow,
/// matching the primary CTA gradient elsewhere in the app.
const Color _accentBlue = Color(0xff5cb4ff);

/// Bright blue fill gradient (top-lit) for the inverted CTA treatment.
const Color _fillTop = Color(0xFF6FC4FF);
const Color _fillBottom = Color(0xFF2E90F5);

/// Dark ink used for the icon, divider and label sitting on the bright fill.
const Color _ink = Color(0xFF0C1422);

/// Angular HUD silhouette: a strong chamfer on the top-left and bottom-right
/// corners, with smaller angular accents on the top-right and bottom-left.
class _HudButtonClipper extends CustomClipper<Path> {
  final double bigCut;
  final double smallCut;
  const _HudButtonClipper({required this.bigCut, required this.smallCut});

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant _HudButtonClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Paints the glowing cyan/blue border by stroking the same HUD path twice:
/// a soft blurred glow stroke under a crisp gradient stroke.
class _HudBorderPainter extends CustomPainter {
  final double glow; // 0..1 intensity
  final double bigCut;
  final double smallCut;
  const _HudBorderPainter({
    required this.glow,
    required this.bigCut,
    required this.smallCut,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        _HudButtonClipper(bigCut: bigCut, smallCut: smallCut).buildPath(size);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Cyber.cyan.withValues(alpha: 0.30 + 0.40 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * glow);
    canvas.drawPath(path, glowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.80 + 0.15 * glow),
          _accentBlue.withValues(alpha: 0.90),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HudBorderPainter old) =>
      old.glow != glow || old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Reusable gamified sci-fi HUD call-to-action button.
///
/// Angular clipped silhouette, glowing cyan border, dark translucent fill with
/// a lower-center lens flare, a chevron compartment and a glowing label. Pulses
/// gently while idle and intensifies on tap. Reuse it for any primary CTA via
/// [label] and the optional [icon].
class HudCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  const HudCtaButton({
    super.key,
    this.label = 'PLAY MATCH',
    this.icon = Icons.keyboard_double_arrow_right,
    required this.onTap,
    this.height = 64,
  });

  @override
  State<HudCtaButton> createState() => _HudCtaButtonState();
}

class _HudCtaButtonState extends State<HudCtaButton>
    with SingleTickerProviderStateMixin {
  static const double _bigCut = 18;
  static const double _smallCut = 8;

  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Idle pulse (0..1); fully lit while pressed for clear feedback.
            final glow = _pressed ? 1.0 : 0.25 + 0.45 * _pulse.value;
            return Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Cyber.cyan.withValues(alpha: 0.18 + 0.22 * glow),
                    blurRadius: 24 + 16 * glow,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color:
                        _accentBlue.withValues(alpha: 0.12 + 0.18 * glow),
                    blurRadius: 40 + 22 * glow,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CustomPaint(
                foregroundPainter: _HudBorderPainter(
                  glow: glow,
                  bigCut: _bigCut,
                  smallCut: _smallCut,
                ),
                child: ClipPath(
                  clipper: const _HudButtonClipper(
                    bigCut: _bigCut,
                    smallCut: _smallCut,
                  ),
                  child: Stack(
                    children: [
                      // Bright blue interior with a subtle top-lit fade.
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_fillTop, _fillBottom],
                            ),
                          ),
                        ),
                      ),
                      // Lower-center white light streak / lens flare.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, 0.8),
                            child: Container(
                              height: widget.height * 0.55,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  radius: 0.9,
                                  colors: [
                                    Colors.white
                                        .withValues(alpha: 0.28 + 0.20 * glow),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Chevron compartment | divider | label.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Icon(
                              widget.icon,
                              color: _ink,
                              size: 26,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.30),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 1.4,
                              height: widget.height * 0.42,
                              color: _ink.withValues(alpha: 0.30),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.30,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Balances the left chevron compartment so the
                            // label reads optically centred.
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
