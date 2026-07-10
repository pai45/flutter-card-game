import 'package:flutter/material.dart';

import '../data/followable_leagues.dart';

/// A purchasable avatar frame ring, mapped 1:1 to a real team. The ring uses
/// the team's [primary] colour; the multi-colour band and the raised inner edge
/// are derived from it (see [frameRingColors] / [frameRaisedEdge]). Equip one
/// to wrap your profile avatar (and the leaderboard "you" row).
class AvatarFrameOption {
  const AvatarFrameOption({
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

  /// Sport chips this frame shows under (e.g. {FIFA}, {FIFA, UCL}, {IPL}).
  final Set<String> sports;

  /// The team's primary colour — drives the whole ring.
  final Color primary;
  final int coinPrice;
}

const int _framePrice = 150;

const Map<String, Set<String>> _leagueSports = {
  'epl': {'FOOTBALL'},
  'laliga': {'FOOTBALL'},
  'seriea': {'FOOTBALL'},
  'bundesliga': {'FOOTBALL'},
  'ipl': {'CRICKET'},
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
  if (_uclTeams.contains(teamId)) base.add('FOOTBALL');
  return base;
}

/// Every frame, seeded from the real teams in [followableLeagues].
final List<AvatarFrameOption> avatarFrameOptions = [
  for (final entry in followableLeagues)
    for (final team in entry.teams)
      AvatarFrameOption(
        id: 'frame_${team.id}',
        teamId: team.id,
        label: team.name,
        leagueId: entry.league.id,
        sports: _sportsFor(entry.league.id, team.id),
        primary: team.color,
        coinPrice: _framePrice,
      ),
];

/// Normalises a stored frame id, mapping the legacy `border_*` form to `frame_*`
/// so pre-rename owned/equipped ids keep resolving.
String normalizeFrameId(String id) =>
    id.startsWith('border_') ? id.replaceFirst('border_', 'frame_') : id;

/// The frame with [id], or null for "none"/unknown (empty equipped slot).
AvatarFrameOption? avatarFrameOptionById(String? id) {
  if (id == null || id.isEmpty) return null;
  final normalized = normalizeFrameId(id);
  for (final option in avatarFrameOptions) {
    if (option.id == normalized) return option;
  }
  return null;
}

/// The 3-stop gradient band painted as the 4px ring, derived from [primary].
List<Color> frameRingColors(Color primary) => [
  Color.lerp(primary, Colors.white, 0.45)!,
  primary,
  Color.lerp(primary, Colors.black, 0.35)!,
];

/// The lightened primary used for the 2px raised inner bevel (the "elevated" edge).
Color frameRaisedEdge(Color primary) =>
    Color.lerp(primary, Colors.white, 0.25)!;
