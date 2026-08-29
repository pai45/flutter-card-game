import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/football_match_data.dart';
import '../models/sport_match.dart';

/// Decodes the normalized football match package used by the match STATS HUD.
class FootballMatchPackageService {
  const FootballMatchPackageService();

  static const bundledAsset = 'assets/data/football-revamp.json';
  static const bundledMatchId = 'football-revamp-20260824-ful-che';

  Future<SportMatch> loadBundled() async {
    final source = await rootBundle.loadString(bundledAsset);
    return decode(source);
  }

  SportMatch decode(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Football package root must be an object.');
    }
    return fromJson(json);
  }

  SportMatch fromJson(Map<String, dynamic> json) {
    final details = _map(json['matchDetails']);
    final score = _map(details['score']);
    final homeScore = _map(score['home']);
    final awayScore = _map(score['away']);
    final teams = _maps(json['teams']);
    final homeTeamData = _teamBySide(teams, 'home');
    final awayTeamData = _teamBySide(teams, 'away');

    final home = _parseTeam(homeTeamData, homeScore, true);
    final away = _parseTeam(awayTeamData, awayScore, false);
    final kickoff = DateTime.parse(_string(details['kickoff'])).toLocal();
    final completed = details['completed'] == true;
    final statusText = _string(details['status']);
    final status = completed || statusText.toLowerCase().contains('full time')
        ? MatchStatus.finished
        : statusText.toLowerCase().contains('progress') ||
              statusText.toLowerCase().contains('live')
        ? MatchStatus.live
        : MatchStatus.upcoming;
    final winner = _nullableString(score['winner']);

    return SportMatch(
      id: bundledMatchId,
      leagueId: 'eng.1',
      sport: Sport.football,
      home: home,
      away: away,
      kickoff: kickoff,
      status: status,
      homeScore: _nullableString(homeScore['score']),
      awayScore: _nullableString(awayScore['score']),
      resultLine: winner == null
          ? null
          : '$winner won ${_string(score['display'])}',
      teamStats: _parseStats(json['topStats']),
      timelineEvents: _parseTimeline(json['timeline']),
      homeLineup: _parseLineup(homeTeamData),
      awayLineup: _parseLineup(awayTeamData),
      commentary: _parseCommentary(json['commentary']),
      footballDetails: _parseDetails(details),
      footballMomentum: _parseMomentum(json['momentum']),
      rewardXp: 40,
    );
  }

  SportTeam _parseTeam(
    Map<String, dynamic> team,
    Map<String, dynamic> scoreTeam,
    bool isHome,
  ) {
    final name = _nullableString(team['name']) ?? _string(scoreTeam['team']);
    return SportTeam(
      id: _nullableString(team['id']) ?? name.toLowerCase(),
      name: name,
      shortName:
          _nullableString(team['abbreviation']) ??
          _nullableString(scoreTeam['abbreviation']) ??
          name.substring(0, name.length.clamp(0, 3)).toUpperCase(),
      color: isHome ? Cyber.cyan : Cyber.magenta,
    );
  }

  FootballMatchDetails _parseDetails(Map<String, dynamic> details) {
    final location = _map(details['location']);
    final score = _map(details['score']);
    return FootballMatchDetails(
      league: _string(details['league']),
      season: _string(details['season']),
      status: _string(details['status']),
      completed: details['completed'] == true,
      venue: _string(location['venue']),
      city: _string(location['city']),
      country: _string(location['country']),
      neutralSite: location['neutralSite'] == true,
      attendance: _int(details['attendance']),
      scoreDisplay: _string(score['display']),
      winner: _nullableString(score['winner']),
      scorers: _maps(details['scorers'])
          .map(
            (scorer) => FootballScorer(
              id: _string(scorer['id']),
              name: _string(scorer['name']),
              team: _string(scorer['team']),
              teamId: _string(scorer['teamId']),
              minute: _string(scorer['minute']),
              period: _int(scorer['period']),
              type: _string(scorer['type']),
              assist: _nullableString(scorer['assist']),
              shootout: scorer['shootout'] == true,
            ),
          )
          .toList(growable: false),
    );
  }

  List<TeamStatLine> _parseStats(dynamic value) => _maps(value)
      .where((stat) => stat['available'] != false)
      .map((stat) {
        final home = _map(stat['home']);
        final away = _map(stat['away']);
        return TeamStatLine(
          label: _string(stat['label']),
          homeDisplay: _string(home['display']),
          awayDisplay: _string(away['display']),
          homeValue: _double(home['value']),
          awayValue: _double(away['value']),
        );
      })
      .toList(growable: false);

  List<MatchEvent> _parseTimeline(dynamic value) => _maps(value)
      .map((event) {
        final kind = _string(event['kind']);
        final side = _nullableString(event['side']);
        final playerIn = _nullableString(event['playerIn']);
        final player = _nullableString(event['player']) ?? playerIn ?? '';
        final assist = _nullableString(event['assist']);
        final playerOut = _nullableString(event['playerOut']);
        return MatchEvent(
          minute: _minute(
            _nullableString(event['minute']),
            _int(event['clock']),
          ),
          displayMinute: _nullableString(event['minute']),
          clockSeconds: _int(event['clock']),
          period: event['period'] == null ? null : _int(event['period']),
          isHomeTeam: side == 'home',
          playerName: player,
          secondaryPlayerName: kind == 'substitution' ? playerOut : assist,
          type: _eventType(kind),
          label: _nullableString(event['label']),
          teamName: _nullableString(event['team']),
          scoreDisplay: _nullableString(_map(event['score'])['display']),
          description: _nullableString(event['text']),
        );
      })
      .toList(growable: false);

  MatchLineup _parseLineup(Map<String, dynamic> team) {
    final players = _maps(team['players']);
    return MatchLineup(
      formation: _string(team['formation']),
      startingXI: players
          .where((player) => player['starter'] == true)
          .map(_parsePlayer)
          .toList(growable: false),
      substitutes: players
          .where((player) => player['starter'] != true)
          .map(_parsePlayer)
          .toList(growable: false),
      confirmed: team['lineupsConfirmed'] == true,
      source: _nullableString(team['source']),
      reportedPlayerCount: _int(team['playerCount']),
    );
  }

  MatchPlayer _parsePlayer(Map<String, dynamic> player) {
    final formationPlace = _nullableString(player['formationPlace']);
    return MatchPlayer(
      id: _string(player['id']),
      name: _string(player['name']),
      shortName: _nullableString(player['shortName']),
      number: _int(player['jersey']),
      role:
          _nullableString(player['positionName']) ??
          _nullableString(player['position']),
      formationPlace: formationPlace == '0' ? null : formationPlace,
      source: _nullableString(player['source']),
    );
  }

  List<MatchCommentary> _parseCommentary(dynamic value) => _maps(value)
      .where((item) => _string(item['text']).isNotEmpty)
      .map(
        (item) => MatchCommentary(
          minute: _nullableString(item['minute']) ?? '',
          text: _string(item['text']),
          sequence: _int(item['sequence']),
          clockSeconds: _int(item['clock']),
          period: item['period'] == null ? null : _int(item['period']),
          kind: _nullableString(item['kind']),
          teamName: _nullableString(item['team']),
          isHomeTeam: item['side'] == null ? null : item['side'] == 'home',
          players: _list(item['players'])
              .map(
                (player) =>
                    player is Map ? _string(player['name']) : _string(player),
              )
              .where((name) => name.isNotEmpty)
              .toList(growable: false),
          playId: _nullableString(item['playId']),
        ),
      )
      .toList(growable: false);

  FootballMomentum _parseMomentum(dynamic value) {
    final momentum = _map(value);
    return FootballMomentum(
      totalMinutes: _int(momentum['totalMinutes']),
      halftimeMinute: _int(momentum['halftimeMinute']),
      homeTeam: _string(_map(momentum['home'])['team']),
      awayTeam: _string(_map(momentum['away'])['team']),
      series: _maps(momentum['series'])
          .map(
            (point) => FootballMomentumPoint(
              minute: _int(point['minute']),
              home: _double(point['home']),
              away: _double(point['away']),
              value: _double(point['value']),
            ),
          )
          .toList(growable: false),
      goals: _maps(momentum['goals'])
          .map(
            (goal) => FootballMomentumGoal(
              minute: _int(goal['minute']),
              axis: _int(goal['axis']),
              clock: _string(goal['clock']),
              isHomeTeam: goal['side'] == 'home',
              team: _string(goal['team']),
              player: _string(goal['player']),
            ),
          )
          .toList(growable: false),
    );
  }

  MatchEventType _eventType(String kind) => switch (kind) {
    'kickoff' => MatchEventType.kickoff,
    'goal' => MatchEventType.goal,
    'yellow-card' => MatchEventType.yellowCard,
    'red-card' => MatchEventType.redCard,
    'substitution' => MatchEventType.substitution,
    'halftime' => MatchEventType.halftime,
    'start-2nd-half' => MatchEventType.secondHalf,
    'end-regular-time' => MatchEventType.fullTime,
    _ => MatchEventType.fullTime,
  };

  Map<String, dynamic> _teamBySide(
    List<Map<String, dynamic>> teams,
    String side,
  ) => teams.firstWhere(
    (team) => team['homeAway'] == side,
    orElse: () => throw FormatException('Missing $side football team.'),
  );

  int _minute(String? display, int clock) {
    final match = RegExp(r'\d+').firstMatch(display ?? '');
    return int.tryParse(match?.group(0) ?? '') ?? (clock ~/ 60);
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      _list(value).map(_map).toList(growable: false);

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String? _nullableString(dynamic value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(_string(value)) ?? 0;
}
