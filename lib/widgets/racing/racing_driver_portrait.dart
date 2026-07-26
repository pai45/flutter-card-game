import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/racing_portraits.dart';
import '../../data/team_palettes.dart';
import '../../models/cards.dart';
import '../../models/racing.dart';
import '../../models/sport_match.dart';
import '../cyber/cyber_widgets.dart';

/// Portrait for motorsport driver cards — real art when shipped, team-colored
/// initials fallback otherwise.
class RacingDriverPortrait extends StatelessWidget {
  const RacingDriverPortrait({
    required this.card,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final PlayerCard card;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final driver = racingDriverById(card.id);
    final asset = card.portraitAsset ?? racingPortraitAsset(driver.id);
    final hasArt = racingPortraitHasArt(driver.id);

    if (hasArt) {
      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => _RacingPortraitFallback(
          driver: driver,
          card: card,
        ),
      );
    }

    return _RacingPortraitFallback(driver: driver, card: card);
  }
}

class _RacingPortraitFallback extends StatelessWidget {
  const _RacingPortraitFallback({required this.driver, required this.card});

  final RacingDriver driver;
  final PlayerCard card;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForDriver(driver);
    final seriesLabel = _seriesLabel(driver.series);
    final initials = _initials(driver.name);
    const clipper = HudChamferClipper(bigCut: 10, smallCut: 3);

    return ChamferedActionSurface(
      clipper: clipper,
      borderColor: palette.secondary.withValues(alpha: 0.85),
      borderWidth: 1.2,
      child: ColoredBox(
        color: palette.primary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -12,
              top: -18,
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  width: 80,
                  height: 120,
                  color: palette.secondary.withValues(alpha: 0.28),
                ),
              ),
            ),
            Center(
              child: Text(
                initials,
                style: Cyber.display(
                  28,
                  color: palette.text,
                  letterSpacing: 2,
                ),
              ),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  seriesLabel,
                  style: Cyber.label(
                    7,
                    color: palette.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                card.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Cyber.label(
                  7,
                  color: palette.text.withValues(alpha: 0.92),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TeamPalette _paletteForDriver(RacingDriver driver) {
    final team = SportTeam(
      id: driver.id,
      name: driver.team,
      shortName: driver.countryCode,
      color: Cyber.magenta,
    );
    final palette = paletteForTeam(team, sport: Sport.motorsport);
    if (palette.primary != derivePalette(Cyber.magenta).primary) {
      return palette;
    }
    return switch (driver.series) {
      RacingSeries.f2 => const TeamPalette(
        Color(0xff1a1f2e),
        Color(0xffffffff),
        Color(0xff5cdfff),
      ),
      RacingSeries.nascar => kTeamPalettes['motorsport:nascarcupfield']!,
      RacingSeries.indycar => kTeamPalettes['motorsport:indycarfield']!,
      RacingSeries.f1 => derivePalette(Cyber.magenta),
    };
  }

  String _seriesLabel(RacingSeries series) => switch (series) {
    RacingSeries.f1 => 'F1',
    RacingSeries.f2 => 'F2',
    RacingSeries.nascar => 'NASCAR',
    RacingSeries.indycar => 'INDY',
  };

  String _initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

bool isRacingPlayerCard(PlayerCard card) =>
    card.icon == Icons.sports_motorsports;
