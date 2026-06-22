import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletSnapshot frame migration', () {
    test('legacy border keys migrate to frame ids and preserve coins', () {
      final legacy = WalletSnapshot.fromJson({
        'coins': 1000,
        'ownedCardIds': ['a'],
        'equippedCardBackId': 'default',
        'ownedAvatarBorderIds': ['border_liv', 'border_mc'],
        'equippedAvatarBorderId': 'border_liv',
      });
      expect(legacy.coins, 1000);
      expect(legacy.ownedAvatarFrameIds, ['frame_liv', 'frame_mc']);
      expect(legacy.equippedAvatarFrameId, 'frame_liv');
    });

    test('new frame keys round-trip and take precedence', () {
      final snap = WalletSnapshot.fromJson({
        'coins': 250,
        'ownedAvatarFrameIds': ['frame_ars'],
        'equippedAvatarFrameId': 'frame_ars',
        // stale legacy keys should be ignored when new keys exist
        'ownedAvatarBorderIds': ['border_liv'],
        'equippedAvatarBorderId': 'border_liv',
      });
      expect(snap.coins, 250);
      expect(snap.ownedAvatarFrameIds, ['frame_ars']);
      expect(snap.equippedAvatarFrameId, 'frame_ars');

      final round = WalletSnapshot.fromJson(snap.toJson());
      expect(round.coins, 250);
      expect(round.ownedAvatarFrameIds, ['frame_ars']);
      expect(round.equippedAvatarFrameId, 'frame_ars');
    });

    test('empty/legacy-free wallet keeps coins and defaults frames', () {
      final snap = WalletSnapshot.fromJson({'coins': 777});
      expect(snap.coins, 777);
      expect(snap.ownedAvatarFrameIds, isEmpty);
      expect(snap.equippedAvatarFrameId, '');
    });
  });
}
