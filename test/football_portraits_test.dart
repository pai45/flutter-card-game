import 'package:card_game/models/cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _suppliedFootballPortraits = <String, String>{
  'bra-ederson-moraes': 'assets/player_images/ederson_moraes.webp',
  'fra-aurelien-tchouameni': 'assets/player_images/aurelien_tchouameni.webp',
  'ned-bart-verbruggen': 'assets/player_images/bart_verbruggen.webp',
  'bra-vinicius-junior': 'assets/player_images/vinicius_junior.webp',
};

void main() {
  test('supplied football portraits resolve to their exact player cards', () {
    final cardsById = {for (final card in allPlayerCards) card.id: card};

    _suppliedFootballPortraits.forEach((id, assetPath) {
      expect(cardsById[id]?.resolvedPortraitAsset, assetPath, reason: id);
    });
  });

  testWidgets('every supplied football portrait is bundled', (tester) async {
    for (final assetPath in _suppliedFootballPortraits.values) {
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
