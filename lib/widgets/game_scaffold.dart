import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'cyber/cyber_widgets.dart';

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.showShop = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showShop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReactHeaderBar(
        title: title,
        subtitle: subtitle,
        onBack: leading == null ? null : () => Navigator.maybePop(context),
        leftSlot: leading,
        showShop: showShop,
      ),
      body: CyberBackground(child: child),
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
    this.showShop = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leftSlot;
  final Widget? rightSlot;
  final bool showShop;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0b1120), Color(0xff070b14)],
          ),
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
              child: Column(
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
                  if (subtitle != null)
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
              ),
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

