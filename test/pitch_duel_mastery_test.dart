import 'package:card_game/models/match.dart';
import 'package:card_game/models/pitch_duel_mastery.dart';
import 'package:card_game/models/pitch_duel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PowerBreakdown power(int combo) => PowerBreakdown(
  player: 80,
  action: 12,
  scenario: 0,
  affinity: combo == 4 || combo == 10 ? 4 : 0,
  scenarioCombo: combo == 6 || combo == 10 ? 6 : 0,
  timing: 4,
);
MatchHistoryEntry history(
  String id, {
  String mode = 'match',
  int? goal,
  List<MatchHistoryRound> rounds = const [],
}) => MatchHistoryEntry(
  id: id,
  mode: mode,
  deckName: '',
  timestampIso: '',
  resultLabel: 'Draw',
  playerScore: 0,
  opponentScore: 0,
  rounds: rounds,
  pitchMasteryIndex: goal,
);

void main() {
  test(
    'goals rotate past retained-history limits and ignore demos/other sports',
    () {
      expect(pitchMasteryGoal([]).kind, PitchMasteryKind.linkedPlays);
      final records = [
        history('real', goal: 0),
        history('demo-seed', goal: 2),
        history('cricket', mode: 'finalover', goal: 2),
      ];
      expect(pitchMasteryGoal(records).kind, PitchMasteryKind.doubleMatch);
      expect(
        pitchCompletedMasteryGoal(records).kind,
        PitchMasteryKind.linkedPlays,
      );
      expect(
        pitchMasteryGoal([history('real', goal: 1)]).kind,
        PitchMasteryKind.linkedRoles,
      );
      expect(
        pitchMasteryGoal([history('real', goal: 2)]).kind,
        PitchMasteryKind.linkedPlays,
      );
      expect(
        pitchMasteryGoal([history('legacy')]).kind,
        PitchMasteryKind.doubleMatch,
      );
    },
  );
  test('both-role goal needs an attacking and defensive combination', () {
    const goal = PitchMasteryGoal(PitchMasteryKind.linkedRoles);
    expect(
      goal.progress([
        (attacking: true, power: power(4)),
        (attacking: true, power: power(10)),
      ]),
      1,
    );
    expect(
      goal.progress([
        (attacking: true, power: power(4)),
        (attacking: false, power: power(6)),
      ]),
      2,
    );
    expect(goal.progress([(attacking: false, power: power(0))]), 0);
    expect(
      const PitchMasteryGoal(
        PitchMasteryKind.doubleMatch,
      ).progress([(attacking: false, power: power(10))]),
      1,
    );
    expect(
      const PitchMasteryGoal(PitchMasteryKind.linkedPlays).progress([
        (attacking: true, power: power(4)),
        (attacking: false, power: power(6)),
        (attacking: true, power: power(10)),
      ]),
      2,
    );
  });
  test(
    'optional mastery history roundtrips and legacy history stays readable',
    () {
      final old = history('old').toJson()..remove('pitchMasteryIndex');
      expect(MatchHistoryEntry.fromJson(old).pitchMasteryIndex, isNull);
      expect(
        MatchHistoryEntry.fromJson(
          history('new', goal: 2).toJson(),
        ).pitchMasteryIndex,
        2,
      );
      expect(
        pitchBestLinkedPlays([
          history(
            'demo-x',
            rounds: [
              MatchHistoryRound(
                round: 1,
                scenarioTitle: '',
                outcomeLabel: '',
                playerAttacking: true,
                playerBreakdown: power(10),
              ),
            ],
          ),
          history('old'),
        ]),
        0,
      );
    },
  );
}
