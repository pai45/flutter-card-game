import 'package:flutter/material.dart';

import 'basketball_scorecard.dart';
import 'cricket_scorecard.dart';
import 'tennis_scorecard.dart';

/// Lifecycle of a fixture, which drives whether a prediction can still be made.
enum MatchStatus { upcoming, live, finished }

enum MatchEventType { goal, yellowCard, redCard, substitution }

class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.isHomeTeam,
    required this.playerName,
    required this.type,
    this.secondaryPlayerName,
  });

  final int minute;
  final bool isHomeTeam;
  final String playerName;
  final MatchEventType type;
  final String? secondaryPlayerName; // Used for substitution (e.g. player subbed off)
}

class MatchCommentary {
  const MatchCommentary({
    required this.minute,
    required this.text,
    this.shortText,
    this.scoreValue,
    this.isWicket = false,
  });
  final String minute;
  final String text;
  final String? shortText;
  final int? scoreValue;
  final bool isWicket;
}

class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.name,
    required this.number,
    this.rating,
    this.imageUrl,
    this.role,
    this.isCaptain = false,
  });
  final String id;
  final String name;
  final int number;
  final double? rating;
  final String? imageUrl;
  final String? role;
  final bool isCaptain;
}

class MatchLineup {
  const MatchLineup({
    required this.formation,
    required this.startingXI,
    this.substitutes = const [],
    this.manager,
  });
  final String formation; // e.g. "4-3-3"
  final List<MatchPlayer> startingXI; // Always 11 players
  final List<MatchPlayer> substitutes; // Bench players
  final String? manager; // Manager/Coach name
}

class F1SessionResult {
  const F1SessionResult({
    required this.name,
    required this.results,
  });
  final String name; // e.g. "Practice 1", "Qualifying"
  final List<String> results; // e.g. ["1. Verstappen", "2. Hamilton"]
}

/// Sport governs how sport-specific surfaces lay out scores and modules.
enum Sport { football, cricket, f1, basketball, tennis }

/// One side of a fixture. Crest art can be added later via [crestAsset];
/// until then the UI falls back to an initials badge tinted with [color].
class SportTeam {
  const SportTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    this.crestAsset,
  });

  final String id;
  final String name;

  /// 2–4 letter code shown on the badge (e.g. "CSK", "MI").
  final String shortName;
  final Color color;
  final String? crestAsset;
}

/// A fixture shown on the prediction home. Mock-sourced for now; later this maps
/// to a backend/sports-feed payload without any UI change.
class SportMatch {
  const SportMatch({
    required this.id,
    required this.leagueId,
    required this.sport,
    required this.home,
    required this.away,
    required this.kickoff,
    required this.status,
    this.prizeLabel,
    this.liveMinute,
    this.homeScore,
    this.awayScore,
    this.resultLine,
    this.liveLastUpdated,
    this.liveStatusNote,
    this.timelineEvents,
    this.homeLineup,
    this.awayLineup,
    this.cricketScorecard,
    this.basketballScorecard,
    this.tennisScorecard,
    this.commentary,
    this.f1Sessions,
    this.f1DriverStandings,
    this.f1WeekendEndDate,
    this.rewardXp = 0,
  });

  final String id;
  final String leagueId;
  final Sport sport;
  final SportTeam home;
  final SportTeam away;
  final DateTime kickoff;
  final MatchStatus status;

  /// Virtual prize copy for the "make prediction" strip (e.g. "WIN ₹5000").
  final String? prizeLabel;

  /// Only meaningful while [status] is [MatchStatus.live].
  final int? liveMinute;

  /// Display-ready score per side. Football: "2". Cricket: "221-4" or
  /// "202-10 (20ov)" or "Yet to Bat". Null when not started.
  final String? homeScore;
  final String? awayScore;

  /// One-line outcome for finished matches, e.g. "Mumbai won by 19 runs".
  final String? resultLine;

  /// Timestamp from the live-score provider when a remote score was merged.
  final DateTime? liveLastUpdated;

  /// Non-fatal live-score state, e.g. missing API key or provider unavailable.
  final String? liveStatusNote;

  /// Timeline of match events like goals, cards, substitutions.
  final List<MatchEvent>? timelineEvents;

  /// Starting lineups and formations
  final MatchLineup? homeLineup;
  final MatchLineup? awayLineup;

  final CricketScorecard? cricketScorecard;
  final BasketballScorecard? basketballScorecard;
  final TennisScorecard? tennisScorecard;

  /// Play-by-play commentary.
  final List<MatchCommentary>? commentary;

  /// F1 Driver Standings.
  final List<String>? f1DriverStandings;

  /// F1 specific sessions (Practice, Qualifying, Race)
  final List<F1SessionResult>? f1Sessions;

  /// The end date of the F1 weekend, for displaying a date range.
  final DateTime? f1WeekendEndDate;

  /// XP shown on the reward strip once the match is finished/settled.
  final int rewardXp;

  /// Predictions are only editable before kickoff.
  bool get predictable => status == MatchStatus.upcoming;

  bool get hasScore => homeScore != null || awayScore != null;

  SportMatch copyWith({
    String? id,
    String? leagueId,
    Sport? sport,
    SportTeam? home,
    SportTeam? away,
    DateTime? kickoff,
    MatchStatus? status,
    String? prizeLabel,
    int? liveMinute,
    String? homeScore,
    String? awayScore,
    String? resultLine,
    DateTime? liveLastUpdated,
    String? liveStatusNote,
    List<MatchEvent>? timelineEvents,
    MatchLineup? homeLineup,
    MatchLineup? awayLineup,
    CricketScorecard? cricketScorecard,
    BasketballScorecard? basketballScorecard,
    TennisScorecard? tennisScorecard,
    List<MatchCommentary>? commentary,
    List<F1SessionResult>? f1Sessions,
    List<String>? f1DriverStandings,
    DateTime? f1WeekendEndDate,
    int? rewardXp,
    bool clearLiveMinute = false,
    bool clearHomeScore = false,
    bool clearAwayScore = false,
    bool clearResultLine = false,
    bool clearLiveLastUpdated = false,
    bool clearLiveStatusNote = false,
  }) => SportMatch(
    id: id ?? this.id,
    leagueId: leagueId ?? this.leagueId,
    sport: sport ?? this.sport,
    home: home ?? this.home,
    away: away ?? this.away,
    kickoff: kickoff ?? this.kickoff,
    status: status ?? this.status,
    prizeLabel: prizeLabel ?? this.prizeLabel,
    liveMinute: clearLiveMinute ? null : liveMinute ?? this.liveMinute,
    homeScore: clearHomeScore ? null : homeScore ?? this.homeScore,
    awayScore: clearAwayScore ? null : awayScore ?? this.awayScore,
    resultLine: clearResultLine ? null : resultLine ?? this.resultLine,
    liveLastUpdated: clearLiveLastUpdated
        ? null
        : liveLastUpdated ?? this.liveLastUpdated,
    liveStatusNote: clearLiveStatusNote
        ? null
        : liveStatusNote ?? this.liveStatusNote,
    timelineEvents: timelineEvents ?? this.timelineEvents,
    homeLineup: homeLineup ?? this.homeLineup,
    awayLineup: awayLineup ?? this.awayLineup,
    cricketScorecard: cricketScorecard ?? this.cricketScorecard,
    basketballScorecard: basketballScorecard ?? this.basketballScorecard,
    tennisScorecard: tennisScorecard ?? this.tennisScorecard,
    commentary: commentary ?? this.commentary,
    f1Sessions: f1Sessions ?? this.f1Sessions,
    f1DriverStandings: f1DriverStandings ?? this.f1DriverStandings,
    f1WeekendEndDate: f1WeekendEndDate ?? this.f1WeekendEndDate,
    rewardXp: rewardXp ?? this.rewardXp,
  );
}
