import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/basketball_match_data.dart';
import '../models/basketball_scorecard.dart';
import '../models/sport_match.dart';

class BasketballMatchPackageService {
  const BasketballMatchPackageService();

  static const assetPath = 'assets/data/basketball-revamp.json';
  static const bundledMatchId = 'basketball-revamp-20260614-ny-sa';

  Future<SportMatch> loadBundled() async =>
      decode(await rootBundle.loadString(assetPath), matchId: bundledMatchId);

  SportMatch decode(String source, {String matchId = bundledMatchId}) {
    final root = _map(jsonDecode(source));
    final match = _map(root['matchDetails']);
    final location = _map(match['location']);
    final score = _map(match['score']);
    final homeScore = _map(score['home']);
    final awayScore = _map(score['away']);
    final rosters = _list(root['teams']).map(_teamRoster).toList();
    final homeRoster = rosters.firstWhere((team) => team.isHome);
    final awayRoster = rosters.firstWhere((team) => !team.isHome);
    final topStats = _list(root['topStats']);
    final plays = _list(root['playByPlay']).map(_play).toList();

    final details = BasketballMatchDetails(
      league: _s(match['league']),
      leagueAbbreviation: _s(match['leagueAbbreviation']),
      season: _i(match['season']),
      gameNote: _s(match['gameNote']),
      status: _s(match['status']),
      venue: _s(location['venue']),
      city: _s(location['city']),
      state: _s(location['state']),
      country: _s(location['country']),
      neutralSite: _b(location['neutralSite']),
      attendance: _i(match['attendance']),
      broadcast: _s(match['broadcast']),
      overtime: _b(match['overtime']),
      series: _list(match['series']).map((entry) {
        final value = _map(entry);
        return BasketballSeriesNote(
          title: _s(value['title']),
          description: _s(value['description']),
          summary: _s(value['summary']),
          completed: _b(value['completed']),
        );
      }).toList(),
      officials: _list(match['officials']).map((entry) {
        final value = _map(entry);
        return BasketballOfficial(
          name: _s(value['name']),
          role: _s(value['role']),
        );
      }).toList(),
      leaders: _list(match['leaders']).map(_leaderGroup).toList(),
      turningPoints: _list(root['turningPoints']).map(_turningPoint).toList(),
      plays: plays,
      injuries: _list(root['injuries']).map(_injuryReport).toList(),
      teams: rosters,
    );

    final teamStats = topStats.map((entry) {
      final value = _map(entry);
      return TeamStatLine(
        label: _s(value['label']),
        homeDisplay: _displayNumber(value['home'], _s(value['name'])),
        awayDisplay: _displayNumber(value['away'], _s(value['name'])),
        homeValue: _d(value['home']),
        awayValue: _d(value['away']),
      );
    }).toList();

    final scorecard = BasketballScorecard(
      homeBoxscore: _boxscore(homeRoster, topStats),
      awayBoxscore: _boxscore(awayRoster, topStats),
      linescores: _linescores(root['lineScore']),
    );

    return SportMatch(
      id: matchId,
      leagueId: 'nba',
      sport: Sport.basketball,
      home: SportTeam(
        id: homeRoster.id,
        name: homeRoster.name,
        shortName: homeRoster.abbreviation,
        color: Cyber.cyan,
      ),
      away: SportTeam(
        id: awayRoster.id,
        name: awayRoster.name,
        shortName: awayRoster.abbreviation,
        color: Cyber.magenta,
      ),
      kickoff: DateTime.parse(_s(match['tipoff'])).toLocal(),
      status: _b(match['completed'])
          ? MatchStatus.finished
          : MatchStatus.upcoming,
      homeScore: _i(homeScore['score']).toString(),
      awayScore: _i(awayScore['score']).toString(),
      resultLine:
          '${_s(score['winner'])} won ${_i(awayScore['score'])}-'
          '${_i(homeScore['score'])}',
      homeLineup: _lineup(homeRoster),
      awayLineup: _lineup(awayRoster),
      basketballScorecard: scorecard,
      commentary: plays
          .map(
            (play) => MatchCommentary(
              minute: 'Q${play.period} ${play.clock}',
              text: play.text,
              shortText: play.label,
              scoreValue: play.points,
              sequence: int.tryParse(play.id),
              period: play.period,
              kind: play.kind,
              isHomeTeam: play.isHomeTeam,
              players: play.players,
              playId: play.id,
            ),
          )
          .toList(),
      teamStats: teamStats,
      basketballDetails: details,
    );
  }

  BasketballLinescores _linescores(Object? value) {
    final line = _map(value);
    final periods = _list(line['periods']).map(_map).toList();
    return BasketballLinescores(
      homeScores: periods.map((period) => _i(period['home'])).toList(),
      awayScores: periods.map((period) => _i(period['away'])).toList(),
      homeTotal: _i(_map(line['home'])['total']),
      awayTotal: _i(_map(line['away'])['total']),
      periodCount: periods.length,
    );
  }

  BasketballTeamBoxscore _boxscore(
    BasketballTeamRoster roster,
    List<Object?> topStats,
  ) {
    num stat(String name) {
      for (final entry in topStats) {
        final value = _map(entry);
        if (_s(value['name']) == name) {
          return roster.isHome
              ? (value['home'] as num? ?? 0)
              : (value['away'] as num? ?? 0);
        }
      }
      return 0;
    }

    int made(BasketballShotSplit split) => split.made;
    int attempted(BasketballShotSplit split) => split.attempted;
    final fgMade = roster.players.fold<int>(
      0,
      (sum, p) => sum + made(p.fieldGoals),
    );
    final fgAttempted = roster.players.fold<int>(
      0,
      (sum, p) => sum + attempted(p.fieldGoals),
    );
    final threeMade = roster.players.fold<int>(
      0,
      (sum, p) => sum + made(p.threePointers),
    );
    final threeAttempted = roster.players.fold<int>(
      0,
      (sum, p) => sum + attempted(p.threePointers),
    );
    final ftMade = roster.players.fold<int>(
      0,
      (sum, p) => sum + made(p.freeThrows),
    );
    final ftAttempted = roster.players.fold<int>(
      0,
      (sum, p) => sum + attempted(p.freeThrows),
    );

    return BasketballTeamBoxscore(
      teamName: roster.name,
      teamId: roster.id,
      stats: BasketballTeamStats(
        fgMadeApt: '$fgMade-$fgAttempted',
        fgPct: stat('fieldGoalPct').toDouble(),
        tpMadeApt: '$threeMade-$threeAttempted',
        tpPct: stat('threePointFieldGoalPct').toDouble(),
        ftMadeApt: '$ftMade-$ftAttempted',
        ftPct: stat('freeThrowPct').toDouble(),
        rebounds: stat('totalRebounds').toInt(),
        assists: stat('assists').toInt(),
        steals: stat('steals').toInt(),
        blocks: stat('blocks').toInt(),
        turnovers: stat('totalTurnovers').toInt(),
        pointsInPaint: stat('pointsInPaint').toInt(),
        fastBreakPoints: stat('fastBreakPoints').toInt(),
        turnoverPoints: stat('turnoverPoints').toInt(),
        fouls: stat('fouls').toInt(),
      ),
      players: roster.players.map((player) {
        return BasketballPlayerStat(
          name: player.name,
          starter: player.starter,
          minutes: _displayDouble(player.minutes),
          points: player.points,
          fg: player.fieldGoals.display,
          tp: player.threePointers.display,
          ft: player.freeThrows.display,
          rebounds: player.rebounds,
          assists: player.assists,
          turnovers: player.turnovers,
          steals: player.steals,
          blocks: player.blocks,
          fouls: player.fouls,
          plusMinus: player.plusMinus > 0
              ? '+${player.plusMinus}'
              : '${player.plusMinus}',
          id: player.id,
          shortName: player.shortName,
          jersey: player.jersey,
          position: player.position,
          didNotPlay: player.didNotPlay,
          reason: player.reason,
          ejected: player.ejected,
          offensiveRebounds: player.offensiveRebounds,
          defensiveRebounds: player.defensiveRebounds,
        );
      }).toList(),
    );
  }

  MatchLineup _lineup(BasketballTeamRoster roster) {
    MatchPlayer player(BasketballRosterPlayer value) => MatchPlayer(
      id: value.id,
      name: value.name,
      shortName: value.shortName,
      number: int.tryParse(value.jersey) ?? 0,
      role: value.position,
      source: 'basketball-package',
    );
    return MatchLineup(
      formation: 'STARTING 5',
      startingXI: roster.players.where((p) => p.starter).map(player).toList(),
      substitutes: roster.players.where((p) => !p.starter).map(player).toList(),
      confirmed: true,
      source: 'basketball-package',
      reportedPlayerCount: roster.playerCount,
    );
  }

  BasketballTeamRoster _teamRoster(Object? entry) {
    final value = _map(entry);
    return BasketballTeamRoster(
      id: _s(value['id']),
      name: _s(value['name']),
      abbreviation: _s(value['abbreviation']),
      isHome: _s(value['homeAway']) == 'home',
      boxscoreAvailable: _b(value['boxscoreAvailable']),
      playerCount: _i(value['playerCount']),
      playedCount: _i(value['playedCount']),
      players: _list(value['players']).map(_rosterPlayer).toList(),
    );
  }

  BasketballRosterPlayer _rosterPlayer(Object? entry) {
    final value = _map(entry);
    return BasketballRosterPlayer(
      id: _s(value['id']),
      name: _s(value['name']),
      shortName: _s(value['shortName']),
      jersey: _s(value['jersey']),
      position: _s(value['position']),
      starter: _b(value['starter']),
      didNotPlay: _b(value['didNotPlay']),
      reason: _nullableString(value['reason']),
      ejected: _b(value['ejected']),
      minutes: _d(value['minutes']),
      points: _i(value['points']),
      fieldGoals: _shotSplit(value['fieldGoals']),
      threePointers: _shotSplit(value['threePointFieldGoals']),
      freeThrows: _shotSplit(value['freeThrows']),
      rebounds: _i(value['rebounds']),
      assists: _i(value['assists']),
      turnovers: _i(value['turnovers']),
      steals: _i(value['steals']),
      blocks: _i(value['blocks']),
      offensiveRebounds: _i(value['offensiveRebounds']),
      defensiveRebounds: _i(value['defensiveRebounds']),
      fouls: _i(value['fouls']),
      plusMinus: _i(value['plusMinus']),
    );
  }

  BasketballShotSplit _shotSplit(Object? entry) {
    final value = _map(entry);
    return BasketballShotSplit(
      made: _i(value['made']),
      attempted: _i(value['attempted']),
      percentage: _d(value['pct']),
    );
  }

  BasketballPlay _play(Object? entry) {
    final value = _map(entry);
    final coordinate = _map(value['coordinate']);
    return BasketballPlay(
      id: _s(value['id']),
      period: _i(value['period']),
      clock: _s(value['clock']),
      kind: _s(value['kind']),
      label: _s(value['label']),
      text: _s(value['text']),
      isHomeTeam: _s(value['side']) == 'home',
      players: _list(value['players']).map(_s).toList(),
      scoringPlay: _b(value['scoringPlay']),
      points: _i(value['points']),
      homeScore: _i(value['homeScore']),
      awayScore: _i(value['awayScore']),
      shootingPlay: _b(value['shootingPlay']),
      made: _b(value['made']),
      coordinate: coordinate.isEmpty
          ? null
          : BasketballCoordinate(
              x: _d(coordinate['x']),
              y: _d(coordinate['y']),
            ),
      homeWinPercentage: _d(value['homeWinPct']),
      swing: _d(value['swing']),
    );
  }

  BasketballTurningPoint _turningPoint(Object? entry) {
    final value = _map(entry);
    return BasketballTurningPoint(
      playId: _s(value['playId']),
      period: _i(value['period']),
      clock: _s(value['clock']),
      homeWinPercentage: _d(value['homeWinPercentage']),
      awayWinPercentage: _d(value['awayWinPercentage']),
      homeScore: _i(value['homeScore']),
      awayScore: _i(value['awayScore']),
      swing: _d(value['swing']),
      text: _s(value['text']),
    );
  }

  BasketballLeaderGroup _leaderGroup(Object? entry) {
    final value = _map(entry);
    return BasketballLeaderGroup(
      team: _s(value['team']),
      teamId: _s(value['teamId']),
      leaders: _list(value['leaders']).map((leader) {
        final item = _map(leader);
        return BasketballLeader(
          id: _s(item['id']),
          category: _s(item['category']),
          label: _s(item['label']),
          name: _s(item['name']),
          value: item['value'] as num? ?? 0,
        );
      }).toList(),
    );
  }

  BasketballInjuryReport _injuryReport(Object? entry) {
    final value = _map(entry);
    return BasketballInjuryReport(
      team: _s(value['team']),
      teamId: _s(value['teamId']),
      injuries: _list(value['injuries']).map((injury) {
        final item = _map(injury);
        return BasketballInjury(
          id: _s(item['id']),
          name: _s(item['name']),
          position: _s(item['position']),
          status: _s(item['status']),
          date: DateTime.tryParse(_s(item['date'])),
        );
      }).toList(),
    );
  }
}

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
List<Object?> _list(Object? value) => value is List ? value : const [];
String _s(Object? value) => value?.toString() ?? '';
String? _nullableString(Object? value) {
  final text = _s(value).trim();
  return text.isEmpty ? null : text;
}

int _i(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;
double _d(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_s(value)) ?? 0;
bool _b(Object? value) => value == true || _s(value).toLowerCase() == 'true';
String _displayDouble(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _displayNumber(Object? value, String name) {
  final suffix = name.toLowerCase().contains('pct') ? '%' : '';
  return '${_displayDouble(_d(value))}$suffix';
}
