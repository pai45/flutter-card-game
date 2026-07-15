import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/xp_ledger.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SuperOverFinished uses exact shared XP and settles once by match ID',
    () async {
      final storage = SecureGameStorage();
      final bloc = GameBloc(storage);
      addTearDown(bloc.close);
      final summary = SuperOverMatchSummary(
        matchId: 'super-over-settlement-1',
        seed: 17,
        mode: SuperOverMode.chase,
        difficulty: SuperOverDifficulty.pro,
        target: 17,
        score: 18,
        wickets: 0,
        ballsFaced: 4,
        wonChase: true,
        objective: const SuperOverObjective(
          type: SuperOverObjectiveType.runs,
          target: 16,
        ),
        objectiveComplete: true,
        battingCardIds: const ['one', 'two', 'three'],
        ballRecords: const [],
        finishingBatterCardId: 'one',
        grade: SuperOverPerformanceGrade.a,
      );
      final event = SuperOverFinished(summary: summary);

      bloc.add(event);
      await bloc.stream.firstWhere(
        (state) => state.progression.totalXP == summary.rewardBreakdown.totalXp,
      );
      bloc.add(event);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.lastMatchXP, summary.rewardBreakdown.totalXp);
      expect(
        bloc.state.matchHistory.where(
          (item) => item.id == 'super-over:${summary.matchId}',
        ),
        hasLength(1),
      );
      expect(
        bloc.state.xpLedger.where(
          (entry) => entry.source == XpTransactionSource.superOver,
        ),
        hasLength(1),
      );
      expect(
        await storage.loadSuperOverSettlementIds(),
        contains('super-over:${summary.matchId}'),
      );
    },
  );
}
