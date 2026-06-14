import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'cyber/cyber_widgets.dart';

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.rightSlot,
    this.titleUnderlay,
    this.compactHeader = false,
    this.showShop = false,
    this.showTitle = true,
    this.grain = false,
    this.safeAreaBottom = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? rightSlot;
  final Widget? titleUnderlay;
  final bool compactHeader;
  final bool showShop;
  final bool showTitle;

  /// Film-grain noise backdrop — reserved for the in-match (card game) screens.
  final bool grain;

  /// Inset the body content above the navigation bar (keeps the textured
  /// background full-bleed). Off for screens that manage their own bottom
  /// insets behind a full-bleed layout (e.g. [MatchPhaseScaffold]).
  final bool safeAreaBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReactHeaderBar(
        title: title,
        subtitle: subtitle,
        onBack: leading == null ? null : () => Navigator.maybePop(context),
        leftSlot: leading,
        rightSlot: rightSlot,
        titleUnderlay: titleUnderlay,
        compact: compactHeader,
        showShop: showShop,
        showTitle: showTitle,
      ),
      body: CyberBackground(
        grain: grain,
        child: safeAreaBottom ? SafeArea(top: false, child: child) : child,
      ),
    );
  }
}

class ReactHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const ReactHeaderBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.leftSlot,
    this.rightSlot,
    this.titleUnderlay,
    this.compact = false,
    this.showShop = false,
    this.showTitle = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leftSlot;
  final Widget? rightSlot;
  final Widget? titleUnderlay;
  final bool compact;
  final bool showShop;
  final bool showTitle;

  @override
  Size get preferredSize => Size.fromHeight(compact ? 56 : 66);

  @override
  Widget build(BuildContext context) {
    final barHeight = compact ? 54.0 : 64.0;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: barHeight,
      titleSpacing: 0,
      // The gradient lives in flexibleSpace so it paints the whole AppBar —
      // status-bar inset included — instead of just the toolbar.
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0b1120), Color(0xff070b14)],
          ),
        ),
      ),
      title: Container(
        height: barHeight,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            if (leftSlot != null)
              SizedBox(width: 42, height: 42, child: leftSlot)
            else if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Cyber.cyan,
              ),
            if (leftSlot != null || onBack != null) const SizedBox(width: 8),
            Expanded(
              child: showTitle
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '/',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (titleUnderlay != null) ...[
                          const SizedBox(height: 5),
                          titleUnderlay!,
                        ] else if (subtitle != null)
                          Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Cyber.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            ?rightSlot,
          ],
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: HudLine(),
      ),
    );
  }
}
