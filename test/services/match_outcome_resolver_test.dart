import 'package:card_game/data/wc_third_place_2026.dart';
import 'package:card_game/models/cricket_scorecard.dart';
import 'package:card_game/models/match_outcome.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/match_outcome_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SportTeam _team(String name) =>
    SportTeam(id: name.toLowerCase(), name: name, shortName: name.substring(0, 3), color: const Color(0xffffffff));

SportMatch _finished({
  required Sport sport,
  String? homeScore,
  String? awayScore,
  String? resultLine,
  List<MatchEvent>? timelineEvents,
  CricketScorecard? cricketScorecard,
}) => SportMatch(
  id: 'test',
  leagueId: 'test',
  sport: sport,
  home: _team('France'),
  away: _team('England'),
  kickoff: DateTime(2026, 7, 18),
  status: MatchStatus.finished,
  homeScore: homeScore,
  awayScore: awayScore,
  resultLine: resultLine,
  timelineEvents: timelineEvents,
  cricketScorecard: cricketScorecard,
);

void main() {
  group('MatchOutcomeResolver — unresolved cases', () {
    test('a non-finished match is always unresolved', () {
      final match = _finished(
        sport: Sport.football,
        homeScore: '1',
        awayScore: '1',
      ).copyWith(status: MatchStatus.live);
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.isFullyResolved, isFalse);
    });

    test('football with no score is unresolved', () {
      final match = _finished(sport: Sport.football);
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.isFullyResolved, isFalse);
    });
  });

  group('MatchOutcomeResolver — football, real WC third-place data', () {
    // Real result: France 4-6 England, Hard Rock Stadium, 18 Jul 2026.
    late MatchOutcome outcome;

    setUp(() {
      final match = _finished(
        sport: Sport.football,
        homeScore: '4',
        awayScore: '6',
        timelineEvents: kWcThirdPlaceTimeline,
      );
      outcome = MatchOutcomeResolver.resolve(match);
    });

    test('resolves fully', () => expect(outcome.isFullyResolved, isTrue));

    test('England (away) won', () {
      expect(outcome.winner, OutcomeSide.away);
      expect(outcome.homeScore, 4);
      expect(outcome.awayScore, 6);
    });

    test('both sides scored and total is 10', () {
      expect(outcome.bothSidesScored, isTrue);
      expect(outcome.totalScoreLine, 10);
    });

    test('England scored first (Declan Rice, 3\')', () {
      expect(outcome.firstScorerSide, OutcomeSide.away);
    });
  });

  group('MatchOutcomeResolver — football edge cases', () {
    test('a draw resolves winner as draw and BTTS true', () {
      final match = _finished(sport: Sport.football, homeScore: '1', awayScore: '1');
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.winner, OutcomeSide.draw);
      expect(outcome.bothSidesScored, isTrue);
    });

    test('a 0-0 has no first scorer', () {
      final match = _finished(sport: Sport.football, homeScore: '0', awayScore: '0', timelineEvents: const []);
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.firstScorerSide, isNull);
      expect(outcome.bothSidesScored, isFalse);
    });
  });

  group('MatchOutcomeResolver — cricket', () {
    test('no-result match is unresolved', () {
      final match = _finished(sport: Sport.cricket, resultLine: 'Match abandoned, no result');
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.isFullyResolved, isFalse);
    });

    test('a tie resolves as a draw', () {
      final match = _finished(
        sport: Sport.cricket,
        resultLine: 'Match tied',
        cricketScorecard: const CricketScorecard(
          innings: [
            CricketInnings(teamName: 'France', scoreText: '160 (20 ov)', batters: [], bowlers: []),
            CricketInnings(teamName: 'England', scoreText: '160-8 (20 ov)', batters: [], bowlers: []),
          ],
        ),
      );
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.winner, OutcomeSide.draw);
    });

    test('winner named in the result line resolves correctly', () {
      final match = _finished(
        sport: Sport.cricket,
        resultLine: 'England won by 23 runs',
        cricketScorecard: const CricketScorecard(
          innings: [
            CricketInnings(
              teamName: 'France',
              scoreText: '150 (20 ov)',
              batters: [
                CricketBatter(name: 'A', runs: 60, balls: 40, fours: 4, sixes: 3, strikeRate: 150),
              ],
              bowlers: [],
            ),
            CricketInnings(
              teamName: 'England',
              scoreText: '173-4 (20 ov)',
              batters: [
                CricketBatter(name: 'B', runs: 80, balls: 45, fours: 6, sixes: 4, strikeRate: 177),
              ],
              bowlers: [],
            ),
          ],
        ),
      );
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.winner, OutcomeSide.away);
      expect(outcome.homeScore, 150);
      expect(outcome.awayScore, 173);
      expect(outcome.sportSpecific['totalSixes'], 7);
      expect(outcome.sportSpecific['firstInningsRuns'], 150);
      expect(outcome.sportSpecific['topScore'], 80);
    });

    test('falls back to comparing totals when the result line is ambiguous', () {
      final match = _finished(
        sport: Sport.cricket,
        resultLine: '',
        cricketScorecard: const CricketScorecard(
          innings: [
            CricketInnings(teamName: 'France', scoreText: '140 (20 ov)', batters: [], bowlers: []),
            CricketInnings(teamName: 'England', scoreText: '145-3 (18.2 ov)', batters: [], bowlers: []),
          ],
        ),
      );
      final outcome = MatchOutcomeResolver.resolve(match);
      expect(outcome.winner, OutcomeSide.away);
    });
  });
}
