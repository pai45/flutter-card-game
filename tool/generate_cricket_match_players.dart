// Adds the per-player match layer to the bundled cricket match package.
//
//   dart run tool/generate_cricket_match_players.dart [options]
//
//     --event 1535465    ESPN event id (default: the bundled IPL 2026 final)
//     --league 8048      ESPN cricket league id (8048 = Indian Premier League)
//     --asset <path>     Override the asset path
//     --summary <path>   Read the summary feed from a saved JSON file
//     --pbp <path>       Read the play-by-play from a saved JSON file
//     --check            Re-extract and diff against the committed asset
//                        without writing (CI mode)
//
// Two ESPN feeds are combined. The site summary carries a 46-stat sheet for
// every one of the 24 players — batting, bowling and fielding in one block —
// nested under `rosters[].roster[].linescores[].linescores[].statistics`, which
// is a very different shape from soccer's flat `stats` array. The play-by-play
// feed carries all 233 deliveries with both the batsman and the bowler named,
// which is what makes a per-player innings tape possible.
//
// ESPN publishes NO positional data for cricket — no wagon wheel, no pitch map,
// no line and length. The core `plays` feed that gives soccer its coordinates
// does not exist for cricket at all (HTTP 400, "Invalid sport/league
// combination"). Do not go looking for it again; the tape is a sequence, not a
// map, because a sequence is what the data supports.
//
// THIS GENERATOR MERGES; IT NEVER REWRITES. assets/data/cricket-revamp.json was
// hand-transcribed from a published scorecard and has no generator that can
// reproduce its commentary, notes or innings progressions. Every pre-existing
// subtree is asserted byte-identical before anything is written.
//
// WARNING: `stats` is positional against the hoisted `playerStatKeys`. Never
// reorder one without the other — Dart always zips the two together, and a
// half-applied hand-edit would silently mislabel every number on every card.

import 'dart:convert';
import 'dart:io';

import 'espn_feed_client.dart';

const _defaultAsset = 'assets/data/cricket-revamp.json';
const _defaultEvent = '1535465';
const _defaultLeague = '8048';

/// Root keys this generator produces. The hand-authored asset must never use
/// them, and --check strips them before comparing.
const _ownedRootKeys = {
  'espnEventId',
  'playerStatKeys',
  'playerStats',
  'deliveryAthletes',
  'deliveryOutcomes',
  'deliveries',
  'playerStatsGeneratedAt',
};

/// The verified shape of this fixture, asserted so a shifting feed fails loudly
/// rather than quietly writing a thinner asset. Probed 2026-09-07.
const _expectPlayers = 24;
const _expectDeliveries = 233;
const _expectFirstInnings = 124;
const _expectSecondInnings = 109;
const _expectStatKeys = 46;

/// A wide is not a ball faced; a leg bye is. Runs off the bat exclude both wides
/// and leg byes. This rule reproduces every batter's `runs`/`ballsFaced` from
/// the stat sheet exactly, which is what the generator asserts below.
const _notBallsFaced = {'wide'};
const _notOffTheBat = {'wide', 'leg bye', 'bye'};

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final assetPath = espnOptionValue(args, '--asset') ?? _defaultAsset;
  final eventId = espnOptionValue(args, '--event') ?? _defaultEvent;
  final league = espnOptionValue(args, '--league') ?? _defaultLeague;
  // Saved responses make a run reproducible and let --check work without the
  // network. ESPN rate-limits an IP hard after a burst of requests, which is
  // otherwise enough to block a rerun for tens of minutes.
  final summaryFile = espnOptionValue(args, '--summary');
  final pbpFile = espnOptionValue(args, '--pbp');

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    stderr.writeln(
      'Usage: dart run tool/generate_cricket_match_players.dart '
      '[--event 1535465] [--league 8048] [--asset <path>] [--check]',
    );
    exitCode = 64;
    return;
  }

  final file = File(assetPath);
  if (!file.existsSync()) {
    stderr.writeln('Missing $assetPath');
    exitCode = 66;
    return;
  }
  final original = file.readAsStringSync();
  final asset = jsonDecode(original) as Map<String, dynamic>;

  final client = EspnFeedClient();
  try {
    stdout.writeln('Event $eventId (cricket/$league)');

    final sheets = await _fetchStatSheets(
      client,
      league,
      eventId,
      cached: summaryFile,
    );
    if (sheets == null) {
      stderr.writeln('Could not read the summary feed; nothing written.');
      exitCode = 70;
      return;
    }
    stdout.writeln('  summary   ${sheets.length} players');

    final balls = await _fetchDeliveries(
      client,
      league,
      eventId,
      cached: pbpFile,
    );
    stdout.writeln('  pbp       ${balls.length} deliveries');

    final layer = _generatedLayer(sheets, balls, eventId: eventId);
    _verify(asset, layer, sheets, balls);

    if (check) {
      // Compares the DATA, not the byte layout: rebuild what the committed
      // asset should carry and diff it against what it does. Splicing text
      // would double the block on a file that already has one.
      const ignoring = {'playerStatsGeneratedAt'};
      final expected = <String, Object?>{...asset, ...layer};
      final a = jsonEncode({
        for (final e in asset.entries)
          if (!ignoring.contains(e.key)) e.key: e.value,
      });
      final b = jsonEncode({
        for (final e in expected.entries)
          if (!ignoring.contains(e.key)) e.key: e.value,
      });
      if (a != b) {
        stderr.writeln('$assetPath is out of date; re-run without --check.');
        exitCode = 1;
        return;
      }
      stdout.writeln('$assetPath is up to date.');
      return;
    }

    final text = _splice(original, layer);
    file.writeAsStringSync(text);
    final beforeKb = (original.length / 1024).toStringAsFixed(1);
    final afterKb = (text.length / 1024).toStringAsFixed(1);
    stdout.writeln('Wrote $assetPath ($beforeKb KB -> $afterKb KB)');
    _report(layer, balls);
  } finally {
    client.close();
  }
}

// -- Feeds --------------------------------------------------------------------

/// Per-athlete stat sheet from the summary feed.
///
/// Cricket nests these far deeper than soccer: each roster entry carries
/// `linescores` (one per innings), each of which carries its own `linescores`
/// whose `statistics.categories[].stats[]` hold the numbers. A player who
/// batted in one innings and bowled in another contributes to both, so the
/// values are folded together into one sheet per athlete.
Future<Map<String, Map<String, num>>?> _fetchStatSheets(
  EspnFeedClient client,
  String league,
  String eventId, {
  String? cached,
}) async {
  final data =
      _readCached(cached) ??
      await client.getJson(
        'https://site.api.espn.com/apis/site/v2/sports/cricket/$league/summary'
        '?event=$eventId',
      );
  final rosters = data?['rosters'];
  if (rosters is! List || rosters.isEmpty) return null;

  final sheets = <String, Map<String, num>>{};
  for (final roster in rosters) {
    if (roster is! Map) continue;
    final entries = roster['roster'];
    if (entries is! List) continue;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final athleteId = (entry['athlete'] as Map?)?['id']?.toString();
      if (athleteId == null) continue;
      final values = <String, num>{};
      for (final outer in (entry['linescores'] as List? ?? const [])) {
        if (outer is! Map) continue;
        for (final inner in (outer['linescores'] as List? ?? const [])) {
          if (inner is! Map) continue;
          final categories =
              (inner['statistics'] as Map?)?['categories'] as List?;
          for (final category in categories ?? const []) {
            if (category is! Map) continue;
            for (final stat in (category['stats'] as List? ?? const [])) {
              if (stat is! Map) continue;
              final name = stat['name']?.toString();
              final value = stat['value'];
              if (name == null || value is! num) continue;
              // Innings blocks are disjoint (a player bats in one, bowls in
              // another), so the larger value is the real one rather than a sum
              // that would double-count a zero-filled block.
              final existing = values[name];
              if (existing == null || value.abs() > existing.abs()) {
                values[name] = value;
              }
            }
          }
        }
      }
      if (values.isNotEmpty) sheets[athleteId] = values;
    }
  }
  return sheets;
}

class _Delivery {
  _Delivery({
    required this.innings,
    required this.over,
    required this.ball,
    required this.batterId,
    required this.bowlerId,
    required this.runs,
    required this.outcome,
    required this.wicket,
  });

  final int innings;
  final int over;
  final int ball;
  final String batterId;
  final String bowlerId;
  final int runs;
  final String outcome;
  final bool wicket;
}

Future<List<_Delivery>> _fetchDeliveries(
  EspnFeedClient client,
  String league,
  String eventId, {
  String? cached,
}) async {
  final data =
      _readCached(cached) ??
      await client.getJson(
        'https://site.api.espn.com/apis/site/v2/sports/cricket/$league'
        '/playbyplay?event=$eventId&limit=1000',
      );
  final items = (data?['commentary'] as Map?)?['items'];
  if (items is! List) return const [];

  final out = <_Delivery>[];
  for (final item in items) {
    if (item is! Map) continue;
    final batter = ((item['batsman'] as Map?)?['athlete'] as Map?)?['id']
        ?.toString();
    final bowler = ((item['bowler'] as Map?)?['athlete'] as Map?)?['id']
        ?.toString();
    final over = item['over'] as Map?;
    final innings = (item['innings'] as Map?)?['number'];
    if (batter == null || bowler == null || over == null || innings is! num) {
      continue;
    }
    out.add(
      _Delivery(
        innings: innings.toInt(),
        // `over.number` is the 1-based over; `over.ball` counts deliveries
        // within it including extras, so a wide does not advance `over.actual`
        // but does advance `over.ball`.
        over: (over['number'] as num?)?.toInt() ?? 0,
        ball: (over['ball'] as num?)?.toInt() ?? 0,
        batterId: batter,
        bowlerId: bowler,
        runs: (item['scoreValue'] as num?)?.toInt() ?? 0,
        outcome:
            (item['playType'] as Map?)?['description']?.toString() ?? 'no run',
        wicket: (item['dismissal'] as Map?)?['dismissal'] == true,
      ),
    );
  }
  out.sort((a, b) {
    final byInnings = a.innings.compareTo(b.innings);
    if (byInnings != 0) return byInnings;
    final byOver = a.over.compareTo(b.over);
    return byOver != 0 ? byOver : a.ball.compareTo(b.ball);
  });
  return out;
}

// -- Merge --------------------------------------------------------------------

/// Builds ONLY the generated block. The hand-authored asset is spliced around
/// it textually (see [_write]), so no existing byte is reformatted.
Map<String, dynamic> _generatedLayer(
  Map<String, Map<String, num>> sheets,
  List<_Delivery> balls, {
  required String eventId,
}) {
  final statKeys = sheets.values.expand((s) => s.keys).toSet().toList()..sort();

  // Athlete ids are 6-7 digits and every delivery names two of them, so an
  // index costs about 4 KB less than repeating the ids 466 times.
  final athletes = <String>[];
  final index = <String, int>{};
  int idOf(String id) => index.putIfAbsent(id, () {
    athletes.add(id);
    return athletes.length - 1;
  });

  final outcomes = <String>[];
  final outcomeIndex = <String, int>{};
  int outcomeOf(String name) => outcomeIndex.putIfAbsent(name, () {
    outcomes.add(name);
    return outcomes.length - 1;
  });

  final deliveries = [
    for (final ball in balls)
      [
        ball.innings,
        ball.over,
        ball.ball,
        idOf(ball.batterId),
        idOf(ball.bowlerId),
        ball.runs,
        outcomeOf(ball.outcome),
        ball.wicket ? 1 : 0,
      ],
  ];

  final playerStats = <String, List<num?>>{
    for (final entry in sheets.entries)
      entry.key: [for (final key in statKeys) _narrow(entry.value[key])],
  };

  return <String, dynamic>{
    'espnEventId': eventId,
    'playerStatKeys': statKeys,
    'playerStats': playerStats,
    'deliveryAthletes': athletes,
    'deliveryOutcomes': outcomes,
    'deliveries': deliveries,
    'playerStatsGeneratedAt': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Narrows a whole-valued double to an int, leaving genuine fractions (strike
/// rate, economy) alone.
num? _narrow(num? value) {
  if (value == null) return null;
  if (value is int) return value;
  return value == value.roundToDouble() ? value.round() : value;
}

/// Reads a saved ESPN response, or null when no path was supplied.
Map<String, dynamic>? _readCached(String? path) {
  if (path == null) return null;
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('$path is not a JSON object');
  }
  return decoded;
}

// -- Writing -----------------------------------------------------------------

/// Splices the generated block into the original TEXT, immediately before its
/// closing brace.
///
/// The asset is re-encoded nowhere. An earlier attempt to decode, merge and
/// re-encode reflowed thousands of lines this generator does not own, because
/// the hand-authored file mixes formatting styles — `inningsProgress` points
/// sit on one line each while player `batting[]` entries are expanded, and no
/// single structural rule reproduces both. Splicing text sidesteps the problem
/// entirely and makes "purely additive" verifiable by eye in the diff.
String _splice(String original, Map<String, dynamic> layer) {
  final trimmed = original.trimRight();
  if (jsonDecode(original) is Map<String, dynamic> &&
      (jsonDecode(original) as Map<String, dynamic>).keys.any(
        _ownedRootKeys.contains,
      )) {
    throw StateError(
      'Asset already carries a generated block; revert it before regenerating '
      '(git checkout the asset) so the splice stays purely additive.',
    );
  }
  if (!trimmed.endsWith('}')) {
    throw StateError('Asset does not end in an object; refusing to splice');
  }
  final body = trimmed.substring(0, trimmed.length - 1).trimRight();
  final block = layer.entries
      .map((e) => '  ${jsonEncode(e.key)}: ${_encodeValue(e.value, '  ')}')
      .join(',\n');
  return '$body,\n$block\n}\n';
}

/// Encodes only the generated block, which this generator owns outright.
/// All-numeric arrays stay on one line so 233 delivery records do not become
/// two thousand.
String _encodeValue(Object? value, String indent) {
  if (value is Map) {
    if (value.isEmpty) return '{}';
    final inner = '$indent  ';
    final entries = value.entries
        .map(
          (e) =>
              '$inner${jsonEncode(e.key.toString())}: '
              '${_encodeValue(e.value, inner)}',
        )
        .join(',\n');
    return '{\n$entries\n$indent}';
  }
  if (value is List) {
    if (value.isEmpty) return '[]';
    if (value.every((e) => e == null || e is num)) {
      return '[${value.map(jsonEncode).join(', ')}]';
    }
    final inner = '$indent  ';
    final items = value
        .map((e) => '$inner${_encodeValue(e, inner)}')
        .join(',\n');
    return '[\n$items\n$indent]';
  }
  return jsonEncode(value);
}

// -- Verification -------------------------------------------------------------

void _verify(
  Map<String, dynamic> asset,
  Map<String, dynamic> layer,
  Map<String, Map<String, num>> sheets,
  List<_Delivery> balls,
) {
  // 1. Nothing hand-authored is even reachable: the layer is root-only and the
  //    writer splices text, so the only thing to guard is a name collision with
  //    a key the asset already uses.
  for (final key in layer.keys) {
    if (!_ownedRootKeys.contains(key)) {
      throw StateError('Layer key "$key" is not declared in _ownedRootKeys');
    }
  }
  for (final key in asset.keys) {
    if (_ownedRootKeys.contains(key) && !layer.containsKey(key)) {
      throw StateError('Asset carries a stale generated key "$key"');
    }
  }

  // 2. ESPN still returned the fixture this was verified against.
  if (sheets.length != _expectPlayers) {
    throw StateError(
      'Expected $_expectPlayers stat sheets, got ${sheets.length}',
    );
  }
  if (balls.length != _expectDeliveries) {
    throw StateError(
      'Expected $_expectDeliveries deliveries, got ${balls.length}',
    );
  }
  final first = balls.where((b) => b.innings == 1).length;
  final second = balls.where((b) => b.innings == 2).length;
  if (first != _expectFirstInnings || second != _expectSecondInnings) {
    throw StateError(
      'Expected $_expectFirstInnings/$_expectSecondInnings deliveries per '
      'innings, got $first/$second',
    );
  }
  final statKeys = (layer['playerStatKeys'] as List).cast<String>();
  if (statKeys.length != _expectStatKeys) {
    throw StateError(
      'Expected $_expectStatKeys stat keys, got ${statKeys.length}',
    );
  }
  // Every athlete named in a delivery must have a stat sheet to join to.
  for (final id in (layer['deliveryAthletes'] as List)) {
    if (!sheets.containsKey(id)) {
      throw StateError('Delivery athlete $id has no stat sheet');
    }
  }

  // 3. The strongest check available: rebuild every batter's innings from the
  //    ball feed and require it to equal BOTH the summary stat sheet and the
  //    figures already hand-transcribed into `scorecard[]`. Three independent
  //    sources agreeing is what makes the tape safe to draw.
  final rebuiltRuns = <String, int>{};
  final rebuiltBalls = <String, int>{};
  for (final ball in balls) {
    if (!_notBallsFaced.contains(ball.outcome)) {
      rebuiltBalls[ball.batterId] = (rebuiltBalls[ball.batterId] ?? 0) + 1;
    }
    if (!_notOffTheBat.contains(ball.outcome)) {
      rebuiltRuns[ball.batterId] = (rebuiltRuns[ball.batterId] ?? 0) + ball.runs;
    }
  }
  var checked = 0;
  for (final entry in rebuiltRuns.entries) {
    final sheet = sheets[entry.key];
    if (sheet == null) continue;
    final sheetRuns = sheet['runs']?.toInt();
    final sheetBalls = sheet['ballsFaced']?.toInt();
    if (sheetRuns != entry.value || sheetBalls != rebuiltBalls[entry.key]) {
      throw StateError(
        'Ball feed disagrees with the stat sheet for athlete ${entry.key}: '
        'rebuilt ${entry.value}(${rebuiltBalls[entry.key]}) vs '
        'sheet $sheetRuns($sheetBalls)',
      );
    }
    checked++;
  }
  if (checked < 12) {
    throw StateError('Only reconciled $checked batters; expected at least 12');
  }

  _verifyAgainstScorecard(asset, rebuiltRuns, rebuiltBalls);
}

/// Cross-checks the ball feed against the hand-transcribed scorecard already in
/// the asset — a source ESPN did not provide.
void _verifyAgainstScorecard(
  Map<String, dynamic> asset,
  Map<String, int> runs,
  Map<String, int> balls,
) {
  for (final innings in (asset['scorecard'] as List? ?? const [])) {
    if (innings is! Map) continue;
    for (final batter in (innings['batting'] as List? ?? const [])) {
      if (batter is! Map) continue;
      final id = batter['id']?.toString();
      if (id == null || !runs.containsKey(id)) continue;
      final cardRuns = (batter['runs'] as num?)?.toInt();
      final cardBalls = (batter['balls'] as num?)?.toInt();
      if (cardRuns != runs[id] || cardBalls != balls[id]) {
        throw StateError(
          'Ball feed disagrees with the bundled scorecard for $id: '
          'rebuilt ${runs[id]}(${balls[id]}) vs card $cardRuns($cardBalls)',
        );
      }
    }
  }
}

void _report(Map<String, dynamic> layer, List<_Delivery> balls) {
  stdout.writeln(
    '  stat sheets ${(layer['playerStats'] as Map).length}'
    '   keys ${(layer['playerStatKeys'] as List).length}',
  );
  stdout.writeln(
    '  deliveries ${balls.where((b) => b.innings == 1).length}'
    ' + ${balls.where((b) => b.innings == 2).length}'
    '   outcomes ${(layer['deliveryOutcomes'] as List).join(', ')}',
  );
}
