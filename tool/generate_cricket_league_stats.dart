// Generates the bundled IPL league package consumed by the league hub.
//
//   dart run tool/generate_cricket_league_stats.dart [options]
//
//     --league 8048     ESPN cricket league id (8048 = Indian Premier League)
//     --out <path>      Override the output path
//     --delay 250       Milliseconds between requests (ESPN rate-limits hard)
//     --check           Re-extract and diff against the committed asset
//
// WHY THIS EXISTS, AND WHY IT IS NOT LIKE THE FOOTBALL ONE.
//
// Football's league hub is fed by two ESPN core-API feeds: a season `leaders`
// endpoint and a per-team `statistics` endpoint. **Neither exists for cricket.**
// The entire core API rejects the sport:
//
//   sports.core.api.espn.com/v2/sports/cricket/leagues/8048/...
//   → HTTP 400 {"error":{"message":"Invalid sport/league combination"}}
//
// and `site.api.espn.com/.../cricket/8048/statistics` returns 403. The only
// league-level feed that works is standings.
//
// So season leaders and per-team season statistics are **aggregated here, from
// every match summary of the season**: the scoreboard gives the event ids for
// each of the 62 calendar dates, and each summary carries a 46-stat sheet for
// all 24 players (see docs/data/ipl-match-player-field-inventory.md). Summing
// those is the only way to know who led the run charts.
//
// That is roughly 140 requests, run once, offline. ESPN rate-limits an IP hard
// after a burst — a 403 wall that blocks everything for tens of minutes — so
// concurrency is 2 and `--delay` puts a gap between requests. Be patient rather
// than parallel here.

import 'dart:convert';
import 'dart:io';

import 'espn_feed_client.dart';

const _defaultOut = 'assets/data/cricket-league-stats.json';
const _defaultLeague = '8048';

/// ESPN rate-limits aggressively; this is deliberately far below the football
/// generator's 6.
const _concurrency = 2;

/// Every id and label a consumer might look the IPL up by. The league hub
/// resolves by alias because the same competition arrives under the repository
/// id, the follow-list id and ESPN's own numeric id — the same collision
/// documented for the football leagues.
const _aliases = <String>[
  'ipl',
  'IPL',
  '8048',
  'Indian Premier League',
  'indianpremierleague',
];

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final out = espnOptionValue(args, '--out') ?? _defaultOut;
  final league = espnOptionValue(args, '--league') ?? _defaultLeague;
  final delayMs = espnIntOption(args, '--delay') ?? 250;

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    exitCode = 64;
    return;
  }

  final client = EspnFeedClient();
  final delay = Duration(milliseconds: delayMs);
  try {
    stdout.writeln('IPL league package (cricket/$league)');

    final standings = await _fetchStandings(client, league);
    if (standings == null) {
      stderr.writeln('Standings unavailable; nothing written.');
      exitCode = 70;
      return;
    }
    stdout.writeln('  standings  ${standings.rows.length} teams');

    final eventIds = await _fetchSeasonEvents(client, league, delay);
    stdout.writeln('  schedule   ${eventIds.length} completed matches');
    if (eventIds.isEmpty) {
      stderr.writeln('No matches found; nothing written.');
      exitCode = 70;
      return;
    }

    final season = _SeasonAggregate();
    final failed = <String>[];
    var done = 0;
    await espnPool(eventIds, (eventId) async {
      final summary = await client.getJson(
        'https://site.api.espn.com/apis/site/v2/sports/cricket/$league'
        '/summary?event=$eventId',
      );
      done++;
      if (done % 10 == 0) {
        stdout.writeln('  summaries  $done/${eventIds.length}');
      }
      if (summary == null) {
        failed.add(eventId);
      } else {
        season.absorb(summary);
      }
      await Future<void>.delayed(delay);
    }, concurrency: _concurrency);

    // A season aggregate silently missing a match understates whoever played in
    // it, and nothing downstream could tell. Refuse rather than ship a total
    // that is quietly 1/74 short.
    if (failed.isNotEmpty) {
      stderr.writeln(
        'Failed to read ${failed.length} of ${eventIds.length} summaries '
        '(${failed.join(', ')}). Re-run; ESPN 502s and 403s are transient.',
      );
      exitCode = 75;
      return;
    }

    stdout.writeln(
      '  aggregated ${season.players.length} players across '
      '${season.matchesSeen} matches',
    );

    final payload = _build(standings, season, league: league);
    _verify(payload, standings, season);

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
    stdout.writeln(
      'Wrote $out (${(text.length / 1024).toStringAsFixed(1)} KB)',
    );
    _report(payload);
  } finally {
    client.close();
  }
}

// -- Feeds --------------------------------------------------------------------

class _Standings {
  _Standings({required this.rows, required this.teams, this.seasonLabel});

  final List<Map<String, Object?>> rows;
  final Map<String, Map<String, Object?>> teams;
  final String? seasonLabel;
}

/// The one league-level cricket feed that works.
Future<_Standings?> _fetchStandings(EspnFeedClient client, String league) async {
  final data = await client.getJson(
    'https://site.web.api.espn.com/apis/v2/sports/cricket/$league/standings',
  );
  final children = data?['children'];
  if (children is! List || children.isEmpty) return null;

  final rows = <Map<String, Object?>>[];
  final teams = <String, Map<String, Object?>>{};
  String? seasonLabel;

  for (final child in children) {
    if (child is! Map) continue;
    final standings = child['standings'];
    if (standings is! Map) continue;
    seasonLabel ??= standings['displayName']?.toString();
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
      final stats = <String, Object?>{};
      for (final stat in (entry['stats'] as List? ?? const [])) {
        if (stat is! Map) continue;
        final name = stat['name']?.toString();
        if (name == null) continue;
        stats[name] = stat['value'] ?? stat['displayValue']?.toString();
      }
      rows.add({'teamId': id, ...stats});
    }
  }
  rows.sort(
    (a, b) => _asInt(a['rank']).compareTo(_asInt(b['rank'])),
  );
  return _Standings(rows: rows, teams: teams, seasonLabel: seasonLabel);
}

/// Walks the season calendar for completed event ids.
Future<List<String>> _fetchSeasonEvents(
  EspnFeedClient client,
  String league,
  Duration delay,
) async {
  final first = await client.getJson(
    'https://site.api.espn.com/apis/site/v2/sports/cricket/$league/scoreboard',
  );
  final calendar = (first?['leagues'] as List?)?.firstOrNull;
  final dates = <String>[];
  if (calendar is Map) {
    for (final entry in (calendar['calendar'] as List? ?? const [])) {
      final raw = entry?.toString();
      if (raw == null || raw.length < 10) continue;
      dates.add(raw.substring(0, 10).replaceAll('-', ''));
    }
  }
  if (dates.isEmpty) return const [];

  final ids = <String>{};
  for (final date in dates) {
    final board = await client.getJson(
      'https://site.api.espn.com/apis/site/v2/sports/cricket/$league'
      '/scoreboard?dates=$date',
    );
    for (final event in (board?['events'] as List? ?? const [])) {
      if (event is! Map) continue;
      final id = event['id']?.toString();
      // Cricket has no `completed` boolean on the scoreboard — a finished match
      // is `status.type.state == 'post'` with description "Result".
      final state =
          ((event['status'] as Map?)?['type'] as Map?)?['state']?.toString();
      if (id != null && state == 'post') ids.add(id);
    }
    await Future<void>.delayed(delay);
  }
  return ids.toList()..sort();
}

// -- Aggregation --------------------------------------------------------------

/// Season totals, summed from every match summary.
class _SeasonAggregate {
  final Map<String, Map<String, num>> players = {};
  final Map<String, Map<String, Object?>> playerMeta = {};
  final Map<String, Map<String, num>> teamTotals = {};
  int matchesSeen = 0;

  /// Counting stats sum across matches; rates must be recomputed from the
  /// totals afterwards, never averaged.
  static const _summable = {
    'runs',
    'ballsFaced',
    'fours',
    'sixes',
    'minutes',
    'notouts',
    'ducks',
    'fiftyPlus',
    'hundreds',
    'outs',
    'wickets',
    'balls',
    'conceded',
    'maidens',
    'dots',
    'wides',
    'noballs',
    'foursConceded',
    'sixesConceded',
    'fourPlusWickets',
    'fiveWickets',
    'caught',
    'caughtFielder',
    'caughtKeeper',
    'stumped',
    'dismissals',
    'batted',
    'bowled',
  };

  void absorb(Map<String, dynamic> summary) {
    final rosters = summary['rosters'];
    if (rosters is! List || rosters.isEmpty) return;
    matchesSeen++;

    for (final roster in rosters) {
      if (roster is! Map) continue;
      final team = roster['team'];
      final teamId = (team is Map ? team['id'] : null)?.toString() ?? '';
      for (final entry in (roster['roster'] as List? ?? const [])) {
        if (entry is! Map) continue;
        final athlete = entry['athlete'];
        if (athlete is! Map) continue;
        final id = athlete['id']?.toString();
        if (id == null) continue;

        final match = _foldMatchStats(entry);
        if (match.isEmpty) continue;

        playerMeta.putIfAbsent(id, () {
          final position = entry['position'];
          return {
            'id': id,
            'name': athlete['displayName']?.toString() ?? '',
            'teamId': teamId,
            'role':
                (position is Map ? position['name'] : null)?.toString() ?? '',
          };
        });

        final season = players.putIfAbsent(id, () => <String, num>{});
        final teamBucket = teamTotals.putIfAbsent(
          teamId,
          () => <String, num>{},
        );
        for (final stat in match.entries) {
          if (!_summable.contains(stat.key)) continue;
          season[stat.key] = (season[stat.key] ?? 0) + stat.value;
          teamBucket[stat.key] = (teamBucket[stat.key] ?? 0) + stat.value;
        }
        // Innings counts are what rates divide by.
        season['innings'] = (season['innings'] ?? 0) + 1;
      }
    }
  }

  /// One match's sheet, folded across that match's innings blocks.
  Map<String, num> _foldMatchStats(Map<Object?, Object?> entry) {
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
}

// -- Build --------------------------------------------------------------------

/// The leaderboards worth a board. `lowerIsBetter` boards rank ascending and
/// carry a qualifying minimum, or a bowler who sent down one tidy over would
/// top the economy chart.
const _leaderSpecs = <Map<String, Object>>[
  {'key': 'runs', 'label': 'Most Runs', 'stat': 'runs', 'unit': 'RUNS'},
  {'key': 'wickets', 'label': 'Most Wickets', 'stat': 'wickets', 'unit': 'WKTS'},
  {'key': 'sixes', 'label': 'Most Sixes', 'stat': 'sixes', 'unit': 'SIXES'},
  {'key': 'fours', 'label': 'Most Fours', 'stat': 'fours', 'unit': 'FOURS'},
  {
    'key': 'fiftyPlus',
    'label': 'Most Fifties',
    'stat': 'fiftyPlus',
    'unit': '50s',
  },
  {'key': 'dots', 'label': 'Most Dot Balls', 'stat': 'dots', 'unit': 'DOTS'},
  {'key': 'caught', 'label': 'Most Catches', 'stat': 'caught', 'unit': 'CT'},
  {
    'key': 'strikeRate',
    'label': 'Best Strike Rate',
    'stat': 'strikeRate',
    'unit': 'SR',
    'derived': true,
    'minimum': 100,
    'minimumOf': 'ballsFaced',
  },
  {
    'key': 'economyRate',
    'label': 'Best Economy',
    'stat': 'economyRate',
    'unit': 'ECON',
    'derived': true,
    'lowerIsBetter': true,
    'minimum': 120,
    'minimumOf': 'balls',
  },
];

Map<String, Object?> _build(
  _Standings standings,
  _SeasonAggregate season, {
  required String league,
}) {
  // Rates are recomputed from season totals — averaging per-match rates would
  // weight a 4-ball cameo the same as a 60-ball innings.
  for (final entry in season.players.entries) {
    final s = entry.value;
    final balls = s['ballsFaced'] ?? 0;
    if (balls > 0) {
      s['strikeRate'] = double.parse(
        ((s['runs'] ?? 0) * 100 / balls).toStringAsFixed(2),
      );
    }
    final bowled = s['balls'] ?? 0;
    if (bowled > 0) {
      s['economyRate'] = double.parse(
        ((s['conceded'] ?? 0) * 6 / bowled).toStringAsFixed(2),
      );
    }
  }

  final leaders = <Map<String, Object?>>[];
  for (final spec in _leaderSpecs) {
    final stat = spec['stat'] as String;
    final lower = spec['lowerIsBetter'] == true;
    final minimum = (spec['minimum'] as int?) ?? 0;
    final minimumOf = spec['minimumOf'] as String?;

    final ranked =
        season.players.entries
            .where((e) {
              final value = e.value[stat];
              if (value == null || value == 0) return false;
              if (minimumOf == null) return true;
              return (e.value[minimumOf] ?? 0) >= minimum;
            })
            .toList()
          ..sort((a, b) {
            final av = a.value[stat]!;
            final bv = b.value[stat]!;
            return lower ? av.compareTo(bv) : bv.compareTo(av);
          });

    leaders.add({
      'key': spec['key'],
      'displayName': spec['label'],
      'unit': spec['unit'],
      'lowerIsBetter': lower,
      if (minimumOf != null) 'qualifier': '$minimum+ ${_qualifierNoun(minimumOf)}',
      'leaders': [
        for (var i = 0; i < ranked.length && i < 25; i++)
          {
            'rank': i + 1,
            'athleteId': ranked[i].key,
            'teamId': season.playerMeta[ranked[i].key]?['teamId'],
            'value': ranked[i].value[stat],
          },
      ],
    });
  }

  // Only the athletes an actual board references need shipping.
  final referenced = <String>{
    for (final board in leaders)
      for (final row in board['leaders'] as List)
        (row as Map)['athleteId'] as String,
  };

  return <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': 'espn',
    'sport': 'cricket',
    'note':
        'Leaders and team statistics are aggregated from every match summary '
        'of the season: ESPN publishes no league-level leaders or team-stats '
        'feed for cricket (the core API rejects the sport outright).',
    'leagues': [
      {
        'id': league,
        'aliases': _aliases,
        'name': 'Indian Premier League',
        'abbreviation': 'IPL',
        'season': standings.seasonLabel,
        'matchesAggregated': season.matchesSeen,
        'teams': standings.teams.values.toList(),
        'standings': standings.rows,
        'leaders': leaders,
        'athletes': {
          for (final id in referenced)
            if (season.playerMeta[id] != null)
              id: {
                ...season.playerMeta[id]!,
                'stats': season.players[id],
              },
        },
        'teamStats': season.teamTotals,
      },
    ],
  };
}

String _qualifierNoun(String key) => switch (key) {
  'ballsFaced' => 'balls faced',
  'balls' => 'balls bowled',
  _ => key,
};

// -- Verification -------------------------------------------------------------

void _verify(
  Map<String, Object?> payload,
  _Standings standings,
  _SeasonAggregate season,
) {
  if (standings.rows.length < 8) {
    throw StateError('Only ${standings.rows.length} standings rows');
  }
  if (season.matchesSeen < 40) {
    throw StateError('Only ${season.matchesSeen} matches aggregated');
  }
  if (season.players.length < 100) {
    throw StateError('Only ${season.players.length} players aggregated');
  }
  final league = (payload['leagues'] as List).first as Map<String, Object?>;
  final athletes = league['athletes'] as Map;
  for (final board in league['leaders'] as List) {
    final rows = (board as Map)['leaders'] as List;
    if (rows.isEmpty) {
      throw StateError('Board "${board['key']}" resolved no leaders');
    }
    for (final row in rows) {
      if (!athletes.containsKey((row as Map)['athleteId'])) {
        throw StateError('Leader ${row['athleteId']} has no athlete entry');
      }
    }
  }
  // Every standings row must resolve to a team the payload ships.
  final teams = {
    for (final team in league['teams'] as List) (team as Map)['id'],
  };
  for (final row in league['standings'] as List) {
    if (!teams.contains((row as Map)['teamId'])) {
      throw StateError('Standings row ${row['teamId']} has no team entry');
    }
  }
}

void _report(Map<String, Object?> payload) {
  final league = (payload['leagues'] as List).first as Map<String, Object?>;
  stdout.writeln(
    '  ${league['abbreviation']}  ${(league['teams'] as List).length} teams, '
    '${(league['standings'] as List).length} standings rows, '
    '${(league['leaders'] as List).length} boards, '
    '${(league['athletes'] as Map).length} athletes, '
    '${(league['teamStats'] as Map).length} team stat blocks',
  );
  for (final board in league['leaders'] as List) {
    final rows = (board as Map)['leaders'] as List;
    final top = rows.isEmpty ? null : rows.first as Map;
    final name = top == null
        ? '-'
        : ((league['athletes'] as Map)[top['athleteId']] as Map?)?['name'];
    stdout.writeln(
      '    ${board['displayName']}: $name ${top?['value'] ?? ''}',
    );
  }
}

// -- Helpers ------------------------------------------------------------------

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _firstLogo(Object? logos) {
  if (logos is! List || logos.isEmpty) return null;
  final first = logos.first;
  return first is Map ? first['href']?.toString() : null;
}
