import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/cards.dart';
import '../models/sport_match.dart';
import '../widgets/team_logo.dart';

/// Resolves a lineup player to a bundled portrait, if we happen to ship one.
///
/// The portrait library is the card game's roster, not these clubs' squads, so
/// coverage of any given fixture is thin — the bundled Fulham v Chelsea match
/// hits 2 of 40. Callers must treat null as the normal case.
///
/// `playerPortraitAssets` is keyed on the uppercase short name (`'A. ROBINSON'`)
/// and the feed's short name is mixed case (`'A. Robinson'`), so uppercasing is
/// the whole mapping.
String? footballPortraitAssetFor(MatchPlayer player) {
  final short = player.shortName;
  if (short != null) {
    final hit = playerPortraitAssets[short.toUpperCase()];
    if (hit != null) return hit;
  }
  return playerPortraitAssets[player.name.toUpperCase()];
}

/// ESPN's rendered kit image for a player in a specific match.
///
/// Soccer athletes have **no headshot** on ESPN — every
/// `a.espncdn.com/i/headshots/soccer/...` URL 404s — but the summary feed does
/// expose a per-event jersey render for every player, which is the only image
/// the API will actually give us. It is a 1440px PNG, so always decode it
/// downscaled.
String? espnSoccerJerseyUrl({
  required String? leagueSlug,
  required String? eventId,
  required String athleteId,
  bool dark = true,
}) {
  if (leagueSlug == null || eventId == null || athleteId.isEmpty) return null;
  return 'https://stitcher.espn.com/sports/soccer/leagues/$leagueSlug'
      '/events/$eventId/athletes/$athleteId/jersey.png?darkMode=$dark';
}

/// A player's picture on the match card, degrading in three steps.
///
/// 1. a bundled portrait, when we ship one for this player,
/// 2. ESPN's kit render, decoded at [size] rather than its native 1440px, and
/// 3. the shirt-number octagon — the same badge the pitch draws, so the card
///    and the formation board speak the same language.
///
/// Step 2 needs the network, which web builds cannot reach for ESPN, so the
/// fallback is the common path rather than an error state and is styled as a
/// real option instead of a grey box.
class FootballPlayerPortrait extends StatelessWidget {
  const FootballPlayerPortrait({
    required this.player,
    required this.accent,
    required this.size,
    this.eventId,
    this.leagueSlug,
    super.key,
  });

  final MatchPlayer player;
  final Color accent;
  final double size;
  final String? eventId;
  final String? leagueSlug;

  @override
  Widget build(BuildContext context) {
    final portrait = footballPortraitAssetFor(player);
    final jersey = portrait == null
        ? espnSoccerJerseyUrl(
            leagueSlug: leagueSlug,
            eventId: eventId,
            athleteId: player.id,
          )
        : null;

    Widget? image;
    if (portrait != null) {
      image = Image.asset(
        portrait,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (jersey != null) {
      image = Image.network(
        jersey,
        fit: BoxFit.contain,
        // Never decode the native 1440px render; a squad of 40 would be a
        // memory trap.
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
        // Fade in over the badge rather than swapping for it, so the octagon
        // is never momentarily empty while a 240 KB kit downloads.
        frameBuilder: (context, child, frame, wasSynchronous) =>
            wasSynchronous || frame != null
            ? (wasSynchronous
                  ? child
                  : AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 220),
                      child: child,
                    ))
            : const SizedBox.shrink(),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        foregroundPainter: OctagonBorderPainter(
          color: accent.withValues(alpha: 0.78),
          strokeWidth: 1.5,
        ),
        child: ClipPath(
          clipper: const OctagonClipper(),
          child: ColoredBox(
            color: Cyber.card,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Always behind: the shirt number is the fallback AND the
                // placeholder, so a slow, missing or failed kit never leaves a
                // blank plate.
                _NumberBadge(player: player, accent: accent),
                if (image != null) Positioned.fill(child: image),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.player, required this.accent});

  final MatchPlayer player;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${player.number}',
            style: Cyber.display(
              22,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
  }
}
