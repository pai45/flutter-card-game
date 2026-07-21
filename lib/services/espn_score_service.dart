import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/cricket_scorecard.dart';
import '../models/league.dart';
import '../models/sport_match.dart';
import '../data/team_colors.dart';
import '../models/basketball_scorecard.dart';
import '../models/tennis_scorecard.dart';
import '../utils/tennis_country_map.dart';

class EspnScoreService {
  /// Leagues discovered from live ESPN payloads whose real competition isn't
  /// one of the ~16 hardcoded [League]s — populated by [_registerLeagueFromPayload]
  /// as football/cricket fixtures are fetched, and merged into
  /// `MockPredictionRepository.leagues()` so those fixtures aren't silently
  /// dropped by the prediction home's `validLeagueIds` filter. Static because
  /// a fresh [EspnScoreService] is constructed per fetch, but discovered
  /// leagues should persist for the app's lifetime.
  static final Map<String, League> discoveredLeagues = {};

  /// Registers a league discovered from an ESPN payload's `leagues[0]`
  /// (present on both the football scoreboard and cricket scorepanel
  /// responses) so it can be surfaced instead of every football/cricket
  /// fixture being force-labelled a single hardcoded league regardless of
  /// its real competition. Returns the real ESPN league id, or null if the
  /// payload didn't carry one.
  static String? _registerLeagueFromPayload(List? leagues) {
    if (leagues == null || leagues.isEmpty) return null;
    final league = leagues.first as Map?;
    final id = league?['id']?.toString();
    if (id == null || id.isEmpty) return null;
    if (!discoveredLeagues.containsKey(id)) {
      final name = league?['name']?.toString() ?? id;
      final abbreviation = league?['abbreviation']?.toString();
      final shortCode = (abbreviation != null && abbreviation.isNotEmpty)
          ? abbreviation
          : (name.length <= 5 ? name.toUpperCase() : id);
      discoveredLeagues[id] = League(
        id: id,
        name: name,
        shortCode: shortCode,
        accent: const Color(0xff5cdfff),
      );
    }
    return id;
  }

  String _getAthleteName(dynamic athlete) {
    if (athlete == null) return 'Unknown';
    String shortName = athlete['shortName']?.toString().trim() ?? '';
    if (shortName.isNotEmpty) return shortName;
    String displayName = athlete['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    String fullName = athlete['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    return 'Unknown';
  }



  static const _fetchTimeout = Duration(seconds: 8);

  /// Fetches every ESPN scoreboard this sport needs, across the whole day
  /// window, CONCURRENTLY rather than one request at a time. The previous
  /// version awaited each of up to ~22 requests (11 days × up to 2 leagues)
  /// sequentially with no timeout — a single slow ESPN response stalled
  /// every request behind it, which is why a sport tab's first load could
  /// take many seconds. Firing them all at once and bounding each with a
  /// timeout turns that into one round-trip's worth of wall-clock time.
  Future<List<SportMatch>> fetchDynamicMatchesForSport(Sport sport) async {
    final now = DateTime.now();
    final tasks = <Future<List<SportMatch>>>[];

    if (sport == Sport.motorsport) {
      tasks.add(_fetchMotorsportSeries('racing/f1', 'f1', 'F1'));
      // 'INDY' (not the full 'IndyCar') so it fits the single-badge race card
      // on one line — matches the league's own shortCode.
      tasks.add(_fetchMotorsportSeries('racing/irl', 'indycar', 'INDY'));
      tasks.add(
        _fetchMotorsportSeries('racing/nascar-premier', 'nascar-cup', 'NASCAR'),
      );
    }

    // Fetch from day - 7 to day + 3 (total 11 days).
    for (int i = -7; i <= 3; i++) {
      final date = now.add(Duration(days: i));
      final dateStr =
          '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

      if (sport == Sport.cricket) {
        tasks.add(_fetchCricketDay(dateStr));
      }
      if (sport == Sport.football) {
        for (final league in ['eng.1', 'uefa.euro']) {
          tasks.add(_fetchFootballDay(league, dateStr));
        }
      }
      if (sport == Sport.basketball) {
        for (final leagueId in ['wnba', 'nba']) {
          tasks.add(_fetchBasketballDay(leagueId, dateStr));
        }
      }
      if (sport == Sport.tennis) {
        for (final league in ['atp', 'wta']) {
          tasks.add(_fetchTennisDay(league, dateStr));
        }
      }
    }

    final results = await Future.wait(tasks);
    final dynamicMatches = <SportMatch>[];
    for (final matches in results) {
      for (final match in matches) {
        if (!dynamicMatches.any((m) => m.id == match.id)) {
          dynamicMatches.add(match);
        }
      }
    }
    return dynamicMatches;
  }

  /// Fetches one motorsport series' full-season schedule and keeps only the
  /// race weekends inside the rolling window (same -7..+3 day range every
  /// other sport uses), rather than the old hardcoded 2-GP-name filter.
  Future<List<SportMatch>> _fetchMotorsportSeries(
    String espnSlug,
    String leagueId,
    String seriesLabel,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/$espnSlug/scoreboard?dates=2026'))
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      final events = data['events'] as List? ?? [];
      final now = DateTime.now();
      final windowStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 7));
      final windowEnd = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 3));
      final matches = <SportMatch>[];
      for (var event in events) {
        final eventDate = DateTime.tryParse(event['date']?.toString() ?? '');
        if (eventDate == null) continue;
        if (eventDate.isBefore(windowStart) || eventDate.isAfter(windowEnd)) {
          continue;
        }
        final match = _parseMotorsportEventToMatch(
          event,
          leagueId,
          seriesLabel,
        );
        if (match != null) matches.add(match);
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  Future<List<SportMatch>> _fetchCricketDay(String dateStr) async {
    try {
      final res = await http
          .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel?dates=$dateStr'))
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      final scores = data['scores'] as List? ?? [];
      final matches = <SportMatch>[];
      for (var score in scores) {
        final leagueId =
            _registerLeagueFromPayload(score['leagues'] as List?) ?? '23810';
        final events = score['events'] as List? ?? [];
        for (var event in events) {
          final match = _parseEventToMatch(event, Sport.cricket, leagueId);
          if (match != null) matches.add(match);
        }
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  Future<List<SportMatch>> _fetchFootballDay(String league, String dateStr) async {
    try {
      final res = await http
          .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/soccer/$league/scoreboard?dates=$dateStr'))
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      final leagueId =
          _registerLeagueFromPayload(data['leagues'] as List?) ?? 'fifa';
      final events = data['events'] as List? ?? [];
      final matches = <SportMatch>[];
      for (var event in events) {
        final match = _parseEventToMatch(event, Sport.football, leagueId);
        if (match != null) matches.add(match);
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  Future<List<SportMatch>> _fetchBasketballDay(String leagueId, String dateStr) async {
    try {
      final res = await http
          .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/$leagueId/scoreboard?dates=$dateStr'))
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      final events = data['events'] as List? ?? [];
      final matches = <SportMatch>[];
      for (var event in events) {
        final match = _parseEventToMatch(event, Sport.basketball, leagueId);
        if (match != null) matches.add(match);
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  /// ESPN's tennis scoreboard returns whole tournaments here — each event's
  /// own `competitions` is empty; the real, individually-dated matches are
  /// nested under `groupings[] (Men's/Women's Singles, Doubles) ->
  /// competitions[]`. Scoped to Singles for now (Doubles has no per-player
  /// identity model yet in this app).
  Future<List<SportMatch>> _fetchTennisDay(String league, String dateStr) async {
    try {
      final res = await http
          .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/tennis/$league/scoreboard?dates=$dateStr'))
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body);
      final events = data['events'] as List? ?? [];
      final matches = <SportMatch>[];
      for (var event in events) {
        final groupings = event['groupings'] as List? ?? [];
        for (var grouping in groupings) {
          final groupingName = grouping['grouping']?['displayName']?.toString() ?? '';
          if (!groupingName.contains('Singles')) continue;
          final competitions = grouping['competitions'] as List? ?? [];
          for (var competition in competitions) {
            final match = _parseTennisCompetitionToMatch(competition, league);
            if (match != null) matches.add(match);
          }
        }
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  SportMatch? _parseMotorsportEventToMatch(
    dynamic event,
    String leagueId,
    String seriesLabel,
  ) {
    try {
      final name = event['name']?.toString() ?? '$seriesLabel Race';
      final eventDate = DateTime.parse(event['date']);
      
      List<F1SessionResult> sessions = [];
      DateTime? weekendEndDate;

      final comps = event['competitions'] as List?;
      if (comps != null && comps.isNotEmpty) {
        for (var comp in comps) {
          final compName = comp['type']?['abbreviation']?.toString() ?? comp['type']?['text']?.toString() ?? 'Session';
          final competitors = comp['competitors'] as List?;
          List<String> results = [];
          if (competitors != null && competitors.isNotEmpty) {
             for (var c in competitors.take(3)) {
               final order = c['order']?.toString() ?? '';
               final athlete = c['athlete']?['displayName']?.toString() ?? 'Unknown';
               final time = c['status']?['displayValue']?.toString() ?? c['status']?['time']?.toString() ?? '';
               final resStr = time.isNotEmpty ? '$order. $athlete ($time)' : '$order. $athlete';
               results.add(resStr);
             }
          }
          sessions.add(F1SessionResult(name: compName, results: results));
        }
        weekendEndDate = DateTime.tryParse(comps.last['date'] ?? '');
      }

      final String? stateStr = event['status']?['type']?['state'];
      MatchStatus status = MatchStatus.upcoming;
      if (stateStr == 'in') status = MatchStatus.live;
      if (stateStr == 'post') status = MatchStatus.finished;

      final brandColor = switch (leagueId) {
        'indycar' => const Color(0xFF001489),
        'nascar-cup' => const Color(0xFFFFCC00),
        _ => const Color(0xFFE10600),
      };
      return SportMatch(
        id: event['id']?.toString() ?? '',
        leagueId: leagueId,
        sport: Sport.motorsport,
        home: SportTeam(
          id: '${leagueId}_home',
          name: name,
          shortName: seriesLabel,
          color: brandColor,
        ),
        away: SportTeam(
          id: '${leagueId}_away',
          name: seriesLabel,
          shortName: seriesLabel,
          color: const Color(0xFF000000),
        ),
        kickoff: eventDate,
        status: status,
        f1Sessions: sessions,
        f1WeekendEndDate: weekendEndDate,
        f1DriverStandings: const [],
      );
    } catch (_) {
      return null;
    }
  }

  SportMatch? _parseEventToMatch(dynamic event, Sport sport, String leagueId) {
    try {
      final comp = event['competitions'] != null && event['competitions'].isNotEmpty
          ? event['competitions'][0]
          : null;
      if (comp == null) return null;

      final competitors = comp['competitors'] as List;
      if (competitors.length < 2) return null;

      final homeTeamData = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => competitors[0],
      );
      final awayTeamData = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => competitors.length > 1 ? competitors[1] : competitors[0],
      );

      Color parseColor(String shortName, String? hex) {
        if (kTeamColors.containsKey(shortName)) return kTeamColors[shortName]!;
        if (hex == null || hex.isEmpty) return const Color(0xffffffff);
        try {
          return Color(int.parse(hex, radix: 16) + 0xFF000000);
        } catch (_) {
          return const Color(0xffffffff);
        }
      }

      final homeAbbrev = homeTeamData['team']['abbreviation']?.toString() ?? '';
      final homeTeam = SportTeam(
        id: homeTeamData['team']['id']?.toString() ?? '',
        name: homeTeamData['team']['name']?.toString() ?? 'Unknown',
        shortName: homeAbbrev,
        color: parseColor(homeAbbrev, homeTeamData['team']['color']?.toString()),
      );

      final awayAbbrev = awayTeamData['team']['abbreviation']?.toString() ?? '';
      final awayTeam = SportTeam(
        id: awayTeamData['team']['id']?.toString() ?? '',
        name: awayTeamData['team']['name']?.toString() ?? 'Unknown',
        shortName: awayAbbrev,
        color: parseColor(awayAbbrev, awayTeamData['team']['color']?.toString()),
      );

      final String? stateStr = event['status']?['type']?['state'];
      MatchStatus status = MatchStatus.upcoming;
      if (stateStr == 'in') status = MatchStatus.live;
      if (stateStr == 'post') status = MatchStatus.finished;

      return SportMatch(
        id: event['id']?.toString() ?? '',
        leagueId: leagueId,
        sport: sport,
        home: homeTeam,
        away: awayTeam,
        kickoff: DateTime.parse(event['date']),
        status: status,
        homeScore: homeTeamData['score']?.toString(),
        awayScore: awayTeamData['score']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses one real match — a single entry from a tournament event's
  /// `groupings[].competitions[]` (NOT the tournament event itself, whose
  /// own top-level `competitions` is always empty for tennis scoreboards).
  SportMatch? _parseTennisCompetitionToMatch(dynamic comp, String leagueId) {
    try {
      final competitors = comp['competitors'] as List;
      if (competitors.length < 2) return null;

      final homeTeamData = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => competitors[0],
      );
      final awayTeamData = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => competitors.length > 1 ? competitors[1] : competitors[0],
      );

      final homeAthlete = homeTeamData['athlete'];
      final awayAthlete = awayTeamData['athlete'];

      final homeName = homeAthlete?['displayName']?.toString() ?? 'Unknown';
      final homeCountryCode = TennisCountryMap.countryCodeFor(homeName);
      final homeShort = homeCountryCode ?? (homeAthlete?['shortName']?.toString() ?? homeName);
      final homeTeam = SportTeam(
        id: homeAthlete?['id']?.toString() ?? '',
        name: homeName,
        shortName: homeShort,
        color: homeCountryCode != null ? TennisCountryMap.colorFor(homeCountryCode) : const Color(0xffffffff),
        flagUrl: homeAthlete?['flag']?['href']?.toString(),
      );

      final awayName = awayAthlete?['displayName']?.toString() ?? 'Unknown';
      final awayCountryCode = TennisCountryMap.countryCodeFor(awayName);
      final awayShort = awayCountryCode ?? (awayAthlete?['shortName']?.toString() ?? awayName);
      final awayTeam = SportTeam(
        id: awayAthlete?['id']?.toString() ?? '',
        name: awayName,
        shortName: awayShort,
        color: awayCountryCode != null ? TennisCountryMap.colorFor(awayCountryCode) : const Color(0xffffffff),
        flagUrl: awayAthlete?['flag']?['href']?.toString(),
      );

      final String? stateStr = comp['status']?['type']?['state'];
      MatchStatus status = MatchStatus.upcoming;
      if (stateStr == 'in') status = MatchStatus.live;
      if (stateStr == 'post') status = MatchStatus.finished;

      // Parse TennisScorecard
      List<TennisSet> sets = [];
      final hLinescores = homeTeamData['linescores'] as List? ?? [];
      final aLinescores = awayTeamData['linescores'] as List? ?? [];
      final maxSets = hLinescores.length > aLinescores.length ? hLinescores.length : aLinescores.length;

      for (int i = 0; i < maxSets; i++) {
        final hl = i < hLinescores.length ? hLinescores[i] : null;
        final al = i < aLinescores.length ? aLinescores[i] : null;

        sets.add(TennisSet(
          homeScore: (hl?['value'] as num?)?.toInt() ?? 0,
          awayScore: (al?['value'] as num?)?.toInt() ?? 0,
          homeTiebreak: (hl?['tiebreak'] as num?)?.toInt(),
          awayTiebreak: (al?['tiebreak'] as num?)?.toInt(),
          isHomeWinner: hl?['winner'] == true,
          isAwayWinner: al?['winner'] == true,
        ));
      }

      TennisScorecard? scorecard;
      if (sets.isNotEmpty) {
        scorecard = TennisScorecard(sets: sets);
      }

      // The ESPN tennis scoreboard never carries a top-level `score` on
      // competitors (unlike football/basketball) — only per-set `linescores`.
      // Derive the headline "sets won" score (e.g. "2"-"0") from the sets
      // themselves so it isn't left null (which would hide the whole score
      // row, set chips included, once the match has actually started).
      String? hScore = homeTeamData['score']?.toString();
      String? aScore = awayTeamData['score']?.toString();
      if ((hScore == null || aScore == null) && sets.isNotEmpty) {
        hScore = sets.where((s) => s.isHomeWinner).length.toString();
        aScore = sets.where((s) => s.isAwayWinner).length.toString();
      }

      return SportMatch(
        id: comp['id']?.toString() ?? '',
        leagueId: leagueId,
        sport: Sport.tennis,
        home: homeTeam,
        away: awayTeam,
        kickoff: DateTime.parse(comp['date']),
        status: status,
        homeScore: hScore?.toString(),
        awayScore: aScore?.toString(),
        tennisScorecard: scorecard,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SportMatch>> enrichAllForSport(List<SportMatch> fixtures, Sport sport) async {
    try {
        List allEvents = [];
        
        if (sport == Sport.football) {
          final soccerRes = await http.get(Uri.parse(
              'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=20260611-20260719'))
              .timeout(_fetchTimeout);

          if (soccerRes.statusCode == 200) {
            final data = json.decode(soccerRes.body);
            allEvents.addAll(data['events'] as List? ?? []);
          }
        }

        if (sport == Sport.cricket) {
          final cricketRes = await http.get(Uri.parse(
              'https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel'))
              .timeout(_fetchTimeout);

          if (cricketRes.statusCode == 200) {
            final data = json.decode(cricketRes.body);
            final scores = data['scores'] as List? ?? [];
            for (var score in scores) {
              allEvents.addAll(score['events'] as List? ?? []);
            }
          }
        }

        if (sport == Sport.basketball) {
          final responses = await Future.wait([
            for (final leagueId in ['wnba', 'nba'])
              http
                  .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/$leagueId/scoreboard'))
                  .timeout(_fetchTimeout)
                  .catchError((_) => http.Response('', 500)),
          ]);
          for (final res in responses) {
            if (res.statusCode == 200) {
              final data = json.decode(res.body);
              allEvents.addAll(data['events'] as List? ?? []);
            }
          }
        }

        if (sport == Sport.tennis) {
          final responses = await Future.wait([
            for (final leagueId in ['atp', 'wta'])
              http
                  .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/tennis/$leagueId/scoreboard'))
                  .timeout(_fetchTimeout)
                  .catchError((_) => http.Response('', 500)),
          ]);
          for (final res in responses) {
            if (res.statusCode == 200) {
              final data = json.decode(res.body);
              allEvents.addAll(data['events'] as List? ?? []);
            }
          }
        }
        
        if (allEvents.isEmpty) return fixtures;
        
        return await Future.wait(fixtures.map((fixture) async {
          var espnEvent = allEvents.firstWhere(
            (e) => fixture.id == e['id'] || _matchesEspnEvent(fixture, e),
            orElse: () => null,
          );

          if (espnEvent == null && (fixture.id == 'wimbledon_mens_final_26' || fixture.id == 'wimbledon_womens_final_26')) {
            try {
              // For mens we need atp, for womens we need wta
              final url = fixture.id == 'wimbledon_mens_final_26'
                  ? 'https://site.api.espn.com/apis/site/v2/sports/tennis/atp/scoreboard?dates=20240714'
                  : 'https://site.api.espn.com/apis/site/v2/sports/tennis/wta/scoreboard?dates=20240713';
              
              final wRes2 = await http.get(Uri.parse(url)).timeout(_fetchTimeout);
              if (wRes2.statusCode == 200) {
                final wData = json.decode(wRes2.body);
                final wEvents = wData['events'] as List?;
                if (wEvents != null) {
                  final searchName = fixture.id == 'wimbledon_mens_final_26' ? 'Alcaraz' : 'Krejcikova';
                  espnEvent = wEvents.firstWhere(
                    (e) => e['name']?.toString().contains(searchName) ?? false,
                    orElse: () => null,
                  );
                }
              }
            } catch (_) {}
          }

          if (espnEvent == null && int.tryParse(fixture.id) != null) {
            try {
              final sportStr = fixture.sport == Sport.football 
                  ? 'soccer/fifa.world' 
                  : fixture.sport == Sport.basketball
                      ? 'basketball/wnba'
                      : fixture.sport == Sport.tennis
                          ? 'tennis/${fixture.leagueId}'
                          : 'cricket/${fixture.leagueId}';
              final summaryRes = await http.get(Uri.parse(
                'https://site.api.espn.com/apis/site/v2/sports/$sportStr/summary?event=${fixture.id}'
              )).timeout(_fetchTimeout);
              if (summaryRes.statusCode == 200) {
                final summaryData = json.decode(summaryRes.body);
                final header = summaryData['header'];
                if (header != null) {
                   final comps = header['competitions'] as List?;
                   if (comps != null && comps.isNotEmpty) {
                     espnEvent = {
                       'id': fixture.id,
                       'competitions': comps,
                       'status': comps[0]['status'] ?? header['status'],
                     };
                   }
                }
              }
            } catch (_) {}
          }

          if (espnEvent == null) return fixture;
          return await _enrichFixtureWithEspnData(fixture, espnEvent);
        }));
    } catch (_) {
      return fixtures;
    }
  }

  bool _matchesEspnEvent(SportMatch fixture, dynamic event) {
    final name = event['name']?.toString().toLowerCase() ?? '';
    final shortName = event['shortName']?.toString().toLowerCase() ?? '';
    final home = fixture.home.name.toLowerCase();
    final away = fixture.away.name.toLowerCase();

    // Just basic matching for ESPN event "Brazil vs. Norway" etc
    return (name.contains(home) || shortName.contains(home)) &&
        (name.contains(away) || shortName.contains(away));
  }

  Future<SportMatch> _enrichFixtureWithEspnData(SportMatch fixture, dynamic event) async {
    dynamic comp;
    if (event['competitions'] != null && event['competitions'].isNotEmpty) {
      comp = event['competitions'][0];
    } else if (event['groupings'] != null) {
      // For tennis, competitions are often inside groupings
      for (final grouping in event['groupings']) {
        if (grouping['competitions'] != null && grouping['competitions'].isNotEmpty) {
          // If we are looking for a specific player (e.g. Alcaraz)
          if (fixture.id == 'wimbledon_mens_final_26' || fixture.id == 'wimbledon_womens_final_26') {
             final searchStr = fixture.id == 'wimbledon_mens_final_26' ? 'Alcaraz' : 'Krejcikova';
             comp = (grouping['competitions'] as List).firstWhere(
                 (c) => json.encode(c).contains(searchStr), 
                 orElse: () => grouping['competitions'][0]
             );
             if (comp != null && json.encode(comp).contains(searchStr)) break;
          } else {
             comp = grouping['competitions'][0];
             break;
          }
        }
      }
    }

    if (comp == null) return fixture;

    final competitors = comp['competitors'] as List;
    final homeTeamData = competitors.firstWhere(
      (c) => c['homeAway'] == 'home',
      orElse: () => competitors[0],
    );
    final awayTeamData = competitors.firstWhere(
      (c) => c['homeAway'] == 'away',
      orElse: () => competitors.length > 1 ? competitors[1] : competitors[0],
    );

    final String? stateStr = event['status']?['type']?['state'];
    final bool isPreMatch = stateStr == 'pre';

    MatchStatus? newStatus;
    if (stateStr == 'pre') {
      newStatus = MatchStatus.upcoming;
    } else if (stateStr == 'in') {
      newStatus = MatchStatus.live;
    } else if (stateStr == 'post') {
      newStatus = MatchStatus.finished;
    }

    String? homeScore = isPreMatch ? null : homeTeamData['score']?.toString();
    String? awayScore = isPreMatch ? null : awayTeamData['score']?.toString();
    // Tennis competitors never carry a top-level `score` (unlike football/
    // basketball) — only per-set `linescores`. Derive the headline "sets won"
    // score (e.g. "2"-"0") from the sets themselves so it isn't left null.
    if (!isPreMatch &&
        fixture.sport == Sport.tennis &&
        (homeScore == null || awayScore == null)) {
      final hLinescores = homeTeamData['linescores'] as List? ?? [];
      final aLinescores = awayTeamData['linescores'] as List? ?? [];
      if (hLinescores.isNotEmpty || aLinescores.isNotEmpty) {
        homeScore = hLinescores.where((s) => s['winner'] == true).length.toString();
        awayScore = aLinescores.where((s) => s['winner'] == true).length.toString();
      }
    }

    final statusText = event['status']?['type']?['description'] ?? 'Finished';
    final clock = event['status']?['displayClock']?.toString();
    final String statusNote = (statusText == 'In Progress' && clock != null)
        ? clock
        : statusText;

    final details = comp['details'] as List? ?? [];
    List<MatchEvent> timelineEvents = [];

    // Fallback: use 'details' from the scoreboard API if summary doesn't load
    for (var detail in details) {
      final isHome =
          detail['team'] != null && detail['team']['id'] == homeTeamData['id'];
      final athletes = detail['athletesInvolved'] as List?;
      final athleteName = athletes != null && athletes.isNotEmpty
          ? _getAthleteName(athletes[0])
          : 'Unknown';
      final clockTime = detail['clock'] != null
          ? detail['clock']['displayValue']?.toString()
          : null;

      bool isGoal = detail['scoreValue'] == 1;
      bool isYellow = detail['yellowCard'] == true;
      bool isRed = detail['redCard'] == true;

      MatchEventType? type;
      if (isGoal) {
        type = MatchEventType.goal;
      } else if (isRed) {
        type = MatchEventType.redCard;
      } else if (isYellow) {
        type = MatchEventType.yellowCard;
      }

      if (type != null) {
        timelineEvents.add(
          MatchEvent(
            minute: _minuteFromClock(clockTime),
            isHomeTeam: isHome,
            playerName: athleteName,
            type: type,
          ),
        );
      }
    }

    MatchLineup? homeLineupData;
    MatchLineup? awayLineupData;
    List<MatchCommentary>? parsedCommentary;
    CricketScorecard? parsedScorecard;
    BasketballScorecard? parsedBasketballScorecard;
    TennisScorecard? parsedTennisScorecard;

    try {
      final summaryUrl = fixture.sport == Sport.football
          ? 'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/summary?event=${event['id']}'
          : fixture.sport == Sport.basketball
              ? 'https://site.api.espn.com/apis/site/v2/sports/basketball/${fixture.leagueId}/summary?event=${event['id']}'
              : fixture.sport == Sport.tennis
                  ? 'https://site.api.espn.com/apis/site/v2/sports/tennis/${fixture.leagueId}/summary?event=${event['id']}'
                  : 'https://site.api.espn.com/apis/site/v2/sports/cricket/${fixture.leagueId}/summary?event=${event['id']}';
            
      final summaryRes = await http.get(Uri.parse(summaryUrl)).timeout(_fetchTimeout);
      if (summaryRes.statusCode == 200) {
        final summaryData = json.decode(summaryRes.body);
        final rosters = summaryData['rosters'] as List?;
        if (rosters != null && rosters.length >= 2) {
          // rosters usually has home at index 0 or 1 based on homeAway
          final r1 = rosters[0];
          final r2 = rosters[1];
          final r1IsHome = r1['homeAway'] == 'home';
          
          final homeRoster = r1IsHome ? r1 : r2;
          final awayRoster = r1IsHome ? r2 : r1;
          
          homeLineupData = _parseLineup(homeRoster);
          awayLineupData = _parseLineup(awayRoster);
        }

        if (fixture.sport == Sport.cricket) {
          parsedScorecard = _parseCricketScorecard(summaryData);
          
          final pbpUrl = 'https://site.api.espn.com/apis/site/v2/sports/cricket/${fixture.leagueId}/playbyplay?event=${event['id']}&limit=1000';
          final pbpRes = await http.get(Uri.parse(pbpUrl)).timeout(_fetchTimeout);
          if (pbpRes.statusCode == 200) {
            final pbpData = json.decode(pbpRes.body);
            final commObj = pbpData['commentary'] as Map?;
            if (commObj != null && commObj.containsKey('items')) {
              final items = commObj['items'] as List?;
              if (items != null && items.isNotEmpty) {
                parsedCommentary = _parseCricketCommentary(items);
              }
            }
          }
        }

        if (fixture.sport == Sport.basketball) {
          final playersData = summaryData['boxscore']?['players'] as List?;
          if (playersData != null && playersData.length >= 2) {
             final t1 = playersData[0];
             final t2 = playersData[1];
             final t1IsHome = t1['team']?['id'] == homeTeamData['id'];
             
             final homePlayers = t1IsHome ? t1 : t2;
             final awayPlayers = t1IsHome ? t2 : t1;

             homeLineupData = _parseBasketballLineup(homePlayers);
             awayLineupData = _parseBasketballLineup(awayPlayers);
          }

          parsedBasketballScorecard = _parseBasketballScorecard(summaryData);

          final pbpUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/${fixture.leagueId}/playbyplay?event=${event['id']}&limit=1000';
          final pbpRes = await http.get(Uri.parse(pbpUrl)).timeout(_fetchTimeout);
          if (pbpRes.statusCode == 200) {
            final pbpData = json.decode(pbpRes.body);
            final items = pbpData['plays'] as List?;
            if (items != null && items.isNotEmpty) {
              parsedCommentary = _parseBasketballCommentary(items);
            }
          }
        }

        final keyEvents = summaryData['keyEvents'] as List?;
        if (keyEvents != null && keyEvents.isNotEmpty) {
          timelineEvents = _parseKeyEvents(keyEvents, homeTeamData['id']?.toString() ?? '');
        }

        if (fixture.sport != Sport.cricket && fixture.sport != Sport.basketball) {
          final commentaryList = summaryData['commentary'] as List?;
          if (commentaryList != null && commentaryList.isNotEmpty) {
            parsedCommentary = _parseCommentary(commentaryList);
          }
        }
      }

      if (fixture.sport == Sport.tennis) {
        parsedTennisScorecard = _parseTennisScorecard(comp);
      }
    } catch (_) {}

    return fixture.copyWith(
      status: newStatus,
      homeScore: homeScore,
      awayScore: awayScore,
      liveStatusNote: statusNote,
      timelineEvents: timelineEvents,
      homeLineup: homeLineupData ?? fixture.homeLineup ?? _getMockLineup(true, fixture.sport),
      awayLineup: awayLineupData ?? fixture.awayLineup ?? _getMockLineup(false, fixture.sport),
      commentary: parsedCommentary ?? fixture.commentary,
      cricketScorecard: parsedScorecard,
      basketballScorecard: parsedBasketballScorecard,
      tennisScorecard: parsedTennisScorecard ?? fixture.tennisScorecard,
      clearHomeScore: homeScore == null,
      clearAwayScore: awayScore == null,
    );
  }

  CricketScorecard? _parseCricketScorecard(dynamic summaryData) {
    try {
      final rosters = summaryData['rosters'] as List?;
      final header = summaryData['header'];
      if (rosters == null || header == null) return null;

      final comp = header['competitions']?[0];
      if (comp == null) return null;

      final competitors = comp['competitors'] as List?;
      if (competitors == null || competitors.length < 2) return null;

      String statStr(List? stats, String name) {
        if (stats == null) return '';
        try {
          final s = stats.firstWhere((e) => e is Map && e['name'] == name, orElse: () => null);
          if (s == null) return '';
          return s['displayValue']?.toString() ?? '';
        } catch (_) { return ''; }
      }

      int statInt(List? stats, String name) => int.tryParse(statStr(stats, name)) ?? 0;
      double statDouble(List? stats, String name) => double.tryParse(statStr(stats, name)) ?? 0.0;

      List<CricketInnings> inningsList = [];

      for (int p = 1; p <= 4; p++) {
        dynamic battingRoster;
        dynamic bowlingRoster;

        for (var r in rosters) {
          bool batted = false;
          final rosterList = r['roster'] as List? ?? [];
          for (var player in rosterList) {
            final linescores = player['linescores'] as List?;
            final ls = linescores?.firstWhere((l) => l['period'] == p, orElse: () => null);
            if (ls != null) {
              final statsArr = ls['statistics']?['categories'] as List?;
              final general = statsArr?.firstWhere((c) => c is Map && c['name'] == 'general', orElse: () => null);
              if (general != null && general['stats'] is List) {
                final b = statInt(general['stats'], 'batted');
                if (b == 1 || statInt(general['stats'], 'battingPosition') > 0) {
                  batted = true;
                  break;
                }
              }
            }
          }
          if (batted) {
            battingRoster = r;
          } else {
            bowlingRoster = r;
          }
        }

        if (battingRoster != null) {
          final teamData = competitors.firstWhere((c) => c['team']?['id'] == battingRoster['team']?['id'], orElse: () => null);
          final ls = (teamData?['linescores'] as List?)?.firstWhere((l) => l['period'] == p, orElse: () => null);
          String scoreStr = '';
          String extras = '';
          List<String> parsedFow = [];
          
          if (ls != null) {
            scoreStr = ls['score']?.toString() ?? ls['displayValue']?.toString() ?? '';
            
            final statsArr = ls['statistics']?['categories'] as List?;
            final generalStats = statsArr?.firstWhere((c) => c is Map && c['name'] == 'general', orElse: () => null);
            if (generalStats != null && generalStats['stats'] is List) {
               final e = (generalStats['stats'] as List).firstWhere((s) => s['name'] == 'extras', orElse: () => null);
               if (e != null) extras = e['displayValue']?.toString() ?? '';
            }
            
            final fowList = ls['fow'] as List?;
            if (fowList != null) {
               for (var fow in fowList) {
                  final runs = fow['runs']?.toString() ?? '';
                  final wkt = fow['wicketNumber']?.toString() ?? '';
                  final over = fow['wicketOver']?.toString() ?? '';
                  final athlete = _getAthleteName(fow['athlete']);
                  parsedFow.add('$runs-$wkt ($athlete, $over ov)');
               }
            }
          }

          List<CricketBatter> batters = [];
          List<String> dnb = [];
          List<CricketBowler> bowlers = [];

          for (var player in battingRoster['roster'] as List? ?? []) {
            final plLs = (player['linescores'] as List?)?.firstWhere((l) => l['period'] == p, orElse: () => null);
            if (plLs != null) {
              final general = (plLs['statistics']?['categories'] as List?)?.firstWhere((c) => c is Map && c['name'] == 'general', orElse: () => null);
              if (general != null && general['stats'] is List) {
                final b = statInt(general['stats'], 'batted');
                final name = _getAthleteName(player['athlete']);
                if (b == 1 || statInt(general['stats'], 'runs') > 0) {
                  batters.add(CricketBatter(
                    name: name,
                    runs: statInt(general['stats'], 'runs'),
                    balls: statInt(general['stats'], 'ballsFaced'),
                    fours: statInt(general['stats'], 'fours'),
                    sixes: statInt(general['stats'], 'sixes'),
                    strikeRate: statDouble(general['stats'], 'strikeRate'),
                    dismissalText: plLs['statistics']?['batting']?['outDetails']?['shortText']?.toString(),
                  ));
                } else if (statInt(general['stats'], 'battingPosition') > 0) {
                  dnb.add(name);
                }
              }
            }
          }

          if (bowlingRoster != null) {
            for (var player in bowlingRoster['roster'] as List? ?? []) {
              final plLs = (player['linescores'] as List?)?.firstWhere((l) => l['period'] == p, orElse: () => null);
              if (plLs != null) {
                final general = (plLs['statistics']?['categories'] as List?)?.firstWhere((c) => c is Map && c['name'] == 'general', orElse: () => null);
                if (general != null && general['stats'] is List) {
                  final bowled = statInt(general['stats'], 'bowled');
                  if (bowled == 1) {
                    bowlers.add(CricketBowler(
                      name: _getAthleteName(player['athlete']),
                      overs: statDouble(general['stats'], 'overs'),
                      maidens: statInt(general['stats'], 'maidens'),
                      runs: statInt(general['stats'], 'conceded'),
                      wickets: statInt(general['stats'], 'wickets'),
                      economyRate: statDouble(general['stats'], 'economyRate'),
                    ));
                  }
                }
              }
            }
          }

          if (batters.isNotEmpty || bowlers.isNotEmpty) {
            inningsList.add(CricketInnings(
              teamName: battingRoster['team']?['displayName']?.toString() ?? 'Unknown Team',
              scoreText: scoreStr,
              batters: batters,
              bowlers: bowlers,
              didNotBat: dnb,
              extras: extras,
              fow: parsedFow,
            ));
          }
        }
      }
      
      if (inningsList.isNotEmpty) {
        return CricketScorecard(innings: inningsList);
      }
    } catch (_) {}
    return null;
  }

  BasketballScorecard? _parseBasketballScorecard(dynamic summaryData) {
    try {
      final boxscore = summaryData['boxscore'];
      final header = summaryData['header'];
      if (boxscore == null || header == null) return null;

      final comps = header['competitions'] as List?;
      if (comps == null || comps.isEmpty) return null;
      final competitors = comps[0]['competitors'] as List?;
      if (competitors == null || competitors.length < 2) return null;

      BasketballLinescores parseLinescores() {
        List<int> home = [];
        List<int> away = [];
        int homeTot = 0;
        int awayTot = 0;
        
        final homeComp = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => competitors[0]);
        final awayComp = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => competitors[1]);
        
        homeTot = int.tryParse(homeComp['score']?.toString() ?? '0') ?? 0;
        awayTot = int.tryParse(awayComp['score']?.toString() ?? '0') ?? 0;
        
        final homeLs = homeComp['linescores'] as List? ?? [];
        for (var ls in homeLs) {
          home.add(int.tryParse(ls['value']?.toString() ?? '0') ?? 0);
        }
        final awayLs = awayComp['linescores'] as List? ?? [];
        for (var ls in awayLs) {
          away.add(int.tryParse(ls['value']?.toString() ?? '0') ?? 0);
        }
        
        return BasketballLinescores(
          homeScores: home,
          awayScores: away,
          homeTotal: homeTot,
          awayTotal: awayTot,
          periodCount: home.isNotEmpty ? home.length : 4,
        );
      }

      BasketballTeamBoxscore parseTeamBoxscore(bool isHome) {
        final teamId = competitors.firstWhere((c) => c['homeAway'] == (isHome ? 'home' : 'away'))['team']['id'];
        
        final teams = boxscore['teams'] as List? ?? [];
        final teamStatsData = teams.firstWhere((t) => t['team']['id'] == teamId, orElse: () => null);
        
        final playersData = boxscore['players'] as List? ?? [];
        final teamPlayersData = playersData.firstWhere((p) => p['team']['id'] == teamId, orElse: () => null);
        
        String statVal(List stats, String name) {
          final s = stats.firstWhere((st) => st['name'] == name, orElse: () => null);
          return s?['displayValue']?.toString() ?? '';
        }
        
        BasketballTeamStats parseTeamStats(dynamic data) {
          if (data == null) return const BasketballTeamStats(fgMadeApt: '', fgPct: 0, tpMadeApt: '', tpPct: 0, ftMadeApt: '', ftPct: 0, rebounds: 0, assists: 0, steals: 0, blocks: 0, turnovers: 0);
          final stats = data['statistics'] as List? ?? [];
          return BasketballTeamStats(
            fgMadeApt: statVal(stats, 'fieldGoalsMade-fieldGoalsAttempted'),
            fgPct: double.tryParse(statVal(stats, 'fieldGoalPct')) ?? 0.0,
            tpMadeApt: statVal(stats, 'threePointFieldGoalsMade-threePointFieldGoalsAttempted'),
            tpPct: double.tryParse(statVal(stats, 'threePointFieldGoalPct')) ?? 0.0,
            ftMadeApt: statVal(stats, 'freeThrowsMade-freeThrowsAttempted'),
            ftPct: double.tryParse(statVal(stats, 'freeThrowPct')) ?? 0.0,
            rebounds: int.tryParse(statVal(stats, 'totalRebounds')) ?? 0,
            assists: int.tryParse(statVal(stats, 'assists')) ?? 0,
            steals: int.tryParse(statVal(stats, 'steals')) ?? 0,
            blocks: int.tryParse(statVal(stats, 'blocks')) ?? 0,
            turnovers: int.tryParse(statVal(stats, 'totalTurnovers')) ?? 0,
          );
        }
        
        List<BasketballPlayerStat> parsePlayers(dynamic data) {
          if (data == null) return [];
          List<BasketballPlayerStat> parsed = [];
          final statsList = data['statistics'] as List? ?? [];
          if (statsList.isEmpty) return parsed;
          
          final keys = statsList[0]['labels'] as List? ?? [];
          final athletes = statsList[0]['athletes'] as List? ?? [];
          
          int idx(String key) => keys.indexOf(key);
          
          for (var ath in athletes) {
            final st = ath['stats'] as List? ?? [];
            if (st.isEmpty) continue;
            
            String sv(String k) {
              final i = idx(k);
              if (i >= 0 && i < st.length) return st[i]?.toString() ?? '';
              return '';
            }
            
            parsed.add(BasketballPlayerStat(
              name: ath['athlete']?['displayName']?.toString() ?? '',
              starter: ath['starter'] == true,
              minutes: sv('MIN'),
              points: int.tryParse(sv('PTS')) ?? 0,
              fg: sv('FG'),
              tp: sv('3PT'),
              ft: sv('FT'),
              rebounds: int.tryParse(sv('REB')) ?? 0,
              assists: int.tryParse(sv('AST')) ?? 0,
              turnovers: int.tryParse(sv('TO')) ?? 0,
              steals: int.tryParse(sv('STL')) ?? 0,
              blocks: int.tryParse(sv('BLK')) ?? 0,
              fouls: int.tryParse(sv('PF')) ?? 0,
              plusMinus: sv('+/-'),
            ));
          }
          return parsed;
        }

        final tStats = parseTeamStats(teamStatsData);
        final tPlayers = parsePlayers(teamPlayersData);
        final tName = teamStatsData?['team']?['displayName']?.toString() ?? teamPlayersData?['team']?['displayName']?.toString() ?? '';
        
        return BasketballTeamBoxscore(
          teamName: tName,
          teamId: teamId,
          stats: tStats,
          players: tPlayers,
        );
      }

      return BasketballScorecard(
        homeBoxscore: parseTeamBoxscore(true),
        awayBoxscore: parseTeamBoxscore(false),
        linescores: parseLinescores(),
      );
    } catch (_) {}
    return null;
  }

  MatchLineup _parseLineup(dynamic rosterData) {
    final formation = rosterData['formation']?.toString() ?? '4-3-3';
    final rosterList = rosterData['roster'] as List? ?? [];
    
    final starters = rosterList.where((p) => p['starter'] == true).toList();
    final bench = rosterList.where((p) => p['starter'] == false).toList();
    
    List<MatchPlayer> startingXI = [];
    for (var p in starters) {
      final athlete = p['athlete'];
      if (athlete == null) continue;
      startingXI.add(MatchPlayer(
        id: athlete['id']?.toString() ?? '',
        name: _getAthleteName(athlete),
        number: int.tryParse(p['jersey']?.toString() ?? '') ?? 0,
        role: p['position']?['name']?.toString(),
        rating: 6.0,
      ));
    }

    List<MatchPlayer> substitutes = [];
    for (var p in bench) {
      final athlete = p['athlete'];
      if (athlete == null) continue;
      substitutes.add(MatchPlayer(
        id: athlete['id']?.toString() ?? '',
        name: _getAthleteName(athlete),
        number: int.tryParse(p['jersey']?.toString() ?? '') ?? 0,
        role: p['position']?['name']?.toString(),
        rating: 6.0,
      ));
    }
    
    return MatchLineup(
      formation: formation,
      startingXI: startingXI,
      substitutes: substitutes,
    );
  }

  MatchLineup _parseBasketballLineup(dynamic playersData) {
    final statsList = playersData['statistics'] as List?;
    final athletesList = (statsList != null && statsList.isNotEmpty) 
        ? statsList[0]['athletes'] as List? ?? [] 
        : [];
    
    final starters = athletesList.where((p) => p['starter'] == true).toList();
    final bench = athletesList.where((p) => p['starter'] == false).toList();
    
    List<MatchPlayer> startingXI = [];
    for (var p in starters) {
      final athlete = p['athlete'];
      if (athlete == null) continue;
      startingXI.add(MatchPlayer(
        id: athlete['id']?.toString() ?? '',
        name: _getAthleteName(athlete),
        number: int.tryParse(athlete['jersey']?.toString() ?? '') ?? 0,
        role: athlete['position']?['name']?.toString(),
        rating: 6.0,
      ));
    }

    List<MatchPlayer> substitutes = [];
    for (var p in bench) {
      final athlete = p['athlete'];
      if (athlete == null) continue;
      substitutes.add(MatchPlayer(
        id: athlete['id']?.toString() ?? '',
        name: _getAthleteName(athlete),
        number: int.tryParse(athlete['jersey']?.toString() ?? '') ?? 0,
        role: athlete['position']?['name']?.toString(),
        rating: 6.0,
      ));
    }
    
    return MatchLineup(
      formation: '2-2-1',
      startingXI: startingXI,
      substitutes: substitutes,
    );
  }

  List<MatchEvent> _parseKeyEvents(List keyEvents, String homeTeamId) {
    List<MatchEvent> events = [];
    for (var event in keyEvents) {
      final typeStr = event['type']?['type']?.toString() ?? '';
      
      MatchEventType? type;
      if (typeStr.contains('goal')) {
        type = MatchEventType.goal;
      } else if (typeStr == 'yellow-card') {
        type = MatchEventType.yellowCard;
      } else if (typeStr == 'red-card') {
        type = MatchEventType.redCard;
      } else if (typeStr == 'substitution') {
        type = MatchEventType.substitution;
      }

      if (type != null) {
        final teamId = event['team']?['id']?.toString();
        final isHome = teamId == homeTeamId;
        final clock = event['clock']?['displayValue']?.toString();
        
        final participants = event['participants'] as List? ?? [];
        String mainPlayer = 'Unknown';
        String? secondaryPlayer;
        
        if (participants.isNotEmpty) {
          mainPlayer = _getAthleteName(participants[0]['athlete']);
          if (participants.length > 1) {
            secondaryPlayer = _getAthleteName(participants[1]['athlete']);
          }
        }
        
        events.add(MatchEvent(
          minute: _minuteFromClock(clock),
          isHomeTeam: isHome,
          playerName: mainPlayer,
          secondaryPlayerName: secondaryPlayer,
          type: type,
        ));
      }
    }
    
    // Ensure they are ordered chronologically (or reverse if desired, UI handles it)
    return events;
  }

  List<MatchCommentary> _parseCommentary(List commentaryData) {
    List<MatchCommentary> result = [];
    for (var item in commentaryData) {
      final text = item['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      final timeStr = item['time']?['displayValue']?.toString() ?? '';
      result.add(MatchCommentary(minute: timeStr, text: text));
    }
    return result.reversed.toList();
  }

  List<MatchCommentary> _parseCricketCommentary(List commentaryData) {
    List<MatchCommentary> result = [];
    for (var item in commentaryData) {
      String text = item['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      
      // Strip basic HTML tags
      text = text.replaceAll(RegExp(r'<[^>]*>'), '');
      
      // Cricket uses "over.actual" or fallback to "period"
      String over = item['over']?['actual']?.toString() ?? item['period']?.toString() ?? '';
      
      final shortText = item['shortText']?.toString();
      final scoreValue = int.tryParse(item['scoreValue']?.toString() ?? '');
      final isWicket = item['dismissal']?['dismissal'] == true;
      
      result.add(MatchCommentary(
        minute: over,
        text: text,
        shortText: shortText,
        scoreValue: scoreValue,
        isWicket: isWicket,
      ));
    }
    return result;
  }

  List<MatchCommentary> _parseBasketballCommentary(List commentaryData) {
    List<MatchCommentary> result = [];
    for (var item in commentaryData) {
      String text = item['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      
      String clock = item['clock']?['displayValue']?.toString() ?? '';
      String period = item['period']?['displayValue']?.toString() ?? '';
      String minute = '$period $clock';
      
      final scoreValue = int.tryParse(item['scoreValue']?.toString() ?? '');
      
      result.add(MatchCommentary(
        minute: minute,
        text: text,
        scoreValue: scoreValue,
      ));
    }
    return result;
  }

  int _minuteFromClock(String? clock) {
    if (clock == null || clock.isEmpty) return 0;
    final match = RegExp(r'\d+').firstMatch(clock);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  MatchLineup _getMockLineup(bool isHome, Sport sport) {
    if (sport == Sport.basketball) {
      return MatchLineup(
        formation: '2-2',
        startingXI: [
          MatchPlayer(id: '1', name: isHome ? 'Point Guard' : 'Point Guard', number: 1, rating: 8.5),
          MatchPlayer(id: '2', name: isHome ? 'Shooting Guard' : 'Shooting Guard', number: 2, rating: 7.2),
          MatchPlayer(id: '3', name: isHome ? 'Small Forward' : 'Small Forward', number: 3, rating: 9.0),
          MatchPlayer(id: '4', name: isHome ? 'Power Forward' : 'Power Forward', number: 4, rating: 6.8),
          MatchPlayer(id: '5', name: isHome ? 'Center' : 'Center', number: 5, rating: 8.1),
        ],
        substitutes: [
          MatchPlayer(id: '6', name: 'Bench 1', number: 6),
          MatchPlayer(id: '7', name: 'Bench 2', number: 7),
          MatchPlayer(id: '8', name: 'Bench 3', number: 8),
          MatchPlayer(id: '9', name: 'Bench 4', number: 9),
        ],
      );
    }
    return MatchLineup(
      formation: '4-3-3',
      startingXI: [
        MatchPlayer(
          id: '1',
          name: isHome ? 'Rangel' : 'Pickford',
          number: 1,
          rating: 5.5,
        ),
        MatchPlayer(
          id: '2',
          name: isHome ? 'Sánchez' : 'Walker',
          number: 2,
          rating: 6.2,
        ),
        MatchPlayer(
          id: '3',
          name: isHome ? 'Montes' : 'Stones',
          number: 3,
          rating: 5.7,
          isCaptain: isHome,
        ),
        MatchPlayer(
          id: '4',
          name: isHome ? 'Vásquez' : 'Maguire',
          number: 5,
          rating: 7.0,
        ),
        MatchPlayer(
          id: '5',
          name: isHome ? 'Gallardo' : 'Shaw',
          number: 23,
          rating: 6.3,
        ),
        MatchPlayer(
          id: '6',
          name: isHome ? 'Mora' : 'Rice',
          number: 19,
          rating: 5.3,
        ),
        MatchPlayer(
          id: '7',
          name: isHome ? 'Lira' : 'Bellingham',
          number: 6,
          rating: 6.8,
        ),
        MatchPlayer(
          id: '8',
          name: isHome ? 'Romo' : 'Henderson',
          number: 7,
          rating: 6.2,
        ),
        MatchPlayer(
          id: '9',
          name: isHome ? 'Alvarado' : 'Saka',
          number: 25,
          rating: 7.7,
        ),
        MatchPlayer(
          id: '10',
          name: isHome ? 'Jiménez' : 'Kane',
          number: 9,
          rating: 7.4,
          isCaptain: !isHome,
        ),
        MatchPlayer(
          id: '11',
          name: isHome ? 'Quiñones' : 'Sterling',
          number: 16,
          rating: 7.6,
        ),
      ],
    );
  }

  TennisScorecard? _parseTennisScorecard(dynamic comp) {
    try {
      final competitors = comp['competitors'] as List?;
      if (competitors == null || competitors.length < 2) return null;
      
      final c1 = competitors[0];
      final c2 = competitors[1];
      
      final homeCompetitor = c1['homeAway'] == 'home' ? c1 : c2;
      final awayCompetitor = c1['homeAway'] == 'home' ? c2 : c1;
      
      final homeLinescores = homeCompetitor['linescores'] as List? ?? [];
      final awayLinescores = awayCompetitor['linescores'] as List? ?? [];
      
      final numSets = [homeLinescores.length, awayLinescores.length].fold<int>(0, (m, e) => e > m ? e : m);
      
      List<TennisSet> sets = [];
      for (int i = 0; i < numSets; i++) {
        final hSet = i < homeLinescores.length ? homeLinescores[i] : null;
        final aSet = i < awayLinescores.length ? awayLinescores[i] : null;
        
        final hScore = (hSet != null ? (hSet['value'] as num?)?.toInt() : null) ?? 0;
        final aScore = (aSet != null ? (aSet['value'] as num?)?.toInt() : null) ?? 0;
        
        final hTiebreak = hSet != null ? (hSet['tiebreak'] as num?)?.toInt() : null;
        final aTiebreak = aSet != null ? (aSet['tiebreak'] as num?)?.toInt() : null;
        
        final hWinner = hSet != null && hSet['winner'] == true;
        final aWinner = aSet != null && aSet['winner'] == true;
        
        sets.add(TennisSet(
          homeScore: hScore,
          awayScore: aScore,
          homeTiebreak: hTiebreak,
          awayTiebreak: aTiebreak,
          isHomeWinner: hWinner,
          isAwayWinner: aWinner,
        ));
      }
      
      if (sets.isEmpty) return null;
      return TennisScorecard(sets: sets);
    } catch (_) {
      return null;
    }
  }
}


