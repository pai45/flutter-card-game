import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import 'cyber_widgets.dart' show ChamferedActionSurface, HudChamferClipper;
import 'game_launch_art.dart';

export 'game_launch_art.dart' show CyberGameArt, CyberGameIllustration;

/// Shared discovery CTA: an etched simulation, a game title and a launch rail.
/// The whole card is one target, including its illustration and action rail.
class CyberGameLaunchCard extends StatefulWidget {
  const CyberGameLaunchCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.action,
    required this.art,
    required this.accent,
    required this.onTap,
    this.titleLines,
    this.portrait = false,
    this.animate = true,
    this.status,
    this.locked = false,
    super.key,
  });

  final String title;
  final List<String>? titleLines;
  final String subtitle;
  final String badge;
  final String action;
  final CyberGameArt art;
  final Color accent;
  final VoidCallback onTap;
  final bool portrait;
  final bool animate;
  final bool locked;
  final Widget? status;

  @override
  State<CyberGameLaunchCard> createState() => _CyberGameLaunchCardState();
}

class _CyberGameLaunchCardState extends State<CyberGameLaunchCard> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final active = (_hover || _focus || _pressed) && !widget.locked;
    final duration = Duration(milliseconds: reduced ? 0 : 120);
    return Semantics(
      button: true,
      label: '${widget.title}, ${widget.locked ? 'locked' : widget.action}',
      onTap: _activate,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
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
          onTap: _activate,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed && !reduced ? 0.985 : 1,
            duration: duration,
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 16, smallCut: 0),
              borderColor: widget.accent.withValues(
                alpha: active ? 0.95 : 0.42,
              ),
              borderWidth: active ? 1.5 : 1,
              child: ColoredBox(
                color: Cyber.panel,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        widget.portrait || constraints.maxWidth < 260;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: compact
                              ? _portrait(constraints.maxHeight)
                              : _landscape(constraints.maxWidth),
                        ),
                        _actionRail(compact, active, duration),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool compact) {
    final label = compact ? widget.badge.split('//').last.trim() : widget.badge;
    return Row(
      children: [
        Container(width: 3, height: 10, color: widget.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(
              10,
              color: widget.accent,
              letterSpacing: compact ? 0.6 : 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _illustration() => IgnorePointer(
    child: CyberGameIllustration(
      art: widget.art,
      accent: widget.accent,
      animate: widget.animate && !widget.locked,
    ),
  );

  Widget _title(double size) {
    final style = Cyber.display(
      size,
      color: AppTheme.whiteColor,
      letterSpacing: 0.5,
    ).copyWith(height: 1.12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.status != null) ...[
          widget.status!,
          const SizedBox(height: 4),
        ],
        if (widget.titleLines != null)
          for (final line in widget.titleLines!)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(line, style: style),
            )
        else
          Text(
            widget.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }

  Widget _subtitle(bool compact) => Text(
    widget.subtitle,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: Cyber.label(
      10,
      color: widget.accent,
      letterSpacing: 0.4,
    ).copyWith(height: 1.4),
  );

  Widget _landscape(double width) => Stack(
    children: [
      Positioned(
        top: 32,
        right: 8,
        bottom: 4,
        width: width * 0.49,
        child: _illustration(),
      ),
      Positioned(top: 16, left: 16, width: width - 32, child: _badge(false)),
      Positioned(
        left: 16,
        bottom: 16,
        width: width * 0.48 - 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _title(width < 350 ? 18 : 20),
            const SizedBox(height: 8),
            _subtitle(false),
          ],
        ),
      ),
    ],
  );

  Widget _portrait(double height) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _badge(true),
        Expanded(child: _illustration()),
        _title(height > 260 ? 17 : 15),
        const SizedBox(height: 4),
        _subtitle(true),
      ],
    ),
  );

  Widget _actionRail(bool compact, bool active, Duration duration) =>
      AnimatedContainer(
        duration: duration,
        padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, 12, 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            widget.accent.withValues(alpha: active ? 0.14 : 0.06),
            Cyber.bg2,
          ),
          border: Border(
            top: BorderSide(color: widget.accent.withValues(alpha: 0.24)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  10,
                  color: widget.accent,
                  letterSpacing: compact ? 0.6 : 1.4,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSlide(
              offset: active ? const Offset(0.14, 0) : Offset.zero,
              duration: duration,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: widget.accent,
                size: compact ? 14 : 18,
              ),
            ),
          ],
        ),
      );
}
