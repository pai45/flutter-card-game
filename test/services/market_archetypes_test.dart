import 'package:card_game/models/match_outcome.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/market_archetypes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PickMarket _market(
  String archetype, {
  List<PickOutcome> outcomes = const [
    PickOutcome(id: 'home', label: 'Home', probabilityPercent: 50, color: Color(0xffffffff)),
    PickOutcome(id: 'away', label: 'Away', probabilityPercent: 50, color: Color(0xffffffff)),
  ],
}) => PickMarket(
  id: 'test::$archetype',
  question: 'Test question',
  type: PickMarketType.match,
  sport: Sport.football,
  leagueId: 'test',
  leagueLabel: 'TEST',
  status: PickMarketStatus.upcoming,
  outcomes: outcomes,
  volumeOz: 1000,
  closesAt: DateTime(2026, 7, 18),
  matchId: 'test',
);

const _overUnder = [
  PickOutcome(id: 'over', label: 'Over', probabilityPercent: 50, color: Color(0xffffffff)),
  PickOutcome(id: 'under', label: 'Under', probabilityPercent: 50, color: Color(0xffffffff)),
];

const _yesNo = [
  PickOutcome(id: 'yes', label: 'Yes', probabilityPercent: 50, color: Color(0xffffffff)),
  PickOutcome(id: 'no', label: 'No', probabilityPercent: 50, color: Color(0xffffffff)),
];

void main() {
  group('MarketArchetypes — unresolved outcome always voids', () {
    for (final archetype in [
      'winner',
      'btts',
      'total_goals_ou',
      'total_sixes_ou',
      'first_innings_runs_ou',
      'total_points_ou',
      'total_sets_ou',
      'straight_sets',
      'race_winner',
    ]) {
      test('$archetype voids when the match never resolved', () {
        final market = _market(
          archetype,
          outcomes: archetype == 'btts' || archetype == 'straight_sets'
              ? _yesNo
              : archetype.endsWith('_ou')
              ? _overUnder
              : const [
                  PickOutcome(id: 'home', label: 'Home', probabilityPercent: 50, color: Color(0xffffffff)),
                  PickOutcome(id: 'away', label: 'Away', probabilityPercent: 50, color: Color(0xffffffff)),
                ],
        );
        final settled = MarketArchetypes.settle(market, const MatchOutcome.unresolved('test'));
        expect(settled.status, PickMarketStatus.voided);
        expect(settled.resolvedOutcomeId, isNull);
      });
    }
  });

  group('MarketArchetypes — basketball', () {
    test('total_points_ou settles over when combined score beats the line', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        winner: OutcomeSide.home,
        totalScoreLine: 165,
      );
      final settled = MarketArchetypes.settle(_market('total_points_ou', outcomes: _overUnder), outcome);
      expect(settled.status, PickMarketStatus.settled);
      expect(settled.resolvedOutcomeId, 'over');
    });

    test('total_points_ou settles under when combined score is below the line', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        winner: OutcomeSide.away,
        totalScoreLine: 140,
      );
      final settled = MarketArchetypes.settle(_market('total_points_ou', outcomes: _overUnder), outcome);
      expect(settled.resolvedOutcomeId, 'under');
    });
  });

  group('MarketArchetypes — tennis', () {
    test('total_sets_ou and straight_sets settle from sportSpecific', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        winner: OutcomeSide.home,
        sportSpecific: {'totalSets': 3, 'straightSets': true},
      );
      final sets = MarketArchetypes.settle(_market('total_sets_ou', outcomes: _overUnder), outcome);
      expect(sets.resolvedOutcomeId, 'under'); // 3 < 3.5 line
      final straight = MarketArchetypes.settle(_market('straight_sets', outcomes: _yesNo), outcome);
      expect(straight.resolvedOutcomeId, 'yes');
    });

    test('a 5-set match settles total_sets_ou over and straight_sets no', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        winner: OutcomeSide.away,
        sportSpecific: {'totalSets': 5, 'straightSets': false},
      );
      final sets = MarketArchetypes.settle(_market('total_sets_ou', outcomes: _overUnder), outcome);
      expect(sets.resolvedOutcomeId, 'over');
      final straight = MarketArchetypes.settle(_market('straight_sets', outcomes: _yesNo), outcome);
      expect(straight.resolvedOutcomeId, 'no');
    });
  });

  group('MarketArchetypes — motorsport race_winner', () {
    test('matches the resolved winner name against a driver-slug outcome', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        sportSpecific: {'winnerName': 'Lewis Hamilton'},
      );
      final market = _market(
        'race_winner',
        outcomes: const [
          PickOutcome(id: 'lewis_hamilton', label: 'Lewis Hamilton', probabilityPercent: 30, color: Color(0xffffffff)),
          PickOutcome(id: 'max_verstappen', label: 'Max Verstappen', probabilityPercent: 40, color: Color(0xffffffff)),
          PickOutcome(id: 'other', label: 'Other', probabilityPercent: 30, color: Color(0xffffffff)),
        ],
      );
      final settled = MarketArchetypes.settle(market, outcome);
      expect(settled.status, PickMarketStatus.settled);
      expect(settled.resolvedOutcomeId, 'lewis_hamilton');
    });

    test('falls back to the "other" outcome when the winner is not a listed candidate', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        sportSpecific: {'winnerName': 'Someone Else'},
      );
      final market = _market(
        'race_winner',
        outcomes: const [
          PickOutcome(id: 'lewis_hamilton', label: 'Lewis Hamilton', probabilityPercent: 60, color: Color(0xffffffff)),
          PickOutcome(id: 'other', label: 'Other', probabilityPercent: 40, color: Color(0xffffffff)),
        ],
      );
      final settled = MarketArchetypes.settle(market, outcome);
      expect(settled.resolvedOutcomeId, 'other');
    });

    test('voids when there is no "other" catch-all and the winner is unlisted', () {
      const outcome = MatchOutcome(
        matchId: 'test',
        isFullyResolved: true,
        sportSpecific: {'winnerName': 'Someone Else'},
      );
      final market = _market(
        'race_winner',
        outcomes: const [
          PickOutcome(id: 'lewis_hamilton', label: 'Lewis Hamilton', probabilityPercent: 100, color: Color(0xffffffff)),
        ],
      );
      final settled = MarketArchetypes.settle(market, outcome);
      expect(settled.status, PickMarketStatus.voided);
    });
  });
}
