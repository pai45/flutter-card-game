import 'package:card_game/models/rival_dossier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RivalDossier.fromSeed', () {
    test('is deterministic — same seed yields identical dossier', () {
      final a = RivalDossier.fromSeed(name: 'jarvis', xp: 3910, pro: true);
      final b = RivalDossier.fromSeed(name: 'jarvis', xp: 3910, pro: true);
      expect(a.level, b.level);
      expect(a.winRate, b.winRate);
      expect(a.matchesPlayed, b.matchesPlayed);
      expect(a.predictionAccuracy, b.predictionAccuracy);
      expect(a.pickWinRate, b.pickWinRate);
      expect(a.ownedCards, b.ownedCards);
      expect(a.border?.id, b.border?.id);
    });

    test('higher XP scales up level and win rate for the same rival', () {
      final weak = RivalDossier.fromSeed(name: 'rookie', xp: 1980);
      final strong = RivalDossier.fromSeed(name: 'rookie', xp: 3910);
      expect(strong.level, greaterThanOrEqualTo(weak.level));
      // Same name → identical jitter, so strength alone moves the rate up.
      expect(strong.winRate, greaterThanOrEqualTo(weak.winRate));
    });

    test('PRO gates the equipped border', () {
      final pro = RivalDossier.fromSeed(name: 'jarvis', xp: 3910, pro: true);
      final amateur = RivalDossier.fromSeed(name: 'jarvis', xp: 3910);
      expect(pro.border, isNotNull);
      expect(amateur.border, isNull);
    });

    test('numbers stay self-consistent and in believable bounds', () {
      for (final name in ['jarvis', 'Vortex', 'rookie', 'Zenith', 'Ghost']) {
        final d = RivalDossier.fromSeed(name: name, xp: 3000);
        expect(d.winRate, inInclusiveRange(32, 84));
        expect(d.predictionAccuracy, inInclusiveRange(28, 88));
        expect(d.pickWinRate, inInclusiveRange(28, 82));
        expect(d.matchWins, lessThanOrEqualTo(d.matchesPlayed));
        expect(d.correctPredictions, lessThanOrEqualTo(d.predictionsMade));
        expect(d.picksWon, lessThanOrEqualTo(d.picksPlaced));
      }
    });

    test('achievement snapshot mirrors the dossier; wallet stays private', () {
      final d = RivalDossier.fromSeed(name: 'jarvis', xp: 3910, pro: true);
      final s = d.achievementStats;
      expect(s.level, d.level);
      expect(s.totalXP, 3910);
      expect(s.matchWins, d.matchWins);
      expect(s.coins, 0);
    });
  });
}
