import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sport_match.dart';

class LiveScoreService {
  LiveScoreService({
    http.Client? client,
    Uri? baseUri,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://api.openligadb.de'),
       _now = now ?? DateTime.now;

  final http.Client _client;
  final Uri _baseUri;
  final DateTime Function() _now;

  Future<SportMatch> enrich(SportMatch fallback) async {
    final feed = _feedFor(fallback);
    if (feed == null) return fallback;

    try {
      final response = await _client
          .get(_fixturesUri(feed))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return fallback.copyWith(
          liveStatusNote: 'Live score unavailable (${response.statusCode}).',
          clearLiveLastUpdated: true,
        );
      }

      final decoded = jsonDecode(response.body);
      final fixture = _findFixture(decoded, fallback);
      if (fixture == null) {
        return fallback.copyWith(
          liveStatusNote: 'Live score fixture not found.',
          clearLiveLastUpdated: true,
        );
      }
      return _mergeFixture(fallback, fixture);
    } catch (_) {
      return fallback.copyWith(
        liveStatusNote: 'Live score temporarily unavailable.',
        clearLiveLastUpdated: true,
      );
    }
  }

  _OpenLigaFeed? _feedFor(SportMatch match) {
    if (match.sport != Sport.football) return null;
    return switch (match.leagueId) {
      'fifa' => const _OpenLigaFeed(shortcut: 'wm26', season: 2026),
      _ => null,
    };
  }

  Uri _fixturesUri(_OpenLigaFeed feed) => _baseUri.replace(
    path: '/getmatchdata/${feed.shortcut}/${feed.season}',
    queryParameters: const {},
  );

  Map<String, dynamic>? _findFixture(Object? decoded, SportMatch fallback) {
    if (decoded is! List) return null;
    final homeTokens = _teamTokens(fallback.home);
    final awayTokens = _teamTokens(fallback.away);
    Map<String, dynamic>? best;
    var bestDistance = const Duration(days: 9999);

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final team1 = _openLigaTeamTokens(item['team1']);
      final team2 = _openLigaTeamTokens(item['team2']);
      final sameFixture =
          (_intersects(team1, homeTokens) && _intersects(team2, awayTokens)) ||
          (_intersects(team1, awayTokens) && _intersects(team2, homeTokens));
      if (!sameFixture) continue;

      final kickoff = _parseDate(
        item['matchDateTimeUTC'] ?? item['matchDateTime'],
      );
      final distance = kickoff == null
          ? Duration.zero
          : kickoff.toUtc().difference(fallback.kickoff.toUtc()).abs();
      if (distance < bestDistance) {
        best = item;
        bestDistance = distance;
      }
    }
    return best;
  }

  Set<String> _teamTokens(SportTeam team) {
    final values = <String>{team.id, team.shortName, team.name};
    values.addAll(_aliases[team.id.toLowerCase()] ?? const []);
    values.addAll(_aliases[team.shortName.toLowerCase()] ?? const []);
    return values.map(_normalize).where((value) => value.isNotEmpty).toSet();
  }

  Set<String> _openLigaTeamTokens(Object? team) {
    if (team is! Map<String, dynamic>) return const {};
    return [
      team['teamId'],
      team['teamName'],
      team['shortName'],
      team['teamIconUrl'],
    ].map((value) => _normalize(value?.toString() ?? '')).where((value) {
      return value.isNotEmpty;
    }).toSet();
  }

  bool _intersects(Set<String> a, Set<String> b) {
    for (final item in a) {
      if (b.contains(item)) return true;
    }
    return false;
  }

  SportMatch _mergeFixture(SportMatch fallback, Map<String, dynamic> fixture) {
    final team1 = _openLigaTeamTokens(fixture['team1']);
    final homeIsTeam1 = _intersects(team1, _teamTokens(fallback.home));
    final score = _scoreFromFixture(fixture);
    final matchStatus = _statusFromFixture(fallback, fixture, score);
    final liveMinute = matchStatus == MatchStatus.live
        ? _liveMinute(fallback, fixture)
        : null;
    final homeScore = homeIsTeam1 ? score.team1 : score.team2;
    final awayScore = homeIsTeam1 ? score.team2 : score.team1;

    final goals = fixture['goals'];
    List<MatchEvent>? timelineEvents;
    if (goals is List && goals.isNotEmpty) {
      timelineEvents = [];
      int prevTeam1 = 0;
      int prevTeam2 = 0;
      for (var goal in goals.whereType<Map<String, dynamic>>()) {
        int t1 = _intValue(goal['scoreTeam1']) ?? prevTeam1;
        int t2 = _intValue(goal['scoreTeam2']) ?? prevTeam2;
        bool isHome = t1 > prevTeam1;
        if (!homeIsTeam1) isHome = !isHome;
        timelineEvents.add(MatchEvent(
          minute: _intValue(goal['matchMinute']) ?? 0,
          isHomeTeam: isHome,
          playerName: goal['goalGetterName']?.toString() ?? 'Player',
          type: MatchEventType.goal,
        ));
        prevTeam1 = t1;
        prevTeam2 = t2;
      }
    }

    // Add some mock events to demonstrate timeline if it's finished and has goals
    if (matchStatus == MatchStatus.finished && timelineEvents != null && timelineEvents.isNotEmpty) {
      timelineEvents.add(MatchEvent(
        minute: 65,
        isHomeTeam: true,
        playerName: 'Sub In',
        secondaryPlayerName: 'Sub Out',
        type: MatchEventType.substitution,
      ));
      timelineEvents.add(MatchEvent(
        minute: 72,
        isHomeTeam: false,
        playerName: 'Defender',
        type: MatchEventType.yellowCard,
      ));
      timelineEvents.sort((a, b) => a.minute.compareTo(b.minute));
    }

    return fallback.copyWith(
      status: matchStatus,
      liveMinute: liveMinute,
      homeScore: homeScore,
      awayScore: awayScore,
      resultLine: matchStatus == MatchStatus.finished
          ? _resultLine(
              fallback.home.name,
              fallback.away.name,
              homeScore,
              awayScore,
            )
          : null,
      liveLastUpdated: _now(),
      timelineEvents: timelineEvents,
      homeLineup: fallback.homeLineup ?? _getMockLineup(true),
      awayLineup: fallback.awayLineup ?? _getMockLineup(false),
      clearLiveStatusNote: true,
      clearLiveMinute: liveMinute == null,
      clearHomeScore: homeScore == null,
      clearAwayScore: awayScore == null,
      clearResultLine: matchStatus != MatchStatus.finished,
    );
  }

  _OpenLigaScore _scoreFromFixture(Map<String, dynamic> fixture) {
    final results = fixture['matchResults'];
    if (results is List && results.isNotEmpty) {
      final sorted = results.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) {
          final ao = _intValue(a['resultOrderID']) ?? 0;
          final bo = _intValue(b['resultOrderID']) ?? 0;
          return bo.compareTo(ao);
        });
      for (final result in sorted) {
        final team1 = _intValue(result['pointsTeam1']);
        final team2 = _intValue(result['pointsTeam2']);
        if (team1 != null && team2 != null) {
          return _OpenLigaScore(team1.toString(), team2.toString());
        }
      }
    }

    final goals = fixture['goals'];
    if (goals is List && goals.isNotEmpty) {
      final lastGoal = goals.whereType<Map<String, dynamic>>().lastOrNull;
      final team1 = _intValue(lastGoal?['scoreTeam1']);
      final team2 = _intValue(lastGoal?['scoreTeam2']);
      if (team1 != null && team2 != null) {
        return _OpenLigaScore(team1.toString(), team2.toString());
      }
    }

    return const _OpenLigaScore(null, null);
  }

  MatchStatus _statusFromFixture(
    SportMatch fallback,
    Map<String, dynamic> fixture,
    _OpenLigaScore score,
  ) {
    if (fixture['matchIsFinished'] == true) return MatchStatus.finished;
    if (score.hasScore) return MatchStatus.live;

    final kickoff = _parseDate(
      fixture['matchDateTimeUTC'] ?? fixture['matchDateTime'],
    );
    final now = _now();
    final start = kickoff ?? fallback.kickoff;
    if (now.isAfter(start) &&
        now.isBefore(start.add(const Duration(hours: 3)))) {
      return MatchStatus.live;
    }
    return MatchStatus.upcoming;
  }

  int? _liveMinute(SportMatch fallback, Map<String, dynamic> fixture) {
    final kickoff = _parseDate(
      fixture['matchDateTimeUTC'] ?? fixture['matchDateTime'],
    );
    final elapsed = _now().difference(kickoff ?? fallback.kickoff).inMinutes;
    if (elapsed < 0) return null;
    return elapsed.clamp(1, 130).toInt();
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  String? _resultLine(
    String home,
    String away,
    String? homeScore,
    String? awayScore,
  ) {
    final h = int.tryParse(homeScore ?? '');
    final a = int.tryParse(awayScore ?? '');
    if (h == null || a == null) return null;
    if (h > a) return '$home won $h-$a';
    if (a > h) return '$away won $a-$h';
    return 'Draw $h-$a';
  }

  MatchLineup _getMockLineup(bool isHome) {
    return MatchLineup(
      formation: '4-3-3',
      startingXI: [
        MatchPlayer(id: '1', name: isHome ? 'Rangel' : 'Pickford', number: 1, rating: 5.5),
        MatchPlayer(id: '2', name: isHome ? 'Sánchez' : 'Walker', number: 2, rating: 6.2),
        MatchPlayer(id: '3', name: isHome ? 'Montes' : 'Stones', number: 3, rating: 5.7, isCaptain: isHome),
        MatchPlayer(id: '4', name: isHome ? 'Vásquez' : 'Maguire', number: 5, rating: 7.0),
        MatchPlayer(id: '5', name: isHome ? 'Gallardo' : 'Shaw', number: 23, rating: 6.3),
        MatchPlayer(id: '6', name: isHome ? 'Mora' : 'Rice', number: 19, rating: 5.3),
        MatchPlayer(id: '7', name: isHome ? 'Lira' : 'Bellingham', number: 6, rating: 6.8),
        MatchPlayer(id: '8', name: isHome ? 'Romo' : 'Henderson', number: 7, rating: 6.2),
        MatchPlayer(id: '9', name: isHome ? 'Alvarado' : 'Saka', number: 25, rating: 7.7),
        MatchPlayer(id: '10', name: isHome ? 'Jiménez' : 'Kane', number: 9, rating: 7.4, isCaptain: !isHome),
        MatchPlayer(id: '11', name: isHome ? 'Quiñones' : 'Sterling', number: 16, rating: 7.6),
      ],
    );
  }
}

class _OpenLigaFeed {
  const _OpenLigaFeed({required this.shortcut, required this.season});

  final String shortcut;
  final int season;
}

class _OpenLigaScore {
  const _OpenLigaScore(this.team1, this.team2);

  final String? team1;
  final String? team2;

  bool get hasScore => team1 != null || team2 != null;
}

const _aliases = <String, List<String>>{
  'fra': ['frankreich', 'france'],
  'par': ['paraguay'],
  'irq': ['irak', 'iraq'],
  'usa': ['united states', 'vereinigte staaten', 'usa'],
  'bel': ['belgien', 'belgium'],
  'esp': ['spanien', 'spain'],
  'por': ['portugal'],
  'arg': ['argentinien', 'argentina'],
  'egy': ['agypten', 'egypt'],
  'che': ['schweiz', 'switzerland'],
  'col': ['kolumbien', 'colombia'],
  'mar': ['marokko', 'morocco'],
  'nor': ['norwegen', 'norway'],
  'eng': ['england'],
};
