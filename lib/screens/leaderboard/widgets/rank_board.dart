import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/avatar_frame_option.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/staggered_card_entrance.dart';
import 'rank_widgets.dart';

/// The shared rank-board vocabulary: the gold #1 hero card, the two podium
/// cards, the flat rows, the pinned "your rank" bar and the small pills they
/// are built from.
///
/// Extracted from `leaderboard_screen.dart` once the in-match TOPS tab needed
/// the same treatment — both boards now render from these widgets so a rival
/// reads identically wherever they appear.

/// One row on a rank board. [score] is whatever the active board measures;
/// [xp] is the player's canonical XP, which drives their dossier.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    required this.movement,
    this.isNew = false,
    this.badge,
    this.isUser = false,
    this.team,
    this.xp = 0,
    this.subtitle,
  });

  /// >0 climbed, <0 dropped, 0 held.
  final int rank;
  final String name;
  final int score;
  final int movement;
  final bool isNew;
  final String? badge;
  final bool isUser;
  final SportTeam? team;

  /// The player's canonical XP (their `_Seed.base`), independent of the active
  /// board type/scope — drives the rival dossier's level and XP meter.
  final int xp;

  /// Optional detail line shown beside the movement badge (e.g. "4/5 CORRECT"
  /// on the in-match board). Null on the season boards.
  final String? subtitle;
}

typedef ScoreMeta = ({String unit});

String formatRankInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

/// `04h 12m` above an hour, `12m 05s` below — the granularity a board countdown
/// pill wants (the quiz screen's own hh:mm:ss line is deliberately separate).
String formatBoardCountdown(Duration remaining) {
  if (remaining <= Duration.zero) return '00m 00s';
  final hours = remaining.inHours;
  if (hours > 0) {
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours.toString().padLeft(2, '0')}h ${minutes}m';
  }
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${minutes}m ${seconds}s';
}

/// Reads the user's equipped avatar frame so their own card/row reflects the
/// cosmetic they bought. Null for every other entry.
List<Color>? _userFrameColors(BuildContext context, LeaderboardEntry entry) {
  if (!entry.isUser) return null;
  final equipped = avatarFrameOptionById(
    context.select<GameBloc, String>((b) => b.state.equippedAvatarFrameId),
  );
  if (equipped == null) return null;
  return frameRingColors(equipped.primary);
}

// ─── Podium ──────────────────────────────────────────────────────────────────

/// The top three: a wide gold hero card over two side-by-side runner-up cards.
class RankPodium extends StatelessWidget {
  const RankPodium({
    required this.entries,
    required this.meta,
    required this.accent,
    required this.animateCards,
    this.onTapEntry,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final ScoreMeta meta;
  final Color accent;
  final bool animateCards;
  final ValueChanged<LeaderboardEntry>? onTapEntry;

  VoidCallback? _tap(LeaderboardEntry entry) =>
      onTapEntry == null ? null : () => onTapEntry!(entry);

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];
    return Column(
      children: [
        StaggeredCardEntrance(
          index: 0,
          animate: animateCards,
          maxAnimatedIndex: entries.length,
          child: RankWinnerTile(
            entry: first,
            meta: meta,
            color: Cyber.gold,
            avatarSize: 86,
            primary: true,
            onTap: _tap(first),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StaggeredCardEntrance(
                index: 1,
                animate: animateCards,
                maxAnimatedIndex: entries.length,
                child: RankWinnerTile(
                  entry: second,
                  meta: meta,
                  color: accent,
                  avatarSize: 66,
                  onTap: _tap(second),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StaggeredCardEntrance(
                index: 2,
                animate: animateCards,
                maxAnimatedIndex: entries.length,
                child: RankWinnerTile(
                  entry: third,
                  meta: meta,
                  color: Cyber.amber,
                  avatarSize: 66,
                  onTap: _tap(third),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A podium card. [primary] is the champion layout (wide row, big score);
/// otherwise the compact runner-up column.
class RankWinnerTile extends StatelessWidget {
  const RankWinnerTile({
    required this.entry,
    required this.meta,
    required this.color,
    required this.avatarSize,
    this.primary = false,
    this.onTap,
    super.key,
  });

  final LeaderboardEntry entry;
  final ScoreMeta meta;
  final Color color;
  final double avatarSize;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Reflect the user's equipped avatar frame on their podium card too.
    final userFrameColors = _userFrameColors(context, entry);
    final tile = Container(
      padding: EdgeInsets.all(primary ? 16 : 12),
      decoration: cutCornerDecoration(
        color: primary
            ? Cyber.panel.withValues(alpha: 0.84)
            : Cyber.panel.withValues(alpha: 0.58),
        borderColor: color.withValues(alpha: primary ? 0.42 : 0.26),
        cut: primary ? 18 : 13,
      ),
      child: primary
          ? Row(
              children: [
                RivalAvatar(
                  name: entry.name,
                  size: avatarSize,
                  ring: color,
                  team: entry.team,
                  frameColors: userFrameColors,
                ),
                const SizedBox(width: 16),
                Expanded(child: _WinnerCopy(entry: entry, color: color)),
                const SizedBox(width: 12),
                _WinnerScore(score: entry.score, unit: meta.unit, color: color),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        color: color,
                        fontFamily: Cyber.displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MovementBadge(
                      movement: entry.movement,
                      isNew: entry.isNew,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    RivalAvatar(
                      name: entry.name,
                      size: avatarSize,
                      ring: color,
                      team: entry.team,
                      frameColors: userFrameColors,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: Cyber.bodyFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedScoreText(
                            key: ValueKey(
                              'winner-${entry.rank}-${entry.score}-${meta.unit}',
                            ),
                            value: entry.score,
                            suffix: ' ${meta.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontFamily: Cyber.displayFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: tile,
    );
  }
}

class _WinnerCopy extends StatelessWidget {
  const _WinnerCopy({required this.entry, required this.color});

  final LeaderboardEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#${entry.rank}',
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.workspace_premium, color: Cyber.gold, size: 18),
            const SizedBox(width: 8),
            MovementBadge(movement: entry.movement, isNew: entry.isNew),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: Cyber.bodyFont,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        if (entry.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            entry.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.9),
          ),
        ],
        if (entry.badge != null) ...[
          const SizedBox(height: 8),
          RankTag(label: entry.badge!, color: color),
        ],
      ],
    );
  }
}

class _WinnerScore extends StatelessWidget {
  const _WinnerScore({
    required this.score,
    required this.unit,
    required this.color,
  });

  final int score;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 98),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedScoreText(
              key: ValueKey('podium-$score-$unit'),
              value: score,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontFamily: Cyber.displayFont,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontFamily: Cyber.displayFont,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flat row ────────────────────────────────────────────────────────────────

/// A board row below the podium. The user's own row is the only one that gets
/// an accent fill + border; everyone else is a calm panel plate.
class RankRow extends StatelessWidget {
  const RankRow({
    required this.entry,
    required this.accent,
    required this.meta,
    this.onTap,
    super.key,
  });

  final LeaderboardEntry entry;
  final Color accent;
  final ScoreMeta meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.isUser;
    final rankColor = entry.rank <= 3 ? Cyber.gold : Cyber.muted;
    // Reflect the user's equipped avatar frame on their own row.
    final userFrameColors = _userFrameColors(context, entry);
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: cutCornerDecoration(
        color: isUser
            ? accent.withValues(alpha: 0.1)
            : Cyber.panel.withValues(alpha: 0.34),
        borderColor: isUser
            ? accent.withValues(alpha: 0.5)
            : Colors.transparent,
        cut: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#${entry.rank}',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: rankColor,
                fontFamily: Cyber.displayFont,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          RivalAvatar(
            name: entry.name,
            size: 48,
            highlight: isUser,
            team: entry.team,
            frameColors: userFrameColors,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: Cyber.bodyFont,
                          fontSize: 15,
                          fontWeight: isUser
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 7),
                      const RankTag(label: 'YOU', color: Cyber.cyan),
                    ] else if (entry.badge != null) ...[
                      const SizedBox(width: 7),
                      RankTag(label: entry.badge!, color: Cyber.violet),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    MovementBadge(movement: entry.movement, isNew: entry.isNew),
                    if (entry.subtitle != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          entry.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            9,
                            color: Cyber.muted,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 86),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedScoreText(
                    key: ValueKey(
                      'row-${entry.rank}-${entry.score}-${meta.unit}',
                    ),
                    value: entry.score,
                    maxLines: 1,
                    style: TextStyle(
                      color: accent,
                      fontFamily: Cyber.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  meta.unit,
                  style: TextStyle(
                    color: Cyber.muted.withValues(alpha: 0.82),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

// ─── Pinned user rank bar ────────────────────────────────────────────────────

/// The docked "where you stand" card. [rankText] overrides the numeral so a
/// board can show `UNRANKED` / `#--` before results land; [showScore] hides the
/// score column in those same states.
class RankUserBar extends StatelessWidget {
  const RankUserBar({
    required this.user,
    required this.meta,
    required this.accent,
    this.label = 'Your rank',
    this.rankText,
    this.showScore = true,
    this.onTap,
    this.ctaLabel,
    super.key,
  });

  final LeaderboardEntry user;
  final ScoreMeta meta;
  final Color accent;
  final String label;
  final String? rankText;
  final bool showScore;
  final VoidCallback? onTap;
  final String? ctaLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: cutCornerDecoration(
        color: accent.withValues(alpha: 0.1),
        borderColor: accent.withValues(alpha: 0.34),
        cut: 18,
      ),
      child: Row(
        children: [
          RivalAvatar(
            name: user.name,
            size: 54,
            highlight: true,
            team: user.team,
            frameColors: _userFrameColors(context, user),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.85),
                        fontFamily: Cyber.displayFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MovementBadge(movement: user.movement, isNew: user.isNew),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      rankText ?? '#${user.rank}',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: Cyber.displayFont,
                        fontSize: rankText == null ? 28 : 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: Cyber.bodyFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (user.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
                  ),
                ],
              ],
            ),
          ),
          if (showScore)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedScoreText(
                  key: ValueKey('user-${meta.unit}-${user.score}'),
                  value: user.score,
                  style: TextStyle(
                    color: accent,
                    fontFamily: Cyber.displayFont,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  meta.unit.toLowerCase(),
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.7),
                    fontFamily: Cyber.displayFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            )
          else if (ctaLabel != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ctaLabel!,
                  style: Cyber.label(10, color: accent, letterSpacing: 1.2),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: accent, size: 20),
              ],
            ),
        ],
      ),
    );

    final framed = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Cyber.bg,
        border: Border(
          top: BorderSide(color: Cyber.line.withValues(alpha: 0.32)),
        ),
      ),
      child: card,
    );
    if (onTap == null) return framed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: framed,
    );
  }
}

// ─── Small parts ─────────────────────────────────────────────────────────────

/// A score that counts up to its value the first time it lands.
class AnimatedScoreText extends StatelessWidget {
  const AnimatedScoreText({
    required this.value,
    required this.style,
    this.suffix = '',
    this.maxLines,
    this.overflow,
    super.key,
  });

  final int value;
  final TextStyle style;
  final String suffix;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
      return _buildText(value);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => _buildText(current.round()),
    );
  }

  Widget _buildText(int current) {
    return Text(
      '${formatRankInt(current)}$suffix',
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
  }
}

/// A tiny chamfered label pill — YOU / PRO / a team's short name.
class RankTag extends StatelessWidget {
  const RankTag({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: cutCornerDecoration(
        color: color.withValues(alpha: 0.16),
        borderColor: color.withValues(alpha: 0.7),
        cut: 4,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: Cyber.displayFont,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// ▲/▼ rank delta, or NEW for a first-time entrant.
class MovementBadge extends StatelessWidget {
  const MovementBadge({
    required this.movement,
    required this.isNew,
    super.key,
  });

  final int movement;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    if (isNew) {
      return _pill('NEW', Cyber.gold);
    }
    if (movement > 0) {
      return _pill('▲$movement', Cyber.success);
    }
    if (movement < 0) {
      return _pill('▼${-movement}', Cyber.danger);
    }
    return Text(
      '—',
      style: TextStyle(
        color: Cyber.muted,
        fontFamily: Cyber.displayFont,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontFamily: Cyber.displayFont,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The amber "time left" pill. Takes a pre-formatted [remaining] so a caller
/// can drive it from a real clock (see [formatBoardCountdown]) or a fixture.
class CountdownPill extends StatelessWidget {
  const CountdownPill({
    required this.remaining,
    this.label,
    this.accent = Cyber.amber,
    super.key,
  });

  final String remaining;
  final String? label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: cutCornerDecoration(
        color: accent.withValues(alpha: 0.14),
        borderColor: accent.withValues(alpha: 0.55),
        cut: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: accent, size: 13),
          const SizedBox(width: 5),
          Text(
            label == null ? remaining : '$label $remaining',
            style: TextStyle(
              color: accent,
              fontFamily: Cyber.displayFont,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
