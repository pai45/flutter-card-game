import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/football_player_profile.dart';
import '../models/sport_match.dart';
import 'espn_league_stats_service.dart';

/// Fetches a detailed soccer player dossier from ESPN's public core feed.
///
/// The full stat split is intentionally lazy: it is only requested after a
/// player chooses to inspect an athlete, and cached for the app lifetime.
class EspnFootballPlayerProfileService {
  const EspnFootballPlayerProfileService();

  static const _timeout = Duration(seconds: 8);
  static final Map<String, FootballPlayerProfile> _cache = {};

  Future<FootballPlayerProfile?> fetch({
    required String leagueId,
    required String athleteId,
    required int? seasonYear,
    SportTeam? team,
  }) async {
    final slug = EspnLeagueStatsService.slugFor(leagueId);
    if (slug == null || seasonYear == null) return null;

    final cacheKey = '$slug/$seasonYear/$athleteId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final root =
        'https://sports.core.api.espn.com/v2/sports/soccer/'
        'leagues/$slug/seasons/$seasonYear';
    final result = await Future.wait([
      _get('$root/athletes/$athleteId?lang=en&region=us'),
      _get('$root/types/1/athletes/$athleteId/statistics?lang=en&region=us'),
    ]);
    final athlete = result[0];
    if (athlete == null) {
      // Network/CORS failures are transient. Do not cache a miss or the player
      // would be permanently stuck on the cached leaderboard shell.
      return null;
    }

    final profile = FootballPlayerProfile(
      athleteId: athleteId,
      name:
          athlete['displayName']?.toString() ??
          athlete['fullName']?.toString() ??
          'UNKNOWN PLAYER',
      shortName: athlete['shortName']?.toString(),
      team: team,
      seasonYear: seasonYear,
      position:
          (athlete['position'] as Map?)?['displayName']?.toString() ??
          (athlete['position'] as Map?)?['abbreviation']?.toString(),
      jersey: athlete['jersey']?.toString(),
      age: (athlete['age'] as num?)?.toInt(),
      dateOfBirth: DateTime.tryParse(athlete['dateOfBirth']?.toString() ?? ''),
      displayHeight: athlete['displayHeight']?.toString(),
      displayWeight: athlete['displayWeight']?.toString(),
      citizenship: athlete['citizenship']?.toString(),
      flagUrl: (athlete['flag'] as Map?)?['href']?.toString(),
      active: athlete['active'] as bool?,
      statGroups: _parseStatGroups(result[1]),
    );
    _cache[cacheKey] = profile;
    return profile;
  }

  static List<FootballPlayerSeasonStatGroup> _parseStatGroups(
    Map<String, dynamic>? data,
  ) {
    final categories =
        ((data?['splits'] as Map?)?['categories'] as List?) ?? const [];
    final groups = <FootballPlayerSeasonStatGroup>[];
    for (final rawCategory in categories) {
      if (rawCategory is! Map) continue;
      final stats = <FootballPlayerSeasonStat>[];
      for (final rawStat in rawCategory['stats'] as List? ?? const []) {
        if (rawStat is! Map) continue;
        final key = rawStat['name']?.toString();
        final value = (rawStat['value'] as num?)?.toDouble();
        if (key == null || value == null) continue;
        stats.add(
          FootballPlayerSeasonStat(
            key: key,
            label:
                rawStat['shortDisplayName']?.toString() ??
                rawStat['displayName']?.toString() ??
                key,
            displayValue:
                rawStat['displayValue']?.toString() ?? _fallbackNumber(value),
            value: value,
          ),
        );
      }
      if (stats.isEmpty) continue;
      groups.add(
        FootballPlayerSeasonStatGroup(
          key: rawCategory['name']?.toString() ?? 'general',
          label: rawCategory['displayName']?.toString() ?? 'SEASON DATA',
          stats: stats,
        ),
      );
    }
    return groups;
  }

  static String _fallbackNumber(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
