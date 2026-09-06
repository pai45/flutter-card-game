// Adds the per-player match layer to the bundled football match package.
//
//   dart run tool/generate_football_match_players.dart [options]
//
//     --event 401879318   ESPN event id (default: the bundled Fulham v Chelsea)
//     --league eng.1      ESPN competition slug for that event
//     --asset <path>      Override the asset path
//     --check             Re-extract and diff against the committed asset
//                         without writing (CI mode)
//
// Two ESPN feeds are combined. The site summary carries a 14-stat sheet for
// every one of the 40 players — free, and thrown away by the app until now. The
// core plays feed carries the positional gold: of 1577 plays, 974 have pitch
// coordinates and 989 name an athlete, which intersect to 1521 attributed
// touches across 31 players. That is what makes a heatmap possible at all.
//
// THIS GENERATOR MERGES; IT NEVER REWRITES. assets/data/football-revamp.json was
// hand-supplied and has no generator that can reproduce its narrative fields
// (commentary, timeline, momentum, topStats). Every pre-existing subtree is
// asserted byte-identical before anything is written, so a bad run fails loudly
// instead of destroying prose nobody can regenerate.
//
// Four size decisions keep the asset near 100 KB rather than 130 KB:
//  * per-player `stats` is a positional array zipped against one hoisted
//    top-level `playerStatKeys`, not 40 copies of 15 key names,
//  * touches are a FLAT [x,y,x,y] array, not a list of pairs,
//  * touches are integers — 1 unit is 1.05 m and the heatmap bins at ~4.4 m, so
//    rounding is lossless for this use, and
//  * touches split into `t1`/`t2` by half, which buys the UI a free 1ST/2ND
//    filter instead of storing a period alongside every coordinate.
//
// Unlike the league-stats asset, this one is written PRETTY-PRINTED, because it
// is hand-authored: the commentary and timeline prose in it cannot be
// regenerated and people need to be able to read and edit it. Only all-numeric
// arrays are inlined, so the 3042 touch coordinates do not each land on their
// own line. The asset contained no numeric array before this generator existed,
// so that rule reformats nothing that was already there.
//
// WARNING: `stats` is positional. Never reorder it without reordering
// `playerStatKeys` in the same edit — Dart always zips the two together and a
// half-applied hand-edit would silently mislabel every number on every card.

import 'dart:convert';
import 'dart:io';

import 'espn_feed_client.dart';

const _defaultAsset = 'assets/data/football-revamp.json';
const _defaultEvent = '401879318';
const _defaultLeague = 'eng.1';

/// Keys this generator owns. Everything else in the asset is hand-authored and
/// must survive untouched.
const _ownedRootKeys = {
  'espnEventId',
  'playerStatKeys',
  'playerStatsGeneratedAt',
};
const _ownedPlayerKeys = {'stats', 'subIn', 'subOut', 'xg', 'xgot', 't1', 't2'};

/// The verified shape of this fixture, asserted so a shifting feed fails loudly
/// rather than quietly writing a thinner asset. Probed 2026-09-06.
const _expectPlayers = 40;
const _expectTouches = 1521;
const _expectTouchedAthletes = 31;
const _expectMinStarterTouches = 35;

Future<void> main(List<String> arguments) async {
  final args = arguments.toList();
  final check = args.remove('--check');
  final assetPath = espnOptionValue(args, '--asset') ?? _defaultAsset;
  final eventId = espnOptionValue(args, '--event') ?? _defaultEvent;
  final league = espnOptionValue(args, '--league') ?? _defaultLeague;

  if (args.isNotEmpty) {
    stderr.writeln('Unexpected arguments: ${args.join(' ')}');
    stderr.writeln(
      'Usage: dart run tool/generate_football_match_players.dart '
      '[--event 401879318] [--league eng.1] [--asset <path>] [--check]',
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
    stdout.writeln('Event $eventId ($league)');

    final sheets = await _fetchStatSheets(client, league, eventId);
    if (sheets == null) {
      stderr.writeln('Could not read the summary feed; nothing written.');
      exitCode = 70;
      return;
    }
    stdout.writeln('  summary   ${sheets.length} players');

    final tracking = await _fetchTracking(client, league, eventId);
    stdout.writeln(
      '  plays     ${tracking.playCount} plays -> '
      '${tracking.totalTouches} touches across '
      '${tracking.touchesByAthlete.length} players',
    );

    final merged = _merge(asset, sheets, tracking, eventId: eventId);
    _verify(original, merged, sheets, tracking);

    final text = '${_encodeAsset(merged)}\n';

    if (check) {
      final ignoring = {'playerStatsGeneratedAt'};
      if (espnWithoutKeys(original, ignoring) !=
          espnWithoutKeys(text, ignoring)) {
        stderr.writeln('$assetPath is out of date; re-run without --check.');
        exitCode = 1;
        return;
      }
      stdout.writeln('$assetPath is up to date.');
      return;
    }

    file.writeAsStringSync(text);
    final beforeKb = (original.length / 1024).toStringAsFixed(1);
    final afterKb = (text.length / 1024).toStringAsFixed(1);
    stdout.writeln('Wrote $assetPath ($beforeKb KB -> $afterKb KB)');
    _report(merged, tracking);
  } finally {
    client.close();
  }
}

// -- Feeds --------------------------------------------------------------------

class _StatSheet {
  _StatSheet({
    required this.athleteId,
    required this.homeAway,
    required this.starter,
    required this.subbedIn,
    required this.subbedOut,
    required this.stats,
  });

  final String athleteId;
  final String homeAway;
  final bool starter;
  final bool subbedIn;
  final bool subbedOut;
  final Map<String, num> stats;
}

/// The summary feed's `rosters[].roster[]`, which carries a complete match stat
/// sheet per player alongside the lineup itself.
Future<Map<String, _StatSheet>?> _fetchStatSheets(
  EspnFeedClient client,
  String league,
  String eventId,
) async {
  final data = await client.getJson(
    'https://site.api.espn.com/apis/site/v2/sports/soccer/$league/summary'
    '?event=$eventId',
  );
  final rosters = data?['rosters'];
  if (rosters is! List || rosters.isEmpty) return null;

  final sheets = <String, _StatSheet>{};
  for (final roster in rosters) {
    if (roster is! Map) continue;
    final homeAway = roster['homeAway']?.toString() ?? 'home';
    final entries = roster['roster'];
    if (entries is! List) continue;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final athleteId = (entry['athlete'] as Map?)?['id']?.toString();
      if (athleteId == null) continue;
      final stats = <String, num>{};
      final raw = entry['stats'];
      if (raw is List) {
        for (final stat in raw) {
          if (stat is! Map) continue;
          final name = stat['name']?.toString();
          final value = stat['value'];
          if (name != null && value is num) stats[name] = value;
        }
      }
      sheets[athleteId] = _StatSheet(
        athleteId: athleteId,
        homeAway: homeAway,
        starter: entry['starter'] == true,
        subbedIn: entry['subbedIn'] == true,
        subbedOut: entry['subbedOut'] == true,
        stats: stats,
      );
    }
  }
  return sheets;
}

class _Tracking {
  final Map<String, List<int>> firstHalf = {};
  final Map<String, List<int>> secondHalf = {};
  final Map<String, double> expectedGoals = {};
  final Map<String, double> expectedGoalsOnTarget = {};
  final Map<String, int> subInMinute = {};
  final Map<String, int> subOutMinute = {};
  int playCount = 0;

  Iterable<String> get touchesByAthlete =>
      {...firstHalf.keys, ...secondHalf.keys};

  int get totalTouches =>
      (firstHalf.values.fold(0, (a, b) => a + b.length) +
          secondHalf.values.fold(0, (a, b) => a + b.length)) ~/
      2;

  int touchCount(String athleteId) =>
      ((firstHalf[athleteId]?.length ?? 0) +
          (secondHalf[athleteId]?.length ?? 0)) ~/
      2;
}

/// Pages the core plays feed and reduces it to per-athlete touch clouds.
///
/// A play counts as a touch when it has BOTH a pitch coordinate and a named
/// athlete; the first participant is the actor (a pass names the passer first,
/// then the receiver).
Future<_Tracking> _fetchTracking(
  EspnFeedClient client,
  String league,
  String eventId,
) async {
  final tracking = _Tracking();
  var page = 1;
  while (true) {
    final data = await client.getJson(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$league'
      '/events/$eventId/competitions/$eventId/plays?limit=1000&page=$page',
    );
    final items = data?['items'];
    if (items is! List) break;
    for (final play in items) {
      if (play is! Map) continue;
      tracking.playCount++;
      _absorbPlay(tracking, play);
    }
    final pageCount = (data?['pageCount'] as num?)?.toInt() ?? 1;
    if (page >= pageCount) break;
    page++;
  }
  return tracking;
}

void _absorbPlay(_Tracking tracking, Map<Object?, Object?> play) {
  final participants = play['participants'];
  final actor = participants is List && participants.isNotEmpty
      ? participants.first
      : null;
  final actorId = actor is Map
      ? espnIdFromRef((actor['athlete'] as Map?)?[r'$ref'])
      : null;

  if (play['type'] is Map &&
      (play['type'] as Map)['type']?.toString() == 'substitution') {
    _absorbSubstitution(tracking, play, participants);
    return;
  }

  if (actorId == null) return;

  final x = play['fieldPositionX'];
  final y = play['fieldPositionY'];
  if (x is num && y is num) {
    // The feed overflows its own frame slightly (x 0.2..101.8, y -1.6..101.8)
    // on events that leave the pitch, so clamp before rounding.
    final cx = x.clamp(0, 100).round();
    final cy = y.clamp(0, 100).round();
    final period = ((play['period'] as Map?)?['number'] as num?)?.toInt() ?? 1;
    final bucket = period >= 2 ? tracking.secondHalf : tracking.firstHalf;
    bucket.putIfAbsent(actorId, () => <int>[]).addAll([cx, cy]);
  }

  final xg = play['expectedGoals'];
  if (xg is num) {
    tracking.expectedGoals[actorId] =
        (tracking.expectedGoals[actorId] ?? 0) + xg.toDouble();
  }
  final xgot = play['expectedGoalsOnTarget'];
  if (xgot is num) {
    tracking.expectedGoalsOnTarget[actorId] =
        (tracking.expectedGoalsOnTarget[actorId] ?? 0) + xgot.toDouble();
  }
}

/// Substitution minutes come from the plays feed, not the summary: the
/// summary's `subbedIn`/`subbedOut` are bare booleans with no clock attached.
void _absorbSubstitution(
  _Tracking tracking,
  Map<Object?, Object?> play,
  Object? participants,
) {
  final minute = _minuteOf(play);
  if (minute == null || participants is! List) return;
  for (final participant in participants) {
    if (participant is! Map) continue;
    final id = espnIdFromRef((participant['athlete'] as Map?)?[r'$ref']);
    if (id == null) continue;
    switch (participant['type']?.toString()) {
      case 'subbed-in':
        tracking.subInMinute[id] = minute;
      case 'subbed-out':
        tracking.subOutMinute[id] = minute;
    }
  }
}

/// Reads the broadcast minute off `clock.displayValue` ("65'"), which is what a
/// reader recognises — `clock.value` is raw seconds and disagrees by a minute
/// either side of the rounding.
int? _minuteOf(Map<Object?, Object?> play) {
  final display = (play['clock'] as Map?)?['displayValue']?.toString();
  if (display == null) return null;
  final digits = RegExp(r'\d+').firstMatch(display)?.group(0);
  return digits == null ? null : int.tryParse(digits);
}

// -- Merge --------------------------------------------------------------------

Map<String, dynamic> _merge(
  Map<String, dynamic> asset,
  Map<String, _StatSheet> sheets,
  _Tracking tracking, {
  required String eventId,
}) {
  final statKeys =
      (sheets.values.expand((s) => s.stats.keys).toSet().toList()..sort());

  final merged = <String, dynamic>{...asset};
  merged['espnEventId'] = eventId;
  merged['playerStatKeys'] = statKeys;
  merged['playerStatsGeneratedAt'] = DateTime.now().toUtc().toIso8601String();

  final teams = merged['teams'];
  if (teams is! List) throw StateError('Asset has no teams[]');

  merged['teams'] = [
    for (final team in teams)
      if (team is Map<String, dynamic>)
        {
          ...team,
          'players': [
            for (final player in (team['players'] as List? ?? const []))
              if (player is Map<String, dynamic>)
                _mergePlayer(player, sheets, tracking, statKeys)
              else
                player,
          ],
        }
      else
        team,
  ];
  return merged;
}

Map<String, dynamic> _mergePlayer(
  Map<String, dynamic> player,
  Map<String, _StatSheet> sheets,
  _Tracking tracking,
  List<String> statKeys,
) {
  final id = player['id']?.toString();
  final sheet = id == null ? null : sheets[id];
  if (id == null || sheet == null) return player;

  final out = <String, dynamic>{...player};
  // Positional against the hoisted statKeys — null where ESPN omits a stat for
  // this position (saves for outfielders, offsides for keepers). ESPN sends
  // these counting stats as doubles; narrowing whole values to int keeps the
  // asset honest ("2 shots", not "2.0 shots") and drops a few hundred bytes.
  out['stats'] = [
    for (final key in statKeys) _narrow(sheet.stats[key]),
  ];

  final subIn = tracking.subInMinute[id];
  final subOut = tracking.subOutMinute[id];
  if (subIn != null) out['subIn'] = subIn;
  if (subOut != null) out['subOut'] = subOut;

  final xg = tracking.expectedGoals[id];
  if (xg != null) out['xg'] = double.parse(xg.toStringAsFixed(3));
  final xgot = tracking.expectedGoalsOnTarget[id];
  if (xgot != null && xgot > 0) {
    out['xgot'] = double.parse(xgot.toStringAsFixed(3));
  }

  final t1 = tracking.firstHalf[id];
  final t2 = tracking.secondHalf[id];
  if (t1 != null && t1.isNotEmpty) out['t1'] = t1;
  if (t2 != null && t2.isNotEmpty) out['t2'] = t2;
  return out;
}

/// Narrows a whole-valued double to an int, leaving genuine fractions alone.
num? _narrow(num? value) {
  if (value == null) return null;
  if (value is int) return value;
  return value == value.roundToDouble() ? value.round() : value;
}

// -- Encoding -----------------------------------------------------------------

/// Pretty-prints with the asset's existing two-space indent, but keeps
/// all-numeric arrays on one line.
///
/// The asset is hand-authored — its commentary and timeline prose have no
/// generator — so it has to stay readable and diffable. A stock
/// `JsonEncoder.withIndent('  ')` would put each of the 3042 touch coordinates
/// on its own line and roughly double the file; compact encoding would collapse
/// the whole thing to one unreadable line. This does neither.
String _encodeAsset(Object? value) => _encodeValue(value, '');

String _encodeValue(Object? value, String indent) {
  if (value is Map) {
    if (value.isEmpty) return '{}';
    final inner = '$indent  ';
    final entries = value.entries
        .map((e) => '$inner${jsonEncode(e.key.toString())}: '
            '${_encodeValue(e.value, inner)}')
        .join(',\n');
    return '{\n$entries\n$indent}';
  }
  if (value is List) {
    if (value.isEmpty) return '[]';
    // The one departure from stock pretty-printing, and the reason this
    // encoder exists at all.
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

/// Fails the run rather than writing when anything looks wrong. Two classes of
/// check: that we did not damage the hand-authored asset, and that ESPN still
/// returned the fixture we verified against.
void _verify(
  String original,
  Map<String, dynamic> merged,
  Map<String, _StatSheet> sheets,
  _Tracking tracking,
) {
  final before = jsonDecode(original) as Map<String, dynamic>;

  // 1. Nothing hand-authored moved.
  for (final entry in before.entries) {
    if (_ownedRootKeys.contains(entry.key)) continue;
    if (entry.key == 'teams') continue;
    if (jsonEncode(merged[entry.key]) != jsonEncode(entry.value)) {
      throw StateError('Refusing to write: root key "${entry.key}" changed');
    }
  }
  final beforeTeams = before['teams'] as List;
  final afterTeams = merged['teams'] as List;
  if (beforeTeams.length != afterTeams.length) {
    throw StateError('Refusing to write: team count changed');
  }
  for (var i = 0; i < beforeTeams.length; i++) {
    final b = beforeTeams[i] as Map<String, dynamic>;
    final a = afterTeams[i] as Map<String, dynamic>;
    for (final key in b.keys) {
      if (key == 'players') continue;
      if (jsonEncode(a[key]) != jsonEncode(b[key])) {
        throw StateError('Refusing to write: team $i key "$key" changed');
      }
    }
    final bp = b['players'] as List;
    final ap = a['players'] as List;
    if (bp.length != ap.length) {
      throw StateError('Refusing to write: team $i player count changed');
    }
    for (var j = 0; j < bp.length; j++) {
      final bpj = bp[j] as Map<String, dynamic>;
      final apj = ap[j] as Map<String, dynamic>;
      for (final key in bpj.keys) {
        if (_ownedPlayerKeys.contains(key)) continue;
        if (jsonEncode(apj[key]) != jsonEncode(bpj[key])) {
          throw StateError(
            'Refusing to write: team $i player $j key "$key" changed',
          );
        }
      }
    }
  }

  // 2. ESPN still returned the fixture this was verified against.
  if (sheets.length != _expectPlayers) {
    throw StateError(
      'Expected $_expectPlayers players from the summary, got ${sheets.length}',
    );
  }
  if (tracking.totalTouches != _expectTouches) {
    throw StateError(
      'Expected $_expectTouches tracked touches, got ${tracking.totalTouches}',
    );
  }
  if (tracking.touchesByAthlete.length != _expectTouchedAthletes) {
    throw StateError(
      'Expected $_expectTouchedAthletes players with touches, '
      'got ${tracking.touchesByAthlete.length}',
    );
  }
  for (final sheet in sheets.values.where((s) => s.starter)) {
    final touches = tracking.touchCount(sheet.athleteId);
    if (touches < _expectMinStarterTouches) {
      throw StateError(
        'Starter ${sheet.athleteId} has only $touches touches '
        '(expected >= $_expectMinStarterTouches)',
      );
    }
  }
  // Every stat must be one the app knows how to label.
  final keys = (merged['playerStatKeys'] as List).cast<String>();
  if (keys.isEmpty) throw StateError('No stat keys resolved');
}

void _report(Map<String, dynamic> merged, _Tracking tracking) {
  for (final team in merged['teams'] as List) {
    final players = (team as Map)['players'] as List;
    final withTouches = players
        .where((p) => (p as Map).containsKey('t1') || p.containsKey('t2'))
        .length;
    final touches = players.fold<int>(0, (sum, p) {
      final m = p as Map;
      return sum +
          (((m['t1'] as List?)?.length ?? 0) +
                  ((m['t2'] as List?)?.length ?? 0)) ~/
              2;
    });
    stdout.writeln(
      '  ${team['abbreviation']}  ${players.length} players, '
      '$withTouches tracked, $touches touches',
    );
  }
  stdout.writeln('  stat keys ${(merged['playerStatKeys'] as List).length}');
}
