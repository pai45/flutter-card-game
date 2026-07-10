import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/cricket_scorecard.dart';
import '../models/sport_match.dart';
import '../data/team_colors.dart';
import '../models/basketball_scorecard.dart';

class EspnScoreService {
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



  // Fetches matches for the past 3 days, today, and the next 3 days.
  Future<List<SportMatch>> fetchDynamicMatches() async {
    final List<SportMatch> dynamicMatches = [];
    final now = DateTime.now();
    
    // Fetch from day - 3 to day + 3 (total 7 days)
    for (int i = -3; i <= 3; i++) {
      final date = now.add(Duration(days: i));
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      
      // 1. Fetch Cricket
      try {
        final cricketRes = await http.get(Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel?dates=$dateStr'));
        if (cricketRes.statusCode == 200) {
          final data = json.decode(cricketRes.body);
          final scores = data['scores'] as List? ?? [];
          for (var score in scores) {
            final events = score['events'] as List? ?? [];
            for (var event in events) {
              final match = _parseEventToMatch(event, Sport.cricket, '23810'); // Map to _intl
              if (match != null && !dynamicMatches.any((m) => m.id == match.id)) {
                dynamicMatches.add(match);
              }
            }
          }
        }
      } catch (_) {}

      // 2. Fetch Football (EPL and UEFA Euro)
      final soccerLeagues = ['eng.1', 'uefa.euro'];
      for (var league in soccerLeagues) {
        try {
          final soccerRes = await http.get(Uri.parse(
              'https://site.api.espn.com/apis/site/v2/sports/soccer/$league/scoreboard?dates=$dateStr'));
          if (soccerRes.statusCode == 200) {
            final data = json.decode(soccerRes.body);
            final events = data['events'] as List? ?? [];
            for (var event in events) {
              final match = _parseEventToMatch(event, Sport.football, 'fifa'); // Map to _fifa
              if (match != null && !dynamicMatches.any((m) => m.id == match.id)) {
                dynamicMatches.add(match);
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fetch Basketball (WNBA)
      try {
        final wnbaRes = await http.get(Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard?dates=$dateStr'));
        if (wnbaRes.statusCode == 200) {
          final data = json.decode(wnbaRes.body);
          final events = data['events'] as List? ?? [];
          for (var event in events) {
            final match = _parseEventToMatch(event, Sport.basketball, 'wnba');
            if (match != null && !dynamicMatches.any((m) => m.id == match.id)) {
              dynamicMatches.add(match);
            }
          }
        }
      } catch (_) {}
    }
    return dynamicMatches;
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
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SportMatch>> enrichAll(List<SportMatch> fixtures) async {
    try {
        List allEvents = [];
        
        final soccerRes = await http.get(Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=20260611-20260719'));
        
        if (soccerRes.statusCode == 200) {
          final data = json.decode(soccerRes.body);
          allEvents.addAll(data['events'] as List? ?? []);
        }

        final cricketRes = await http.get(Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel'));
        
        if (cricketRes.statusCode == 200) {
          final data = json.decode(cricketRes.body);
          final scores = data['scores'] as List? ?? [];
          for (var score in scores) {
            allEvents.addAll(score['events'] as List? ?? []);
          }
        }

        final wnbaRes = await http.get(Uri.parse(
            'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard'));
        
        if (wnbaRes.statusCode == 200) {
          final data = json.decode(wnbaRes.body);
          allEvents.addAll(data['events'] as List? ?? []);
        }
        
        if (allEvents.isEmpty) return fixtures;
        
        return await Future.wait(fixtures.map((fixture) async {
          var espnEvent = allEvents.firstWhere(
            (e) => fixture.id == e['id'] || _matchesEspnEvent(fixture, e),
            orElse: () => null,
          );

          if (espnEvent == null && int.tryParse(fixture.id) != null) {
            try {
              final sportStr = fixture.sport == Sport.football 
                  ? 'soccer/fifa.world' 
                  : fixture.sport == Sport.basketball
                      ? 'basketball/wnba'
                      : 'cricket/${fixture.leagueId}';
              final summaryRes = await http.get(Uri.parse(
                'https://site.api.espn.com/apis/site/v2/sports/$sportStr/summary?event=${fixture.id}'
              ));
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
    final comp =
        event['competitions'] != null && event['competitions'].isNotEmpty
        ? event['competitions'][0]
        : null;

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

    final homeScore = isPreMatch ? null : homeTeamData['score']?.toString();
    final awayScore = isPreMatch ? null : awayTeamData['score']?.toString();

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

    try {
      final summaryUrl = fixture.sport == Sport.football
          ? 'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/summary?event=${event['id']}'
          : fixture.sport == Sport.basketball
              ? 'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/summary?event=${event['id']}'
              : 'https://site.api.espn.com/apis/site/v2/sports/cricket/${fixture.leagueId}/summary?event=${event['id']}';
            
      final summaryRes = await http.get(Uri.parse(summaryUrl));
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
          final pbpRes = await http.get(Uri.parse(pbpUrl));
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

          final pbpUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/playbyplay?event=${event['id']}&limit=1000';
          final pbpRes = await http.get(Uri.parse(pbpUrl));
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
    } catch (_) {}

    return fixture.copyWith(
      status: newStatus,
      homeScore: homeScore,
      awayScore: awayScore,
      liveStatusNote: statusNote,
      timelineEvents: timelineEvents,
      homeLineup: homeLineupData ?? fixture.homeLineup ?? _getMockLineup(true),
      awayLineup: awayLineupData ?? fixture.awayLineup ?? _getMockLineup(false),
      commentary: parsedCommentary ?? fixture.commentary,
      cricketScorecard: parsedScorecard,
      basketballScorecard: parsedBasketballScorecard,
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

  MatchLineup _getMockLineup(bool isHome) {
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
}

