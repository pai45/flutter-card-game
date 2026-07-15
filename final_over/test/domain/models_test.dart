import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FieldVector math is deterministic and immutable', () {
    const first = FieldVector(3, 4);
    const second = FieldVector(1, -2);
    expect(first.length, 5);
    expect(first + second, const FieldVector(4, 2));
    expect(first - second, const FieldVector(2, 6));
    expect(first.normalized.length, closeTo(1, 0.0000001));
    expect(FieldVector.lerp(first, second, 0.5), const FieldVector(2, 1));
  });

  test('MatchState exposes provisional score without committing it twice', () {
    final state = MatchState.initial().copyWith(
      committedScore: 5,
      pendingExtras: 1,
      pendingRuns: 2,
      pendingBatRuns: 4,
    );
    expect(state.score, 12);
    expect(state.committedScore, 5);
  });

  test('nullable copyWith fields can be deliberately cleared', () {
    final paused = MatchState.initial().copyWith(
      phase: MatchPhase.paused,
      suspendedPhase: MatchPhase.fieldPlay,
    );
    final resumed = paused.copyWith(
      phase: MatchPhase.fieldPlay,
      suspendedPhase: null,
    );
    expect(resumed.suspendedPhase, isNull);
  });

  test('history and fielder collections cannot be mutated', () {
    final history = <BallResult>[];
    final state = MatchState.initial().copyWith(history: history);
    history.clear();
    expect(state.history, isEmpty);
    expect(() => state.history.add(_dot), throwsUnsupportedError);
  });
}

const _dot = BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: 0,
  legal: true,
  extra: ExtraType.none,
  extraRuns: 0,
  runsOffBat: 0,
  completedRunningRuns: 0,
  boundary: 0,
  dismissal: DismissalType.none,
  contactType: ContactType.miss,
  timing: TimingGrade.miss,
  freeHitDelivery: false,
  historyToken: '0',
);
