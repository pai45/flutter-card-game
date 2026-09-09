// Generates the bundled NBA league package consumed by the league hub.
//
//   dart run tool/generate_nba_league_stats.dart [options]
//
//     --season 2026     ESPN season year (2026 == the 2025-26 campaign)
//     --out <path>      Override the output path
//     --delay 0         Milliseconds between requests
//     --check           Re-extract and diff against the committed asset
//
// WHY THIS ONE IS THE EASY SPORT.
//
// Cricket needed 140 requests because ESPN's core API rejects the sport, so
// every leader and team total had to be re-derived from match summaries
// (see generate_cricket_league_stats.dart). **Basketball has no such problem.**
// All three league-level feeds football uses exist and answer:
//
//   site.web.api.espn.com/apis/v2/sports/basketball/nba/standings   200
//   sports.core.api.../basketball/leagues/nba/seasons/N/types/2/leaders   200
//   sports.core.api.../.../types/2/teams/{id}/statistics                  200
//
// So this generator is a straight extraction: standings, the season leader
// boards, and 109 season stats for each of the 30 clubs. About 60 requests.
//
// THE SEASON TRAP. Calling standings without `?season=` returns a payload whose
// `season` block says **2026-27** while the entries it carries are the
// completed **2025-26** table. Reading the label would ship a season-off-by-one
// asset. The newest year in the payload's own `seasons` list is the truth, and
// the run refuses any season whose standings come back empty.

import 'dart:convert';
import 'dart:io';

import 'espn_feed_client.dart';

const _defaultOut = 'assets/data/nba-league-stats.json';

/// The NBA's own core-API slug, and ESPN's numeric id for the competition.
const _slug = 'nba';
const _espnLeagueId = '46';

const _teamCount = 30;
const _conferenceCount = 2;
const _leadersPerBoard = 10;

/// How many names to pull off each raw board before qualifying them. ESPN
/// ships 25; taking all of them leaves enough to backfill a board after the
/// low-minutes players are cut.
const _candidatesPerBoard = 25;

/// The NBA's own minimum for a per-game leaderboard: 58 games, 70% of 82.
const _minGames = 58;

/// Every id and label a consumer might look the NBA up by. The hub resolves by
/// alias because the same competition arrives under the repository id, the
/// follow-list id and ESPN's own numeric id.
///
/// Deliberately NOT 'basketball': that is the sport, not the competition, and
/// it would hand the WNBA — or any other basketball league — the NBA's table.
const _aliases = <String>[
  'nba',
  'NBA',
  _espnLeagueId,
  'National Basketball Association',
  'nationalbasketballassociation',
];

/// The leader boards the hub shows, in display order: scoring first, then the
/// other counting stats, then efficiency, then the discipline-style board.
///
/// ESPN publishes 16 categories. The six left out are either duplicates of a
/// board already here (`points` duplicates `pointsPerGame`'s ranking almost
/// exactly), or opaque composites nobody reads a leaderboard for (`NBARating`),
/// or not an achievement at all (`minutesPerGame`, `foulsPerGame`).
const _boardSpecs = <_BoardSpec>[
  _BoardSpec(_perGame, 'POINTS PER GAME', key: 'pointsPerGame'),
  _BoardSpec(_perGame, 'REBOUNDS PER GAME', key: 'reboundsPerGame'),
  _BoardSpec(_perGame, 'ASSISTS PER GAME', key: 'assistsPerGame'),
  _BoardSpec(_perGame, 'THREES MADE PER GAME', key: '3PointsMadePerGame'),
  _BoardSpec(_perGame, 'STEALS PER GAME', key: 'stealsPerGame'),
  _BoardSpec(_perGame, 'BLOCKS PER GAME', key: 'blocksPerGame'),
  // A count, not a rate: nobody racks up 56 double-doubles off a small sample,
  // so this board needs no cut.
  _BoardSpec.counting('doubleDouble', 'DOUBLE-DOUBLES'),
  _BoardSpec(_perGame, 'PLAYER EFFICIENCY RATING', key: 'PER'),
  // The shooting boards use the league's own award minimums rather than a
  // games cut, because that is how a shooting title is actually decided.
  _BoardSpec(
    _madeFieldGoals,
    'FIELD GOAL %',
    key: 'fieldGoalPercentage',
  ),
  // ESPN ships this one as a 0-1 fraction while the other two percentage
  // boards in the SAME response are already 0-100. Scaled here so every
  // percentage board reads the same way.
  _BoardSpec(_madeThrees, 'THREE-POINT %', key: '3PointPct', scale: 100),
  _BoardSpec(_madeFreeThrows, 'FREE THROW %', key: 'FreeThrowPct'),
  // Ranked most-first, like football's cards boards: this is a "who gives it
  // away most" board, and its accent says so rather than its ordering.
  _BoardSpec(_perGame, 'TURNOVERS PER GAME', key: 'avgTurnovers'),
];

/// The NBA's published minimums for a qualifying leaderboard.
const _perGame = _Qualifier('gamesPlayed', _minGames, '58+ GAMES');
const _madeFieldGoals = _Qualifier('fieldGoalsMade', 300, '300+ MADE');
const _madeThrees = _Qualifier('threePointFieldGoalsMade', 82, '82+ MADE');
const _madeFreeThrows = _Qualifier('freeThrowsMade', 125, '125+ MADE');

class _Qualifier {
  const _Qualifier(this.stat, this.minimum, this.label);

  final String stat;
  final num minimum;
  final String label;
}

class _BoardSpec {
  const _BoardSpec(this.qualifier, this.unit, {required this.key, this.scale = 1});

  /// A counting board, where a short sample cannot flatter anyone.
  const _BoardSpec.counting(this.key, this.unit)
    : qualifier = null,
      scale = 1;

  final String key;

  /// Headline noun for the board's hero card.
  final String unit;

  /// Multiplier applied to ESPN's raw value — see the `3PointPct` note above.
  final num scale;

  /// The minimum a player must clear to appear on this board, or null where
  /// the board needs none.
  final _Qualifier? qualifier;

  bool qualifies(Map<String, num>? season) {
    final cut = qualifier;
    if (cut == null) return true;
    final value = season?[cut.stat];
    return value != null && value >= cut.minimum;
  }
}

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final out = espnOptionValue(args, '--out') ?? _defaultOut;
  final seasonArg = espnIntOption(args, '--season');
  final delayMs = espnIntOption(args, '--delay') ?? 0;

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    exitCode = 64;
    return;
  }

  final client = EspnFeedClient();
  final delay = Duration(milliseconds: delayMs);
  try {
    stdout.writeln('NBA league package (basketball/$_slug)');

    final season = seasonArg ?? await _latestSeason(client);
    if (season == null) {
      stderr.writeln('Could not determine a season; nothing written.');
      exitCode = 70;
      return;
    }
    stdout.writeln('  season     $season');

    final standings = await _fetchStandings(client, season);
    if (standings == null) {
      stderr.writeln('Standings unavailable for $season; nothing written.');
      exitCode = 70;
      return;
    }
    stdout.writeln(
      '  standings  ${standings.teams.length} teams in '
      '${standings.conferences.length} conferences (${standings.label})',
    );

    final candidates = await _fetchLeaders(client, season);
    final candidateIds = <String>{
      for (final board in candidates)
        for (final leader in board.leaders) leader.athleteId,
    }.toList();
    stdout.writeln(
      '  leaders    ${candidates.length} boards, '
      '${candidateIds.length} candidates',
    );

    // ESPN's leader feed applies NO games or minutes cut, so a two-way player
    // with eight appearances tops PER and free-throw percentage. Qualifying
    // needs each candidate's season totals, which is the one extra sweep.
    final seasons = await _fetchAthleteSeasons(
      client,
      season,
      candidateIds,
      delay,
    );
    final boards = _qualify(candidates, seasons);
    stdout.writeln('  qualified  ${_leaderCount(boards)} board entries');

    final athleteIds = <String>{
      for (final board in boards)
        for (final leader in board.leaders) leader.athleteId,
    }.toList();
    final athletes = await _fetchAthletes(client, season, athleteIds, delay);
    stdout.writeln('  athletes   ${athletes.length}/${athleteIds.length}');

    final teamIds = standings.teams.keys.toList();
    final teamStats = <String, Map<String, num>>{};
    final definitions = <String, Map<String, Object?>>{};
    final failed = <String>[];
    await espnPool(teamIds, (teamId) async {
      final stats = await _fetchTeamStats(client, season, teamId, definitions);
      if (stats == null) {
        failed.add(teamId);
      } else {
        teamStats[teamId] = stats;
      }
      await Future<void>.delayed(delay);
    });

    // One missing club silently drops out of every ranking on the STATS tab,
    // and nothing downstream could tell a 29-team league from a 30-team one.
    if (failed.isNotEmpty) {
      stderr.writeln(
        'Failed to read season statistics for ${failed.length} of '
        '${teamIds.length} teams (${failed.join(', ')}). Re-run.',
      );
      exitCode = 75;
      return;
    }
    stdout.writeln(
      '  teamStats  ${teamStats.length} teams, '
      '${definitions.length} stat keys',
    );

    final payload = _build(
      standings: standings,
      boards: boards,
      athletes: athletes,
      teamStats: teamStats,
      definitions: definitions,
      season: season,
    );
    _verify(payload);

    final text = '${jsonEncode(payload)}\n';

    if (check) {
      const ignoring = {'generatedAt'};
      final file = File(out);
      if (!file.existsSync()) {
        stderr.writeln('Missing $out; run without --check to generate it.');
        exitCode = 1;
        return;
      }
      if (espnWithoutKeys(file.readAsStringSync(), ignoring) !=
          espnWithoutKeys(text, ignoring)) {
        stderr.writeln('$out is out of date; re-run without --check.');
        exitCode = 1;
        return;
      }
      stdout.writeln('$out is up to date.');
      return;
    }

    File(out).writeAsStringSync(text);
    stdout.writeln('Wrote $out (${(text.length / 1024).toStringAsFixed(1)} KB)');
    _report(payload);
  } finally {
    client.close();
  }
}

// -- Feeds --------------------------------------------------------------------

/// Newest season ESPN lists for the competition.
///
/// Deliberately read from the `seasons` array rather than the payload's own
/// `season` block: the unparameterised standings call labels itself with the
/// upcoming campaign while serving the completed one.
Future<int?> _latestSeason(EspnFeedClient client) async {
  final data = await client.getJson(
    'https://site.web.api.espn.com/apis/v2/sports/basketball/$_slug/standings',
  );
  final seasons = data?['seasons'];
  if (seasons is! List) return null;
  var best = 0;
  for (final entry in seasons) {
    if (entry is! Map) continue;
    final year = _asInt(entry['year']);
    if (year > best) best = year;
  }
  return best == 0 ? null : best;
}

class _Standings {
  _Standings({
    required this.conferences,
    required this.teams,
    required this.label,
  });

  /// One entry per conference, each already rank-sorted.
  final List<_Conference> conferences;
  final Map<String, Map<String, Object?>> teams;

  /// ESPN's own season wording, e.g. "2025-26".
  final String label;
}

class _Conference {
  _Conference({required this.label, required this.rows});

  final String label;
  final List<Map<String, Object?>> rows;
}

/// `level=2` is the conference view — the table an NBA fan actually reads.
/// `level=3` nests divisions inside conferences and leaves the conference
/// entries empty, which looks like a broken feed.
Future<_Standings?> _fetchStandings(EspnFeedClient client, int season) async {
  final data = await client.getJson(
    'https://site.web.api.espn.com/apis/v2/sports/basketball/$_slug/standings'
    '?level=2&season=$season',
  );
  final children = data?['children'];
  if (children is! List || children.isEmpty) return null;

  final conferences = <_Conference>[];
  final teams = <String, Map<String, Object?>>{};

  for (final child in children) {
    if (child is! Map) continue;
    final standings = child['standings'];
    if (standings is! Map) continue;
    final rows = <Map<String, Object?>>[];
    for (final entry in (standings['entries'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final team = entry['team'];
      if (team is! Map) continue;
      final id = team['id']?.toString();
      if (id == null) continue;
      teams[id] = {
        'id': id,
        'displayName': team['displayName']?.toString() ?? '',
        'abbreviation': team['abbreviation']?.toString() ?? '',
        'shortDisplayName': team['shortDisplayName']?.toString() ?? '',
        'logo': _firstLogo(team['logos']),
      };

      final row = <String, Object?>{'teamId': id};
      for (final stat in (entry['stats'] as List? ?? const [])) {
        if (stat is! Map) continue;
        final value = stat['value'];
        // The record splits are the entries with no numeric value — a bare
        // "8-2". ESPN names them for humans ("Last Ten Games", "vs. Div."), so
        // they are re-keyed by their stable `type` instead.
        if (value is! num) {
          final type = stat['type']?.toString();
          if (type != null) row['record.$type'] = stat['displayValue'];
          continue;
        }
        final name = stat['name']?.toString();
        if (name == null) continue;
        row[name] = _round(value);
        // `gamesBehind` is 0.0 for the leader and its display is "-", while
        // `streak` is a bare magnitude whose display carries the W/L letter.
        // Neither reads correctly without ESPN's own formatting.
        if (name == 'gamesBehind' || name == 'streak') {
          row['$name.display'] = stat['displayValue'];
        }
      }
      rows.add(row);
    }
    if (rows.isEmpty) continue;
    // ESPN returns the entries in no order at all, and `playoffSeed` is NOT
    // the table: on a finished season it is the FINAL, post-play-in seed, so
    // Phoenix at 45-37 sits below Portland at 42-40. A regular-season
    // conference table is ordered by win percentage, with the seed standing in
    // for the tiebreakers ESPN already applied on equal records.
    rows.sort((a, b) {
      final byRecord = _asDouble(
        b['winPercent'],
      ).compareTo(_asDouble(a['winPercent']));
      if (byRecord != 0) return byRecord;
      return _asInt(a['playoffSeed']).compareTo(_asInt(b['playoffSeed']));
    });
    for (var i = 0; i < rows.length; i++) {
      rows[i]['rank'] = i + 1;
      // The post-play-in seed has done its job as a tiebreaker; shipping it
      // would leave a second, disagreeing ordering in the asset.
      rows[i].remove('playoffSeed');
    }
    conferences.add(
      _Conference(label: child['name']?.toString() ?? '', rows: rows),
    );
  }

  if (conferences.isEmpty) return null;
  final label =
      (data?['season'] as Map?)?['displayName']?.toString() ?? '$season';
  return _Standings(
    conferences: conferences,
    teams: teams,
    // The payload's own label is the UPCOMING season on an unparameterised
    // call; with `?season=` it agrees, which is the other reason to pin it.
    label: label,
  );
}

class _Board {
  _Board({required this.spec, required this.leaders});

  final _BoardSpec spec;
  final List<_Leader> leaders;
}

class _Leader {
  _Leader({required this.athleteId, required this.teamId, required this.value});

  final String athleteId;
  final String? teamId;
  final num value;
}

/// Pulls the raw candidate lists. Qualification happens later, once every
/// candidate's season totals are known.
Future<List<_Board>> _fetchLeaders(EspnFeedClient client, int season) async {
  final data = await client.getJson(
    'https://sports.core.api.espn.com/v2/sports/basketball/leagues/$_slug'
    '/seasons/$season/types/2/leaders',
  );
  final categories = data?['categories'];
  if (categories is! List) return const [];

  final byName = <String, Map>{
    for (final category in categories)
      if (category is Map && category['name'] != null)
        category['name'].toString(): category,
  };

  final boards = <_Board>[];
  for (final spec in _boardSpecs) {
    final category = byName[spec.key];
    if (category == null) {
      stderr.writeln('  ! leader board ${spec.key} is missing from the feed');
      continue;
    }
    final leaders = <_Leader>[];
    for (final entry in (category['leaders'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final athleteId = espnIdFromRef((entry['athlete'] as Map?)?[r'$ref']);
      final value = entry['value'];
      if (athleteId == null || value is! num) continue;
      leaders.add(
        _Leader(
          athleteId: athleteId,
          teamId: espnIdFromRef((entry['team'] as Map?)?[r'$ref']),
          value: value * spec.scale,
        ),
      );
      if (leaders.length == _candidatesPerBoard) break;
    }
    if (leaders.isNotEmpty) boards.add(_Board(spec: spec, leaders: leaders));
  }
  return boards;
}

Future<Map<String, Map<String, Object?>>> _fetchAthletes(
  EspnFeedClient client,
  int season,
  List<String> ids,
  Duration delay,
) async {
  final out = <String, Map<String, Object?>>{};
  await espnPool(ids, (id) async {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/basketball/leagues/$_slug'
      '/seasons/$season/athletes/$id',
    );
    if (data == null) return;
    final name = data['displayName']?.toString();
    if (name == null || name.isEmpty) return;
    final position = (data['position'] as Map?)?['abbreviation']?.toString();
    out[id] = {
      'name': name,
      if (position != null && position.isNotEmpty) 'role': position,
      if (data['jersey'] != null) 'jersey': data['jersey'].toString(),
    };
    await Future<void>.delayed(delay);
  });
  return out;
}

Future<Map<String, num>?> _fetchTeamStats(
  EspnFeedClient client,
  int season,
  String teamId,
  Map<String, Map<String, Object?>> definitions,
) async {
  final data = await client.getJson(
    'https://sports.core.api.espn.com/v2/sports/basketball/leagues/$_slug'
    '/seasons/$season/types/2/teams/$teamId/statistics',
  );
  final categories = (data?['splits'] as Map?)?['categories'];
  if (categories is! List) return null;

  final values = <String, num>{};
  for (final category in categories) {
    if (category is! Map) continue;
    final group = category['name']?.toString() ?? 'general';
    for (final stat in (category['stats'] as List? ?? const [])) {
      if (stat is! Map) continue;
      final name = stat['name']?.toString();
      final value = stat['value'];
      if (name == null || value is! num) continue;
      values[name] = value;
      definitions.putIfAbsent(
        name,
        () => {
          'category': group,
          'displayName': stat['displayName']?.toString() ?? name,
          if (stat['shortDisplayName'] != null)
            'shortDisplayName': stat['shortDisplayName'].toString(),
          if (stat['abbreviation'] != null)
            'abbreviation': stat['abbreviation'].toString(),
          if (stat['description'] != null)
            'description': stat['description'].toString(),
        },
      );
    }
  }
  return values.isEmpty ? null : values;
}

// -- Payload ------------------------------------------------------------------

Map<String, Object?> _build({
  required _Standings standings,
  required List<_Board> boards,
  required Map<String, Map<String, Object?>> athletes,
  required Map<String, Map<String, num>> teamStats,
  required Map<String, Map<String, Object?>> definitions,
  required int season,
}) {
  return {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': 'ESPN basketball/$_slug',
    'seasonType': 2,
    'statDictionary': {
      for (final entry in (definitions.keys.toList()..sort()))
        entry: definitions[entry],
    },
    'leagues': [
      {
        'id': _slug,
        'espnId': _espnLeagueId,
        'name': 'National Basketball Association',
        'abbreviation': 'NBA',
        'aliases': _aliases,
        'season': standings.label,
        'seasonYear': season,
        'teams': [
          for (final id in (standings.teams.keys.toList()..sort()))
            standings.teams[id],
        ],
        'conferences': [
          for (final conference in standings.conferences)
            {'label': conference.label, 'rows': conference.rows},
        ],
        'leaders': [
          for (final board in boards)
            {
              'key': board.spec.key,
              'unit': board.spec.unit,
              if (board.spec.qualifier != null)
                'qualifier': board.spec.qualifier!.label,
              'leaders': [
                for (final leader in board.leaders)
                  {
                    'athleteId': leader.athleteId,
                    if (leader.teamId != null) 'teamId': leader.teamId,
                    'value': _round(leader.value),
                  },
              ],
            },
        ],
        'athletes': {
          for (final id in (athletes.keys.toList()..sort())) id: athletes[id],
        },
        'teamStats': {
          for (final id in (teamStats.keys.toList()..sort()))
            id: {
              for (final key in (teamStats[id]!.keys.toList()..sort()))
                key: _round(teamStats[id]![key]!),
            },
        },
      },
    ],
  };
}

/// ESPN sends doubles with 8 decimal places of float noise (`0.73170733`).
/// Rounding here keeps the asset readable and its `--check` diff stable.
num _round(num value) {
  if (value is int || value == value.roundToDouble()) return value.round();
  return double.parse(value.toStringAsFixed(4));
}

// -- Guardrails ---------------------------------------------------------------

/// Asserts the shape the app depends on. If ESPN's feed changes, this fails
/// loudly rather than writing a thinner asset that quietly renders half a hub.
void _verify(Map<String, Object?> payload) {
  final league = (payload['leagues'] as List).single as Map<String, Object?>;

  final teams = league['teams'] as List;
  _expect(
    teams.length == _teamCount,
    'expected $_teamCount teams, got ${teams.length}',
  );

  final conferences = league['conferences'] as List;
  _expect(
    conferences.length == _conferenceCount,
    'expected $_conferenceCount conferences, got ${conferences.length}',
  );
  var rowCount = 0;
  for (final conference in conferences) {
    final rows = (conference as Map)['rows'] as List;
    rowCount += rows.length;
    _expect(
      rows.isNotEmpty,
      'conference ${conference['label']} has no standings rows',
    );
    num previous = 2;
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i] as Map;
      _expect(
        entry['wins'] is num && entry['losses'] is num,
        'standings row ${entry['teamId']} is missing its record',
      );
      _expect(
        entry['rank'] == i + 1,
        'standings row ${entry['teamId']} is ranked ${entry['rank']} at '
        'position ${i + 1}',
      );
      // The table must read downhill. This is the guard that caught the
      // post-play-in seed masquerading as a standings position.
      final pct = entry['winPercent'];
      _expect(
        pct is num && pct <= previous,
        'win percentage climbs at rank ${i + 1} in ${conference['label']}',
      );
      previous = pct as num;
    }
  }
  _expect(
    rowCount == _teamCount,
    'expected $_teamCount standings rows, got $rowCount',
  );

  final boards = league['leaders'] as List;
  _expect(boards.isNotEmpty, 'no leader boards were built');
  final athletes = league['athletes'] as Map;
  for (final board in boards) {
    final entries = (board as Map)['leaders'] as List;
    _expect(
      entries.length == _leadersPerBoard,
      'leader board ${board['key']} kept ${entries.length} of '
      '$_leadersPerBoard after qualifying — widen _candidatesPerBoard',
    );
    for (final entry in entries) {
      final id = (entry as Map)['athleteId'];
      _expect(
        athletes.containsKey(id),
        'leader $id on ${board['key']} has no resolved athlete — an '
        'unresolved leader renders as a blank row',
      );
    }
  }

  final teamStats = league['teamStats'] as Map;
  _expect(
    teamStats.length == _teamCount,
    'expected season statistics for $_teamCount teams, got '
    '${teamStats.length}',
  );
  final dictionary = payload['statDictionary'] as Map;
  _expect(dictionary.isNotEmpty, 'the stat dictionary is empty');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError('Guardrail failed: $message');
}

void _report(Map<String, Object?> payload) {
  final league = (payload['leagues'] as List).single as Map<String, Object?>;
  final teams = <String, String>{
    for (final team in (league['teams'] as List))
      (team as Map)['id'].toString():
          team['abbreviation']?.toString() ?? team['displayName'].toString(),
  };
  final athletes = league['athletes'] as Map;
  stdout.writeln('  season     ${league['season']}');
  for (final conference in (league['conferences'] as List)) {
    final rows = (conference as Map)['rows'] as List;
    final top = rows.first as Map;
    stdout.writeln(
      '  ${conference['label']}: ${teams[top['teamId']]} '
      '${top['wins']}-${top['losses']}',
    );
  }
  for (final board in (league['leaders'] as List)) {
    final top = ((board as Map)['leaders'] as List).first as Map;
    final athlete = athletes[top['athleteId']] as Map?;
    stdout.writeln(
      '  ${board['key'].toString().padRight(20)} '
      '${athlete?['name'] ?? top['athleteId']} ${top['value']}',
    );
  }
}

/// Season totals for every leader candidate, used only to qualify them.
Future<Map<String, Map<String, num>>> _fetchAthleteSeasons(
  EspnFeedClient client,
  int season,
  List<String> ids,
  Duration delay,
) async {
  const wanted = {
    'gamesPlayed',
    'minutes',
    'fieldGoalsMade',
    'threePointFieldGoalsMade',
    'freeThrowsMade',
  };
  final out = <String, Map<String, num>>{};
  await espnPool(ids, (id) async {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/basketball/leagues/$_slug'
      '/seasons/$season/types/2/athletes/$id/statistics/0',
    );
    final categories = (data?['splits'] as Map?)?['categories'];
    if (categories is! List) return;
    final values = <String, num>{};
    for (final category in categories) {
      if (category is! Map) continue;
      for (final stat in (category['stats'] as List? ?? const [])) {
        if (stat is! Map) continue;
        final name = stat['name']?.toString();
        final value = stat['value'];
        if (name != null && wanted.contains(name) && value is num) {
          values[name] = value;
        }
      }
    }
    if (values.isNotEmpty) out[id] = values;
    await Future<void>.delayed(delay);
  });
  return out;
}

/// Applies each board's minimum and keeps the top [_leadersPerBoard] survivors.
/// A candidate whose season totals never arrived is dropped rather than waved
/// through — an unqualified name at the top of a board is worse than a short
/// board.
List<_Board> _qualify(
  List<_Board> candidates,
  Map<String, Map<String, num>> seasons,
) {
  final out = <_Board>[];
  for (final board in candidates) {
    final kept = <_Leader>[];
    for (final leader in board.leaders) {
      if (!board.spec.qualifies(seasons[leader.athleteId])) continue;
      kept.add(leader);
      if (kept.length == _leadersPerBoard) break;
    }
    if (kept.isEmpty) {
      stderr.writeln('  ! ${board.spec.key} has no qualified leaders');
      continue;
    }
    out.add(_Board(spec: board.spec, leaders: kept));
  }
  return out;
}

int _leaderCount(List<_Board> boards) =>
    boards.fold(0, (sum, board) => sum + board.leaders.length);

// -- Helpers ------------------------------------------------------------------

String? _firstLogo(Object? logos) {
  if (logos is! List) return null;
  for (final logo in logos) {
    if (logo is Map && logo['href'] is String) return logo['href'] as String;
  }
  return null;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
