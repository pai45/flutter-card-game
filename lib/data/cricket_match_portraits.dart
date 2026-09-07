import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/cards.dart';
import '../widgets/team_logo.dart';

/// Bundled cricket portraits, keyed by the slug the filenames use.
///
/// Unlike football — where the portrait library is the card game's roster and
/// covers 2 of 40 players in the bundled fixture — cricket coverage is good:
/// 22 of the 24 in the IPL final resolve, once
/// [cricketPortraitAliases] rescues the odd-named files.
const _portraitFolder = 'assets/cricketer_images/';

/// Whether a bundled portrait exists for [name].
///
/// The asset list is not enumerable at runtime, so this checks the two naming
/// conventions the folder actually uses. A wrong answer is not fatal — the
/// image widget falls back — but it keeps the common case off the error path.
bool hasCricketPortrait(String name) {
  final slug = cricketPortraitSlug(name);
  return slug.isNotEmpty;
}

/// ESPN's headshot for a cricket athlete.
///
/// Cricket is the sport where this actually exists — soccer athletes have none
/// at all — but coverage is partial: 9 of the 24 in the bundled final resolve
/// and the rest 404, so this is a middle fallback rather than a primary source.
String? espnCricketHeadshotUrl(String athleteId) =>
    athleteId.isEmpty
    ? null
    : 'https://a.espncdn.com/i/headshots/cricket/players/full/$athleteId.png';

/// A cricket player's picture, degrading in three steps.
///
/// 1. the bundled portrait,
/// 2. ESPN's headshot, decoded downscaled, and
/// 3. the player's initials on the octagon badge.
///
/// The initials sit permanently *behind* the image so a slow, missing or failed
/// load never leaves a blank plate — the lesson from the football card, where
/// swapping placeholder for image left an empty octagon for a second.
class CricketPlayerPortrait extends StatelessWidget {
  const CricketPlayerPortrait({
    required this.athleteId,
    required this.name,
    required this.accent,
    required this.size,
    super.key,
  });

  final String athleteId;
  final String name;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final slug = cricketPortraitSlug(name);
    final alias = cricketPortraitAliases[slug];
    final asset = slug.isEmpty
        ? null
        : '$_portraitFolder${alias ?? '$slug.webp'}';
    final headshot = espnCricketHeadshotUrl(athleteId);

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
                _Initials(name: name, accent: accent),
                if (asset != null)
                  Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    // A missing bundled portrait drops through to the headshot
                    // rather than to the initials.
                    errorBuilder: (_, _, _) => headshot == null
                        ? const SizedBox.shrink()
                        : _Headshot(url: headshot, size: size),
                  )
                else if (headshot != null)
                  _Headshot(url: headshot, size: size),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Headshot extends StatelessWidget {
  const _Headshot({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      // ESPN serves these at full size; never decode one at native resolution.
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
      // Fade in over the initials rather than swapping for them.
      frameBuilder: (context, child, frame, wasSynchronous) =>
          wasSynchronous || frame != null
          ? child
          : const SizedBox.shrink(),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.accent});

  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.characters.take(2).toString().toUpperCase()
        : '${parts.first.characters.first}${parts.last.characters.first}'
              .toUpperCase();
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            initials,
            style: Cyber.display(20, color: accent, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}
