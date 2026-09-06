import 'package:card_game/config/enums.dart';
import 'package:card_game/data/racing_drivers.dart';
import 'package:card_game/data/racing_portraits.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every motorsport driver resolves a portrait asset path', () {
    for (final driver in allRacingDrivers) {
      final path = racingPortraitAsset(driver.id);
      final extension = kRacingWebpPortraitArtIds.contains(driver.id)
          ? 'webp'
          : 'png';
      expect(path, 'assets/racing_driver_images/${driver.id}.$extension');
    }
    expect(allRacingDrivers, isNotEmpty);
  });

  test('all shipped motorsport portraits map to current roster drivers', () {
    expect(kRacingPngPortraitArtIds, hasLength(22));
    expect(kRacingWebpPortraitArtIds, hasLength(83));
    expect(racingPortraitArtCount, 105);
    for (final id in kRacingPortraitArtIds) {
      expect(racingPortraitHasArt(id), isTrue);
      expect(allRacingDrivers.any((driver) => driver.id == id), isTrue);
    }
  });

  testWidgets('every shipped motorsport portrait is bundled', (tester) async {
    for (final id in kRacingPortraitArtIds) {
      final assetPath = racingPortraitAsset(id);
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });

  test('racing cards expose portraitAsset and unique shortNames', () {
    final shortNames = <String>{};
    for (final card in racingPlayerCards) {
      expect(card.portraitAsset, isNotNull);
      expect(card.hasPortrait, isTrue);
      expect(shortNames.add(card.shortName), isTrue);
    }
    expect(racingPlayerCards.length, allRacingDrivers.length);
  });

  test('series role counts for shop avatar filters', () {
    expect(
      racingPlayerCards.where((c) => c.role == PlayerRole.f1Driver).length,
      f1Drivers2026.length,
    );
    expect(
      racingPlayerCards.where((c) => c.role == PlayerRole.f2Driver).length,
      f2Drivers2026.length,
    );
    expect(
      racingPlayerCards.where((c) => c.role == PlayerRole.nascarDriver).length,
      nascarDrivers2026.length,
    );
    expect(
      racingPlayerCards.where((c) => c.role == PlayerRole.indycarDriver).length,
      indycarDrivers2026.length,
    );
  });
}
