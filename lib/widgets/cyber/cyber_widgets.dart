import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../utils/label_helpers.dart';
import '../../utils/sound_effects.dart';

class CyberConfirmDialog extends StatelessWidget {
  const CyberConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? Cyber.red : Cyber.cyan;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: CyberPanel(
          accent: destructive ? Cyber.magenta : Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: accent,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          destructive ? 'WARNING' : 'CONFIRM',
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'Orbitron',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xff9aa8bb),
                        fontFamily: 'Onest',
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: _CyberDialogAction(
                        label: cancelLabel,
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff1e2538)),
                    Expanded(
                      child: _CyberDialogAction(
                        label: '$confirmLabel >',
                        color: accent,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberDialogAction extends StatelessWidget {
  const _CyberDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showCyberConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: CyberConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    ),
  );
  return confirmed ?? false;
}

class PackBurst extends StatelessWidget {
  const PackBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        children: [
          for (var i = 0; i < 12; i++)
            Positioned.fill(
              child: Transform.rotate(
                angle: i * pi / 6,
                child: Align(
                  alignment: const Alignment(0, -0.38),
                  child: Container(
                    width: 3,
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Cyber.amber.withValues(alpha: 0.95),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Cyber.amber.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Film-grain texture ───────────────────────────────────────────────────────
// A small procedural noise tile, generated once and shared by every
// [CyberBackground]. Tiled + additive at very low intensity it de-flattens the
// dark surfaces so they read as filmed/printed rather than computer-flat.
ui.Image? _cyberNoise;
Future<ui.Image>? _cyberNoiseFuture;

final Float64List _kIdentity4 = Float64List.fromList(<double>[
  1, 0, 0, 0, //
  0, 1, 0, 0, //
  0, 0, 1, 0, //
  0, 0, 0, 1, //
]);

Future<ui.Image> _loadCyberNoise() {
  final cached = _cyberNoise;
  if (cached != null) return Future<ui.Image>.value(cached);
  return _cyberNoiseFuture ??= _buildCyberNoise(256).then((image) {
    _cyberNoise = image;
    return image;
  });
}

Future<ui.Image> _buildCyberNoise(int size) {
  final rnd = Random(7);
  final pixels = Uint8List(size * size * 4);
  for (var i = 0; i < size * size; i++) {
    final v = rnd.nextInt(20); // grey grain, added over near-black surfaces
    final o = i * 4;
    pixels[o] = v;
    pixels[o + 1] = v;
    pixels[o + 2] = v;
    pixels[o + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    size,
    size,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class CyberBackground extends StatefulWidget {
  const CyberBackground({
    required this.child,
    this.animated = false,
    this.grain = false,
    super.key,
  });

  final Widget child;

  /// When true, the radial glow slowly drifts (used on the home screen).
  final bool animated;

  /// Film-grain noise overlay — reserved for the in-match (card game) screens.
  final bool grain;

  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 16),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _glow(double t) {
    final dx = 0.2 + 0.3 * sin(t * 2 * pi);
    final dy = -0.75 + 0.18 * cos(t * 2 * pi);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(dx, dy),
            radius: 1.1,
            colors: [
              Cyber.cyan.withValues(alpha: 0.12),
              Cyber.violet.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: CyberGridPainter())),
        Positioned.fill(child: CyberTextureOverlay(grain: widget.grain)),
        if (_controller == null)
          _glow(0)
        else
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) => _glow(_controller!.value),
          ),
        widget.child,
      ],
    );
  }
}

/// Shared full-bleed stadium treatment for game hubs and landing screens.
///
/// The art drifts behind a restrained accent pulse, light beams, telemetry
/// streaks, shade, and the standard cyber texture. Feature screens only choose
/// their art and semantic accent instead of carrying private copies of the
/// animation and painter.
class CyberArenaBackground extends StatefulWidget {
  const CyberArenaBackground({
    required this.assetPath,
    required this.accent,
    required this.child,
    this.secondaryAccent,
    this.assetOpacity = 0.2,
    this.horizonColor = Cyber.arenaHorizon,
    this.topShadeAlpha = 0.32,
    this.middleShadeAlpha = 0,
    this.bottomShadeAlpha = 0.62,
    this.additiveBeams = false,
    super.key,
  });

  final String assetPath;
  final Color accent;
  final Color? secondaryAccent;
  final Widget child;
  final double assetOpacity;
  final Color horizonColor;
  final double topShadeAlpha;
  final double middleShadeAlpha;
  final double bottomShadeAlpha;
  final bool additiveBeams;

  @override
  State<CyberArenaBackground> createState() => _CyberArenaBackgroundState();
}

class _CyberArenaBackgroundState extends State<CyberArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cyber.arenaSky, widget.horizonColor, Cyber.arenaFloor],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * pi * 2;
                return Transform.translate(
                  offset: Offset(sin(phase) * 8, cos(phase) * 6),
                  child: Transform.scale(
                    scale: 1.05 + 0.008 * sin(phase * 2),
                    child: child,
                  ),
                );
              },
              child: Opacity(
                opacity: widget.assetOpacity,
                child: Image.asset(
                  widget.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _CyberArenaMotionPainter(
                  progress: _controller.value,
                  accent: widget.accent,
                  secondaryAccent: widget.secondaryAccent ?? widget.accent,
                  additiveBeams: widget.additiveBeams,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: widget.topShadeAlpha),
                    Cyber.bg.withValues(alpha: widget.middleShadeAlpha),
                    Cyber.bg.withValues(alpha: widget.bottomShadeAlpha),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}

class _CyberArenaMotionPainter extends CustomPainter {
  const _CyberArenaMotionPainter({
    required this.progress,
    required this.accent,
    required this.secondaryAccent,
    required this.additiveBeams,
  });

  final double progress;
  final Color accent;
  final Color secondaryAccent;
  final bool additiveBeams;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final phase = progress * pi * 2;
    final pulse = 0.5 + 0.5 * sin(phase * 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.72),
          radius: 0.88,
          colors: [
            accent.withValues(alpha: 0.08 + pulse * 0.035),
            secondaryAccent.withValues(alpha: 0.025),
            Colors.transparent,
          ],
          stops: const [0, 0.28, 1],
        ).createShader(rect),
    );

    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.08, size.height * 0.72),
      end: Offset(size.width * (0.42 + sin(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + pulse * 0.016,
    );
    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.92, size.height * 0.72),
      end: Offset(size.width * (0.58 + cos(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + (1 - pulse) * 0.016,
    );

    final streakPaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final seed = i * 37.0;
      final x = ((seed * 19) % size.width) + sin(phase + i) * 18;
      final travel = (progress + i * 0.071) % 1.0;
      final y = size.height * (0.96 - travel * 0.82);
      final length = 12.0 + (i % 4) * 5.0;
      final opacity = 0.025 + 0.03 * sin(phase + i).abs();
      streakPaint.color = accent.withValues(alpha: opacity);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length * 0.42, y - length),
        streakPaint,
      );
    }
  }

  void _drawBeam(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double width,
    required double opacity,
  }) {
    final path = Path()
      ..moveTo(start.dx - width * 0.5, start.dy)
      ..lineTo(start.dx + width * 0.5, start.dy)
      ..lineTo(end.dx + width * 0.08, end.dy)
      ..lineTo(end.dx - width * 0.08, end.dy)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          accent.withValues(alpha: opacity),
          accent.withValues(alpha: opacity * 0.35),
          Colors.transparent,
        ],
      ).createShader(additiveBeams ? Offset.zero & size : path.getBounds());
    if (additiveBeams) paint.blendMode = BlendMode.plus;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CyberArenaMotionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.secondaryAccent != secondaryAccent ||
      oldDelegate.additiveBeams != additiveBeams;
}

class CyberPlainBackground extends StatelessWidget {
  const CyberPlainBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),
        ),
        child,
      ],
    );
  }
}

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the shared HUD texture layers — CRT scanlines, tiled film-grain and an
/// edge vignette — over whatever is already on the canvas. Shared by the full
/// [CyberBackground] and the standalone [CyberTextureOverlay].
void _paintCyberTexture(
  Canvas canvas,
  Size size,
  ui.Image? grainImage, {
  bool vignette = true,
  bool grain = true,
}) {
  final rect = Offset.zero & size;

  // CRT scanlines — faint dark rows every 3px, crisp (no anti-alias).
  final scan = Paint()
    ..color = Colors.black.withValues(alpha: 0.14)
    ..strokeWidth = 1
    ..isAntiAlias = false;
  for (var y = 0.0; y < size.height; y += 3) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
  }

  // Film grain — tiled noise, additive. Reserved for the in-match screens.
  if (grain && grainImage != null) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          grainImage,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          _kIdentity4,
        )
        ..blendMode = BlendMode.plus,
    );
  }

  // Vignette — darken the edges to pull focus to the centre.
  if (vignette) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.15,
          colors: [
            Colors.transparent,
            const Color(0xff04060c).withValues(alpha: 0.5),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }
}

/// A transparent overlay of the shared HUD texture (scanlines + film-grain +
/// optional vignette) for screens that draw their own background instead of
/// using [CyberBackground] (e.g. the home stadium, the shop). Drop it into a
/// Stack above the background and below the content:
/// `const Positioned.fill(child: CyberTextureOverlay())`.
class CyberTextureOverlay extends StatefulWidget {
  const CyberTextureOverlay({
    this.vignette = true,
    this.grain = false,
    super.key,
  });

  final bool vignette;

  /// Film-grain noise is reserved for the in-match (card game) screens.
  final bool grain;

  @override
  State<CyberTextureOverlay> createState() => _CyberTextureOverlayState();
}

class _CyberTextureOverlayState extends State<CyberTextureOverlay> {
  ui.Image? _noise;

  @override
  void initState() {
    super.initState();
    if (!widget.grain) return;
    final cached = _cyberNoise;
    if (cached != null) {
      _noise = cached;
    } else {
      _loadCyberNoise().then((image) {
        if (mounted) setState(() => _noise = image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CyberOverlayPainter(
          noise: _noise,
          vignette: widget.vignette,
          grain: widget.grain,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CyberOverlayPainter extends CustomPainter {
  const _CyberOverlayPainter({
    required this.noise,
    required this.vignette,
    required this.grain,
  });

  final ui.Image? noise;
  final bool vignette;
  final bool grain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintCyberTexture(canvas, size, noise, vignette: vignette, grain: grain);
  }

  @override
  bool shouldRepaint(covariant _CyberOverlayPainter oldDelegate) =>
      oldDelegate.noise != noise ||
      oldDelegate.vignette != vignette ||
      oldDelegate.grain != grain;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class CyberNoDataState extends StatelessWidget {
  const CyberNoDataState({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = Cyber.cyan,
    this.spark = Icons.auto_awesome,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final IconData spark;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel == null || onAction == null
        ? null
        : PressableScale(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, color: accent, size: 16),
                  const SizedBox(width: 7),
                  Text(
                    actionLabel!,
                    style: Cyber.label(9, color: accent, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 118,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: accent.withValues(alpha: 0.86), size: 78),
                    Positioned(
                      right: 12,
                      bottom: 6,
                      child: Icon(
                        spark,
                        color: Colors.white.withValues(alpha: 0.82),
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.display(
                  14,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  13,
                  color: Cyber.muted,
                  weight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      ),
    );
  }
}

class HudLine extends StatelessWidget {
  const HudLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.9),
            Cyber.magenta.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// A polished progress / meter bar shared by every XP, rank and power meter so
/// the "gradient flow" reads identically across the app. The fill ramps from a
/// soft translucent accent to full colour over ~70% of its width and finishes
/// on a bright leading edge, paired with a tight, subtle glow and a glossy top
/// sheen for a clean finish.
class CyberProgressBar extends StatelessWidget {
  const CyberProgressBar({
    required this.value,
    this.accent = Cyber.cyan,
    this.height = 7,
    this.radius = 2,
    this.animate = true,
    this.trackColor,
    this.trackBorderColor,
    super.key,
  });

  /// Fill fraction, 0..1.
  final double value;
  final Color accent;
  final double height;
  final double radius;

  /// When true the fill grows from 0 to [value] on first build. Leave false
  /// when the caller already animates [value] itself.
  final bool animate;
  final Color? trackColor;
  final Color? trackBorderColor;

  Widget _bar(double v) {
    final r = BorderRadius.circular(radius);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor ?? Cyber.bg.withValues(alpha: 0.7),
                borderRadius: r,
                border: trackBorderColor == null
                    ? null
                    : Border.all(color: trackBorderColor!),
              ),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The flow: soft fade-in, full colour by ~70%, bright tip.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            accent.withValues(alpha: 0.45),
                            accent.withValues(alpha: 0.95),
                            accent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                    // Glossy top sheen.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height * 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    if (!animate) return _bar(target);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => _bar(v),
    );
  }
}

/// What a [CyberChargeMeter] needs to draw itself. Every field is a 0..1
/// fraction of the track, so the meter never has to know what it is measuring —
/// Hoop Duel feeds it a jump, Final Over feeds it a backlift.
class ChargeMeterView {
  const ChargeMeterView({
    required this.progress,
    required this.perfectCenter,
    required this.perfectHalf,
    required this.goodHalf,
    this.overswingFrom,
    this.hot = false,
  });

  /// Where the needle sits.
  final double progress;

  /// Centre of the PERFECT band, and its half-width.
  final double perfectCenter;
  final double perfectHalf;

  /// How far the GOOD band extends *beyond* the perfect band on each side.
  final double goodHalf;

  /// Above this, you have overcooked it — drawn as a danger zone. Null for
  /// meters where holding longer simply cannot hurt you.
  final double? overswingFrom;

  /// The moment to release is NOW. Lights the track's edge — the only thing in
  /// here that glows, because it is the one live beat.
  final bool hot;
}

/// The shot meter, shared by Hoop Duel and Final Over: a dim GOOD band, a bright
/// PERFECT band, and a gold needle riding up the track. Release inside the lime.
class CyberChargeMeter extends StatelessWidget {
  const CyberChargeMeter({required this.view, super.key});

  final ChargeMeterView view;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 150,
    child: CustomPaint(painter: _ChargeMeterPainter(view)),
  );
}

class _ChargeMeterPainter extends CustomPainter {
  _ChargeMeterPainter(this.view);

  final ChargeMeterView view;

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width / 2 - 5;
    final right = size.width / 2 + 5;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, 10, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(track, Paint()..color = Cyber.bg.withValues(alpha: 0.75));
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = view.hot ? 1.6 : 1
        ..color = view.hot ? Cyber.lime : Cyber.border,
    );

    double y(double frac) => size.height * (1 - frac.clamp(0.0, 1.0));

    // Charged-so-far fill goes UNDER the bands: it tints the empty track, it
    // does not wash out the very zones you are aiming at.
    final needleY = y(view.progress);
    canvas.drawRect(
      Rect.fromLTRB(left, needleY, right, size.height),
      Paint()..color = Cyber.gold.withValues(alpha: 0.42),
    );

    // Good window (wider, dimmer) behind the perfect band.
    canvas.drawRect(
      Rect.fromLTRB(
        left,
        y(view.perfectCenter + view.perfectHalf + view.goodHalf),
        right,
        y(view.perfectCenter - view.perfectHalf - view.goodHalf),
      ),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.26),
    );
    // Overswing: held too long, and it costs you control.
    final overswing = view.overswingFrom;
    if (overswing != null) {
      canvas.drawRect(
        Rect.fromLTRB(left, y(1), right, y(overswing)),
        Paint()..color = Cyber.danger.withValues(alpha: 0.55),
      );
    }
    // Perfect band.
    canvas.drawRect(
      Rect.fromLTRB(
        left,
        y(view.perfectCenter + view.perfectHalf),
        right,
        y(view.perfectCenter - view.perfectHalf),
      ),
      Paint()..color = Cyber.lime.withValues(alpha: 0.85),
    );

    // The needle.
    canvas.drawLine(
      Offset(0, needleY),
      Offset(size.width, needleY),
      Paint()
        ..color = Cyber.gold
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ChargeMeterPainter old) =>
      old.view.progress != view.progress ||
      old.view.perfectCenter != view.perfectCenter ||
      old.view.perfectHalf != view.perfectHalf ||
      old.view.overswingFrom != view.overswingFrom ||
      old.view.hot != view.hot;
}

class CyberCtaButton extends StatelessWidget {
  const CyberCtaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.clip = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary
        ? const LinearGradient(colors: [Cyber.cyan, Color(0xff5cb4ff)])
        : LinearGradient(colors: [Cyber.panel2, Cyber.panel]);
    final inner = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: bg,
        border: clip
            ? null
            : Border.all(color: primary ? Cyber.cyan : Cyber.line),
        boxShadow: [
          BoxShadow(
            color: (primary ? Cyber.cyan : Cyber.bg).withValues(alpha: 0.3),
            blurRadius: 18,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: primary ? Cyber.bg : Cyber.cyan,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: clip
            ? ChamferedActionSurface(
                clipper: CyberClipper(),
                borderColor: primary ? Cyber.cyan : Cyber.line,
                child: inner,
              )
            : inner,
      ),
    );
  }
}

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  /// Whether this is a focal / active surface that should glow. Off by default:
  /// most panels are plain surfaces and rely on the fill + border for depth.
  /// Reserve [glow] for the panel the user should look at first on a screen.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _CyberPanelBorderPainter(color: borderColor),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Cyber.panel,
            boxShadow: glow
                ? Cyber.glow(accent, alpha: 0.18, blur: 18, spread: 1)
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _CyberPanelBorderPainter extends CustomPainter {
  const _CyberPanelBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CyberPanelBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class RectangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CyberClipper extends CustomClipper<Path> {
  static const double cut = 12;

  static Path buildPath(Size size, {double cut = cut}) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Angular HUD silhouette shared by the primary CTA ([HudCtaButton]) and player
/// cards: a strong chamfer on the top-left and bottom-right corners with smaller
/// accent cuts on the top-right and bottom-left. Keeping one silhouette across
/// buttons and cards makes them read as the same "HUD hardware" family.
class HudChamferClipper extends CustomClipper<Path> {
  const HudChamferClipper({required this.bigCut, required this.smallCut});

  final double bigCut;
  final double smallCut;

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
  bool shouldReclip(covariant HudChamferClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Clips an interactive surface and strokes that exact path in the foreground.
///
/// A rectangular [BoxDecoration.border] is clipped along with its child and
/// therefore cannot paint the diagonal chamfer segments. CTA implementations
/// use this shell so every straight and cut edge receives the same border.
class ChamferedActionSurface extends StatelessWidget {
  const ChamferedActionSurface({
    required this.clipper,
    required this.borderColor,
    required this.child,
    this.borderWidth = 1,
    this.glowColor,
    this.glow = 0,
    super.key,
  });

  final CustomClipper<Path> clipper;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glow;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: ChamferedActionBorderPainter(
      clipper: clipper,
      color: borderColor,
      width: borderWidth,
      glowColor: glowColor,
      glow: glow,
    ),
    child: ClipPath(clipper: clipper, child: child),
  );
}

/// Border painter shared by app CTAs that use a clipped action silhouette.
class ChamferedActionBorderPainter extends CustomPainter {
  const ChamferedActionBorderPainter({
    required this.clipper,
    required this.color,
    required this.width,
    this.glowColor,
    this.glow = 0,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final double width;
  final Color? glowColor;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (glow > 0 && glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!.withValues(alpha: 0.22 * glow.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 1.5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * glow),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant ChamferedActionBorderPainter oldDelegate) =>
      oldDelegate.clipper != clipper ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.glow != glow;
}

enum VisualCardSize { sm, md, lg }

// Full-luminance grayscale matrix for disabled/suspended cards.
const List<double> _grayscaleMatrix = <double>[
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Shared interaction shell for player/action cards. Handles hover lift,
/// selected hard-elevation (offset shadow + accent fill + square marker),
/// and disabled grayscale + "SUSPENDED" banner + shake on a blocked tap.
class PremiumCardShell extends StatefulWidget {
  const PremiumCardShell({
    required this.width,
    required this.height,
    required this.selected,
    required this.disabled,
    required this.accent,
    required this.selectedAccent,
    required this.builder,
    this.onTap,
    this.disabledLabel = 'IN DECK',
    this.clipper,
    this.tapSound = SoundEffect.cardSelect,
    super.key,
  });

  final double width;
  final double height;
  final bool selected;
  final bool disabled;
  final Color accent;
  final Color selectedAccent;
  final Widget Function(bool hovered) builder;
  final VoidCallback? onTap;
  final String disabledLabel;

  /// Sound played on a valid tap. Action tiles override it per category
  /// (attack/defense/special); the default is the generic card-select tick.
  final SoundEffect tapSound;

  /// Silhouette used to mask the disabled "SUSPENDED" banner so it matches the
  /// card's clipped shape. Defaults to [CyberClipper] (bottom-corner chamfer);
  /// the player card passes a [HudChamferClipper] to match its angular edge.
  final CustomClipper<Path>? clipper;

  @override
  State<PremiumCardShell> createState() => _PremiumCardShellState();
}

class _PremiumCardShellState extends State<PremiumCardShell>
    with SingleTickerProviderStateMixin {
  static const _hardShadowColor = Color(0xff04060b);

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _hovered = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) {
      _shake.forward(from: 0);
      return;
    }
    playSound(widget.tapSound);
    // Light tactile confirmation so a selection feels like it "registered".
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, _) {
            final hot = _hovered && !widget.disabled;
            final lift = widget.selected ? -5.0 : (hot ? -3.0 : 0.0);
            final scale = hot && !widget.selected ? 1.02 : 1.0;
            final shakeX = _shake.isAnimating
                ? sin(_shake.value * pi * 6) * 4 * (1 - _shake.value)
                : 0.0;

            Widget cardBody = SizedBox(
              width: widget.width,
              height: widget.height,
              child: widget.builder(_hovered),
            );

            if (widget.disabled) {
              cardBody = ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                child: cardBody,
              );
              cardBody = Stack(
                children: [
                  cardBody,
                  Positioned.fill(
                    child: ClipPath(
                      clipper: widget.clipper ?? CyberClipper(),
                      child: _SuspendedBanner(widget.disabledLabel),
                    ),
                  ),
                ],
              );
            } else if (widget.selected) {
              final clipper = widget.clipper ?? CyberClipper();
              final inner = SizedBox(
                width: widget.width,
                height: widget.height,
                child: widget.builder(_hovered),
              );
              cardBody = Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 6),
                    child: ClipPath(
                      clipper: clipper,
                      child: SizedBox(
                        width: widget.width,
                        height: widget.height,
                        child: const ColoredBox(color: _hardShadowColor),
                      ),
                    ),
                  ),
                  ClipPath(
                    clipper: clipper,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.selectedAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: widget.selectedAccent,
                          width: 2,
                        ),
                      ),
                      child: inner,
                    ),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: _SelectionSquare(color: widget.selectedAccent),
                  ),
                ],
              );
            }

            return Transform.translate(
              offset: Offset(shakeX, lift),
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: hot && !widget.selected && !widget.disabled
                        ? [
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.28),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: cardBody,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectionSquare extends StatelessWidget {
  const _SelectionSquare({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _SuspendedBanner extends StatelessWidget {
  const _SuspendedBanner(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -pi / 4,
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Cyber.danger.withValues(alpha: 0.92),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardIconFallback extends StatelessWidget {
  const _CardIconFallback({
    required this.card,
    required this.tier,
    required this.small,
    required this.large,
  });

  final PlayerCard card;
  final Color tier;
  final bool small;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xfff7f7f4),
            Colors.white,
            tier,
            const Color(0xff111827),
            Cyber.red,
          ],
          stops: const [0, 0.40, 0.54, 0.72, 1],
        ),
      ),
      child: Center(
        child: Icon(
          card.icon,
          size: small ? 42 : (large ? 72 : 64),
          color: const Color(0xff111827),
        ),
      ),
    );
  }
}

class CyberPlayerCardTile extends StatefulWidget {
  const CyberPlayerCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.size = VisualCardSize.sm,
    this.selectedAccent = Cyber.cyan,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final bool disabled;
  final VisualCardSize size;
  final Color selectedAccent;
  final VoidCallback? onTap;

  @override
  State<CyberPlayerCardTile> createState() => _CyberPlayerCardTileState();
}

class _CyberPlayerCardTileState extends State<CyberPlayerCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (widget.selected) {
      _tapController.value = 1;
    }
  }

  @override
  void didUpdateWidget(CyberPlayerCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _tapController.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _tapController.reverse();
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final selected = widget.selected;
    final disabled = widget.disabled;
    final size = widget.size;
    final selectedAccent = widget.selectedAccent;
    final onTap = widget.onTap;
    final tier = tierColor(card.tier);
    final rank = card.tier.index; // 0 bronze · 1 silver · 2 gold · 3 platinum
    final posColor = switch (card.role) {
      PlayerRole.attacker => Cyber.cyan,
      PlayerRole.defender => Cyber.violet,
      PlayerRole.goalkeeper => Cyber.gold,
      PlayerRole.batsman => Cyber.cyan,
      PlayerRole.bowler => Cyber.magenta,
      PlayerRole.basketballGuard => Cyber.gold,
      PlayerRole.basketballWing => Cyber.cyan,
      PlayerRole.basketballBig => Cyber.violet,
    };
    final small = size == VisualCardSize.sm;
    final large = size == VisualCardSize.lg;
    final width = small ? 96.0 : (large ? 144.0 : 128.0);
    final height = small ? 144.0 : (large ? 216.0 : 192.0);

    // Angular HUD silhouette shared with the Play Match CTA; cuts scale with
    // the card so every size keeps the same proportion.
    final bigCut = (width * 0.13).clamp(10.0, 19.0);
    final smallCut = bigCut * 0.5;
    final clipper = HudChamferClipper(bigCut: bigCut, smallCut: smallCut);

    final scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );
    final rotateAnim = Tween<double>(begin: 0, end: 0.06).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _tapController,
      builder: (_, child) => Transform.scale(
        scale: scaleAnim.value,
        child: Transform.rotate(angle: rotateAnim.value, child: child),
      ),
      child: PremiumCardShell(
        width: width,
        height: height,
        selected: selected,
        disabled: disabled,
        accent: tier,
        selectedAccent: selectedAccent,
        clipper: clipper,
        onTap: onTap,
        builder: (hovered) {
          final content = ClipPath(
            clipper: clipper,
            child: Stack(
              children: [
                // Tier-graded foil fill — richer the higher the tier; the
                // gradient angle shifts on hover for a holographic shimmer.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _foilColors(tier, rank),
                        stops: _foilStops(rank),
                        transform: GradientRotation(hovered ? 1.13 : 0),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: CardStripePainter(color: tier)),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  top: 4,
                  bottom: height * 0.24,
                  child: card.hasPortrait
                      ? Image.asset(
                          card.resolvedPortraitAsset!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          // ignore: prefer_void_to_null
                          errorBuilder: (_, _, _) => _CardIconFallback(
                            card: card,
                            tier: tier,
                            small: small,
                            large: large,
                          ),
                        )
                      : _CardIconFallback(
                          card: card,
                          tier: tier,
                          small: small,
                          large: large,
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _OvrBadge(
                    rating: card.rating,
                    tier: tier,
                    rank: rank,
                    small: small,
                    large: large,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: Colors.black.withValues(alpha: 0.58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${playerRoleLabel(card)} - ${card.position.split('/').first}',
                          style: TextStyle(
                            color: posColor,
                            fontFamily: 'Orbitron',
                            fontSize: small ? 6 : (large ? 8 : 7),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          card.countryCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: small ? 5 : (large ? 7 : 6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: height * 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    color: Colors.black.withValues(alpha: 0.64),
                    child: Text(
                      card.trait,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: small ? 7 : (large ? 10 : 9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height * 0.24,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff202836), Color(0xff121824)],
                      ),
                      // Tier-coloured nameplate edge — another always-on rarity
                      // cue (no glow, so the rule stays intact).
                      border: Border(
                        left: BorderSide(
                          color: tier.withValues(alpha: 0.9),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TierPips(rank: rank, color: tier, small: small),
                        SizedBox(height: small ? 2 : 3),
                        Text(
                          card.shortName,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.w900,
                            fontSize: small ? 9 : (large ? 13 : 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          // Static rarity edge on idle/hover; selected uses a hard accent rim
          // (elevation + border live on [PremiumCardShell]).
          return CustomPaint(
            foregroundPainter: _CardFramePainter(
              tier: tier,
              accent: selected ? selectedAccent : tier,
              rank: rank,
              glow: selected ? 0 : (hovered ? 0.6 : 0.0),
              bigCut: bigCut,
              smallCut: smallCut,
            ),
            child: content,
          );
        },
      ),
    );
  }
}

/// Foil fill colours for a player card, graded by tier rank (0 bronze ·
/// 1 silver · 2 gold · 3 platinum). Higher tiers get a richer, lighter,
/// more iridescent base so rarity reads even before the edge is seen.
List<Color> _foilColors(Color tier, int rank) => switch (rank) {
  3 => [
    const Color(0xff0b1426),
    tier.withValues(alpha: 0.22),
    const Color(0xff141d3a),
    Cyber.violet.withValues(alpha: 0.18),
    const Color(0xff0b1426),
  ],
  2 => [
    const Color(0xff1a1606),
    tier.withValues(alpha: 0.16),
    const Color(0xff14130a),
    const Color(0xff0f1118),
  ],
  1 => [
    const Color(0xff141a24),
    tier.withValues(alpha: 0.12),
    const Color(0xff10151f),
    const Color(0xff0e1118),
  ],
  _ => [
    const Color(0xff19120c),
    tier.withValues(alpha: 0.10),
    const Color(0xff120f0e),
  ],
};

/// Gradient stops matching [_foilColors] for each tier rank.
List<double> _foilStops(int rank) => switch (rank) {
  3 => const [0, 0.30, 0.5, 0.72, 1],
  2 => const [0, 0.34, 0.7, 1],
  1 => const [0, 0.36, 0.7, 1],
  _ => const [0, 0.5, 1],
};

/// A row of four pips with `rank + 1` filled — a language-free rarity gauge
/// (1 = bronze … 4 = platinum) on the nameplate.
class _TierPips extends StatelessWidget {
  const _TierPips({
    required this.rank,
    required this.color,
    required this.small,
  });

  final int rank;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final filled = rank + 1;
    final d = small ? 4.0 : 5.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: d,
            height: d,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: i < filled
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.45)),
            ),
          ),
      ],
    );
  }
}

/// The OVR plate, restyled as a CTA-style compartment: an angular chamfer, a
/// metallic tier-graded face (brighter for gold/platinum), a hairline divider
/// and tabular figures.
class _OvrBadge extends StatelessWidget {
  const _OvrBadge({
    required this.rating,
    required this.tier,
    required this.rank,
    required this.small,
    required this.large,
  });

  final int rating;
  final Color tier;
  final int rank;
  final bool small;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final w = small ? 38.0 : (large ? 52.0 : 46.0);
    final h = small ? 32.0 : (large ? 44.0 : 40.0);
    final faceTop = Color.lerp(tier, Colors.white, rank >= 2 ? 0.6 : 0.3)!;
    final faceBottom = Color.lerp(tier, Cyber.bg, rank >= 1 ? 0.18 : 0.45)!;
    return ClipPath(
      clipper: HudChamferClipper(bigCut: small ? 7 : 9, smallCut: 3),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [faceTop, faceBottom],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$rating',
              style: TextStyle(
                color: Cyber.bg,
                fontFamily: 'Orbitron',
                fontSize: small ? 13 : (large ? 19 : 16),
                fontWeight: FontWeight.w900,
                height: 0.9,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Container(
              width: w * 0.4,
              height: 0.8,
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              color: Cyber.bg.withValues(alpha: 0.4),
            ),
            Text(
              'OVR',
              style: TextStyle(
                color: Cyber.bg,
                fontFamily: 'Orbitron',
                fontSize: small ? 5 : 6,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the card's angular edge. The static edge encodes rarity (heavier and
/// brighter — holographic for platinum — with tier rank) so bronze → platinum
/// reads at a glance; the soft blurred glow is gated on [glow] (hover/selected),
/// keeping the blurred glow scarce per the design rule.
class _CardFramePainter extends CustomPainter {
  const _CardFramePainter({
    required this.tier,
    required this.accent,
    required this.rank,
    required this.glow,
    required this.bigCut,
    required this.smallCut,
  });

  final Color tier;
  final Color accent;
  final int rank; // 0 bronze .. 3 platinum
  final double glow; // 0 resting .. 1 fully lit
  final double bigCut;
  final double smallCut;

  @override
  void paint(Canvas canvas, Size size) {
    final path = HudChamferClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    // Soft blurred glow — only when active (hover/selected).
    if (glow > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: 0.22 + 0.45 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 7 * glow);
      canvas.drawPath(path, glowPaint);
    }

    // Static rarity edge: thicker and brighter with tier rank.
    final edgeWidth = 1.0 + rank * 0.45;
    final a = (0.5 + rank * 0.12 + 0.3 * glow).clamp(0.0, 1.0);
    final List<Color> edgeColors = rank >= 3
        // Platinum: holographic white → cyan → violet rim (elite).
        ? [
            Colors.white.withValues(alpha: a),
            tier.withValues(alpha: a),
            Cyber.violet.withValues(alpha: a),
          ]
        : [
            Color.lerp(
              tier,
              Colors.white,
              0.15 + rank * 0.17,
            )!.withValues(alpha: a),
            tier.withValues(alpha: a),
          ];
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = edgeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: edgeColors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _CardFramePainter old) =>
      old.glow != glow ||
      old.rank != rank ||
      old.tier != tier ||
      old.accent != accent ||
      old.bigCut != bigCut ||
      old.smallCut != smallCut;
}

class CyberActionCardTile extends StatefulWidget {
  const CyberActionCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.disabledLabel = 'IN DECK',
    this.size = VisualCardSize.sm,
    this.selectedAccent = Cyber.cyan,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final bool disabled;
  final String disabledLabel;
  final VisualCardSize size;
  final Color selectedAccent;
  final VoidCallback? onTap;

  @override
  State<CyberActionCardTile> createState() => _CyberActionCardTileState();
}

class _CyberActionCardTileState extends State<CyberActionCardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (widget.selected) {
      _tapController.value = 1;
    }
  }

  @override
  void didUpdateWidget(CyberActionCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _tapController.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _tapController.reverse();
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = actionColor(widget.card.category);
    final catAccent = switch (widget.card.category) {
      ActionCategory.attack => Cyber.danger,
      ActionCategory.defense => Cyber.violet,
      ActionCategory.special => Cyber.gold,
    };
    final catColors = switch (widget.card.category) {
      ActionCategory.attack => const [Color(0xff1a1520), Color(0xff200d0d)],
      ActionCategory.defense => const [Color(0xff151020), Color(0xff1d0d2b)],
      ActionCategory.special => const [Color(0xff0d1520), Color(0xff1a1520)],
    };
    // The card's power IS its rating — render it in the score colour (gold, per
    // cyber-ui) at full weight so the headline stat is never the dim element.
    // Magnitude is conveyed by the value itself, not by fading low values out.
    const ratingColor = Cyber.gold;
    // Bronze read too close to gold on the thin tier strip; deepen it to a true
    // copper bronze (matching the player OVR plate) so the tier is unmistakable.
    final stripColor = widget.card.tier == CardTier.bronze
        ? const Color(0xffa85f25)
        : tierColor(widget.card.tier);
    final large = widget.size == VisualCardSize.lg;

    final scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );
    final rotateAnim = Tween<double>(begin: 0, end: 0.08).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _tapController,
      builder: (_, _) {
        return Transform.scale(
          scale: scaleAnim.value,
          child: Transform.rotate(
            angle: rotateAnim.value,
            child: PremiumCardShell(
              width: large ? 116 : 96,
              height: large ? 162 : 128,
              selected: widget.selected,
              disabled: widget.disabled,
              disabledLabel: widget.disabledLabel,
              accent: widget.card.risky ? Cyber.magenta : catAccent,
              selectedAccent: widget.selectedAccent,
              clipper: RectangleClipper(),
              onTap: widget.onTap,
              tapSound: switch (widget.card.category) {
                ActionCategory.attack => SoundEffect.attack,
                ActionCategory.defense => SoundEffect.defense,
                ActionCategory.special => SoundEffect.special,
              },
              builder: (hovered) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: widget.selected
                        ? null
                        : Border.all(
                            color: widget.card.risky
                                ? Cyber.magenta
                                : catAccent.withValues(alpha: 0.55),
                          ),
                    gradient: widget.selected
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: catColors,
                            transform: GradientRotation(hovered ? 1.13 : 0),
                          ),
                  ),
                  child: ClipPath(
                    clipper: RectangleClipper(),
                    child: Stack(
                      children: [
                        // Top accent line (category color).
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(height: 2, color: catAccent),
                        ),
                        Positioned(
                          top: 2,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            color: catAccent,
                            child: Text(
                              actionCode(widget.card.category),
                              style: const TextStyle(
                                color: Cyber.bg,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          // Top inset clears the single-line rating badge so
                          // the centred icon never tucks under it.
                          padding: EdgeInsets.fromLTRB(
                            8,
                            large ? 26 : 24,
                            8,
                            8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                widget.card.icon,
                                color: color,
                                size: large ? 28 : 24,
                              ),
                              Text(
                                widget.card.title.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                // Scale the headline with the card (frozen at 9
                                // it read tiny on the lg reveal face), mirroring
                                // CyberPlayerCardTile's size-aware text.
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: large ? 14 : 9,
                                ),
                              ),
                              Text(
                                widget.card.effect,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.76),
                                  fontSize: large ? 10 : 7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.card.risky)
                          const Positioned(
                            bottom: 3,
                            left: 3,
                            child: Icon(
                              Icons.dangerous,
                              color: Cyber.danger,
                              size: 13,
                            ),
                          ),
                        // Tier strip along the bottom edge so each tiered
                        // version of an action reads at a glance.
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(height: 6, color: stripColor),
                        ),
                        // Rating badge — headline stat; stays flat when selected
                        // (elevation is handled by [PremiumCardShell]).
                        Positioned(
                          top: 2,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
                            decoration: BoxDecoration(
                              color: Cyber.bg.withValues(alpha: 0.85),
                              border: const Border(
                                left: BorderSide(color: ratingColor, width: 3),
                                bottom: BorderSide(color: Color(0x73ffd166)),
                              ),
                            ),
                            // Single line keeps the badge short so it never
                            // reaches the centred icon below it.
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'PWR',
                                  style: TextStyle(
                                    color: ratingColor.withValues(alpha: 0.72),
                                    fontFamily: Cyber.displayFont,
                                    fontSize: 6,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '+${widget.card.power}',
                                  style: TextStyle(
                                    color: ratingColor,
                                    fontFamily: Cyber.displayFont,
                                    fontSize: large ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Standard press feedback for tappable HUD surfaces: a quick scale-down to
/// 0.97 while the pointer is down, matching the action-card tap feel. Wrap the
/// visual only — supply [onTap] here instead of an outer GestureDetector.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _active ? widget.onTap : null,
      onTapDown: _active ? (_) => _setPressed(true) : null,
      onTapUp: _active ? (_) => _setPressed(false) : null,
      onTapCancel: _active ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class CyberChip extends StatelessWidget {
  const CyberChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Onest',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class CardStripePainter extends CustomPainter {
  const CardStripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CardStripePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A one-shot "slide up + fade in" entrance. Wrap any element to have it rise
/// into place on first build; stagger siblings by passing increasing [delay]s.
/// Used for the lobby entrance reveals (home + shootout landing pages).
class CyberSlideUpFadeIn extends StatefulWidget {
  const CyberSlideUpFadeIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 30,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<CyberSlideUpFadeIn> createState() => _CyberSlideUpFadeInState();
}

class _CyberSlideUpFadeInState extends State<CyberSlideUpFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _kickoff = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, child) => Opacity(
        opacity: _progress.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _progress.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A looping pulse driver for "live" HUD elements (alerts, active indicators,
/// ON FIRE states). Rebuilds [builder] with `t` sweeping 0 → 1 → 0 each
/// [period]. Keep it scarce — a pulse marks the one live thing on screen.
class CyberPulse extends StatefulWidget {
  const CyberPulse({
    required this.builder,
    this.period = const Duration(milliseconds: 900),
    super.key,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration period;

  @override
  State<CyberPulse> createState() => _CyberPulseState();
}

class _CyberPulseState extends State<CyberPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}

/// A one-shot "dealt card" entrance: the child flies up from below with a slight
/// alternating tilt and an easeOutBack settle, fading in along the way. Use for
/// rows of stat cells / action buttons; stagger via [index] + [staggerMs].
class CyberDealtCard extends StatefulWidget {
  const CyberDealtCard({
    required this.index,
    required this.child,
    this.initialDelay = const Duration(milliseconds: 220),
    this.staggerMs = 75,
    this.flyDistance = 260,
    this.duration = const Duration(milliseconds: 540),
    super.key,
  });

  final int index;
  final Widget child;
  final Duration initialDelay;
  final int staggerMs;
  final double flyDistance;
  final Duration duration;

  @override
  State<CyberDealtCard> createState() => _CyberDealtCardState();
}

class _CyberDealtCardState extends State<CyberDealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _settle;
  late final Animation<double> _opacity;
  late final Animation<double> _tilt;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _settle = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );
    _tilt = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    final delay =
        widget.initialDelay +
        Duration(milliseconds: widget.index * widget.staggerMs);
    _kickoff = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        const tiltAmount = 0.07;
        final tiltAngle =
            (widget.index.isEven ? -tiltAmount : tiltAmount) *
            (1 - _tilt.value);
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.flyDistance * (1 - _slide.value)),
            child: Transform.rotate(
              angle: tiltAngle,
              child: Transform.scale(
                scale: _settle.value.clamp(0.5, 1.2),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Frame painter for HUD bottom sheets: chamfered border + cyan→magenta accent
/// stripe along the top edge. Used by order-ticket and filter sheets.
class HudSheetFramePainter extends CustomPainter {
  const HudSheetFramePainter({this.bigCut = 18, this.smallCut = 4});

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
        ..strokeWidth = 1
        ..color = Cyber.border,
    );

    final topPath = Path()
      ..moveTo(0, bigCut)
      ..lineTo(bigCut, 0)
      ..lineTo(size.width - smallCut, 0)
      ..lineTo(size.width, smallCut);
    canvas.drawPath(
      topPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          colors: const [
            Colors.transparent,
            Cyber.cyan,
            Cyber.magenta,
            Colors.transparent,
          ],
          stops: const [0, 0.28, 0.72, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, bigCut + smallCut)),
    );
  }

  @override
  bool shouldRepaint(covariant HudSheetFramePainter old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

// ── Pager dock: PREVIOUS / NEXT button + progress segments ────────────────────
// Shared by the prediction quiz and the profile-setup wizard so the paginated
// "one step at a time" dock looks identical everywhere.

/// An angular HUD pager button on the [HudChamferClipper] silhouette.
/// [focal] = the bright glowing forward CTA (NEXT/SUBMIT); otherwise a calm dark
/// plate (PREVIOUS). Disabled state dims content and calms the plate.
class HudPagerButton extends StatelessWidget {
  const HudPagerButton({
    required this.label,
    required this.focal,
    required this.enabled,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  });

  final String label;
  final bool focal;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final Color content = !enabled
        ? Cyber.muted
        : focal
        ? const Color(0xff06121b)
        : Cyber.cyan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 56,
        child: CustomPaint(
          painter: _HudPagerButtonPainter(focal: focal, enabled: enabled),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, color: content, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: Cyber.body(
                      16,
                      color: content,
                      weight: FontWeight.w800,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, color: content, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudPagerButtonPainter extends CustomPainter {
  const _HudPagerButtonPainter({required this.focal, required this.enabled});
  final bool focal;
  final bool enabled;

  static const _clipper = HudChamferClipper(bigCut: 14, smallCut: 7);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _clipper.buildPath(size);
    if (focal) {
      // Bright glowing forward CTA (NEXT / SUBMIT).
      canvas.drawPath(
        path,
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(Cyber.cyan, Colors.white, 0.28)!, Cyber.cyan],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: enabled ? 0.72 : 0.32),
      );
    } else {
      // Calm dark plate (PREVIOUS, or a disabled forward action).
      canvas.drawPath(
        path,
        Paint()
          ..color = enabled ? const Color(0xff1b2336) : const Color(0xff141a26),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = enabled
              ? Cyber.cyan.withValues(alpha: 0.45)
              : Cyber.line.withValues(alpha: 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HudPagerButtonPainter old) =>
      old.focal != focal || old.enabled != enabled;
}

// Progress-segment palette (green = done, amber = current, slate = pending).
const _segGreenA = Color(0xFF00C850);
const _segGreenB = Color(0xFF009865);
const _segAmberA = Color(0xFFFFB13D);
const _segAmberB = Color(0xFFFF7A1A);
const _segTrack = Color(0xFF314158);

/// One bar in a paginated progress row: amber "you are here" for [current],
/// green for already-[answered]/passed, slate otherwise. Only the current
/// segment glows.
class HudProgressSegment extends StatelessWidget {
  const HudProgressSegment({
    required this.answered,
    required this.current,
    super.key,
  });

  final bool answered;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final Gradient? gradient = current
        ? const LinearGradient(colors: [_segAmberA, _segAmberB])
        : answered
        ? const LinearGradient(colors: [_segGreenA, _segGreenB])
        : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 8,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? _segTrack : null,
        boxShadow: current
            ? Cyber.glow(Cyber.amber, alpha: 0.35, blur: 8)
            : null,
      ),
    );
  }
}

/// A countdown ring + caption — the "card select starts in…" / launch-sequence
/// 3·2·1 block. Drives off an external repeating [scanner] animation (for the
/// sweeping radar) and a [seconds] value the parent decrements. Shared across
/// the match scenario briefing, the penalty shootout, and onboarding launch.
class CountdownBlock extends StatelessWidget {
  const CountdownBlock({
    required this.seconds,
    required this.scanner,
    required this.accent,
    this.caption = 'Card select starts in...',
    super.key,
  });

  final int seconds;
  final Animation<double> scanner;
  final Color accent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CountdownRing(seconds: seconds, scanner: scanner, accent: accent),
        const SizedBox(height: 12),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: Cyber.body(
            12,
            color: accent.withValues(alpha: 0.7),
            weight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.seconds,
    required this.scanner,
    required this.accent,
    super.key,
  });

  final int seconds;
  final Animation<double> scanner;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scanner,
      builder: (context, _) {
        final pulse = 1 + sin(scanner.value * pi * 2) * 0.025;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 154,
            height: 154,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CountdownRingPainter(scanner.value, accent),
                  ),
                ),
                Text(
                  seconds > 0 ? '$seconds' : 'GO',
                  style:
                      Cyber.display(
                        seconds > 0 ? 72 : 44,
                        color: accent,
                        letterSpacing: 0.8,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: accent.withValues(alpha: 0.85),
                            blurRadius: 24,
                          ),
                          Shadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 42,
                          ),
                        ],
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter(this.scan, this.accent);

  final double scan;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final faint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final line = Paint()
      ..color = accent.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi * 2,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.08),
          accent.withValues(alpha: 0.68),
          Colors.transparent,
        ],
        stops: const [0, 0.68, 0.82, 1],
        transform: GradientRotation(scan * pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 8, faint);
    canvas.drawCircle(center, radius - 28, faint);
    canvas.drawCircle(center, radius - 46, line);
    canvas.drawCircle(center, radius - 16, sweep);

    for (var i = 0; i < 12; i++) {
      final angle = (pi * 2 / 12) * i;
      final inner = radius - (i % 3 == 0 ? 25 : 18);
      final outer = radius - 8;
      final p1 = center + Offset(cos(angle), sin(angle)) * inner;
      final p2 = center + Offset(cos(angle), sin(angle)) * outer;
      canvas.drawLine(p1, p2, faint);
    }

    final crosshair = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crosshair,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crosshair,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.scan != scan || oldDelegate.accent != accent;
}

// ─── Gliding colour-morphing tab bar ─────────────────────────────────────────
/// One tab in a [CyberGlidingTabs] bar: a label, its own identity [accent], and
/// an [icon] builder so the active/inactive tint stays centralised (pass an
/// `Icon`, `SvgPicture`, or a `CustomPaint` glyph).
class CyberGlidingTab {
  const CyberGlidingTab({
    required this.label,
    required this.accent,
    required this.icon,
  });

  final String label;

  /// Each tab owns its identity colour; the active plate morphs between them as
  /// it glides.
  final Color accent;

  /// `(color) => glyph` — receives the resolved tint for the tab's current state.
  final Widget Function(Color color) icon;
}

/// A calm dark tab strip with ONE raised, glowing plate that GLIDES — and
/// colour-morphs between the per-tab accents — as you switch tabs. Per the glow
/// rule only that active plate glows; resting tabs stay colour-coded in a calm,
/// desaturated take on their OWN accent so each identity reads at a glance. The
/// active tab's icon pops with an elastic bounce.
///
/// This is the match-hub bar (PREDICT / PICK / GAMES); reuse it for any top tab
/// row that wants the same travel feel (e.g. the shop catalogue tabs).
class CyberGlidingTabs extends StatefulWidget {
  const CyberGlidingTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    super.key,
  });

  final List<CyberGlidingTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  State<CyberGlidingTabs> createState() => _CyberGlidingTabsState();
}

class _CyberGlidingTabsState extends State<CyberGlidingTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  // The continuously-interpolated tab index that drives the plate's position
  // and accent as it slides between tabs. Whole values land on a tab; the
  // fractional range in between is where the colour morphs.
  late double _displayIndex = widget.activeIndex.toDouble();
  double _fromIndex = 0;

  static const _rowHeight = 61.0;
  static const _chamfer = 16.0; // bottom corner cut on the active plate
  static const _fill = AppTheme.unselectedColor;
  static const _activeInk = AppTheme.darkInk; // dark ink on the bright plate
  static const _mutedInk = AppTheme.textMedium;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_onTick);
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  void _onTick() {
    final target = widget.activeIndex.toDouble();
    setState(() {
      _displayIndex = _fromIndex + (target - _fromIndex) * _curve.value;
    });
  }

  @override
  void didUpdateWidget(covariant CyberGlidingTabs old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) {
      _fromIndex = _displayIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// Lerps across the per-tab accents so the plate morphs colour while it glides.
  Color _accentAt(double t) {
    final tabs = widget.tabs;
    final clamped = t.clamp(0.0, (tabs.length - 1).toDouble());
    final i = clamped.floor();
    if (i >= tabs.length - 1) return tabs.last.accent;
    return Color.lerp(tabs[i].accent, tabs[i + 1].accent, clamped - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final plateAccent = _accentAt(_displayIndex);
    return SizedBox(
      height: _rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The uniform dark tab row — every tab fills this full height.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _fill,
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.16)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / widget.tabs.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The active plate — flush, the SAME height as every tab. It
                    // stands out via its bright fill + glow + chamfer, not size.
                    Positioned(
                      left: tabWidth * _displayIndex,
                      top: 0,
                      width: tabWidth,
                      height: _rowHeight,
                      child: CustomPaint(
                        painter: _GlidingActiveTabPainter(
                          accent: plateAccent,
                          chamfer: _chamfer,
                        ),
                      ),
                    ),
                    // Tab content — every tab fills the row and centres its
                    // icon+label on the same baseline.
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < widget.tabs.length; i++)
                            Expanded(
                              child: _GlidingTab(
                                key: ValueKey('cyber_gliding_tab_$i'),
                                data: widget.tabs[i],
                                active: i == widget.activeIndex,
                                activeInk: _activeInk,
                                mutedInk: _mutedInk,
                                onTap: () {
                                  if (i == widget.activeIndex) return;
                                  playSound(SoundEffect.uiTap);
                                  HapticFeedback.selectionClick();
                                  widget.onTap(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlidingTab extends StatelessWidget {
  const _GlidingTab({
    super.key,
    required this.data,
    required this.active,
    required this.activeInk,
    required this.mutedInk,
    required this.onTap,
  });

  final CyberGlidingTab data;
  final bool active;
  final Color activeInk;
  final Color mutedInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Active: dark ink reads on the bright accent plate. Resting: a calm,
    // desaturated take on the tab's OWN accent so each tab stays colour-coded.
    final Color color = active
        ? activeInk
        : Color.lerp(data.accent, mutedInk, 0.32)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon pops with an elastic bounce as its tab takes focus.
          AnimatedScale(
            scale: active ? 1.0 : 0.84,
            duration: const Duration(milliseconds: 380),
            curve: active ? Curves.elasticOut : Curves.easeOutCubic,
            child: SizedBox(width: 18, height: 18, child: data.icon(color)),
          ),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: Cyber.label(
              active ? 12 : 10,
              color: color,
              weight: active ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: active ? 0.5 : 0.3,
              height: active ? 1.25 : 1.5,
            ),
            child: Text(data.label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// Paints the active tab as a FLUSH bright plate — the same height as every tab,
/// no overhang. A square-topped, chamfered-bottom trapezoid (floating with a
/// small side gap) filled with a bright vertical accent gradient, a crisp accent
/// edge and top sheen, and — as the one focal, "live" element — wrapped in a soft
/// accent glow halo so it stands out by light, not size. Accent morphs in as the
/// plate glides.
class _GlidingActiveTabPainter extends CustomPainter {
  const _GlidingActiveTabPainter({required this.accent, required this.chamfer});

  final Color accent;
  final double chamfer;

  @override
  void paint(Canvas canvas, Size size) {
    const sideInset = 7.0;
    final bottom = size.height;
    final path = Path()
      ..moveTo(sideInset, 0)
      ..lineTo(size.width - sideInset, 0)
      ..lineTo(size.width - sideInset, bottom - chamfer)
      ..lineTo(size.width - sideInset - chamfer, bottom)
      ..lineTo(sideInset + chamfer, bottom)
      ..lineTo(sideInset, bottom - chamfer)
      ..close();

    // Focal "live" element → a scarce accent glow halo is allowed (and wanted).
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Bright vertical accent gradient fill.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(accent, Colors.white, 0.30)!, accent],
        ).createShader(Offset.zero & size),
    );

    // Crisp brightened accent edge.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(accent, Colors.white, 0.45)!,
    );

    // Top sheen highlight.
    canvas.drawLine(
      const Offset(sideInset + 2, 1.5),
      Offset(size.width - sideInset - 2, 1.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _GlidingActiveTabPainter old) =>
      old.accent != accent || old.chamfer != chamfer;
}

/// A face-down card on the shared chamfered card silhouette: flat [Cyber.panel]
/// fill, diagonal-line weave and a dim centre emblem. Used wherever a card
/// exists but its value is hidden (Duel Board opponent deck row and
/// placed-but-unrevealed arena slots). Size it from the outside (SizedBox /
/// AspectRatio ~0.64 to match card tiles).
class CardBackFace extends StatelessWidget {
  const CardBackFace({
    this.accent = Cyber.cyan,
    this.dimmed = false,
    super.key,
  });

  final Color accent;

  /// Greys the back out (red-carded / spent slots in a face-down row).
  final bool dimmed;

  static const _clipper = HudChamferClipper(bigCut: 9, smallCut: 4.5);

  @override
  Widget build(BuildContext context) {
    final tone = dimmed ? Cyber.muted : accent;
    final weave = tone.withValues(alpha: dimmed ? 0.14 : 0.28);
    final edge = tone.withValues(alpha: dimmed ? 0.30 : 0.55);
    return CustomPaint(
      foregroundPainter: _CardBackEdgePainter(color: edge),
      child: ClipPath(
        clipper: _clipper,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(color: Cyber.panel)),
            CustomPaint(painter: _CardBackWeavePainter(lineColor: weave)),
            Center(
              child: Image.asset(
                'assets/icons/app_logo.png',
                width: 22,
                height: 22,
                color: edge,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.bolt, size: 20, color: edge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diagonal-line weave confined to the card bounds (same pattern language as
/// the pack-reveal card back).
class _CardBackWeavePainter extends CustomPainter {
  const _CardBackWeavePainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const spacing = 10.0;
    final diag = size.width + size.height;
    for (double d = -diag; d < diag; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CardBackWeavePainter old) => old.lineColor != lineColor;
}

class _CardBackEdgePainter extends CustomPainter {
  const _CardBackEdgePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CardBackFace._clipper.buildPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CardBackEdgePainter old) => old.color != color;
}
