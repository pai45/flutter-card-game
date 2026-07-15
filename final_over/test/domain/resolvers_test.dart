import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

DeliverySpec delivery({
  DeliveryLine line = DeliveryLine.middle,
  DeliveryLength length = DeliveryLength.good,
  ExtraType extra = ExtraType.none,
  double movement = 0,
}) => DeliverySpec(
  ordinal: 1,
  seed: 1,
  line: line,
  length: length,
  speed: 0.9,
  movement: movement,
  extra: extra,
  lineX: GameplayTuning.lineX[line]!,
  expectedContactMicros: 1000000,
);

BallResult result({
  bool legal = true,
  ExtraType extra = ExtraType.none,
  int extraRuns = 0,
  int batRuns = 0,
  int runningRuns = 0,
  int boundary = 0,
  DismissalType dismissal = DismissalType.none,
  ContactType contact = ContactType.clean,
  int legalBallsBefore = 0,
}) => BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: legalBallsBefore,
  legal: legal,
  extra: extra,
  extraRuns: extraRuns,
  runsOffBat: batRuns,
  completedRunningRuns: runningRuns,
  boundary: boundary,
  dismissal: dismissal,
  contactType: contact,
  timing: TimingGrade.good,
  freeHitDelivery: false,
  historyToken: 'test',
);

void main() {
  group('timing', () {
    test('continuous boundaries are inclusive', () {
      expect(TimingResolver.resolve(-50), TimingGrade.perfect);
      expect(TimingResolver.resolve(50), TimingGrade.perfect);
      expect(TimingResolver.resolve(-51), TimingGrade.good);
      expect(TimingResolver.resolve(115), TimingGrade.good);
      expect(TimingResolver.resolve(-116), TimingGrade.early);
      expect(TimingResolver.resolve(190), TimingGrade.late);
      expect(TimingResolver.resolve(-191), TimingGrade.poor);
      expect(TimingResolver.resolve(275), TimingGrade.poor);
      expect(TimingResolver.resolve(276), TimingGrade.miss);
      expect(TimingResolver.resolve(0, hasInput: false), TimingGrade.miss);
    });
  });

  group('contact', () {
    const resolver = ContactResolver();

    test(
      'compatibility rewards matching line and applies mismatch penalty',
      () {
        final ball = delivery(
          line: DeliveryLine.off,
          length: DeliveryLength.good,
        );
        final matching = resolver.compatibility(
          ball,
          ShotDirection.offSide,
          Elevation.ground,
        );
        final mismatch = resolver.compatibility(
          ball,
          ShotDirection.legSide,
          Elevation.ground,
        );
        expect(matching - mismatch, closeTo(0.26, 0.000001));
      },
    );

    test('unreachable ball misses even with perfect input', () {
      final outcome = resolver.resolve(
        delivery: delivery(line: DeliveryLine.wideOff),
        elevation: Elevation.loft,
        direction: ShotDirection.offSide,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: false,
        random: DeterministicRandom(4),
      );
      expect(outcome.type, ContactType.miss);
      expect(outcome.acceptedSwing, isTrue);
    });

    test('power shot changes output but never cricket runs directly', () {
      final normal = resolver.resolve(
        delivery: delivery(),
        elevation: Elevation.loft,
        direction: ShotDirection.straight,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: false,
        random: DeterministicRandom(10),
      );
      final powered = resolver.resolve(
        delivery: delivery(),
        elevation: Elevation.loft,
        direction: ShotDirection.straight,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: true,
        random: DeterministicRandom(10),
      );
      expect(powered.power, greaterThan(normal.power));
      expect(powered.control, greaterThanOrEqualTo(normal.control));
      expect(powered.powerShotUsed, isTrue);
    });

    test('no input identifies a bowled threat in the stump channel', () {
      final outcome = resolver.resolve(
        delivery: delivery(length: DeliveryLength.full),
        elevation: Elevation.ground,
        direction: ShotDirection.straight,
        timingErrorMs: 276,
        hasInput: false,
        powerShot: false,
        random: DeterministicRandom(1),
      );
      expect(outcome.type, ContactType.miss);
      expect(outcome.bowledThreat, isTrue);
    });
  });

  group('physics and exact ties', () {
    const physics = PhysicsResolver();
    const fielding = FieldingResolver();

    test('ground shots and bounced lofts cannot become a six', () {
      const crossing = BallKinematics(
        position: FieldVector(1, 0),
        velocity: FieldVector(1, 0),
        height: 0.2,
        verticalVelocity: 0.1,
        aerial: true,
      );
      expect(physics.boundaryValue(crossing, Elevation.ground), 4);
      expect(physics.boundaryValue(crossing, Elevation.loft), 6);
      expect(
        physics.boundaryValue(
          crossing.copyWith(firstBounceOccurred: true),
          Elevation.loft,
        ),
        4,
      );
    });

    test('catch must be strictly before bounce', () {
      expect(physics.catchPrecedesBounce(0.9, 1.0), isTrue);
      expect(physics.catchPrecedesBounce(1.0, 1.0), isFalse);
    });

    test('pickup must be strictly before boundary', () {
      expect(physics.pickupPrecedesBoundary(0.9, 1.0), isTrue);
      expect(physics.pickupPrecedesBoundary(1.0, 1.0), isFalse);
    });

    test('crease tie is safe', () {
      expect(
        fielding.isRunOut(stumpBreakMicros: 999, creaseMicros: 1000),
        isTrue,
      );
      expect(
        fielding.isRunOut(stumpBreakMicros: 1000, creaseMicros: 1000),
        isFalse,
      );
    });

    test('risk labels use the documented margins', () {
      expect(fielding.riskForMargin(0.301), RiskLevel.safe);
      expect(fielding.riskForMargin(0.30), RiskLevel.close);
      expect(fielding.riskForMargin(-0.15), RiskLevel.close);
      expect(fielding.riskForMargin(-0.151), RiskLevel.danger);
    });
  });

  group('scoring', () {
    test('first-three objective includes intervening illegal runs', () {
      var update = ScoringResolver.updateObjective(
        ObjectiveType.sixRunsFirstThreeLegalBalls,
        0,
        result(
          legal: false,
          extra: ExtraType.noBall,
          extraRuns: 1,
          batRuns: 4,
          boundary: 4,
          legalBallsBefore: 2,
        ),
      );
      expect(update.progress, 5);
      expect(update.completed, isFalse);
      update = ScoringResolver.updateObjective(
        ObjectiveType.sixRunsFirstThreeLegalBalls,
        update.progress,
        result(runningRuns: 1, legalBallsBefore: 2),
      );
      expect(update.completed, isTrue);
    });

    test('double completes only after second running run', () {
      expect(
        ScoringResolver.updateObjective(
          ObjectiveType.completeDouble,
          0,
          result(runningRuns: 1),
        ).completed,
        isFalse,
      );
      expect(
        ScoringResolver.updateObjective(
          ObjectiveType.completeDouble,
          0,
          result(runningRuns: 2),
        ).completed,
        isTrue,
      );
    });

    test('no-contact extra leaves combo and power unchanged', () {
      final wide = result(
        legal: false,
        extra: ExtraType.wide,
        extraRuns: 1,
        contact: ContactType.none,
      );
      expect(ScoringResolver.nextCombo(2, wide), 2);
      expect(ScoringResolver.chargeFor(wide, 2), 0);
    });

    test('productive contacted no-ball advances combo', () {
      final noBallFour = result(
        legal: false,
        extra: ExtraType.noBall,
        extraRuns: 1,
        batRuns: 4,
        boundary: 4,
      );
      expect(ScoringResolver.nextCombo(1, noBallFour), 2);
      expect(ScoringResolver.chargeFor(noBallFour, 2), 3);
    });

    test('history tokens combine extras, runs, and wickets', () {
      expect(
        ScoringResolver.historyToken(
          extra: ExtraType.noBall,
          totalRuns: 5,
          batAndRunningRuns: 4,
          boundary: 4,
          dismissal: DismissalType.none,
        ),
        'NB+4',
      );
      expect(
        ScoringResolver.historyToken(
          extra: ExtraType.none,
          totalRuns: 1,
          batAndRunningRuns: 1,
          boundary: 0,
          dismissal: DismissalType.runOut,
        ),
        '1+RUN OUT',
      );
    });
  });
}
