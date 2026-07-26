import '../models/match_outcome.dart';
import '../models/sport_match.dart';

/// Computes a sport-agnostic [MatchOutcome] from a finished [SportMatch]'s
/// already-enriched data (scores, scorecards, timeline). Pure and synchronous
/// — no network calls happen here; enrichment (fetching that data) is
/// [EspnScoreService]'s job, done before this ever runs. Called once per
/// finished match by the rollover engine; its result is fanned out to both
/// the quiz-settlement writer and the market-settlement writer so "who won"
/// is computed exactly once, not duplicated between the two systems.
abstract final class MatchOutcomeResolver {
  static MatchOutcome resolve(SportMatch match) {
    if (match.status != MatchStatus.finished) {
      return MatchOutcome.unresolved(match.id);
    }
    return switch (match.sport) {
      Sport.football => _resolveFootball(match),
      Sport.cricket => _resolveCricket(match, allowPartial: false),
      Sport.tennis => _resolveTennis(match, allowPartial: false),
      Sport.basketball => _resolveBasketball(match),
      Sport.motorsport => _resolveMotorsport(match, allowPartial: false),
    };
  }

  /// Best-known in-play facts. Unlike [resolve], this accepts a live fixture
  /// and deliberately keeps partial sport data for question-status signals.
  static MatchOutcome resolveCurrent(SportMatch match) => switch (match.sport) {
    Sport.football => _resolveFootball(match),
    Sport.cricket => _resolveCricket(match, allowPartial: true),
    Sport.tennis => _resolveTennis(match, allowPartial: true),
    Sport.basketball => _resolveBasketball(match),
    Sport.motorsport => _resolveMotorsport(match, allowPartial: true),
  };

  static MatchOutcome _resolveFootball(SportMatch match) {
    final home = _parseInt(match.homeScore);
    final away = _parseInt(match.awayScore);
    if (home == null || away == null) return MatchOutcome.unresolved(match.id);

    OutcomeSide? firstScorer;
    final goals =
        match.timelineEvents
            ?.where((e) => e.type == MatchEventType.goal)
            .toList()
          ?..sort((a, b) => a.minute.compareTo(b.minute));
    if (goals != null && goals.isNotEmpty) {
      firstScorer = goals.first.isHomeTeam
          ? OutcomeSide.home
          : OutcomeSide.away;
    }

    return MatchOutcome(
      matchId: match.id,
      isFullyResolved: true,
      winner: _sideFor(home, away),
      homeScore: home,
      awayScore: away,
      bothSidesScored: home > 0 && away > 0,
      totalScoreLine: home + away,
      firstScorerSide: firstScorer,
    );
  }

  static MatchOutcome _resolveCricket(
    SportMatch match, {
    required bool allowPartial,
  }) {
    final scorecard = match.cricketScorecard;
    final resultLine = match.resultLine?.toLowerCase() ?? '';
    final noResult =
        resultLine.contains('no result') || resultLine.contains('abandon');

    OutcomeSide? winner;
    if (noResult ||
        resultLine.contains('tied') ||
        resultLine.contains(' tie ')) {
      winner = OutcomeSide.draw;
    } else if (resultLine.isNotEmpty) {
      final homeMentioned = resultLine.contains(match.home.name.toLowerCase());
      final awayMentioned = resultLine.contains(match.away.name.toLowerCase());
      final wonMentioned = resultLine.contains('won');
      if (wonMentioned && homeMentioned && !awayMentioned) {
        winner = OutcomeSide.home;
      } else if (wonMentioned && awayMentioned && !homeMentioned) {
        winner = OutcomeSide.away;
      }
    }

    int? homeRuns;
    int? awayRuns;
    var totalSixes = 0;
    var totalWickets = 0;
    var topScore = 0;
    int? firstInningsRuns;
    if (scorecard != null && scorecard.innings.isNotEmpty) {
      for (final innings in scorecard.innings) {
        for (final batter in innings.batters) {
          totalSixes += batter.sixes;
          if (batter.runs > topScore) topScore = batter.runs;
        }
        totalWickets +=
            _wicketsFromScore(innings.scoreText) ??
            innings.batters
                .where((batter) => batter.dismissalText != null)
                .length;
        final runs = _leadingInt(innings.scoreText);
        if (runs == null) continue;
        final isHomeInnings = innings.teamName.toLowerCase().contains(
          match.home.name.toLowerCase(),
        );
        final isAwayInnings = innings.teamName.toLowerCase().contains(
          match.away.name.toLowerCase(),
        );
        if (isHomeInnings && homeRuns == null) homeRuns = runs;
        if (isAwayInnings && awayRuns == null) awayRuns = runs;
      }
      firstInningsRuns = _leadingInt(scorecard.innings.first.scoreText);

      // Fall back to comparing totals directly if the result line couldn't
      // name a winner but both sides' runs are known.
      winner ??= (homeRuns != null && awayRuns != null)
          ? _sideFor(homeRuns, awayRuns)
          : null;
    }

    final resolved = winner != null || (homeRuns != null && awayRuns != null);
    if (!resolved && !allowPartial) return MatchOutcome.unresolved(match.id);
    if (!resolved && scorecard == null) {
      return MatchOutcome.unresolved(match.id);
    }

    return MatchOutcome(
      matchId: match.id,
      isFullyResolved: resolved && match.status == MatchStatus.finished,
      winner: winner,
      homeScore: homeRuns,
      awayScore: awayRuns,
      totalScoreLine: (homeRuns != null && awayRuns != null)
          ? homeRuns + awayRuns
          : null,
      sportSpecific: {
        'totalSixes': scorecard != null && scorecard.innings.isNotEmpty
            ? totalSixes
            : null,
        'firstInningsRuns': firstInningsRuns,
        'firstInningsComplete':
            match.status == MatchStatus.finished ||
            (scorecard?.innings.length ?? 0) > 1,
        'topScore': scorecard != null && scorecard.innings.isNotEmpty
            ? topScore
            : null,
        'totalWickets': scorecard != null && scorecard.innings.isNotEmpty
            ? totalWickets
            : null,
      },
    );
  }

  static MatchOutcome _resolveTennis(
    SportMatch match, {
    required bool allowPartial,
  }) {
    final scorecard = match.tennisScorecard;
    if (scorecard == null || scorecard.sets.isEmpty) {
      return MatchOutcome.unresolved(match.id);
    }
    final homeSets = scorecard.sets.where((s) => s.isHomeWinner).length;
    final awaySets = scorecard.sets.where((s) => s.isAwayWinner).length;
    if (homeSets == awaySets && !allowPartial) {
      return MatchOutcome.unresolved(match.id);
    }

    final winner = homeSets == awaySets
        ? null
        : (homeSets > awaySets ? OutcomeSide.home : OutcomeSide.away);
    final winnerSets = homeSets > awaySets ? homeSets : awaySets;
    final straightSets = winnerSets == scorecard.sets.length;
    final firstSet = scorecard.sets.first;
    final set1Winner = firstSet.isHomeWinner
        ? OutcomeSide.home
        : (firstSet.isAwayWinner ? OutcomeSide.away : null);

    return MatchOutcome(
      matchId: match.id,
      isFullyResolved:
          match.status == MatchStatus.finished && homeSets != awaySets,
      winner: winner,
      sportSpecific: {
        'totalSets': scorecard.sets.length,
        'totalGames': scorecard.sets.fold<int>(
          0,
          (total, set) => total + set.homeScore + set.awayScore,
        ),
        'straightSets': straightSets,
        'set1Winner': set1Winner,
      },
    );
  }

  static MatchOutcome _resolveBasketball(SportMatch match) {
    final scorecard = match.basketballScorecard;
    if (scorecard == null) return MatchOutcome.unresolved(match.id);
    final home = scorecard.linescores.homeTotal;
    final away = scorecard.linescores.awayTotal;

    OutcomeSide? biggestQuarterSide;
    var biggestMargin = -1;
    final homeQ = scorecard.linescores.homeScores;
    final awayQ = scorecard.linescores.awayScores;
    for (var i = 0; i < homeQ.length && i < awayQ.length; i++) {
      final margin = (homeQ[i] - awayQ[i]).abs();
      if (margin > biggestMargin) {
        biggestMargin = margin;
        biggestQuarterSide = homeQ[i] >= awayQ[i]
            ? OutcomeSide.home
            : OutcomeSide.away;
      }
    }
    final halftimeHome = homeQ
        .take(2)
        .fold<int>(0, (sum, value) => sum + value);
    final halftimeAway = awayQ
        .take(2)
        .fold<int>(0, (sum, value) => sum + value);
    final halftimeLeader = homeQ.length < 2 || awayQ.length < 2
        ? null
        : _sideFor(halftimeHome, halftimeAway);

    return MatchOutcome(
      matchId: match.id,
      isFullyResolved: true,
      winner: _sideFor(home, away),
      homeScore: home,
      awayScore: away,
      totalScoreLine: home + away,
      sportSpecific: {
        'biggestQuarterSide': biggestQuarterSide,
        'winningMargin': (home - away).abs(),
        'halftimeLeader': halftimeLeader,
        'halftimeComplete':
            match.status == MatchStatus.finished ||
            (homeQ.length >= 3 &&
                awayQ.length >= 3 &&
                (homeQ[2] > 0 || awayQ[2] > 0)),
      },
    );
  }

  static MatchOutcome _resolveMotorsport(
    SportMatch match, {
    required bool allowPartial,
  }) {
    final sessions = match.f1Sessions;
    if (sessions == null || sessions.isEmpty) {
      return MatchOutcome.unresolved(match.id);
    }
    final race = _sessionNamed(sessions, 'race');
    if ((race == null || race.results.isEmpty) && !allowPartial) {
      return MatchOutcome.unresolved(match.id);
    }
    final podium = race?.results.take(3).map(_driverName).toList() ?? const [];
    final winnerName = podium.isEmpty ? null : podium.first;
    final winningConstructor = race == null || race.results.isEmpty
        ? null
        : _constructorName(race.results.first);

    String? poleSitter;
    final qualifying = _sessionNamed(sessions, 'qualifying');
    if (qualifying != null && qualifying.results.isNotEmpty) {
      poleSitter = _driverName(qualifying.results.first);
    }
    final qualifyingOrder =
        qualifying?.results.map(_driverName).toList() ?? const <String>[];
    final winnerGridIndex = winnerName == null
        ? -1
        : qualifyingOrder.indexWhere(
            (driver) => driver.toLowerCase() == winnerName.toLowerCase(),
          );

    return MatchOutcome(
      matchId: match.id,
      isFullyResolved:
          match.status == MatchStatus.finished && winnerName != null,
      sportSpecific: {
        'winnerName': winnerName,
        'podiumNames': podium,
        'poleSitter': poleSitter,
        'winningConstructor': winningConstructor,
        'poleToWin': poleSitter == null || winnerName == null
            ? null
            : poleSitter == winnerName,
        'winnerStartedTopThree': winnerGridIndex < 0
            ? null
            : winnerGridIndex < 3,
        // Fastest lap isn't modelled in F1SessionResult today — any archetype
        // asking for it must void until that data is captured.
        'fastestLapName': null,
      },
    );
  }

  static F1SessionResult? _sessionNamed(
    List<F1SessionResult> sessions,
    String needle,
  ) {
    for (final s in sessions) {
      if (s.name.toLowerCase().contains(needle)) return s;
    }
    return null;
  }

  /// Strips a leading "1. "/"2) " style position marker from a results entry.
  static String _stripPosition(String entry) =>
      entry.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '').trim();

  static String _driverName(String entry) =>
      _stripPosition(entry).split(' · ').first.split(' (').first.trim();

  static String? _constructorName(String entry) {
    final parts = _stripPosition(entry).split(' · ');
    if (parts.length < 2) return null;
    return parts[1].split(' (').first.trim();
  }

  static OutcomeSide _sideFor(int home, int away) => home == away
      ? OutcomeSide.draw
      : (home > away ? OutcomeSide.home : OutcomeSide.away);

  static int? _parseInt(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  /// Extracts the leading integer from a cricket score string like
  /// "171 (20 ov)" or "202-10 (20 ov)" — the number before any space/dash.
  static int? _leadingInt(String text) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static int? _wicketsFromScore(String text) {
    final match = RegExp(r'^\s*\d+\s*-\s*(\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
