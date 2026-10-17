import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Shared Fuse treatment with native keyboard/focus support for this lobby.
class FinalOverFuseCta extends StatefulWidget {
  const FinalOverFuseCta({
    required this.label,
    required this.onTap,
    this.loading = false,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  @override
  State<FinalOverFuseCta> createState() => _FinalOverFuseCtaState();
}

class _FinalOverFuseCtaState extends State<FinalOverFuseCta> {
  bool _focus = false;
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
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (value) => setState(() => _focus = value),
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
        child: CustomPaint(
          foregroundPainter: _focus
              ? const ChamferedActionBorderPainter(
                  clipper: HudChamferClipper(bigCut: 16, smallCut: 5),
                  color: AppTheme.whiteColor,
                  width: 3,
                )
              : null,
          child: CyberFuseCtaButton(
            label: label,
            onTap: _enabled ? widget.onTap : null,
            tapSound: SoundEffect.playMatch,
            // This is an untimed lobby: no fabricated countdown/fuse value.
          ),
        ),
      ),
    );
  }
}
