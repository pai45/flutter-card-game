import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config/theme.dart';
import '../models/league_stat_leaders.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';

/// Reads the bundled NBA league package into the league hub's models.
///
/// Unlike cricket, basketball is a sport ESPN serves fully: standings, a season
/// leaders feed and per-team season statistics all answer, so
/// `tool/generate_nba_league_stats.dart` is a straight extraction rather than a
/// re-derivation from match summaries. What the package buys is the same thing
/// it buys football — an instant first paint, and a hub that works on web,
/// where live ESPN is CORS-blocked.
///
/// See `docs/data/nba-league-stats-field-inventory.md`.
class NbaLeagueStatsPackageService {
  const NbaLeagueStatsPackageService();

  static const assetPath = 'assets/data/nba-league-stats.json';

  /// The NBA's playoff structure, which the feed states only as a seed number.
  /// Seeds 1-6 go straight to the playoffs, 7-10 play the play-in.
  static const _playoffSeeds = 6;
  static const _playInSeeds = 10;

  static Future<Map<String, dynamic>>? _pending;

  static Future<Map<String, dynamic>> _load() =>
      _pending ??= rootBundle.loadString(assetPath).then((raw) {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      });

  @visibleForTesting
  static void clearCache() => _pending = null;

  /// Whether this league is one the NBA package covers.
  static Future<bool> supports(
    String leagueId, {
    String? leagueName,
    String? shortCode,
  }) async =>
      (await snapshotFor(
        leagueId,
        leagueName: leagueName,
        shortCode: shortCode,
      )) !=
      null;

  /// Resolves by **alias**, never a single id — the same competition arrives as
  /// the repository's `nba`, ESPN's numeric `46`, or a display name, exactly
  /// like the colliding football league ids.
  static Future<LeagueStatsSnapshot?> snapshotFor(
    String leagueId, {
    String? leagueName,
    String? shortCode,
  }) async {
    try {
      final root = await _load();
      final leagues = root['leagues'];
      if (leagues is! List) return null;

      final wanted = <String?>{
        _normalise(leagueId),
        _normalise(leagueName),
        _normalise(shortCode),
      }..removeWhere((value) => value == null);
      if (wanted.isEmpty) return null;

      for (final league in leagues) {
        if (league is! Map<String, dynamic>) continue;
        final aliases = <String?>{
          _normalise(league['id']?.toString()),
          _normalise(league['espnId']?.toString()),
          _normalise(league['name']?.toString()),
          _normalise(league['abbreviation']?.toString()),
          for (final alias in (league['aliases'] as List? ?? const []))
            _normalise(alias.toString()),
        };
        if (aliases.intersection(wanted).isEmpty) continue;
        return _decode(league, _definitions(root));
      }
      return null;
    } catch (error) {
      debugPrint('NbaLeagueStatsPackageService: $error');
      return null;
    }
  }

  /// ESPN publishes real prose for every basketball stat, so the dictionary is
  /// shipped in the asset rather than written here — the opposite of cricket,
  /// where no descriptions exist and the copy had to be ours.
  static Map<String, LeagueStatDefinition> _definitions(
    Map<String, dynamic> root,
  ) {
    final raw = root['statDictionary'];
    if (raw is! Map) return const {};
    final out = <String, LeagueStatDefinition>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final name = entry.key.toString();
      out[name] = LeagueStatDefinition(
        name: name,
        category: value['category']?.toString() ?? 'general',
        displayName: value['displayName']?.toString() ?? name,
        shortDisplayName: value['shortDisplayName']?.toString(),
        abbreviation: value['abbreviation']?.toString(),
        description: value['description']?.toString(),
      );
    }
    return out;
  }

  static LeagueStatsSnapshot _decode(
    Map<String, dynamic> league,
    Map<String, LeagueStatDefinition> definitions,
  ) {
    final teams = <String, SportTeam>{};
    // ESPN's nickname ("Cavaliers" for "Cleveland Cavaliers"), which is what a
    // standings row has room for once the crest and six numeric columns are
    // placed.
    final tableNames = <String, String>{};
    for (final entry in (league['teams'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final id = entry['id']?.toString();
      if (id == null) continue;
      final name = entry['displayName']?.toString() ?? '';
      final code = entry['abbreviation']?.toString();
      final short = entry['shortDisplayName']?.toString();
      if (short != null && short.isNotEmpty) tableNames[id] = short;
      teams[id] = SportTeam(
        id: id,
        name: name,
        shortName: code == null || code.isEmpty ? _initials(name) : code,
        color: Cyber.cyan,
        crestAsset: entry['logo']?.toString(),
      );
    }

    return LeagueStatsSnapshot(
      groups: _standings(league, teams, tableNames),
      categories: _leaders(league, teams),
      teamStats: _teamStats(league, teams),
      statDefinitions: definitions,
      seasonLabel: league['season']?.toString(),
      seasonYear: _int(league['seasonYear']),
    );
  }

  static List<StandingsGroup> _standings(
    Map<String, dynamic> league,
    Map<String, SportTeam> teams,
    Map<String, String> tableNames,
  ) {
    final groups = <StandingsGroup>[];
    for (final conference in (league['conferences'] as List? ?? const [])) {
      if (conference is! Map) continue;
      final rows = <TeamStanding>[];
      for (final entry in (conference['rows'] as List? ?? const [])) {
        if (entry is! Map) continue;
        final teamId = entry['teamId']?.toString();
        final team = teams[teamId];
        if (team == null) continue;
        // The generator writes `rank` as the regular-season table position.
        // ESPN's own `playoffSeed` is the post-play-in seed and disagrees.
        final seed = _int(entry['rank']) ?? 0;
        final wins = _int(entry['wins']) ?? 0;
        final losses = _int(entry['losses']) ?? 0;
        final zone = _zoneFor(seed);
        rows.add(
          TeamStanding(
            team: team,
            rank: seed,
            // The NBA does not publish a games-played column, and it is not
            // one: 82 minus postponements is exactly W+L.
            played: wins + losses,
            won: wins,
            lost: losses,
            // Wins are the standings currency here — there is no points
            // system to convert them into.
            points: wins,
            // Games behind, as the feed formatted it: the leader's is "-",
            // and half-games are real ("4.5").
            diffLabel: _gamesBehind(entry),
            // No per-game W/L sequence is published for the NBA, so there is
            // nothing to draw form pips from; `lastTen` carries the same
            // reading as its own column instead.
            form: '',
            // Basketball has no draws. `winPercent` being non-null is what
            // tells StandingsTable this is a basketball table and not a
            // cricket one, which is also drawless.
            drawn: null,
            winPercent: _double(entry['winPercent']),
            streak: entry['streak.display']?.toString(),
            lastTen: entry['record.lasttengames']?.toString(),
            tableName: tableNames[teamId],
            zoneNote: zone?.$1,
            zoneColor: zone?.$2,
          ),
        );
      }
      if (rows.isEmpty) continue;
      rows.sort((a, b) => a.rank.compareTo(b.rank));
      groups.add(
        StandingsGroup(
          label: conference['label']?.toString() ?? '',
          rows: rows,
        ),
      );
    }
    return groups;
  }

  /// The two cut lines every NBA table is read against. ESPN states only the
  /// seed, so the 6/10 split — the league's published structure — is applied
  /// here rather than invented per row.
  static (String, Color)? _zoneFor(int seed) {
    if (seed <= 0) return null;
    if (seed <= _playoffSeeds) return ('Playoffs', Cyber.success);
    if (seed <= _playInSeeds) return ('Play-In', Cyber.amber);
    return null;
  }

  static String _gamesBehind(Map<dynamic, dynamic> entry) {
    final display = entry['gamesBehind.display']?.toString().trim();
    // ESPN writes the leader's gap as "-", which reads as a missing value on a
    // HUD table; an em dash reads as "none".
    if (display == null || display.isEmpty || display == '-') return '—';
    return display;
  }

  static List<StatLeaderCategory> _leaders(
    Map<String, dynamic> league,
    Map<String, SportTeam> teams,
  ) {
    final athletes = league['athletes'];
    final byId = athletes is Map ? athletes : const {};

    final categories = <StatLeaderCategory>[];
    for (final board in (league['leaders'] as List? ?? const [])) {
      if (board is! Map) continue;
      final key = board['key']?.toString() ?? '';
      final leaders = <StatLeader>[];
      for (final row in (board['leaders'] as List? ?? const [])) {
        if (row is! Map) continue;
        final athleteId = row['athleteId']?.toString();
        if (athleteId == null) continue;
        final athlete = byId[athleteId];
        final raw = _double(row['value']) ?? 0;
        // Basketball quotes its rates to one decimal; the asset keeps ESPN's
        // full precision so the ranking is exact.
        final value = _isCount(key) ? raw : (raw * 10).roundToDouble() / 10;
        final display = _isCount(key)
            ? value.round().toString()
            : value.toStringAsFixed(1);
        leaders.add(
          StatLeader(
            athleteId: athleteId,
            value: value,
            // Same string the board already prints, so the leader plate does
            // not repeat itself on a detail line.
            displayValue: display,
            name: athlete is Map ? athlete['name']?.toString() : null,
            teamId: row['teamId']?.toString(),
            team: teams[row['teamId']?.toString()],
            position: athlete is Map ? athlete['role']?.toString() : null,
          ),
        );
      }
      if (leaders.isEmpty) continue;
      categories.add(
        StatLeaderCategory(
          key: key,
          label: _boardLabel(key),
          // The qualifier belongs in the headline: "FREE THROW %" without
          // "125+ MADE" invites the reader to wonder why a 6-for-6 night is
          // not top of the league.
          unitLabel: board['qualifier'] == null
              ? (board['unit']?.toString() ?? '')
              : '${board['unit']} // ${board['qualifier']}',
          accent: _accentFor(key),
          leaders: leaders,
        ),
      );
    }
    return categories;
  }

  static List<TeamSeasonStats> _teamStats(
    Map<String, dynamic> league,
    Map<String, SportTeam> teams,
  ) {
    final raw = league['teamStats'];
    if (raw is! Map) return const [];
    final out = <TeamSeasonStats>[];
    for (final entry in raw.entries) {
      final team = teams[entry.key.toString()];
      final values = entry.value;
      if (team == null || values is! Map) continue;
      out.add(
        TeamSeasonStats(
          team: team,
          values: {
            for (final stat in values.entries)
              if (_double(stat.value) case final value?)
                stat.key.toString(): TeamStatValue(
                  value: value,
                  display: _display(value),
                ),
          },
        ),
      );
    }
    return out;
  }

  /// Boards whose value is a whole count rather than a rate.
  static bool _isCount(String key) => key == 'doubleDouble';

  /// Board tab copy. The generator ships stable ESPN keys; the wording lives
  /// here so it can be tuned without regenerating a 130 KB asset.
  static String _boardLabel(String key) => switch (key) {
    'pointsPerGame' => 'POINTS',
    'reboundsPerGame' => 'REBOUNDS',
    'assistsPerGame' => 'ASSISTS',
    '3PointsMadePerGame' => 'THREES',
    'stealsPerGame' => 'STEALS',
    'blocksPerGame' => 'BLOCKS',
    'doubleDouble' => 'DOUBLE-DOUBLES',
    'PER' => 'PER',
    'fieldGoalPercentage' => 'FG%',
    '3PointPct' => '3P%',
    'FreeThrowPct' => 'FT%',
    'avgTurnovers' => 'TURNOVERS',
    _ => key.toUpperCase(),
  };

  /// Colour discipline: the defensive boards read as success, the volume
  /// achievements as amber, and giving the ball away as danger — the same
  /// semantics football's saves and cards boards use.
  static StatAccent _accentFor(String key) => switch (key) {
    'stealsPerGame' || 'blocksPerGame' => StatAccent.success,
    'doubleDouble' || 'PER' => StatAccent.amber,
    'avgTurnovers' => StatAccent.danger,
    _ => StatAccent.league,
  };

  static String _display(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 3))
          .toUpperCase();
    }
    return parts.take(3).map((p) => p.substring(0, 1)).join().toUpperCase();
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _normalise(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}
