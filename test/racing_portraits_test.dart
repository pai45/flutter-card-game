import 'package:card_game/config/enums.dart';
import 'package:card_game/data/racing_drivers.dart';
import 'package:card_game/data/racing_portraits.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every motorsport driver resolves a portrait asset path', () {
    for (final driver in allRacingDrivers) {
      final path = racingPortraitAsset(driver.id);
      expect(path, 'assets/racing_driver_images/${driver.id}.png');
    }
    expect(allRacingDrivers, isNotEmpty);
  });

  test('F1 grid drivers with shipped art are flagged', () {
    expect(racingPortraitArtCount, 22);
    for (final id in kRacingPortraitArtIds) {
      expect(racingPortraitHasArt(id), isTrue);
      expect(f1Drivers2026.any((driver) => driver.id == id), isTrue);
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
