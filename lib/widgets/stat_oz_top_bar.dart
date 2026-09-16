import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../blocs/game/game_bloc.dart';
import '../models/streak.dart';
import '../screens/predictions/streak_calendar_screen.dart';
import '../utils/sound_effects.dart';
import '../config/theme.dart';
import 'cyber/cyber_underline_tabs.dart';
import 'streak_widgets.dart';

const _barFill = Color(0xff1a253a);

class StatOzTopBar extends StatelessWidget {
  const StatOzTopBar({
    required this.title,
    required this.onAddCoins,
    this.accent = Cyber.cyan,
    this.onStreakTap,
    this.leading,
    super.key,
  });

  final String title;
  final VoidCallback onAddCoins;
  final Color accent;

  /// Opens the streak hub. Null falls back to the hub without quest routing,
  /// so the flame is live on every screen that shows this bar.
  final VoidCallback? onStreakTap;

  /// Back action shown before the title when the bar isn't a tab root.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final wallet = context
        .select<
          GameBloc,
          ({int coins, int streak, StreakFlameState flame, bool questReady})
        >((bloc) {
          final now = DateTime.now();
          final streak = bloc.state.streak;
          return (
            coins: bloc.state.coins,
            streak: streak.current(StreakCategory.overall, now: now),
            flame: streakFlameState(streak, now),
            questReady: bloc.state.dailyQuests.claimableCoins > 0,
          );
        });

    // Fold the status-bar inset into the bar so its fill covers the status bar
    // (the host screen wraps this in SafeArea(top: false)). Content stays 54px.
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Container(
      height: 78 + topInset,
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 14, 12),
      decoration: BoxDecoration(
        color: _barFill,
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
          if (leading != null) ...[
            SizedBox(width: 34, height: 40, child: leading),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontWeight: FontWeight.w900,
                // A back action costs the title 40px of the bar's width.
                fontSize: leading == null ? 22 : 19,
                height: 1,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.3), blurRadius: 12),
                ],
              ),
            ),
          ),
          _TopBarStreak(
            value: _formatInt(wallet.streak),
            flame: wallet.flame,
            questReady: wallet.questReady,
            onTap: onStreakTap ?? () => showStreakCalendar(context),
          ),
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

/// Tab-root page shell: the [topBar] and any [collapsible] rows beneath it (the
/// MATCH / GAMES switcher) scroll away with the feed, while [pinned] — the sport
/// strip — sticks to the top so switching sport is always one tap away.
///
/// The status-bar inset keeps the bar fill, so the pinned strip parks below the
/// system clock instead of sliding under it. Body scroll views need no wiring:
/// [NestedScrollView] hands them its controller on every platform.
class StatOzCollapsingHeaderView extends StatelessWidget {
  const StatOzCollapsingHeaderView({
    required this.topBar,
    required this.pinned,
    required this.body,
    this.collapsible,
    super.key,
  });

  final Widget topBar;
  final Widget? collapsible;
  final Widget pinned;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Column(
      children: [
        ColoredBox(
          color: _barFill,
          child: SizedBox(height: topInset, width: double.infinity),
        ),
        Expanded(
          // The inset is painted above, so the bar inside must not add it again.
          child: MediaQuery.removeViewPadding(
            context: context,
            removeTop: true,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [topBar, ?collapsible],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: CyberPinnedTabsDelegate(child: pinned),
                ),
              ],
              body: body,
            ),
          ),
        ),
      ],
    );
  }
}

/// Flame tally in the top bar. The flame colour carries the streak state
/// (gold live / amber pending / red at risk); a gold beacon dot marks rewards
/// waiting in the quest vault. Persistent chrome, so nothing pulses here.
class _TopBarStreak extends StatelessWidget {
  const _TopBarStreak({
    required this.value,
    required this.flame,
    required this.questReady,
    required this.onTap,
  });

  final String value;
  final StreakFlameState flame;
  final bool questReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '$value day streak${questReady ? ', quest rewards ready' : ''}. Open streaks',
      child: GestureDetector(
        key: const ValueKey('top-bar-streak'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  StreakFlame(state: flame, size: 22, animate: false),
                  if (questReady)
                    Positioned(
                      right: -2,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Cyber.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: _barFill, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: Cyber.display(15, letterSpacing: 0).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
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
