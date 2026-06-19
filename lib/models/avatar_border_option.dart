import 'package:flutter/material.dart';

import '../data/followable_leagues.dart';

/// A purchasable avatar border ring, mapped 1:1 to a real team. The ring uses
/// the team's [primary] colour; the multi-colour band and the raised inner edge
/// are derived from it (see [borderRingColors] / [borderRaisedEdge]). Equip one
/// to wrap your profile avatar (and the leaderboard "you" row).
class AvatarBorderOption {
  const AvatarBorderOption({
    required this.id,
    required this.teamId,
    required this.label,
    required this.leagueId,
    required this.sports,
    required this.primary,
    required this.coinPrice,
  });

  final String id;
  final String teamId;
  final String label;
  final String leagueId;

  /// Sport chips this border shows under (e.g. {FIFA}, {FIFA, UCL}, {IPL}).
  final Set<String> sports;

  /// The team's primary colour — drives the whole ring.
  final Color primary;
  final int coinPrice;
}

const int _borderPrice = 150;

// Football leagues all sit under the broad FIFA chip; cricket under IPL.
const Map<String, Set<String>> _leagueSports = {
  'epl': {'FIFA'},
  'laliga': {'FIFA'},
  'seriea': {'FIFA'},
  'bundesliga': {'FIFA'},
  'ipl': {'IPL'},
};

// Elite clubs that also surface under the UCL chip.
const Set<String> _uclTeams = {
  'liv',
  'mc',
  'ars',
  'rma',
  'fcb',
  'atm',
  'juv',
  'int',
  'mil',
  'bay',
  'bvb',
};

Set<String> _sportsFor(String leagueId, String teamId) {
  final base = {...?_leagueSports[leagueId]};
  if (_uclTeams.contains(teamId)) base.add('UCL');
  return base;
}

/// Every border, seeded from the real teams in [followableLeagues].
final List<AvatarBorderOption> avatarBorderOptions = [
  for (final entry in followableLeagues)
    for (final team in entry.teams)
      AvatarBorderOption(
        id: 'border_${team.id}',
        teamId: team.id,
        label: team.name,
        leagueId: entry.league.id,
        sports: _sportsFor(entry.league.id, team.id),
        primary: team.color,
        coinPrice: _borderPrice,
      ),
];

/// The border with [id], or null for "none"/unknown (empty equipped slot).
AvatarBorderOption? avatarBorderOptionById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final option in avatarBorderOptions) {
    if (option.id == id) return option;
  }
  return null;
}

/// The 3-stop gradient band painted as the 4px ring, derived from [primary].
List<Color> borderRingColors(Color primary) => [
  Color.lerp(primary, Colors.white, 0.45)!,
  primary,
  Color.lerp(primary, Colors.black, 0.35)!,
];

/// The lightened primary used for the 2px raised inner bevel (the "elevated" edge).
Color borderRaisedEdge(Color primary) =>
    Color.lerp(primary, Colors.white, 0.25)!;
