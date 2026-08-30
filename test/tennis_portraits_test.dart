import 'package:flutter/services.dart';
import 'package:card_game/data/tennis_athletes.dart';
import 'package:card_game/data/tennis_portraits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supplied tennis portraits map to real roster athletes', () {
    final rosterIds = tennisTop100.map((athlete) => athlete.id).toSet();

    expect(tennisPortraitAssets, hasLength(47));
    expect(tennisPortraitAssets.keys, everyElement(isIn(rosterIds)));
    expect(
      tennisPortraitAssetFor('alexander-bublik'),
      'assets/tennis_player_images/alexander-bublik.png',
    );
    expect(
      tennisPortraitAssetFor('jannik-sinner'),
      'assets/tennis_player_images/jannik-sinner.webp',
    );
    expect(tennisPortraitAssetFor('alexander-zverev'), isNull);
  });

  testWidgets('every mapped tennis portrait is bundled', (tester) async {
    for (final assetPath in tennisPortraitAssets.values) {
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
