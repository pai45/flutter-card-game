import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config/theme.dart';
import '../models/league_stat_leaders.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';

/// Reads the bundled IPL league package into the league hub's models.
///
/// Cricket cannot use the live path football uses. ESPN's core API rejects the
/// sport outright (`Invalid sport/league combination (cricket/8048)`), so there
/// is **no season leaders feed and no per-team statistics feed**. Everything
/// except standings is aggregated offline from every match summary of the
/// season by `tool/generate_cricket_league_stats.dart` — see
/// `docs/data/ipl-match-player-field-inventory.md`.
///
/// That makes the package the only source, not a first-render optimisation:
/// there is nothing to layer over it later.
class CricketLeagueStatsPackageService {
  const CricketLeagueStatsPackageService();

  static const assetPath = 'assets/data/cricket-league-stats.json';

  static Future<Map<String, dynamic>>? _pending;

  static Future<Map<String, dynamic>> _load() =>
      _pending ??= rootBundle.loadString(assetPath).then((raw) {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
      });

  @visibleForTesting
  static void clearCache() => _pending = null;

  /// Whether this league is one the cricket package covers.
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
  /// the repository's `ipl`, ESPN's numeric `8048`, or a display name, exactly
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
          _normalise(league['name']?.toString()),
          _normalise(league['abbreviation']?.toString()),
          for (final alias in (league['aliases'] as List? ?? const []))
            _normalise(alias.toString()),
        };
        if (aliases.intersection(wanted).isEmpty) continue;
        return _decode(league);
      }
      return null;
    } catch (error) {
      debugPrint('CricketLeagueStatsPackageService: $error');
      return null;
    }
  }

  static LeagueStatsSnapshot _decode(Map<String, dynamic> league) {
    final teams = <String, SportTeam>{};
    for (final entry in (league['teams'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final id = entry['id']?.toString();
      if (id == null) continue;
      final name = entry['displayName']?.toString() ?? '';
      final code = entry['abbreviation']?.toString();
      teams[id] = SportTeam(
        id: id,
        name: name,
        shortName: code == null || code.isEmpty ? _initials(name) : code,
        color: Cyber.cyan,
        crestAsset: entry['logo']?.toString(),
      );
    }

    return LeagueStatsSnapshot(
      groups: _standings(league, teams),
      categories: _leaders(league, teams),
      teamStats: _teamStats(league, teams),
      statDefinitions: _definitions,
      seasonLabel: league['season']?.toString(),
    );
  }

  static List<StandingsGroup> _standings(
    Map<String, dynamic> league,
    Map<String, SportTeam> teams,
  ) {
    final rows = <TeamStanding>[];
    for (final entry in (league['standings'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final team = teams[entry['teamId']?.toString()];
      if (team == null) continue;
      final netRunRate = _num(entry['netrr']);
      rows.add(
        TeamStanding(
          team: team,
          rank: _int(entry['rank']),
          played: _int(entry['matchesPlayed']),
          won: _int(entry['matchesWon']),
          lost: _int(entry['matchesLost']),
          points: _int(entry['matchPoints']),
          // Cricket's differential is net run rate, and it reads with a sign.
          diffLabel: netRunRate == null
              ? '—'
              : '${netRunRate >= 0 ? '+' : ''}${netRunRate.toStringAsFixed(3)}',
          form: '',
          // Deliberately null. `StandingsTable` treats a null `drawn` as the
          // signal to render its cricket layout — P/W/L/NRR — instead of
          // football's P/W/D/L/GD, and cricket has no drawn column to show:
          // a no-result is not a draw, and it was 0 for every side this season.
          drawn: null,
          // ESPN sends the qualification flag as the numeric 1 on the four
          // playoff teams and omits it elsewhere; the string 'Y' only appears
          // in its displayValue.
          zoneNote: _qualified(entry['qualified']) ? 'Playoffs' : null,
          zoneColor: _qualified(entry['qualified']) ? Cyber.success : null,
        ),
      );
    }
    rows.sort((a, b) => a.rank.compareTo(b.rank));
    return rows.isEmpty ? const [] : [StandingsGroup(label: '', rows: rows)];
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
      final lowerIsBetter = board['lowerIsBetter'] == true;
      final leaders = <StatLeader>[];
      for (final row in (board['leaders'] as List? ?? const [])) {
        if (row is! Map) continue;
        final athleteId = row['athleteId']?.toString();
        if (athleteId == null) continue;
        final athlete = byId[athleteId];
        final value = _num(row['value']) ?? 0;
        leaders.add(
          StatLeader(
            athleteId: athleteId,
            value: value.toDouble(),
            displayValue: _display(value),
            name: athlete is Map ? athlete['name']?.toString() : null,
            teamId: row['teamId']?.toString(),
            team: teams[row['teamId']?.toString()],
            position: _role(athlete),
          ),
        );
      }
      if (leaders.isEmpty) continue;
      categories.add(
        StatLeaderCategory(
          key: key,
          label: _boardLabel(key),
          // The qualifier belongs in the headline: "BEST ECONOMY" without
          // "120+ balls bowled" invites the reader to wonder why a one-over
          // cameo is not top.
          unitLabel: board['qualifier'] == null
              ? (board['unit']?.toString() ?? '')
              : '${board['unit']} // ${board['qualifier']}',
          accent: _accentFor(key, lowerIsBetter: lowerIsBetter),
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
              if (_num(stat.value) != null)
                stat.key.toString(): TeamStatValue(
                  value: _num(stat.value)!.toDouble(),
                  display: _display(_num(stat.value)!),
                ),
          },
        ),
      );
    }
    return out;
  }

  /// Board headline copy. The generator ships stable keys; the wording lives
  /// here so it can be tuned without regenerating a 63 KB asset.
  static String _boardLabel(String key) => switch (key) {
    'runs' => 'RUNS',
    'wickets' => 'WICKETS',
    'sixes' => 'SIXES',
    'fours' => 'FOURS',
    'fiftyPlus' => 'FIFTIES',
    'dots' => 'DOT BALLS',
    'caught' => 'CATCHES',
    'strikeRate' => 'STRIKE RATE',
    'economyRate' => 'ECONOMY',
    _ => key.toUpperCase(),
  };

  static StatAccent _accentFor(String key, {required bool lowerIsBetter}) {
    if (lowerIsBetter) return StatAccent.success;
    return switch (key) {
      'wickets' || 'dots' => StatAccent.success,
      'sixes' || 'fiftyPlus' => StatAccent.amber,
      _ => StatAccent.league,
    };
  }

  /// Stat metadata for the STATS tab boards, written here rather than shipped
  /// in the asset — ESPN publishes no descriptions for cricket, so the prose is
  /// ours either way.
  static const _definitions = <String, LeagueStatDefinition>{
    'runs': LeagueStatDefinition(
      name: 'runs',
      category: 'batting',
      displayName: 'Runs Scored',
      abbreviation: 'R',
      description: 'Total runs scored by this team across the season.',
    ),
    'sixes': LeagueStatDefinition(
      name: 'sixes',
      category: 'batting',
      displayName: 'Sixes',
      abbreviation: '6s',
      description: 'Balls hit for six across the season.',
    ),
    'fours': LeagueStatDefinition(
      name: 'fours',
      category: 'batting',
      displayName: 'Fours',
      abbreviation: '4s',
      description: 'Balls hit for four across the season.',
    ),
    'fiftyPlus': LeagueStatDefinition(
      name: 'fiftyPlus',
      category: 'batting',
      displayName: 'Fifties',
      abbreviation: '50s',
      description: 'Individual scores of fifty or more.',
    ),
    'wickets': LeagueStatDefinition(
      name: 'wickets',
      category: 'bowling',
      displayName: 'Wickets Taken',
      abbreviation: 'W',
      description: 'Wickets taken by this team\'s bowlers.',
    ),
    'dots': LeagueStatDefinition(
      name: 'dots',
      category: 'bowling',
      displayName: 'Dot Balls',
      abbreviation: 'DOT',
      description: 'Deliveries bowled from which no run was scored.',
    ),
    'maidens': LeagueStatDefinition(
      name: 'maidens',
      category: 'bowling',
      displayName: 'Maiden Overs',
      abbreviation: 'M',
      description: 'Complete overs bowled without conceding a run.',
    ),
    'conceded': LeagueStatDefinition(
      name: 'conceded',
      category: 'bowling',
      displayName: 'Runs Conceded',
      abbreviation: 'RC',
      description: 'Runs given away by this team\'s bowlers.',
    ),
    'wides': LeagueStatDefinition(
      name: 'wides',
      category: 'bowling',
      displayName: 'Wides',
      abbreviation: 'WD',
      description: 'Wide deliveries bowled across the season.',
    ),
    'noballs': LeagueStatDefinition(
      name: 'noballs',
      category: 'bowling',
      displayName: 'No Balls',
      abbreviation: 'NB',
      description: 'No balls bowled across the season.',
    ),
    'caught': LeagueStatDefinition(
      name: 'caught',
      category: 'fielding',
      displayName: 'Catches',
      abbreviation: 'CT',
      description: 'Catches taken in the field.',
    ),
    'stumped': LeagueStatDefinition(
      name: 'stumped',
      category: 'fielding',
      displayName: 'Stumpings',
      abbreviation: 'ST',
      description: 'Batters stumped by the wicketkeeper.',
    ),
  };

  /// ESPN's cricket position taxonomy has no "Batter", so a specialist batter
  /// comes back as the literal string "Unknown" — 23 of the 81 ranked players
  /// here. Showing that under a leader's name is worse than showing nothing, so
  /// it degrades to the team alone.
  static String? _role(Object? athlete) {
    if (athlete is! Map) return null;
    final raw = athlete['role']?.toString().trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'unknown') {
      return null;
    }
    return raw;
  }

  static String _display(num value) => value is int || value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 3)).toUpperCase();
    }
    return parts.take(3).map((p) => p.substring(0, 1)).join().toUpperCase();
  }

  static bool _qualified(Object? value) {
    if (value is num) return value > 0;
    final raw = value?.toString().toUpperCase();
    return raw == 'Y' || raw == '1' || raw == 'TRUE';
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static num? _num(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static String? _normalise(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}
