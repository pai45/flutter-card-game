import 'package:flutter/material.dart';

/// Lifecycle of a fixture, which drives whether a prediction can still be made.
enum MatchStatus { upcoming, live, finished }

/// Sport governs how scores are laid out on the card (cricket shows per-team
/// score lines under the name; football shows a compact centre score).
enum Sport { cricket, football }

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

  /// XP shown on the reward strip once the match is finished/settled.
  final int rewardXp;

  /// Predictions are only editable before kickoff.
  bool get predictable => status == MatchStatus.upcoming;

  bool get hasScore => homeScore != null || awayScore != null;
}
