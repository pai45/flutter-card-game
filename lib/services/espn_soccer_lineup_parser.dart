import '../models/football_match_data.dart';
import '../models/sport_match.dart';

/// Maps one entry of an ESPN soccer `summary.rosters[]` to a [MatchLineup].
///
/// Extracted out of `EspnScoreService` so it can be tested against a captured
/// fixture: the service itself is ~1,800 lines and unreachable without the
/// network, and this parse has real logic in it now.
///
/// The summary already carries a complete 14-stat match sheet per player. It
/// costs nothing extra to read — it arrives in the same response the lineup
/// does — so every live football fixture gets a player card, not just the
/// bundled one. Positional tracking is NOT here: those coordinates live in a
/// separate ~1.5 MB plays feed that is not worth fetching per fixture, so
/// [FootballPlayerMatchStats.hasTracking] is false on this path and the card
/// shows its "no tracked touches" state.
MatchLineup parseSoccerRosterLineup(
  Map<String, dynamic> roster, {
  required bool isHomeTeam,
}) {
  final entries = roster['roster'] as List? ?? const [];
  final players = <MatchPlayer>[];
  final bench = <MatchPlayer>[];

  for (final entry in entries) {
    if (entry is! Map) continue;
    final athlete = entry['athlete'];
    if (athlete == null) continue;
    final player = _parsePlayer(entry, athlete);
    if (entry['starter'] == true) {
      players.add(player);
    } else {
      bench.add(player);
    }
  }

  return MatchLineup(
    formation: roster['formation']?.toString() ?? '4-3-3',
    startingXI: players,
    substitutes: bench,
    confirmed: players.isNotEmpty,
    source: 'roster',
    reportedPlayerCount: players.length + bench.length,
  );
}

MatchPlayer _parsePlayer(Map<Object?, Object?> entry, dynamic athlete) {
  // `formationPlace` is what the pitch board sorts by. Dropping it — as this
  // parser used to — left every live lineup laid out in arbitrary roster order.
  final formationPlace = entry['formationPlace']?.toString();
  return MatchPlayer(
    id: athlete['id']?.toString() ?? '',
    name: _athleteName(athlete),
    shortName: athlete['shortName']?.toString(),
    number: int.tryParse(entry['jersey']?.toString() ?? '') ?? 0,
    role: (entry['position'] as Map?)?['name']?.toString(),
    formationPlace: formationPlace == '0' ? null : formationPlace,
    source: 'roster',
    matchStats: _parseStats(entry),
  );
}

FootballPlayerMatchStats? _parseStats(Map<Object?, Object?> entry) {
  final raw = entry['stats'];
  if (raw is! List || raw.isEmpty) return null;
  final values = <String, num>{};
  for (final stat in raw) {
    if (stat is! Map) continue;
    final name = stat['name']?.toString();
    final value = stat['value'];
    if (name != null && value is num) values[name] = value;
  }
  if (values.isEmpty) return null;
  return FootballPlayerMatchStats(
    values: values,
    starter: entry['starter'] == true,
  );
}

/// Prefers the full name here, unlike the scoreboard's own helper: the match
/// card has room for it and `shortName` is kept separately.
String _athleteName(dynamic athlete) {
  for (final key in ['displayName', 'fullName', 'shortName']) {
    final value = athlete[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return 'Unknown';
}

/// ESPN competition slug for a football fixture's league id.
///
/// The summary feed used to be requested as `soccer/fifa.world` for every
/// football fixture regardless of competition, which is simply the wrong
/// league for a domestic match. The same competition reaches us under several
/// ids (see the league-hub alias note), so this resolves by alias and keeps
/// `fifa.world` only as the last resort.
String soccerSummarySlug(String? leagueId) {
  final key = leagueId?.toLowerCase().replaceAll(RegExp('[^a-z0-9.]'), '');
  return switch (key) {
    'eng.1' || 'epl' || '700' || '23' => 'eng.1',
    'esp.1' || 'laliga' || 'lal' || '740' || '15' => 'esp.1',
    'usa.1' || 'mls' => 'usa.1',
    'uefa.euro' => 'uefa.euro',
    _ => key == null || key.isEmpty ? 'fifa.world' : key,
  };
}
