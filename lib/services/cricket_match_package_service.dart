import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/cricket_match_data.dart';
import '../models/cricket_scorecard.dart';
import '../models/sport_match.dart';

class CricketMatchPackageService {
  const CricketMatchPackageService();

  static const assetPath = 'assets/data/cricket-revamp.json';
  static const bundledMatchId = 'cricket-revamp-20260531-rcb-gt';

  Future<SportMatch> loadBundled() async =>
      decode(await rootBundle.loadString(assetPath), matchId: bundledMatchId);

  SportMatch decode(String source, {String matchId = bundledMatchId}) {
    final root = _map(jsonDecode(source));
    final match = _map(root['matchDetails']);
    final location = _map(match['location']);
    final score = _map(match['score']);
    final homeScore = _map(score['home']);
    final awayScore = _map(score['away']);
    final squads = _list(root['teams']).map(_teamSquad).toList();
    final homeSquad = squads.firstWhere((team) => team.isHome);
    final awaySquad = squads.firstWhere((team) => !team.isHome);
    final innings = _list(root['innings']).map(_inningsSummary).toList();
    final inningsProgress = _list(
      root['inningsProgress'],
    ).map(_inningsProgress).toList();
    final balls = _list(root['commentary']).map(_ballCommentary).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final notes = _list(root['notes']).map(_note).toList();

    final awards = <CricketAward>[
      if (_map(match['playerOfTheMatch']).isNotEmpty)
        _award(match['playerOfTheMatch']),
      if (_map(match['playerOfTheSeries']).isNotEmpty)
        _award(match['playerOfTheSeries']),
    ];

    final details = CricketMatchDetails(
      league: _s(match['league']),
      leagueAbbreviation: _s(match['leagueAbbreviation']),
      season: _i(match['season']),
      title: _s(match['title']),
      stage: _s(match['stage']),
      format: _s(match['format']),
      formatName: _s(match['formatName']),
      status: _s(match['status']),
      state: _s(match['state']),
      result: _s(match['result']),
      seriesNote: _s(match['seriesNote']),
      venue: _s(location['venue']),
      city: _s(location['city']),
      country: _s(location['country']),
      neutralSite: _b(location['neutralSite']),
      toss: CricketToss(
        team: _s(_map(match['toss'])['team']),
        decision: _s(_map(match['toss'])['decision']),
      ),
      innings: innings,
      awards: awards,
      officials: _list(match['officials']).map((entry) {
        final value = _map(entry);
        return CricketOfficial(
          name: _s(value['name']),
          role: _s(value['role']),
          country: _s(value['country']),
        );
      }).toList(),
      notes: notes,
      commentary: balls,
      inningsProgress: inningsProgress,
      teams: squads,
    );

    final teamStats = _list(root['teamStats']).map((entry) {
      final value = _map(entry);
      return TeamStatLine(
        label: _s(value['label']),
        homeDisplay: _displayNumber(value['home']),
        awayDisplay: _displayNumber(value['away']),
        homeValue: _d(value['home']),
        awayValue: _d(value['away']),
      );
    }).toList();

    return SportMatch(
      id: matchId,
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: SportTeam(
        id: homeSquad.id,
        name: homeSquad.name,
        shortName: homeSquad.abbreviation,
        color: Cyber.cyan,
      ),
      away: SportTeam(
        id: awaySquad.id,
        name: awaySquad.name,
        shortName: awaySquad.abbreviation,
        color: Cyber.magenta,
      ),
      kickoff: DateTime.parse(_s(match['start'])).toLocal(),
      status: _b(match['completed'])
          ? MatchStatus.finished
          : MatchStatus.upcoming,
      homeScore: _s(homeScore['score']),
      awayScore: _s(awayScore['score']),
      resultLine: _s(match['result']),
      homeLineup: _lineup(homeSquad),
      awayLineup: _lineup(awaySquad),
      cricketScorecard: CricketScorecard(
        innings: _list(root['scorecard']).map(_scorecardInnings).toList(),
      ),
      commentary: balls
          .map(
            (ball) => MatchCommentary(
              minute: ball.over,
              text: ball.text,
              shortText: ball.shortText,
              scoreValue: ball.runs,
              isWicket: ball.wicket,
              sequence: ball.sequence,
              period: ball.innings,
              kind: 'ball',
              players: [ball.batter, ball.bowler],
              playId: ball.id,
            ),
          )
          .toList(),
      teamStats: teamStats,
      cricketDetails: details,
    );
  }

  CricketInnings _scorecardInnings(Object? entry) {
    final value = _map(entry);
    final extras = _map(value['extras']);
    final structuredExtras = CricketExtras(
      total: _i(extras['total']),
      wides: _i(extras['wides']),
      noBalls: _i(extras['noballs']),
      byes: _i(extras['byes']),
      legByes: _i(extras['legByes']),
    );
    return CricketInnings(
      teamName: _s(value['battingTeam']),
      scoreText: _s(value['score']),
      number: _i(value['innings']),
      runs: _i(value['runs']),
      wickets: _i(value['wickets']),
      overs: _d(value['overs']),
      runRate: _d(value['runRate']),
      target: value['target'] == null ? null : _i(value['target']),
      extrasBreakdown: structuredExtras,
      extras:
          '${structuredExtras.total} '
          '(w ${structuredExtras.wides}, nb ${structuredExtras.noBalls}, '
          'b ${structuredExtras.byes}, lb ${structuredExtras.legByes})',
      batters: _list(value['batting']).map(_batter).toList(),
      bowlers: _list(value['bowling']).map(_bowler).toList(),
      didNotBat: _list(value['didNotBat']).map(_s).toList(),
      fow: _list(value['fallOfWickets']).map((entry) {
        final item = _map(entry);
        return '${_s(item['score'])} ${_s(item['batter'])} '
            '(${_displayNumber(item['overs'])} ov)';
      }).toList(),
      fallOfWickets: _list(value['fallOfWickets']).map((entry) {
        final item = _map(entry);
        return CricketFallOfWicket(
          wicket: _i(item['wicket']),
          score: _s(item['score']),
          runs: _i(item['runs']),
          overs: _d(item['overs']),
          batter: _s(item['batter']),
        );
      }).toList(),
      partnerships: _list(value['partnerships']).map((entry) {
        final item = _map(entry);
        return CricketPartnership(
          wicket: _s(item['wicket']),
          runs: _i(item['runs']),
          overs: _d(item['overs']),
          batters: _list(item['batters']).map((entry) {
            final batter = _map(entry);
            return CricketPartnershipBatter(
              name: _s(batter['name']),
              runs: _i(batter['runs']),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  CricketBatter _batter(Object? entry) {
    final value = _map(entry);
    final dismissal = _nullableString(value['dismissal']);
    return CricketBatter(
      name: _s(value['name']),
      runs: _i(value['runs']),
      balls: _i(value['balls']),
      fours: _i(value['fours']),
      sixes: _i(value['sixes']),
      strikeRate: _d(value['strikeRate']),
      dismissalText: dismissal,
      id: _s(value['id']),
      position: _i(value['position']),
      minutes: _i(value['minutes']),
      notOut: _b(value['notOut']),
      milestone: _nullableString(value['milestone']),
    );
  }

  CricketBowler _bowler(Object? entry) {
    final value = _map(entry);
    return CricketBowler(
      name: _s(value['name']),
      overs: _d(value['overs']),
      maidens: _i(value['maidens']),
      runs: _i(value['runs']),
      wickets: _i(value['wickets']),
      economyRate: _d(value['economy']),
      id: _s(value['id']),
      position: _i(value['position']),
      balls: _i(value['balls']),
      dots: _i(value['dots']),
      wides: _i(value['wides']),
      noBalls: _i(value['noballs']),
      foursConceded: _i(value['foursConceded']),
      sixesConceded: _i(value['sixesConceded']),
    );
  }

  CricketInningsSummary _inningsSummary(Object? entry) {
    final value = _map(entry);
    return CricketInningsSummary(
      number: _i(value['innings']),
      team: _s(value['team']),
      teamId: _s(value['teamId']),
      abbreviation: _s(value['abbreviation']),
      runs: _i(value['runs']),
      wickets: _i(value['wickets']),
      overs: _d(value['overs']),
      fours: _i(value['fours']),
      sixes: _i(value['sixes']),
      target: value['target'] == null ? null : _i(value['target']),
      score: _s(value['score']),
      description: _s(value['description']),
      current: _b(value['current']),
    );
  }

  CricketInningsProgress _inningsProgress(Object? entry) {
    final value = _map(entry);
    return CricketInningsProgress(
      innings: _i(value['innings']),
      teamId: _s(value['teamId']),
      points: _list(value['points']).map((point) {
        final item = _map(point);
        return CricketScoreProgressPoint(
          over: _i(item['over']),
          runs: _i(item['runs']),
          wickets: _i(item['wickets']),
          wicket: _b(item['wicket']),
        );
      }).toList(),
    );
  }

  CricketBallCommentary _ballCommentary(Object? entry) {
    final value = _map(entry);
    final required = _map(value['required']);
    return CricketBallCommentary(
      id: _s(value['id']),
      sequence: _i(value['sequence']),
      innings: _i(value['innings']),
      over: _s(value['over']),
      overNumber: _i(value['overNumber']),
      ball: _i(value['ball']),
      batter: _s(value['batter']),
      bowler: _s(value['bowler']),
      runs: _i(value['runs']),
      boundary: _b(value['boundary']),
      wicket: _b(value['wicket']),
      dismissal: _nullableString(value['dismissal']),
      score: _s(value['score']),
      runRate: _d(value['runRate']),
      required: required.isEmpty
          ? null
          : CricketRequiredRate(
              runs: _i(required['runs']),
              balls: _i(required['balls']),
              runRate: _d(required['runRate']),
            ),
      shortText: _s(value['shortText']),
      text: _s(value['text']),
      preText: _nullableString(value['preText']),
      postText: _nullableString(value['postText']),
    );
  }

  CricketMatchNote _note(Object? entry) {
    final value = _map(entry);
    return CricketMatchNote(
      id: _s(value['id']),
      innings: _i(value['innings']),
      day: _i(value['day']),
      kind: _s(value['kind']),
      text: _s(value['text']),
    );
  }

  CricketAward _award(Object? entry) {
    final value = _map(entry);
    return CricketAward(
      id: _s(value['id']),
      name: _s(value['name']),
      award: _s(value['award']),
      team: _s(value['team']),
      teamId: _s(value['teamId']),
    );
  }

  CricketTeamSquad _teamSquad(Object? entry) {
    final value = _map(entry);
    return CricketTeamSquad(
      id: _s(value['id']),
      name: _s(value['name']),
      abbreviation: _s(value['abbreviation']),
      isHome: _s(value['homeAway']) == 'home',
      captain: _s(value['captain']),
      keeper: _s(value['keeper']),
      squadPublished: _b(value['squadPublished']),
      playerCount: _i(value['playerCount']),
      players: _list(value['players']).map(_squadPlayer).toList(),
    );
  }

  CricketSquadPlayer _squadPlayer(Object? entry) {
    final value = _map(entry);
    final performances = <int, CricketPlayerPerformance>{};
    for (final entry in _list(value['batting'])) {
      final batting = _map(entry);
      final innings = _i(batting['innings']);
      performances[innings] = CricketPlayerPerformance(
        innings: innings,
        battingScore: _s(batting['score']),
      );
    }
    for (final entry in _list(value['bowling'])) {
      final bowling = _map(entry);
      final innings = _i(bowling['innings']);
      final current = performances[innings];
      performances[innings] = CricketPlayerPerformance(
        innings: innings,
        battingScore: current?.battingScore,
        bowlingFigures: _s(bowling['figures']),
        catches: current?.catches ?? 0,
        stumpings: current?.stumpings ?? 0,
      );
    }
    for (final entry in _list(value['fielding'])) {
      final fielding = _map(entry);
      final innings = _i(fielding['innings']);
      final current = performances[innings];
      performances[innings] = CricketPlayerPerformance(
        innings: innings,
        battingScore: current?.battingScore,
        bowlingFigures: current?.bowlingFigures,
        catches: _i(fielding['catches']),
        stumpings: _i(fielding['stumpings']),
      );
    }
    final sorted = performances.values.toList()
      ..sort((a, b) => a.innings.compareTo(b.innings));
    return CricketSquadPlayer(
      id: _s(value['id']),
      name: _s(value['name']),
      fullName: _s(value['fullName']),
      battingName: _s(value['battingName']),
      role: _s(value['role']),
      keeper: _b(value['keeper']),
      captain: _b(value['captain']),
      starter: _b(value['starter']),
      subbedIn: _b(value['subbedIn']),
      subbedOut: _b(value['subbedOut']),
      active: _b(value['active']),
      battingStyle: _s(value['battingStyle']),
      bowlingStyle: _s(value['bowlingStyle']),
      performances: sorted,
    );
  }

  MatchLineup _lineup(CricketTeamSquad squad) {
    MatchPlayer player(CricketSquadPlayer value) => MatchPlayer(
      id: value.id,
      name: value.name,
      number: 0,
      role: value.role,
      isCaptain: value.captain,
      source: 'cricket-package',
    );
    return MatchLineup(
      formation: 'PLAYING XI',
      startingXI: squad.players.where((p) => p.starter).map(player).toList(),
      substitutes: squad.players.where((p) => !p.starter).map(player).toList(),
      confirmed: squad.squadPublished,
      source: 'cricket-package',
      reportedPlayerCount: squad.playerCount,
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
String _displayNumber(Object? value) {
  final number = _d(value);
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}
