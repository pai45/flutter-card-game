import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_widgets.dart'
    show ChamferedActionSurface, HudChamferClipper, SectionLabel;

enum CyberActionVariant { primary, secondary, icon }

/// A flat technical action. Only an enabled primary action receives a halo.
/// The parent chooses the single primary action in a composition.
class CyberActionButton extends StatefulWidget {
  const CyberActionButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.variant = CyberActionVariant.primary,
    this.loading = false,
    this.autofocus = false,
    this.bare = false,
    this.tapSound = SoundEffect.uiTap,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final CyberActionVariant variant;
  final bool loading;
  final bool autofocus;

  /// Icon-only utility control without a painted surface or border. It keeps
  /// the standard 48 px hit target and semantic button behavior.
  final bool bare;
  final SoundEffect tapSound;

  @override
  State<CyberActionButton> createState() => _CyberActionButtonState();
}

class _CyberActionButtonState extends State<CyberActionButton> {
  final _focusNode = FocusNode();
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;
  bool _hasFocus = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    playSound(widget.tapSound);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final primary = widget.variant == CyberActionVariant.primary;
    final compact = widget.variant == CyberActionVariant.icon;
    final ink = !_enabled
        ? Cyber.muted
        : primary
        ? Cyber.bg
        : Cyber.cyan;
    final fill = _enabled && primary
        ? Cyber.cyan
        : (_hovered || _pressed) && _enabled
        ? Cyber.panel
        : Cyber.card;
    final label = widget.loading ? '${widget.label} · WORKING' : widget.label;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      liveRegion: widget.loading,
      focusable: _enabled,
      focused: _hasFocus,
      onFocus: _enabled ? _focusNode.requestFocus : null,
      onTap: _enabled ? _activate : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        onFocusChange: (value) => setState(() => _hasFocus = value),
        enabled: _enabled,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
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
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed && _enabled && !reduced ? 0.985 : 1,
            duration: reduced ? Duration.zero : CyberKit.press,
            child: Builder(
              builder: (context) {
                final content = Container(
                  constraints: BoxConstraints(
                    minHeight: compact
                        ? CyberKit.touchTarget
                        : CyberKit.actionHeight,
                    minWidth: CyberKit.touchTarget,
                  ),
                  color: widget.bare && compact ? Colors.transparent : fill,
                  padding: EdgeInsets.all(compact ? 12 : CyberKit.inset),
                  child: compact
                      ? Icon(
                          widget.icon,
                          size: 20,
                          color: _focused && widget.bare
                              ? AppTheme.textContrast
                              : ink,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: Cyber.label(
                                  12,
                                  color: ink,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: CyberKit.gap),
                            Icon(
                              widget.loading
                                  ? Icons.hourglass_top_rounded
                                  : widget.icon,
                              size: 20,
                              color: ink,
                            ),
                          ],
                        ),
                );
                if (widget.bare && compact) return content;
                return ChamferedActionSurface(
                  clipper: const HudChamferClipper(
                    bigCut: CyberKit.smallCut,
                    smallCut: 0,
                  ),
                  borderColor: _focused && _enabled
                      ? AppTheme.textContrast
                      : _enabled
                      ? Cyber.cyan
                      : Cyber.line,
                  borderWidth: _focused && _enabled
                      ? CyberKit.focusStroke
                      : CyberKit.stroke,
                  glowColor: Cyber.cyan,
                  glow: primary && _enabled ? 0.7 : 0,
                  child: content,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CyberKitSection extends StatelessWidget {
  const CyberKitSection({required this.label, this.count, super.key});
  final String label;
  final String? count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: SectionLabel(label: label)),
          if (count != null) ...[
            const SizedBox(width: CyberKit.gap),
            Text(
              count!,
              style: Cyber.label(
                11,
                color: Cyber.muted,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ],
      ),
      const SizedBox(height: CyberKit.gap),
      Row(
        children: [
          const SizedBox(
            width: 24,
            height: 2,
            child: ColoredBox(color: Cyber.cyan),
          ),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 1, color: Cyber.line)),
          const SizedBox(width: 4),
          const SizedBox(
            width: 4,
            height: 2,
            child: ColoredBox(color: Cyber.line),
          ),
        ],
      ),
    ],
  );
}

enum CyberStatusTone { available, locked, reward }

class CyberStatusBadge extends StatelessWidget {
  const CyberStatusBadge({
    required this.label,
    this.tone = CyberStatusTone.available,
    super.key,
  });
  final String label;
  final CyberStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      CyberStatusTone.available => Cyber.cyan,
      CyberStatusTone.locked => Cyber.muted,
      CyberStatusTone.reward => Cyber.gold,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(label, style: Cyber.label(9, color: color, letterSpacing: 1)),
    );
  }
}

class CyberSportEmblem extends StatelessWidget {
  const CyberSportEmblem({required this.icon, required this.accent, super.key});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ChamferedActionSurface(
      clipper: const HudChamferClipper(bigCut: CyberKit.cut, smallCut: 0),
      borderColor: accent.withValues(alpha: CyberKit.borderAlpha),
      child: Container(
        width: 64,
        height: 64,
        color: Cyber.panel,
        alignment: Alignment.center,
        child: Icon(icon, size: 32, color: accent),
      ),
    ),
  );
}

/// An informational route entry; purchase previews never launch games.
class CyberProgressionEntry extends StatelessWidget {
  const CyberProgressionEntry({
    required this.index,
    required this.title,
    required this.icon,
    required this.detail,
    this.featured = false,
    this.last = false,
    super.key,
  });
  final int index;
  final String title;
  final IconData icon;
  final String detail;
  final bool featured;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = featured ? Cyber.cyan : Cyber.muted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  index.toString().padLeft(2, '0'),
                  style: Cyber.label(11, color: color).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: CyberKit.gap),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(width: 1, color: Cyber.line),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: CyberKit.gap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: CyberKit.gap),
              child: ChamferedActionSurface(
                clipper: const HudChamferClipper(
                  bigCut: CyberKit.smallCut,
                  smallCut: 0,
                ),
                borderColor: featured
                    ? Cyber.cyan.withValues(alpha: CyberKit.borderAlpha)
                    : Cyber.line,
                child: Container(
                  color: featured ? Cyber.panel : Cyber.card,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (featured) ...[
                        const CyberStatusBadge(label: 'OPENS ON UNLOCK'),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: featured ? 24 : 18, color: color),
                          const SizedBox(width: CyberKit.gap),
                          Expanded(
                            child: Text(
                              title,
                              style: Cyber.display(
                                featured ? 17 : 12,
                                color: featured
                                    ? AppTheme.textContrast
                                    : Cyber.muted,
                              ),
                            ),
                          ),
                          if (!featured) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Cyber.muted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: CyberKit.gap),
                      Text(detail, style: Cyber.body(13, color: Cyber.muted)),
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

/// Adaptive bottom sheet: docked actions on roomy screens, one scroll surface
/// at large text sizes or short heights. No nested scrollable footer.
class CyberKitSheet extends StatelessWidget {
  const CyberKitSheet({
    required this.body,
    required this.footer,
    required this.onClose,
    super.key,
  });
  final Widget body;
  final Widget footer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : CyberKit.entrance,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 8 * (1 - value)),
          child: child,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Material(
            type: MaterialType.transparency,
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(
                bigCut: CyberKit.cut,
                smallCut: 0,
              ),
              borderColor: Cyber.cyan.withValues(alpha: CyberKit.borderAlpha),
              child: ColoredBox(
                color: Cyber.bg,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dock =
                        constraints.hasBoundedHeight &&
                        constraints.maxHeight >= CyberKit.dockMinHeight &&
                        MediaQuery.textScalerOf(context).scale(14) <= 16.8;
                    final content = Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CyberKit.inset,
                      ),
                      child: body,
                    );
                    final actions = Container(
                      padding: const EdgeInsets.all(CyberKit.inset),
                      decoration: const BoxDecoration(
                        color: Cyber.card,
                        border: Border(top: BorderSide(color: Cyber.line)),
                      ),
                      child: footer,
                    );
                    final chrome = Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 40,
                                height: 3,
                                child: ColoredBox(color: Cyber.line),
                              ),
                            ),
                          ),
                          CyberActionButton(
                            label: 'Close unlock sheet',
                            icon: Icons.close,
                            variant: CyberActionVariant.icon,
                            bare: true,
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    );
                    if (!dock) {
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            chrome,
                            content,
                            const SizedBox(height: 16),
                            actions,
                          ],
                        ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        chrome,
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: content,
                          ),
                        ),
                        actions,
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
}
