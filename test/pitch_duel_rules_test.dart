import 'dart:math';

import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/models/pitch_duel_rules.dart';
import 'package:card_game/models/progression.dart';
import 'package:flutter_test/flutter_test.dart';

ActionCard action(String id, [CardTier tier = CardTier.bronze]) =>
    actionCards.firstWhere((a) => pitchActionBaseId(a) == id && a.tier == tier);

void verifyEveryContinuation(
  List<ActionCard> deck,
  bool attacking, [
  int round = 1,
  List<String> used = const [],
]) {
  if (round > 4) return;
  final legal = pitchLegalActions(
    actions: deck,
    usedIds: used,
    round: round,
    attacking: attacking,
  );
  expect(
    legal,
    isNotEmpty,
    reason: 'Round $round / ${deck.map((a) => a.id)} / $used',
  );
  for (final a in legal) {
    expect(used, isNot(contains(a.id)));
    expect(pitchActionFitsRole(a, attacking), isTrue);
    verifyEveryContinuation(deck, !attacking, round + 1, [...used, a.id]);
  }
}

void main() {
  test('all football players have one affinity; other sports do not', () {
    for (final p in [...attackers, ...defenders]) {
      expect(pitchPlayerAffinities[p.id], isNotNull);
      expect(pitchMatchingActionNames(pitchAffinityFor(p)!), isNotEmpty);
    }
    expect(pitchAffinityFor(batsmen.first), isNull);
    expect(pitchAffinityFor(goalkeepers.first), isNull);
  });

  test(
    'every affinity and tier earns +4 once, scenario +6 once, capped at +10',
    () {
      for (final affinity in PitchAffinity.values) {
        final p = [
          ...attackers,
          ...defenders,
        ].firstWhere((p) => pitchAffinityFor(p) == affinity);
        final attacking = p.role == PlayerRole.attacker;
        final id = pitchAffinityActions[affinity]!.firstWhere(
          (id) => pitchActionFitsRole(action(id), attacking),
        );
        final scenario = scenarios.firstWhere(
          (s) => pitchScenarioActions[s.id]!.contains(id),
        );
        for (final tier in CardTier.values) {
          final a = action(id, tier);
          final b = pitchPower(
            player: p,
            action: a,
            scenario: scenario,
            attacking: attacking,
            timing: 8,
          );
          expect(b.affinity, 4);
          expect(b.scenarioCombo, 6);
          expect(b.combo, 10);
          expect(
            b.scenario,
            attacking ? scenario.attackBonus : scenario.defenseBonus,
          );
          expect(b.total, p.rating + a.power + b.scenario + 10 + 8);
        }
      }
    },
  );

  test(
    'authored football matches, isolated bonuses and All In stay honest',
    () {
      for (final pair in [('sc1', 'act6'), ('sc3', 'act5'), ('sc5', 'act9')]) {
        expect(pitchScenarioActions[pair.$1], contains(pair.$2));
      }
      final p = attackers.firstWhere(
        (p) => pitchAffinityFor(p) == PitchAffinity.finisher,
      );
      final a = action('act1');
      final noMatch = scenarios.firstWhere(
        (s) => !pitchScenarioActions[s.id]!.contains('act1'),
      );
      expect(
        pitchPower(
          player: p,
          action: a,
          scenario: noMatch,
          attacking: true,
        ).combo,
        4,
      );
      final runner = attackers.firstWhere(
        (p) => pitchAffinityFor(p) == PitchAffinity.runner,
      );
      expect(
        pitchPower(
          player: runner,
          action: a,
          scenario: scenarios.first,
          attacking: true,
        ).combo,
        6,
      );
      for (final tier in CardTier.values) {
        for (final s in scenarios) {
          expect(
            pitchPower(
              player: p,
              action: action('act13', tier),
              scenario: s,
              attacking: true,
            ).combo,
            0,
          );
        }
        expect(action('act14', tier).title, 'Disrupt Play');
      }
    },
  );

  test('a lower-rated contextual card can beat a stronger alternative', () {
    final runners = attackers.where(
      (p) => pitchAffinityFor(p) == PitchAffinity.runner,
    );
    final others = attackers.where(
      (p) => pitchAffinityFor(p) != PitchAffinity.runner,
    );
    final candidates = [
      for (final low in runners)
        for (final high in others)
          if (high.rating > low.rating && high.rating - low.rating < 4)
            (low, high),
    ];
    expect(candidates, isNotEmpty);
    final pair = candidates.first;
    int score(PlayerCard p) => pitchPower(
      player: p,
      action: action('act6'),
      scenario: scenarios.first,
      attacking: true,
    ).base;
    expect(score(pair.$1), greaterThan(score(pair.$2)));
  });

  test('timing boundaries are centered, inclusive and symmetric', () {
    expect(ShotTimingResult.accessible.bonus, 4);
    for (final boundary in [
      (ShotTimingResult.perfectHalfWidth, 8),
      (ShotTimingResult.greatHalfWidth, 6),
      (ShotTimingResult.goodHalfWidth, 4),
    ]) {
      for (final direction in [-1, 1]) {
        expect(
          ShotTimingResult.at(.5 + direction * boundary.$1).bonus,
          boundary.$2,
        );
        expect(
          ShotTimingResult.at(.5 + direction * (boundary.$1 + .00001)).bonus,
          lessThan(boundary.$2),
        );
      }
    }
    expect(ShotTimingResult.at(.5).quality, ShotTimingQuality.perfect);
    expect(ShotTimingResult.at(-1).quality, ShotTimingQuality.early);
    expect(ShotTimingResult.at(2).quality, ShotTimingQuality.late);
  });

  test('reservation protects every future round for either starting role', () {
    final deck = [
      action('act1'),
      action('act2'),
      action('act3'),
      action('act4'),
      action('act7'),
      action('act13'),
    ];
    expect(pitchCanComplete(deck, [true, false, true, false]), isTrue);
    expect(
      pitchLegalActions(
        actions: deck,
        usedIds: [],
        round: 1,
        attacking: true,
      ).map((a) => a.id),
      isNot(contains(action('act13').id)),
    );
    verifyEveryContinuation(deck, true);
    verifyEveryContinuation(deck, false);
    expect(
      pitchCanComplete(
        [action('act1'), action('act1'), action('act7'), action('act7')],
        [true, false, true, false],
      ),
      isFalse,
    );
    expect(
      pitchCanComplete(
        [for (var i = 1; i <= 6; i++) action('act$i')],
        [true, false, true, false],
      ),
      isFalse,
    );
  });

  test(
    'generated CPU decks complete all legal continuations at all difficulties',
    () {
      for (final level in [1, 6, 12, 25]) {
        for (var seed = 0; seed < 15; seed++) {
          final cpu = generateOpponentDeck(
            level,
            attackers,
            defenders,
            actionCards,
            random: Random(seed),
          );
          expect(cpu.attackers.map((p) => p.id).toSet(), hasLength(2));
          expect(cpu.defenders.map((p) => p.id).toSet(), hasLength(2));
          expect(cpu.actions.map((a) => a.id).toSet(), hasLength(6));
          verifyEveryContinuation(cpu.actions, true);
          verifyEveryContinuation(cpu.actions, false);
        }
      }
    },
  );

  test('rival range bounds every remaining legal pair and timing outcome', () {
    final deck = [
      action('act7'),
      action('act8'),
      action('act9'),
      action('act1'),
      action('act2'),
      action('act13'),
    ];
    final usedPlayers = [defenders.first.id];
    final usedActions = [action('act7').id, action('act1').id];
    final players = defenders.take(2).toList();
    final range = pitchRivalRange(
      players: players,
      actions: deck,
      usedPlayers: usedPlayers,
      usedActions: usedActions,
      scenario: scenarios.first,
      round: 3,
      attacking: false,
    )!;
    final powers = [
      for (final p in players.where((p) => !usedPlayers.contains(p.id)))
        for (final a in pitchLegalActions(
          actions: deck,
          usedIds: usedActions,
          round: 3,
          attacking: false,
        ))
          pitchPower(
            player: p,
            action: a,
            scenario: scenarios.first,
            attacking: false,
          ).base,
    ]..sort();
    expect(range.min, powers.first);
    expect(range.max, powers.last + 8);
  });

  test('optional history breakdowns round trip and old records still load', () {
    final old = {
      'round': 1,
      'scenarioTitle': 'Counter Attack',
      'outcomeLabel': 'GOAL',
      'playerAttacking': true,
    };
    expect(MatchHistoryRound.fromJson(old).playerBreakdown, isNull);
    final breakdown = pitchPower(
      player: attackers.first,
      action: action('act1'),
      scenario: scenarios.first,
      attacking: true,
      timing: 8,
    );
    final round = MatchHistoryRound.fromJson({
      ...old,
      'playerBreakdown': breakdown.toJson(),
    });
    expect(
      MatchHistoryRound.fromJson(round.toJson()).playerBreakdown!.total,
      breakdown.total,
    );
  });
}
