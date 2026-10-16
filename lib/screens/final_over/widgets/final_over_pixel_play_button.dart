import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme.dart';
import '../../../design_system/typography.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Feature-local arcade treatment, using the shared clipped-surface painter.
class FinalOverPixelPlayButton extends StatefulWidget {
  const FinalOverPixelPlayButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  @override
  State<FinalOverPixelPlayButton> createState() =>
      _FinalOverPixelPlayButtonState();
}

class _FinalOverPixelPlayButtonState extends State<FinalOverPixelPlayButton> {
  bool _pressed = false;
  bool _focus = false;
  bool _hover = false;
  bool get _enabled => widget.onTap != null && !widget.loading;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    playSound(SoundEffect.playMatch);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.loading ? 'LOADING SQUAD' : widget.label;
    final style = Cyber.bodyFor(
      context,
      StatOzTypography.p20,
      color: _enabled ? Cyber.bg : Cyber.muted,
      weight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.2,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final text = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, box.maxWidth - 40));
        final height = math.max(68.0, text.height + 24);
        return Semantics(
          button: true,
          enabled: _enabled,
          label: label,
          excludeSemantics: true,
          onTap: _enabled ? _activate : null,
          child: FocusableActionDetector(
            enabled: _enabled,
            onShowFocusHighlight: (v) => setState(() => _focus = v),
            onShowHoverHighlight: (v) => setState(() => _hover = v),
            mouseCursor: _enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _enabled ? _activate : null,
              onTapDown: _enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: SizedBox(
                height: height + 6,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      height: height,
                      child: ClipPath(
                        clipper: const _PixelStepClipper(),
                        child: ColoredBox(
                          color: _enabled
                              ? Color.alphaBlend(
                                  Cyber.cyan.withValues(alpha: .35),
                                  Cyber.bg,
                                )
                              : Cyber.line,
                        ),
                      ),
                    ),
                    Positioned(
                      top: _pressed && _enabled ? 4 : 0,
                      left: 0,
                      right: 0,
                      height: height,
                      child: ChamferedActionSurface(
                        clipper: const _PixelStepClipper(),
                        borderColor: _focus && _enabled
                            ? AppTheme.whiteColor
                            : _enabled
                            ? Cyber.cyan
                            : Cyber.line,
                        borderWidth: _focus && _enabled ? 2 : 1,
                        child: ColoredBox(
                          color: !_enabled
                              ? Cyber.panel
                              : _hover
                              ? Color.lerp(
                                  Cyber.cyan,
                                  AppTheme.whiteColor,
                                  .12,
                                )!
                              : Cyber.cyan,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Center(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: style,
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
          ),
        );
      },
    );
  }
}

class _PixelStepClipper extends CustomClipper<Path> {
  const _PixelStepClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(8, 0)
    ..lineTo(s.width - 8, 0)
    ..lineTo(s.width - 8, 4)
    ..lineTo(s.width - 4, 4)
    ..lineTo(s.width - 4, 8)
    ..lineTo(s.width, 8)
    ..lineTo(s.width, s.height - 8)
    ..lineTo(s.width - 4, s.height - 8)
    ..lineTo(s.width - 4, s.height - 4)
    ..lineTo(s.width - 8, s.height - 4)
    ..lineTo(s.width - 8, s.height)
    ..lineTo(8, s.height)
    ..lineTo(8, s.height - 4)
    ..lineTo(4, s.height - 4)
    ..lineTo(4, s.height - 8)
    ..lineTo(0, s.height - 8)
    ..lineTo(0, 8)
    ..lineTo(4, 8)
    ..lineTo(4, 4)
    ..lineTo(8, 4)
    ..close();
  @override
  bool shouldReclip(covariant _PixelStepClipper oldClipper) => false;
}
