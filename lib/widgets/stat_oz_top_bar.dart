import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../blocs/game/game_bloc.dart';
import '../models/streak.dart';
import '../utils/sound_effects.dart';
import '../config/theme.dart';

class StatOzTopBar extends StatelessWidget {
  const StatOzTopBar({
    required this.title,
    required this.onAddCoins,
    this.accent = Cyber.cyan,
    this.onStreakTap,
    super.key,
  });

  final String title;
  final VoidCallback onAddCoins;
  final Color accent;
  final VoidCallback? onStreakTap;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select<GameBloc, ({int coins, int streak})>(
      (bloc) => (
        coins: bloc.state.coins,
        streak: bloc.state.streak.current(StreakCategory.overall),
      ),
    );

    // Fold the status-bar inset into the bar so its fill covers the status bar
    // (the host screen wraps this in SafeArea(top: false)). Content stays 54px.
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Container(
      height: 78 + topInset,
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xff1a253a),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.26)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                height: 1,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.3), blurRadius: 12),
                ],
              ),
            ),
          ),
          _TopBarStreak(value: _formatInt(wallet.streak), onTap: onStreakTap),
          const SizedBox(width: 12),
          _TopBarCoinPill(
            coins: wallet.coins == 0 ? 1000 : wallet.coins,
            accent: accent,
            onAdd: onAddCoins,
          ),
        ],
      ),
    );
  }
}

class _TopBarStreak extends StatelessWidget {
  const _TopBarStreak({required this.value, this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department_outlined,
          color: StreakTheme.primary,
          size: 22,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: Cyber.displayFont,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap!();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: content,
      ),
    );
  }
}

class _TopBarCoinPill extends StatelessWidget {
  const _TopBarCoinPill({
    required this.coins,
    required this.accent,
    required this.onAdd,
  });

  final int coins;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/oz_coins.svg',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 7),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: coins.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => Text(
              _formatInt(value.round()),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              playSound(SoundEffect.uiTap);
              onAdd();
            },
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent),
              child: const Icon(Icons.add, color: Color(0xff0d111a), size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
