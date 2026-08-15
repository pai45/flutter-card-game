import 'package:card_game/blocs/achievement/achievement_celebration_controller.dart';
import 'package:card_game/models/achievement.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'pd_celebrated_achievements_v1': '[]',
    });
  });

  test('Treasury unlock is recorded without queuing its celebration', () async {
    final storage = SecureGameStorage();
    final controller = AchievementCelebrationController(storage);
    addTearDown(controller.close);
    await Future<void>.delayed(Duration.zero);

    controller.sync(_statsWithCoins(1000));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.queue, isEmpty);
    expect(await storage.loadCelebratedAchievements(), contains('treasury'));
  });
}

AchievementStats _statsWithCoins(int coins) => AchievementStats(
  level: 1,
  totalXP: 0,
  matchesPlayed: 0,
  matchWins: 0,
  bestMatchStreak: 0,
  cleanSheets: 0,
  shootoutWins: 0,
  basketballWins: 0,
  tennisAchievements: const {},
  predictionsMade: 0,
  correctPredictions: 0,
  picksPlaced: 0,
  picksWon: 0,
  pickStreak: 0,
  pickProfit: 0,
  ownedCards: 0,
  platinumOwned: 0,
  coins: coins,
);
