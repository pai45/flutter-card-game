// Generates a bundled F1 race-weekend package.
//
//   dart run tool/generate_f1_race.dart [options]
//
//     --race italian    Match a race by name or 3-letter code within the season
//     --season 2026     Season year to resolve --race against
//     --event 600057442 Skip the lookup and extract this event id directly
//     --out <path>      Override the output path
//     --check           Re-extract and diff against the committed asset
//
// WHY THIS USES A DIFFERENT HOST TO THE RUNTIME SERVICE.
//
// lib/services/espn_score_service.dart reads F1 from
// `site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=2026` and
// flattens each session into display strings. That host answers inside the app
// but returns **403 for every sport** to an offline extractor like this one —
// Akamai bot filtering, not an F1 problem (soccer 403s from here too). There is
// also no `summary?event=` feed for racing at all: it 404s, unlike football and
// cricket, so there is no single rich document to pull.
//
// What does work offline is the core API, which models a race weekend as a
// reference graph rather than a document:
//
//   /events/{id}                    the weekend: dates, circuit ref, 5 sessions
//   /circuits/{id}                  length, laps, turns, lap record, track maps
//   /venues/{id}                    address, country flag, photo
//   .../competitions/{id}/statistics                 session totals
//   .../competitors/{ath}/status     Classified / Retired + laps
//   .../competitors/{ath}/statistics per-driver stat sheet
//   /seasons/{yr}/athletes/{id}      car number, engine, tyre, flag, birthplace
//
// plus championship tables from site.web.api's `/racing/f1/standings`.
//
// So this walks the graph: ~260 requests for one weekend, most of them the
// 5 sessions x 22 drivers x 2 endpoints of classification detail. Run once,
// offline, and commit the result. See docs/data/f1-race-field-inventory.md for
// the full field inventory and the quirks encoded below.

import 'dart:convert';
import 'dart:io';

import 'espn_feed_client.dart';

const _defaultOut = 'assets/data/f1-italian-gp.json';
const _defaultRace = 'italian';
const _defaultSeason = 2026;

const _core = 'https://sports.core.api.espn.com/v2/sports/racing/leagues/f1';
const _standingsUrl =
    'https://site.web.api.espn.com/apis/v2/sports/racing/f1/standings';
const _headshotBase =
    'https://a.espncdn.com/i/headshots/rpm/players/full';

/// Session-level stats ESPN defines for F1 but never populates: every one of
/// them comes back `.000` on a completed race. A UI rendering `victoryMargin`
/// would print a margin of victory of zero for a 3.8s win, so they are dropped
/// at extraction rather than left for a consumer to discover.
const _deadSessionStats = <String>{
  'avgSpeed',
  'victoryMargin',
  'poleSpeed',
  'poleTime',
};

/// `pole` is not a pole flag. In a race stat sheet it holds the driver's grid
/// slot — the Italian GP winner's value is 19, because he started 19th. The
/// competitor's own `startOrder` says the same thing without the trap, so this
/// is dropped and `grid` is read from there.
const _misleadingCompetitorStats = <String>{'pole'};

/// Stats where ESPN writes a zero instead of omitting the field, and zero is
/// not a real value:
///   - a driver eliminated in Q1 has `qual2TimeMS`/`qual3TimeMS` of 0.000
///   - only lead-lap finishers get a `totalTime`; the rest get 0
///   - `fastestLap` is filled in for the one driver who set the fastest lap
/// Serialising those as 0 would claim a driver set a 0.000 lap, so they are
/// omitted and a consumer sees an absent key.
const _zeroMeansAbsent = <String>{
  'totalTime',
  'qual1TimeMS',
  'qual2TimeMS',
  'qual3TimeMS',
  'fastestLap',
  'fastestLapNum',
};

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final out = espnOptionValue(args, '--out') ?? _defaultOut;
  final race = espnOptionValue(args, '--race') ?? _defaultRace;
  final season = espnIntOption(args, '--season') ?? _defaultSeason;
  final eventOption = espnOptionValue(args, '--event');

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    exitCode = 64;
    return;
  }

  final client = EspnFeedClient();
  try {
    final eventId = eventOption ?? await _resolveEvent(client, season, race);
    if (eventId == null) {
      exitCode = 70;
      return;
    }
    stdout.writeln('F1 race package (season $season, event $eventId)');

    final event = await client.getJson('$_core/events/$eventId');
    if (event == null) {
      stderr.writeln('Event $eventId unavailable; nothing written.');
      exitCode = 70;
      return;
    }

    final payload = await _extract(client, event, season);
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

    final file = File(out);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    stdout.writeln(
      'Wrote $out (${(text.length / 1024).toStringAsFixed(1)} KB)',
    );
    _report(payload);
  } finally {
    client.close();
  }
}

/// Finds the event whose name or 3-letter abbreviation matches [race] within
/// [season]. Ambiguity is an error rather than a silent first-match: "grand
/// prix" would otherwise resolve to whichever race ESPN happened to list first.
Future<String?> _resolveEvent(
  EspnFeedClient client,
  int season,
  String race,
) async {
  final index = await client.getJson(
    '$_core/seasons/$season/types/2/events?limit=60',
  );
  final items = (index?['items'] as List?) ?? const [];
  if (items.isEmpty) {
    stderr.writeln('No events listed for season $season.');
    return null;
  }

  final needle = race.toLowerCase();
  final matches = <String, String>{};
  await espnPool(items.cast<Object?>().toList(), (item) async {
    final ref = _https(espnRefOf(item));
    if (ref == null) return;
    final event = await client.getJson(ref);
    if (event == null) return;
    final id = event['id'] as String?;
    final name = (event['name'] as String?) ?? '';
    final code = (event['abbreviation'] as String?) ?? '';
    if (id == null) return;
    if (name.toLowerCase().contains(needle) ||
        code.toLowerCase() == needle) {
      matches[id] = name;
    }
  });

  if (matches.isEmpty) {
    stderr.writeln('No $season race matched "$race".');
    return null;
  }
  if (matches.length > 1) {
    stderr.writeln(
      'Ambiguous race "$race" — matched '
      '${matches.entries.map((e) => '${e.key} (${e.value})').join(', ')}. '
      'Re-run with --event <id>.',
    );
    return null;
  }
  stdout.writeln('  resolved   "$race" -> ${matches.values.single}');
  return matches.keys.single;
}

Future<Map<String, Object?>> _extract(
  EspnFeedClient client,
  Map<String, dynamic> event,
  int season,
) async {
  final dictionary = <String, Map<String, Object?>>{};

  final circuit = await _fetchCircuit(client, event);
  final sessions = await _fetchSessions(client, event, dictionary);
  final driverIds = <String>{
    for (final session in sessions)
      for (final row in session['classification'] as List)
        (row as Map)['driverId'] as String,
  };
  final standings = await _fetchStandings(client);
  final constructors = standings.constructors;
  final drivers = await _fetchDrivers(
    client,
    season,
    driverIds.toList()..sort(),
    constructors,
  );

  return <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': 'espn',
    'sport': 'motorsport',
    'series': const {
      'id': '2030',
      'slug': 'f1',
      'name': 'Formula 1',
      'abbreviation': 'F1',
      'color': 'ff1E00',
    },
    'statDictionary': _sortedMap(dictionary),
    'race': {
      'id': event['id'],
      'name': event['name'],
      'shortName': event['shortName'],
      'abbreviation': event['abbreviation'],
      'season': season,
      'seasonType': 2,
      'startDate': event['date'],
      'endDate': event['endDate'],
      'links': _links(event),
      'defendingChampion': {
        'driverId': espnIdFromRef(
          espnRefOf((event['defendingChampion'] as Map?)?['driver']),
        ),
        'constructorId': espnIdFromRef(
          espnRefOf((event['defendingChampion'] as Map?)?['manufacturer']),
        ),
      },
      'circuit': circuit,
    },
    'drivers': drivers,
    'constructors': _sortedMap(constructors.byId),
    'sessions': sessions,
    'standings': {
      'season': season,
      'throughRace': event['abbreviation'],
      'raceCodes': standings.raceCodes,
      'drivers': standings.drivers,
      'constructors': standings.constructorRows,
    },
  };
}

Future<Map<String, Object?>?> _fetchCircuit(
  EspnFeedClient client,
  Map<String, dynamic> event,
) async {
  final ref = _https(espnRefOf(event['circuit']));
  if (ref == null) return null;
  final circuit = await client.getJson(ref);
  if (circuit == null) return null;

  final venueRef = _https(espnRefOf(circuit['track']));
  final venue = venueRef == null ? null : await client.getJson(venueRef);
  final address = (circuit['address'] as Map?) ?? const {};

  return <String, Object?>{
    'id': circuit['id'],
    'fullName': circuit['fullName'],
    'city': address['city'],
    'country': address['country'],
    'countryFlag': ((venue?['countryFlag'] as Map?)?['href']),
    'type': circuit['type'],
    // ESPN ships these as display strings ("5.793 km"); the numbers are what a
    // consumer wants, and the unit is always km.
    'lengthKm': _kilometres(circuit['length']),
    'distanceKm': _kilometres(circuit['distance']),
    'laps': circuit['laps'],
    'turns': circuit['turns'],
    'direction': circuit['direction'],
    'established': circuit['established'],
    'lapRecord': {
      'driverId': espnIdFromRef(espnRefOf(circuit['fastestLapDriver'])),
      'time': circuit['fastestLapTime'],
      'year': circuit['fastestLapYear'],
    },
    'diagrams': _diagrams(circuit['diagrams']),
    'photo': (((venue?['images'] as List?)?.firstOrNull) as Map?)?['href'],
  };
}

/// Keeps the SVG of each diagram variant, keyed by its `rel` tail. ESPN ships
/// every map twice (SVG and JPG at 2000x1125); the vector scales, so the raster
/// duplicate is dropped.
Map<String, Object?> _diagrams(Object? raw) {
  final out = <String, Object?>{};
  for (final entry in (raw as List? ?? const [])) {
    if (entry is! Map) continue;
    final href = entry['href'] as String?;
    if (href == null || !href.endsWith('.svg')) continue;
    final rel = (entry['rel'] as List?)?.whereType<String>().toList() ?? [];
    final key = rel.where((r) => r != 'full').join('-');
    if (key.isEmpty) continue;
    out[_camel(key)] = href;
  }
  return _sortedMap(out);
}

Future<List<Map<String, Object?>>> _fetchSessions(
  EspnFeedClient client,
  Map<String, dynamic> event,
  Map<String, Map<String, Object?>> dictionary,
) async {
  final competitions = (event['competitions'] as List?) ?? const [];
  if (competitions.isEmpty) {
    throw StateError('Event ${event['id']} has no competitions.');
  }

  final sessions = <Map<String, Object?>>[];
  for (var i = 0; i < competitions.length; i++) {
    final competition = competitions[i] as Map<String, dynamic>;
    final id = competition['id'] as String;
    final type = (competition['type'] as Map?) ?? const {};

    final totals = await client.getJson('$_core/events/${event['id']}'
        '/competitions/$id/statistics');
    final competitors = (competition['competitors'] as List?) ?? const [];
    final rows = List<Map<String, Object?>?>.filled(competitors.length, null);

    await espnPool(
      List<int>.generate(competitors.length, (index) => index),
      (index) async {
        rows[index] = await _classificationRow(
          client,
          competitors[index] as Map<String, dynamic>,
          dictionary,
        );
      },
    );

    final classification = rows.whereType<Map<String, Object?>>().toList()
      ..sort(
        (a, b) => (a['position'] as int).compareTo(b['position'] as int),
      );

    stdout.writeln(
      '  ${(type['abbreviation'] as String? ?? '?').padRight(5)}'
      '  ${classification.length} entries',
    );

    sessions.add(<String, Object?>{
      'id': id,
      'order': i + 1,
      'type': {
        'id': type['id'],
        'text': type['text'],
        'abbreviation': type['abbreviation'],
      },
      'date': competition['date'],
      'stats': _statBlock(
        (totals?['categories'] as List?),
        dictionary,
        drop: _deadSessionStats,
      ),
      'classification': classification,
    });
  }
  return sessions;
}

Future<Map<String, Object?>?> _classificationRow(
  EspnFeedClient client,
  Map<String, dynamic> competitor,
  Map<String, Map<String, Object?>> dictionary,
) async {
  final driverId = competitor['id'] as String?;
  final position = competitor['order'];
  if (driverId == null || position is! int) return null;

  final statusRef = _https(espnRefOf(competitor['status']));
  final statsRef = _https(espnRefOf(competitor['statistics']));
  final status = statusRef == null ? null : await client.getJson(statusRef);
  final stats = statsRef == null ? null : await client.getJson(statsRef);

  final vehicle = (competitor['vehicle'] as Map?) ?? const {};
  final statusType = (status?['type'] as Map?) ?? const {};

  return <String, Object?>{
    'position': position,
    'driverId': driverId,
    // Grid, not qualifying position: at Monza the winner qualified 7th and
    // started 19th. Only `startOrder` reflects penalties, and ESPN sets it on
    // the race session alone.
    if (competitor['startOrder'] != null) 'grid': competitor['startOrder'],
    if (competitor['winner'] == true) 'winner': true,
    'number': vehicle['number'],
    'constructor': vehicle['manufacturer'],
    'teamColor': vehicle['teamColor'],
    'status': {
      'name': statusType['name'],
      'description': statusType['description'],
      'completed': statusType['completed'],
      'laps': status?['period'],
    },
    'stats': _statBlock(
      ((stats?['splits'] as Map?)?['categories'] as List?),
      dictionary,
      drop: _misleadingCompetitorStats,
    ),
  };
}

/// Flattens ESPN's category/stat nesting into `name -> [value, displayValue]`,
/// hoisting each stat's labels into [dictionary] so the descriptions are stored
/// once for the file rather than repeated on all 110 classification rows.
Map<String, Object?> _statBlock(
  List<Object?>? categories,
  Map<String, Map<String, Object?>> dictionary, {
  Set<String> drop = const {},
}) {
  final out = <String, Object?>{};
  for (final category in categories ?? const []) {
    if (category is! Map) continue;
    for (final stat in (category['stats'] as List? ?? const [])) {
      if (stat is! Map) continue;
      final name = stat['name'] as String?;
      if (name == null || drop.contains(name)) continue;

      final value = stat['value'];
      if (_zeroMeansAbsent.contains(name) && (value is num) && value == 0) {
        continue;
      }

      dictionary.putIfAbsent(
        name,
        () => <String, Object?>{
          'displayName': stat['displayName'],
          'shortDisplayName': stat['shortDisplayName'],
          'abbreviation': stat['abbreviation'],
          'description': stat['description'],
        },
      );
      out[name] = <Object?>[_number(value), stat['displayValue']];
    }
  }
  return _sortedMap(out);
}

Future<Map<String, Object?>> _fetchDrivers(
  EspnFeedClient client,
  int season,
  List<String> ids,
  _Constructors constructors,
) async {
  final drivers = <String, Object?>{};
  await espnPool(ids, (id) async {
    final athlete = await client.getJson('$_core/seasons/$season/athletes/$id');
    if (athlete == null) return;
    final vehicle =
        ((athlete['vehicles'] as List?)?.firstOrNull as Map?) ?? const {};
    final team = vehicle['team'] as String?;
    drivers[id] = <String, Object?>{
      'id': id,
      'fullName': athlete['fullName'],
      'displayName': athlete['displayName'],
      'shortName': athlete['shortName'],
      'abbreviation': athlete['abbreviation'],
      'slug': athlete['slug'],
      'dateOfBirth': athlete['dateOfBirth'],
      'birthPlace': (athlete['birthPlace'] as Map?)?['city'],
      'countryFlag': (athlete['flag'] as Map?)?['href'],
      'countryName': (athlete['flag'] as Map?)?['alt'],
      'headshot': '$_headshotBase/$id.png',
      'number': vehicle['number'],
      'constructorId': constructors.idFor(team ?? vehicle['manufacturer']),
      'team': team,
      'engine': vehicle['engine'],
      'tire': vehicle['tire'],
    };
  });
  stdout.writeln('  drivers ${drivers.length}/${ids.length}');
  return _sortedMap(drivers);
}

Future<_Standings> _fetchStandings(EspnFeedClient client) async {
  final raw = await client.getJson(_standingsUrl);
  final children = (raw?['children'] as List?) ?? const [];
  if (children.isEmpty) {
    throw StateError('Standings returned no tables.');
  }

  var raceCodes = const <String>[];
  final driverRows = <Map<String, Object?>>[];
  final constructorRows = <Map<String, Object?>>[];
  final constructorsById = <String, Map<String, Object?>>{};
  final constructorIdByName = <String, String>{};

  for (final child in children) {
    if (child is! Map) continue;
    final entries =
        ((child['standings'] as Map?)?['entries'] as List?) ?? const [];
    if (entries.isEmpty) continue;

    // The per-race points grid is keyed by 3-letter GP code, and the codes are
    // only discoverable from the stat names themselves.
    if (raceCodes.isEmpty) {
      raceCodes = [
        for (final stat in (entries.first as Map)['stats'] as List)
          if (stat is Map)
            if (!const {'rank', 'championshipPts', 'points', 'overall'}
                .contains(stat['name']))
              stat['name'] as String,
      ];
    }

    final isConstructor = (child['name'] as String?)?.contains('Constructor')
        ?? false;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final stats = <String, String>{
        for (final stat in (entry['stats'] as List? ?? const []))
          if (stat is Map && stat['displayValue'] is String)
            stat['name'] as String: stat['displayValue'] as String,
      };
      final byRace = <String, Object?>{
        for (final code in raceCodes) code: ?_racePoints(stats[code]),
      };

      if (isConstructor) {
        final team = (entry['team'] as Map?) ?? const {};
        final id = team['id'] as String?;
        if (id == null) continue;
        constructorsById[id] = <String, Object?>{
          'id': id,
          'name': team['name'],
          'displayName': team['displayName'],
          // `abbreviation` is junk for F1 constructors — Mercedes comes back as
          // "LP" — so it is deliberately not carried through.
          'color': team['color'],
        };
        final name = team['name'] as String?;
        if (name != null) constructorIdByName[name.toLowerCase()] = id;
        constructorRows.add(<String, Object?>{
          'rank': int.tryParse(stats['rank'] ?? ''),
          'constructorId': id,
          'points': int.tryParse(stats['points'] ?? ''),
          'byRace': byRace,
        });
      } else {
        final athlete = (entry['athlete'] as Map?) ?? const {};
        final id = athlete['id'] as String?;
        if (id == null) continue;
        driverRows.add(<String, Object?>{
          'rank': int.tryParse(stats['rank'] ?? ''),
          'driverId': id,
          'name': athlete['displayName'],
          'points': int.tryParse(stats['championshipPts'] ?? ''),
          'byRace': byRace,
        });
      }
    }
  }

  driverRows.sort((a, b) => _rank(a).compareTo(_rank(b)));
  constructorRows.sort((a, b) => _rank(a).compareTo(_rank(b)));
  stdout.writeln(
    '  standings  ${driverRows.length} drivers, '
    '${constructorRows.length} constructors',
  );

  return _Standings(
    raceCodes: raceCodes,
    drivers: driverRows,
    constructorRows: constructorRows,
    constructors: _Constructors(constructorsById, constructorIdByName),
  );
}

class _Standings {
  _Standings({
    required this.raceCodes,
    required this.drivers,
    required this.constructorRows,
    required this.constructors,
  });

  final List<String> raceCodes;
  final List<Map<String, Object?>> drivers;
  final List<Map<String, Object?>> constructorRows;
  final _Constructors constructors;
}

class _Constructors {
  _Constructors(this.byId, this._idByName);

  final Map<String, Map<String, Object?>> byId;
  final Map<String, String> _idByName;

  /// The season athlete feed names a driver's team as a string ("Racing
  /// Bulls"); only the standings feed carries constructor ids. All 11 team
  /// strings match a standings row exactly, so the join is by name.
  String? idFor(Object? team) =>
      team is String ? _idByName[team.toLowerCase()] : null;
}

/// A blank cell means the race has not happened; "-" means the entrant raced
/// and scored nothing. Only the first is absent data.
int? _racePoints(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value == '-') return 0;
  return int.tryParse(value);
}

int _rank(Map<String, Object?> row) => (row['rank'] as int?) ?? 1 << 20;

void _verify(Map<String, Object?> payload) {
  final sessions = payload['sessions'] as List;
  final drivers = payload['drivers'] as Map;
  final race = sessions.firstWhere(
    (s) => ((s as Map)['type'] as Map)['abbreviation'] == 'Race',
    orElse: () => throw StateError('No race session in the weekend.'),
  ) as Map;

  final classification = race['classification'] as List;
  if (classification.length < 10) {
    throw StateError(
      'Race has only ${classification.length} entries; expected a full field.',
    );
  }
  for (final session in sessions) {
    for (final row in (session as Map)['classification'] as List) {
      final id = (row as Map)['driverId'];
      if (!drivers.containsKey(id)) {
        throw StateError('Classification references unknown driver $id.');
      }
    }
  }
  final standings = payload['standings'] as Map;
  if ((standings['drivers'] as List).isEmpty ||
      (standings['constructors'] as List).isEmpty) {
    throw StateError('Standings are missing a table.');
  }
  if ((payload['race'] as Map)['circuit'] == null) {
    throw StateError('Circuit could not be resolved.');
  }
}

void _report(Map<String, Object?> payload) {
  final race = payload['race'] as Map;
  final circuit = race['circuit'] as Map;
  final drivers = payload['drivers'] as Map;
  final sessions = payload['sessions'] as List;
  stdout.writeln('  ${race['name']} — ${circuit['fullName']}');
  stdout.writeln(
    '  ${circuit['laps']} laps, ${circuit['turns']} turns, '
    'lap record ${(circuit['lapRecord'] as Map)['time']}',
  );
  for (final session in sessions) {
    final rows = (session as Map)['classification'] as List;
    final winner = rows.isEmpty ? null : rows.first as Map;
    final name = winner == null
        ? '-'
        : ((drivers[winner['driverId']] as Map?)?['displayName'] ?? '?');
    stdout.writeln(
      '  ${((session['type'] as Map)['abbreviation'] as String).padRight(5)}'
      '  P1 $name',
    );
  }
}

Map<String, Object?> _links(Map<String, dynamic> event) {
  final out = <String, Object?>{};
  for (final link in (event['links'] as List? ?? const [])) {
    if (link is! Map) continue;
    final text = link['text'] as String?;
    final href = link['href'] as String?;
    if (text == null || href == null) continue;
    out[_camel(text)] = href;
  }
  return _sortedMap(out);
}

/// ESPN writes every stat value as a double. Whole numbers are re-encoded as
/// ints so laps read `53`, not `53.0`.
Object? _number(Object? value) {
  if (value is! num) return value;
  final asDouble = value.toDouble();
  return asDouble == asDouble.truncateToDouble() && asDouble.abs() < 1e15
      ? asDouble.toInt()
      : asDouble;
}

/// "5.793 km" -> 5.793
double? _kilometres(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is! String) return null;
  return double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
}

String _camel(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return raw;
  return parts.first.toLowerCase() +
      parts
          .skip(1)
          .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
          .join();
}

/// Sorted so a re-run produces a byte-identical file and `--check` means
/// something; ESPN does not guarantee key order.
Map<String, T> _sortedMap<T>(Map<String, T> source) => <String, T>{
  for (final key in source.keys.toList()..sort()) key: source[key] as T,
};

String? _https(String? ref) => ref?.replaceFirst('http://', 'https://');

/// Reads `{"$ref": "..."}` wrappers, which the core API uses for every edge.
String? espnRefOf(Object? node) =>
    node is Map ? node[r'$ref'] as String? : (node is String ? node : null);

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
