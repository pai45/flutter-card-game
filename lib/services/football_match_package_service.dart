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
    // Hoisted once: every player's `stats` array is positional against this.
    final statKeys = _list(
      json['playerStatKeys'],
    ).map((key) => key.toString()).toList(growable: false);

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
      homeLineup: _parseLineup(homeTeamData, statKeys),
      awayLineup: _parseLineup(awayTeamData, statKeys),
      commentary: _parseCommentary(json['commentary']),
      footballDetails: _parseDetails(
        details,
        json['commentary'],
        _nullableString(json['espnEventId']),
      ),
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

  FootballMatchDetails _parseDetails(
    Map<String, dynamic> details,
    dynamic commentary,
    String? espnEventId,
  ) {
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
      shots: _parseShots(commentary),
      espnEventId: espnEventId,
    );
  }

  /// Shots ride on the commentary entries, because that is where the feed
  /// publishes their tracked positions. An entry without a usable coordinate is
  /// dropped rather than defaulted — the feed reports a missing position as
  /// `0/0`, which would otherwise plot on the goal line.
  List<FootballShot> _parseShots(dynamic value) {
    final shots = <FootballShot>[];
    for (final item in _maps(value)) {
      final kind = _string(item['kind']);
      if (!kind.startsWith('shot') && !kind.startsWith('goal')) continue;
      if (item['fieldPositionX'] == null || item['fieldPositionY'] == null) {
        continue;
      }
      final x = _double(item['fieldPositionX']);
      final y = _double(item['fieldPositionY']);
      if (x == 0 && y == 0) continue;

      final players = _list(item['players'])
          .map(
            (player) =>
                player is Map ? _string(player['name']) : _string(player),
          )
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      final text = _string(item['text']);
      final minuteLabel = _nullableString(item['minute']) ?? '';

      shots.add(
        FootballShot(
          playId: _nullableString(item['playId']) ?? '${shots.length}',
          minuteLabel: minuteLabel,
          minute:
              int.tryParse(RegExp(r'\d+').stringMatch(minuteLabel) ?? '') ?? 0,
          period: _int(item['period']),
          isHomeTeam: item['side'] == 'home',
          team: _string(item['team']),
          shooter: players.isEmpty ? '' : players.first,
          assist: players.length > 1 ? players[1] : null,
          outcome: _shotOutcome(kind),
          zone: _nullableString(item['shotZone']),
          fieldX: x / 100,
          fieldY: y / 100,
          isHeader: text.toLowerCase().contains('header'),
          netPlacement: _netPlacement(text),
        ),
      );
    }
    return List.unmodifiable(shots);
  }

  /// Where the attempt finished, read out of the commentary prose.
  ///
  /// The feed publishes no goal-mouth coordinate — `goalPosition*` is zero
  /// throughout — but it does describe the placement in words for every attempt
  /// that reached the frame, and the miss direction for every one that did not.
  /// Anything unrecognised returns null so it is drawn as "no placement" rather
  /// than guessed into the middle of the goal.
  static (double, double)? _netPlacement(String text) {
    final lower = text.toLowerCase();

    // On target: a corner of the goal, or straight down the middle.
    const inFrame = <String, (double, double)>{
      'top left': (0.18, 0.24),
      'top right': (0.82, 0.24),
      'top centre': (0.50, 0.22),
      'bottom left': (0.18, 0.78),
      'bottom right': (0.82, 0.78),
      'bottom centre': (0.50, 0.80),
    };
    for (final entry in inFrame.entries) {
      if (lower.contains('${entry.key} corner') ||
          lower.contains('${entry.key} of the goal')) {
        return entry.value;
      }
    }
    if (lower.contains('centre of the goal')) return (0.50, 0.55);

    // Off target: placed outside the frame in the direction described.
    // Kept just beyond the posts: these read as "off the frame" while still
    // fitting inside the diagram alongside their marker.
    if (lower.contains('high and wide to the right')) return (1.10, -0.08);
    if (lower.contains('high and wide to the left')) return (-0.10, -0.08);
    if (lower.contains('too high') || lower.contains('is high')) {
      return (0.50, -0.12);
    }
    if (lower.contains('misses to the right')) return (1.10, 0.50);
    if (lower.contains('misses to the left')) return (-0.10, 0.50);

    return null;
  }

  static FootballShotOutcome _shotOutcome(String kind) {
    if (kind.startsWith('goal')) return FootballShotOutcome.goal;
    if (kind.contains('on-target')) return FootballShotOutcome.onTarget;
    if (kind.contains('blocked')) return FootballShotOutcome.blocked;
    return FootballShotOutcome.offTarget;
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

  /// A half's closing score is the meaningful transition for a match report.
  /// ESPN/package feeds can also publish a same-clock "start 2nd half" marker;
  /// suppress it so EVENTS shows one clean `HALFTIME 1 - 2` rail instead of two
  /// duplicate period markers with the identical score.
  List<MatchEvent> _parseTimeline(dynamic value) => _maps(value)
      .where((event) => _string(event['kind']) != 'start-2nd-half')
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

  MatchLineup _parseLineup(Map<String, dynamic> team, List<String> statKeys) {
    final players = _maps(team['players']);
    return MatchLineup(
      formation: _string(team['formation']),
      startingXI: players
          .where((player) => player['starter'] == true)
          .map((player) => _parsePlayer(player, statKeys))
          .toList(growable: false),
      substitutes: players
          .where((player) => player['starter'] != true)
          .map((player) => _parsePlayer(player, statKeys))
          .toList(growable: false),
      confirmed: team['lineupsConfirmed'] == true,
      source: _nullableString(team['source']),
      reportedPlayerCount: _int(team['playerCount']),
    );
  }

  MatchPlayer _parsePlayer(Map<String, dynamic> player, List<String> statKeys) {
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
      matchStats: _parsePlayerStats(player, statKeys),
    );
  }

  /// The per-player match layer added by
  /// `tool/generate_football_match_players.dart`. Absent in an older asset, in
  /// which case every consumer degrades to "no tracking" rather than breaking.
  FootballPlayerMatchStats? _parsePlayerStats(
    Map<String, dynamic> player,
    List<String> statKeys,
  ) {
    final raw = player['stats'];
    if (statKeys.isEmpty || raw is! List) return null;
    final values = <String, num>{};
    // Positional: `stats[i]` is the value for `playerStatKeys[i]`. A null entry
    // means the stat does not apply to this position, so it is left out rather
    // than stored as zero.
    for (var i = 0; i < statKeys.length && i < raw.length; i++) {
      final value = raw[i];
      if (value is num) values[statKeys[i]] = value;
    }
    return FootballPlayerMatchStats(
      values: values,
      firstHalfTouches: _touches(player['t1']),
      secondHalfTouches: _touches(player['t2']),
      subInMinute: player['subIn'] == null ? null : _int(player['subIn']),
      subOutMinute: player['subOut'] == null ? null : _int(player['subOut']),
      starter: player['starter'] == true,
      expectedGoals: _nullableDouble(player['xg']),
      expectedGoalsOnTarget: _nullableDouble(player['xgot']),
    );
  }

  /// Reads a flat `[x, y, x, y, ...]` coordinate array into normalised pairs.
  ///
  /// The feed overflows its own 0..100 frame on events that leave the pitch
  /// (observed x 101.8, y -1.6), so both axes are clamped. A trailing odd
  /// element is dropped rather than paired with a default.
  List<(double, double)> _touches(dynamic value) {
    if (value is! List) return const [];
    final out = <(double, double)>[];
    for (var i = 0; i + 1 < value.length; i += 2) {
      final x = value[i];
      final y = value[i + 1];
      if (x is! num || y is! num) continue;
      out.add((
        (x / 100).clamp(0.0, 1.0).toDouble(),
        (y / 100).clamp(0.0, 1.0).toDouble(),
      ));
    }
    return List.unmodifiable(out);
  }

  double? _nullableDouble(dynamic value) =>
      value is num ? value.toDouble() : null;

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
