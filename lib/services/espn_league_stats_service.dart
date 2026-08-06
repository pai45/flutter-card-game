import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/team_colors.dart';
import '../models/league_stat_leaders.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';

/// Live league-wide stats for the league hub: the standings table (grouped by
/// conference where the competition has them) and the ESPN stat leaderboards.
///
/// Three feeds are combined:
///  * `apis/v2/.../{slug}/standings` — grouped table, qualification notes, and
///    the team directory every other feed is resolved against.
///  * `site/v2/.../{slug}/statistics` — goals and assists with athlete names
///    inline, so the two headline boards need no follow-up requests.
///  * `sports.core.api.../leaders` — every remaining category, but with
///    athletes as `$ref` links. Those are resolved lazily, top-N at a time,
///    only for the board the player is actually looking at.
///
/// Results are cached per league for the app's lifetime, so re-entering the
/// hub is instant.
class EspnLeagueStatsService {
  const EspnLeagueStatsService();

  static const _timeout = Duration(seconds: 8);

  /// How many players each board shows (and therefore how many athlete
  /// references a lazy category resolve has to fetch).
  static const leaderCount = 10;

  /// Curated league id to ESPN competition slug. Leagues discovered at runtime
  /// carry ESPN's numeric id rather than a slug and simply resolve to null —
  /// the hub then falls back to the repository's own standings.
  static const _slugs = <String, String>{
    'mls': 'usa.1',
    'epl': 'eng.1',
    'fifa': 'fifa.world',
    'uclq': 'uefa.champions_qual',
    'brasileirao': 'bra.1',
    'ligamx': 'mex.1',
    'allsvenskan': 'swe.1',
    'eliteserien': 'nor.1',
  };

  /// Boards in display order: attacking output first, then shot-stopping, then
  /// discipline. ESPN ships `goals`/`goalsLeaders` (and the assists pair) as
  /// the same stat with different formatting, so only the richer `*Leaders`
  /// variant is kept.
  static const _categorySpecs = <_CategorySpec>[
    _CategorySpec('goalsLeaders', 'GOALS', 'GOALS SCORED', StatAccent.league),
    _CategorySpec('assistsLeaders', 'ASSISTS', 'ASSISTS', StatAccent.league),
    _CategorySpec(
      'shotsOnTarget',
      'ON TARGET',
      'SHOTS ON TARGET',
      StatAccent.league,
    ),
    _CategorySpec('totalShots', 'SHOTS', 'TOTAL SHOTS', StatAccent.league),
    _CategorySpec(
      'accuratePasses',
      'PASSES',
      'ACCURATE PASSES',
      StatAccent.league,
    ),
    _CategorySpec('saves', 'SAVES', 'SAVES MADE', StatAccent.success),
    _CategorySpec(
      'foulsSuffered',
      'FOULS WON',
      'FOULS SUFFERED',
      StatAccent.amber,
    ),
    _CategorySpec('foulsCommitted', 'FOULS', 'FOULS COMMITTED', StatAccent.amber),
    _CategorySpec('yellowCards', 'YELLOW', 'YELLOW CARDS', StatAccent.amber),
    _CategorySpec('redCards', 'RED', 'RED CARDS', StatAccent.danger),
  ];

  static final Map<String, LeagueStatsSnapshot> _snapshotCache = {};
  static final Map<String, _LeagueContext> _contextCache = {};
  static final Map<String, _ResolvedAthlete> _athleteCache = {};

  /// True when [leagueId] maps to a competition ESPN can serve stats for.
  static bool supports(String leagueId) => _slugs.containsKey(leagueId);

  @visibleForTesting
  static void clearCache() {
    _snapshotCache.clear();
    _contextCache.clear();
    _athleteCache.clear();
  }

  /// Standings plus every leaderboard for [leagueId]. Goals and assists come
  /// back fully resolved; the rest carry values only until [resolveCategory]
  /// fills in the names.
  Future<LeagueStatsSnapshot> fetchSnapshot(String leagueId) async {
    final cached = _snapshotCache[leagueId];
    if (cached != null) return cached;

    final slug = _slugs[leagueId];
    if (slug == null) return LeagueStatsSnapshot.empty;

    final results = await Future.wait([
      _get('https://site.web.api.espn.com/apis/v2/sports/soccer/$slug/standings'),
      _get(
        'https://site.api.espn.com/apis/site/v2/sports/soccer/$slug/statistics',
      ),
    ]);

    final standingsData = results[0];
    final statsData = results[1];

    final teams = <String, SportTeam>{};
    final groups = _parseStandings(standingsData, teams);

    final season = statsData?['season'] as Map<String, dynamic>?;
    final seasonYear = (season?['year'] as num?)?.toInt();
    final seasonLabel = season?['displayName']?.toString();

    final inline = _parseInlineLeaders(statsData, teams);
    final core = seasonYear == null
        ? const <String, List<StatLeader>>{}
        : await _fetchCoreLeaders(slug, seasonYear, teams);

    final categories = <StatLeaderCategory>[];
    for (final spec in _categorySpecs) {
      // The inline feed only carries goals/assists, but its athletes arrive
      // named, so prefer it and fall back to the reference-based feed.
      final leaders = inline[spec.key] ?? core[spec.key] ?? const <StatLeader>[];
      if (leaders.isEmpty) continue;
      categories.add(
        StatLeaderCategory(
          key: spec.key,
          label: spec.label,
          unitLabel: spec.unitLabel,
          accent: spec.accent,
          leaders: leaders.take(leaderCount).toList(growable: false),
        ),
      );
    }

    final snapshot = LeagueStatsSnapshot(
      groups: groups,
      categories: categories,
      seasonLabel: seasonLabel,
    );
    if (!snapshot.isEmpty) {
      _snapshotCache[leagueId] = snapshot;
      if (seasonYear != null) {
        _contextCache[leagueId] = _LeagueContext(
          slug: slug,
          seasonYear: seasonYear,
          teams: teams,
        );
      }
    }
    return snapshot;
  }

  /// Fills in athlete names for one board. Only the players actually on screen
  /// are fetched, and every athlete is cached across boards — the same striker
  /// tops several categories, so most resolves are already warm.
  Future<StatLeaderCategory> resolveCategory(
    String leagueId,
    StatLeaderCategory category,
  ) async {
    if (category.isResolved) return category;
    final context = _contextCache[leagueId];
    if (context == null) return category;

    final pending = category.leaders
        .where((l) => !l.isResolved && !_athleteCache.containsKey(l.athleteId))
        .map((l) => l.athleteId)
        .toSet();

    if (pending.isNotEmpty) {
      final fetched = await Future.wait(
        pending.map((id) => _fetchAthlete(context, id)),
      );
      for (final athlete in fetched) {
        if (athlete != null) _athleteCache[athlete.id] = athlete;
      }
    }

    final resolved = <StatLeader>[];
    for (final leader in category.leaders) {
      final athlete = _athleteCache[leader.athleteId];
      if (athlete == null) {
        resolved.add(leader);
        continue;
      }
      resolved.add(
        leader.copyWith(
          name: athlete.name,
          position: athlete.position,
          flagUrl: athlete.flagUrl,
          team: leader.team ?? context.teams[leader.teamId],
        ),
      );
    }
    final next = category.withLeaders(resolved);
    _replaceCachedCategory(leagueId, next);
    return next;
  }

  void _replaceCachedCategory(String leagueId, StatLeaderCategory category) {
    final snapshot = _snapshotCache[leagueId];
    if (snapshot == null) return;
    final index = snapshot.categories.indexWhere((c) => c.key == category.key);
    if (index < 0) return;
    _snapshotCache[leagueId] = snapshot.withCategory(index, category);
  }

  // ── Standings ─────────────────────────────────────────────────────────────

  List<StandingsGroup> _parseStandings(
    Map<String, dynamic>? data,
    Map<String, SportTeam> teams,
  ) {
    if (data == null) return const [];
    final children = data['children'] as List? ?? const [];
    final groups = <StandingsGroup>[];

    for (final child in children) {
      if (child is! Map) continue;
      final entries = (child['standings'] as Map?)?['entries'] as List? ?? const [];
      final rows = <TeamStanding>[];
      final groupLabel = child['name']?.toString() ?? '';

      for (final entry in entries) {
        if (entry is! Map) continue;
        final teamData = entry['team'] as Map?;
        if (teamData == null) continue;
        final team = _parseTeam(teamData);
        teams[team.id] = team;

        final stats = entry['stats'] as List? ?? const [];
        String stat(String name) {
          for (final s in stats) {
            if (s is Map && s['name'] == name) {
              return s['displayValue']?.toString() ?? '';
            }
          }
          return '';
        }

        int statInt(String name) =>
            int.tryParse(stat(name).replaceAll('+', '')) ?? 0;

        final note = entry['note'] as Map?;
        rows.add(
          TeamStanding(
            team: team,
            rank: statInt('rank'),
            played: statInt('gamesPlayed'),
            won: statInt('wins'),
            drawn: statInt('ties'),
            lost: statInt('losses'),
            points: statInt('points'),
            diffLabel: stat('pointDifferential'),
            form: '',
            group: groupLabel,
            tableName: teamData['shortDisplayName']?.toString(),
            goalsFor: statInt('pointsFor'),
            goalsAgainst: statInt('pointsAgainst'),
            zoneNote: note?['description']?.toString(),
            zoneColor: _parseHexColor(note?['color']?.toString()),
            rankChange: statInt('rankChange'),
          ),
        );
      }

      if (rows.isEmpty) continue;
      rows.sort((a, b) => a.rank.compareTo(b.rank));
      groups.add(StandingsGroup(label: groupLabel, rows: rows));
    }
    return groups;
  }

  SportTeam _parseTeam(Map teamData) {
    final abbreviation = teamData['abbreviation']?.toString() ?? '';
    final name =
        teamData['displayName']?.toString() ??
        teamData['name']?.toString() ??
        'Unknown';
    final logos = teamData['logos'] as List?;
    final firstLogo = (logos == null || logos.isEmpty) ? null : logos.first;
    // The standings feed carries no colour, so fall back to the shared team
    // colour table. TeamLogo resolves known clubs by name anyway; this only
    // matters for sides the palette database has never seen.
    final color =
        kTeamColors[abbreviation] ??
        _parseHexColor(teamData['color']?.toString()) ??
        const Color(0xff3b82f6);
    return SportTeam(
      id: teamData['id']?.toString() ?? '',
      name: name,
      shortName: abbreviation.isEmpty
          ? name.substring(0, name.length < 3 ? name.length : 3).toUpperCase()
          : abbreviation,
      color: color,
      crestAsset: firstLogo is Map ? firstLogo['href']?.toString() : null,
    );
  }

  // ── Leaderboards ──────────────────────────────────────────────────────────

  /// Goals and assists straight off the site statistics feed, where athletes
  /// arrive with their names already attached.
  Map<String, List<StatLeader>> _parseInlineLeaders(
    Map<String, dynamic>? data,
    Map<String, SportTeam> teams,
  ) {
    if (data == null) return const {};
    final out = <String, List<StatLeader>>{};
    for (final group in data['stats'] as List? ?? const []) {
      if (group is! Map) continue;
      final key = group['name']?.toString();
      if (key == null) continue;
      final leaders = <StatLeader>[];
      for (final entry in group['leaders'] as List? ?? const []) {
        if (entry is! Map) continue;
        final athlete = entry['athlete'] as Map?;
        final athleteId = athlete?['id']?.toString();
        if (athleteId == null) continue;
        final teamId =
            (entry['team'] as Map?)?['id']?.toString() ??
            (athlete?['team'] as Map?)?['id']?.toString();
        leaders.add(
          StatLeader(
            athleteId: athleteId,
            value: (entry['value'] as num?)?.toDouble() ?? 0,
            displayValue: entry['displayValue']?.toString() ?? '',
            name: athlete?['displayName']?.toString(),
            teamId: teamId,
            team: teamId == null ? null : teams[teamId],
            flagUrl: (athlete?['flag'] as Map?)?['href']?.toString(),
          ),
        );
      }
      if (leaders.isNotEmpty) out[key] = leaders;
    }
    return out;
  }

  /// Every category from the core leaders feed. Athletes are references here,
  /// so only ids and values are known until [resolveCategory] runs.
  Future<Map<String, List<StatLeader>>> _fetchCoreLeaders(
    String slug,
    int seasonYear,
    Map<String, SportTeam> teams,
  ) async {
    final data = await _get(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/$slug'
      '/seasons/$seasonYear/types/1/leaders',
    );
    if (data == null) return const {};

    final out = <String, List<StatLeader>>{};
    for (final category in data['categories'] as List? ?? const []) {
      if (category is! Map) continue;
      final key = category['name']?.toString();
      if (key == null) continue;
      final leaders = <StatLeader>[];
      for (final entry in category['leaders'] as List? ?? const []) {
        if (entry is! Map) continue;
        final athleteId = _idFromRef((entry['athlete'] as Map?)?[r'$ref']);
        if (athleteId == null) continue;
        final teamId = _idFromRef((entry['team'] as Map?)?[r'$ref']);
        final cached = _athleteCache[athleteId];
        leaders.add(
          StatLeader(
            athleteId: athleteId,
            value: (entry['value'] as num?)?.toDouble() ?? 0,
            displayValue: entry['displayValue']?.toString() ?? '',
            name: cached?.name,
            position: cached?.position,
            flagUrl: cached?.flagUrl,
            teamId: teamId,
            team: teamId == null ? null : teams[teamId],
          ),
        );
        if (leaders.length >= leaderCount) break;
      }
      if (leaders.isNotEmpty) out[key] = leaders;
    }
    return out;
  }

  Future<_ResolvedAthlete?> _fetchAthlete(
    _LeagueContext context,
    String athleteId,
  ) async {
    final data = await _get(
      'https://sports.core.api.espn.com/v2/sports/soccer/leagues/${context.slug}'
      '/seasons/${context.seasonYear}/athletes/$athleteId?lang=en&region=us',
    );
    final name =
        data?['displayName']?.toString() ?? data?['fullName']?.toString();
    if (name == null) return null;
    return _ResolvedAthlete(
      id: athleteId,
      name: name,
      position: (data?['position'] as Map?)?['abbreviation']?.toString(),
      flagUrl: (data?['flag'] as Map?)?['href']?.toString(),
    );
  }

  // ── Plumbing ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = json.decode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('EspnLeagueStatsService: request failed ($url): $e');
      return null;
    }
  }

  /// Pulls the trailing id out of a core-API reference URL, e.g.
  /// `.../athletes/277128?lang=en` becomes `277128`.
  static String? _idFromRef(Object? ref) {
    if (ref is! String) return null;
    final path = Uri.tryParse(ref)?.pathSegments;
    if (path == null || path.isEmpty) return null;
    return path.last.isEmpty ? null : path.last;
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(cleaned.length <= 6 ? value + 0xFF000000 : value);
  }
}

class _CategorySpec {
  const _CategorySpec(this.key, this.label, this.unitLabel, this.accent);

  final String key;
  final String label;
  final String unitLabel;
  final StatAccent accent;
}

/// What a lazy athlete resolve needs to rebuild reference URLs, plus the team
/// directory harvested from the standings feed.
class _LeagueContext {
  const _LeagueContext({
    required this.slug,
    required this.seasonYear,
    required this.teams,
  });

  final String slug;
  final int seasonYear;
  final Map<String, SportTeam> teams;
}

class _ResolvedAthlete {
  const _ResolvedAthlete({
    required this.id,
    required this.name,
    this.position,
    this.flagUrl,
  });

  final String id;
  final String name;
  final String? position;
  final String? flagUrl;
}
