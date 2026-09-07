import '../models/cricket_match_data.dart';

/// Maps one entry of an ESPN cricket `summary.rosters[]` to a squad, including
/// the per-player match stat sheet the summary already carries.
///
/// Extracted out of `EspnScoreService` so it can be tested against a captured
/// fixture: the service is ~1,800 lines and unreachable without the network.
///
/// Cricket nests its stats far deeper than soccer. Where a soccer roster entry
/// has a flat `stats` array, a cricket one has `linescores` (one block per
/// innings), each with its own `linescores`, each with
/// `statistics.categories[].stats[]`. A player who batted in one innings and
/// bowled in another contributes to both blocks, so they are folded into a
/// single sheet of 46 values.
///
/// Ball-by-ball is deliberately NOT here: it lives in a separate play-by-play
/// request, so [CricketPlayerMatchStats.hasBallByBall] is false on this path
/// and the card shows its "no ball-by-ball" state while the stat sheet, the
/// identity plate and the match sheet all still render.
CricketTeamSquad parseCricketRosterSquad(Map<String, dynamic> roster) {
  final team = roster['team'];
  final players = <CricketSquadPlayer>[];

  for (final entry in (roster['roster'] as List? ?? const [])) {
    if (entry is! Map) continue;
    final athlete = entry['athlete'];
    if (athlete is! Map) continue;
    players.add(_parsePlayer(entry, athlete));
  }

  return CricketTeamSquad(
    id: (team is Map ? team['id'] : null)?.toString() ?? '',
    name: (team is Map ? team['displayName'] : null)?.toString() ?? '',
    abbreviation: (team is Map ? team['abbreviation'] : null)?.toString() ?? '',
    isHome: roster['homeAway']?.toString() == 'home',
    captain: players
        .where((p) => p.captain)
        .map((p) => p.name)
        .firstWhere((_) => true, orElse: () => ''),
    keeper: players
        .where((p) => p.keeper)
        .map((p) => p.name)
        .firstWhere((_) => true, orElse: () => ''),
    squadPublished: players.isNotEmpty,
    playerCount: players.length,
    players: players,
  );
}

CricketSquadPlayer _parsePlayer(
  Map<Object?, Object?> entry,
  Map<Object?, Object?> athlete,
) {
  final values = _foldStats(entry);
  final position = entry['position'];
  return CricketSquadPlayer(
    id: athlete['id']?.toString() ?? '',
    name: athlete['displayName']?.toString() ?? 'Unknown',
    fullName: athlete['fullName']?.toString() ?? '',
    battingName: athlete['battingName']?.toString() ?? '',
    role: (position is Map ? position['name'] : null)?.toString() ?? '',
    // ESPN flags the keeper through the position, not a boolean.
    keeper:
        (position is Map ? position['abbreviation'] : null)?.toString() == 'WK',
    captain: entry['captain'] == true,
    starter: entry['starter'] == true,
    subbedIn: entry['subbedIn'] == true,
    subbedOut: entry['subbedOut'] == true,
    active: entry['active'] == true,
    battingStyle: _style(athlete, 'batting'),
    bowlingStyle: _style(athlete, 'bowling'),
    performances: const [],
    matchStats: values.isEmpty
        ? null
        : CricketPlayerMatchStats(values: values),
  );
}

/// Folds every innings block into one sheet.
///
/// Blocks are disjoint — a player bats in one innings and bowls in another —
/// so the larger magnitude wins rather than a sum, which would double-count the
/// zero-filled block ESPN sends for the discipline they did not play.
Map<String, num> _foldStats(Map<Object?, Object?> entry) {
  final values = <String, num>{};
  for (final outer in (entry['linescores'] as List? ?? const [])) {
    if (outer is! Map) continue;
    for (final inner in (outer['linescores'] as List? ?? const [])) {
      if (inner is! Map) continue;
      final categories = (inner['statistics'] as Map?)?['categories'] as List?;
      for (final category in categories ?? const []) {
        if (category is! Map) continue;
        for (final stat in (category['stats'] as List? ?? const [])) {
          if (stat is! Map) continue;
          final name = stat['name']?.toString();
          final value = stat['value'];
          if (name == null || value is! num) continue;
          final existing = values[name];
          if (existing == null || value.abs() > existing.abs()) {
            values[name] = value;
          }
        }
      }
    }
  }
  return values;
}

/// "Left-hand bat" / "Right-arm medium" out of `athlete.style[]`.
String _style(Map<Object?, Object?> athlete, String type) {
  for (final style in (athlete['style'] as List? ?? const [])) {
    if (style is! Map) continue;
    if (style['type']?.toString() != type) continue;
    return style['description']?.toString() ?? '';
  }
  return '';
}
