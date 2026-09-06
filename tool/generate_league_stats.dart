// Generates the bundled league-stats package consumed by the league hub.
//
//   dart run tool/generate_league_stats.dart [options]
//
//     --leagues eng.1,esp.1   ESPN competition slugs to extract (default: both)
//     --season 2026           Override the season year (default: discovered)
//     --out <path>            Override the output path
//     --check                 Re-extract and diff against the committed asset
//                             without writing (CI mode)
//
// Six ESPN feeds are combined per league. Standings and the site statistics feed
// give the table and the season label; the core leaders feed gives every
// leaderboard but with athletes as reference links; per-team season statistics
// give the 112-stat block the app has never had access to.
//
// Two size decisions keep the asset near 300 KB rather than 1.1 MB:
//  * stat metadata (display names, ESPN's own descriptions) is hoisted into one
//    top-level `statDictionary` instead of repeating per team, and
//  * each team stat reduces to a `[value, displayValue]` pair.
//
// Athletes are deduped into a per-league map — the same striker tops several
// boards, so 300 leader rows resolve to roughly 131 unique players.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

const _defaultOut = 'assets/data/football-league-stats.json';

/// Regular season. ESPN uses type 1 for soccer league play.
const _seasonType = 1;

/// Parallel in-flight requests. ESPN throttles aggressively above this.
const _concurrency = 6;

const _timeout = Duration(seconds: 20);
const _maxAttempts = 4;

/// Competitions to extract, with every id and label a consumer might look them
/// up by. The same competition arrives under four different identifiers
/// depending on the path: the repository's curated `League.id` (`eng.1`), the
/// follow list's id (`epl`), ESPN's *scoreboard* league id (`700`) and ESPN's
/// *standings* league id (`23`) — which are not the same number. Names and
/// abbreviations are included too, so a league discovered at runtime still
/// resolves when its id is one nobody predicted.
const _leagueSpecs = <_LeagueSpec>[
  _LeagueSpec(
    slug: 'eng.1',
    name: 'English Premier League',
    aliases: [
      'eng.1',
      'epl',
      'EPL',
      '700', // ESPN scoreboard league id
      '23', // ESPN standings league id
      'English Premier League',
      'Premier League',
    ],
  ),
  _LeagueSpec(
    slug: 'esp.1',
    name: 'LaLiga',
    aliases: [
      'esp.1',
      'laliga',
      'LAL',
      'LALIGA',
      '740', // ESPN scoreboard league id
      '15', // ESPN standings league id
      'Spanish LALIGA',
      'La Liga',
    ],
  ),
];

class _LeagueSpec {
  const _LeagueSpec({
    required this.slug,
    required this.name,
    required this.aliases,
  });

  final String slug;
  final String name;
  final List<String> aliases;
}

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final out = _optionValue(args, '--out') ?? _defaultOut;
  final seasonOverride = _intOption(args, '--season');
  final slugFilter = _optionValue(args, '--leagues')
      ?.split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    stderr.writeln(
      'Usage: dart run tool/generate_league_stats.dart '
      '[--leagues eng.1,esp.1] [--season 2026] [--out <path>] [--check]',
    );
    exitCode = 64;
    return;
  }

  final specs = slugFilter == null
      ? _leagueSpecs
      : _leagueSpecs.where((s) => slugFilter.contains(s.slug)).toList();
  if (specs.isEmpty) {
    stderr.writeln('No known leagues matched --leagues');
    stderr.writeln('Known slugs: ${_leagueSpecs.map((s) => s.slug).join(', ')}');
    exitCode = 64;
    return;
  }

  final client = _Client();
  // Stat metadata is identical across leagues, so one shared dictionary is
  // filled as the per-team feeds stream in.
  final statDictionary = SplayTreeMap<String, Map<String, Object?>>();
  final leagues = <Map<String, Object?>>[];

  try {
    for (final spec in specs) {
      leagues.add(
        await _extractLeague(client, spec, statDictionary, seasonOverride),
      );
    }
  } finally {
    client.close();
  }

  final payload = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': 'espn',
    'seasonType': _seasonType,
    'statDictionary': statDictionary,
    'leagues': leagues,
  };

  // Compact, not pretty-printed: indenting splits every `[value, displayValue]`
  // pair across four lines and more than doubles the shipped asset (704 KB vs
  // 300 KB). Readability lives in docs/data/league-stats-field-inventory.md.
  final text = '${jsonEncode(payload)}\n';

  if (check) {
    if (!_check(out, text)) {
      exitCode = 1;
      return;
    }
    stdout.writeln('Verified $out (ignoring generatedAt).');
    return;
  }

  final file = File(out);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);
  stdout.writeln(
    'Wrote $out (${(file.lengthSync() / 1024).toStringAsFixed(1)} KB).',
  );
}

Future<Map<String, Object?>> _extractLeague(
  _Client client,
  _LeagueSpec spec,
  SplayTreeMap<String, Map<String, Object?>> statDictionary,
  int? seasonOverride,
) async {
  final slug = spec.slug;
  stdout.writeln('-- $slug (${spec.name})');

  final standingsData = await client.getJson(
    'https://site.web.api.espn.com/apis/v2/sports/soccer/$slug/standings',
  );
  final statsData = await client.getJson(
    'https://site.api.espn.com/apis/site/v2/sports/soccer/$slug/statistics',
  );
  if (standingsData == null) {
    throw StateError('$slug: standings feed returned nothing.');
  }

  final season = statsData?['season'] as Map<String, dynamic>?;
  final seasonYear = seasonOverride ?? (season?['year'] as num?)?.toInt();
  if (seasonYear == null) {
    throw StateError('$slug: could not determine season year; pass --season.');
  }

  // -- Teams + standings ------------------------------------------------------
  final teams = SplayTreeMap<String, Map<String, Object?>>();
  final standings = <Map<String, Object?>>[];

  for (final child in standingsData['children'] as List? ?? const []) {
    if (child is! Map) continue;
    final groupLabel = child['name']?.toString();
    final entries =
        (child['standings'] as Map?)?['entries'] as List? ?? const [];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final teamData = entry['team'] as Map?;
      final teamId = teamData?['id']?.toString();
      if (teamData == null || teamId == null) continue;

      teams[teamId] = <String, Object?>{
        'id': teamId,
        'name': teamData['name']?.toString(),
        'displayName': teamData['displayName']?.toString(),
        'shortDisplayName': teamData['shortDisplayName']?.toString(),
        'abbreviation': teamData['abbreviation']?.toString(),
        'location': teamData['location']?.toString(),
        'logo': _firstLogo(teamData['logos']),
      };

      final stats = SplayTreeMap<String, Object?>();
      for (final s in entry['stats'] as List? ?? const []) {
        if (s is! Map) continue;
        final name = s['name']?.toString();
        if (name == null) continue;
        stats[name] = <Object?>[
          (s['value'] as num?)?.toDouble(),
          s['displayValue']?.toString(),
        ];
      }

      final note = entry['note'] as Map?;
      standings.add(<String, Object?>{
        'teamId': teamId,
        'rank': _statInt(stats, 'rank'),
        if (groupLabel != null && groupLabel.isNotEmpty) 'group': groupLabel,
        'stats': stats,
        'note': note == null
            ? null
            : <String, Object?>{
                'description': note['description']?.toString(),
                'color': _hex(note['color']?.toString()),
                'rank': (note['rank'] as num?)?.toInt(),
              },
      });
    }
  }
  standings.sort(
    (a, b) => (a['rank'] as int? ?? 0).compareTo(b['rank'] as int? ?? 0),
  );
  stdout.writeln('   standings: ${standings.length} rows');

  // -- Leaders ----------------------------------------------------------------
  final leadersData = await client.getJson(
    'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
    '/seasons/$seasonYear/types/$_seasonType/leaders',
  );

  final leaders = <Map<String, Object?>>[];
  final athleteIds = <String>{};
  for (final category in leadersData?['categories'] as List? ?? const []) {
    if (category is! Map) continue;
    final key = category['name']?.toString();
    if (key == null) continue;
    final rows = <Map<String, Object?>>[];
    var rank = 0;
    for (final entry in category['leaders'] as List? ?? const []) {
      if (entry is! Map) continue;
      final athleteId = _idFromRef((entry['athlete'] as Map?)?[r'$ref']);
      if (athleteId == null) continue;
      athleteIds.add(athleteId);
      rows.add(<String, Object?>{
        'rank': ++rank,
        'athleteId': athleteId,
        'teamId': _idFromRef((entry['team'] as Map?)?[r'$ref']),
        'value': (entry['value'] as num?)?.toDouble(),
        'displayValue': entry['displayValue']?.toString(),
      });
    }
    if (rows.isEmpty) continue;
    leaders.add(<String, Object?>{
      'key': key,
      'displayName': category['displayName']?.toString(),
      'shortDisplayName': category['shortDisplayName']?.toString(),
      'abbreviation': category['abbreviation']?.toString(),
      'leaders': rows,
    });
  }
  stdout.writeln(
    '   leaders: ${leaders.length} categories, '
    '${athleteIds.length} unique athletes',
  );

  // -- Team colours (the standings feed carries none) -------------------------
  final teamIds = teams.keys.toList();
  await _pool(teamIds, (teamId) async {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
      '/seasons/$seasonYear/teams/$teamId?lang=en&region=us',
    );
    if (data == null) return;
    final team = teams[teamId]!;
    team['color'] = _hex(data['color']?.toString());
    team['alternateColor'] = _hex(data['alternateColor']?.toString());
    team['logo'] ??= _firstLogo(data['logos']);
  });

  // -- Per-team season statistics ---------------------------------------------
  final teamStats = SplayTreeMap<String, Object?>();
  await _pool(teamIds, (teamId) async {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
      '/seasons/$seasonYear/types/$_seasonType/teams/$teamId/statistics',
    );
    final categories =
        (data?['splits'] as Map?)?['categories'] as List? ?? const [];
    if (categories.isEmpty) return;

    final byCategory = SplayTreeMap<String, Object?>();
    for (final category in categories) {
      if (category is! Map) continue;
      final categoryName = category['name']?.toString();
      if (categoryName == null) continue;
      final values = SplayTreeMap<String, Object?>();
      for (final s in category['stats'] as List? ?? const []) {
        if (s is! Map) continue;
        final name = s['name']?.toString();
        if (name == null) continue;
        values[name] = <Object?>[
          (s['value'] as num?)?.toDouble(),
          s['displayValue']?.toString(),
        ];
        // Metadata is identical for every team, so record it once.
        statDictionary.putIfAbsent(
          name,
          () => <String, Object?>{
            'category': categoryName,
            'displayName': s['displayName']?.toString(),
            'shortDisplayName': s['shortDisplayName']?.toString(),
            'abbreviation': s['abbreviation']?.toString(),
            'description': s['description']?.toString(),
          },
        );
      }
      if (values.isNotEmpty) byCategory[categoryName] = values;
    }
    if (byCategory.isNotEmpty) teamStats[teamId] = byCategory;
  });
  final statCount = teamStats.isEmpty
      ? 0
      : (teamStats.values.first! as Map).values.fold<int>(
          0,
          (sum, c) => sum + (c as Map).length,
        );
  stdout.writeln('   teamStats: ${teamStats.length} teams x $statCount stats');

  // -- Athletes ---------------------------------------------------------------
  final athletes = SplayTreeMap<String, Object?>();
  await _pool(athleteIds.toList(), (athleteId) async {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
      '/seasons/$seasonYear/athletes/$athleteId?lang=en&region=us',
    );
    final name =
        data?['displayName']?.toString() ?? data?['fullName']?.toString();
    if (data == null || name == null) return;
    final position = data['position'] as Map?;
    athletes[athleteId] = <String, Object?>{
      'id': athleteId,
      'displayName': name,
      'fullName': data['fullName']?.toString(),
      'shortName': data['shortName']?.toString(),
      'jersey': data['jersey']?.toString(),
      'position': position?['name']?.toString(),
      'positionAbbr': position?['abbreviation']?.toString(),
      'citizenship': data['citizenship']?.toString(),
      'age': (data['age'] as num?)?.toInt(),
      'dateOfBirth': data['dateOfBirth']?.toString(),
      'flag': (data['flag'] as Map?)?['href']?.toString(),
    };
  });
  stdout.writeln('   athletes: ${athletes.length} resolved');

  return <String, Object?>{
    'slug': slug,
    'aliases': spec.aliases,
    'name': spec.name,
    'season': <String, Object?>{
      'year': seasonYear,
      'displayName': season?['displayName']?.toString(),
      'name': season?['name']?.toString(),
      'type': (season?['type'] as num?)?.toInt(),
    },
    'teams': teams.values.toList(),
    'standings': standings,
    'leaders': leaders,
    'athletes': athletes,
    'teamStats': teamStats,
  };
}

// -- Plumbing -----------------------------------------------------------------

/// Runs [task] over [items] with at most [_concurrency] requests in flight.
Future<void> _pool<T>(List<T> items, Future<void> Function(T) task) async {
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= items.length) return;
      await task(items[index]);
    }
  }

  await Future.wait([
    for (var i = 0; i < _concurrency && i < items.length; i++) worker(),
  ]);
}

class _Client {
  final HttpClient _client = HttpClient()..connectionTimeout = _timeout;

  void close() => _client.close(force: true);

  /// GETs [url], retrying transient failures with a short backoff. Returns null
  /// only once every attempt has failed.
  Future<Map<String, dynamic>?> getJson(String url) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final request = await _client.getUrl(Uri.parse(url)).timeout(_timeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(_timeout);
        if (response.statusCode != 200) {
          await response.drain<void>();
          // 404 is a real answer (no such feed), not a transient failure.
          if (response.statusCode == 404) return null;
          throw HttpException('HTTP ${response.statusCode}');
        }
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(_timeout);
        final decoded = jsonDecode(body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (e) {
        if (attempt == _maxAttempts) {
          stderr.writeln('  ! gave up on $url: $e');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
    return null;
  }
}

bool _check(String path, String expected) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path; run without --check to generate it.');
    return false;
  }
  if (_withoutTimestamp(file.readAsStringSync()) !=
      _withoutTimestamp(expected)) {
    stderr.writeln('$path is out of date; re-run without --check.');
    return false;
  }
  return true;
}

/// Re-encodes without `generatedAt` so a fresh run can be compared against the
/// committed asset — the timestamp changes on every invocation. Structural
/// rather than line-based, because the asset is written compact.
String _withoutTimestamp(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) return source;
  return jsonEncode(
    <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key != 'generatedAt') entry.key: entry.value,
    },
  );
}

String? _optionValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  final value = args[index + 1];
  args.removeRange(index, index + 2);
  return value;
}

int? _intOption(List<String> args, String name) {
  final raw = _optionValue(args, name);
  return raw == null ? null : int.tryParse(raw);
}

int? _statInt(Map<String, Object?> stats, String name) {
  final pair = stats[name];
  if (pair is! List || pair.isEmpty) return null;
  return (pair.first as num?)?.round();
}

String? _firstLogo(Object? logos) {
  if (logos is! List || logos.isEmpty) return null;
  final first = logos.first;
  return first is Map ? first['href']?.toString() : null;
}

/// ESPN returns bare `e20520`; the app's colour parsing expects a leading `#`.
String? _hex(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final cleaned = raw.replaceAll('#', '');
  if (cleaned.isEmpty) return null;
  return '#${cleaned.toLowerCase()}';
}

/// Pulls the trailing id out of a core-API reference URL, e.g.
/// `.../athletes/277128?lang=en` becomes `277128`.
String? _idFromRef(Object? ref) {
  if (ref is! String) return null;
  final segments = Uri.tryParse(ref)?.pathSegments;
  if (segments == null || segments.isEmpty) return null;
  return segments.last.isEmpty ? null : segments.last;
}
