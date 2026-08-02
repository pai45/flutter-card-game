import 'package:card_game/models/progression.dart';
import 'package:card_game/models/xp_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('per-track progression', () {
    test('applies XP to the matching track only', () {
      var progression = PlayerProgression.initial();
      final hoop = applyXpTransaction(
        progression: progression,
        ledger: const [],
        delta: 100,
        source: XpTransactionSource.basketball,
        title: 'HOOP DUEL',
        timestamp: DateTime(2026, 7, 1),
      );
      progression = hoop.progression;
      expect(progression.xpFor(ProgressTrack.hoopDuel), 100);
      expect(progression.xpFor(ProgressTrack.pitchDuel), 0);
      expect(progression.levelFor(ProgressTrack.hoopDuel), 2);
      expect(progression.totalXP, 100);
      expect(progression.playerLevel, 2);
      expect(hoop.track, ProgressTrack.hoopDuel);
    });

    test('total level uses levelFromXp of summed track XP', () {
      final progression = PlayerProgression(
        xpByTrack: {
          ProgressTrack.pitchDuel: 600,
          ProgressTrack.hoopDuel: 4500,
        },
      );
      expect(progression.levelFor(ProgressTrack.pitchDuel), 4);
      expect(progression.levelFor(ProgressTrack.hoopDuel), 10);
      expect(progression.totalXP, 5100);
      expect(progression.playerLevel, levelFromXp(5100));
      expect(progression.playerLevel, isNot(14));
    });

    test('maps sources onto tracks', () {
      expect(
        progressTrackForSource(XpTransactionSource.match),
        ProgressTrack.pitchDuel,
      );
      expect(
        progressTrackForSource(XpTransactionSource.prediction),
        ProgressTrack.prediction,
      );
      expect(
        progressTrackForSource(XpTransactionSource.pack),
        ProgressTrack.cardsMeta,
      );
      expect(
        progressTrackForSource(XpTransactionSource.superOver),
        ProgressTrack.finalOver,
      );
      expect(
        progressTrackForSource(XpTransactionSource.bingo),
        ProgressTrack.bingo,
      );
    });

    test('migrates legacy total via ledger fold', () {
      final ledger = [
        XpLedgerEntry(
          id: 'a',
          timestamp: DateTime(2026, 1, 2),
          delta: 50,
          balanceAfter: 150,
          type: XpTransactionType.earn,
          source: XpTransactionSource.basketball,
          title: 'HOOP',
        ),
        XpLedgerEntry(
          id: 'b',
          timestamp: DateTime(2026, 1, 1),
          delta: 100,
          balanceAfter: 100,
          type: XpTransactionType.earn,
          source: XpTransactionSource.match,
          title: 'PITCH',
        ),
      ];
      final migrated = migrateProgressionFromLegacy(
        legacyTotalXp: 150,
        ledger: ledger,
      );
      expect(migrated.xpFor(ProgressTrack.pitchDuel), 100);
      expect(migrated.xpFor(ProgressTrack.hoopDuel), 50);
      expect(migrated.totalXP, 150);
    });

    test('migrates legacy total to cardsMeta when ledger empty', () {
      final migrated = migrateProgressionFromLegacy(
        legacyTotalXp: 450,
        ledger: const [],
      );
      expect(migrated.xpFor(ProgressTrack.cardsMeta), 450);
      expect(migrated.totalXP, 450);
      expect(migrated.playerLevel, levelFromXp(450));
    });

    test('round-trips xpByTrack JSON', () {
      final original = PlayerProgression(
        xpByTrack: {
          ProgressTrack.prediction: 40,
          ProgressTrack.quiz: 20,
        },
      );
      final restored = PlayerProgression.fromJson(original.toJson());
      expect(restored.xpFor(ProgressTrack.prediction), 40);
      expect(restored.xpFor(ProgressTrack.quiz), 20);
      expect(PlayerProgression.jsonIsLegacy(original.toJson()), isFalse);
      expect(PlayerProgression.jsonIsLegacy({'totalXP': 100}), isTrue);
    });

    test('prefers total-level crosses in levelsGained', () {
      final result = applyXpTransaction(
        progression: PlayerProgression(
          xpByTrack: {ProgressTrack.cardsMeta: 99},
        ),
        ledger: const [],
        delta: 2,
        source: XpTransactionSource.match,
        title: 'PITCH',
        timestamp: DateTime(2026, 7, 2),
      );
      expect(result.totalLevelsGained, [2]);
      expect(result.levelsGained, [2]);
      expect(result.track, ProgressTrack.pitchDuel);
    });
  });
}