import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/blocs/super_over/super_over_bloc.dart';
import 'package:card_game/blocs/super_over/super_over_event.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SuperOverBloc Tests', () {
    late SecureGameStorage storage;
    late SuperOverBloc bloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = SecureGameStorage();
      bloc = SuperOverBloc(storage);
    });

    tearDown(() {
      bloc.close();
    });

    test('emits correct initial state for Score Attack', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );

      await Future.microtask(() {});

      expect(bloc.state.mode, SuperOverMode.scoreAttack);
      expect(bloc.state.cpuTarget, 0);
    });

    test('DeliveryResolved processes runs correctly', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      bloc.add(const SuperOverDeliveryResolved(ShotOutcome.four));
      await Future.microtask(() {});

      expect(bloc.state.score, 4);
      expect(bloc.state.ballsFaced, 1);
      expect(bloc.state.wagonWheel, [ShotOutcome.four]);
      expect(bloc.state.momentum, 1);
    });

    test('ShotResolved captures one-tap timing feedback', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      bloc.add(const SuperOverNextBallRequested());
      await Future.microtask(() {});
      bloc.add(const SuperOverInputArmed());
      await Future.microtask(() {});

      expect(bloc.state.canTap, true);

      bloc.add(const SuperOverSwingLocked());
      await Future.microtask(() {});
      bloc.add(const SuperOverSwingLocked());
      await Future.microtask(() {});

      expect(bloc.state.swingLocked, true);
      expect(bloc.state.canTap, false);

      bloc.add(const SuperOverShotResolved(timingErrorMs: 0));
      await Future.microtask(() {});

      expect(bloc.state.ballsFaced, 1);
      expect(bloc.state.timingTier, TimingTier.perfect);
      expect(bloc.state.shotSector, ShotSector.v);
      expect(bloc.state.lastOutcome, isNotNull);
    });

    test('shot selection is explicit and locks after swing', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      bloc.add(const SuperOverSectorSelected(ShotSector.leg));
      await Future.microtask(() {});
      bloc.add(const SuperOverShotStyleSelected(ShotStyle.loft));
      await Future.microtask(() {});
      expect(bloc.state.selectedSector, ShotSector.leg);
      expect(bloc.state.selectedShotStyle, ShotStyle.loft);

      bloc.add(const SuperOverNextBallRequested());
      await Future.microtask(() {});
      bloc.add(const SuperOverInputArmed());
      await Future.microtask(() {});
      bloc.add(const SuperOverSwingLocked());
      await Future.microtask(() {});
      bloc.add(const SuperOverSectorSelected(ShotSector.off));
      await Future.microtask(() {});
      expect(bloc.state.selectedSector, ShotSector.leg);
    });

    test('generates a fair field and upcoming delivery each ball', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.chase,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      void expectFairField(List<int> field) {
        expect(field, hasLength(3));
        expect(
          field.fold<int>(0, (s, n) => s + n),
          9,
          reason: '9 fielders split across OFF/V/LEG',
        );
        expect(
          field.reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(1),
          reason: 'every field preset keeps all sectors represented',
        );
        expect(
          field.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(5),
          reason: 'no sector should swallow the whole field',
        );
      }

      expectFairField(bloc.state.fieldSectors);
      expect(DeliveryType.values, contains(bloc.state.upcomingDelivery));
      expect(DeliveryLength.values, contains(bloc.state.deliveryPlan.length));

      bloc.add(const SuperOverDeliveryResolved(ShotOutcome.two));
      await Future.microtask(() {});

      // A fresh field is rolled for the next ball.
      expectFairField(bloc.state.fieldSectors);
    });

    test('three clean contacts arm one On Fire delivery', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      for (var i = 0; i < 3; i++) {
        bloc.add(const SuperOverDeliveryResolved(ShotOutcome.two));
        await Future.microtask(() {});
        if (i < 2) {
          bloc.add(const SuperOverNextBallRequested());
          await Future.microtask(() {});
        }
      }

      expect(bloc.state.onFire, isTrue);
      expect(bloc.state.confidence, greaterThan(0));
      expect(bloc.state.maxCombo, 3);
    });

    test('DeliveryResolved handles wickets and limits', () async {
      bloc.add(
        const SuperOverStarted(
          battingOrder: [],
          mode: SuperOverMode.scoreAttack,
          playerLevel: 10,
        ),
      );
      await Future.microtask(() {});

      bloc.add(const SuperOverDeliveryResolved(ShotOutcome.bowled));
      await Future.microtask(() {});

      expect(bloc.state.wickets, 1);
      expect(bloc.state.ballsFaced, 1);
      expect(bloc.state.strikerIndex, 2);

      bloc.add(const SuperOverNextBallRequested());
      await Future.microtask(() {});
      bloc.add(const SuperOverDeliveryResolved(ShotOutcome.caught));
      await Future.microtask(() {});

      expect(bloc.state.wickets, 2);
      expect(bloc.state.ballsFaced, 2);
      expect(bloc.state.isOver, true);
    });
  });
}
