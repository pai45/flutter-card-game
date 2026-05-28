import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

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

class CyberBackground extends StatefulWidget {
  const CyberBackground({
    required this.child,
    this.animated = false,
    super.key,
  });

  final Widget child;

  /// When true, the radial glow slowly drifts (used on the home screen).
  final bool animated;

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

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
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

class CyberCtaButton extends StatelessWidget {
  const CyberCtaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary
        ? const LinearGradient(colors: [Cyber.cyan, Color(0xff5cb4ff)])
        : LinearGradient(colors: [Cyber.panel2, Cyber.panel]);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipPath(
          clipper: CyberClipper(),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: bg,
              border: Border.all(color: primary ? Cyber.cyan : Cyber.line),
              boxShadow: [
                BoxShadow(
                  color: (primary ? Cyber.cyan : Cyber.bg).withValues(
                    alpha: 0.3,
                  ),
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
          ),
        ),
      ),
    );
  }
}

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(accent),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
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
  @override
  Path getClip(Size size) {
    const cut = 12.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

enum VisualCardSize { sm, md, lg }

// Full-luminance grayscale matrix for disabled/suspended cards.
const List<double> _grayscaleMatrix = <double>[
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Shared interaction shell for player/action cards. Handles the premium
/// states from the design spec: hover lift, selected lift+scale+pulsing glow
/// ring + glow dot, and disabled grayscale + "SUSPENDED" banner + shake on a
/// blocked tap. The [builder] receives the current hover state so inner
/// visuals (e.g. holographic gradients) can react.
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

  @override
  State<PremiumCardShell> createState() => _PremiumCardShellState();
}

class _PremiumCardShellState extends State<PremiumCardShell>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _hovered = false;

  @override
  void dispose() {
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) {
      _shake.forward(from: 0);
      return;
    }
    playSound(SoundEffect.cardSelect);
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
          animation: Listenable.merge([_pulse, _shake]),
          builder: (context, _) {
            final hot = _hovered && !widget.disabled;
            final lift = hot ? -3.0 : 0.0;
            final scale = hot ? 1.02 : 1.0;
            final shakeX = _shake.isAnimating
                ? sin(_shake.value * pi * 6) * 4 * (1 - _shake.value)
                : 0.0;
            final ring = widget.selected ? 3.0 + 3.0 * _pulse.value : 0.0;
            final glowA = widget.selected ? 0.25 - 0.15 * _pulse.value : 0.0;

            Widget card = SizedBox(
              width: widget.width,
              height: widget.height,
              child: widget.builder(_hovered),
            );

            if (widget.disabled) {
              card = ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                child: card,
              );
              card = Stack(
                children: [
                  card,
                  Positioned.fill(
                    child: ClipPath(
                      clipper: CyberClipper(),
                      child: _SuspendedBanner(widget.disabledLabel),
                    ),
                  ),
                ],
              );
            } else if (widget.selected) {
              card = Stack(
                children: [
                  card,
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: _GlowDot(_pulse.value, color: widget.selectedAccent),
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
                    boxShadow: widget.selected
                        ? [
                            BoxShadow(
                              color: widget.selectedAccent.withValues(
                                alpha: glowA,
                              ),
                              blurRadius: 22,
                              spreadRadius: ring,
                            ),
                            BoxShadow(
                              color: widget.selectedAccent.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 28,
                            ),
                          ]
                        : (hot
                              ? [
                                  BoxShadow(
                                    color: widget.accent.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ]
                              : null),
                  ),
                  child: card,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot(this.t, {required this.color});
  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6 + 0.4 * t),
            blurRadius: 8 + 4 * t,
            spreadRadius: 1,
          ),
        ],
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

class CyberPlayerCardTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tier = tierColor(card.tier);
    final posColor = switch (card.role) {
      PlayerRole.attacker => Cyber.cyan,
      PlayerRole.defender => Cyber.violet,
      PlayerRole.goalkeeper => Cyber.gold,
    };
    final small = size == VisualCardSize.sm;
    final large = size == VisualCardSize.lg;
    final width = small ? 96.0 : (large ? 144.0 : 128.0);
    final height = small ? 144.0 : (large ? 216.0 : 192.0);
    return PremiumCardShell(
      width: width,
      height: height,
      selected: selected,
      disabled: disabled,
      accent: tier,
      selectedAccent: selectedAccent,
      onTap: onTap,
      builder: (hovered) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? selectedAccent : tier.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1,
            ),
            // Holographic foil: angle shifts on hover (135deg -> ~200deg).
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xff111827),
                Color(0xff1a2540),
                Color(0xff111827),
              ],
              stops: const [0, 0.5, 1],
              transform: GradientRotation(hovered ? 1.13 : 0),
            ),
          ),
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
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
                          errorBuilder: (_, ___, ____) => _CardIconFallback(
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
                  child: Container(
                    width: small ? 36 : (large ? 48 : 44),
                    height: small ? 30 : (large ? 40 : 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white, tier]),
                      border: const Border(
                        left: BorderSide(color: Colors.black54, width: 2),
                        bottom: BorderSide(color: Colors.black54, width: 2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${card.rating}',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontFamily: 'Orbitron',
                            fontSize: small ? 12 : (large ? 17 : 15),
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                          ),
                        ),
                        const Text(
                          'OVR',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontSize: 5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff202836), Color(0xff121824)],
                      ),
                    ),
                    child: Text(
                      card.shortName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: small ? 9 : (large ? 13 : 12),
                      ),
                    ),
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
  }

  @override
  void didUpdateWidget(CyberActionCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _tapController.forward(from: 0);
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
    final powerColor = widget.card.power >= 15
        ? Cyber.gold
        : (widget.card.power >= 5 ? Cyber.cyan : Cyber.muted);
    final small = widget.size == VisualCardSize.sm;
    final large = widget.size == VisualCardSize.lg;

    final scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );
    final rotateAnim = Tween<double>(begin: 0, end: 0.08).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );
    final glowAnim = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_tapController, scaleAnim, rotateAnim, glowAnim]),
      builder: (_, __) {
        return Transform.scale(
          scale: scaleAnim.value,
          child: Transform.rotate(
            angle: rotateAnim.value,
            child: PremiumCardShell(
              width: small ? 80 : (large ? 112 : 96),
              height: small ? 96 : (large ? 148 : 128),
              selected: widget.selected,
              disabled: widget.disabled,
              disabledLabel: widget.disabledLabel,
              accent: widget.card.risky ? Cyber.magenta : catAccent,
              selectedAccent: widget.selectedAccent,
              onTap: widget.onTap,
              builder: (hovered) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: widget.selected
                        ? [
                            BoxShadow(
                              color: catAccent.withValues(
                                alpha: 0.3 * glowAnim.value,
                              ),
                              blurRadius: 24 * glowAnim.value,
                              spreadRadius: 4 * glowAnim.value,
                            ),
                          ]
                        : null,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.selected
                            ? widget.selectedAccent
                            : (widget.card.risky
                                  ? Cyber.magenta
                                  : catAccent.withValues(alpha: 0.55)),
                        width: widget.selected ? 1.5 : 1,
                      ),
                      gradient: LinearGradient(
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
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Text(
                                '+${widget.card.power}',
                                style: TextStyle(
                                  color: powerColor,
                                  fontFamily: Cyber.displayFont,
                                  fontSize: small ? 14 : (large ? 18 : 16),
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  widget.card.icon,
                                  color: color,
                                  size: small ? 20 : (large ? 28 : 24),
                                ),
                                Text(
                                  widget.card.title.toUpperCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  widget.card.effect,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: color.withValues(alpha: 0.76),
                                    fontSize: 7,
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
                        ],
                      ),
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
          fontWeight: FontWeight.w900,
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
