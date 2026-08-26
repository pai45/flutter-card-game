import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/data/basketball_portraits.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supplied basketball portraits map to current roster athletes', () {
    final rosterIds = basketballAthletes.map((athlete) => athlete.id).toSet();

    expect(basketballPortraitAssets, hasLength(69));
    expect(basketballPortraitAssets.keys, everyElement(isIn(rosterIds)));
    final cardPortraits = {
      for (final card in basketballPlayerCards) card.id: card.portraitAsset,
    };
    basketballPortraitAssets.forEach((athleteId, assetPath) {
      expect(cardPortraits[athleteId], assetPath, reason: athleteId);
    });
    expect(
      basketballPortraitAssetFor('lal-lebron-james'),
      'assets/basketball_player_images/lebron_james.webp',
    );
    expect(
      basketballPortraitAssetFor('lal-austin-reaves'),
      'assets/basketball_player_images/austin_reaves.webp',
    );
    expect(basketballPortraitAssetFor('gsw-stephen-curry'), isNull);
  });

  testWidgets('every mapped basketball portrait is bundled', (tester) async {
    for (final assetPath in basketballPortraitAssets.values) {
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
