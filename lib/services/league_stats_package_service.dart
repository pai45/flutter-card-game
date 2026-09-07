import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/team_colors.dart';
import '../models/league_stat_leaders.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';

/// Decodes the bundled league-stats package
/// (`assets/data/football-league-stats.json`, built by
/// `tool/generate_league_stats.dart`) into the same models the live ESPN
/// service produces, plus the per-team season statistics only the package has.
///
/// This is what makes the league hub fill instantly and work offline: the
/// package is read once at startup cost of a single asset load, and the live
/// feed is layered over it afterwards rather than being the thing the player
/// waits on.
///
/// Leagues are looked up by **alias**, never by a single id. The same
/// competition reaches this class as `eng.1` (curated repository league),
/// `epl` (follow list), `700` (ESPN scoreboard) or `23` (ESPN standings), so
/// the package records every spelling and matching is normalised.
class LeagueStatsPackageService {
  const LeagueStatsPackageService();

  static const assetPath = 'assets/data/football-league-stats.json';
  static const seasonsAssetPath = 'assets/data/football-league-seasons.json';

  /// Decoded once per app run and shared by every hub route.
  static Future<Map<String, LeagueStatsSnapshot>>? _pending;
  static Future<Map<String, List<LeagueSeasonOption>>>? _seasonsPending;

  @visibleForTesting
  static void clearCache() {
    _pending = null;
    _seasonsPending = null;
  }

  /// Every league in the package, keyed by each of its normalised aliases.
  static Future<Map<String, LeagueStatsSnapshot>> _load() {
    return _pending ??= _decodeAsset();
  }

  /// Lightweight offline season catalogue. Historical snapshots still come
  /// from ESPN; this keeps the selector useful when the live catalogue cannot
  /// be reached (notably in browser builds blocked by CORS).
  static Future<List<LeagueSeasonOption>> seasonsFor(
    String leagueId, {
    String? leagueName,
    String? shortCode,
  }) async {
    final byAlias = await (_seasonsPending ??= _decodeSeasonsAsset());
    for (final candidate in [leagueId, shortCode, leagueName]) {
      final key = _normalise(candidate);
      if (key == null) continue;
      final seasons = byAlias[key];
      if (seasons != null) return seasons;
    }
    return const [];
  }

  static Future<Map<String, List<LeagueSeasonOption>>>
  _decodeSeasonsAsset() async {
    try {
      final source = await rootBundle.loadString(seasonsAssetPath);
      final root = jsonDecode(source) as Map<String, dynamic>;
      final byAlias = <String, List<LeagueSeasonOption>>{};
      for (final raw in root['leagues'] as List? ?? const []) {
        if (raw is! Map) continue;
        final years = [
          for (final year in raw['seasons'] as List? ?? const [])
            if (year is num) year.toInt(),
        ];
        final seasons = List<LeagueSeasonOption>.unmodifiable([
          for (var index = 0; index < years.length; index++)
            LeagueSeasonOption(
              year: years[index],
              label: _seasonLabel(years[index]),
              isCurrent: index == 0,
            ),
        ]);
        for (final alias in raw['aliases'] as List? ?? const []) {
          final key = _normalise(alias.toString());
          if (key != null) byAlias[key] = seasons;
        }
      }
      return byAlias;
    } catch (e) {
      debugPrint(
        'LeagueStatsPackageService: could not load $seasonsAssetPath: $e',
      );
      return const {};
    }
  }

  static String _seasonLabel(int year) =>
      '$year-${((year + 1) % 100).toString().padLeft(2, '0')}';

  static Future<Map<String, LeagueStatsSnapshot>> _decodeAsset() async {
    try {
      final source = await rootBundle.loadString(assetPath);
      return const LeagueStatsPackageService().decode(source);
    } catch (e) {
      debugPrint('LeagueStatsPackageService: could not load $assetPath: $e');
      return const {};
    }
  }

  /// The bundled snapshot for [leagueId], or null when the package doesn't
  /// cover that competition. [leagueName] and [shortCode] are consulted too,
  /// so a league discovered at runtime under an unexpected id still resolves.
  static Future<LeagueStatsSnapshot?> snapshotFor(
    String leagueId, {
    String? leagueName,
    String? shortCode,
    int? seasonYear,
  }) async {
    final byAlias = await _load();
    if (byAlias.isEmpty) return null;
    for (final candidate in [leagueId, shortCode, leagueName]) {
      final key = _normalise(candidate);
      if (key == null) continue;
      final hit = byAlias[key];
      if (hit != null && (seasonYear == null || hit.seasonYear == seasonYear)) {
        return hit;
      }
    }
    return null;
  }

  /// Lowercased and stripped of punctuation/spacing, so `La Liga`, `LALIGA`
  /// and `laliga` all collapse to one key.
  static String? _normalise(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  @visibleForTesting
  Map<String, LeagueStatsSnapshot> decode(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, dynamic>) {
      throw const FormatException(
        'League stats package root must be an object.',
      );
    }

    final definitions = <String, LeagueStatDefinition>{};
    final rawDefinitions = root['statDictionary'];
    if (rawDefinitions is Map) {
      rawDefinitions.forEach((key, value) {
        if (value is! Map) return;
        final name = key.toString();
        definitions[name] = LeagueStatDefinition(
          name: name,
          category: value['category']?.toString() ?? 'general',
          displayName: value['displayName']?.toString() ?? name,
          shortDisplayName: value['shortDisplayName']?.toString(),
          abbreviation: value['abbreviation']?.toString(),
          description: value['description']?.toString(),
        );
      });
    }

    final byAlias = <String, LeagueStatsSnapshot>{};
    for (final entry in root['leagues'] as List? ?? const []) {
      if (entry is! Map) continue;
      final snapshot = _decodeLeague(entry, definitions);
      for (final alias in entry['aliases'] as List? ?? const []) {
        final key = _normalise(alias.toString());
        if (key != null) byAlias[key] = snapshot;
      }
      final slug = _normalise(entry['slug']?.toString());
      if (slug != null) byAlias[slug] = snapshot;
    }
    return byAlias;
  }

  LeagueStatsSnapshot _decodeLeague(
    Map<dynamic, dynamic> league,
    Map<String, LeagueStatDefinition> definitions,
  ) {
    final teams = <String, SportTeam>{};
    for (final raw in league['teams'] as List? ?? const []) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      if (id == null) continue;
      teams[id] = _team(raw);
    }

    return LeagueStatsSnapshot(
      groups: _decodeStandings(league['standings'], teams),
      categories: _decodeLeaders(league, teams),
      teamStats: _decodeTeamStats(league['teamStats'], teams),
      statDefinitions: definitions,
      seasonLabel: (league['season'] as Map?)?['displayName']?.toString(),
      seasonYear: ((league['season'] as Map?)?['year'] as num?)?.toInt(),
    );
  }

  SportTeam _team(Map<dynamic, dynamic> raw) {
    final abbreviation = raw['abbreviation']?.toString() ?? '';
    final name =
        raw['displayName']?.toString() ?? raw['name']?.toString() ?? 'Unknown';
    // The shared palette table is the authority on club colour and already
    // covers both competitions; the feed's own colour is only a backstop.
    final color =
        kTeamColors[abbreviation] ??
        _parseHexColor(raw['color']?.toString()) ??
        const Color(0xff3b82f6);
    return SportTeam(
      id: raw['id']?.toString() ?? '',
      name: name,
      shortName: abbreviation.isEmpty
          ? name.substring(0, name.length < 3 ? name.length : 3).toUpperCase()
          : abbreviation,
      color: color,
      crestAsset: raw['logo']?.toString(),
    );
  }

  List<StandingsGroup> _decodeStandings(
    Object? rows,
    Map<String, SportTeam> teams,
  ) {
    if (rows is! List || rows.isEmpty) return const [];
    final byGroup = <String, List<TeamStanding>>{};

    for (final raw in rows) {
      if (raw is! Map) continue;
      final team = teams[raw['teamId']?.toString()];
      if (team == null) continue;
      final stats = raw['stats'] as Map? ?? const {};

      double? value(String name) {
        final pair = stats[name];
        return pair is List && pair.isNotEmpty
            ? (pair.first as num?)?.toDouble()
            : null;
      }

      String display(String name) {
        final pair = stats[name];
        if (pair is! List || pair.length < 2) return '';
        return pair[1]?.toString() ?? '';
      }

      int intOf(String name) => value(name)?.round() ?? 0;

      final note = raw['note'] as Map?;
      final group = raw['group']?.toString() ?? '';
      byGroup
          .putIfAbsent(group, () => <TeamStanding>[])
          .add(
            TeamStanding(
              team: team,
              rank: (raw['rank'] as num?)?.toInt() ?? intOf('rank'),
              played: intOf('gamesPlayed'),
              won: intOf('wins'),
              drawn: intOf('ties'),
              lost: intOf('losses'),
              points: intOf('points'),
              diffLabel: display('pointDifferential'),
              form: '',
              group: group,
              tableName: team.name,
              goalsFor: intOf('pointsFor'),
              goalsAgainst: intOf('pointsAgainst'),
              zoneNote: note?['description']?.toString(),
              zoneColor: _parseHexColor(note?['color']?.toString()),
              rankChange: intOf('rankChange'),
            ),
          );
    }

    final groups = <StandingsGroup>[];
    for (final entry in byGroup.entries) {
      final sorted = [...entry.value]..sort((a, b) => a.rank.compareTo(b.rank));
      groups.add(StandingsGroup(label: entry.key, rows: sorted));
    }
    return groups;
  }

  /// Rebuilds the leaderboards in the same display order and accent scheme the
  /// live service uses, so the LEADERS tab looks identical from either source.
  List<StatLeaderCategory> _decodeLeaders(
    Map<dynamic, dynamic> league,
    Map<String, SportTeam> teams,
  ) {
    final athletes = league['athletes'] as Map? ?? const {};
    final byKey = <String, StatLeaderCategory>{};

    for (final raw in league['leaders'] as List? ?? const []) {
      if (raw is! Map) continue;
      final key = raw['key']?.toString();
      if (key == null) continue;
      final spec = _leaderSpecs[key];
      if (spec == null) continue;

      final leaders = <StatLeader>[];
      for (final row in raw['leaders'] as List? ?? const []) {
        if (row is! Map) continue;
        final athleteId = row['athleteId']?.toString();
        if (athleteId == null) continue;
        final athlete = athletes[athleteId] as Map?;
        final teamId = row['teamId']?.toString();
        leaders.add(
          StatLeader(
            athleteId: athleteId,
            value: (row['value'] as num?)?.toDouble() ?? 0,
            displayValue: row['displayValue']?.toString() ?? '',
            name: athlete?['displayName']?.toString(),
            teamId: teamId,
            team: teamId == null ? null : teams[teamId],
            position: athlete?['positionAbbr']?.toString(),
            flagUrl: athlete?['flag']?.toString(),
          ),
        );
        if (leaders.length >= _leaderCount) break;
      }
      if (leaders.isEmpty) continue;

      byKey[key] = StatLeaderCategory(
        key: key,
        label: spec.label,
        unitLabel: spec.unitLabel,
        accent: spec.accent,
        leaders: leaders,
      );
    }

    return [
      for (final key in _leaderSpecs.keys)
        if (byKey.containsKey(key)) byKey[key]!,
    ];
  }

  List<TeamSeasonStats> _decodeTeamStats(
    Object? raw,
    Map<String, SportTeam> teams,
  ) {
    if (raw is! Map) return const [];
    final out = <TeamSeasonStats>[];
    raw.forEach((teamId, categories) {
      final team = teams[teamId.toString()];
      if (team == null || categories is! Map) return;
      final values = <String, TeamStatValue>{};
      // Flattened across ESPN's four categories: a stat name is unique
      // league-wide, so callers never need to know its group.
      categories.forEach((_, stats) {
        if (stats is! Map) return;
        stats.forEach((name, pair) {
          if (pair is! List || pair.length < 2) return;
          final value = (pair.first as num?)?.toDouble();
          if (value == null) return;
          values[name.toString()] = TeamStatValue(
            value: value,
            display: pair[1]?.toString() ?? '',
          );
        });
      });
      if (values.isNotEmpty) {
        out.add(TeamSeasonStats(team: team, values: values));
      }
    });
    return out;
  }
}

/// How many players each leaderboard shows. Matches
/// `EspnLeagueStatsService.leaderCount` so both sources render the same depth.
const _leaderCount = 10;

class _LeaderSpec {
  const _LeaderSpec(this.label, this.unitLabel, this.accent);

  final String label;
  final String unitLabel;
  final StatAccent accent;
}

/// Board order and tinting, mirroring `EspnLeagueStatsService._categorySpecs`.
/// ESPN ships `goals`/`goalsLeaders` (and the assists pair) as the same stat in
/// two formats, so only the richer `*Leaders` variant is kept.
const _leaderSpecs = <String, _LeaderSpec>{
  'goalsLeaders': _LeaderSpec('GOALS', 'GOALS SCORED', StatAccent.league),
  'assistsLeaders': _LeaderSpec('ASSISTS', 'ASSISTS', StatAccent.league),
  'shotsOnTarget': _LeaderSpec(
    'ON TARGET',
    'SHOTS ON TARGET',
    StatAccent.league,
  ),
  'totalShots': _LeaderSpec('SHOTS', 'TOTAL SHOTS', StatAccent.league),
  'accuratePasses': _LeaderSpec('PASSES', 'ACCURATE PASSES', StatAccent.league),
  'saves': _LeaderSpec('SAVES', 'SAVES MADE', StatAccent.success),
  'foulsSuffered': _LeaderSpec('FOULS WON', 'FOULS SUFFERED', StatAccent.amber),
  'foulsCommitted': _LeaderSpec('FOULS', 'FOULS COMMITTED', StatAccent.amber),
  'yellowCards': _LeaderSpec('YELLOW', 'YELLOW CARDS', StatAccent.amber),
  'redCards': _LeaderSpec('RED', 'RED CARDS', StatAccent.danger),
};

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(cleaned.length <= 6 ? value + 0xFF000000 : value);
}
