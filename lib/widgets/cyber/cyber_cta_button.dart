import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

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
  final Color glowColor;
  final Color borderColor;
  const _HudBorderPainter({
    required this.glow,
    required this.bigCut,
    required this.smallCut,
    required this.glowColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _HudButtonClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = glowColor.withValues(alpha: 0.30 + 0.40 * glow)
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
          borderColor.withValues(alpha: 0.90),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HudBorderPainter old) =>
      old.glow != glow ||
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.glowColor != glowColor ||
      old.borderColor != borderColor;
}

/// Reusable gamified sci-fi HUD call-to-action button.
///
/// Angular clipped silhouette, glowing cyan border, bright gradient fill with
/// a chevron compartment and a glowing label. Pulses
/// gently while idle and intensifies on tap. Reuse it for any primary CTA via
/// [label] and the optional [icon].
class HudCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;
  final bool enabled;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onPressCancel;

  /// Primary accent for the glow, border and fill. Defaults to the Play Match
  /// cyan; pass e.g. [Cyber.violet] to recolour the button for another role.
  final Color accent;

  /// Cue played on tap. Defaults to the Play Match whoosh.
  final SoundEffect tapSound;

  /// Optional small sub-line rendered under [label] (e.g. an odds readout).
  final String? helper;

  /// When true (default) the button carries the pulsing neon halo. Set false
  /// for a calmer, elevated treatment (crisp border + a plain drop shadow, no
  /// neon glow) — e.g. on the profile-setup flow.
  final bool glow;

  const HudCtaButton({
    super.key,
    this.label = 'PLAY MATCH',
    this.icon = Icons.keyboard_double_arrow_right,
    this.onTap,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.tapSound = SoundEffect.playMatch,
    this.helper,
    this.glow = true,
    this.enabled = true,
    this.onPressStart,
    this.onPressEnd,
    this.onPressCancel,
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
  void didUpdateWidget(covariant HudCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _pressed) {
      _pressed = false;
      widget.onPressCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    // The default cyan keeps the exact original Play Match palette; any other
    // accent derives a lighter companion tone and a bright fill from it.
    final bool isCyan = accent == Cyber.cyan;
    final Color secondary = isCyan
        ? _accentBlue
        : Color.lerp(accent, Colors.white, 0.30)!;
    final Color fillTop = widget.enabled
        ? (isCyan ? _fillTop : Color.lerp(accent, Colors.white, 0.34)!)
        : Cyber.panel2;
    final Color fillBottom = widget.enabled
        ? (isCyan ? _fillBottom : accent)
        : Cyber.panel;
    final contentColor = widget.enabled ? _ink : Cyber.muted;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                setState(() => _pressed = true);
                widget.onPressStart?.call();
              }
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressEnd?.call();
              }
            : null,
        onTapCancel: widget.enabled
            ? () {
                setState(() => _pressed = false);
                widget.onPressCancel?.call();
              }
            : null,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                HapticFeedback.mediumImpact();
                playSound(widget.tapSound);
                widget.onTap!.call();
              }
            : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Idle pulse (0..1); fully lit while pressed for clear feedback.
            // With glow off the halo is dropped (a faint press tick only) and
            // the border stays crisp.
            final glow = widget.enabled && widget.glow
                ? (_pressed ? 1.0 : 0.25 + 0.45 * _pulse.value)
                : (_pressed ? 0.3 : 0.0);
            return Opacity(
              opacity: widget.enabled ? 1 : 0.58,
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  boxShadow: widget.enabled && widget.glow
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18 + 0.22 * glow),
                            blurRadius: 24 + 16 * glow,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: secondary.withValues(
                              alpha: 0.12 + 0.18 * glow,
                            ),
                            blurRadius: 40 + 22 * glow,
                            spreadRadius: 2,
                          ),
                        ]
                      : const [
                          // Elevation, not glow: a plain dark drop shadow.
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 18,
                            offset: Offset(0, 9),
                          ),
                        ],
                ),
                child: CustomPaint(
                  foregroundPainter: _HudBorderPainter(
                    glow: glow,
                    bigCut: _bigCut,
                    smallCut: _smallCut,
                    glowColor: widget.enabled ? accent : Cyber.line,
                    borderColor: widget.enabled ? secondary : Cyber.line,
                  ),
                  child: ClipPath(
                    clipper: const _HudButtonClipper(
                      bigCut: _bigCut,
                      smallCut: _smallCut,
                    ),
                    child: Stack(
                      children: [
                        // Bright interior with a subtle top-lit fade.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [fillTop, fillBottom],
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
                                color: contentColor,
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
                                color: contentColor.withValues(alpha: 0.30),
                              ),
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          widget.label,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: contentColor,
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
                                      if (widget.helper != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          widget.helper!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: contentColor.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ],
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
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Primary HUD CTA with an explicit press/hold/release lifecycle.
///
/// It shares [HudCtaButton]'s chrome while avoiding a tap callback after the
/// release, which is important for charge controls that must resolve once.
class HudHoldCtaButton extends StatelessWidget {
  const HudHoldCtaButton({
    required this.label,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
    this.icon = Icons.keyboard_double_arrow_right,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.glow = true,
    super.key,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;
  final IconData icon;
  final double height;
  final Color accent;
  final bool glow;

  @override
  Widget build(BuildContext context) => HudCtaButton(
    label: label,
    icon: icon,
    height: height,
    accent: accent,
    glow: glow,
    enabled: enabled,
    onPressStart: onPressStart,
    onPressEnd: onPressEnd,
    onPressCancel: onPressCancel,
  );
}
