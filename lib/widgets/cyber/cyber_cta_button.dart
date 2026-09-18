import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_widgets.dart' show ChamferedActionSurface, HudChamferClipper;

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

    // Soft halo only when intensity > 0 — glow:false CTAs stay crisp/flat.
    if (glow > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = glowColor.withValues(alpha: 0.30 + 0.40 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * glow);
      canvas.drawPath(path, glowPaint);
    }

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

  /// Optional copy used while the pointer is held down. Hold-to-charge actions
  /// use this to tell the player exactly what releasing will do.
  final String? pressedLabel;
  final String? pressedHelper;

  /// When true (default) the button carries the pulsing neon halo. Set false
  /// for a calmer flat treatment (crisp border, no neon glow, no drop shadow)
  /// — e.g. on the hold-to-lock dock or profile-setup flow.
  final bool glow;

  /// Calm secondary action with a flat panel fill and accent-colored content.
  final bool outlined;
  final TextStyle? labelStyle;

  const HudCtaButton({
    super.key,
    this.label = 'PLAY MATCH',
    this.icon = Icons.keyboard_double_arrow_right,
    this.onTap,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.tapSound = SoundEffect.playMatch,
    this.helper,
    this.pressedLabel,
    this.pressedHelper,
    this.glow = true,
    this.outlined = false,
    this.labelStyle,
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
    final contentColor = widget.enabled
        ? (widget.outlined ? accent : _ink)
        : Cyber.muted;
    final displayLabel = _pressed
        ? widget.pressedLabel ?? widget.label
        : widget.label;
    final displayHelper = _pressed
        ? widget.pressedHelper ?? widget.helper
        : widget.helper;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: displayLabel,
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
                  // Glow rule: halo only when [glow] is on. Flat otherwise —
                  // crisp border only, no drop shadow.
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
                      : null,
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
                              color: widget.outlined ? Cyber.panel : null,
                              gradient: widget.outlined
                                  ? null
                                  : LinearGradient(
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
                                          displayLabel,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style:
                                              (widget.labelStyle ??
                                                      DefaultTextStyle.of(
                                                        context,
                                                      ).style)
                                                  .copyWith(
                                                    color: contentColor,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 3,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.30,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                      if (displayHelper != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          displayHelper,
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

/// Time-pressured "ignition" CTA: a solid accent core holding the action glyph,
/// a slanted seam into a dark body with the label + helper, a chevron chase
/// pulling the eye toward the tap, and an optional burning fuse along the base
/// showing how much time is left. The one focal glow wherever it sits.
class CyberFuseCtaButton extends StatefulWidget {
  const CyberFuseCtaButton({
    required this.label,
    required this.onTap,
    this.helper,
    this.icon = Icons.local_fire_department,
    this.accent = Cyber.cyan,
    this.fuse,
    this.height = 68,
    this.tapSound = SoundEffect.uiConfirm,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final String? helper;
  final IconData icon;
  final Color accent;

  /// Remaining fraction (0..1) drawn as a burning fuse; null hides it.
  final double? fuse;
  final double height;
  final SoundEffect tapSound;

  @override
  State<CyberFuseCtaButton> createState() => _CyberFuseCtaButtonState();
}

class _CyberFuseCtaButtonState extends State<CyberFuseCtaButton>
    with SingleTickerProviderStateMixin {
  static const _clipper = HudChamferClipper(bigCut: 16, smallCut: 5);
  static const _slant = 14.0;

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _pressed = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final accent = enabled ? widget.accent : Cyber.muted;
    final bright = Color.lerp(accent, Colors.white, 0.35)!;
    final core = widget.height + 4;
    final helper = widget.helper;

    return Semantics(
      button: true,
      enabled: enabled,
      label: helper == null ? widget.label : '${widget.label}. $helper',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                playSound(widget.tapSound);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = _loop.value;
              final breathe = _still
                  ? 0.5
                  : 0.5 + 0.5 * math.sin(t * 2 * math.pi);
              final glow = !enabled
                  ? 0.0
                  : _pressed
                  ? 1.0
                  : 0.35 + 0.3 * breathe;
              return DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: enabled
                      ? Cyber.glow(
                          accent,
                          alpha: 0.16 + 0.24 * glow,
                          blur: 18 + 16 * glow,
                          spread: -2,
                        )
                      : null,
                ),
                child: ChamferedActionSurface(
                  clipper: _clipper,
                  borderColor: bright.withValues(alpha: enabled ? 0.95 : 0.4),
                  borderWidth: 1.5,
                  child: SizedBox(
                    height: widget.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: Color.alphaBlend(
                              accent.withValues(alpha: 0.12),
                              Cyber.panel,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: core + _slant,
                          child: ClipPath(
                            clipper: const _SlantSeamClipper(_slant),
                            child: ColoredBox(color: accent),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          width: core + _slant,
                          height: 2,
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: core,
                              child: Icon(
                                widget.icon,
                                size: 30,
                                color: AppTheme.darkInk,
                              ),
                            ),
                            const SizedBox(width: _slant + 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      style: Cyber.display(17, letterSpacing: 1.4),
                                    ),
                                  ),
                                  if (helper != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      helper,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Cyber.label(
                                        9.5,
                                        color: bright,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ChevronChase(t: t, color: bright, still: _still),
                            const SizedBox(width: 16),
                          ],
                        ),
                        if (widget.fuse != null)
                          // Inset above the chamfered border so the lit fuse
                          // never merges into the same-colour stroke.
                          Positioned(
                            left: core + _slant + 12,
                            right: 22,
                            bottom: 7,
                            height: 3,
                            child: _FuseLine(
                              value: widget.fuse!.clamp(0.0, 1.0),
                              accent: accent,
                              flicker: breathe,
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
      ),
    );
  }
}

/// Core plate whose right edge leans like a `/` seam.
class _SlantSeamClipper extends CustomClipper<Path> {
  const _SlantSeamClipper(this.slant);

  final double slant;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - slant, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _SlantSeamClipper old) => old.slant != slant;
}

/// Three chevrons lit in sequence so the button reads "go this way".
class _ChevronChase extends StatelessWidget {
  const _ChevronChase({required this.t, required this.color, required this.still});

  final double t;
  final Color color;
  final bool still;

  double _alpha(int i) {
    if (still) return 0.8;
    final distance = ((t * 3) % 3 - i).abs();
    return 0.25 + 0.75 * (1 - distance.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Align(
          widthFactor: 0.5,
          child: Icon(
            Icons.chevron_right,
            size: 24,
            color: color.withValues(alpha: _alpha(i)),
          ),
        ),
    ],
  );
}

/// Burnt-down fuse: a lit stretch for the time left, capped by a flickering
/// ember at the burning end.
class _FuseLine extends StatelessWidget {
  const _FuseLine({
    required this.value,
    required this.accent,
    required this.flicker,
  });

  final double value;
  final Color accent;
  final double flicker;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final lit = box.maxWidth * value;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(color: Cyber.bg.withValues(alpha: 0.7)),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: lit,
            child: ColoredBox(color: accent),
          ),
          Positioned(
            left: lit - 3,
            top: -1.5,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Color.lerp(accent, Colors.white, 0.4 + 0.5 * flicker),
                boxShadow: Cyber.glow(accent, alpha: 0.9, blur: 8),
              ),
            ),
          ),
        ],
      );
    },
  );
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
    this.helper,
    this.pressedLabel,
    this.pressedHelper,
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
  final String? helper;
  final String? pressedLabel;
  final String? pressedHelper;

  @override
  Widget build(BuildContext context) => HudCtaButton(
    label: label,
    icon: icon,
    height: height,
    accent: accent,
    glow: glow,
    enabled: enabled,
    helper: helper,
    pressedLabel: pressedLabel,
    pressedHelper: pressedHelper,
    onPressStart: onPressStart,
    onPressEnd: onPressEnd,
    onPressCancel: onPressCancel,
  );
}
