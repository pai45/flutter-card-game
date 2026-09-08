import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/theme.dart';
import '../data/team_colors.dart';
import '../models/sport_match.dart';
import '../models/team_hub.dart';
import 'espn_score_service.dart';

abstract interface class TeamHubRepository {
  Future<TeamHubData> loadBundled({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  });

  Future<TeamHubData> loadLive({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  });
}

/// Reads the generated ESPN packages first, then performs a best-effort live
/// refresh. An empty live response is valid and never erases bundled content.
class EspnTeamHubRepository implements TeamHubRepository {
  EspnTeamHubRepository({EspnScoreService? scoreService})
    : _scoreService = scoreService ?? EspnScoreService();

  final EspnScoreService _scoreService;

  static const _footballAsset = 'assets/data/football-league-stats.json';
  static const _cricketAsset = 'assets/data/cricket-league-stats.json';

  @override
  Future<TeamHubData> loadBundled({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  }) async {
    final source = await rootBundle.loadString(
      sport == Sport.cricket ? _cricketAsset : _footballAsset,
    );
    final root = jsonDecode(source);
    final league = _findLeague(root, leagueId);
    if (league == null) {
      return TeamHubData(
        leagueId: leagueId,
        teamId: teamId,
        seasonYear: seasonYear,
        seasonLabel: seasonLabel,
      );
    }
    return TeamHubData(
      leagueId: leagueId,
      teamId: teamId,
      seasonYear: _seasonYear(league) ?? seasonYear,
      seasonLabel: _seasonLabel(league) ?? seasonLabel,
      fixtures: _decodeFixtures(league, sport, teamId),
      players: _decodePlayers(league, teamId),
    );
  }

  @override
  Future<TeamHubData> loadLive({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  }) async {
    if (sport != Sport.football || kIsWeb) {
      return TeamHubData(
        leagueId: leagueId,
        teamId: teamId,
        seasonYear: seasonYear,
        seasonLabel: seasonLabel,
      );
    }
    final fixtures = await _scoreService.fetchFootballSeasonMatches(
      leagueId,
      seasonYear,
    );
    final players = await _fetchFootballRoster(
      leagueId: leagueId,
      teamId: teamId,
      seasonYear: seasonYear,
    );
    return TeamHubData(
      leagueId: leagueId,
      teamId: teamId,
      seasonYear: seasonYear,
      seasonLabel: seasonLabel,
      fixtures: fixtures
          .where((match) => match.home.id == teamId || match.away.id == teamId)
          .toList(growable: false),
      players: players,
    );
  }

  Map<dynamic, dynamic>? _findLeague(Object? root, String leagueId) {
    if (root is! Map) return null;
    final wanted = _normalise(leagueId);
    for (final item in root['leagues'] as List? ?? const []) {
      if (item is! Map) continue;
      final aliases = <String>{
        _normalise(item['id']?.toString() ?? ''),
        _normalise(item['slug']?.toString() ?? ''),
        _normalise(item['name']?.toString() ?? ''),
        _normalise(item['abbreviation']?.toString() ?? ''),
        for (final alias in item['aliases'] as List? ?? const [])
          _normalise(alias.toString()),
      };
      if (aliases.contains(wanted)) return item;
    }
    return null;
  }

  List<TeamSeasonPlayer> _decodePlayers(
    Map<dynamic, dynamic> league,
    String teamId,
  ) {
    final athletes = league['athletes'];
    if (athletes is! Map) return const [];

    final athleteTeam = <String, String>{};
    for (final board in league['leaders'] as List? ?? const []) {
      if (board is! Map) continue;
      for (final row in board['leaders'] as List? ?? const []) {
        if (row is! Map) continue;
        final athleteId = row['athleteId']?.toString();
        final rowTeamId = row['teamId']?.toString();
        if (athleteId != null && rowTeamId != null) {
          athleteTeam[athleteId] = rowTeamId;
        }
      }
    }

    final rosterIds = <String>{};
    final rosters = league['rosters'];
    if (rosters is Map) {
      for (final raw in rosters[teamId] as List? ?? const []) {
        if (raw is Map) {
          final id = raw['id']?.toString();
          if (id != null) rosterIds.add(id);
        } else {
          rosterIds.add(raw.toString());
        }
      }
    }

    final players = <TeamSeasonPlayer>[];
    for (final entry in athletes.entries) {
      if (entry.value is! Map) continue;
      final raw = entry.value as Map;
      final id = raw['id']?.toString() ?? entry.key.toString();
      final playerTeamId = raw['teamId']?.toString() ?? athleteTeam[id];
      if (playerTeamId != teamId && !rosterIds.contains(id)) continue;
      final name =
          raw['displayName']?.toString() ??
          raw['name']?.toString() ??
          raw['fullName']?.toString();
      if (name == null || name.trim().isEmpty) continue;
      final rawStats = raw['stats'];
      players.add(
        TeamSeasonPlayer(
          id: id,
          teamId: teamId,
          name: name,
          shortName: raw['shortName']?.toString(),
          jersey: raw['jersey']?.toString(),
          role: raw['position']?.toString() ?? raw['role']?.toString(),
          positionAbbreviation: raw['positionAbbr']?.toString(),
          nationality: raw['citizenship']?.toString(),
          flagUrl: raw['flag']?.toString(),
          stats: rawStats is Map
              ? {
                  for (final stat in rawStats.entries)
                    if (stat.value is num)
                      stat.key.toString(): stat.value as num,
                }
              : const {},
        ),
      );
    }
    players.sort((a, b) {
      final group = _roleRank(a).compareTo(_roleRank(b));
      return group == 0 ? a.name.compareTo(b.name) : group;
    });
    return players;
  }

  Future<List<TeamSeasonPlayer>> _fetchFootballRoster({
    required String leagueId,
    required String teamId,
    required int seasonYear,
  }) async {
    final slug = _footballSlug(leagueId);
    final uri = Uri.parse(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
      '/seasons/$seasonYear/teams/$teamId/athletes?limit=100',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('ESPN roster HTTP ${response.statusCode}');
    }
    final collection = jsonDecode(response.body);
    if (collection is! Map) return const [];
    final refs = <String>[];
    for (final item in collection['items'] as List? ?? const []) {
      if (item is! Map) continue;
      final ref = item[r'$ref']?.toString();
      if (ref != null) refs.add(ref.replaceFirst('http://', 'https://'));
    }

    final players = <TeamSeasonPlayer>[];
    for (var offset = 0; offset < refs.length; offset += 6) {
      final end = (offset + 6).clamp(0, refs.length);
      final batch = await Future.wait([
        for (final ref in refs.sublist(offset, end))
          _fetchFootballPlayer(ref, teamId),
      ]);
      players.addAll(batch.whereType<TeamSeasonPlayer>());
    }
    players.sort((a, b) {
      final group = _roleRank(a).compareTo(_roleRank(b));
      return group == 0 ? a.name.compareTo(b.name) : group;
    });
    return players;
  }

  Future<TeamSeasonPlayer?> _fetchFootballPlayer(
    String url,
    String teamId,
  ) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final raw = jsonDecode(response.body);
      if (raw is! Map) return null;
      final name =
          raw['displayName']?.toString() ?? raw['fullName']?.toString();
      if (name == null || name.isEmpty) return null;
      final position = raw['position'];
      final flag = raw['flag'];
      return TeamSeasonPlayer(
        id: raw['id']?.toString() ?? '',
        teamId: teamId,
        name: name,
        shortName: raw['shortName']?.toString(),
        jersey: raw['jersey']?.toString(),
        role: position is Map ? position['name']?.toString() : null,
        positionAbbreviation: position is Map
            ? position['abbreviation']?.toString()
            : null,
        nationality: raw['citizenship']?.toString(),
        flagUrl: flag is Map ? flag['href']?.toString() : null,
      );
    } catch (_) {
      return null;
    }
  }

  List<SportMatch> _decodeFixtures(
    Map<dynamic, dynamic> league,
    Sport sport,
    String teamId,
  ) {
    final teams = <String, SportTeam>{};
    for (final raw in league['teams'] as List? ?? const []) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      if (id == null) continue;
      teams[id] = _decodeTeam(raw, sport);
    }
    final fixtures = <SportMatch>[];
    for (final raw in league['fixtures'] as List? ?? const []) {
      if (raw is! Map) continue;
      final homeId = raw['homeTeamId']?.toString();
      final awayId = raw['awayTeamId']?.toString();
      final home = teams[homeId];
      final away = teams[awayId];
      final kickoff = DateTime.tryParse(raw['kickoff']?.toString() ?? '');
      if (home == null || away == null || kickoff == null) continue;
      if (home.id != teamId && away.id != teamId) continue;
      fixtures.add(
        SportMatch(
          id: raw['id']?.toString() ?? '',
          leagueId:
              league['slug']?.toString() ?? league['id']?.toString() ?? '',
          sport: sport,
          home: home,
          away: away,
          kickoff: kickoff,
          status: switch (raw['status']?.toString()) {
            'live' => MatchStatus.live,
            'finished' => MatchStatus.finished,
            _ => MatchStatus.upcoming,
          },
          homeScore: raw['homeScore']?.toString(),
          awayScore: raw['awayScore']?.toString(),
          resultLine: raw['resultLine']?.toString(),
        ),
      );
    }
    return fixtures;
  }

  SportTeam _decodeTeam(Map<dynamic, dynamic> raw, Sport sport) {
    final name =
        raw['displayName']?.toString() ?? raw['name']?.toString() ?? '';
    final code = raw['abbreviation']?.toString() ?? _initials(name);
    return SportTeam(
      id: raw['id']?.toString() ?? '',
      name: name,
      shortName: code,
      color: kTeamColors[code] ?? Cyber.cyan,
      crestAsset: raw['logo']?.toString(),
    );
  }

  int? _seasonYear(Map<dynamic, dynamic> league) {
    final season = league['season'];
    if (season is Map && season['year'] is num) {
      return (season['year'] as num).toInt();
    }
    final direct = league['seasonYear'];
    return direct is num ? direct.toInt() : null;
  }

  String? _seasonLabel(Map<dynamic, dynamic> league) {
    final season = league['season'];
    if (season is Map) return season['displayName']?.toString();
    return season?.toString();
  }

  static int _roleRank(TeamSeasonPlayer player) {
    final abbreviation = player.positionAbbreviation?.toLowerCase().trim();
    final value = player.role?.toLowerCase() ?? '';
    if (value.contains('goal') || abbreviation == 'gk') return 0;
    if (value.contains('def') || abbreviation == 'd') return 1;
    if (value.contains('mid') || abbreviation == 'm') return 2;
    if (value.contains('forw') ||
        value.contains('attack') ||
        abbreviation == 'f') {
      return 3;
    }
    if (value.contains('wicket')) return 0;
    if (value.contains('batt')) return 1;
    if (value.contains('all')) return 2;
    if (value.contains('bowl')) return 3;
    return 4;
  }

  static String _footballSlug(String value) {
    final key = _normalise(value);
    if (const {'epl', 'eng1', '700', '23', 'premierleague'}.contains(key)) {
      return 'eng.1';
    }
    if (const {'laliga', 'lal', 'esp1', '740', '15'}.contains(key)) {
      return 'esp.1';
    }
    return value;
  }

  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(3)
      .map((part) => part.substring(0, 1))
      .join()
      .toUpperCase();
}
